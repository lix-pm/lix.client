# Changelog

## 17.0.3 - 2026-07-18

### Added

- `lix dev` writes a `# @run: haxelib run-dir ...` directive when the library has a `main` field or a `run.n` file

### Fixed

- (haxeshim) `haxelib run` for Haxe `--run` mains now resolves `-lib <name>` like upstream haxelib

## 17.0.2 - 2026-07-05

### Fixed

- (haxeshim) `haxelibshim` honors leading `--cwd` / `-cwd` / `--global` and forwards raw args when falling back to real haxelib

### Changed

- `lix run` and library-run paths pass raw args through to `HaxelibCli.run` so flag handling can match haxeshim

## 17.0.1 - 2026-07-02

### Fixed

- GitHub source lookup casts credentials with `.toString()` so nullable abstract string interpolation works

## 17.0.0 - 2026-07-02

### Added

- (haxeshim) support for Haxe `--server-connect` (alongside existing `--wait`) via updated compiler-server handling

Major version bump from updating the haxeshim pin (`138172e` → `8ba24a2`).
