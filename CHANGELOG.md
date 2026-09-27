# Changelog

All notable changes to vox-libs are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/). This version covers
the collection as a package; each library also carries its own `Library
<name> version "x.y".` declaration, which is what a consumer's
`see ... version ... from` matches against.

## [0.3.0] - unreleased

### Added

- **textkit** (library version 0.2) — three exports make it a general
  tokenizer rather than one that only splits on whitespace: `'split on'`
  splits a text on any separator (empty fields kept, a trailing separator
  yields a trailing empty field, an empty separator returns the text
  unsplit), `'split lines'` splits on `\n` with a preceding `\r` dropped
  and no trailing empty element from a final newline, and `replace`
  replaces every non-overlapping occurrence of a needle left to right. The
  0.1 exports are unchanged in name and behaviour, and `join` is `'split
  on'`'s inverse, the tests say so with a round trip. `textkit/textkit_tests.vox`
  ships 22 such assertions, in the json pattern.

### Changed

- **json** test and demo fixtures — register entry #111 (fixed in vox
  0.4.15) made storing a collection into, or reading one out of, another
  collection copy it rather than alias it. Two consequences, both in the
  fixtures rather than in `json.vox` itself, which is untouched:
  - A map or list can no longer hold itself, so there is nothing left for
    the depth guard to catch on that front. Removed the two self-holding
    test claims from `json/json_tests.vox` and the self-holding
    demonstration from `json/json_demo.vox` (keeping its `ten deep` line
    and `--- depth ---` heading), each with a one-sentence comment saying
    why. Both fixtures' `.expected` transcripts are updated to match —
    `json_tests.expected` now reads 148 assertions, 0 failures, and
    `json_demo.expected` drops the one line that reported a byte count
    for a map that no longer holds itself.
  - `json_demo.vox`'s `tags`, read out of `person` before being appended
    to, is its own copy: the demo now sets `person`'s `"tags"` back to
    the grown list, with a comment saying why, so the written document
    still shows all three tags as it always did — no `.expected` change
    needed for that part.

## [0.2.0] - 2026-08-23

### Added

- **json** (library version 0.1) — full JSON serialisation and
  deserialisation, written in Vox: `'to json'` builds the JSON text for any
  value and `'from json'` builds the value for a JSON text, the pair Python
  spells `dumps` and `loads`. The two shapes correspond one for one — object
  to map, array to list, string to text, number to number or decimal, true
  and false to boolean, null to nothing — so a document read in is an
  ordinary Vox map you can index, change, and write back out unchanged. The
  reader follows JSON's grammar rather than a looser reading of it: a
  leading zero, a trailing comma, an unquoted key, a lone surrogate, a raw
  control byte in a string and text left over after the document are all
  refused rather than guessed at, and nesting stops at 64 levels instead of
  running the stack out. Escapes are exact in both directions, `\uXXXX`
  included, with a surrogate pair read back as the one character it stands
  for. A third export, `'reads as json'`, answers whether a text is one
  complete document — needed because `nothing` is the honest answer both for
  a malformed document and for `null`, and because on vox 0.4.10 the error
  flag a shared library raises does not reach the calling program. A fourth,
  `'to json with indent'`, writes the same document laid out to be read —
  each member on its own line, indented per level, a space after each colon
  — matching `json.dumps(indent=n)` byte for byte, while `'to json'` stays
  compact.
- **Per-library unit tests**: a library may ship
  `<name>/<name>_tests.vox`, a program of named assertions that prints only
  its headings and a tally and exits non-zero when a claim does not hold.
  `make test` runs it beside the demo and checks it twice over — the exit
  status and the recorded transcript — so a library gates itself in this
  repo rather than only being demonstrated. json ships 150 such assertions.

### Changed

- `make test` now labels its lines `PASS <lib> demo` and `PASS <lib> tests`
  rather than `PASS <lib>`, since a library can now be checked two ways.

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
