# TODO

Findings for the user to schedule; not part of PLAN.md.

- `exec 3< <(list)`: after the command the shell waits for the list,
  which blocks while the list still has more to write than the pipe
  holds and nobody reads fd 3. Left on purpose (Luis, 2026-10-06):
  rare.
- An assignment's expression ends where the expression does, and what
  follows on the line is taken as a new command without `;`:
  `x := (1 + 2))` runs `)`, and `x := 1 echo hi` parses. A stray `)`
  there is no syntax error for `-n` or `-q check`.
- `concha.1` has no `-h`/`--help` in SYNOPSIS or anywhere, though the
  usage answers both (the shared CLAUDE.md asks the page to list it).
- test.cn's `< ( is a redirection` check lets `(nofile): cannot open`
  through to the test run's output, under both builds.
- A `procedure` in another's `var` section, where Pascal puts it, is
  not one: the section reads `procedure` and its name as two
  variables, the nested body's `end` closes the outer procedure, and
  the outer `begin ... end` runs at the top. `-n` says nothing. A
  nested procedure works only inside the body.
- No hex formatting and no UTF-8 decoding: there is no `hex` or
  `format`, and `length`, `ord` and `copy` work on bytes (`ord('─')`
  is 226). So a script can't write a character as a JSON `\uXXXX`
  escape; cyk's `test/cast.cn` writes raw UTF-8 instead (2026-10-20).
- `split('', sep)` gives an empty list, not `['']`, so code that
  splits text into pieces and counts separators gets -1 for an empty
  piece. Defensible, but `man concha` doesn't say so (2026-10-20).
- `$name` in an expression, as in `writeln($f)`, fails with only
  "expected an expression". The rule (`$` for command words, the bare
  name in expressions) is right; the message could name it, e.g.
  "write f, not $f, in an expression" (2026-10-20).
