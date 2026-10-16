# concha

A Unix shell whose scripting language is Pascal. It keeps the useful parts of
the Bourne shell: commands, pipes, redirection, heredocs, `&&`/`||` and `&`.
It drops word splitting, quote mazes and `[ ... ]`. At the prompt it has
its own line editor with persistent, searchable history.

About 9800 lines of raz (`man raz`), with nothing but raz's library
under it: no libc. Scratch values live in a mark/release arena, so
memory stays flat in long loops. It was ported from a Free Pascal
concha, whose language it keeps as it was.

    make                        build/concha, by the raz the Makefile names
    make test                   the self-test, the examples, the man pages
    concha                      interactive (reads ~/.concharc)
    concha script.cn a b        script; arguments in `args`
    concha -c 'text' a b
    concha -n script.cn         check syntax only, run nothing
    concha -q check script.cn   the first syntax error: line, column, message
    concha -q outline f.cn      its procs, funcs and vars, with their places
    concha -q words f.cn:3:1    what can be typed there
    concha -q def f.cn:3:1      where the routine named there is declared

The queries are what `concha-lsp(1)` (`~/lib/concha-lsp`), concha's
language server, asks to give an editor errors, an outline,
completion, hover and go to definition.

To install:

    make && make install

This installs `concha`, its three man pages, and the examples in
`$(DATADIR)/examples`.
`PREFIX` (default `~/.local`) and `DESTDIR` (for staged installs) are
overridable, along with `RAZ`, `BINDIR`, `MANDIR` and `DATADIR`; see the
`Makefile`.

Documentation:

- `man ./doc/concha.1`: the complete reference
- `man ./doc/concha-tutorial.7`: a tour for shell users, with a table
  translating sh to concha
- [doc/internals.md](doc/internals.md): how it works, for people changing it
- [examples/](examples/): short commented scripts, and
  [examples/concharc](examples/concharc), a starting `~/.concharc`
  whose prompt counts the lines changed in a git or sauce tree

## Two kinds of statement

A line that starts with a keyword, an assignment (`x :=`) or a call (`f(`) is
Pascal. Any other line is a command.

    ls -l /tmp | grep conf > out.txt      // command
    n := length(lines(`ls`))              // Pascal
    writeln('there are ', n, ' files')

A newline or `;` ends a command. So does a bare `end`, `else` or `until` that
closes an open `begin`, `if`, `case` or `repeat`, so
`if x > 1 then echo big else echo small` works as written. Anywhere else these
are ordinary words: `echo the end` prints `the end`. Between Pascal
statements the `;` is optional. Comments are `// ...` and `{ ... }`.

## Command words

| form        | meaning                                               |
|-------------|-------------------------------------------------------|
| `foo`       | literal; `* ? [..]` glob, and no match is an error     |
| `'it''s'`   | Pascal string, literal                                |
| `"a $x b"`  | `$name`, `${name}` and `$(expr)` interpolated      |
| `$x`        | a variable's value: **one** argument, or one per list item |
| `$(expr)`   | any expression                                        |
| `` `cmd` `` | the command's output, trailing newlines removed       |
| `<(cmd)`    | a `/dev/fd/N` to read the command's output from      |
| `~`         | `$HOME`                                               |
| `\c`        | literal character                                     |

Values are never re-split or re-globbed. To split, say so:
`rm $(lines(`find . -name '*.o'`))`.

Redirections: `< f`, `> f`, `>> f`, `2> f`, `2>&1`, `&> f`, `<<< 'text'`,
and heredocs. A heredoc body starts on the line after the command. A quoted
tag (`<<'EOF'`) makes the body literal. If the terminator is indented, that
indentation is removed from every body line:

    procedure usage;
    begin
      cat <<EOF
        usage: $prog file
        EOF
    end;

## Values

Values are `nil`, booleans, integers, strings and lists (`[1, 'two']`), and
they're copied on assignment. `+` adds integers, joins lists, and otherwise
concatenates strings. `- * div mod` read numeric strings, so
`int(`wc -l < f`) + 1` works. `=` treats `'10'` and `10` as equal. Conditions
must be boolean. Operator precedence is Pascal's, so write
`(a = 1) and (b = 2)`. Strings index from 1, lists from 0.

