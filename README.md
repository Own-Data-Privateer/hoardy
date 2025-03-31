# Table of Contents
<details><summary>(Click me to see it.)</summary>
<ul>
<li><a href="#what-is-hoardy" id="toc-what-is-hoardy">What is <code>hoardy</code>?</a></li>
<li><a href="#what-can-hoardy-do" id="toc-what-can-hoardy-do">What can <code>hoardy</code> do?</a></li>
<li><a href="#on-honesty-in-reporting-of-data-loss-issues" id="toc-on-honesty-in-reporting-of-data-loss-issues">On honesty in reporting of data loss issues</a></li>
<li><a href="#glossary" id="toc-glossary">Glossary</a></li>
<li><a href="#quickstart" id="toc-quickstart">Quickstart</a>
<ul>
<li><a href="#pre-installation" id="toc-pre-installation">Pre-installation</a></li>
<li><a href="#installation" id="toc-installation">Installation</a></li>
<li><a href="#deduplicate-files-in-your-downloads" id="toc-deduplicate-files-in-your-downloads">Deduplicate files in your <code>~/Downloads</code></a></li>
<li><a href="#deduplicate-rsync-snapshots" id="toc-deduplicate-rsync-snapshots">Deduplicate <code>rsync</code> snapshots</a></li>
<li><a href="#deduplicate-files-in-your-home" id="toc-deduplicate-files-in-your-home">Deduplicate files in your <code>$HOME</code></a>
<ul>
<li><a href="#deduplicate-.gitobjects" id="toc-deduplicate-.gitobjects">Deduplicate <code>.git/objects</code></a></li>
<li><a href="#deduplicate-node_modules" id="toc-deduplicate-node_modules">Deduplicate <code>node_modules</code></a></li>
<li><a href="#deduplicate-git-worktree-and-other-commonly-duplicated-source-files" id="toc-deduplicate-git-worktree-and-other-commonly-duplicated-source-files">Deduplicate <code>git worktree</code> and other commonly duplicated source files</a></li>
</ul></li>
</ul></li>
<li><a href="#quirks-and-bugs" id="toc-quirks-and-bugs">Quirks and Bugs</a>
<ul>
<li><a href="#known-issues" id="toc-known-issues">Known Issues</a></li>
<li><a href="#situations-where-hoardy-deduplicate-could-lose-data" id="toc-situations-where-hoardy-deduplicate-could-lose-data">Situations where <code>hoardy deduplicate</code> could lose data</a></li>
</ul></li>
<li><a href="#frequently-asked-questions" id="toc-frequently-asked-questions">Frequently Asked Questions</a>
<ul>
<li><a href="#im-using-fdupesjdupes-now-how-do-i-migrate-to-using-hoardy" id="toc-im-using-fdupesjdupes-now-how-do-i-migrate-to-using-hoardy">I’m using <code>fdupes</code>/<code>jdupes</code> now, how do I migrate to using <code>hoardy</code>?</a></li>
<li><a href="#i-have-two-identical-files-but-hoardy-deduplicate-does-not-deduplicate-them.-why" id="toc-i-have-two-identical-files-but-hoardy-deduplicate-does-not-deduplicate-them.-why">I have two identical files, but <code>hoardy deduplicate</code> does not deduplicate them. Why?</a></li>
<li><a href="#what-would-happen-if-i-run-hoardy-deduplicate-with-an-outdated-index-would-hoardy-loose-some-of-my-files-by-wrongly-deduplicating-them" id="toc-what-would-happen-if-i-run-hoardy-deduplicate-with-an-outdated-index-would-hoardy-loose-some-of-my-files-by-wrongly-deduplicating-them">What would happen if I run <code>hoardy deduplicate</code> with an outdated index? Would <code>hoardy</code> loose some of my files by wrongly “deduplicating” them?</a></li>
<li><a href="#i-have-two-files-with-equal-sha256-hash-digests-and-sizes-and-yet-they-are-unequal-when-compared-as-binary-strings.-would-hoardy-deduplicate-them-wrongly" id="toc-i-have-two-files-with-equal-sha256-hash-digests-and-sizes-and-yet-they-are-unequal-when-compared-as-binary-strings.-would-hoardy-deduplicate-them-wrongly">I have two files with equal <code>SHA256</code> hash digests and <code>size</code>s, and yet they are unequal when compared as binary strings. Would <code>hoardy</code> “deduplicate” them wrongly?</a></li>
<li><a href="#what-would-happen-if-i-run-hoardy-deduplicate---delete-with-the-same-directory-given-in-two-different-arguments-would-it-consider-those-files-to-be-equivalent-to-themselves-and-delete-them-losing-all-my-data" id="toc-what-would-happen-if-i-run-hoardy-deduplicate---delete-with-the-same-directory-given-in-two-different-arguments-would-it-consider-those-files-to-be-equivalent-to-themselves-and-delete-them-losing-all-my-data">What would happen if I run <code>hoardy deduplicate --delete</code> with the same directory given in two different arguments? Would it consider those files to be equivalent to themselves and delete them, losing all my data?</a></li>
<li><a href="#but-what-if-i-give-the-same-directory-to-hoardy-deduplicate---delete-twice-but-not-as-equivalent-paths-but-by-giving-one-of-them-as-a-symlink-into-an-ancestor-of-the-other-followed-by-their-common-suffix-will-it-loose-my-data-now" id="toc-but-what-if-i-give-the-same-directory-to-hoardy-deduplicate---delete-twice-but-not-as-equivalent-paths-but-by-giving-one-of-them-as-a-symlink-into-an-ancestor-of-the-other-followed-by-their-common-suffix-will-it-loose-my-data-now">But what if I give the same directory to <code>hoardy deduplicate --delete</code> twice, but not as equivalent paths, but by giving one of them as a symlink into an ancestor of the other, followed by their common suffix? Will it loose my data now?</a></li>
<li><a href="#alright-but-what-if-i-mount---bind-a-directory-to-another-directory-then-hoardy-index-and-run-hoardy-deduplicate---delete-on-both.-the-cloned-directory-will-appear-to-be-exactly-the-same-as-the-original-directory-but-paths-would-be-different-and-there-would-be-no-symlinks-involved.-so-hoardy-deduplicate---delete-would-then-detect-them-as-duplicates-and-would-need-to-delete-all-files-from-one-of-them.-but-deleting-a-file-from-one-will-also-delete-it-from-the-other-ha-finally-surely-it-would-loose-my-data-now" id="toc-alright-but-what-if-i-mount---bind-a-directory-to-another-directory-then-hoardy-index-and-run-hoardy-deduplicate---delete-on-both.-the-cloned-directory-will-appear-to-be-exactly-the-same-as-the-original-directory-but-paths-would-be-different-and-there-would-be-no-symlinks-involved.-so-hoardy-deduplicate---delete-would-then-detect-them-as-duplicates-and-would-need-to-delete-all-files-from-one-of-them.-but-deleting-a-file-from-one-will-also-delete-it-from-the-other-ha-finally-surely-it-would-loose-my-data-now">Alright, but what if I <code>mount --bind</code> a directory to another directory, then <code>hoardy index</code> and run <code>hoardy deduplicate --delete</code> on both. The cloned directory will appear to be exactly the same as the original directory, but paths would be different, and there would be no symlinks involved. So <code>hoardy deduplicate --delete</code> would then detect them as duplicates and would need to delete all files from one of them. But deleting a file from one will also delete it from the other! Ha! Finally! Surely, it would loose my data now?!</a></li>
<li><a href="#hmm-but-hoardy-deduplicate-implementation-looks-rather-complex.-what-if-a-bug-there-causes-it-to-deduplicate-some-files-that-are-not-actually-duplicates-and-loose-data" id="toc-hmm-but-hoardy-deduplicate-implementation-looks-rather-complex.-what-if-a-bug-there-causes-it-to-deduplicate-some-files-that-are-not-actually-duplicates-and-loose-data">Hmm, but <code>hoardy deduplicate</code> implementation looks rather complex. What if a bug there causes it to “deduplicate” some files that are not actually duplicates and loose data?</a></li>
</ul></li>
<li><a href="#why-does-hoardy-exists" id="toc-why-does-hoardy-exists">Why does <code>hoardy</code> exists?</a></li>
<li><a href="#development-history" id="toc-development-history">Development history</a></li>
<li><a href="#alternatives" id="toc-alternatives">Alternatives</a>
<ul>
<li><a href="#fdupes-and-jdupes" id="toc-fdupes-and-jdupes"><code>fdupes</code> and <code>jdupes</code></a></li>
<li><a href="#rhash" id="toc-rhash"><code>RHash</code></a></li>
</ul></li>
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

