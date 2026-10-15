# Working on concha

concha is a Unix shell whose scripting language is Pascal, written in
raz. It is being ported from Free Pascal (`~/lib/concha`, frozen at
`8eb7b3d`: never work there). Read `PLAN.md` first: the port, a module
to a step, and the handover that replaces the Pascal concha. The
language is defined by raz's report (`man raz`, `~/r/raz/doc/raz.md`,
the library `~/r/raz/doc/raz-lib.md`); the program builds with the raz
on PATH, of the version `RAZVERSION` in the Makefile says. `~/r/sauce`
is the port before this one, and the model for it.

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
  output, which concha-lsp reads. A difference is a bug, unless
  `PLAN.md` lists it as meant.
- Modules keep the Pascal units' jobs and order, each named with a `C`:
  `Ckern`, `Ccore`, `Csyntax`, `Cedit`, `Cinterp`, `Concha`; `Cfuzzy`
  and `Czone` are what the Pascal took from outside (fuzzy(3), hora(3)).
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
