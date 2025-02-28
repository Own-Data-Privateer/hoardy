# Table of Contents
<details><summary>(Click me to see it.)</summary>
<ul>
<li><a href="#what-is-hoardy" id="toc-what-is-hoardy">What is <code>hoardy</code>?</a></li>
<li><a href="#what-can-hoardy-do" id="toc-what-can-hoardy-do">What can <code>hoardy</code> do?</a></li>
<li><a href="#glossary" id="toc-glossary">Glossary</a></li>
<li><a href="#quickstart" id="toc-quickstart">Quickstart</a>
<ul>
<li><a href="#pre-installation" id="toc-pre-installation">Pre-installation</a></li>
<li><a href="#installation" id="toc-installation">Installation</a></li>
</ul></li>
<li><a href="#quirks-and-bugs" id="toc-quirks-and-bugs">Quirks and Bugs</a>
<ul>
<li><a href="#known-issues" id="toc-known-issues">Known Issues</a></li>
<li><a href="#situations-where-hoardy-deduplicate-could-lose-data" id="toc-situations-where-hoardy-deduplicate-could-lose-data">Situations where <code>hoardy deduplicate</code> could lose data</a></li>
</ul></li>
<li><a href="#why-does-hoardy-exists" id="toc-why-does-hoardy-exists">Why does <code>hoardy</code> exists?</a></li>
<li><a href="#development-history" id="toc-development-history">Development history</a></li>
<li><a href="#meta" id="toc-meta">Meta</a>
<ul>
<li><a href="#changelog" id="toc-changelog">Changelog?</a></li>
<li><a href="#todo" id="toc-todo">TODO?</a></li>
<li><a href="#license" id="toc-license">License</a></li>
<li><a href="#contributing" id="toc-contributing">Contributing</a></li>
</ul></li>
<li><a href="#usage" id="toc-usage">Usage</a>
<ul>
<li><a href="#hoardy" id="toc-hoardy">hoardy</a>
<ul>
<li><a href="#hoardy-index" id="toc-hoardy-index">hoardy index</a></li>
<li><a href="#hoardy-find" id="toc-hoardy-find">hoardy find</a></li>
<li><a href="#hoardy-find-duplicates" id="toc-hoardy-find-duplicates">hoardy find-duplicates</a></li>
<li><a href="#hoardy-deduplicate" id="toc-hoardy-deduplicate">hoardy deduplicate</a></li>
<li><a href="#hoardy-verify" id="toc-hoardy-verify">hoardy verify</a></li>
<li><a href="#hoardy-upgrade" id="toc-hoardy-upgrade">hoardy upgrade</a></li>
</ul></li>
<li><a href="#examples" id="toc-examples">Examples</a></li>
</ul></li>
<li><a href="#development-.test-hoardy.sh---help---wine---fast-default-namepath" id="toc-development-.test-hoardy.sh---help---wine---fast-default-namepath">Development: <code>./test-hoardy.sh [--help] [--wine] [--fast] [default] [(NAME|PATH)]*</code></a>
<ul>
<li><a href="#examples-1" id="toc-examples-1">Examples</a></li>
</ul></li>
</ul>
</details>

# What is `hoardy`?

`hoardy` is an tool for digital data hoarding, a Swiss-army-knife-like utility for managing otherwise unmanageable piles of files.

