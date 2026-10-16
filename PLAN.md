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
- [x] 5. `Cedit`: the line editor, history, highlighting, the menu.
      Raw mode is `Sys.rawMode`, which turns OPOST off as the Pascal
      didn't: a new line written then is `\r\n`. The Pascal's timed
      read for an escape sequence (VTIME 0.2 s) is `Sys.ready(fd, 200)`.
      The hooks are `Cedit.hooks^`, as `Ccore.opts^`. Checked against
      the Pascal editor through a pty, 27 scripts of keys, each byte
      written to the terminal, each line got and the history file the
      same.
- [x] 6. `Cinterp`, 3,400 lines of Pascal, in four steps, each
      compiled: (a) variables, expressions, statements, procedures;
      (b) words, expansion, redirections, processes, pipes, jobs,
      signals and traps; (c) the builtins; (d) completion, the spec
      files and the hooks. The parts that depend on the rest only one
      way are modules of their own: `Cvars`, the variables, the
      procedures, "did you mean", `~user` and PATH; `Cglob`, patterns
      and globbing; `Cclock`, `time()`'s format; and `Ccomplete`,
      completion and the spec files,
      which `Cinterp` imports and hands the user's `complete` function
      as a parameter. Until a step is done, what it brings answers
      that it is missing.
  - [x] (a) `Cvars`, and `Cinterp`'s expressions, statements and
        procedure calls. A call that fails gives its frame back as it
        returns, where the Pascal left it for `Recover`. Checked
        against the Pascal on 42 scripts of expressions, statements
        and errors, by the globals they leave and what they say.
  - [x] (b) words, expansion, redirections, processes, pipes, jobs,
        signals and traps; `Cglob`. `Ckern` was back for one call,
        execve, until raz 0.17.2's `Sys.execve`: `Sys.exec` gives a program every signal as it is at
        first, ignored ones too, where `trap ''` and a script's
        background jobs keep theirs, and looks along the process's
        PATH, not the shell's (RAZ-NOTES.md). A signal is seen where
        the shell looks: before each statement, and where a system
        call it interrupted gave up; so the REPL must call
        `noteSignals` when `editLine` ends, or a hangup at the prompt
        reaches no job. Checked against the Pascal on 40 scripts of
        pipelines, redirections, here strings, captures, `<(...)`,
        globs, errexit, pipefail, exec failures, background lists and
        signals, by standard output, standard error and status. Job
        control wants a terminal, and is checked at step 7.
  - [x] (c) the builtins, and `Cclock`. `tests/test.cn` runs under
        a scratch driver to its first `completions()`, line 676, as
        under the Pascal; 40 more scripts of builtins, their errors,
        `trap`, `source`, `exec`, `wait` and the job commands give the
        same output, errors and status. It found that a call lost its
        caller's locals (`Cvars.leave` cut the stack to the caller's
        base), now mended.
  - [x] (d) completion, the spec files and the hooks; `Ccomplete`.
        `tests/test.cn` runs whole under the driver as under the
        Pascal, 344 of 345, the one failing in both its path to
        `concha.1`, which is `doc/concha.1` here; and 8 scripts more
        of command words, variables, paths, `~user`, fuzzy ranking and
        complete functions give the same `completions()`. What wants a
        terminal (Tab, "did you mean" offered as the next line, ctrl-x
        ctrl-e, job control) is checked at step 7.
- [x] 7. `Concha`: the command line, the REPL, startup, the queries.
      `Cinterp` gives it `prompt`, `runTyped`, `setInteractive` and
      `takeIntr`; the colour variables, and the looks at `TERM` and
      `NO_COLOR`, are Concha's own. The REPL's `Catch` is a loop over
      `turn`, which answers an `ERROR`. A signal noted only where the
      shell looks wants the editor to look too: a hangup at the prompt
      came while `editLine` waited for a key, so the editor calls a
      hook, `signalled`, the shell's `noteSignals`, when a signal breaks
      the wait. `make test` passes; the `-q` answers for every concha
      script on the machine (7,155 of them: check, outline, dump, and
      words and def at a dozen places each and at each ref) are the
      Pascal's byte for byte, as are the bad queries, the options,
      scripts' errors and statuses, `-c`, `-n` and standard input; and
      26 scripts of keys through a pty (Tab, Ctrl-C at the prompt and in
      a child, Ctrl-Z, `jobs`, `fg`, stopped jobs on the way out, "did
      you mean", ctrl-x ctrl-e, the prompt procedure and its failure,
      ctrl-l, `.concharc`'s errors, continuation lines, errexit, traps,
      hangup with a job, history) give the same terminal and status.
- [x] 8. `doc/concha.1`, `README.md`, `doc/internals.md`: the build
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

- **Wide characters.** The editor counts a character's columns by
  raz's `Width`, so a CJK character or an emoji takes two and the
  cursor stays where it is drawn; the Pascal counted one a character.
- **A complete function that fails** puts back what it changed, the
  frames and the fds above where it started, where the Pascal reset
  the whole shell: from `completions()` in a procedure, the procedure
  goes on with its own variables.
- **A prompt procedure that fails on ctrl-l** gives way to the plain
  prompt, and the line being typed stays; the Pascal dropped the line.
- **ctrl-x ctrl-e's editor**, stopped with Ctrl-Z or not started for
  want of a fork, ends the edit with the line as the file holds it;
  the Pascal dropped the line.

## The handover

1. [x] **Same suite.** `tests/test.cn` passes under both concha's.
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
