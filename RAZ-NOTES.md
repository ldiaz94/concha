# What raz lacks, or makes awkward

Found while porting concha from Free Pascal, for raz's owner. Each says
what was wanted, what concha does instead, and how much it cost.
`~/r/sauce/RAZ-NOTES.md` has what the port before this one found.

## The library

- **No fork and exec.** `Sys.spawn` starts a program with three
  descriptors and a process group, which is what most programs want;
  a shell wants more between the fork and the exec: any descriptor
  redirected (`3>&1`, `2>&1`), the signals a trap ignores kept
  ignored, and, for a stage of a pipe that is a procedure, no exec at
  all, the shell itself running on in the child. raz after 0.15.0 has
  `Sys.exec`, `dup`, `dupTo` and `Program.more`; `fork`, and a copy of
  an fd at 10 or above (`Ckern.dupAbove`), are proposed in raz's
  `PROPOSALS.md`, "What a shell still needs of `Sys`".
- **No handler for a signal.** `Sys.catch` gives signals on an fd, the
  right thing for a program built round a loop of `readyOf`. But a
  shell blocked in `wait4` for its foreground program, or in `read`
  for a key, must see Ctrl-C at once, and a blocked signal can't break
  either call; nor would polling the fd before each statement be
  cheap. `Ckern.handle` installs a handler with `rt_sigaction`, without
  `SA_RESTART`, and its own copy of `Rt`'s `sigReturn`: 15 lines.
  Proposed as `Sys.handle`, with `Sys.group` (`getpgrp`).
- **`Sys.wait` always reports a stopped child** (`WUNTRACED`), so
  concha's `wait` builtin, which waits for a job to end, has its own
  `Ckern.wait`. Not needed: a stop is reported once, so the builtin
  can wait again after one; and `Sys.wait` already takes `-g` for a
  group, which the proposal asks the doc to say.

## The language

- **A slice's pointer can't be had.** The report gives a slice's
  layout, `ptr` and `len`, but only `LEN` reaches it; `ADR(s[0])` is
  the pointer, and fails its check when `s` is empty. `Ccore` keeps a
  value as a kind, a length and a pointer, as the Pascal did, and each
  place that makes one from a `Buf` or a `Vec` tests for the empty one
  first (`bufVal`, `listVal`). Proposed as `PTR(s)` in raz's
  `PROPOSALS.md`, "A slice's pointer".
