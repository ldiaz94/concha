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
  all, the shell itself running on in the child. `Ckern` has `fork`,
  `exec` and `dup2`, 40 lines. Exposing these three in `Sys` would
  serve any shell, `make`, or an init.
- **No handler for a signal.** `Sys.catch` gives signals on an fd, the
  right thing for a program built round a loop of `readyOf`. But a
  shell blocked in `wait4` for its foreground program, or in `read`
  for a key, must see Ctrl-C at once, and a blocked signal can't break
  either call; nor would polling the fd before each statement be
  cheap. `Ckern.handle` installs a handler with `rt_sigaction`, without
  `SA_RESTART`, and its own copy of `Rt`'s `sigReturn`: 15 lines. A
  `Sys.handle(sig, proc(sig: INT))` would do.
- **`Sys.wait` always reports a stopped child** (`WUNTRACED`), so
  concha's `wait` builtin, which waits for a job to end, has its own
  `Ckern.wait` with the options as `wait4` takes them.

## The language

- **A slice's pointer can't be had.** The report gives a slice's
  layout, `ptr` and `len`, but only `LEN` reaches it; `ADR(s[0])` is
  the pointer, and fails its check when `s` is empty. `Ccore` keeps a
  value as a kind, a length and a pointer, as the Pascal did, and each
  place that makes one from a `Buf` or a `Vec` tests for the empty one
  first (`bufVal`, `listVal`). A `PTR(s)`, `nil` for the empty slice,
  would do.
- **A conversion takes no selector.** `^Val(v.p)[0..n]` doesn't parse,
  since `^T(x)` is a factor and not a designator; it takes a local
  pointer first (`Ccore.items`).
