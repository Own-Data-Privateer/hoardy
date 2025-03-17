#!/usr/bin/env python3
#
# Copyright (c) 2020-2025 Jan Malakhovski <oxij@oxij.org>
#
# This file is a part of `hoardy` project.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this program. If not, see
# <http://www.gnu.org/licenses/>.

"""`main()`."""

import collections as _c
import dataclasses as _dc
import errno as _errno
import hashlib as _hashlib
import io as _io
import logging as _logging
import os as _os
import os.path as _op
import stat as _stat
import sys as _sys
import typing as _t

from contextlib import contextmanager as _contextmanager
from gettext import gettext
from struct import unpack as _unpack

from kisstdlib import *
from kisstdlib import argparse_ext as argparse
from kisstdlib.argparse_ext import SUPPRESS
from kisstdlib.fs import *
from kisstdlib.sqlite3_ext import DictSettingsAppDB, Cursor, iter_fetchmany
from kisstdlib.time import Timestamp

__prog__ = "hoardy"
DB_POSIX = "~/.local/share/hoardy/index.db"
DB_WINDOWS = R"%LOCALAPPDATA%\hoardy\index.db"
REPORT_SIZE = 64 * MiB
NANOSECOND = 10**9


class DB(DictSettingsAppDB):
    MIN_VERSION = 3
    MAX_VERSION = 3

    def __init__(self, path: str, *args: _t.Any, **kwargs: _t.Any) -> None:
        super().__init__(path, 3, {}, *args, **kwargs)

    def upgrade(self, cur: Cursor, target_version: int) -> None:
        if self.version == 0:
            cur.execute(
                "CREATE TABLE files (path BLOB NOT NULL PRIMARY KEY, sha256 BLOB NOT NULL, size INTEGER NOT NULL, original_mtime INTEGER NOT NULL, ino_mtime INTEGER, ino_status INTEGER, ino_id INTEGER) WITHOUT ROWID"
            )
            self.version = 3
            return

        assert False


def str_path(fpath: str | bytes) -> str:
    return escape_path(fsdecode(fpath))


def get_stdout_path(cargs: _t.Any) -> _t.Callable[[bytes], str | bytes]:
    if cargs.terminator == b"\0":
        return identity
    return str_path


failed_msg = gettext("`%s` failed: [Errno %d, %s] %s: %s")
skipping_failed_msg = gettext("skipping: `%s` failed: [Errno %d, %s] %s: %s")


def on_os_error(msg: str, what: str, exc: OSError) -> tuple[str, str, int, str, str, str]:
    errno = exc.errno
    if errno == _errno.EIO:
        # the disk is dead, stop immediately
        raise exc
    return (
        msg,
        what,
        errno,
        _errno.errorcode.get(errno, "?"),
        _os.strerror(errno),
        str_path(exc.filename),
    )


@_contextmanager
def keep_progress(lhnd: ANSILogHandler) -> _t.Iterator[None]:
    lhnd.flush()
    try:
        yield None
    finally:
        stdout.flush()
        lhnd.update()


def sha256_symlink(fpath: bytes) -> bytes:
    target = _os.readlink(fpath)
    fhash = _hashlib.sha256()
    fhash.update(target)
    return fhash.digest()


def get_xattrs(path: str | bytes, /) -> dict[bytes, bytes]:
    path = fsencode(path)  # for efficiency
    res = {}
    for name_ in _os.listxattr(path):
        name = fsencode(name_)
        res[name] = _os.getxattr(path, name)
    return res


# TODO: make into a LRU cache?
inode_hash_cache: dict[tuple[int, int], tuple[bytes, bytes]] = {}


def get_sha256(fpath: bytes, fstat: _os.stat_result, hash_len: int | None) -> bytes:
    inode = (fstat.st_dev, fstat.st_ino)
    try:
        return inode_hash_cache[inode][1]
    except KeyError:
        pass

    if fstat.st_size > REPORT_SIZE:
        info("Hashing `%s`...", str_path(fpath))

    if _stat.S_ISREG(fstat.st_mode):
        sha256 = sha256_file(fpath)
    elif _stat.S_ISLNK(fstat.st_mode):
        sha256 = sha256_symlink(fpath)
    else:
        raise ValueError("bad inode type")
    if hash_len is not None:
        sha256 = sha256[:hash_len]
    inode_hash_cache[inode] = (fpath, sha256)
    return sha256


def note_hash(fpath: bytes, fstat: _os.stat_result, sha256: bytes) -> None:
    inode = (fstat.st_dev, fstat.st_ino)
    try:
        _pfpath, psha256 = inode_hash_cache[inode]
    except KeyError:
        inode_hash_cache[inode] = (fpath, sha256)
    else:
        # TODO: log errors instead?
        assert psha256 == sha256


def fmode_to_type(status: int) -> str:
    if _stat.S_ISREG(status):
        return "f"
    if _stat.S_ISLNK(status):
        return "l"
    return "?"


wrong_field_msg = gettext("wrong %s: %s -> %s: `%s`")
wrong_field_error = partial(error, wrong_field_msg)
wrong_field_warning = partial(warning, wrong_field_msg)


def equal_stat(
    onerror: _t.Callable[[str, str | int, str | int, str], None] | None,
    fpath: str | bytes,
    fstat: _os.stat_result,
    **kwargs: int | None,
) -> bool:
    """Check that specified `os.stat_result` fields stay same."""
    res = True

    mode = kwargs.pop("mode", None)
    typ = kwargs.pop("type", mode)

    if typ is not None:
        etyp = _stat.S_IFMT(typ)
        eatyp = _stat.S_IFMT(fstat.st_mode)
        if etyp != eatyp:
            if onerror is not None:
                onerror(
                    "type",
                    fmode_to_type(etyp),
                    fmode_to_type(eatyp),
                    str_path(fpath),
                )
            res = False

    if mode is not None:
        emode = _stat.S_IMODE(mode)
        eamode = _stat.S_IMODE(fstat.st_mode)
        if emode != eamode:
            if onerror is not None:
                m1 = oct(emode)[2:]
                m2 = oct(eamode)[2:]
                onerror(
                    "mode",
                    m1,
                    m2,
                    str_path(fpath),
                )
            res = False

    value: str | int | None
    for name, value in kwargs.items():
        if value is None or name == "ino" and value == 0:
            continue
        avalue = getattr(fstat, "st_" + name)
        if value != avalue:
            if onerror is not None:
                if name.endswith("_ns"):
                    name = name[:-3]
                    value = "[" + Timestamp(Decimal(value) / NANOSECOND).format(precision=9) + "]"
                    avalue = "[" + Timestamp(Decimal(avalue) / NANOSECOND).format(precision=9) + "]"
                onerror(
                    name,
                    value,
                    avalue,
                    str_path(fpath),
                )
            res = False

    return res


def equal_xattrs(
    onerror: _t.Callable[[str, str | int, str | int, str], None] | None,
    fpath: str | bytes,
    exattrs: dict[bytes, bytes],
    xattrs: dict[bytes, bytes] | None,
) -> bool:
    res = True

    if xattrs is not None:
        keys = set(xattrs.keys())
        keys.update(exattrs.keys())
        for key in keys:
            a = xattrs.get(key, None)
            b = exattrs.get(key, None)
            if a != b:
                if onerror is not None:
                    onerror(
                        f"xattr `{fsdecode(key)}`",
                        repr(abbrev(a, 16)) if a is not None else "None",
                        repr(abbrev(b, 16)) if b is not None else "None",
                        str_path(fpath),
                    )
                res = False

    return res


def iter_input_queries(cargs: _t.Any) -> _t.Iterator[tuple[str, tuple[_t.Any, ...]]]:
    suffix_where = []
    suffix_params = []

    if cargs.size_geq is not None:
        suffix_where.append("size >= ?")
        suffix_params.append(cargs.size_geq)
    if cargs.size_leq is not None:
        suffix_where.append("size <= ?")
        suffix_params.append(cargs.size_leq)

    if cargs.sha256_geq is not None:
        suffix_where.append("sha256 >= ?")
        suffix_params.append(bytes.fromhex(cargs.sha256_geq))
    if cargs.sha256_leq is not None:
        suffix_where.append("sha256 <= ?")
        suffix_params.append(bytes.fromhex(cargs.sha256_leq))

    for fpath in cargs.inputs:
        fprefix = fpath if fpath != b"/" else b""
        sql_where = "(path = ? OR (path > ? AND path < ?))"
        sql_params = [fpath, fprefix + b"/", fprefix + b"0"]
        sql_where = " AND ".join([sql_where] + suffix_where)
        sql_params = sql_params + suffix_params
        yield sql_where, tuple(sql_params)


DBObj = tuple[bytes, bytes, int, int, int, int, int]


