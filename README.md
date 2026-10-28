# concha

**A Unix shell whose scripting language is Pascal.**

Commands are commands, and everything around them is Pascal: real
variables, real conditions, real functions. No word splitting, no quote
mazes, no `[ ... ]`.

<table>
<tr><th>sh</th><th>concha</th></tr>
<tr><td>

```sh
for f in *.log; do
  n=$(grep -c ERROR "$f")
  if [ "$n" -gt 0 ]; then
    echo "$f: $n errors"
  fi
done
```

</td><td>

```pascal
for f in glob('*.log') do begin
  n := int(`grep -c ERROR $f`)
  if n > 0 then writeln(f, ': ', n, ' errors')
end
```

</td></tr>
</table>

`$f` is always one argument, even when the name has spaces in it, so
there is nothing to quote.

- **It keeps** what the Bourne shell is good at: commands, pipes,
  redirections, heredocs, `&&`, `||`, `&`, globs and job control.
- **It drops** what makes shell scripts fragile: values split and
  globbed again, `$IFS`, `test` and `[ ... ]`, and quoting to keep a
  value whole.
- **At the prompt** it has its own line editor, with highlighting as you
  type, history suggestions, Tab completion with a menu, and "did you
  mean".

## Install

concha is written in [raz](https://raz.lucelad.workers.dev), and builds
with the version the `Makefile` names (`RAZVERSION`); `make` warns if
the `raz` on your `PATH` is another. It needs
[rzone](https://github.com/ldiaz94/rzone), for local time, installed first
with `make install` in its checkout (it goes to `~/.raz/lib`).

    make                # build/concha
    make test           # the self-test, the examples, the man pages
    make install        # concha, three man pages and the examples, into ~/.local

`PREFIX`, `DESTDIR`, `BINDIR`, `MANDIR`, `DATADIR` and `RAZ` can be set
on the command line; see the `Makefile`.

    concha                     interactive; reads ~/.concharc first
    concha script.cn a b       run a script; its arguments are in args
    concha -c 'text' a b       run text
    concha -n script.cn        check the syntax, run nothing
    ... | concha               run standard input

## A tour

### Two kinds of statement

A line that starts with a keyword, an assignment (`x :=`) or a call (`f(`)
is Pascal. Any other line is a command.

    ls -l /tmp | grep conf > out.txt      // a command
    n := length(lines(`ls`))              // Pascal
    writeln('there are ', n, ' files')

A newline or `;` ends a command. So does a bare `end`, `else` or `until`
that closes an open `begin`, `if`, `case` or `repeat`, so
`if x > 1 then echo big else echo small` works as written. Anywhere else
these are ordinary words: `echo the end` prints `the end`. Between Pascal
statements the `;` is optional. Comments are `// ...` and `{ ... }`.

### Command words

| word        | means                                                   |
|-------------|---------------------------------------------------------|
| `foo`       | itself; `*`, `?` and `[..]` glob, and no match is an error |
| `'it''s'`   | a Pascal string, taken literally                        |
| `"a $x b"`  | `$name`, `${name}` and `$(expr)` interpolated           |
| `$x`        | a variable's value: one argument, or one per list item  |
| `$(expr)`   | any expression                                          |
| `` `cmd` `` | the command's output, its trailing newlines removed     |
| `<(cmd)`    | a `/dev/fd/N` to read the command's output from         |
| `~`         | `$HOME`                                                 |
| `\c`        | the character `c`                                       |

Values are never re-split or re-globbed. To split, say so:
``rm $(lines(`find . -name '*.o'`))``.

Redirections are `< f`, `> f`, `>> f`, `2> f`, `2>&1`, `&> f`,
`<<< 'text'` and heredocs. A heredoc's body starts on the line after the
command; a quoted tag (`<<'EOF'`) makes it literal, and an indented
terminator takes its indentation off every line of the body:

    procedure usage;
    begin
      cat <<EOF
        usage: $prog file
        EOF
    end;

### Values

Values are `nil`, booleans, integers, strings and lists (`[1, 'two']`),
and they are copied on assignment. `+` adds integers, joins lists, and
otherwise concatenates strings. `-`, `*`, `div` and `mod` read numeric
strings, so ``int(`wc -l < f`) + 1`` works, and `=` treats `'10'` and
`10` as equal. Conditions must be boolean. Operator precedence is
Pascal's, so write `(a = 1) and (b = 2)`. Strings index from 1, lists
from 0.

### Statements

    var x := 1, y                       if c then s else s
    x := e;  l[i] := e                  while c do s
    begin ... end                       repeat ... until c
    for i := 1 to n do s                for f in glob('*.txt') do s
    for i := n downto 1 do s            case e of 1, 2: s; 'x': s else ... end
    export PATH := PATH + ':/opt/bin'   break  continue  exit  exit(e)

    procedure greet(name);              function sq(x);
    begin                               begin
      writeln('hello, ', name)            result := x * x
    end;                                end;

A procedure can be called as a command (`greet bob`) or as Pascal
(`greet('bob')`), and every call also gets its whole argument list in
`args`. New variables are local inside routines and global outside them,
and nothing outside a routine sees its locals. Only exported globals
reach child processes; the environment concha starts with is exported
already.

A `begin ... end` block, or any control statement, can be a stage of a
pipeline or take redirections:

    printf 'a\nb\n' | while readln(l) do writeln('> ', l)
    begin echo b; echo a end | sort > sorted.txt

Procedures and blocks run inside the shell, so they can change
variables; in the middle of a pipeline they run in a child, and can't.

### Status

After each command, `status` holds its exit code, 128+n if signal n
killed it. Pascal statements leave it alone, but a call made as a
statement is a command: `writeln(...)` has status 0, and a procedure the
status of the last command it ran. Under `errexit` a failed command ends
the script with `concha: f.cn:12: errexit: grep -q x (status 1)`.

    grep -q root /etc/passwd
    if status = 0 then writeln('yes')
    make && ./prog || echo failed

`errexit := true` stops a script at the first command that fails, and
`pipefail := true` makes a pipeline fail when any of its stages does.
`halt(n)` ends the shell; `exit` leaves the routine or the script, and
`exit(e)` sets the function's result or the status as it goes.

### Builtins

- **Commands:** `cd [-]`, `echo [-n]`, `exec`, `source file`, `trap`,
  `ulimit`, `umask`, `unset`, `wait [pid]`, and for jobs `jobs`, `fg`,
  `bg` and `disown`.
- **Input and output:** `write`, `writeln` and `readln(v)`, which
  answers false at the end of input. A `write` used as a command writes
  to the command's standard output, so `writeln(x) > file` works.
- **Strings and lists:** `length copy pos int str chr ord upcase
  lowcase trim`, `unicode(s) chars(s) hex(n[, w])` for UTF-8 and hex, `split(s[, sep]) join(l[, sep]) lines(s)
  replace(s, old, new) sort(l)`, `glob(pattern) match(s, pattern)`.
- **Files:** `exists(p) isdir(p) isfile(p) basename(p[, suffix])
  dirname(p)`.
- **The shell:** `inc(v[, n]) dec(v[, n]) halt([n]) defined(name)`,
  `environ() getenv(name) setenv(name, value)`, `now()
  time(fmt[, ms])` and `completions(line)`.

## At the prompt

- **Editing** has the usual keys: the arrows, `^A` `^E` `^B` `^F`,
  `Alt-b` `Alt-f`, `^W` `Alt-d` `^U` `^K`, `^Y` to put back what was
  killed, `^_` to undo, `Alt-.` for the last word of the line before,
  `^T`, `^L`, and `^X^E` to edit the line in `$EDITOR`. The man page
  lists them all.
- **Colour** highlights the line as you type, and the command word is
  blue when it can run and red when it can't. `NO_COLOR=1` turns colour
  off.
- **History** is kept in `~/.concha_history`. `Up` and `Down` walk it,
  `^R` searches it, and the newest line that starts with what you have
  typed is suggested, dim, after the cursor: `Right` or `^E` takes it.
  After `ehco hi` and its "did you mean echo?", the next prompt suggests
  `echo hi`.
- **Tab** completes commands, procedures, `$variables` and file names,
  with a menu when several fit. A `function complete(words)` teaches it
  your commands' arguments, git branches say. A program can describe its
  subcommands, options and operands in a small file instead
  (concha-complete(5)), which Tab reads without ever running it.
  `completions(line)` lists what Tab would offer.
- **The prompt** is a `procedure prompt`, if you write one, and the
  default if it fails. Input that isn't finished yet (a `begin` with no
  `end`, an open string, a heredoc) gets a `. ` prompt for the rest.
- **Jobs**: Ctrl-C interrupts the command or the loop that runs.
  Ctrl-Z stops the command in the foreground; `jobs` lists the jobs,
  `fg` and `bg` go on with one in the foreground or the background, and
  `disown` lets one outlive the terminal.

## For editors

concha answers questions about a script without running it, one line a
thing and its fields split by tabs. They are what concha-lsp(1)
(`~/lib/concha-lsp`), concha's language server, asks to give an editor
errors, an outline, completion, hover and go to definition.

    concha -q check script.cn     the first syntax error: line, column, message
    concha -q outline f.cn        its procs, funcs and vars, and where they are
    concha -q words f.cn:3:1      what can be typed there
    concha -q def f.cn:3:1        where the routine named there is declared

## Documentation

- `man ./doc/concha.1`: the whole reference.
- `man ./doc/concha-tutorial.7`: a tour for shell users, with a table
  translating sh to concha.
- `man ./doc/concha-complete.5`: the completion files.
- [examples/](examples/): short commented scripts, and
  [examples/concharc](examples/concharc), a `~/.concharc` to start from,
  whose prompt counts the lines changed in a git or sauce tree.
- [doc/internals.md](doc/internals.md): how it works, for people
  changing it.

## About

About 9,800 lines of raz, with nothing under them but raz's library: no
libc. Scratch values live in an arena that is released after every
statement, so memory stays flat in long loops. concha was first written
in Free Pascal, and ported to raz with its language kept exactly as it
was; [doc/internals.md](doc/internals.md) tells how. ISC licence.
