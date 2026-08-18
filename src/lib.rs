//! Distribution vehicle for the Vox-language libraries, not a Rust library.
//!
//! The payload of this crate is the `.vox` source under `textkit/` and
//! `process/`, compiled by the [vox](https://crates.io/crates/vox) compiler
//! into `.so`/`.lib` pairs via the bundled `Makefile`:
//!
//! ```sh
//! make            # build every library into build/
//! make test       # compile each demo against its library, diff the output
//! sudo make install
//! ```
//!
//! Vox itself has no standard library, deliberately — the compiler never
//! assumes these are installed. They are ordinary libraries you choose to
//! build and link, the way you would any C library.
