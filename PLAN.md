# Plan: concha in raz, and the handover

## The port

One step at a time, bottom up, each committed when it compiles with
`-Werror`, is laid out as `make fmt` wants, and does what its Pascal
unit does. A step that is too big to read in one sitting is split
before it is started, not after.

- [x] 1. `Ckern`: the system calls `Sys` lacked. raz 0.16.0 has them
      all in `Sys` (fork, exec, `dup`, `dupTo`, `dupAbove`, `handle`
      and `came`, a terminal's modes, `group`, umask, limits, `access`,
      `wait` on a group), so `Ckern` is gone; its errno names are
      `Ccore`'s.
- [x] 2. `Ccore`: the arena, values, errors, output, files, the
      distance between two names.
- [x] 3. `Csyntax`: scanner, parser, syntax tree, and the notes the
      queries read (`-q outline`, `words`, `def`). The tree's lists are
      slices; a ref holds its name and place, not the command or call.
      Checked against the Pascal's parse of every concha script on the
      machine and of each syntax error, by a dump of both trees, the
      outline and the refs.
- [x] 4. `Cfuzzy` and `Czone`: wuzzy's matcher (`fuzzy.pas`, 120
      lines), and hora's offset and abbreviation at an instant, by
      `TZ` or `/etc/localtime` (TZif files and POSIX TZ strings; sauce's
      `Sbase` reads the offset alone). `Czone.at(t)` reads the zone at
      its first call, as `ZoneAt` did; hora's limits on a zone's size
      went. Checked against fuzzy(3) on 60,000 pairs, and against hora
      at 10,000 instants in every zone, fat and slim, and at every hour
      of DST years in zones with footers made for it.
- [ ] 5. `Cedit`: the line editor, history, highlighting, the menu.
      Raw mode is `Sys.rawMode`, which turns OPOST off as the Pascal
      didn't: a new line written then is `\r\n`. The Pascal's timed
      read for an escape sequence (VTIME 0.2 s) is `Sys.ready(fd, 200)`.
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
  blocking `wait4` or `read` as Ctrl-C must, so concha uses
  `Sys.handle`: the call a signal comes during fails with -4, and
  `Sys.came` says which signal it was.

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