## Statements

    var x := 1, y                       if c then s else s
    x := e;  l[i] := e                  while c do s
    begin ... end                       repeat ... until c
    for i := 1 to n do s                for f in glob('*.pas') do s
    for i := n downto 1 do s            case e of 1, 2: s; 'x': s else ... end
    export PATH := PATH + ':/opt/bin'   break  continue  exit  exit(e)

    procedure greet(name);              function sq(x);
    begin                               begin
      writeln('hello, ', name)            result := x * x
    end;                                end;

You can call a procedure as a command (`greet bob`) or as Pascal
(`greet('bob')`). Every call also gets the full argument list in `args`. New
variables are local inside routines and global outside them, and nothing
outside a routine can see its locals. Only exported globals reach child
processes; the environment you start with is already exported.

A `begin ... end` block, or any control statement, can be a pipeline stage or
take redirections:

    printf 'a\nb\n' | while readln(l) do writeln('> ', l)
    begin echo b; echo a end | sort > sorted.txt

Procedures and blocks run inside the shell, so they can change variables.
In the middle of a pipeline they run in a forked child and can't.

## Status

After each command, `status` holds its exit code (128+n if a signal killed
it). Pascal statements leave it alone.

    grep -q root /etc/passwd
    if status = 0 then writeln('yes')
    make && ./prog || echo failed

Set `errexit := true` to stop a script at the first failed command, and
`pipefail := true` to make a pipeline fail when any stage does.

`halt(n)` quits the shell. `exit` leaves the current routine or script, and
`exit(e)` also sets the function result or the status.

## Builtins

Commands: `cd [-]`, `echo [-n]`, `exec`, `source file`, `trap`, `ulimit`,
`umask`, `unset`, `wait [pid]`.

Pascal: `write writeln readln(v) inc(v[,n]) dec(v[,n]) halt([n])`,
`length copy pos int str chr ord upcase lowcase trim`,
`split(s[,sep]) join(l[,sep]) lines(s) replace(s,old,new) sort(l)`,
`glob(pat) match(s,pat)`,
`exists(p) isdir(p) isfile(p) basename(p[,suffix]) dirname(p)`,
`defined(name)`,
`environ() getenv(name) setenv(name,value)`,
`now() time(fmt[,ms])`.

`readln(v)` returns false at end of input. A command-style `write` goes to
the current stdout, so `writeln(x) > file` works.

## Interactive

Lines are edited in place with the usual keys: arrows, `^A` `^E` `^B` `^F`,
`Alt-b` `Alt-f`, `^W` `Alt-d` `^U` `^K`, `^Y` to put back what was killed, `^_`
to undo, `Alt-.` for the last word of the previous line, `^X^E` to edit the
line in `$EDITOR`, and `^T` `^L`. `Up`/`Down` walk the history and
`^R` searches it. The newest history line that starts with what you've
typed is suggested dim after the cursor; `Right` or `^E` takes it.
After `ehco hi` and its "did you mean echo?", the next prompt
suggests `echo hi`. `Tab`
completes commands, procedures, `$variables` and file names, with a
menu to pick from when several fit, and a
`function complete(words)` teaches it the arguments of your commands,
such as git branches. A program can instead describe its subcommands,
options and operands in a small file (concha-complete(5)), which `Tab`
reads without ever running the program. `completions(line)` lists
what `Tab` would offer for a line. History is saved to `~/.concha_history`. All keys are
listed in the man page. On a colour terminal the line is highlighted as
you type, and the command word is blue when it can run and red when it
can't; `NO_COLOR=1` turns colour off.

A `procedure prompt` defines the prompt; if it fails, concha falls back to the
default. Unfinished input (`begin` with no `end`, an open string, a heredoc)
gets a `. ` continuation prompt. Ctrl-C interrupts the running command or
loop. Ctrl-Z stops the command in the foreground; `jobs` lists the
jobs, `fg` and `bg` resume one in the foreground or background, and
`disown` lets one outlive the terminal.
