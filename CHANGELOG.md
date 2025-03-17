# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Also, at the bottom of this file there is a [TODO list](#todo) with planned future changes.

## [v0.0.1] - 2024-09-04

### Added

- Initial stub.

[v0.0.1]: https://github.com/Own-Data-Privateer/hoardy/releases/tag/v0.0.1

# TODO

- Database format `v4`, to save lots of database space.
- Import filtering and streaming machineries from `hoardy-web` into here.
- Add a bunch more file filters, replacing `find`.
- Allow databases be per-directory.
- Add merging and splitting of databases.
- Add slurping of `RHash` outputs.
- Add optional indexes.
- Add support for `.gitignore` and similar.
- Make a subcommand for automated metadata and extended file attribute merges.
- Implement metadata smearing across different copies for, e.g., propagating file permissions across copies.
- Add duplicate directory discovery, i.e., recognize when whole directories are equal by using Merkle-trees.
- Allow to record and process more metadata, like `uid`s, `birthtime_ns`, etc.
- `--shard` automatically, by querying available RAM.
- Record paths to broken files in the database and allow them to be queried.
- Allow disabling of the sharding stage, which would improve performance of file-only pre-grouped `--stdin0` inputs.
- Handle file renames without re-hashing.
- Replace `rsync` on my use cases.
- Replace `git-annex` on my use cases.
- Replace `Perkeep` on my use cases.
