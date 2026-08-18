# Changelog

All notable changes to vox-libs are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/). This version covers
the collection as a package; each library also carries its own `Library
<name> version "x.y".` declaration, which is what a consumer's
`see ... version ... from` matches against.

## [0.1.0] - 2026-08-18

The seed release: the first two Vox libraries move into their own home.

### Added

- **textkit** (library version 0.1, from the voxos project) — substring,
  search, trim, case, and tokenizing over Vox's text type: the byte loops
  every Vox author would otherwise hand-roll, packaged once behind
  text-in/text-out signatures. Positions are 1-indexed and byte-oriented,
  matching `byte N of` and `element N of`.
- **process** (library version 0.1, from the vox compiler repo) — decodes
  the raw wait-status word that `the reaped status` returns, with four
  functions matching the `<sys/wait.h>` macros: `'exit code of'` (bits
  8–15), `'signal of'` (the low 7 bits), `crashed`, and
  `'exited normally'`. Moved here because the compiler ships no libraries:
  `the reaped status` is complete on its own, and Vox deliberately has no
  standard library.
- **Build and install machinery** following the C model: `make` compiles
  each library with vox `--shared` into a `.so` with its `.lib` interface
  beside it; `make install` places interfaces in `/usr/include/vox/`
  alongside the system headers and shared objects in `/usr/lib64/` where
  ldconfig indexes them. `PREFIX`, `DESTDIR`, `LIBDIR`, and `INCDIR` are
  honoured so rpm, Nix, and a plain install drive the same rules.
- **Per-library demo tests**: each library's `<name>_demo.vox` compiles
  against the built `.so` and its output is diffed against
  `<name>_demo.expected` by `make test`.
