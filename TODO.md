# TODO

Findings for the user to schedule.

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
  oku's `test/cast.cn` counts screen columns with a helper of its
  own that reads `ord` byte by byte (2026-10-22).
- `split('', sep)` gives an empty list, not `['']`, so code that
  splits text into pieces and counts separators gets -1 for an empty
  piece. Defensible, but `man concha` doesn't say so (2026-10-20). oku's cast script met it too
  (2026-10-22).
- `$name` in an expression, as in `writeln($f)`, fails with only
  "expected an expression". The rule (`$` for command words, the bare
  name in expressions) is right; the message could name it, e.g.
  "write f, not $f, in an expression" (2026-10-20).
- A failed capture's status outlives `errexit := false`. A function
  that turns errexit off, captures a failing command and turns it
  back on leaves `status` at 1 (`Cinterp.raz` `Cvars.setStatus(waitFor(pid))`
  in the capture), since Pascal statements leave it alone; the next
  procedure-call statement is an `sCmd` and takes that stale 1 as its
  own, and `execStmt` ends the script by errexit. Exits 1 after `a`:

      errexit := true
      function quiet;
      begin
        errexit := false
        result := `false`
        errexit := true
      end;
      procedure p;
      begin
        x := quiet()
      end;
      echo a
      p()
      echo b

  A call to a procedure should give it its own status (0 unless it
  runs a command that fails), not the last one seen. blick's
  `test/check.cn` captures with `|| true` instead (2026-10-23).
  Nothing needs to turn errexit off: a capture is exempt, but its
  status still stands, and the next statement that is a call, even
  `writeln`, takes it as its own. Exits 1 after `a`:

      concha -c 'errexit := true; x := `false`; writeln("a"); writeln("b")'

  So a script under errexit can't read a failed capture's status and
  then print: `writeln(`diff a b`)` ends it too. huh's `test/check.cn`
  runs `true` after each such capture (2026-10-28).
- errexit ends a script with no word: no file, line or command. The
  case above was found only by adding echo lines until it moved; a
  message on stderr like `script.cn:12: errexit: p() (status 1)`
  would have found it at once (2026-10-23).
- `args` as a procedure parameter name: `procedure p(want, args)` binds
  the parameter, but every call then overwrites it with the full
  argument list (`man concha`: "Every call also receives the full
  argument list in the local variable args"), so `args` holds `want`
  and the list flattened; `p('x', ['a','b'])` then `echo $args` prints
  `x a b`. A parameter named `argv` is untouched (`a b`). The manual
  never says a parameter may not be called `args`; the call should
  either bind the declared parameter or `-n` should reject the name
  (found in desh's `test/run.cn`, 2026-10-23).
- The stale status after `errexit := false` is not only a capture's: a
  plain failing command does it too, and any later statement that
  leaves `status` alone ends the script silently once `errexit := true`
  is set. Exits 1 after `w`, `next` never printed (2026-10-23):

      errexit := false
      false
      errexit := true
      writeln('w')
      echo next

  `x := 1` instead of the `writeln` is fine; the exit is at the
  `writeln` statement, not at the assignment. bash's `set +e; false;
  set -e` does not exit on re-enabling, and its next command resets
  `$?`. Seen in lolo's `test/run.cn`.
- A heredoc inside a backtick capture is refused with "unterminated
  heredoc" (exit 2), though the same heredoc as a plain command works:

      x := `cat <<EOF
      hello
      EOF`

  The reader seems to look for the terminator before the closing
  backtick is matched. Worked around in lolo's `tools/album.cn` by
  writing the heredoc to a file and capturing that (2026-10-23).