On GNU/Linux, [`hoardy` it pretty well-tested on my files](#why-does-hoardy-exists) and I find it to be an essentially irreplaceable tool for managing the mess of media files in my home directory, backup snapshots made with `rsync`, as well as `git-annex` and `hydrus` file object stores.

On Windows, however, `hoardy` is a work in progress essentially unusable alpha software that is completely untested.

Data formats and command-line syntax of `hoardy` are subject to change in future versions.
See [below](#development-history) for why.

# What can `hoardy` do?

`hoardy` can

- record hashes and metadata of separate files and/or whole filesystem trees/hierarchies/directories, recursively, in [`SQLite`](https://www.sqlite.org/) databases;

  both one big database and/or many small ones are supported;

- update those records incrementally by adding new filesystem trees and/or re-indexing previously added ones;

  it can also re-`index` filesystem hierarchies much faster if files in its input directories only ever get added or removed, but their contents never change, which is common with backup directories (see [`hoardy index --no-update`](#hoardy-index));

- **find duplicated files matching specified criteria**, and then

  - display them,

  - **replace some of the duplicated files with hardlinks to others**, or

  - **delete some of the duplicated files**;

- **verify actual filesystem contents against file metadata and/or hashes previously recorded in its databases**.

See the ["Alternatives" section](#alternatives) for more info.

# Glossary

- *Inode* is a physical unnamed files.

  Directories reference them, giving them names.

  Different directories, or different names in the same directory, can refer to the same inode, making that file available under different names.

  Editing such a file under one name will change its content under all the other names too.

- `nlinks` is the number of times an inode is referenced by all the directories on a filesystem.

See [`man 7 inode`](https://man7.org/linux/man-pages/man7/inode.7.html) for more info.

# Quickstart

## Pre-installation

- Install `Python 3`:

  - On a conventional POSIX system like most GNU/Linux distros and MacOS X: Install `python3` via your package manager. Realistically, it probably is installed already.

## Installation

- On a POSIX system:

  Open a terminal, install this with
  ```bash
  pip install hoardy
  ```
  and run as
  ```bash
  hoardy --help
  ```

- Alternatively, for light development (without development tools, for those see `nix-shell` below):

  Open a terminal/`cmd.exe`, `cd` into this directory, then install with
  ```bash
  python -m pip install -e .
  # or
  pip install -e .
  ```
  and run as:
  ```bash
  python -m hoardy --help
  # or
  hoardy --help
  ```

- Alternatively, on a system with [Nix package manager](https://nixos.org/nix/)

  ```bash
  nix-env -i -f ./default.nix
  hoardy --help
  ```

  Though, in this case, you'll probably want to do the first command from the parent directory, to install everything all at once.

- Alternatively, to replicate my development environment:

  ```bash
  nix-shell ./default.nix --arg developer true
  ```

# Quirks and Bugs

## Known Issues

- `hoardy` databases take up quite a bit of space.

  This will be fixed with database format `v4`, which will store file trees instead of plain file tables indexed by paths.

- When a previously indexed file or directory can't be accessed due to file modes/permissions, `hoardy index` will remove it from the database.

  This is a design issue with the current scanning algorithm which will be solved after database format `v4`.

  At the moment, it can be alleviated by running `hoardy index` with `--no-remove` option.

- By default, `hoardy index` requires its input files to live on a filesystem which either has persistent inode numbers or reports all inode numbers as zeros.

  I.e., by default, `index`ing files from a filesystem like `unionfs` or `sshfs`, which use dynamic inode numbers, will produce broken index records.

  Filesystems like that can still be indexed with `--no-ino` option set, but there's no auto-detection for this option at the moment.

  Though, brokenly `index`ed trees can be fixed by simply re-`index`ing with `--no-ino` set.

- When `hoardy` is running, mounting a new filesystem into a directory given as its `INPUT`s could break some things in unpredictable ways, making `hoardy` report random files as having broken metadata.

  No data loss should occur in this case while `deduplicate` is running, but the outputs of `find-duplicates` could become useless.

## Situations where `hoardy deduplicate` could lose data

- Files changing at inconvenient times while `hoardy` is running **could make it lose either the old or the updated version** of each such file.

  Consider this:

  - `hoardy deduplicate` (`--hardlink` or `--delete`) discovers `source` and `target` files to be potential duplicates,
  - checks `source` and `target` files to have equal contents,
  - checks their file metadata, they match its database state,
  - "Okay!", it thinks, "Let's deduplicate them!"
  - but the OS puts `hoardy` to sleep doing its multi-tasking thing,
  - *another program sneaks in and sneakily updates `source` or `target`*,
  - the OS wakes `hoardy` up,
  - `hoardy` proceeds to deduplicate them, loosing one of them.

  `hoardy` calls `lstat` just before each file is `--hardlink`ed or `--delete`d, so this situation is quite unlikely and will be detected with very high probability, but it's not impossible.

  If it does happen, `hoardy` running with default settings will loose the updated version of the file, unless `--reverse` option is set, in which case it will loose be the oldest one instead.

  I know of no good solution to fix this.
  As far as I know, all [alternatives](#alternatives) suffer from the same issue.

  Technically, on Linux, there's a partial workaround for this via `renameat2` syscall with `RENAME_EXCHANGE` flag, which is unused by both `hoardy` and all similar tools at the moment, AFAICS.

  On Windows, AFAIK, there's no way around this issue at all.

  **Thus, you should not `deduplicate` directories with files that change.**

# <span id="why"/>Why does `hoardy` exists?

Originally, I made `hoardy` as a replacement for [its alternatives](#alternatives) so that I could:

- Find files by hash, because I wanted to easily open content-addressed links in my [org-mode](https://orgmode.org/) files.

- Efficiently deduplicate files between different backups produced by [`rsync`](https://rsync.samba.org/)/[`rsnapshot`](https://rsnapshot.org/):

  ```bash
  rsync -aHAXivRyy --link-dest=/backup/yesterday /home /backup/today
  ```

  since `rsync` does not handle file movements and renames very well, even with repeated `--fuzzy/-y` (see its `man` page for more info).

- Efficiently deduplicate per-app backups produced by [`hoardy-adb`](https://oxij.org/software/hoardy-adb/):

  ```bash
  hoardy-adb split backup.ab
  ```

- Efficiently deduplicate files between all of the above and `.git/objects` of related repositories, `.git/annex/objects` produced by [`git-annex`](https://git-annex.branchable.com/), `.local/share/hydrus/files` produced by [`hydrus`](https://github.com/hydrusnetwork/hydrus), and similar, in cases where they all live on the same filesystem.

  The issue here is that `git-annex`, `hydrus`, and similar tools **copy** files into their object stores, even when the files you feed them are read-only and can be hardlinked instead.
  Which, usually, is a good thing preventing catastrophic consequences of user errors.
  But I never edit read-only files, I do backups of backups, and, in general, I know what I'm doing, thank you very much, so I'd like to save my disk space instead, please.

"But `ZFS`/`BTRFS` solves this!" I hear you say?
Well, sure, such filesystems can deduplicate data blocks between different files (though, usually, you have to make a special effort to archive this as, by default, they do not), but how much space gets wasted to store the inodes?
Let's be generous and say an average inode takes 256 bytes (on a modern filesystems it's usually 512 bytes or more, which, by the way, is usually a good thing, since it allows small files to be stored much more efficiently by inlining them into the inode itself, but this is awful for efficient storage of backups).
My home directory has ~10M files in it (most of those are emails and files in source repositories, and this is the minimum I use all the time, I have a bunch more stuff on external drives, but it does not fit onto my SSD), thus a year of naively taken daily `rsync`-backups would waste `(256 * 10**7 * 365) / (1024 ** 3) = 870.22` GiB in inodes alone.
Sure, `rsync --link-dest` will save a bunch of that space, but if you move a bunch of files, they'll get duplicated.

In practice, the last time I deduplicated a never-before touched pristine `rsnapshot` hierarchy containing backups of my `$HOME` it saved me 1.1 TiB of space.
Don't you think you would find a better use for 1.1TiB of additional space than storing useless inodes?
Well, I did.

"But `fdupes` and its forks solve this!" I hear you say?
Well, sure, but the experience of using them in the above use cases of deduplicating mostly-read-only files is quite miserable.
See the ["Alternatives" section](#alternatives) for discussion.

Also, I wanted to store the oldest known `mtime` for each individual path, even when `deduplicate`-hardlinking all the copies, so that the exact original filesystem tree could be re-created from the backup when needed.
AFAIK, `hoardy` is the only tool that does this.
Yes, this feature is somewhat less useful on modern filesystems which support `reflink`s (Copy-on-Write lightweight copies), but even there, a `reflink` takes a whole inode, while storing an `mtime` in a database takes `<= 8` bytes.

Also, in general, indexing, search, duplicate discovery, set operations, send-receive from remote nodes, and application-defined storage APIs (like `HTTP`/`WebDAV`/`FUSE`/`SFTP`), can be combined to produce many useful functions.
It's annoying there appears to be no tool that can do all of those things on top of a plain file hierarchy.
All such tools known to me first slurp all the files into their own object stores, and usually store those files quite less efficiently than I would prefer, which is annoying.
See the ["Wishlist"](./doc/design.md#wishlist) for more info.

# Development history

This version of `hoardy` is a minimal valuable version of my privately developed tool (referred to as "bootstrap version" in commit messages), taken at its version circa 2020, cleaned up, rebased on top of [`kisstdlib`](https://oxij.org/software/kisstdlib/), slightly polished, and documented for public display and consumption.

The private version has more features and uses a much more space-efficient database format, but most of those cool new features are unfinished and kind of buggy, so I was actually mostly using the naive-database-formatted bootstrap version in production.
So, I decided to finish generalizing the infrastructure stuff to `kisstdlib` first, chop away everything related to `v4` on-disk format and later, and then publish this part first.
(*Which still took me two months of work. Ridiculous!*)

The rest is currently a work in progress.

If you'd like all those planned features from the the ["TODO" list](./CHANGELOG.md#todo) and the ["Wishlist"](./doc/design.md#wishlist) to be implemented, [sponsor them](https://oxij.org/#sponsor).
I suck at multi-tasking and I need to eat, time spent procuring sustenance money takes away huge chunks of time I could be working on [this and other related projects](https://oxij.org/software/).

# Meta

## Changelog?

See [`CHANGELOG.md`](./CHANGELOG.md).

## TODO?

See above, also the [bottom of `CHANGELOG.md`](./CHANGELOG.md#todo).

## License

[LGPLv3](./LICENSE.txt)+ (because it will become a library, eventually).

## Contributing

Contributions are accepted both via GitHub issues and PRs, and via pure email.
In the latter case I expect to see patches formatted with `git-format-patch`.

If you want to perform a major change and you want it to be accepted upstream here, you should probably write me an email or open an issue on GitHub first.
In the cover letter, describe what you want to change and why.
I might also have a bunch of code doing most of what you want in my stash of unpublished patches already.

# Usage

## hoardy

A thingy for hoarding digital assets.

- options:
  - `--version`
  : show program's version number and exit
  - `-h, --help`
  : show this help message and exit
  - `--markdown`
  : show `--help` formatted in Markdown
  - `-d DATABASE, --database DATABASE`
  : database file to use; default: `~/.local/share/hoardy/index.db` on POSIX, `%LOCALAPPDATA%\hoardy\index.db` on Windows
  - `--dry-run`
  : perform a trial run without actually performing any changes

- output defaults:
  - `--color`
  : set defaults to `--color-stdout` and `--color-stderr`
  - `--no-color`
  : set defaults to `--no-color-stdout` and `--no-color-stderr`

- output:
  - `--color-stdout`
  : color `stdout` output using ANSI escape sequences; default when `stdout` is connected to a TTY and environment variables do not set `NO_COLOR=1`
  - `--no-color-stdout`
  : produce plain-text `stdout` output without any ANSI escape sequences
  - `--color-stderr`
  : color `stderr` output using ANSI escape sequences; default when `stderr` is connected to a TTY and environment variables do not set `NO_COLOR=1`
  - `--no-color-stderr`
  : produce plain-text `stderr` output without any ANSI escape sequences
  - `--progress`
  : report progress to `stderr`; default when `stderr` is connected to a TTY
  - `--no-progress`
  : do not report progress

- filters:
  - `--size-leq INT`
  : `size <= value`
  - `--size-geq INT`
  : `size >= value`
  - `--sha256-leq HEX`
  : `sha256 <= from_hex(value)`
  - `--sha256-geq HEX`
  : `sha256 >= from_hex(value)`

- subcommands:
  - `{index,find,find-duplicates,find-dupes,deduplicate,verify,fsck,upgrade}`
    - `index`
    : index given filesystem trees and record results in a `DATABASE`
    - `find`
    : print paths of indexed files matching specified criteria
    - `find-duplicates (find-dupes)`
    : print groups of duplicated indexed files matching specified criteria
    - `deduplicate`
    : produce groups of duplicated indexed files matching specified criteria, and then deduplicate them
    - `verify (fsck)`
    : verify that the index matches the filesystem
    - `upgrade`
    : backup the `DATABASE` and then upgrade it to latest format

### hoardy index

Recursively walk given `INPUT`s and update the `DATABASE` to reflect them.

#### Algorithm

- For each `INPUT`, walk it recursively (both in the filesystem and in the `DATABASE`), for each walked `path`:
  - if it is present in the filesystem but not in the `DATABASE`,
    - if `--no-add` is set, do nothing,
    - otherwise, index it and add it to the `DATABASE`;

  - if it is not present in the filesystem but present in the `DATABASE`,
    - if `--no-remove` is set, do nothing,
    - otherwise, remove it from the `DATABASE`;

  - if it is present in both,
    - if `--no-update` is set, do nothing,
    - if `--verify` is set, verify it as if `hoardy verify $path` was run,
    - if `--checksum` is set or if file `type`, `size`, or `mtime` changed,
      - re-index the file and update the `DATABASE` record,
      - otherwise, do nothing.

#### Options

- positional arguments:
  - `INPUT`
  : input files and/or directories to process

- options:
  - `-h, --help`
  : show this help message and exit
  - `--markdown`
  : show `--help` formatted in Markdown
  - `--stdin0`
  : read zero-terminated `INPUT`s from stdin, these will be processed after all `INPUTS`s specified as command-line arguments

- output:
  - `-v, --verbose`
  : increase output verbosity; can be specified multiple times for progressively more verbose output
  - `-q, --quiet, --no-verbose`
  : decrease output verbosity; can be specified multiple times for progressively less verbose output
  - `-l, --lf-terminated`
  : print output lines terminated with `\n` (LF) newline characters; default
  - `-z, --zero-terminated, --print0`
  : print output lines terminated with `\0` (NUL) bytes, implies `--no-color` and zero verbosity

- content hashing:
  - `--checksum`
  : re-hash everything; i.e., assume that some files could have changed contents without changing `type`, `size`, or `mtime`
  - `--no-checksum`
  : skip hashing if file `type`, `size`, and `mtime` match `DATABASE` record; default

- index how:
  - `--add`
  : for files present in the filesystem but not yet present in the `DATABASE`, index and add them to the `DATABASE`; note that new files will be hashed even if `--no-checksum` is set; default
  - `--no-add`
  : ignore previously unseen files
  - `--remove`
  : for files that vanished from the filesystem but are still present in the `DATABASE`, remove their records from the `DATABASE`; default
  - `--no-remove`
  : do not remove vanished files from the database
  - `--update`
  : for files present both on the filesystem and in the `DATABASE`, if a file appears to have changed on disk (changed `type`, `size`, or `mtime`), re-index it and write its updated record to the `DATABASE`; note that changed files will be re-hashed even if `--no-checksum` is set; default
  - `--no-update`
  : skip updates for all files that are present both on the filesystem and in the `DATABASE`
  - `--reindex`
  : an alias for `--update --checksum`: for all files present both on the filesystem and in the `DATABASE`, re-index them and then update `DATABASE` records of files that actually changed; i.e. re-hash files even if they appear to be unchanged
  - `--verify`
  : proceed like `--update` does, but do not update any records in the `DATABASE`; instead, generate errors if newly generated records do not match those already in the `DATABASE`
  - `--reindex-verify`
  : an alias for `--verify --checksum`: proceed like `--reindex` does, but then `--verify` instead of updating the `DATABASE`

- record what:
  - `--ino`
  : record inode numbers reported by `stat` into the `DATABASE`; default
  - `--no-ino`
  : ignore inode numbers reported by `stat`, recording them all as `0`s; this will force `hoardy` to ignore inode numbers in metadata checks and process such files as if each path is its own inode when doing duplicate search;
    
        on most filesystems, the default `--ino` will do the right thing, but this option needs to be set explicitly when indexing files from a filesystem which uses dynamic inode numbers (`unionfs`, `sshfs`, etc); otherwise, files indexed from such filesystems will be updated on each re-`index` and `find-duplicates`, `deduplicate`, and `verify` will always report them as having broken metadata

### hoardy find

Print paths of files under `INPUT`s that match specified criteria.

#### Algorithm

- For each `INPUT`, walk it recursively (in the `DATABASE`), for each walked `path`:
  - if the `path` and/or the file associated with that path matches specified filters, print the `path`;
  - otherwise, do nothing.

#### Options

- positional arguments:
  - `INPUT`
  : input files and/or directories to process

- options:
  - `-h, --help`
  : show this help message and exit
  - `--markdown`
  : show `--help` formatted in Markdown
  - `--stdin0`
  : read zero-terminated `INPUT`s from stdin, these will be processed after all `INPUTS`s specified as command-line arguments
  - `--porcelain`
  : print outputs in a machine-readable format

- output:
  - `-v, --verbose`
  : increase output verbosity; can be specified multiple times for progressively more verbose output
  - `-q, --quiet, --no-verbose`
  : decrease output verbosity; can be specified multiple times for progressively less verbose output
  - `-l, --lf-terminated`
  : print output lines terminated with `\n` (LF) newline characters; default
  - `-z, --zero-terminated, --print0`
  : print output lines terminated with `\0` (NUL) bytes, implies `--no-color` and zero verbosity

### hoardy find-duplicates

Print groups of paths of duplicated files under `INPUT`s that match specified criteria.

#### Algorithm

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
In reality, there's also a pre-computation step designed to filter out single-element `group`s very early, before loading of most of file metadata into memory, thus allowing `hoardy` to process groups incrementally, report its progress more precisely, and fit more potential duplicates into RAM.
In particular, this allows `hoardy` to work on `DATABASE`s with hundreds of millions of indexed files on my 2013-era laptop.

#### Output

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

#### Options

- positional arguments:
  - `INPUT`
  : input files and/or directories to process

- options:
  - `-h, --help`
  : show this help message and exit
  - `--markdown`
  : show `--help` formatted in Markdown
  - `--stdin0`
  : read zero-terminated `INPUT`s from stdin, these will be processed after all `INPUTS`s specified as command-line arguments

- output:
  - `-v, --verbose`
  : increase output verbosity; can be specified multiple times for progressively more verbose output
  - `-q, --quiet, --no-verbose`
  : decrease output verbosity; can be specified multiple times for progressively less verbose output
  - `-l, --lf-terminated`
  : print output lines terminated with `\n` (LF) newline characters; default
  - `-z, --zero-terminated, --print0`
  : print output lines terminated with `\0` (NUL) bytes, implies `--no-color` and zero verbosity
  - `--spaced`
  : print more empty lines between different parts of the output; can be specified multiples
  - `--no-spaced`
  : print less empty lines between different parts of the output; can be specified multiples

- duplicate file grouping defaults:
  - `--match-meta`
  : set defaults to `--match-device --match-permissions --match-owner --match-group`
  - `--ignore-meta`
  : set defaults to `--ignore-device --ignore-permissions --ignore-owner --ignore-group`; default
  - `--match-extras`
  : set defaults to `--match-xattrs`
  - `--ignore-extras`
  : set defaults to `--ignore-xattrs`; default
  - `--match-times`
  : set defaults to `--match-last-modified`
  - `--ignore-times`
  : set defaults to `--ignore-last-modified`; default

- duplicate file grouping; consider same-content files to be duplicates when they...:
  - `--match-size`
  : ... have the same file size; default
  - `--ignore-size`
  : ... regardless of file size; only useful for debugging or discovering hash collisions
  - `--match-argno`
  : ... were produced by recursion from the same command-line argument (which is checked by comparing `INPUT` indexes in `argv`, if the path is produced by several different arguments, the smallest one is taken)
  - `--ignore-argno`
  : ... regardless of which `INPUT` they came from; default
  - `--match-device`
  : ... come from the same device/mountpoint/drive
  - `--ignore-device`
  : ... regardless of devices/mountpoints/drives; default
  - `--match-perms, --match-permissions`
  : ... have the same file modes/permissions
  - `--ignore-perms, --ignore-permissions`
  : ... regardless of file modes/permissions; default
  - `--match-owner, --match-uid`
  : ... have the same owner id
  - `--ignore-owner, --ignore-uid`
  : ... regardless of owner id; default
  - `--match-group, --match-gid`
  : ... have the same group id
  - `--ignore-group, --ignore-gid`
  : ... regardless of group id; default
  - `--match-last-modified, --match-mtime`
  : ... have the same `mtime`
  - `--ignore-last-modified, --ignore-mtime`
  : ... regardless of `mtime`; default
  - `--match-xattrs`
  : ... have the same extended file attributes
  - `--ignore-xattrs`
  : ... regardless of extended file attributes; default

- `--order-*` defaults:
  - `--order {mtime,argno,abspath,dirname,basename}`
  : set all `--order-*` option defaults to the given value, except specifying `--order mtime` will set the default `--order-paths` to `argno` instead (since all of the paths belonging to the same `inode` have the same `mtime`); default: `mtime`

- order of elements in duplicate file groups:
  - `--order-paths {argno,abspath,dirname,basename}`
  : in each `inode` info record, order `path`s by:
    
    - `argno`: the corresponding `INPUT`'s index in `argv`, if a `path` is produced by several different arguments, the index of the first of them is used; default
    - `abspath`: absolute file path
    - `dirname`: absolute file path without its last component
    - `basename`: the last component of absolute file path
  - `--order-inodes {mtime,argno,abspath,dirname,basename}`
  : in each duplicate file `group`, order `inode` info records by:
    
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
  - `--reverse`
  : when sorting, invert all comparisons

- duplicate file group filters:
  - `--min-paths MIN_PATHS`
  : only process duplicate file groups with at least this many `path`s; default: `2`
  - `--min-inodes MIN_INODES`
  : only process duplicate file groups with at least this many `inodes`; default: `2`

### hoardy deduplicate

Produce groups of duplicated indexed files matching specified criteria, similar to how `find-duplicates` does, except with much stricter default `--match-*` settings, and then deduplicate the resulting files by hardlinking them to each other.

#### Algorithm

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

#### Output

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

#### Options

- positional arguments:
  - `INPUT`
  : input files and/or directories to process

- options:
  - `-h, --help`
  : show this help message and exit
  - `--markdown`
  : show `--help` formatted in Markdown
  - `--stdin0`
  : read zero-terminated `INPUT`s from stdin, these will be processed after all `INPUTS`s specified as command-line arguments

- output:
  - `-v, --verbose`
  : increase output verbosity; can be specified multiple times for progressively more verbose output
  - `-q, --quiet, --no-verbose`
  : decrease output verbosity; can be specified multiple times for progressively less verbose output
  - `-l, --lf-terminated`
  : print output lines terminated with `\n` (LF) newline characters; default
  - `-z, --zero-terminated, --print0`
  : print output lines terminated with `\0` (NUL) bytes, implies `--no-color` and zero verbosity
  - `--spaced`
  : print more empty lines between different parts of the output; can be specified multiples
  - `--no-spaced`
  : print less empty lines between different parts of the output; can be specified multiples

- duplicate file grouping defaults:
  - `--match-meta`
  : set defaults to `--match-device --match-permissions --match-owner --match-group`; default
  - `--ignore-meta`
  : set defaults to `--ignore-device --ignore-permissions --ignore-owner --ignore-group`
  - `--match-extras`
  : set defaults to `--match-xattrs`; default
  - `--ignore-extras`
  : set defaults to `--ignore-xattrs`
  - `--match-times`
  : set defaults to `--match-last-modified`
  - `--ignore-times`
  : set defaults to `--ignore-last-modified`; default

- duplicate file grouping; consider same-content files to be duplicates when they...:
  - `--match-size`
  : ... have the same file size; default
  - `--ignore-size`
  : ... regardless of file size; only useful for debugging or discovering hash collisions
  - `--match-argno`
  : ... were produced by recursion from the same command-line argument (which is checked by comparing `INPUT` indexes in `argv`, if the path is produced by several different arguments, the smallest one is taken)
  - `--ignore-argno`
  : ... regardless of which `INPUT` they came from; default
  - `--match-device`
  : ... come from the same device/mountpoint/drive; default
  - `--ignore-device`
  : ... regardless of devices/mountpoints/drives
  - `--match-perms, --match-permissions`
  : ... have the same file modes/permissions; default
  - `--ignore-perms, --ignore-permissions`
  : ... regardless of file modes/permissions
  - `--match-owner, --match-uid`
  : ... have the same owner id; default
  - `--ignore-owner, --ignore-uid`
  : ... regardless of owner id
  - `--match-group, --match-gid`
  : ... have the same group id; default
  - `--ignore-group, --ignore-gid`
  : ... regardless of group id
  - `--match-last-modified, --match-mtime`
  : ... have the same `mtime`
  - `--ignore-last-modified, --ignore-mtime`
  : ... regardless of `mtime`; default
  - `--match-xattrs`
  : ... have the same extended file attributes; default
  - `--ignore-xattrs`
  : ... regardless of extended file attributes

- `--order-*` defaults:
  - `--order {mtime,argno,abspath,dirname,basename}`
  : set all `--order-*` option defaults to the given value, except specifying `--order mtime` will set the default `--order-paths` to `argno` instead (since all of the paths belonging to the same `inode` have the same `mtime`); default: `mtime`

- order of elements in duplicate file groups; note that unlike with `find-duplicates`, these settings influence not only the order they are printed, but also which files get kept and which get replaced with `--hardlink`s to kept files or `--delete`d:
  - `--order-paths {argno,abspath,dirname,basename}`
  : in each `inode` info record, order `path`s by:
    
    - `argno`: the corresponding `INPUT`'s index in `argv`, if a `path` is produced by several different arguments, the index of the first of them is used; default
    - `abspath`: absolute file path
    - `dirname`: absolute file path without its last component
    - `basename`: the last component of absolute file path
  - `--order-inodes {mtime,argno,abspath,dirname,basename}`
  : in each duplicate file `group`, order `inode` info records by:
    
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
  - `--reverse`
  : when sorting, invert all comparisons

- duplicate file group filters:
  - `--min-paths MIN_PATHS`
  : only process duplicate file groups with at least this many `path`s; default: `2`
  - `--min-inodes MIN_INODES`
  : only process duplicate file groups with at least this many `inodes`; default: `2` when `--hardlink` is set, `1` when --delete` is set

- deduplicate how:
  - `--hardlink, --link`
  : deduplicate duplicated file groups by replacing all but the very first file in each group with hardlinks to it (hardlinks go **from** destination file **to** source file); see the "Algorithm" section above for a longer explanation; default
  - `--delete, --unlink`
  : deduplicate duplicated file groups by deleting all but the very first file in each group; see `--order*` options for how to influence which file would be the first
  - `--sync`
  : batch changes, apply them right before commit, `fsync` all affected directories, and only then commit changes to the `DATABASE`; this way, after a power loss, the next `deduplicate` will at least notice those files being different from their records; default
  - `--no-sync`
  : perform all changes eagerly without `fsync`ing anything, commit changes to the `DATABASE` asynchronously; not recommended unless your machine is powered by a battery/UPS; otherwise, after a power loss, the `DATABASE` will likely be missing records about files that still exists, i.e. you will need to re-`index` all `INPUTS` to make the database state consistent with the filesystems again

- before `--hardlink`ing or `--delete`ing a target, check that source and target...:
  - `--careful`
  : ... inodes have equal data contents, once for each new inode; i.e.check that source and target have the same data contents as efficiently as possible; assumes that no files change while `hoardy` is running
  - `--paranoid`
  : ... paths have equal data contents, for each pair of them; this can be slow --- though it is usually not --- but it guarantees that `hoardy` won't loose data even if other internal functions are buggy; it will also usually, though not always, prevent data loss if files change while `hoardy` is running, see "Quirks and Bugs" section of the `README.md` for discussion; default

### hoardy verify

Verfy that indexed files from under `INPUT`s that match specified criteria exist on the filesystem and their metadata and hashes match filesystem contents.

#### Algorithm

- For each `INPUT`, walk it recursively (in the filesystem), for each walked `path`:
  - fetch its `DATABASE` record,
  - if `--checksum` is set or if file `type`, `size`, or `mtime` is different from the one in the `DATABASE` record,
    - re-index the file,
    - for each field:
      - if its value matches the one in `DATABASE` record, do nothing;
      - otherwise, if `--match-<field>` option is set, print an error;
      - otherwise, print a warning.

This command runs with an implicit `--match-sha256` option which can not be disabled, so hash mismatches always produce errors.

#### Options

- positional arguments:
  - `INPUT`
  : input files and/or directories to process

- options:
  - `-h, --help`
  : show this help message and exit
  - `--markdown`
  : show `--help` formatted in Markdown
  - `--stdin0`
  : read zero-terminated `INPUT`s from stdin, these will be processed after all `INPUTS`s specified as command-line arguments

- output:
  - `-v, --verbose`
  : increase output verbosity; can be specified multiple times for progressively more verbose output
  - `-q, --quiet, --no-verbose`
  : decrease output verbosity; can be specified multiple times for progressively less verbose output
  - `-l, --lf-terminated`
  : print output lines terminated with `\n` (LF) newline characters; default
  - `-z, --zero-terminated, --print0`
  : print output lines terminated with `\0` (NUL) bytes, implies `--no-color` and zero verbosity

- content verification:
  - `--checksum`
  : verify all file hashes; i.e., assume that some files could have changed contents without changing `type`, `size`, or `mtime`; default
  - `--no-checksum`
  : skip hashing if file `type`, `size`, and `mtime` match `DATABASE` record

- verification defaults:
  - `--match-meta`
  : set defaults to `--match-permissions`; default
  - `--ignore-meta`
  : set defaults to `--ignore-permissions`
  - `--match-extras`
  : set defaults to `--match-xattrs`; default
  - `--ignore-extras`
  : set defaults to `--ignore-xattrs`
  - `--match-times`
  : set defaults to `--match-last-modified`
  - `--ignore-times`
  : set defaults to `--ignore-last-modified`; default

- verification; consider a file to be `ok` when it and its `DATABASE` record...:
  - `--match-size`
  : ... have the same file size; default
  - `--ignore-size`
  : ... regardless of file size; only useful for debugging or discovering hash collisions
  - `--match-perms, --match-permissions`
  : ... have the same file modes/permissions; default
  - `--ignore-perms, --ignore-permissions`
  : ... regardless of file modes/permissions
  - `--match-last-modified, --match-mtime`
  : ... have the same `mtime`
  - `--ignore-last-modified, --ignore-mtime`
  : ... regardless of `mtime`; default

### hoardy upgrade

Backup the `DATABASE` and then upgrade it to latest format.

This exists for development purposes.

You don't need to call this explicitly as, normally, database upgrades are completely automatic.

- options:
  - `-h, --help`
  : show this help message and exit
  - `--markdown`
  : show `--help` formatted in Markdown

## Examples

- Index all files in `/backup`:
  ```
  hoardy index /backup
  ```

- Search paths of files present in `/backup`:
  ```
  hoardy find /backup | grep something
  ```

- List all duplicated files in `/backup`, i.e. list all files in `/backup` that have multiple on-disk copies with same contents but using different inodes:
  ```
  hoardy find-dupes /backup | tee dupes.txt
  ```

- Same as above, but also include groups consisting solely of hardlinks to the same inode:
  ```
  hoardy find-dupes --min-inodes 1 /backup | tee dupes.txt
  ```

- Produce exactly the same duplicate file groups as those the following `deduplicate` would use by default:
  ```
  hoardy find-dupes --match-meta /backup | tee dupes.txt
  ```

- Deduplicate `/backup` by replacing files that have exactly the same metadata and contents (but with any `mtime`) with hardlinks to a file with the earliest known `mtime` in each such group:
  ```
  hoardy deduplicate /backup
  ```

- Deduplicate `/backup` by replacing same-content files larger than 1 KiB with hardlinks to a file with the latest `mtime` in each such group:
  ```
  hoardy deduplicate --size-geq 1024 --reverse --ignore-meta /backup
  ```

  This plays well with directories produced by `rsync --link-dest` and `rsnapshot`.

- Similarly, but for each duplicate file group use a file with the largest absolute path (in lexicographic order) as the source for all generated hardlinks:
  ```
  hoardy deduplicate --size-geq 1024 --ignore-meta --reverse --order-inodes abspath /backup
  ```

- When you have enough indexed files that a run of `find-duplicates` or `deduplicate` stops fitting into RAM, you can shard inputs by file size or hash:
  ```
  # deduplicate files larger than 100 MiB
  hoardy deduplicate --size-geq 104857600 --ignore-meta /backup
  # deduplicate files between 1 and 100 MiB
  hoardy deduplicate --size-geq 1048576 --size-leq 104857600 --ignore-meta /backup
  # deduplicate files between 64 bytes and 1 MiB
  hoardy deduplicate --size-geq 64 --size-leq 1048576 --ignore-meta /backup
  # deduplicate the rest
  hoardy deduplicate --size-leq 64 --ignore-meta /backup

  # deduplicate about half of the files
  hoardy deduplicate --sha256-leq 7f --ignore-meta /backup
  # deduplicate the other half
  hoardy deduplicate --sha256-geq 80 --ignore-meta /backup
  ```

  The result would be exactly the same as if you had more RAM and run a single `deduplicate` without those limits.

# Development: `./test-hoardy.sh [--help] [--wine] [--fast] [default] [(NAME|PATH)]*`

Sanity check and test `hoardy` command-line interface.

## Examples

- Run internal tests:

  ```
  ./test-hoardy.sh default
  ```

- Run fixed-output tests on a given directory:

  ```
  ./test-hoardy.sh ~/rarely-changing-path
  ```

  This will copy the whole contents of that path to `/tmp` first.