def cmd_index(cargs: _t.Any, lhnd: ANSILogHandler) -> None:
    verbosity = cargs.verbosity
    stdout_path = get_stdout_path(cargs)

    dry_run: bool = cargs.dry_run
    hash_len = cargs.hash_len
    checksum = cargs.checksum
    do_verify = False
    do_add: bool = cargs.do_add
    do_remove: bool = cargs.do_remove
    do_update: bool
    if isinstance(cargs.do_update, bool):
        do_update = cargs.do_update
    elif cargs.do_update == "reindex":
        do_update = True
        checksum = True
    elif cargs.do_update == "verify":
        do_verify = True
    elif cargs.do_update == "both":
        do_update = True
        checksum = True
        do_verify = True
    else:
        assert False

    record_ino: bool = cargs.record_ino

    adding_msg = gettext("add") + " "
    removing_msg = gettext("rm") + " "
    updating_msg = gettext("update") + " "
    if dry_run:
        adding_msg = gettext("dry-run: (not)") + " " + adding_msg
        removing_msg = gettext("dry-run: (not)") + " " + removing_msg
        updating_msg = gettext("dry-run: (not)") + " " + updating_msg

    roots_total = len(cargs.inputs)

    class Stats:
        roots_so_far: int = 0
        paths_so_far: int = 0

    def progress(fpath: bytes) -> None:
        roots_so_far = Stats.roots_so_far
        info(
            "Indexing (%d%% %d/%d roots, %d paths) `%s`...",
            100 * roots_so_far // roots_total,
            roots_so_far,
            roots_total,
            Stats.paths_so_far,
            str_path(fpath),
        )

    con = DB(cargs.database)
    updcur = con.cursor()
    cur = con.cursor()

    def db_remove(_dbobj: DBObj | None, fpath: bytes) -> None:
        if not do_remove:
            return

        if verbosity > 0:
            with keep_progress(lhnd):
                stdout.write_str(removing_msg)
                stdout.write_ln(stdout_path(fpath))

        if not dry_run:
            updcur.execute("DELETE FROM files WHERE path = ?", (fpath,))
            con.commit_maybe()

    def db_update(dbobj: DBObj | None, fpath: bytes, is_root: bool = False) -> None:
        paths_so_far = Stats.paths_so_far
        if is_root or paths_so_far % 100000 == 0:
            progress(fpath)
        Stats.paths_so_far = paths_so_far + 1

        try:
            fstat = _os.lstat(fpath)
        except FileNotFoundError as exc:
            if is_root:
                if dbobj is None:
                    # wasn't in the DATABASE, does not exists now
                    error(gettext("not found: `%s`"), str_path(fpath))
                else:
                    # was in the DATABASE, does not exists now
                    db_remove(dbobj, fpath)
            else:
                error(*on_os_error(skipping_failed_msg, "stat", exc))
            return
        except OSError as exc:
            error(*on_os_error(skipping_failed_msg, "stat", exc))
            return

        if _stat.S_ISDIR(fstat.st_mode):
            assert is_root

            if dbobj is not None:
                # was in the DATABASE, was a regular file or a symlink before
                db_remove(dbobj, fpath)

            fprefix = fpath if fpath != b"/" else b""
            cur.execute(
                "SELECT path, sha256, size, original_mtime, ino_mtime, ino_status, ino_id FROM files WHERE path > ? AND path < ?",
                (fprefix + b"/", fprefix + b"0"),
            )
            db_iter: _t.Iterator[DBObj] = iter_fetchmany(cur)
            fs_iter = iter_subtree(
                fpath,
                include_directories=False,
                follow_symlinks=False,
                handle_error=_logging.error,
            )

            # apply differences between (sorted) db_iter and fs_iter to the database
            for d in diff_sorted(db_iter, fs_iter, first, first):
                raise_first_delayed_signal()

                if isinstance(d, tuple):
                    db_obj, fs_obj = d
                    db_update(db_obj, fs_obj[0])
                elif isinstance(d, Left):
                    db_obj = d.left
                    db_remove(db_obj, db_obj[0])
                elif isinstance(d, Right):
                    fs_obj = d.right
                    db_update(None, fs_obj[0])
                else:
                    assert False
            return

        fmode = fstat.st_mode

        if not _stat.S_ISREG(fmode) and not _stat.S_ISLNK(fmode):
            if dbobj is None:
                warning(
                    gettext("skipping: unsupported inode type `%s`: `%s`"),
                    fmode_to_type(fmode),
                    str_path(fpath),
                )
            else:
                if do_remove:
                    warning(
                        gettext("removing: unsupported inode type `%s`: `%s`"),
                        fmode_to_type(fmode),
                        str_path(fpath),
                    )
                else:
                    warning(
                        gettext(
                            "`--no-remove`, thus, not removing: unsupported inode type `%s`: `%s`"
                        ),
                        fmode_to_type(fmode),
                        str_path(fpath),
                    )
                db_remove(dbobj, fpath)
            return

        fsize = fstat.st_size
        fmtime_ns = fstat.st_mtime_ns
        fino = fstat.st_ino if record_ino else 0

        if dbobj is None:
            if not do_add:
                return

            try:
                with yes_signals():
                    sha256 = get_sha256(fpath, fstat, hash_len)
            except OSError as exc:
                error(*on_os_error(skipping_failed_msg, "stat", exc))
                return

            if verbosity > 0:
                with keep_progress(lhnd):
                    stdout.write_str(adding_msg)
                    stdout.write_ln(stdout_path(fpath))

            if not dry_run:
                updcur.execute(
                    "INSERT INTO files VALUES (?, ?, ?, ?, ?, ?, ?)",
                    (fpath, sha256, fsize, fmtime_ns, None, fmode, fino),
                )
                con.commit_maybe()
        else:
            if not do_update:
                return

            _, old_sha256, old_size, old_orig_mtime_ns, old_over_mtime_ns, old_mode, old_ino = dbobj
            old_mtime_ns = old_over_mtime_ns if old_over_mtime_ns is not None else old_orig_mtime_ns

            if (
                checksum
                or old_size != fsize
                or old_mtime_ns != fmtime_ns
                or _stat.S_IFMT(old_mode) != _stat.S_IFMT(fmode)
            ):
                try:
                    with yes_signals():
                        sha256 = get_sha256(fpath, fstat, hash_len)
                except OSError as exc:
                    error(*on_os_error(skipping_failed_msg, "stat", exc))
                    return
            else:
                sha256 = old_sha256
                note_hash(fpath, fstat, sha256)

            over_mtime_ns = fmtime_ns if old_orig_mtime_ns != fmtime_ns else None

            if (
                old_sha256 != sha256
                or old_size != fsize
                or old_over_mtime_ns != over_mtime_ns
                or old_mode != fmode
                or old_ino != fino
            ):
                if do_verify:
                    error(gettext("verify failed: `%s`"), str_path(fpath))
                    return

                if verbosity > 0:
                    with keep_progress(lhnd):
                        stdout.write_str(updating_msg)
                        stdout.write_ln(stdout_path(fpath))

                if not dry_run:
                    updcur.execute(
                        "REPLACE INTO files VALUES (?, ?, ?, ?, ?, ?, ?)",
                        (fpath, sha256, fsize, old_orig_mtime_ns, over_mtime_ns, fmode, fino),
                    )
                    con.commit_maybe()

    try:
        for root in cargs.inputs:
            raise_first_delayed_signal()

            root_dbobj = cur.execute(
                "SELECT path, sha256, size, original_mtime, ino_mtime, ino_status, ino_id FROM files WHERE path = ?",
                (root,),
            ).fetchone()
            db_update(root_dbobj, root, True)
            Stats.roots_so_far += 1

        con.commit()
    except (GentleSignalInterrupt, BrokenPipeError):
        error("Indexing was interrupted.")
        info("Commiting partial results...")
        con.commit()
    except BaseException:
        con.rollback()
        raise

    info("Done. Syncing `DATABASE`...")
    con.close()


def cmd_find(cargs: _t.Any, _lhnd: ANSILogHandler) -> None:
    stdout_path = get_stdout_path(cargs)

    if cargs.porcelain:

        def output(sha256: bytes, fmode: int, fpath: bytes) -> None:
            stdout.write_str(sha256.hex())
            stdout.write_str(" ")
            stdout.write_str(fmode_to_type(fmode))
            stdout.write_str(" ")
            stdout.write_ln(stdout_path(fpath))

    else:

        def output(  # pylint: disable=unused-argument
            sha256: bytes, fmode: int, fpath: bytes
        ) -> None:
            stdout.write_ln(stdout_path(fpath))

    do_flush = stdout.isatty()

    con = DB(cargs.database)
    cur = con.cursor()

    for sql_where, sql_params in iter_input_queries(cargs):
        cur.execute("SELECT path, sha256, ino_status FROM files WHERE " + sql_where, sql_params)
        for fpath, sha256, fmode in cur:
            raise_first_delayed_signal()
            output(sha256, fmode, fpath)
            if do_flush:
                stdout.flush()


# TODO: on Linux, parse /proc/mounts instead
st_dev_stack: list[tuple[bytes, int]] = []


def get_dev(fpath: bytes) -> int:
    """Get `stat.st_dev` without actually `stat`ting each file by `stat`ting the
    directory stack instead.
    """
    fdir = _op.dirname(fpath)

    while st_dev_stack:
        ldir, ldev = st_dev_stack[len(st_dev_stack) - 1]
        if ldir == fdir:
            return ldev
        if fdir.startswith(ldir) and fdir.startswith(sepb, len(ldir)):
            # it's a parent of ours, keep it as it might be useful later
            break
        st_dev_stack.pop()

    # warning("stat `%s`", fdir)
    dstat = _os.lstat(fdir)
    if not _stat.S_ISDIR(dstat.st_mode):
        raise NotADirectoryError(_errno.ENOTDIR, _os.strerror(_errno.ENOTDIR), fdir)

    res = dstat.st_dev
    st_dev_stack.append((fdir, res))
    return res


@_dc.dataclass
class Inode:
    dev: int
    ino: int
    mode: int
    size: int
    mtime_ns: int
    uid: int | None = _dc.field(default=None)
    gid: int | None = _dc.field(default=None)
    xattrs: dict[bytes, bytes] | None = _dc.field(default=None)


def equal_stat_inode(
    onerror: _t.Callable[[str, str | int, str | int, str], None] | None,
    fpath: str | bytes,
    fstat: _os.stat_result,
    inode: Inode,
) -> bool:
    return equal_stat(
        onerror,
        fpath,
        fstat,
        mode=inode.mode,
        dev=inode.dev,
        ino=inode.ino,
        size=inode.size,
        mtime_ns=inode.mtime_ns,
        uid=inode.uid,
        gid=inode.gid,
    )


StatKey = bytes  # = inode type + hash
# mode, dev, ino, size, mtime
FileKey = tuple[int, int, int, int, int]
# tuple[argno, path]
ArgPath = tuple[int, bytes]
FileInfo = _c.defaultdict[FileKey, list[ArgPath]]
# (dev, ino) | unique int
InodeKey = tuple[int, int] | int
InodeInfo = tuple[Inode, list[ArgPath]]
# tuple[sha256, inodes]
DuplicateGroup = tuple[bytes, list[InodeInfo]]


