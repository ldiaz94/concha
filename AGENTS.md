# Working on concha

concha is a Unix shell whose scripting language is Pascal, written in
[raz](https://raz.lucela.org). Read `CONTRIBUTING.md` first: defects and
documentation fixes are offered as GitHub issues, not pull requests; a
fix comes only after the defect is agreed, you sign off (DCO), and a tool
such as an AI model only helps you, you answer for every line.

## What defines behaviour

The manual pages (`doc/concha.1`, `doc/concha-complete.5`,
`doc/concha-tutorial.7`) and `README.md`. `doc/internals.md` tells how
the code is built. A defect is concha doing other than they say. What is
left out on purpose is under **Left out** in the `README.md`.

## Build and check

    make            # build/concha, with -Werror
    make test       # tests/test.cn under build/concha, the examples (concha -n), the man pages through groff
    make fmt        # src/ and tests/Play.raz are laid out as raz's formatter lays them out

The program builds with the raz named by `RAZVERSION` in the `Makefile`
(0.25.0); `make` warns of any other. `make test` and `make fmt` must
pass. The formatter is `Pretty.raz` from that raz's `tools/`.

## Layout

- `src/`: one module per job, each named with a `C`: `Ccore`, `Csyntax`,
  `Cedit`, `Cinterp`, `Concha` (the main module), and the parts of the
  interpreter that depend on the rest one way only: `Cvars`, `Cglob`,
  `Cclock`, `Ccomplete`, `Cfuzzy`.
- `tests/test.cn`: the tests, a concha script. A fix adds a case there.
- `examples/`: scripts that must pass `concha -n`.
- `doc/`: the manual pages and `internals.md`.

## Conventions

- The language concha takes stays as it is: existing scripts must keep
  working, and the `-q` queries (read by editor tooling) keep their
  output. A change to either is made on purpose and listed in
  `doc/internals.md`.
- Idiomatic raz: an error is an `ERROR` passed on with `try`, strings
  are `[]U8`, growable arrays are `Vec`; procedures and variables are
  `lowerCamel`, types and modules `Capitalised`. Follow raz's
  `STANDARDS.md`.
- Readability first: each module opens with a comment saying what it
  is, what it depends on and what it leaves out; every procedure, type
  and field has a short plain comment; comments say why. A comment must
  not hold `*)`.
- Keep procedures short, one job each.
- A change to what concha does updates the manual page and `README.md`
  in the same patch.
