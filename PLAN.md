# Plan: concha in raz, and the handover

## The port

One step at a time, bottom up, each committed when it compiles with
`-Werror`, is laid out as `make fmt` wants, and does what its Pascal
unit does. A step that is too big to read in one sitting is split
before it is started, not after.

- [x] 1. `Ckern`: the system calls `Sys` lacks (fork, exec, `dup2`
      and a copy above 10, signal handlers, the terminal's settings,
      the process group, umask, resource limits, `access`, `wait4`
      with its options). Of `kern.pas`, what `Sys` has (the terminal's
      size and owner, `setpgid`, `chdir`, `getcwd`, the time) is
      `Sys`'s.
- [ ] 2. `Ccore`: the arena, values, errors, output, files, the
      distance between two names.
- [ ] 3. `Csyntax`: scanner, parser, syntax tree, and the notes the
      queries read (`-q outline`, `words`, `def`).
- [ ] 4. `Cfuzzy` and `Czone`: wuzzy's matcher (`fuzzy.pas`, 120
      lines), and hora's offset and abbreviation at an instant, by
      `TZ` or `/etc/localtime` (TZif files and POSIX TZ strings; sauce's
      `Sbase` reads the offset alone).
- [ ] 5. `Cedit`: the line editor, history, highlighting, the menu.
- [ ] 6. `Cinterp`, 3,400 lines of Pascal, in four steps, each
      compiled: (a) variables, expressions, statements, procedures;
      (b) words, expansion, redirections, processes, pipes, jobs,
      signals and traps; (c) the builtins; (d) completion, the spec
      files and the hooks. Where a part depends on the rest only one
      way it becomes a module of its own; which, is decided at (a).
- [ ] 7. `Concha`: the command line, the REPL, startup, the queries.
      `make test` passes `tests/test.cn`.
- [ ] 8. `doc/concha.1`, `README.md`, `doc/internals.md`: the build
      and the insides are raz's.

## How the Pascal maps onto raz

- **Errors.** `Catch` and `Throw` ran the work on coroutines of its own
  stacks, as setjmp and longjmp. In raz an error is an `ERROR`, passed
  on with `try`, four of them for `Throw`'s four codes: `Failed` (1),
  `More` (2, more input wanted), `Stopped` (3, an interrupt or a
  stopped job) and `ErrExit` (4). `fail` writes the message, as now,
  and answers `Failed`; a procedure that can fail has an `ERROR` last,
  and where a `Catch` stood the caller tests it and `Recover`s. In a
  forked child `fail` still ends the process. `ulam`'s `co` goes.
- **Memory.** The three lifetimes stay: syntax trees from the heap,
  never freed; temporaries from an arena with marks, as an allocator
  so that `Buf` and `Vec` grow in it; variables' values from the heap,
  copied on assignment.
- **Strings** are `[]U8` without a closing zero; the C strings `exec`
  wants are made where it is called. ShortString's 255 bytes limited
  messages and names; nothing does now.
- **Signals.** `Sys.catch` gives signals on an fd, which can't break a
  blocking `wait4` or `read` as Ctrl-C must, so `Ckern` installs a
  handler, as the Pascal did; a handler sets a flag with `XCHG`.

Meant differences from the Pascal concha are listed here as they are
made.

## The handover

1. [ ] **Same suite.** `tests/test.cn` passes under both concha's.
2. [ ] **Daily use.** The raz concha is the shell of one terminal for
   a week: `~/.concharc`, the prompt, completion, jobs, and the
   scripts under `~/lib` that are concha.
3. [ ] **Switch.** `make install` into `~/.local/bin`; the Pascal one
   kept as `~/.local/bin/concha-fpc` for a while. `man desktop` (`OUR
   OWN: CONCHA, ROBBIE, SAUCE`) says concha is raz, then `make check`
   and `make install` in `~/lib/desktop`. concha-lsp
   (`~/lib/concha-lsp`) is checked against the new `-q` answers.
4. [ ] **Retire.** After a few weeks of use with no difference found,
   `concha-fpc` is removed.
