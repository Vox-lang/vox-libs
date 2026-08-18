# 314 — `voxlib-install`

**Status:** specified by TheJostler (2026-08-18). **Not started.** Spec only —
do not build from this yet.

**Repo:** vox-libs. Plan numbers are shared across the Vox project, so a
number means one thing whichever repo you are in; 312 and 313 are in the
compiler.

**Dependencies:** none. It builds against nothing but the compiler.

## Why this is not a compiler feature

Installing a library means knowing a distribution's directory layout,
holding root, and rewriting a file in place. A compiler that does any of
that has stopped being a compiler. `gcc` does not install libraries;
`make install`, `libtool`, and `pkg-config` do.

It would also undo a decision already taken: **the compiler must be
standalone from the standard library**, because a compiler that assumes a
package exists carries a circular dependency it can never pay off. Giving
`vox` a library-installation mode reintroduces exactly that coupling, and
bakes one directory convention into the compiler where today it is only a
convention in a Makefile.

So the knowledge lives where the libraries live. vox-libs ships a program.

## Why it is written in Vox, and uses no libraries

Written in Vox because a library installer is a real systems utility —
argument parsing, path arithmetic, binary file copy, in-place text
rewriting, and an `execve` — and Vox exists to prove it can write exactly
this. It is the first Vox program shipped as a system command.

**It links nothing.** Not textkit, not process, nothing. This is the
whole point: `voxlib-install` is what installs textkit, so it cannot
require textkit to run. A standalone static binary has no bootstrap order
to get wrong, no `LD_LIBRARY_PATH` to arrange, and works on a system where
no Vox library has ever been installed.

The price is real and should be planned for: every string operation —
finding a line, extracting a quoted path, taking a directory name, joining
two paths — is a byte loop written by hand. That is the bulk of the work
in this plan, and it is worth it.

## What it does

```
voxlib-install [options] <path/to/lib<name>.lib>
voxlib-install --remove <name>
```

Given the `.lib` a build has just produced, it installs the interface and
its shared object to their system locations and rewrites the interface so
it still points at its implementation.

### The problem it solves

A `.lib` is an interface file — the Vox equivalent of a `.h`. The compiler
emits it beside the `.so` and records where that `.so` was **relative to
the `.lib` itself**:

```
Library process version "0.1".
Location "./libprocess.so".

Table of Contents:
    To 'exit code of' with a number called status, returning a number.
    ...
```

Installing splits the pair — interface to `/usr/include/vox/`,
implementation to `/usr/lib64/` — so `./libprocess.so` stops resolving and
the installed library is unusable without a manual `--lib-path`. The fix
is to rewrite `Location` to the absolute installed path as the file is
copied, the way a `.pc` file gets its prefix substituted at install time.

### Steps

1. Read the `.lib`.
2. Parse `Library <name> version "<v>".` from the first line. **`<name>` is
   the authority on the library's name** — not the filename, which a user
   may have renamed.
3. Parse `Location "<path>".` and resolve it: absolute paths as given,
   relative paths against the directory holding the `.lib`.
4. Work out the destinations (see *Paths* below).
5. Copy the `.so` to `<libdir>/lib<name>.so`, mode 0755.
6. Write the `.lib` to `<incdir>/<name>.lib`, mode 0644, with the
   `Location` line replaced by the absolute installed `.so` path. Every
   other byte passes through untouched.
7. Run `ldconfig` so the dynamic linker can find the new object — unless
   `--destdir` was given, where the staged tree is not the running system's
   and indexing it would be wrong.
8. Print what was installed and where.

### Paths

| Option | Default |
|---|---|
| `--prefix DIR` | `/usr` |
| `--libdir DIR` | `<prefix>/lib64` when that directory exists, otherwise `<prefix>/lib` |
| `--incdir DIR` | `<prefix>/include/vox` |
| `--destdir DIR` | empty |

`--destdir` prefixes where files are **written** and is deliberately
excluded from the path recorded in `Location`: staging is a build-time
detail, not where the file will live. This is the same rule the Makefile
follows today, and it must stay the same rule, because the Makefile is
going to start calling this program instead of duplicating it.