def iter_duplicate_group1(
    cargs: _t.Any, min_paths: int, min_inodes: int, old_sha256: bytes, candidates: FileInfo
) -> _t.Iterator[DuplicateGroup]:
    # for numbering inodes with no `st_ino`
    unique: int = 0
    # any issues?
    broken = False

    # split given `candidates` into separate inodes

    inodes: dict[InodeKey, InodeInfo] = {}
    key: InodeKey

    for (old_dev, old_ino, old_mode, old_size, old_mtime_ns), argpaths in candidates.items():
        if old_ino != 0:
            # dev, ino are pecified, use them as-is
            key = (old_dev, old_ino)
            try:
                pinode, pargpaths = inodes[key]
            except KeyError:
                inode = Inode(old_dev, old_ino, old_mode, old_size, old_mtime_ns)
                inodes[key] = inode, argpaths
            else:
                for argpath in argpaths:
                    pargpaths.append(argpath)
                if (
                    pinode.mode != old_mode
                    or pinode.size != old_size
                    or pinode.mtime_ns != old_mtime_ns
                ):
                    # different `DATABASE` records disagree
                    broken = True
            continue

        # no inode number is specified, `stat` and check each given path
        for argpath in argpaths:
            argno, fpath = argpath
            try:
                fstat = _os.lstat(fpath)
            except OSError as exc:
                error(*on_os_error(failed_msg, "stat", exc))
                broken = True
                continue

            if not equal_stat(wrong_field_error, fpath, fstat, mode=old_mode, dev=old_dev, size=old_size, mtime_ns=old_mtime_ns):  # fmt: skip
                # does not match the `DATABASE` record
                broken = True
                continue

            old_ino = fstat.st_ino
            if old_ino != 0:
                # got an actual inode number
                #
                # NB: this will usually work fine on dynamic-inode
                # filesystems, since the above `lstat` and following `link`
                # or `unlink`s will be close enough for those inodes to be
                # cached. if not, `deduplicate` will simply fail and do
                # nothing
                key = (old_dev, old_ino)
            else:
                # the filesystem does not support inodes, generate a fake id instead
                key = unique
                unique += 1

            try:
                pinode, pargpaths = inodes[key]
            except KeyError:
                inode = Inode(old_dev, old_ino, old_mode, old_size, old_mtime_ns, fstat.st_uid, fstat.st_gid)  # fmt: skip
                inodes[key] = inode, [argpath]
            else:
                pargpaths.append(argpath)
                if not equal_stat_inode(None, fpath, fstat, pinode):
                    # (sameInode)
                    # different paths supposedly pointing to the same inode disagree
                    broken = True

    # group inodes into candidate duplicate groups, from already known data

    preres: _c.defaultdict[tuple[int, int, int, int, int], list[InodeInfo]] = _c.defaultdict(list)
    # all unique arpaths
    unique_argpaths = []

    match_size: bool = cargs.match_size
    match_argno: bool = cargs.match_argno
    match_device: bool = cargs.match_device
    match_perms: bool = cargs.match_perms
    match_mtime: bool = cargs.match_mtime

    for inode, argpaths in inodes.values():
        # smallest argno that includes this inode
        min_argno = argpaths[0][0]
        # filter out duplicated paths and compute `min_argno`
        first_seen: dict[bytes, int] = {}
        clean_argpaths = []
        for argpath in argpaths:
            argno, fpath = argpath
            try:
                first_argno = first_seen[fpath]
            except KeyError:
                first_seen[fpath] = argno
                clean_argpaths.append(argpath)
                unique_argpaths.append(argpath)
                min_argno = min(min_argno, argno)
            else:
                warning(
                    gettext(
                        "ignored a repeated path: `INPUT`s #%d (`%s`) and #%d (`%s`) both contain path `%s`"
                    ),
                    first_argno,
                    str_path(cargs.inputs[first_argno]),
                    argno,
                    str_path(cargs.inputs[argno]),
                    str_path(fpath),
                )

        grpkey = (
            inode.size if match_size else 0,
            min_argno if match_argno else 0,
            inode.dev if match_device else 0,
            _stat.S_IMODE(inode.mode) if match_perms else 0,
            inode.mtime_ns if match_mtime else 0,
        )
        preres[grpkey].append((inode, clean_argpaths))

    # group more precisely by using database and filesystem data, when required

    res: _c.defaultdict[_t.Any, list[InodeInfo]] = _c.defaultdict(list)

    match_uid: bool = cargs.match_uid
    match_gid: bool = cargs.match_gid
    match_ids = match_uid or match_gid
    match_xattrs: bool = cargs.match_xattrs

    for grpkey, group in preres.items():
        if (
            len(group) < min_inodes
            or sum(map(lambda inode_info: len(inode_info[1]), group)) < min_paths
        ):
            # this group is boring, ignore it
            continue

        if len(group) == 1 or not (match_ids or match_xattrs):
            # no need to `stat` anything
            res[grpkey] = group
            continue

        # some metadata might be missing
        for inode_info in group:
            inode, argpaths = inode_info

            if match_ids and (inode.uid is None or inode.gid is None):
                # NB: the second part of the condition above ensures that
                # this block will be skipped if (sameInode) was run, because
                # double-checking is useless here
                for _argno, fpath in argpaths:
                    try:
                        fstat = _os.lstat(fpath)
                    except OSError as exc:
                        error(*on_os_error(failed_msg, "stat", exc))
                        broken = True
                        continue

                    if not equal_stat_inode(wrong_field_error, fpath, fstat, inode):
                        broken = True

                    inode.uid = fstat.st_uid
                    inode.gid = fstat.st_gid

            if match_xattrs:
                for _argno, fpath in argpaths:
                    try:
                        xattrs = get_xattrs(fpath)
                    except OSError as exc:
                        error(*on_os_error(failed_msg, "listxattr/getxattr", exc))
                        broken = True
                        continue

                    if not equal_xattrs(wrong_field_error, fpath, xattrs, xattrs=inode.xattrs):
                        broken = True

                    inode.xattrs = xattrs

            grpkey2 = (
                grpkey,
                inode.uid if match_uid else 0,
                inode.gid if match_gid else 0,
                inode.xattrs if match_xattrs else None,
            )
            res[grpkey2].append(inode_info)

    del preres

    if broken:
        error(
            "aborting candidate group: disagreement in metadata: re-run `index` on the following paths to fix this:\n%s",
            "\n".join(map(lambda x: str_path(x[1]), unique_argpaths)),
        )
        return

    if len(res) == 0:
        return

    # sort elements in resulting groups and then yield them

    order_paths: str = cargs.order_paths
    order_inodes: str = cargs.order_inodes

    minmax: _t.Callable[[_t.Iterable[AType]], AType] = min  # type: ignore
    reverse = cargs.reverse
    if reverse:
        minmax = max  # type: ignore

    for group in res.values():
        # pre-sort everything by abspath
        for inode_info in group:
            inode_info[1].sort(key=lambda x: x[1], reverse=cargs.reverse)
        group.sort(key=lambda inode_info: inode_info[1][0][1], reverse=cargs.reverse)

        if order_paths == "argno":
            for inode_info in group:
                inode_info[1].sort(key=lambda x: x[0], reverse=cargs.reverse)
        elif order_paths == "abspath":
            pass
        elif order_paths == "dirname":
            for inode_info in group:
                inode_info[1].sort(key=lambda x: _op.dirname(x[1]), reverse=cargs.reverse)
        elif order_paths == "basename":
            for inode_info in group:
                inode_info[1].sort(key=lambda x: _op.basename(x[1]), reverse=cargs.reverse)
        else:
            assert False

        if order_inodes == "argno":
            if order_paths == order_inodes:
                group.sort(key=lambda inode_info: inode_info[1][0][0], reverse=cargs.reverse)
            else:
                group.sort(
                    key=lambda inode_info: minmax(map(lambda x: x[0], inode_info[1])),
                    reverse=cargs.reverse,
                )
        elif order_inodes == "mtime":
            group.sort(key=lambda inode_info: inode_info[0].mtime_ns, reverse=cargs.reverse)
        elif order_inodes == "abspath":
            if order_paths == order_inodes:
                pass
            else:
                group.sort(
                    key=lambda inode_info: minmax(map(lambda x: x[1], inode_info[1])),
                    reverse=cargs.reverse,
                )
        elif order_inodes == "dirname":
            if order_paths == order_inodes:
                group.sort(
                    key=lambda inode_info: _op.dirname(inode_info[1][0][1]), reverse=cargs.reverse
                )
            else:
                group.sort(
                    key=lambda inode_info: minmax(map(lambda x: _op.dirname(x[1]), inode_info[1])),
                    reverse=cargs.reverse,
                )
        elif order_inodes == "basename":
            if order_paths == order_inodes:
                group.sort(
                    key=lambda inode_info: _op.basename(inode_info[1][0][1]),
                    reverse=cargs.reverse,
                )
            else:
                group.sort(
                    key=lambda inode_info: minmax(map(lambda x: _op.basename(x[1]), inode_info[1])),
                    reverse=cargs.reverse,
                )
        else:
            assert False

        yield old_sha256, group


def iter_duplicate_groups(
    cargs: _t.Any,
    cur: Cursor,
    min_paths: int,
    min_inodes: int,
) -> _t.Iterator[DuplicateGroup]:
    """For each sha256 it gives fsize, and a map from grouped paths matching this key."""

    min_uses = min(min_paths, min_inodes)
    match_device: bool = cargs.match_device

    # count how many times each statkey appears in the DATABASE

    shards_from, shards_to, shards_total = cargs.shard
    for shard in range(shards_from - 1, shards_to):
        sharding = shards_total > 1
        shard_prefix = gettext("Shard %d/%d:") % (shard + 1, shards_total) + " " if sharding else ""

        info(
            shard_prefix
            + "Scanning `DATABASE` for potential duplicates matching given `INPUT`s and criteria..."
        )

        paths_total = 0
        seen_: _c.defaultdict[StatKey, int] = _c.defaultdict(lambda: 0)

        for sql_where, sql_params in iter_input_queries(cargs):
            raise_first_delayed_signal()

            cur.execute("SELECT sha256, ino_status FROM files WHERE " + sql_where, sql_params)
            for old_sha256, old_mode in cur:
                raise_first_delayed_signal()

                paths_total += 1

                if sharding and _unpack("i", old_sha256[:4])[0] % shards_total != shard:
                    continue

                statkey = fmode_to_type(old_mode).encode("ascii") + old_sha256
                seen_[statkey] = seen_[statkey] + 1

        # re-create, only keeping the ones that duplicate needed number of times
        #
        # this is done to save RAM when processing a ton of statkeys

        seen: dict[StatKey, int] = {}

        while seen_:
            statkey, statkey_seen = seen_.popitem()
            if statkey_seen >= min_uses:
                seen[statkey] = statkey_seen
        del seen_

        statkeys_total = len(seen)
        if statkeys_total == 0:
            # no duplicates
            return

        # walk the DATABASE again and generate duplicate groups

        info(shard_prefix + "Generating duplicates...")

        statkey_candidates: _c.defaultdict[StatKey, FileInfo] = _c.defaultdict(
            lambda: _c.defaultdict(list)
        )

        def forget(statkey: bytes) -> None:
            del statkey_candidates[statkey]
            del seen[statkey]

        paths_so_far = statkeys_so_far = 0

        def progress(fpath: bytes) -> None:
            info(
                shard_prefix + "Processing (%d%% %d/%d candidate groups, %d%% %d/%d paths) `%s`...",
                100 * statkeys_so_far // statkeys_total,
                statkeys_so_far,
                statkeys_total,
                100 * paths_so_far // paths_total,
                paths_so_far,
                paths_total,
                str_path(fpath),
            )

        for argno, (sql_where, sql_params) in enumerate(iter_input_queries(cargs)):
            raise_first_delayed_signal()

            cur.execute(
                "SELECT path, sha256, size, original_mtime, ino_mtime, ino_status, ino_id FROM files WHERE "
                + sql_where,
                sql_params,
            )
            for (
                fpath,
                old_sha256,
                old_size,
                old_orig_mtime_ns,
                old_over_mtime_ns,
                old_mode,
                old_ino,
            ) in iter_fetchmany(cur):
                raise_first_delayed_signal()

                if paths_so_far % 100000 == 0:
                    progress(fpath)
                paths_so_far += 1

                statkey = fmode_to_type(old_mode).encode("ascii") + old_sha256
                try:
                    statkey_seen = seen[statkey]
                except KeyError:
                    # not duplicated, done, or errored
                    continue

                try:
                    old_dev = get_dev(fpath) if match_device else 0
                except NotADirectoryError:
                    error(
                        "aborting candidate group: path's `dirname` is not a directory: `%s`", fpath
                    )
                    forget(statkey)
                    continue

                old_mtime_ns = (
                    old_over_mtime_ns if old_over_mtime_ns is not None else old_orig_mtime_ns
                )

                filekey = (old_dev, old_ino, old_mode, old_size, old_mtime_ns)
                candidates = statkey_candidates[statkey]
                candidates[filekey].append((argno, fpath))

                statkey_seen -= 1
                if statkey_seen > 0:
                    # not the last use yet
                    seen[statkey] = statkey_seen
                    continue

                # this is the last use, `candidates` is now complete
                forget(statkey)

                yield from iter_duplicate_group1(
                    cargs, min_paths, min_inodes, old_sha256, candidates
                )

                statkeys_so_far += 1
                progress(fpath)

        for statkey in seen:
            raise RuntimeFailure("BUG: statkey `%s` was forgotten about", statkey.hex())


