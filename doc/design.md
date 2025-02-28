# Design principles

- When it's a choice, `hoardy` is designed to be usable with simple files living on a simple filesystem.

  I.e., it will never **require** you using it to take over (a part of) a filesystem, or delegate things to an HTTP-only interface, like many other similar tools do.

  Though, some features of that kind will be optionally supported in the future, but they will be just that, **optional**.

- When it's a choice, `hoardy` is designed to, by default, consume the least amount of disk space, not to be as fast as possible.

  Most other tools do exactly the opposite, wasting disk space to improve performance when possible, but I prefer to use disk space to store more **data** instead.
  So, if a tool uses too much disk space I usually find myself uninstalling it and falling back to simpler things.
  `hoardy` is designed with that in mind.

  Speed-ups using optional indexes will be supported in the future, but they will be just that, **optional**.

  Current pie-in-the-sky target is to use less than 5% of additional disk space to implement all basic slow version of all `hoardy` subcommands.

  In contrast, most file indexing tools consume 50% or more additional disk space.

- When it's a choice, `hoardy` is designed to use interval logic and arithmetic.

  E.g., `2024-01-01` looks like a timestamp, but it's not, it's a time interval between `2024-01-01 00:00:00.000(0)--2024-01-02 00:00:00.000(0)` (the latter timestamp not included).
  Doing things this way simplifies many things.

- When it's a choice, `hoardy` is designed to use Bayesian and multi-valued logics.

  E.g., a tag system, when implemented, will be a "certainly yes, certainly no, probability" system, not just Boolean.

  Which actually has nice implications for index disk space usage, since this allows for latent variables, which can be stored instead.

- When it's a choice, `hoardy` is designed to be used as a library.

# Wishlist

In short, I think this world needs yet another alternative to [syncthing](https://syncthing.net/), [`git-annex`](https://git-annex.branchable.com/), [bup](https://bup.github.io/), [Perkeep](https://perkeep.org/), and [`libchop`](https://www.nongnu.org/libchop/), but with [rsync](https://rsync.samba.org/) and a Bayesian alternative to [recoll](https://www.lesbonscomptes.com/recoll/index.html) on top.

I.e., the target state of this thing is

- a network- and sub-file-of-arbitrary-depth-transparent filesystem-independent filesystem-equivalent;

  that is, it should support all of:

  - rendering queries into lists of matching paths/URLs;

    a-la `recoll`;

  - rendering queries into filesystem trees, i.e. generation of directory trees with hardlinks/symlinks of files pointing to original indexed files, but using filenames in specified format,

    a-la `git annex view`, but without needing to fiddle with `git` `branch`es and `worktree`s;

  - `HTTP`/`WebDAV`/`FUSE`/`SFTP` interfaces with on-demand generation of such,

    a-la `Perkeep`;

- with full-text and structural Bayesian indexing and search;

  a-la `recoll`, but Bayesian;

- with rule-based file deduplication and replication;

  a-la `git annex vicfg`, `rsync --filter`, and `syncthing`'s config;

- which should also allow logical and physical representation of files to be different;

  kind of like `Perkeep` does, but with most of its design choices reversed, to make something closer to `git` instead;

  i.e., by default, it would mostly store raw files, while improving storage efficiency by arbitrary-depth deduplicating things, applying `xdelta`, and compressing;

  chopping files into tiny pieces and deduplicating those is also useful, sometimes, and should be supported, eventually, but that should only be applied on case-by-case basis, IMHO, as otherwise things usually actually get worse, storage-wise;

  filesystems suck at storing small files, thus `Perkeep` and similarly-designed tools like `libchop` shoot themselves in the foot by doing this, since they have to then pack those tiny pieces back into files to store them efficiently on disk

  - to which my reaction is "Why not just store the original files, optionally compressed, instead!?",
  - to which they would say "But duplicated blocks would be duplicated on disk!"
  - to which I would say "Sure, but xdelta!"
  - to which they would say "But then, the xdelta-ed files are not raw files anymore, anyway!"
  - to which I would say "Well, yes, but the xdelta source files are still raw. So, select the most compressed, most conveniently accessible, or most frequently used copy as the source and xdelta everything else against it instead of re-creating all files from their pieces all the time."

I.e. it should be able to do things like:

- generate me a tree of hardlinks to all known MP3 and FLAC files on this machine, put them under `~/music`, name them `<artist>/<album>/<title>.<ext>`;

  now, if the original files live under `~/unsorted`, remove those;

- find me all EPUB files authored by `John Smith` containing the word `sympathetic` or something close with 95% confidence and not tagged as "junk", including those stored in archive files, email attachments, [`hoardy-web`](https://oxij.org/software/hoardy-web/), [`mitmproxy`](https://github.com/mitmproxy/mitmproxy), [`hoardy-adb`](https://oxij.org/software/hoardy-adb/) captures, my other computers, etc, and make me a dynamic FUSE mountpoint for accessing all of them as if they were simple plain files, transparently unpacking them from archives, or fetching them from other computers on-demand;

- replicate that set of files to all of my machines, and keep replicating newly added files matching these criteria as they get added to the index;

- but, when replicating, do it efficiently: e.g., if a given file is already present on the destination in an archive there, reuse that;

- replicate a given filesystem tree to another machine, except not like `rsync` does it (by sending a flat list of files and missing file content suffixes), instead, first send all file data missing on the destination (efficiently! reusing whatever that host already has) and then re-create the tree by reconstructing it using Merkle-trees (similarly);

- deduplicate my files to arbitrary depth: i.e., if some of my saved booru images are also present in some of my EPUB files (as covers or illustrations), allow me to delete the former from disk, but also make me a FUSE mountpoint equivalent to my original booru dumping directory where such images are still accessible by transparently re-creating those images from my EPUBs on-demand, but also ensure that each logical file has at least 3 separate physical copies, unless tagged as "junk";

- make me a FUSE mountpoint equivalent to my `Maildir`, but, on disk, store my RFC822 message bodies and attachments in separate compressed block-deduplicated files and only re-create my RFC822 messages with their `base64`-encoded attachments on-demand with a bit of LRU caching to make it both disk-efficient and fast-enough, while also ensuring that no files actually change while going through such a transformation.

If you want to have most of the above now, use [Perkeep](https://perkeep.org/).
I can do 80% of the above, it's cool, it's just the way it does things annoys me greatly.
