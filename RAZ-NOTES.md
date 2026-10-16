# What raz lacks, or makes awkward

Found while porting concha from Free Pascal, for raz's owner. Each says
what was wanted, what concha does instead, and how much it cost.
`~/r/sauce/RAZ-NOTES.md` has what the port before this one found.

## The library

- **What a shell needs of `Sys`**, fork and exec, moving fds, a
  handler for a signal, a terminal's modes for each job, the process
  group and the rest, was proposed in two parts and is in raz 0.16.0;
  `Ckern` went with it.

## The language

- **A slice's pointer can't be had.** The report gives a slice's
  layout, `ptr` and `len`, but only `LEN` reaches it; `ADR(s[0])` is
  the pointer, and fails its check when `s` is empty. `Ccore` keeps a
  value as a kind, a length and a pointer, as the Pascal did, and each
  place that makes one from a `Buf` or a `Vec` tests for the empty one
  first (`bufVal`, `listVal`). Proposed as `PTR(s)` in raz's
  `PROPOSALS.md`, "A slice's pointer".
- **An empty slice has no literal.** `nil` is for pointers, procedures
  and `ERROR`s, so a procedure returning a slice and an error declares
  a variable to return as the empty slice beside the error (`none` in
  `Csyntax`, six times), as `Vec.all` does. `return nil, err` would
  read better; a cost of a line each.
- **No `continue`.** The Pascal's loops that skip ahead (`;` between
  statements, a comment in a command) become `if ... elsif` chains in
  `Csyntax`; one, in `interpolate`, reads `elsif (c # '$') or not try
  dollar(...)`, which `continue` would have said more plainly. Cheap.