def cmd_find_duplicates(cargs: _t.Any, lhnd: ANSILogHandler) -> None:
    verbosity = cargs.verbosity
    spacing = cargs.spacing
    stdout_path = get_stdout_path(cargs)

    # batch outputs so that `keep_progress` would produce less flicker
    bio = _io.BytesIO()
    wio = TIOWrappedWriter(bio, encoding=stdout.encoding, eol=stdout.eol, ansi=stdout.ansi)

    con = DB(cargs.database)
    cur = con.cursor()

    for sha256, group in iter_duplicate_groups(cargs, cur, cargs.min_paths, cargs.min_inodes):
        raise_first_delayed_signal()

        bio.seek(0)
        bio.truncate(0)

        if verbosity > 1:
            wio.write_str_ln(f"# sha256 {sha256.hex()}", color=ANSIColor.MAGENTA)

        for inode, argpaths in group:
            if verbosity > 0:
                first_fpath = True
                for _argno, fpath in argpaths:
                    prefix = "__ " if first_fpath else "=> "
                    wio.write_str(prefix)
                    if verbosity > 2:
                        wio.write_str(f"{inode.dev},{inode.ino} ")
                    wio.write_ln(stdout_path(fpath))
                    first_fpath = False
            else:
                for _argno, fpath in argpaths:
                    wio.write_ln(stdout_path(fpath))

            if spacing > 1:
                wio.write_str_ln("")

        if spacing > 0:
            wio.write_str_ln("")

        with keep_progress(lhnd):
            stdout.write(bio.getvalue())


def cmd_deduplicate(cargs: _t.Any, lhnd: ANSILogHandler) -> None:
    verbosity = cargs.verbosity + 1
    spacing = cargs.spacing
    stdout_path = get_stdout_path(cargs)

    dry_run: bool = cargs.dry_run
    dry_prefix = gettext("dry-run: (not)") + " " if dry_run else ""
    paranoid = cargs.paranoid

    hardlink = True
    if cargs.how == "delete":
        hardlink = False

    min_inodes = cargs.min_inodes if cargs.min_inodes is not None else (2 if hardlink else 1)

    def say(prefix: str, inode: Inode, fpath: bytes, color: int = ANSIColor.GREEN) -> None:
        stdout.write_str(prefix, color=color)
        if verbosity > 2:
            stdout.write_str(f"{inode.dev},{inode.ino} ")
        stdout.write_ln(stdout_path(fpath))
        stdout.flush()

    sync: DeferredSync[bytes] | bool = False
    if cargs.sync:
        sync = DeferredSync(False)

    con = DB(cargs.database)
    cur = con.cursor()
    updcur = con.cursor()

    try:
        num_updates = 0

        for sha256, group in iter_duplicate_groups(cargs, cur, cargs.min_paths, min_inodes):
            raise_first_delayed_signal()

            if verbosity > -1:
                lhnd.flush()

            if verbosity > 1:
                stdout.write_str_ln(f"# sha256 {sha256.hex()}", color=ANSIColor.MAGENTA)

            src = group[0]
            src_inode = src[0]
            src_fpath = src[1][0][1]
            src_broken = False

            first_inode = True
            for inode, argpaths in group:
                known_equal = False

                # sanity check `iter_duplicate_groups`
                assert _stat.S_IFMT(src_inode.mode) == _stat.S_IFMT(inode.mode)

                first_fpath = True
                for _argno, fpath in argpaths:
                    if src_broken:
                        say("fail ", inode, fpath, color=ANSIColor.RED)
                    elif first_inode and first_fpath:
                        if verbosity > -1:
                            say("__ ", inode, fpath)
                    elif first_inode and hardlink:
                        if verbosity > 0:
                            say("=> ", inode, fpath)
                    else:
                        # not src_broken and
                        # not first_inode or (first_inode and not first_fpath and not hardlink)

                        # check that file content data matches `src_fpath`
                        #
                        # when `not paranoid` only check once per inode
                        try:
                            if (paranoid or not known_equal) and (
                                _stat.S_ISREG(src_inode.mode)
                                and not same_file_data(src_fpath, fpath)
                                or _stat.S_ISLNK(src_inode.mode)
                                and not same_symlink_data(src_fpath, fpath)
                            ):
                                error(
                                    gettext(
                                        "skipping: collision: sha256 is `%s` while\nfile   `%s`\nis not `%s`"
                                    ),
                                    sha256.hex(),
                                    str_path(src_fpath),
                                    str_path(fpath),
                                )
                                say("fail ", inode, fpath, color=ANSIColor.RED)
                                continue
                        except OSError as exc:
                            error(*on_os_error(failed_msg, "same_data", exc))
                            if exc.filename == fpath:
                                error(
                                    "skipping deduplication: broken target: `%s`", str_path(fpath)
                                )
                            else:
                                error(
                                    "aborting duplicate group: broken source: `%s`",
                                    str_path(src_fpath),
                                )
                                src_broken = True
                            say("fail ", inode, fpath, color=ANSIColor.RED)
                            continue

                        # ... and remember that it is equal
                        known_equal = True

                        # check that source is still the same
                        try:
                            src_fstat = _os.lstat(src_fpath)
                        except OSError as exc:
                            error(*on_os_error(failed_msg, "stat", exc))
                            error(
                                "aborting duplicate group: broken source: `%s`",
                                str_path(src_fpath),
                            )
                            src_broken = True
                            say("fail ", inode, fpath, color=ANSIColor.RED)
                            continue

                        if not equal_stat_inode(wrong_field_error, src_fpath, src_fstat, src_inode):
                            error(
                                "aborting duplicate group: source changed unexpectedly: `%s`",
                                str_path(src_fpath),
                            )
                            src_broken = True
                            say("fail ", inode, fpath, color=ANSIColor.RED)
                            continue

                        # check the target it still the same
                        try:
                            fstat = _os.lstat(fpath)
                        except OSError as exc:
                            error(*on_os_error(failed_msg, "stat", exc))
                            error("skipping deduplication: broken target: `%s`", str_path(fpath))
                            say("fail ", inode, fpath, color=ANSIColor.RED)
                            continue

                        if not equal_stat_inode(wrong_field_error, fpath, fstat, inode):
                            error(
                                "skipping deduplication: target changed unexpectedly: `%s`",
                                str_path(fpath),
                            )
                            say("fail ", inode, fpath, color=ANSIColor.RED)
                            continue

                        if src_fstat.st_dev == fstat.st_dev and src_fstat.st_ino == fstat.st_ino:
                            # if they point to the exact same inode
                            #
                            # they must be grouped together under `first_inode`
                            assert first_inode or fstat.st_ino == 0

                            # TODO: handle `st_ino == 0` filesystems somehow other than rejecting
                            # deduplications there
                            if src_fstat.st_nlink <= 1 or fstat.st_nlink <= 1:
                                # `src_fpath` and `fpath` point to the same inode on disk and that's
                                # the only copy, the `or` and `<= 1` are just in case
                                #
                                # this happens, for instance, when deduplicating several `mount --bind`
                                # clones of the same directory
                                error(
                                    "skipping deduplication: source and target are different paths for the same inode with `nlink == 1`:\n`%s`\n`%s`\nis this a `mount --bind`?",
                                    str_path(src_fpath),
                                    str_path(fpath),
                                )
                                say("fail ", inode, fpath, color=ANSIColor.RED)
                                continue

                        try:
                            if not dry_run:
                                if hardlink:
                                    atomic_link(src_fpath, fpath, True, follow_symlinks=False, makedirs=False, sync=sync)  # fmt: skip
                                else:
                                    atomic_unlink(fpath, sync=sync)
                        except OSError as exc:
                            syscall = "link" if hardlink else "unlink"
                            error(*on_os_error(failed_msg, syscall, exc))
                            say("fail ", inode, fpath, color=ANSIColor.RED)
                            continue

                        if verbosity > -1:
                            prefix = dry_prefix + ("ln " if hardlink else "rm ")
                            say(prefix, inode, fpath)

                        if dry_run:
                            continue

                        if hardlink:
                            old_orig_mtime_ns = updcur.execute(
                                "SELECT original_mtime FROM files WHERE path = ?",
                                (fpath,),
                            ).fetchone()[0]

                            src_mtime_ns = src_inode.mtime_ns
                            over_mtime_ns = (
                                src_mtime_ns if old_orig_mtime_ns != src_mtime_ns else None
                            )

                            updcur.execute(
                                "UPDATE files SET ino_mtime = ?, ino_status = ?, ino_id = ? WHERE path = ?",
                                (
                                    over_mtime_ns,
                                    src_inode.mode,
                                    src_inode.ino,
                                    fpath,
                                ),
                            )
                        else:
                            updcur.execute("DELETE FROM files WHERE path = ?", (fpath,))
                        num_updates += 1
                    first_fpath = False
                first_inode = False

                if verbosity > -1 and spacing > 1:
                    stdout.write_str_ln("")

            if verbosity > -1:
                if spacing > 0:
                    stdout.write_str_ln("")
                stdout.flush()

            if num_updates > 1024:
                if isinstance(sync, DeferredSync):
                    sync.flush()
                con.commit()
                num_updates = 0

        if isinstance(sync, DeferredSync):
            sync.flush()
        con.commit()
    except (GentleSignalInterrupt, BrokenPipeError):
        error("Deduplication was interrupted.")
        info("Commiting partial results...")

        if isinstance(sync, DeferredSync):
            sync.flush()
        con.commit()
    except BaseException:
        if isinstance(sync, DeferredSync):
            sync.clear()
        con.rollback()
        raise

    info("Done. Syncing `DATABASE`...")
    con.close()


