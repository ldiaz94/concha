# Working on concha

concha is a Unix shell whose scripting language is Pascal, written in
raz. It was ported from Free Pascal (`~/lib/concha`, frozen at
`8eb7b3d`: never work there); `doc/internals.md` tells its insides. The
language is defined by raz's report (`man raz`, `~/r/raz/doc/raz.md`,
the library `~/r/raz/doc/raz-lib.md`); the program builds with the raz
on PATH, of the version `RAZVERSION` in the Makefile says.

## Setup and checks

    make            # build/concha
    make test       # tests/test.cn under build/concha, the examples, the man pages
    make fmt        # src/ is laid out as raz's formatter lays it out
    make install    # ~/.local (PREFIX=...)

`make fmt` must pass before every commit, and the build with
`-Werror`; `make test` too, once the program runs.

## How we work

- The language concha takes stays what it is: every script and
  `~/.concharc` must keep working, and the `-q` queries keep their
  output, which concha-lsp reads. A change to it is made on purpose
  and listed in `doc/internals.md` ("From the Pascal").
- Modules keep the Pascal units' jobs and order, each named with a `C`:
  `Ccore`, `Csyntax`, `Cedit`, `Cinterp`, `Concha`; `Cfuzzy`
  is what the Pascal took from fuzzy(3), and local time, hora(3)'s
  part, is rzone's `Zone` (`~/r/rzone`, installed in `~/.raz/lib`);
  `Cvars`, `Cglob`, `Cclock` and `Ccomplete` are the parts of
  `interp.pas` that depend on the rest one way only.
- Idiomatic raz, not Pascal transcribed: an error is an `ERROR`
  passed on with `try`, strings are `[]U8`, growable arrays are `Vec`,
  procedures and variables are `lowerCamel`, types `Capitalised`
  without Pascal's `T`.
- Readability first. Each module opens with what it is, what it
  depends on and what it leaves out; comments say why. A comment must
  not hold `*)`.
- What raz lacks, or makes awkward, goes in `RAZ-NOTES.md`, for raz's
  owner; it is not worked around quietly.
- Commits: author `Luis <42945842+ldiaz94@users.noreply.github.com>`,
  unsigned (`--no-gpg-sign`), no attribution trailer. Pushed to `main`
  of `ldiaz94/concha` once that repository exists. No pull requests
  unless asked.