On GNU/Linux, [`hoardy` it pretty well-tested on my files](#why-does-hoardy-exists) and I find it to be an essentially irreplaceable tool for managing duplicated files in related source code trees, media files duplicated between my home directory, [`git-annex`](https://git-annex.branchable.com/), and [`hydrus`](https://github.com/hydrusnetwork/hydrus) file object stores, as well as backup snapshots made with [`rsync`](https://rsync.samba.org/) and [`rsnapshot`](https://rsnapshot.org/).

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

  similarly to what [`fdupes`](https://github.com/adrianlopezroche/fdupes) and [`jdupes`](https://codeberg.org/jbruchon/jdupes) do, but `hoardy` **[won't loose your files, won't loose extended file attributes, won't leave your filesystem in an inconsistent state in case of power failure, is much faster on large inputs, can used even if you have more files than you have RAM to store their metadata, can be run incrementally without degrading the quality of results, ...](#fdupes-and-jdupes)**;

- **verify actual filesystem contents against file metadata and/or hashes previously recorded in its databases**;

  which is similar to what [`RHash`](https://github.com/rhash/RHash) can do, but [`hoardy` is faster on large databases of file records, can verify file metadata, and slightly more convenient to use, but, also, at the moment, `hoardy` only computes and checks `SHA256` hash digests and nothing else](#rhash).

See the ["Alternatives" section](#alternatives) for more info.

# On honesty in reporting of data loss issues

This document mentions **data loss** and situations when it could occur, repeatedly.
I realize that this may turn some people off.
Unfortunately, the reality is that with modern computing it's quite easy to screw things up.
If a tool can delete or overwrite data, it can loose data.
Hence, **make backups!**

With that said, **`hoardy` tries its very best to make situations where it causes data loss impossible** by doing a ton of paranoid checks before doing anything destructive.
Unfortunately, the set of situations where it could lose some data even after doing all those checks **is not empty**.
Which is why ["Quirks and Bugs" section](#quirks-and-bugs) documents all of those situations known to me.
(So... Make backups!)
Meanwhile, ["Frequently Asked Questions"](#frequently-asked-questions), among other things, documents various cases that are handled safely.
Most of those are quite non-obvious and not recognized by other tools, **which will loose your data where `hoardy` would not**.

**As far as I know, `hoardy` is actually the safest tool for doing what it does**, but this document mentions *data loss* repeatedly, while other tools prefer to be quiet about it.
I've read the sources of [`hoardy`'s alternatives](#alternatives) to make those comparisons there, and to figure out if I maybe should change how `hoardy` does some things, **and I became much happier with `hoardy`'s internals as a result**.
Just saying.

Also, should I ever find an issue in `hoardy` that produces loss off data, I commit to fixing and honestly documenting it all immediately, and then adding new tests to the test suite to prevent that issues in the future.
A promise that can be confirmed by the fact that I did such a thing before for [`hoardy-web` tool, see its `tool-v0.18.1` release](https://oxij.org/software/hoardy-web/tree/master/CHANGELOG.md).

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

## Deduplicate files in your `~/Downloads`

So, as the simplest use case, deduplicate your `~/Downloads` directory.

Index your `~/Downloads` directory:

```bash
hoardy index ~/Downloads
```

Look at the list of duplicated files there:

```bash
hoardy find-dupes ~/Downloads
```

**Deduplicate them by hardlinking each duplicate file to its oldest available duplicate version**, i.e. make all paths pointing to duplicate files point to the oldest available inode among those duplicates:

```bash
hoardy deduplicate --hardlink ~/Downloads
# or, equivalently
hoardy deduplicate ~/Downloads
```

The following should produce an empty output now:

```bash
hoardy find-dupes ~/Downloads
```

If it does not (which is unlikely for `~/Downloads`), then some duplicates have different metadata (permissions, owner, group, extended attributes, etc), which will be discussed below.

By default, both `deduplicate --hardlink` and `find-dupes` run with implied `--min-inodes 2` option.
Thus, to see paths that point to the same inodes on disk you'll need to run the following instead:

```
hoardy find-dupes --min-inodes 1 ~/Downloads
```

**To delete all but the oldest file among duplicates in a given directory, run**

```
hoardy deduplicate --delete ~/Downloads
```

in which case `--min-inodes 1` is implied by default.

The result of which could, of course, have been archived by running this last command directly, without doing all of the above except for `index`.

Personally, I have

```
hoardy index ~/Downloads && hoardy deduplicate --delete ~/Downloads
```

scheduled in my daily `crontab`, because I frequently re-download files from local servers while developing things (for testing).

Normally, you probably don't need to run it that often.

## Deduplicate `rsync` snapshots

Assuming you have a bunch of directories that were produced by something like

```
rsync -aHAXivRyy --link-dest=/backup/yesterday /home /backup/today
```

you can deduplicate them by running

```
hoardy index /backup
hoardy deduplicate /backup
```

(Which will probably take a while.)

**Doing this will deduplicate everything by hardlinking each duplicate file to an inode with the oldest `mtime` while respecting and preserving all file permissions, owners, groups, and `user` extended attributes.**
If you run it as super-user it will also respect all other extended name-spaces, like ACLs, trusted extended attributes, etc.
See [`man 7 xattr`](https://man7.org/linux/man-pages/man7/xattr.7.html) for more info.

**But, depending on your setup and wishes, the above might not be what you'd want to run.**
For instance, personally, I run

```
hoardy index /backup
hoardy deduplicate --reverse --ignore-meta /backup
```

instead.

Doing this hardlinks each duplicate file to an inode with the latest `mtime` (`--reverse`) and ignores all file metadata (but not extended attributes), so that the next

```
rsync -aHAXivRyy --link-dest=/backup/today /home /backup/tomorrow
```

could re-use those inodes via `--link-dest` as much as possible again.
Without those options the next `rsync --link-dest` would instead re-create many of those inodes again, which is not what I want, but your mileage may vary.

Also, even with `--reverse` the original `mtime` of each path will be kept in the `hoardy`'s database so that it could be restored later.
(Which is pretty cool, right?)

Also, if you have so many files under `/backup` that `deduplicate` does not fit into RAM, you can still run it incrementally (while producing the same deduplicated result) via sharding by `SHA256` hash digest.
See [examples](#examples) for more info.

## Deduplicate files in your `$HOME`

**Note however, that simply running `hoardy deduplicate` on your whole `$HOME` directory will probably break almost everything**, as many programs depend on file timestamps not moving backwards, use zero-length or similarly short files for various things, overwrite files without copying them first, and expect them to stay as independent inodes.
Hardlinking different same-data files together on a non-backup filesystem will break all those assumptions.

(If you do screw it up, you can fix it by simply doing `cp -a file file.copy ; mv file.copy file` for each wrongly deduplicated file.)

However, sometimes deduplicating some files under `$HOME` can be quite useful, so `hoardy` implements a fairly safe way to do it semi-automatically.

Index your home directory and generate a list of all duplicated files, matched strictly, like `deduplicate` would do:

```bash
hoardy index ~
hoardy find-dupes --print0 --match-meta ~ > dupes.print0
```

`--print0` is needed here because otherwise file names with newlines and/or weird symbols in them could be parsed as multiple separate paths and/or mangled.
By default, without `--print0`, `hoardy` solves this by escaping control characters in its outputs, and, in theory, it could then allow to read back its own outputs using that format.
But normal UNIX tools won't be able to use them, hence `--print0`, which is almost universally supported.

You can then easily view the resulting file from a terminal with:

```bash
cat dupes.print0 | tr '\0' '\n' | less
```

which, if none of the paths have control symbols in them, will be equivalent to the output of:

```bash
hoardy find-dupes --match-meta ~ | less
```

But you can now use `grep` or another similar tool to filter those outputs.

### Deduplicate `.git/objects`

Say, for example, you want to deduplicate `git` objects across different repositories:

```bash
grep -zP '/\.git/objects/([0-9a-f]{2}|pack)/' dupes.print0 > git-objects.print0
cat git-objects.print0 | tr '\0' '\n' | less
```

These are never modified, as so they can be hardlinked together.
In fact, `git` does this silently when it notices, so you might not get a lot of duplicates there, especially if you mostly clone local repositories from each other.
But if you have several related repositories cloned from external sources at `$HOME`, the above output, most likely, will not be empty.

So, you can now pretend to deduplicate all of those files:

```bash
hoardy deduplicate --dry-run --stdin0 < git-objects.print0
```

and then actually do it:

```bash
hoardy deduplicate --stdin0 < git-objects.print0
```

Ta-da! More disk space! For free!

### Deduplicate `node_modules`

Of course, the above probably won't have deduplicated much.
However, if you use `npm` lots, then your filesystem is probably chock full of `node_modules` directories full of files that can be deduplicated.
In fact, [`pnpm`](https://pnpm.io/) tool does this automatically when installing new stuff, but it won't help with the previously installed stuff.
Whereas `hoardy` can help:

```bash
grep -zF '/node_modules/' dupes.print0 > node_modules.print0
cat node_modules.print0 | tr '\0' '\n' | less
hoardy deduplicate --stdin0 < node_modules.print0
```

Doing this could save quite a bit of space, since `nodejs` packages tend to duplicate everything dozens of times.

### Deduplicate `git worktree` and other commonly duplicated source files

... and then duplicate them on-demand while editing.

Personally, I use `git worktree`s a lot.
That is, usually, I clone a repo, make a feature branch, check it out into a separate worktree, and work on it there:

```bash
git clone --origin upstream url/to/repo repo
cd repo
git branch feature-branch
git worktree add feature feature-branch
cd feature
# now working on a feature-branch
# ....
```

Meanwhile, in another TTY, I check out successive testable revisions and test them in a separate `nix-shell` session

```bash
cd ~/src/repo
hash=$(cd ~/src/repo/feature; git rev-parse HEAD)
git worktree add testing $hash
cd testing
nix-shell ./default.nix

# run long-running tests here

# when feature-branch updated lots
hash=$(cd ~/src/repo/feature; git rev-parse HEAD)
git checkout $hash

# again, run long-running tests here
```

which allows me to continue working on `feature-branch` without interruptions while the tests are being run on a frozen worktree, which eliminates a whole class of testing errors.
With a bit of conscientiousness, it also allows me to compare `feature-branch` to the latest revision that passed all the tests very easily.

Now, this workflow costs almost nothing for small projects, but for Nixpkgs, Firefox, or the Linux Kernel each worktree checkout takes quite a bit of space.
If you have dozens of feature-branches, then space usage can be quite horrifying.

But `hoardy` and `Emacs` can help!

`Emacs` with `break-hardlink-on-save` variable set to `t` (`M-x customize-variable break-hardlink-on-save`) will always re-create and then `rename` files when writing buffers to disk, always breaking hardlinks.
I.e., with it enabled, `Emacs` won't be overriding any files in-place, ever.
This has safety advantages, so that, e.g., power loss won't loose your data even if your `Emacs` happened to be writing out a huge `org-mode` file to disk at that moment.
Which is nice.
But enabling that option also allows you to simply `hoardy deduplicate` all source files on your filesystem without care.

That is, I have the above variable set in my `Emacs` config, I run

```bash
hoardy index ~/src/nixpkgs/* ~/src/firefox/* ~/src/linux/*
hoardy deduplicate ~/src/nixpkgs/* ~/src/firefox/* ~/src/linux/*
```

periodically, and let my `Emacs` duplicate files I actually touch, on-demand.

For `Vim`, the docs say, the following setting in `.vimrc` should produce the same effect:

```vimrc
set backupcopy=no,breakhardlink
```

but I tried it, and it does not work.

(You can try it yourself:

```bash
cd /tmp
echo test > test-file
ln test-file test-file2
vim test-file2
# edit it
# :wq
ls -l test-file test-file2
```

The files should be different, but on my system they stay hardlinked.)

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

# Frequently Asked Questions

## I'm using `fdupes`/`jdupes` now, how do I migrate to using `hoardy`?

- `hoardy find-dupes` usually produces the same results as `jdupes --recurse --zeromatch --order time`.

- `hoardy deduplicate --hardlink` is a replacement for `jdupes --recurse --zeromatch --permissions --order time --linkhard --noprompt`.

- `hoardy deduplicate --delete` is a replacement for `jdupes --recurse --zeromatch --permissions --order time --hardlinks --delete --noprompt`.

## I have two identical files, but `hoardy deduplicate` does not deduplicate them. Why?

By default, files must match in **everything but timestamps** for `hoardy deduplicate` to consider them to be duplicates.

In comparison, `hoardy find-duplicates` considers everything with equal `SHA256` hash digest and `size`s to be duplicates instead.

It works this way because `hoardy find-duplicates` is designed to inform you of all the potential things you could deduplicate while  `hoardy deduplicate` is designed to preserve all metadata by default (`hoardy deduplicate --hardlink` also preserves the original file `mtime` in the database, so it can be restored later).

If things like file permissions, owners, and groups are not relevant to you, you can run

```
hoardy deduplicate --ignore-meta path/to/file1 path/to/file2
```

to deduplicate files that mismatch in those metadata fields.
(If you want to control this more precisely, see [`deduplicate`'s options](#hoardy-deduplicate).)

If even that does not deduplicate your files, and they are actually equal as binary strings, extended file attributes must be different.
At the moment, if you are feeling paranoid, you will need to manually do something like

```
# dump them all
getfattr --match '.*' --dump path/to/file1 path/to/file2 > attrs.txt

# edit the result so that records of both files match
$EDITOR attrs.txt

# write them back
setfattr --restore=attrs.txt
```

after which `hoardy deduplicate --ignore-meta` would deduplicate them (if they are indeed duplicates).

(Auto-merging of extended attributes, when possible, is on the ["TODO" list](./CHANGELOG.md#todo).)

## What would happen if I run `hoardy deduplicate` with an outdated index? Would `hoardy` loose some of my files by wrongly "deduplicating" them?

No, it would not.

`hoardy` checks that each soon-to-be `deduplicate`d file from its index matches its filesystem counterpart, printing an error and skipping that file and all its apparent duplicates if not.

## I have two files with equal `SHA256` hash digests and `size`s, and yet they are unequal when compared as binary strings. Would `hoardy` "deduplicate" them wrongly?

No, it would not.

`hoardy` checks that source and target inodes have equal data contents before hardlinking them.

## What would happen if I run `hoardy deduplicate --delete` with the same directory given in two different arguments? Would it consider those files to be equivalent to themselves and delete them, losing all my data?

Nope, `hoardy` will notice the same path being processed twice and ignore the second occurrence, printing a warning.

## But what if I give the same directory to `hoardy deduplicate --delete` twice, but not as equivalent paths, but by giving one of them as a symlink into an ancestor of the other, followed by their common suffix? Will it loose my data now?

Nope, `hoardy` will detect this too by resolving all of its inputs first.

## Alright, but what if I `mount --bind` a directory to another directory, then `hoardy index` and run `hoardy deduplicate --delete` on both. The cloned directory will appear to be exactly the same as the original directory, but paths would be different, and there would be no symlinks involved. So `hoardy deduplicate --delete` would then detect them as duplicates and would need to delete all files from one of them. But deleting a file from one will also delete it from the other! Ha! Finally! Surely, it would loose my data now?!

Nope, `hoardy` will detect this and skip all such files too.

Before acting `hoardy deduplicate` checks that if `source` and `target` point to the same file on the same device then it's `nlinks` is not `1`.
If both `source` and `target` point to the same last copy of a file, it will not be acted upon.

Note that `hoardy` does this check not only in `--delete` mode, but also in `--hardlink` mode, since re-linking them will simply produce useless `link`+`rename` churn and disk IO.

**Actually, if you think about it, this check catches all other possible issues of "removing the last copy of a file when we should not" kind, so all other similar "What if" questions can be answered by "in the worst case, it will be caught by that magic check and at least one copy of the file will persist".**
And that's the end of that.

As far as I know, `hoardy` is the only tool in existence that handles this properly.

Probably because I'm rare in that I like using `mount --bind`s at `$HOME`.
(They are useful in places where you'd normally want to hardlink directories, but can't because POSIX disallows it.
For instance, `vendor/kisstdlib` directory here is a `mount --bind` on my system, so that I could ensure all my projects work with its latest version without fiddling with `git`.)
And so I want `hoardy` to work even while they are all mounted.

## Hmm, but `hoardy deduplicate` implementation looks rather complex. What if a bug there causes it to "deduplicate" some files that are not actually duplicates and loose data?

Firstly, a healthy habit to have is to simply not trust any one tool to not loose your data, make a backup (including of your backups) before running `hoardy deduplicate` first.

(E.g., if you are feeling very paranoid, you can run `rsync -aHAXiv --link-dest=source source copy` to make a hardlink-copy or `cp -a --reflink=always source copy` to make a reflink-copy first.
On a modern filesystem these cost very little.
And you can later remove them to save the space used by inodes, e.g., after you `hoardy verify`ed that nothing is broken.)

Secondly, I'm pretty sure it works fine as `hoardy` has quite a comprehensive test suite for this and is rather well-tested on my backups.

Thirdly, the actual body of `hoardy deduplicate` is written in a rather paranoid way re-verifying all assumptions before attempting to do anything.

Fourthly, by default, `hoardy deduplicate` runs with `--paranoid` option enabled, which checks that source and target have equal contents before doing anything to a pair of supposedly duplicate files, and emits errors if they are not.
This could be awfully inefficient, true, but in practice it usually does not matter as on a reasonably powerful machine with those files living on an HDD the resulting content re-checks get eaten by IO latency anyway.
Meanwhile, `--paranoid` prevents data loss even if the rest of the code is completely broken.

With `--no-paranoid` is still checks file content equality, but once per every new inode, not for each pair of paths.
Eventually `--no-paranoid` will probably become the default (when I stop editing all that code and fearing I would accidentally break something).

Which, by the way, is the reason why `hoardy deduplicate` looks rather complex.
All those checks are not free.

So, since I'm using this tool extensively myself on my backups which I very much don't want to later restore from their cold backups, I'm pretty paranoid at ensuring it does not loose any data.
It should be fine.

**That is, I've been using `hoardy` to deduplicate files inside my backup directories, which contain billions of files spanning decades, since at least 2020.**

So far, for me, bugs in `hoardy` caused **zero data loss**.

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

# Alternatives

## [`fdupes`](https://github.com/adrianlopezroche/fdupes) and [`jdupes`](https://codeberg.org/jbruchon/jdupes)

`fdupes` is the original file deduplication tool.
It walks given input directories, hashes all files, groups them into potential duplicate groups, then compares the files in each group as binary strings, and then deduplicates the ones that match.

`jdupes` is a fork of `fdupes` that does duplicate discovery more efficiently by hashing as little as possible, which works really well on an SSD or when your files contain very small number of duplicates.
But in other situations, like with a file hierarchy with tons of duplicated files living on an HDD, it works quite miserably, since it generates a lot of disk `seek`s by doing file comparisons incrementally.

Meanwhile, since the fork, `fdupes` added hashing into an `SQLite` database, similar to what `hoardy` does.

Comparing `hoardy`, `fdupes`, and `jdupes` I notice the following:

- **`hoardy` will not loose your data.**

  `hoardy` will refuse to delete a last known copy of a file, it always checks that at least one copy of content data of each file it processes will still be available after it finishes doing whatever it's doing.

  `fdupes` and `jdupes` will happily delete everything if you ask, and it's quite easy to ask accidentally, literally a single key press.

   Also, they will happily delete your data in some of the situations discussed in ["Frequently Asked Questions"](#frequently-asked-questions), even if you don't ask.

  Yes, usually, they work fine, but I recall restoring data from backups multiple times after using them.

- **Unlike with `jdupes`, filesystem changes done by `hoardy deduplicate` are atomic with respect to power being lost.**

  `hoardy` implements `--hardlink` by `link`ing `source` to a `temp` file near `target`, and then `rename`ing it to the `target`, which, on a journaled filesystem, is atomic.
  Thus, after a power loss, either the `source` or the `target` will be in place of `target`.

  `jdupes` renames the `target` file to `temp`, `link source target`, and then `rm temp` instead.
  This is not atomic.
  Also, it probably does this to improve safety, but it does not actually help, since if the `target` is open by another process, that process can still write into there after the `rename` anyway.

  `fdupes` does not implement `--hardlink` at all.

- **`hoardy` is aware of extended file attributes and won't ignore or loose them**, unless you specifically ask.

  Meanwhile, both `fdupes` and `jdupes` ignore and then usually loose them when deduplicating.

- **`jdupes` re-starts from zero it gets interrupted, while `fdupes` and `hoardy` keep most of the progress on interrupt.**

  `jdupes` has `--softabort` option which helps with this issue somewhat, but it won't help if your machine crashes or loses power in the middle.

  `fdupes` lacks hardlinking support, `jdupes` takes literally months of wall-time to finish on my backups, even with files less that 1 MiB excluded, so both tools essentially unusable for my use case.

  But, if you have a smallish bunch of files sitting on an SSD, like a million or less and you want to deduplicate them once and then never again, like if you are a computer service technician or something, then `jdupes` is probably the best solution then.

  Meanwhile, both `fdupes` and `hoardy index` index all files into a database once, which does take quite a bit of time, but for billion-file hierarchies it takes days, not months, since all those files get accessed linearly.
  And that process can be interrupted at any time, including with a power loss, without losing most of the progress.

- **Both `fdupes` and `hoardy` can apply incremental updates to already `index`ed hierarchies, which take little time to re-`index`, assuming file sizes and/or `mtime`s change as they should.**

  Except, `hoardy` allows you to optionally tweak its `index` algorithm to save bunch of disk accesses when run on file hierarchies where files only ever get added or removed, but their contents never change, which is common with backup directories, see [`hoardy index --no-update`](#hoardy-index).

  Meanwhile, `fdupes` does not support this latter feature and `jdupes` does not support database indexes at all.

- **`hoardy` can both dump the outputs of `find-dupes --print0` and load them back with `deduplicate --stdin0` allowing you to filter files it would deduplicate easily.**

  With small number of files you can run `xargs -0 fdupes`, `xargs -0 jdupes`, or some such, but for large numbers it won't work.

  The number of inputs you can feed into `hoardy` is limited by your RAM, not by OS command line argument list size limit.

  Neither of `fdupes` or `jdupes` can do this.

- **`hoardy deduplicate` can shard its inputs, allowing it to work with piles of files large enough so that even their metadata alone does not to fit into RAM**.

  Or, you can that feature to run `deduplicate` on duplicate-disjoint self-contained chunks of its database, i.e. "dedupicate me about 1/5 of all duplicates, please, taking slightly more than 1/5 of the time of the whole thing", without degrading the quality of the results.

  I.e., with `fdupes` and `jdupes` you can shard by running them on subsets of your inputs.
  But then, files shared by different inputs won't be deduplicated between them.
  In contrast, `hoardy` can do sharding by `SHA256`, which will result in everything being properly deduplicated.

  See [examples](#examples) below.

  Neither of `fdupes` or `jdupes` can do this.

- **Both `fdupes` and `hoardy` are faster than `jdupes` on large inputs, especially on HDDs.**

  Both `fdupes` and `hoardy deduplicate` use indexed hashes to find pretty good approximate sets of potential duplicates very quickly on large inputs and walks the filesystem mostly linearly, which greatly improves performance on an HDD.

  In practice, I have not yet managed to become patient enough for `jdupes` to finish deduplicating my whole backup directory once, and I once left it running for two months.

  Meanwhile, on my backups, `hoardy index` takes a couple of days, while `hoardy deduplicates` takes a couple of weeks of wall time, which can easily be done incrementally with sharding, see [examples](#examples).

  `fdupes` does not support hardlinking, and I'm not motivated enough to copy my whole backup hierarchy and run it, comparing its outputs to `hoardy deduplicate --delete`.

- **Also, with both `fdupes` and `hoardy` re-deduplication will skip re-doing most of the work.**

- **`hoardy deduplicate` is very good at RAM usage.**

  It uses the database to allow a much larger working set to fit into RAM, since it can unload file metadata from RAM and re-load it later from the database again at any moment.

  Also, it pre-computes hash usage counts and then uses them to report progress and evict finished duplicate groups from memory as soon as possible.
  So, in practice, on very large inputs, it will first eat a ton of memory (which, if it's an issue, can be solved by sharding), but then it will rapidly processes and discards duplicate candidates groups, making all that memory available to other programs rather quickly again.

  Meaning, you can feed it a ton of whole-system backups made with `rsync`spanning decades, and it will work, and it will deduplicate them using reasonable amounts time and memory.

  `fdupes` has the `--immediate` option which performs somewhat similarly, but at the cost of losing all control about which files get deleted.
  `hoardy` is good by default, without compromises.

  `jdupes` can't do this at all.

- Unlike `fdupes` and `jdupes`, `hoardy find-dupes` reports same-hash+length files as duplicates even if they do not match as binary strings, which might not be what you want.

  Doing this allows `hoardy find-dupes` to compute potential duplicates without touching the indexed file hierarchies at all (when running with its default settings), improving performance greatly.

  On non-malicious files of sufficient size, the default `SHA256` hash function makes hash collisions highly improbable, so it's not really an issue, IMHO.
  But `fdupes` and `jdupes` are technically better at this.

  `hoardy deduplicate` does check file equality properly before doing anything destructive, similar to `fdupes`/`jdupes`, so hash collisions will not loose your data, but `hoardy find-dupes` will still list such files as duplicates.

In short, `hoardy` implements almost a union of features of both `fdupes` and `jdupes`, with some more useful features on top, but with some little bits missing here and there, but `hoardy` is also **significantly safer to use than either of the other two**.

## [`RHash`](https://github.com/rhash/RHash)

`RHash` is "recursive hasher".

Basically, you give it a list of directories, it outputs `<hash digest> <path>` lines (or similar, it's configurable), then, later, you can verify files against a file consisting of such lines.
It also has some nice features, like hashing with many hashes simultaneously, skipping of already-hashed files present in the output file, and etc.

Practically speaking, it's usage is very similar to `hoardy index` followed by `hoardy verify`, except

- `RHash` can compute way more hash functions than `hoardy` (at the moment, `hoardy` only ever computes `SHA256`);

- for large indexed file hierarchies `hoardy` is much faster at updating its indexes, since, unlike plain-text files generated by `rhash`, `SQLite` databases can be modified easily and incrementally;

  also, all the similar `index`ing advantages from the previous subsection apply;

- `hoardy verify` can verify both hashes and file metadata;

- `hoardy`'s CLI is more convenient than `RHash`'s CLI, IMHO.

Many years before `hoardy` was born, I was using `RHash` quite extensively (and I remember the original forum it was discussed/developed at, yes).

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

- sharding:
  - `--shard FROM/TO/SHARDS|SHARDS|NUM/SHARDS`
  : split database into a number of disjoint pieces (shards) and process a range of them:
    
    - with `FROM/TO/SHARDS` specified, split database into `SHARDS` shards and then process those with numbers between `FROM` and `TO` (both including, counting from `1`);
    - with `SHARDS` syntax, interpret it as `1/SHARDS/SHARDS`, thus processing the whole database by splitting it into `SHARDS` pieces first;
    - with `NUM/SHARDS`, interpret it as `NUM/NUM/SHARDS`, thus processing a single shard `NUM` of `SHARDS`;
    - default: `1/1/1`, `1/1`, or just `1`, which processes the whole database as a single shard;

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

- sharding:
  - `--shard FROM/TO/SHARDS|SHARDS|NUM/SHARDS`
  : split database into a number of disjoint pieces (shards) and process a range of them:
    
    - with `FROM/TO/SHARDS` specified, split database into `SHARDS` shards and then process those with numbers between `FROM` and `TO` (both including, counting from `1`);
    - with `SHARDS` syntax, interpret it as `1/SHARDS/SHARDS`, thus processing the whole database by splitting it into `SHARDS` pieces first;
    - with `NUM/SHARDS`, interpret it as `NUM/NUM/SHARDS`, thus processing a single shard `NUM` of `SHARDS`;
    - default: `1/1/1`, `1/1`, or just `1`, which processes the whole database as a single shard;

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

- When you have enough indexed files that a run of `find-duplicates` or `deduplicate` stops fitting into RAM, you can process your database piecemeal by sharding by `SHA256` hash digests:
  ```
  # shard the database into 4 pieces and then process each piece separately
  hoardy find-dupes --shard 4 /backup
  hoardy deduplicate --shard 4 /backup

  # assuming the previous command was interrupted in the middle, continue from shard 2 of 4
  hoardy deduplicate --shard 2/4/4 /backup

  # shard the database into 4 pieces, but only process the first one of them
  hoardy deduplicate --shard 1/4 /backup

  # uncertain amounts of time later...
  # (possibly, after a reboot)

  # process piece 2
  hoardy deduplicate --shard 2/4 /backup
  # then piece 3
  hoardy deduplicate --shard 3/4 /backup

  # or, equivalently, process pieces 2 and 3 one after the other
  hoardy deduplicate --shard 2/3/4 /backup

  # uncertain amounts of time later...

  # process piece 4
  hoardy deduplicate --shard 4/4 /backup
  ```

  With `--shard SHARDS` set, `hoardy` takes about `1/SHARDS` amount of RAM, but produces exactly the same result as if you had enough RAM to run it with the default `--shard 1`, except it prints/deduplicates duplicate file groups in pseudo-randomly different order and trades RAM usage for longer total run time.

- Alternatively, you can shard the database manually with filters:
  ```
  # deduplicate files larger than 100 MiB
  hoardy deduplicate --size-geq 104857600 /backup
  # deduplicate files between 1 and 100 MiB
  hoardy deduplicate --size-geq 1048576 --size-leq 104857600 /backup
  # deduplicate files between 16 bytes and 1 MiB
  hoardy deduplicate --size-geq 16 --size-leq 1048576 /backup

  # deduplicate about half of the files
  hoardy deduplicate --sha256-leq 7f /backup
  # deduplicate the other half
  hoardy deduplicate --sha256-geq 80 /backup
  ```

  The `--shard` option does something very similar to the latter example.

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