def cmd_verify(cargs: _t.Any, lhnd: ANSILogHandler) -> None:
    hash_len = cargs.hash_len

    verbosity = cargs.verbosity
    stdout_path = get_stdout_path(cargs)

    checksum = cargs.checksum

    match_perms: bool = cargs.match_perms
    match_mtime: bool = cargs.match_mtime

    wrong_field_perms = wrong_field_error if match_perms else wrong_field_warning
    wrong_field_mtime = wrong_field_error if match_mtime else wrong_field_warning

    def say(what: str, fpath: bytes, color: int = ANSIColor.GREEN) -> None:
        lhnd.flush()
        stdout.write_str(what, color=color)
        stdout.write_str(" ")
        stdout.write_ln(stdout_path(fpath))
        stdout.flush()

    con = DB(cargs.database)
    cur = con.cursor()

    paths_so_far = 0
    report_every = 100 if checksum else 100000

    for sql_where, sql_params in iter_input_queries(cargs):
        cur.execute(
            "SELECT path, sha256, size, original_mtime, ino_mtime, ino_status, ino_id FROM files WHERE "
            + sql_where,
            sql_params,
        )
        for (
            fpath,
            old_sha256,
            old_size,
            old_orig_mtime_ns,
            old_over_mtime_ns,
            old_mode,
            _old_ino,
        ) in iter_fetchmany(cur):
            raise_first_delayed_signal()

            if paths_so_far % report_every:
                info("Processing `%s`...", str_path(fpath))
            paths_so_far += 1

            had_problems = False
            must_checksum = checksum

            try:
                fstat = _os.lstat(fpath)
            except OSError as exc:
                error(*on_os_error(failed_msg, "stat", exc))
                had_problems = True

            if not had_problems:
                if not equal_stat(wrong_field_error, fpath, fstat, type=old_mode, size=old_size):
                    had_problems = True
                    must_checksum = True

                old_mtime_ns = (
                    old_over_mtime_ns if old_over_mtime_ns is not None else old_orig_mtime_ns
                )
                if not equal_stat(wrong_field_mtime, fpath, fstat, mtime_ns=old_mtime_ns):
                    had_problems = had_problems or match_mtime
                    must_checksum = True

                if must_checksum:
                    try:
                        with yes_signals():
                            sha256 = get_sha256(fpath, fstat, hash_len)
                    except OSError as exc:
                        error(*on_os_error(failed_msg, "hash", exc))
                    else:
                        if old_sha256 != sha256:
                            wrong_field_error(
                                "sha256", old_sha256.hex(), sha256.hex(), str_path(fpath)
                            )
                            had_problems = True

                if not equal_stat(wrong_field_perms, fpath, fstat, type=None, mode=old_mode):
                    had_problems = had_problems or match_perms

            if had_problems:
                say("fail", fpath, color=ANSIColor.RED)
            elif verbosity > 0:
                say("ok", fpath)

    info("Done.")


def cmd_upgrade(cargs: _t.Any, _lhnd: ANSILogHandler) -> None:
    db = DB(cargs.database, backup_before_upgrades=True)
    db.close()
    info("Done.")


def add_doc(fmt: argparse.BetterHelpFormatter) -> None:
    _: _t.Callable[[str], str] = gettext

    # fmt: off
    fmt.add_text(_("# Examples"))

    fmt.start_section(_("Index all files in `/backup`"))
    fmt.add_code(f"{__prog__} index /backup")
    fmt.end_section()

    fmt.start_section(_("Search paths of files present in `/backup`"))
    fmt.add_code(f"{__prog__} find /backup | grep something")
    fmt.end_section()

    fmt.start_section(_("List all duplicated files in `/backup`, i.e. list all files in `/backup` that have multiple on-disk copies with same contents but using different inodes"))
    fmt.add_code(f"{__prog__} find-dupes /backup | tee dupes.txt")
    fmt.end_section()

    fmt.start_section(_("Same as above, but also include groups consisting solely of hardlinks to the same inode"))
    fmt.add_code(f"{__prog__} find-dupes --min-inodes 1 /backup | tee dupes.txt")
    fmt.end_section()

    fmt.start_section(_("Produce exactly the same duplicate file groups as those the following `deduplicate` would use by default"))
    fmt.add_code(f"{__prog__} find-dupes --match-meta /backup | tee dupes.txt")
    fmt.end_section()

    fmt.start_section(_("Deduplicate `/backup` by replacing files that have exactly the same metadata and contents (but with any `mtime`) with hardlinks to a file with the earliest known `mtime` in each such group"))
    fmt.add_code(f"{__prog__} deduplicate /backup")
    fmt.end_section()

    fmt.start_section(_("Deduplicate `/backup` by replacing same-content files larger than 1 KiB with hardlinks to a file with the latest `mtime` in each such group"))
    fmt.add_code(f"{__prog__} deduplicate --size-geq 1024 --reverse --ignore-meta /backup")
    fmt.add_text(_("This plays well with directories produced by `rsync --link-dest` and `rsnapshot`."))
    fmt.end_section()

    fmt.start_section(_("Similarly, but for each duplicate file group use a file with the largest absolute path (in lexicographic order) as the source for all generated hardlinks"))
    fmt.add_code(f"{__prog__} deduplicate --size-geq 1024 --ignore-meta --reverse --order-inodes abspath /backup")
    fmt.end_section()

    fmt.start_section(_("When you have enough indexed files that a run of `find-duplicates` or `deduplicate` stops fitting into RAM, you can process your database piecemeal by sharding by `SHA256` hash digests"))
    fmt.add_code(f"""# {_("shard the database into 4 pieces and then process each piece separately")}
{__prog__} find-dupes --shard 4 /backup
{__prog__} deduplicate --shard 4 /backup

# {_("assuming the previous command was interrupted in the middle, continue from shard 2 of 4")}
{__prog__} deduplicate --shard 2/4 /backup

# {_("shard the database into 4 pieces, but only process the first one of them")}
{__prog__} deduplicate --shard 1/1/4 /backup

# {_("uncertain amounts of time later...")}

# {_("process pieces 2 and 3")}
{__prog__} deduplicate --shard 2/3/4 /backup

# {_("uncertain amounts of time later...")}

# {_("process piece 4")}
{__prog__} deduplicate --shard 4/4 /backup
""")
    fmt.add_text(_("With `--shard SHARDS` set, `hoardy` takes about `1/SHARDS` amount of RAM, but produces exactly the same result as if you had enough RAM to run it with the default `--shard 1`, except it prints/deduplicates duplicate file groups in pseudo-randomly different order and trades RAM usage for longer total run time."))
    fmt.end_section()

    fmt.start_section(_("Alternatively, you can shard the database manually with filters"))
    fmt.add_code(f"""# {_("deduplicate files larger than 100 MiB")}
{__prog__} deduplicate --size-geq 104857600 /backup
# {_("deduplicate files between 1 and 100 MiB")}
{__prog__} deduplicate --size-geq 1048576 --size-leq 104857600 /backup
# {_("deduplicate files between 16 bytes and 1 MiB")}
{__prog__} deduplicate --size-geq 16 --size-leq 1048576 /backup

# {_("deduplicate about half of the files")}
{__prog__} deduplicate --sha256-leq 7f /backup
# {_("deduplicate the other half")}
{__prog__} deduplicate --sha256-geq 80 /backup
""")
    fmt.add_text(_("The `--shard` option does something very similar to the latter example."))
    fmt.end_section()
    # fmt: on


