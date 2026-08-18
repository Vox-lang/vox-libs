# vox-libs

Shared libraries for [Vox](https://github.com/Vox-lang/vox), written in Vox.

**Vox has no standard library, and that is deliberate.** The compiler
builds and runs with nothing installed here — it must never assume a
package exists, or the language would carry a circular dependency it
could never pay off. These are ordinary libraries you choose to install,
exactly like any C library you link against.

They follow the C model, because Vox already had its shape: an interface
is separate from its implementation. A library ships a `.lib` interface —
the type information a compiler can check a call against — and a `.so`
holding the code. Interfaces install alongside the system headers in
`/usr/include/vox/`; shared objects install alongside every other shared
object in `/usr/lib64/`, where `ldconfig` can index them.

## Libraries

| Library | What it does |
|---|---|
| **textkit** | Substring, search, trim, case, and tokenizing — the byte loops every Vox author would otherwise hand-roll. |
| **process** | Decodes a raw wait status into an exit code or terminating signal, the way `<sys/wait.h>` does for C. |

Each library carries its own version and moves on its own clock; the
compiler's version does not drag them along.

## Building and installing

```sh
make                 # build every library into build/
make test            # compile each demo against its library and diff the output
sudo make install    # .lib -> /usr/include/vox, .so -> /usr/lib64
```

`PREFIX` and `DESTDIR` are honoured, so distribution packaging drives the
same rules rather than inventing its own layout:

```sh
make install PREFIX=/usr/local
make install DESTDIR=/tmp/stage PREFIX=/usr
```

If you are building against a Vox you compiled yourself rather than an
installed one, point the compiler at its own runtime — otherwise an
installed `/usr/share/vox/coreasm` silently shadows it:

```sh
make VOX=../vox/target/release/vox VOX_CORE_PATH=../vox/coreasm
```

## Using a library

```vox
see process version "0.1" from "./libprocess.lib".

a number called 'a clean exit' is 1792.
Print "exit code: {'exit code of' of 'a clean exit'}".
```

```sh
vox yourprogram.vox --link process --lib-path build -o yourprogram
```

`--link` names a library and `--lib-path` adds a search directory —
deliberately the same shape as `gcc -lprocess -Lbuild`.

**Current limitation.** A `.lib` records the location of its `.so` as it
stood at build time, so a `see ... from` needs a path that resolves from
where you are compiling. Resolving an installed library by bare name —
the equivalent of `#include <sys/wait.h>` — is being designed; see the
Vox repo. Until then, give the path.

## Adding a library

One directory per library, named after it, containing `<name>.vox` with a
`Library <name> version "x.y".` declaration on the first line. A
`<name>_demo.vox` and `<name>_demo.expected` beside it become its test.
Add the name to `LIBS` in the Makefile.

Code follows the Vox style guide: names are the thing's true name, and a
line should read aloud as English.

## Licence

GPLv3 — see [LICENSE](LICENSE).
