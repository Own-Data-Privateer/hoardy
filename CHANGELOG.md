# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Also, at the bottom of this file there is a [TODO list](#todo) with planned future changes.

## [v0.2.0] - 2025-03-31

### Changed

- `find-duplicates`, `deduplicate`:

  - Changed the meaning of `--shard NUM/SHARD` to mean `--shard NUM/NUM/SHARD` instead of the previous `--shard NUM/SHARD/SHARD`.

    I.e. `--shard NUM/SHARD` syntax now means "process the shard number `NUM`", not "process all shards starting from `NUM`".

    The previous interpretation was too surprising.

  - Improved performance, especially when feeding `INPUT`s with `--stdin0`.

- `*`:

  - Improved symlink resolution in `INPUT`s.

    From now on, `hoardy` will only follow symlinks in `dirname` parts of in given `INPUT`s, which allows all subcommands to properly work with paths that point to symlink inodes.

    The exception to this are `find-duplicates --stdin0` and `deduplicate --stdin0` which skip all path resolutions on all paths given via the stdin, because, otherwise, program performance in most common use cases becomes absolutely awful.

  - Improved error handling.

  - Improved log messages.

- Improved documentation.

### Fixed

- `index`:

  - Fixed `--no-add` and `--no-update` `stat`ting too much.

    E.g., `hoardy index --no-update` should not `stat` any known files at all now.

    This is how it was supposed to work, but I broke it while refactoring in 0caacc0730b23c33e597bc5fd0b7600073cdbc16.

## [v0.1.0] - 2025-03-17

### Added

- Published a minimal valuable version.

### Removed

- Removed the stub.

## [v0.0.1] - 2024-09-04

### Added

- Initial stub.

[v0.2.0]: https://github.com/Own-Data-Privateer/hoardy/compare/v0.1.0...v0.2.0
[v0.1.0]: https://github.com/Own-Data-Privateer/hoardy/compare/v0.0.1...v0.1.0
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