def make_argparser(real: bool) -> _t.Any:
    _: _t.Callable[[str], str] = gettext

    parser = argparse.BetterArgumentParser(
        prog=__prog__,
        description=_("A thingy for hoarding digital assets."),
        additional_sections=[add_doc],
        add_version=True,
        add_help=True,
    )

    def no_cmd(_cargs: _t.Any) -> None:
        parser.print_help(_sys.stderr)
        _sys.exit(2)

    parser.set_defaults(func=no_cmd)

    def_def = _("; default")

    def def_tty(what: str) -> str:
        return _("; default when `%s` is connected to a TTY") % (what,)

    def def_color(what: str) -> str:
        return _(
            "; default when `%s` is connected to a TTY and environment variables do not set `NO_COLOR=1`"
        ) % (what,)

    def add_input(cmd: _t.Any) -> None:
        cmd.add_argument(
            "inputs",
            metavar="INPUT",
            nargs="*",
            type=str,
            help=_("input files and/or directories to process"),
        )
        cmd.add_argument(
            "--stdin0",
            action="store_true",
            help=_(
                "read zero-terminated `INPUT`s from stdin, these will be processed after all `INPUTS`s specified as command-line arguments"
            ),
        )

    def add_output(cmd: _t.Any, agrp: _t.Any | None = None, add_spaced: bool = False) -> None:
        if agrp is None:
            agrp = cmd.add_argument_group("output")

        grp = agrp.add_mutually_exclusive_group()
        grp.add_argument(
            "-v",
            "--verbose",
            dest="verbosity",
            action="count",
            default=0,
            help=_(
                "increase output verbosity; can be specified multiple times for progressively more verbose output"
            ),
        )
        grp.add_argument(
            "-q",
            "--quiet",
            "--no-verbose",
            dest="unverbosity",
            action="count",
            default=0,
            help=_(
                "decrease output verbosity; can be specified multiple times for progressively less verbose output"
            ),
        )

        grp = agrp.add_mutually_exclusive_group()
        grp.add_argument(
            "-l",
            "--lf-terminated",
            dest="terminator",
            action="store_const",
            const="\n",
            help=_("print output lines terminated with `\\n` (LF) newline characters") + def_def,
        )
        grp.add_argument(
            "-z",
            "--zero-terminated",
            "--print0",
            dest="terminator",
            action="store_const",
            const=b"\0",
            help=_(
                "print output lines terminated with `\\0` (NUL) bytes, implies `--no-color` and zero verbosity"
            ),
        )
        cmd.set_defaults(terminator="\n")

        if not add_spaced:
            return

        grp = agrp.add_mutually_exclusive_group()
        grp.add_argument(
            "--spaced",
            dest="spacing",
            action="count",
            default=1,
            help=_(
                "print more empty lines between different parts of the output; can be specified multiples"
            ),
        )
        grp.add_argument(
            "--no-spaced",
            dest="unspacing",
            action="count",
            default=0,
            help=_(
                "print less empty lines between different parts of the output; can be specified multiples"
            ),
        )

    def add_common(cmd: _t.Any, add_spaced: bool = False) -> None:
        cmd.add_argument(
            "-d",
            "--database",
            type=str,
            default=None,
            help=_("database file to use; default: `%s` on POSIX, `%s` on Windows")
            % (DB_POSIX, DB_WINDOWS.replace("%", "%%")),
        )
        # for hash-collision tests
        cmd.add_argument(
            "--debug-hash-len",
            dest="hash_len",
            type=int,
            default=None,
            help=SUPPRESS,
        )

        cmd.add_argument(
            "--dry-run",
            action="store_true",
            help=_("perform a trial run without actually performing any changes"),
        )

        agrp = cmd.add_argument_group("output defaults")
        grp = agrp.add_mutually_exclusive_group()
        grp.add_argument(
            "--color",
            dest="color",
            action="store_true",
            help=_("set defaults to `--color-stdout` and `--color-stderr`"),
        )
        grp.add_argument(
            "--no-color",
            dest="color",
            action="store_false",
            help=_("set defaults to `--no-color-stdout` and `--no-color-stderr`"),
        )
        cmd.set_defaults(color=None)

        agrp = cmd.add_argument_group("output")
        grp = agrp.add_mutually_exclusive_group()
        grp.add_argument(
            "--color-stdout",
            dest="color_stdout",
            action="store_true",
            help=_("color `stdout` output using ANSI escape sequences") + def_color("stdout"),
        )
        grp.add_argument(
            "--no-color-stdout",
            dest="color_stdout",
            action="store_false",
            help=_("produce plain-text `stdout` output without any ANSI escape sequences"),
        )
        cmd.set_defaults(color_stdout=None)

        grp = agrp.add_mutually_exclusive_group()
        grp.add_argument(
            "--color-stderr",
            dest="color_stderr",
            action="store_true",
            help=_("color `stderr` output using ANSI escape sequences") + def_color("stderr"),
        )
        grp.add_argument(
            "--no-color-stderr",
            dest="color_stderr",
            action="store_false",
            help=_("produce plain-text `stderr` output without any ANSI escape sequences"),
        )
        cmd.set_defaults(color_stderr=None)

        grp = agrp.add_mutually_exclusive_group()
        grp.add_argument(
            "--progress",
            dest="progress",
            action="store_true",
            help=_("report progress to `stderr`") + def_tty("stderr"),
        )
        grp.add_argument(
            "--no-progress",
            dest="progress",
            action="store_false",
            help=_("do not report progress"),
        )
        cmd.set_defaults(progress=None)

        if real:
            add_input(cmd)
            add_output(cmd, agrp, add_spaced)

    def add_filter(cmd: _t.Any) -> None:
        agrp = cmd.add_argument_group("filters")
        agrp.add_argument(
            "--size-leq", metavar="INT", type=int, default=None, help=_("`size <= value`")
        )
        agrp.add_argument(
            "--size-geq", metavar="INT", type=int, default=1, help=_("`size >= value`")
        )
        agrp.add_argument(
            "--sha256-leq",
            metavar="HEX",
            type=str,
            default=None,
            help=_("`sha256 <= from_hex(value)`"),
        )
        agrp.add_argument(
            "--sha256-geq",
            metavar="HEX",
            type=str,
            default=None,
            help=_("`sha256 >= from_hex(value)`"),
        )
        # cmd.add_argument("--exclude-rw", action="store_true", help=_("TODO"))

    def add_content(cmd: _t.Any, verify: bool, strict: bool) -> None:
        if verify:
            agrp = cmd.add_argument_group("content verification")
        else:
            agrp = cmd.add_argument_group("content hashing")

        def_strict = def_def if strict else ""
        def_lax = def_def if not strict else ""

        grp = agrp.add_mutually_exclusive_group()
        grp.add_argument(
            "--checksum",
            dest="checksum",
            action="store_true",
            help=_("verify all file hashes" if verify else "re-hash everything")
            + _(
                "; i.e., assume that some files could have changed contents without changing `type`, `size`, or `mtime`"
            )
            + def_strict,
        )
        grp.add_argument(
            "--no-checksum",
            dest="checksum",
            action="store_false",
            help=_("skip hashing if file `type`, `size`, and `mtime` match `DATABASE` record")
            + def_lax,
        )
        cmd.set_defaults(checksum=strict)

    def add_match(cmd: _t.Any, verify: bool, strict: bool) -> None:
        if verify:
            defgrp = cmd.add_argument_group("verification defaults")
            agrp = cmd.add_argument_group(
                "verification; consider a file to be `ok` when it and its `DATABASE` record..."
            )
        else:
            defgrp = cmd.add_argument_group("duplicate file grouping defaults")
            agrp = cmd.add_argument_group(
                "duplicate file grouping; consider same-content files to be duplicates when they..."
            )

        def_strict = def_def if strict else ""
        def_lax = def_def if not strict else ""

        grp = defgrp.add_mutually_exclusive_group()
        grp.add_argument(
            "--match-meta",
            dest="match_meta",
            action="store_true",
            help=(
                _("set defaults to `--match-permissions`")
                if verify
                else _(
                    "set defaults to `--match-device --match-permissions --match-owner --match-group`"
                )
            )
            + def_strict,
        )
        grp.add_argument(
            "--ignore-meta",
            dest="match_meta",
            action="store_false",
            help=(
                _("set defaults to `--ignore-permissions`")
                if verify
                else _(
                    "set defaults to `--ignore-device --ignore-permissions --ignore-owner --ignore-group`"
                )
            )
            + def_lax,
        )
        cmd.set_defaults(match_meta=strict)

        grp = defgrp.add_mutually_exclusive_group()
        grp.add_argument(
            "--match-extras",
            dest="match_extras",
            action="store_true",
            help=_("set defaults to `--match-xattrs`") + def_strict,
        )
        grp.add_argument(
            "--ignore-extras",
            dest="match_extras",
            action="store_false",
            help=_("set defaults to `--ignore-xattrs`") + def_lax,
        )
        cmd.set_defaults(match_extras=strict)

        grp = defgrp.add_mutually_exclusive_group()
        grp.add_argument(
            "--match-times",
            dest="match_times",
            action="store_true",
            help=_("set defaults to `--match-last-modified`"),
        )
        grp.add_argument(
            "--ignore-times",
            dest="match_times",
            action="store_false",
            help=_("set defaults to `--ignore-last-modified`") + def_def,
        )
        cmd.set_defaults(match_times=False)

        grp = agrp.add_mutually_exclusive_group()
        grp.add_argument(
            "--match-size",
            dest="match_size",
            action="store_true",
            help=_("... have the same file size") + def_def,
        )
        grp.add_argument(
            "--ignore-size",
            dest="match_size",
            action="store_false",
            help=_(
                "... regardless of file size; only useful for debugging or discovering hash collisions"
            ),
        )
        cmd.set_defaults(match_size=True)

        if not verify:
            grp = agrp.add_mutually_exclusive_group()
            grp.add_argument(
                "--match-argno",
                dest="match_argno",
                action="store_true",
                help=_(
                    "... were produced by recursion from the same command-line argument (which is checked by comparing `INPUT` indexes in `argv`, if the path is produced by several different arguments, the smallest one is taken)"
                ),
            )
            grp.add_argument(
                "--ignore-argno",
                dest="match_argno",
                action="store_false",
                help=_("... regardless of which `INPUT` they came from") + def_def,
            )
            cmd.set_defaults(match_argno=False)

            grp = agrp.add_mutually_exclusive_group()
            grp.add_argument(
                "--match-device",
                dest="match_device",
                action="store_true",
                help=_("... come from the same device/mountpoint/drive") + def_strict,
            )
            grp.add_argument(
                "--ignore-device",
                dest="match_device",
                action="store_false",
                help=_("... regardless of devices/mountpoints/drives") + def_lax,
            )
            cmd.set_defaults(match_device=None)

        grp = agrp.add_mutually_exclusive_group()
        grp.add_argument(
            "--match-perms",
            "--match-permissions",
            dest="match_perms",
            action="store_true",
            help=_("... have the same file modes/permissions") + def_strict,
        )
        grp.add_argument(
            "--ignore-perms",
            "--ignore-permissions",
            dest="match_perms",
            action="store_false",
            help=_("... regardless of file modes/permissions") + def_lax,
        )
        cmd.set_defaults(match_perms=None)

        if not verify:
            grp = agrp.add_mutually_exclusive_group()
            grp.add_argument(
                "--match-owner",
                "--match-uid",
                dest="match_uid",
                action="store_true",
                help=_("... have the same owner id") + def_strict,
            )
            grp.add_argument(
                "--ignore-owner",
                "--ignore-uid",
                dest="match_uid",
                action="store_false",
                help=_("... regardless of owner id") + def_lax,
            )
            cmd.set_defaults(match_uid=None)

            grp = agrp.add_mutually_exclusive_group()
            grp.add_argument(
                "--match-group",
                "--match-gid",
                dest="match_gid",
                action="store_true",
                help=_("... have the same group id") + def_strict,
            )
            grp.add_argument(
                "--ignore-group",
                "--ignore-gid",
                dest="match_gid",
                action="store_false",
                help=_("... regardless of group id") + def_lax,
            )
            cmd.set_defaults(match_gid=None)

        grp = agrp.add_mutually_exclusive_group()
        grp.add_argument(
            "--match-last-modified",
            "--match-mtime",
            dest="match_mtime",
            action="store_true",
            help=_("... have the same `mtime`"),
        )
        grp.add_argument(
            "--ignore-last-modified",
            "--ignore-mtime",
            dest="match_mtime",
            action="store_false",
            help=_("... regardless of `mtime`") + def_def,
        )
        cmd.set_defaults(match_mtime=None)

        if not verify:
            grp = agrp.add_mutually_exclusive_group()
            grp.add_argument(
                "--match-xattrs",
                dest="match_xattrs",
                action="store_true",
                help=_("... have the same extended file attributes") + def_strict,
            )
            grp.add_argument(
                "--ignore-xattrs",
                dest="match_xattrs",
                action="store_false",
                help=_("... regardless of extended file attributes") + def_lax,
            )
            cmd.set_defaults(match_perms=None)

    def parse_shard(x: str) -> tuple[int, int, int]:
        def fail() -> None:
            raise CatastrophicFailure(
                "can't parse `--shard` argument, expected `<int>/<int>/<int>`, `<int>/<int>`, or `<int>`, got: `%s`",
                x,
            )

        parts = x.split("/")
        num_parts = len(parts)
        if num_parts < 1 or num_parts > 3:
            fail()
        try:
            ints = list(map(int, parts))
        except ValueError:
            fail()

        if num_parts == 1:
            n1 = 1
            n2 = n3 = ints[0]
        elif num_parts == 2:
            n1, n2 = ints
            n3 = n2
        else:
            n1, n2, n3 = ints

        if 0 < n1 <= n2 <= n3:
            return (n1, n2, n3)

        raise CatastrophicFailure("bad `--shard` argument: `0 < FROM <= TO <= SHARDS` check failed")

    def add_sharding(cmd: _t.Any) -> None:
        agrp = cmd.add_argument_group("sharding")
        agrp.add_argument(
            "--shard",
            metavar="SHARDS|FROM/SHARDS|FROM/TO/SHARDS",
            dest="shard",
            action="store_map",
            func=parse_shard,
            default=(1, 1, 1),
            help=_(
                "split database into `SHARDS` of disjoint pieces and process pieces with numbers between `FROM` and `TO`; if `FROM` is unspecified, it defaults to `1`; if `TO` is unspecified, it defaults to `SHARDS`; default: `1`, which is the same as `1/1` and `1/1/1`, which processes the whole database as a single shard"
            ),
        )

    if not real:
        add_common(parser)
        add_filter(parser)

    subparsers = parser.add_subparsers(title="subcommands")

    ### index
    cmd = subparsers.add_parser(
        "index",
        help=_("index given filesystem trees and record results in a `DATABASE`"),
        description=_(
            f"""Recursively walk given `INPUT`s and update the `DATABASE` to reflect them.

### Algorithm

- For each `INPUT`, walk it recursively (both in the filesystem and in the `DATABASE`), for each walked `path`:
  - if it is present in the filesystem but not in the `DATABASE`,
    - if `--no-add` is set, do nothing,
    - otherwise, index it and add it to the `DATABASE`;

  - if it is not present in the filesystem but present in the `DATABASE`,
    - if `--no-remove` is set, do nothing,
    - otherwise, remove it from the `DATABASE`;

  - if it is present in both,
    - if `--no-update` is set, do nothing,
    - if `--verify` is set, verify it as if `{__prog__} verify $path` was run,
    - if `--checksum` is set or if file `type`, `size`, or `mtime` changed,
      - re-index the file and update the `DATABASE` record,
      - otherwise, do nothing.

### Options
"""
        ),
    )

    if real:
        add_common(cmd)
        # TODO: filter
        # TODO?: ignore
    else:
        add_input(cmd)
        add_output(cmd)
    add_content(cmd, False, False)

    agrp = cmd.add_argument_group("index how")
    grp = agrp.add_mutually_exclusive_group()
    grp.add_argument(
        "--add",
        dest="do_add",
        action="store_true",
        help=_(
            "for files present in the filesystem but not yet present in the `DATABASE`, index and add them to the `DATABASE`; note that new files will be hashed even if `--no-checksum` is set"
        )
        + def_def,
    )
    grp.add_argument(
        "--no-add",
        dest="do_add",
        action="store_false",
        help=_("ignore previously unseen files"),
    )
    cmd.set_defaults(do_add=True)

    grp = agrp.add_mutually_exclusive_group()
    grp.add_argument(
        "--remove",
        dest="do_remove",
        action="store_true",
        help=_(
            "for files that vanished from the filesystem but are still present in the `DATABASE`, remove their records from the `DATABASE`; default"
        ),
    )
    grp.add_argument(
        "--no-remove",
        dest="do_remove",
        action="store_false",
        help=_("do not remove vanished files from the database"),
    )
    cmd.set_defaults(do_remove=True)

    grp = agrp.add_mutually_exclusive_group()
    grp.add_argument(
        "--update",
        dest="do_update",
        action="store_true",
        help=_(
            "for files present both on the filesystem and in the `DATABASE`, if a file appears to have changed on disk (changed `type`, `size`, or `mtime`), re-index it and write its updated record to the `DATABASE`; note that changed files will be re-hashed even if `--no-checksum` is set; default"
        ),
    )
    grp.add_argument(
        "--no-update",
        dest="do_update",
        action="store_false",
        help=_(
            "skip updates for all files that are present both on the filesystem and in the `DATABASE`"
        ),
    )
    grp.add_argument(
        "--reindex",
        dest="do_update",
        action="store_const",
        const="reindex",
        help=_(
            "an alias for `--update --checksum`: for all files present both on the filesystem and in the `DATABASE`, re-index them and then update `DATABASE` records of files that actually changed; i.e. re-hash files even if they appear to be unchanged"
        ),
    )
    grp.add_argument(
        "--verify",
        dest="do_update",
        action="store_const",
        const="verify",
        help=_(
            "proceed like `--update` does, but do not update any records in the `DATABASE`; instead, generate errors if newly generated records do not match those already in the `DATABASE`"
        ),
    )
    grp.add_argument(
        "--reindex-verify",
        dest="do_update",
        action="store_const",
        const="both",
        help=_(
            "an alias for `--verify --checksum`: proceed like `--reindex` does, but then `--verify` instead of updating the `DATABASE`"
        ),
    )
    cmd.set_defaults(do_update=True)

    agrp = cmd.add_argument_group("record what")
    grp = agrp.add_mutually_exclusive_group()
    grp.add_argument(
        "--ino",
        dest="record_ino",
        action="store_true",
        help=_("record inode numbers reported by `stat` into the `DATABASE`") + def_def,
    )
    grp.add_argument(
        "--no-ino",
        dest="record_ino",
        action="store_false",
        help=_(
            f"""ignore inode numbers reported by `stat`, recording them all as `0`s; this will force `{__prog__}` to ignore inode numbers in metadata checks and process such files as if each path is its own inode when doing duplicate search;

    on most filesystems, the default `--ino` will do the right thing, but this option needs to be set explicitly when indexing files from a filesystem which uses dynamic inode numbers (`unionfs`, `sshfs`, etc); otherwise, files indexed from such filesystems will be updated on each re-`index` and `find-duplicates`, `deduplicate`, and `verify` will always report them as having broken metadata"""
        ),
    )
    cmd.set_defaults(record_ino=True)

    cmd.set_defaults(func=cmd_index)

    ### find
    cmd = subparsers.add_parser(
        "find",
        help=_("print paths of indexed files matching specified criteria"),
        description=_(
            """Print paths of files under `INPUT`s that match specified criteria.

### Algorithm

- For each `INPUT`, walk it recursively (in the `DATABASE`), for each walked `path`:
  - if the `path` and/or the file associated with that path matches specified filters, print the `path`;
  - otherwise, do nothing.

### Options
"""
        ),
    )

    if real:
        add_common(cmd)
        add_filter(cmd)
    else:
        add_input(cmd)
        add_output(cmd)

    cmd.add_argument(
        "--porcelain", action="store_true", help=_("print outputs in a machine-readable format")
    )

    cmd.set_defaults(func=cmd_find)

    ### find-dupes
    cmd = subparsers.add_parser(
        "find-duplicates",
        aliases=["find-dupes"],
        help=_("print groups of duplicated indexed files matching specified criteria"),
        description=_(
            f"""Print groups of paths of duplicated files under `INPUT`s that match specified criteria.

### Algorithm

1. For each `INPUT`, walk it recursively (in the `DATABASE`), for each walked `path`:

   - get its `group`, which is a concatenation of its `type`, `sha256` hash, and all metadata fields for which a corresponding `--match-*` options are set;
     e.g., with `--match-perms --match-uid`, this produces a tuple of `type, sha256, mode, uid`;
   - get its `inode_id`, which is a tuple of `device_number, inode_number` for filesystems which report `inode_number`s and a unique `int` otherwise;
    - record this `inode`'s metadata and `path` as belonging to this `inode_id`;
    - record this `inode_id` as belonging to this `group`.

2. For each `group`, for each `inode_id` in `group`:

   - sort `path`s as `--order-paths` says,
   - sort `inodes`s as `--order-inodes` says.

3. For each `group`, for each `inode_id` in `group`, for each `path` associated to `inode_id`:

   - print the `path`.

Also, if you are reading the source code, note that the actual implementation of this command is a bit more complex than what is described above.
In reality, there's also a pre-computation step designed to filter out single-element `group`s very early, before loading of most of file metadata into memory, thus allowing `{__prog__}` to process groups incrementally, report its progress more precisely, and fit more potential duplicates into RAM.
In particular, this allows `{__prog__}` to work on `DATABASE`s with hundreds of millions of indexed files on my 2013-era laptop.

### Output

With the default verbosity, this command simply prints all `path`s in resulting sorted order.

With verbosity of `1` (a single `--verbose`), each `path` in a `group` gets prefixed by:

- `__`, if it is the first `path` associated to an `inode`,
  i.e., this means this `path` introduces a previously unseen `inode`,
- `=>`, otherwise,
  i.e., this means that this `path` is a hardlink to the path last marked with `__`.

With verbosity of `2`, each `group` gets prefixed by a metadata line.

With verbosity of `3`, each `path` gets prefixed by associated `inode_id`.

With the default spacing of `1` a new line gets printed after each `group`.

With spacing of `2` (a single `--spaced`) a new line also gets printed after each `inode`.

### Options
"""
        ),
    )

    def add_duplicates(cmd: _t.Any, strict: bool) -> None:
        if real:
            add_common(cmd, add_spaced=True)
            add_filter(cmd)
        else:
            add_input(cmd)
            add_output(cmd, add_spaced=True)
        add_match(cmd, False, strict)
        add_sharding(cmd)

        defgrp = cmd.add_argument_group("`--order-*` defaults")
        defgrp.add_argument(
            "--order",
            dest="order",
            choices=["mtime", "argno", "abspath", "dirname", "basename"],
            default=None,
            help=_(
                "set all `--order-*` option defaults to the given value, except specifying `--order mtime` will set the default `--order-paths` to `argno` instead (since all of the paths belonging to the same `inode` have the same `mtime`); default: `mtime`"
            ),
        )

        agrp = cmd.add_argument_group(
            _("order of elements in duplicate file groups")
            + _(
                "; note that unlike with `find-duplicates`, these settings influence not only the order they are printed, but also which files get kept and which get replaced with `--hardlink`s to kept files or `--delete`d"
                if strict
                else ""
            )
        )
        agrp.add_argument(
            "--order-paths",
            choices=["argno", "abspath", "dirname", "basename"],
            default=None,
            help=_(
                """in each `inode` info record, order `path`s by:

- `argno`: the corresponding `INPUT`'s index in `argv`, if a `path` is produced by several different arguments, the index of the first of them is used; default
- `abspath`: absolute file path
- `dirname`: absolute file path without its last component
- `basename`: the last component of absolute file path
"""
            ),
        )
        agrp.add_argument(
            "--order-inodes",
            choices=["mtime", "argno", "abspath", "dirname", "basename"],
            default=None,
            help=_(
                """in each duplicate file `group`, order `inode` info records by:

- `argno`: same as `--order-paths argno`
- `mtime`: file modification time; default
- `abspath`: same as `--order-paths abspath`
- `dirname`: same as `--order-paths dirname`
- `basename`: same as `--order-paths basename`

When an `inode` has several associated `path`s, sorting by `argno`, `abspath`, `dirname`, and `basename` is performed by taking the smallest of the respective values.

For instance, a duplicate file `group` that looks like the following when ordered with `--order-inodes mtime --order-paths abspath`:

```
__ 1/3
=> 1/4
__ 2/5
=> 2/6
__ 1/2
=> 2/1
```

will look like this, when ordered with `--order-inodes basename --order-paths abspath`:

```
__ 1/2
=> 2/1
__ 1/3
=> 1/4
__ 2/5
=> 2/6
```
"""
            ),
        )
        agrp.add_argument(
            "--reverse",
            dest="reverse",
            action="store_true",
            help=_("when sorting, invert all comparisons"),
        )

        agrp = cmd.add_argument_group("duplicate file group filters")
        agrp.add_argument(
            "--min-paths",
            dest="min_paths",
            type=int,
            default=2,
            help=_(
                "only process duplicate file groups with at least this many `path`s; default: `2`"
            ),
        )
        agrp.add_argument(
            "--min-inodes",
            dest="min_inodes",
            type=int,
            default=None if strict else 2,
            help=(
                _("only process duplicate file groups with at least this many `inodes`")
                + (
                    _("; default: `2` when `--hardlink` is set, `1` when --delete` is set")
                    if strict
                    else _("; default: `2`")
                )
            ),
        )

    add_duplicates(cmd, False)

    cmd.set_defaults(func=cmd_find_duplicates)

    ### deduplicate
    cmd = subparsers.add_parser(
        "deduplicate",
        help=_(
            "produce groups of duplicated indexed files matching specified criteria, and then deduplicate them"
        ),
        description=_(
            """Produce groups of duplicated indexed files matching specified criteria, similar to how `find-duplicates` does, except with much stricter default `--match-*` settings, and then deduplicate the resulting files by hardlinking them to each other.

### Algorithm

1. Proceed exactly as `find-duplicates` does in its step 1.

2. Proceed exactly as `find-duplicates` does in its step 2.

3. For each `group`:

   - assign the first `path` of the first `inode_id` as `source`,
   - print `source`,
   - for each `inode_id` in `group`, for each `inode` and `path` associated to an `inode_id`:
     - check that `inode` metadata matches filesystems metadata of `path`,
       - if it does not, print an error and skip this `inode_id`,
     - if `source`, continue with other `path`s;
     - if `--paranoid` is set or if this the very first `path` of `inode_id`,
       - check whether file data/contents of `path` matches file data/contents of `source`,
         - if it does not, print an error and skip this `inode_id`,
     - if `--hardlink` is set, hardlink `source -> path`,
     - if `--delete` is set, `unlink` the `path`,
     - update the `DATABASE` accordingly.

### Output

The verbosity and spacing semantics are similar to the ones used by `find-duplicates`, except this command starts at verbosity of `1`, i.e. as if a single `--verbose` is specified by default.

Each processed `path` gets prefixed by:

- `__`, if this is the very first `path` in a `group`, i.e. this is a `source`,
- when `--hardlink`ing:
  - `=>`, if this is a non-`source` `path` associated to the first `inode`,
    i.e. it's already hardlinked to `source` on disk, thus processing of this `path` was skipped,
  - `ln`, if this `path` was successfully hardlinked (to an equal `source`),
- when `--delete`ing:
  - `rm`, if this `path` was successfully deleted (while an equal `source` was kept),
- `fail`, if there was an error while processing this `path` (which will be reported to `stderr`).

### Options
"""
        ),
    )

    add_duplicates(cmd, True)

    agrp = cmd.add_argument_group("deduplicate how")
    grp = agrp.add_mutually_exclusive_group()
    grp.add_argument(
        "--hardlink",
        "--link",
        dest="how",
        action="store_const",
        const="hardlink",
        help=_(
            """deduplicate duplicated file groups by replacing all but the very first file in each group with hardlinks to it (hardlinks go **from** destination file **to** source file); see the "Algorithm" section above for a longer explanation"""
        )
        + def_def,
    )
    grp.add_argument(
        "--delete",
        "--unlink",
        dest="how",
        action="store_const",
        const="delete",
        help=_(
            """deduplicate duplicated file groups by deleting all but the very first file in each group; see `--order*` options for how to influence which file would be the first"""
        ),
    )

    grp = agrp.add_mutually_exclusive_group()
    grp.add_argument(
        "--sync",
        dest="sync",
        action="store_true",
        help=_(
            "batch changes, apply them right before commit, `fsync` all affected directories, and only then commit changes to the `DATABASE`; this way, after a power loss, the next `deduplicate` will at least notice those files being different from their records; default"
        ),
    )
    grp.add_argument(
        "--no-sync",
        dest="sync",
        action="store_false",
        help=_(
            "perform all changes eagerly without `fsync`ing anything, commit changes to the `DATABASE` asynchronously; not recommended unless your machine is powered by a battery/UPS; otherwise, after a power loss, the `DATABASE` will likely be missing records about files that still exists, i.e. you will need to re-`index` all `INPUTS` to make the database state consistent with the filesystems again"
        ),
    )
    cmd.set_defaults(sync=True)

    agrp = cmd.add_argument_group(
        "before `--hardlink`ing or `--delete`ing a target, check that source and target..."
    )
    grp = agrp.add_mutually_exclusive_group()
    grp.add_argument(
        "--careful",
        dest="paranoid",
        action="store_false",
        help=_(
            f"... inodes have equal data contents, once for each new inode; i.e.check that source and target have the same data contents as efficiently as possible; assumes that no files change while `{__prog__}` is running"
        ),
    )
    grp.add_argument(
        "--paranoid",
        dest="paranoid",
        action="store_true",
        help=_(
            f"""... paths have equal data contents, for each pair of them; this can be slow --- though it is usually not --- but it guarantees that `{__prog__}` won't loose data even if other internal functions are buggy; it will also usually, though not always, prevent data loss if files change while `{__prog__}` is running, see "Quirks and Bugs" section of the `README.md` for discussion"""
        )
        + def_def,
    )
    cmd.set_defaults(paranoid=True)

    # TODO:
    # cmd.add_argument("--merge", action="store_true", help=_("TODO"))

    cmd.set_defaults(func=cmd_deduplicate)

    ### verify
    cmd = subparsers.add_parser(
        "verify",
        aliases=["fsck"],
        help=_("verify that the index matches the filesystem"),
        description=_(
            """Verfy that indexed files from under `INPUT`s that match specified criteria exist on the filesystem and their metadata and hashes match filesystem contents.

### Algorithm

- For each `INPUT`, walk it recursively (in the filesystem), for each walked `path`:
  - fetch its `DATABASE` record,
  - if `--checksum` is set or if file `type`, `size`, or `mtime` is different from the one in the `DATABASE` record,
    - re-index the file,
    - for each field:
      - if its value matches the one in `DATABASE` record, do nothing;
      - otherwise, if `--match-<field>` option is set, print an error;
      - otherwise, print a warning.

This command runs with an implicit `--match-sha256` option which can not be disabled, so hash mismatches always produce errors.

### Options
"""
        ),
    )

    if real:
        add_common(cmd)
        add_filter(cmd)
    else:
        add_input(cmd)
        add_output(cmd)
    add_content(cmd, True, True)
    add_match(cmd, True, True)

    cmd.set_defaults(func=cmd_verify)

    ### upgrade
    cmd = subparsers.add_parser(
        "upgrade",
        help=_("backup the `DATABASE` and then upgrade it to latest format"),
        description=_(
            """Backup the `DATABASE` and then upgrade it to latest format.

This exists for development purposes.

You don't need to call this explicitly as, normally, database upgrades are completely automatic.
"""
        ),
    )

    if real:
        add_common(cmd)

    cmd.set_defaults(func=cmd_upgrade)

    return parser