The `lib64`/`lib` default is a guess and must be overridable — Fedora uses
`lib64`, Nix uses `lib`, Debian uses a triplet path. Guess by looking, not
by assuming.

### Other options

- `--dry-run` — print every action, change nothing. Should be the first
  thing implemented and the easiest thing to test.
- `--remove <name>` — delete `<incdir>/<name>.lib` and
  `<libdir>/lib<name>.so`, then `ldconfig`. Symmetry with `make uninstall`,
  and cheap once the path arithmetic exists.
- `--help`, `--version`.

## Failure behaviour

Every one of these must produce a clear message naming the path involved,
and a nonzero exit. None may leave a half-installed pair behind: copy the
`.so` first, write the `.lib` second, so a failure between the two leaves
an unreferenced object rather than an interface pointing at nothing.

- The `.lib` does not exist or cannot be read.
- The first line is not a `Library` declaration — refuse rather than guess
  the name.
- There is no `Location` line.
- The `.so` named by `Location` does not exist.
- The destination is not writable — the common case, a user who forgot
  `sudo`. Say so in those words: this will be the most-seen error the
  program ever produces.

## Packaging

A new subpackage, **`vox-libs-tools`**, carrying `%{_bindir}/voxlib-install`.

Per TheJostler's decision, the dependency runs **both ways**: `vox-libs`
requires `vox-libs-tools` and `vox-libs-tools` requires `vox-libs`, so
either name installs the pair. Both are built from the one spec file and
so always resolve in a single transaction; rpm handles the cycle.

- **`Makefile`** — build `tools/voxlib-install.vox` to
  `build/voxlib-install`, install it to `$(DESTDIR)$(PREFIX)/bin`. Then
  **delete the `sed` from the `install` target and call `voxlib-install`
  instead**, so the rewrite rule has exactly one implementation. Build the
  tool before the libraries; it depends on neither.
- **`vox-libs.spec`** — the subpackage, its `%files`, and the two
  `Requires`.
- **`flake.nix`** — install the binary into `$out/bin`.
- **`README.md`** — document it, and delete the "Current limitation" note
  about needing a path, which this closes.

## Acceptance

1. `make install DESTDIR=/tmp/stage` produces a tree in which
   `/tmp/stage/usr/include/vox/process.lib` records
   `Location "/usr/lib64/libprocess.so".` — the real path, not the staged
   one.
2. After a real `sudo make install`, a program in an unrelated directory
   compiles and runs with no `--lib-path`:
   ```sh
   vox demo.vox --link process -o demo && ./demo
   ```
   where `demo.vox` opens with `see process version "0.1" from
   "/usr/include/vox/process.lib".`
3. `voxlib-install --dry-run` on a built `.lib` prints the same
   destinations the real run uses, and creates nothing.
4. `voxlib-install --prefix /tmp/p1 --libdir /tmp/p1/lib` honours both, and
   the recorded `Location` reads `/tmp/p1/lib/libprocess.so`.
5. `voxlib-install --remove process` leaves neither file behind and exits 0;
   removing a library that is not installed exits nonzero with a clear
   message.
6. Running it as a non-root user against `/usr` fails with a message that
   names the path and says it is not writable. It does not print a stack
   trace, a raw errno, or nothing at all.
7. The `.so` survives byte-for-byte: `cmp` the installed object against the
   built one. A binary copy done through a text path would corrupt it, and
   this is the check that catches that.
8. `ldconfig -p | grep libprocess` finds it after a real install.
9. Every byte of the `.lib` other than the `Location` line is unchanged:
   `diff` the built and installed interfaces and confirm exactly one line
   differs.

## Notes for whoever builds this

- Verify how Vox reads a file of unknown size into a buffer before
  designing the copy — the `.so` is binary and must not go through any
  text conversion. Prove acceptance test 7 early; it constrains the design.
- Prove `Execute` of `/sbin/ldconfig` works from a Vox program, and decide
  what to do when it is absent (a warning, not a failure — the install
  itself succeeded).
- Follow `docs/STYLE.md` in the compiler repo. Names are the thing's true
  name: `the interface path`, `the recorded location`, not `p` or `buf`.
- The compiler repo is not to be modified from this work.