def massage(cargs: _t.Any, lhnd: ANSILogHandler) -> None:
    stdout.ansi = first_def(cargs.color_stdout, cargs.color, stdout.ansi)
    stderr.ansi = first_def(cargs.color_stderr, cargs.color, stderr.ansi)

    if cargs.progress is None:
        cargs.progress = stderr.isatty()
    if cargs.progress:
        lhnd.level = INFO

    cargs.verbosity -= cargs.unverbosity
    del cargs.unverbosity
    if hasattr(cargs, "spacing"):
        cargs.spacing -= cargs.unspacing
        del cargs.unspacing

    if hasattr(cargs, "inputs"):
        try:
            cargs.inputs = cinputs = [
                _op.realpath(_op.expanduser(fsencode(a)), strict=True) for a in cargs.inputs if a
            ]
        except OSError as exc:
            raise CatastrophicFailure(*on_os_error(failed_msg, "readlink", exc)) from exc

        if cargs.stdin0:
            inputs = stdin.read_all_bytes().split(b"\0")
            last_path = inputs.pop()
            if last_path != b"":
                raise Failure("`--stdin0` input format error")
            for path in inputs:
                if path:
                    try:
                        cinputs.append(_op.realpath(path))
                    except OSError as exc:
                        raise CatastrophicFailure(
                            *on_os_error(failed_msg, "readlink", exc)
                        ) from exc

        if len(cinputs) == 0:
            warning(gettext("no `INPUT`s"))

    if hasattr(cargs, "terminator"):
        stdout.eol = terminator = cargs.terminator
        if terminator == b"\0":
            stdout.ansi = False
            cargs.verbosity = 0

    if hasattr(cargs, "match_meta"):
        cargs.match_perms = first_def(cargs.match_perms, cargs.match_meta)
        cargs.match_mtime = first_def(cargs.match_mtime, cargs.match_times)

        if hasattr(cargs, "match_device"):
            cargs.match_device = first_def(cargs.match_device, cargs.match_meta)
            cargs.match_uid = first_def(cargs.match_uid, cargs.match_meta)
            cargs.match_gid = first_def(cargs.match_gid, cargs.match_meta)
            cargs.match_xattrs = first_def(cargs.match_xattrs, cargs.match_extras)

    if hasattr(cargs, "order"):
        cargs.order_paths = first_def(cargs.order_paths, cargs.order, "argno")
        cargs.order_inodes = first_def(cargs.order_inodes, cargs.order, "mtime")
        if cargs.order_paths == "mtime":
            cargs.order_paths = "argno"

    if cargs.database is None:
        if POSIX:
            cargs.database = _op.expanduser(DB_POSIX)
        else:
            cargs.database = _op.expandvars(DB_WINDOWS)
        cargs.database = _op.realpath(cargs.database)
        _os.makedirs(_op.dirname(cargs.database), exist_ok=True)
    else:
        cargs.database = _op.realpath(_op.expanduser(cargs.database))


def run(cargs: _t.Any, lhnd: ANSILogHandler) -> None:
    with yes_signals():
        massage(cargs, lhnd)
    cargs.func(cargs, lhnd)


def main() -> None:
    _counter, lhnd = setup_result = setup_kisstdlib(__prog__, ephemeral_below=WARNING)
    run_kisstdlib_main(
        setup_result,
        argparse.make_argparser_and_run,
        make_argparser,
        lambda cargs: run(cargs, lhnd),
    )


if __name__ == "__main__":
    main()
