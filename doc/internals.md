# concha internals

concha is written in raz (`man raz`), in ten modules, each depending
only on those above it in this table:

| module | lines | job |
|--------|-------|-----|
| `Ccore` | ~610 | arena, values, errors, output, files, the distance between names |
| `Csyntax` | ~1830 | scanner, parser, syntax tree, the notes the queries read |
| `Cfuzzy` | ~120 | wuzzy's fuzzy matcher, which ranks completions |
| `Cedit` | ~1950 | line editor, history, highlighting, the menu |
| `Cvars` | ~460 | variables, procedures, "did you mean", `~user`, `PATH` |
| `Cglob` | ~200 | patterns and globbing |
| `Cclock` | ~100 | `time()`'s format |
| `Ccomplete` | ~690 | completion, and the concha-complete(5) files |
| `Cinterp` | ~3130 | evaluator, expansion, processes, jobs, signals, builtins |
| `Concha` | ~590 | command line, the queries, the REPL, startup |

It was ported from a Free Pascal concha, a module for each of its units
and in their order; `Cfuzzy` is what that one took from
fuzzy(3), local time is rzone's `Zone` (hora(3)'s part), and `Cvars`, `Cglob`, `Cclock` and
`Ccomplete` the parts of its interpreter that depend on the rest one way
only. "From the Pascal", at the end, lists the differences that were
meant.

Everything goes through raz's library: `Sys` for the system calls (the
terminal, process groups, signals, limits, and execve, which leaves an
ignored signal ignored as `trap ''` wants), `Buf` and `Vec` for
growable buffers and arrays, `Fmt` for messages. Nothing links libc, so
`~user` is found by reading `/etc/passwd` (`Cvars.passwd`).

Build with `make`, which wants the raz on `PATH` to be of the version
`RAZVERSION` in the `Makefile` names, and builds with `-Werror`; `make
fmt` checks that `src/` is laid out as raz's formatter lays it out. Test
with `make test`, which runs `tests/test.cn` under `build/concha`; the
script runs `$CONCHA` for the checks that start a shell.

## Memory

There are three lifetimes, and each has its own allocator:

- **Syntax trees** are allocated with `GetMem` and never freed. A parsed
  program lives as long as the shell, because procedures point into it.
  Everything the tree needs is copied out of the source buffer (`PermStr`),
  so the buffer can be reused.
- **Temporaries** come from a chunked arena (`Alloc`, `Mark`, `Release`).
  `ExecStmt` marks on entry and releases on exit, and loops release after
  every test of their condition. Whatever an expression builds dies with its
  statement. A two-million-iteration loop peaks at under 500 kB.
- **Variables** own heap copies. `keep` deep-copies a value to the heap and
  `Drop` frees it. `Store` keeps the new value before dropping the old one,
  so `x := x + 'a'` is safe. Reading a variable copies it into the arena
  (`Temp`), which prevents a later assignment in the same expression from
  freeing something still in use. Indexing and `length` read in place, so
  loops over lists aren't quadratic.

Values are copied on assignment, so no two variables share storage, and no
garbage collector is needed.

`TVal` is a three-word record: a kind, an `n` (the integer, the boolean, the
string length or the list count), and a pointer `p` (to the string bytes or
the items).

## Errors and control flow

An error is an `ERROR`, passed on with `try` to whoever deals with it.
There are four, in `Ccore`: `Failed`, an error, written already;
`More`, input that ends before what it opens does, written nowhere;
`Stopped`, a Ctrl-C or a stopped foreground job; and `ErrExit`, a
command that failed under `errexit`. `Ccore.fail` writes the message
and answers `Failed`; in a forked child it ends the process instead,
with status 2. A script stops at its first error, which ends the shell
(status 2, 130 after `Stopped`, the command's after `ErrExit`); the REPL
ends the line and goes on, keeping it for `More` and asking for the
rest with `. `. Either way `Cinterp.recover` first puts the shell back
as it is between statements: saved file descriptors restored, `<(...)`s
closed, local frames dropped, the control flag reset.
Every statement and command keeps the line and file it was parsed
from (`path`, `""` for typed lines and `-c`); `execStmt` and `expand`
copy them to `Ccore.where` for the message, and `callProc` puts back
the caller's on return. A procedure call that fails gives its frame
back as it returns.
Two places deal with an error closer in: the `complete` hook (`ask`),
which puts back the frames and descriptors above where it started and
counts the error as no answer, and `source` run by the `prompt`
procedure (`sourceGuarded`), which does the same and returns status 1.
Left to the REPL, that error would turn the prompt procedure off for
good.

A redirection that can't be opened is not an error passed on. `openRedir`
reports it with `Ccore.warnOn` and `redirect` returns `false`, and the
command gets status 1 without running, in the shell or in a child alike.

`break`, `continue` and `exit` are not errors. They set `ctl`, which
`execList` and the loops check.

`exempt` counts the reasons a failure may not trigger `errexit`:
`runChain` raises it around every pipeline but the last, and a capture's
child raises it for good.

## Parsing: two worlds in one buffer

The parser works on the raw source, character by character, and only
statement starts decide which world it is in. `Csyntax.parseStmt` looks at
the identifier under the cursor, without consuming it:

- a keyword → Pascal statement;
- an assignment (`name :=`, or `name[...] :=`) → assignment;
- anything else → `parseCmdStmt`, which is command mode.

Pascal expressions are scanned into tokens with one token of lookahead.
`exprRaw` fetches a token, parses, and then **rewinds** to the end of the
last token it used (`endPos`). Code after an expression therefore sees the
raw text again, including any newline that ends a command. `next` never
fails on a character it doesn't know (`tOther`), because the lookahead
often lands on command syntax like `|`.

Command mode reads words as lists of parts (`Csyntax.Part`): literal
(quoted or not), variable, expression, capture, `<(...)`, and home, which
holds the user of a `~user` (empty for `~`), at the start of a word or, in
`NAME=value`, after the first `=` or an unquoted `:`. `Cvars.passwd` reads
`/etc/passwd` to find a user's home; concha does not link libc, so there is
no `getpwnam`. A backtick opens a capture by calling `parseList`
recursively, so a capture holds statements.
`inBack` says whether a backtick in command mode closes a capture or opens
a new one: `parseList`, `parseCommand` and `termAt` all stop at a closing
backtick. This is how `` `echo $(f(`date`))` `` nests without escaping.
A word that starts unquoted with `<(` is a process substitution, a
`ptSub` part alone in its word (`procSub`). Its list is parsed the same
way, with `inSub` set instead: a `)` then ends a bare word, a command
and a list (`endsWord`). `procSub` clears `inBack` and `capture` clears
`inSub`, so the innermost of the two decides what closes. With a space,
`< (` is still a redirection.

A bare `end`, `else` or `until` ends a command only if it closes something
open. `closers` holds the words that would: a `begin` or procedure body sets
it to `end` alone, a `repeat` body to `until`, a case arm to `end` and
`else`, and an `if` adds `else` to it while parsing the `then` branch. A
capture starts empty. Each of these saves and restores it, so the innermost
construct decides. `termAt` checks it.

Heredocs: when `<<TAG` is parsed, the body is found after the end of the
current line and recorded as a *skip region* (`Here`). `adv` jumps over the
region whenever it steps past that newline. Two heredocs on one line chain
their regions. The body's interpolations are parsed right away by
temporarily moving `pos` into the region. An indented terminator gives an
indent, which `dedent` strips after each newline.

An error at end of input writes no message when `quietEof` is on. Instead
`synErrAt` returns `Ccore.More`, and that is how the REPL knows to print
`. ` and read another line.

Every syntax error goes through `synErrAt`, which sets `Ccore.where^.line`,
`col` and `file` from a byte offset and its line; the column is counted
back to the newline before it, so it is in bytes and right after a
heredoc. `synErr` takes the scanner's place, `tokErr` the lookahead
token's (`tokPos`, `tokLine`), since `pos` has moved past it by then;
an unterminated string names its opening quote, and an unterminated
heredoc its tag. A heredoc body is parsed with `line` set to the
body's own line. Only `-n` prints the column (`Ccore.opts^.showCol`).
`-q check` sets `Ccore.opts^.keepErr`, so `Ccore.warn` keeps the message
for `Ccore.kept()` instead of printing it, and `Concha` prints line,
column and message.
`-q outline` sets `outlining`, and the parser notes (`note`) each
`sProc` as its name is read, and each `var` or `export` name, on the
list `outline`, each with its `owner`, the proc it is inside
(`curProc`); the outline prints only the unowned vars; a procedure's last line is
filled in at its `end`. Noting as it goes, rather than walking the
tree after, gives the outline of what parsed before an error too.
`-q words` uses the same list: the variables in scope at a place are
the items before it whose owner is nil or contains it, and the
parameters (`params`) of the procs that contain it. After an error
`noteProcsAfter` scans the remaining lines for `procedure`/`function`
names. The keyword, builtin and usage tables (`Csyntax.Keywords`,
`Csyntax.Builtins` and `Csyntax.CmdBuiltins`, the last two lists of a
name and its usage) are in `Csyntax`; `test.cn` checks each usage against
the rendered `concha.1`.
A `Csyntax.Stmt`'s `col` is the name's byte column (`colOf`), set for
procedures and declarations only.
Also while outlining, the parser notes each use of a name that could be
a procedure on the list `refs` (`noteRef`): word 0 of a command when it
is one plain literal, and an `eCall` that is not a builtin (`Expr.line`
and `col`). A `Ref` holds the name, its position and length, and its
`owner`; nothing is added to the `Cmd`. Variables and the parts of a
string get no position: nothing asks where they are, and every `Expr`
would pay for the fields.
`-q dump`, hidden, prints the list for `test.cn`.
`-q def` finds the declaration or the use at the place, and resolves a
use's name (`Concha.resolve`) among the outline's procedures: those owned by
the use's own procedure, then by its owner, outwards to the top, so the
innermost visible declaration wins, wherever it stands in the file.

## Running commands

`runAndOr` → `runChain` (`&&`, `||`) → `runPipe` → `runSingle` or `runMulti`
(all in `Cinterp`).

Expansion always happens in the parent, before any fork. Errors and
captures therefore behave the same whether the stage is external or not.

- **Single stage, not external** (procedure, builtin, call, block): runs
  inside the shell. Redirections are applied with `saveFd` (a `Sys.dupAbove`
  from fd 10 on, close-on-exec), then undone with `restoreFds`. The save stack is
  also unwound by `recover` after an error. `exec` with no command sets
  `keepFds`, and `runSingle` then keeps the redirections (`commitFds`)
  instead of restoring them.
- **Single stage, external**: `fork`, apply redirections in the child,
  `execve` along `PATH` (`tryExec`).
- **Several stages**: every stage is forked. An in-shell stage runs the
  interpreter in the child and exits with its status.
- **Tail exec**: a capture or background child that runs a single external
  command execs it directly instead of forking again (`tailOk`). For a
  capture, that means its list is one command statement, not in the
  background. The flag is cleared as soon as it is read, so commands nested
  in a procedure never exec over the child.

A `<(list)` is expanded by `openSub`, which forks as `capture` does
but leaves the pipe's read end open in the shell (inherited, not
close-on-exec) and pushes it with the child's pid on `subs`; the word
is `/dev/fd/N`. `runPipe` notes the depth of `subs` before the
command, and `closeSubs` closes the read ends above it after, then
reaps the children, closing first so a writer still going dies of
`SIGPIPE` instead of blocking. Their status is dropped. `recover`
closes them all, and a child closes those it inherited.

Heredoc and here-string input is written into a pipe. Content over 32 kB is
written by a forked writer, so the pipe cannot deadlock.

Job control is on only in the interactive shell (`jc`, set by
`jobControl` once the shell leads its own process group and holds the
terminal). The job table (`jobs`, in `Cinterp`) holds background jobs
and stopped ones, and the foreground job while it runs; entries are kept
in age order, and the last is the current job. A foreground command or
pipeline forks into a new group, which both parent and child set up
(`joinGroup`, `childJob`) since either may run first; `waitJob` waits on
the whole group and takes the terminal back. A stop leaves the job in the
table with its terminal settings and goes back to the prompt: `waitJob` answers `Ccore.Stopped`.
`reapJobs`, before each prompt, reports what finished or stopped in the
background. `hangUp`, any shell's default for `SIGHUP`, passes it on to every
job (and wakes the stopped ones to take it) before dying of it. Children always run with `jc` off, so their own
commands are not jobs.

A background list is a process group of its own, with or without job
control, led by the child shell that runs it (`runAndOr`), or by the
program that shell execs for a lone command. That child
takes `SIGHUP`, `SIGTERM`, `SIGUSR1` and `SIGUSR2` as `dPassOn` (see `Disp`):
`noteSignals` resets the signal and sends it to the whole group, itself
included, so `kill $lastpid` stops every stage of a background
pipeline, and `wait` sees the child die of the signal. `SIGINT` and
`SIGQUIT` are not passed on, since the terminal already sends them to
the whole group, or they are ignored.

Without job control `waitFor` waits for one pid, asking `Sys.wait` to
report stops too. A
stopped child is sent `SIGCONT`, because nobody could resume it, unless
the waiter is itself part of a job (`jobChild`): then it stops itself
too, and `fg` or `bg` continue the whole group.

`giveTerm` hands the terminal to a process group with `Sys.foreground`.

A signal the shell takes is only noted when it comes: `Sys.handle` makes
the system call it interrupts fail with -4 (`Ccore.errIntr`, EINTR), and
`Sys.came(sig)` says it came. `noteSignals` looks, before each statement
(`execStmt`) and wherever an interrupted call gave up (`waitFor`,
`waitJob`, the reads), and does what `disps` says that signal does (`Disp`):
`SIGINT` sets `intr`; `SIGHUP` runs `hangUp`; a trapped signal sets `pend`
and `trapPending`; in a background list the signal is passed on to the
group. The REPL calls `noteSignals` when the editor returns, and the editor
calls the `signalled` hook (`Cedit.hooks^.signalled`, which `Concha`
points at `Cinterp.noteSignals`) when a signal breaks its wait for a key,
so a hangup at the prompt ends the shell at once.

`execStmt` checks `intr` after `noteSignals` and returns `Ccore.Stopped`
(through `interrupted`), so Ctrl-C breaks loops that run
inside the shell. Children reset their signals to the defaults
(`childSignals`). `waitFor`
waits and sees, like bash: if the child it reaped was not killed by
`SIGINT`, it caught the Ctrl-C, and `waitFor` clears `intr`. In a pipeline
the last stage decides; `intSeen` remembers a Ctrl-C an earlier stage
absorbed. Under job control the terminal sends `SIGINT` to the
foreground job, not the shell, and `waitJob` sets `intr` if the job's last
process died of it.

`trap` keeps a small table, entry 0 being `EXIT`. A trapped signal is
noted by `noteSignals`, which only sets `pend` and `trapPending`;
`execStmt` runs the procedures (`runTraps`) next to its `intr` check.
`childSignals` forgets trap procedures but keeps ignored signals ignored.
Every exit of the shell goes through `leave`, which runs the `EXIT`
procedure once.

## Variables

The globals and the local stack are growable arrays (`Vec`) of `Cvars.Var`.
`callProc` pushes the parameters, `args` and `result` above `base`, runs
the body, and pops. The lookup order is the current frame, then the
globals. There is no access to enclosing frames. The names in a `Var` point
into permanent memory (the syntax tree or `Ccore.perm`, from the heap), so a frame costs no
name copies.

A pointer to a `Var` is invalid after anything that can create a
variable, because the array may be reallocated. Look a variable up, use
it, and let the pointer go.

## Line editor

`Cedit.editLine` switches to raw mode, then asks the terminal for the cursor
position (`ESC [6n`, with a 0.2 s timeout). Everything is drawn relative to
that column. The editor never needs to know the prompt's width, so
coloured or procedural prompts cost nothing. Typed-ahead bytes that arrive
before the terminal's answer are pushed back.

`show` works on offsets. The cursor's position is
`startCol + width(text before cursor)`. Dividing by the terminal width
gives the row and column. The editor remembers which row the cursor is on,
so a redraw moves up to the first row, clears to the end of the screen,
writes the line, and moves back. When the text ends exactly at the right
margin, it writes an explicit `CR LF`, so the terminal's deferred wrap
can't confuse the arithmetic. Widths are `Width.width`'s, by character
(`columns`): a CJK character or an emoji takes two columns, a control
character one.

With colour on, `paint` draws the line through `classify`, a small scanner
that gives every byte a class (comment, string, variable, keyword, ...).
Escapes go only into the output buffer; widths and the cursor are always
worked out from the raw text, so colour cannot upset the arithmetic.
The command word is coloured by the `known` hook (`Cedit.hooks^.known`),
which `Concha` points at `Ccomplete.knownCommand`; `runnable` remembers the last word asked
about, so typing elsewhere on the line looks nothing up.

History is an array of heap strings, capped at 1000. `draw` shows a
suggestion, the rest of the newest entry that starts with the line, as
`show`'s dim suffix; `plain` draws without one, for the final draw
of an entered or cancelled line. `editLine` is told whether the line is
a continuation, which gets no suggestion. Ahead of history comes
`offer`, a corrected line: `Cinterp.correct` sees, before forking, that
an external command at the prompt will not be found and calls
`Cedit.propose` with its "did you mean", which swaps the word in the newest
history line and keeps the result in `fixed`; the next `editLine`
moves it to `offer`, so it lasts one line. Each entered line is
appended to `~/.concha_history` right away, so concurrent shells interleave
rather than overwrite. The file is rewritten, trimmed, when loading finds
it more than half again over the cap.

Tab completion is split in two. `Cedit` scans the line up to the cursor to
find the current word, whether it sits in a quote, and its context:
`cxCommand` where a command belongs (at the start, after `|`, `;`, `&`,
`` ` ``, `(`, or after `then`, `do`, `else`, `begin`, `repeat`),
`cxExpr` in a Pascal expression (after `:=`, after a keyword that takes
one, or inside a parenthesis opened right after a word, which covers
calls and `$(`), `cxDir` for the arguments of a `cd`, and `cxArg`
elsewhere. `scan` keeps one bit per open
parenthesis to know what a `)` returns to. It also notes where the
command's words lie (`Spans`), leaving out redirections. It unquotes
the word, and those, and hands them to the `complete` hook (`Cedit.hooks^.complete`), which
`Concha` points at `Cinterp.complete`, which calls `Ccomplete.complete`:
that knows the keywords,
`PATH`, the builtins, the procedures and the variables. If nothing
starts with the word it tries again with `Cfuzzy.score` and hands back
the matches ranked (`Ccomplete.rank`), which `Cedit` then leaves unsorted. For an
argument it first calls the user's `complete` function (`Cinterp.ask`), with
fds 0 to 2 on `/dev/null`, `status` kept, and an error in it only an
empty answer. Candidates come back
unquoted, and `Cedit` sorts them and inserts the common prefix,
re-escaped for the quote it is in (`take`). `candidates` does the
finding, for Tab and for the `completions` builtin alike: `Cedit.completions`
points the scanner at the given line, the cursor at its end, and puts
the edited line and `wd` back after, since a `complete` function may
call it while Tab waits. When there is nothing to insert, `menu`
runs a loop of its own, as `^R` does: it draws the candidates below
the line through `show`, the one drawing routine,
which writes rows after the line and moves back up, so the next redraw's
clear to the end of the screen wipes the menu. Stepping through it
replaces the word with each candidate; the first key it has no use
for goes back to `editLine`.

After the user's `complete`, an argument looks for the command's
completion file, concha-complete(5) (`Ccomplete.specFind`, under the XDG data
directories). It is read on every Tab, into the arena, as a list of
fields per line (`specLines`), and nothing in it can run anything:
Tab must never start a process. `specSays` walks the words before the
cursor, keeping the scope, the operand count, whether `--` has been
seen and an option waiting for its value, then says what the word
may be: names to offer (subcommands, options, `one` and `in` words),
plus a `Ccomplete.Kind` that `Ccomplete.complete` turns into its usual rules
(`kFile`, `kDir`), nothing more (`kNone`), or a command line of its own
(`kCommand`), which it completes by calling itself on the words from
there on. A value after `--name=` is completed the same way, alone,
and `--name=` put back in front.

`^X^E` works the same way: `Cedit` writes the line to a file in `/tmp`, and
the `editor` hook, `Cinterp.editFile`, runs `$VISUAL` or `$EDITOR` on it
through `runArgs`, so the editor may be a procedure and gets the
terminal as a foreground job.

Every key but undo first pushes the line on a small undo stack (64
steps, oldest dropped), and pops it again if the key changed nothing;
a run of typed characters shares one step. Kills go to one buffer,
`killed`, which kills in a row extend.

The terminal is back in cooked mode before a line runs, so commands see a
normal tty and Ctrl-C works. `Cedit.reset` also runs during error recovery (`Concha.repl`),
in case a `prompt` procedure fails while the editor is redrawing.

## Adding a builtin

- **Routine:** add a `Csyntax.Doc` (name and usage) to `Csyntax.Builtins`
  and a `b...` enumerator to `Csyntax.Builtin`, in the same place in both
  (`Builtins[INT(b) - 1]` is `b`'s), then a case to `Cinterp.builtin`.
  Use `need` to check the argument count, and `argStr` or `eval` to
  evaluate arguments.
- **Command:** add a `Csyntax.Doc` to `Csyntax.CmdBuiltins`, then a case
  with the same name to `Cinterp.runCmdBuiltin`. It receives the expanded
  words, with element 0 being its own name.

`test.cn` checks each usage against the rendered `concha.1`, so the man
page needs its line too.

## From the Pascal

The port kept the language as it was. What differs from the Pascal
concha, on purpose:

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
- **Local time is rzone's.** `Czone` gave way to `~/r/rzone`'s
  `Zone`, which reads `TZ` as the C library does: `TZ` empty is UTC
  (it was `/etc/localtime`), `TZDIR` is looked in for a name, `TZ`
  that names no file is read as a POSIX rule (`EST5EDT,M3.2.0,M11.1.0`;
  it was UTC), and an abbreviation is no longer cut to 7 bytes.
- **type and help**, two builtins the Pascal lacked: `type name`
  says what a command word is and where a procedure was declared;
  `help name` prints a procedure's heading and the comment above it,
  or a builtin's usage. They are in `-q words` and completion too.
  So that help finds a procedure's file wherever the shell has gone
  since, an error in `~/.concharc` names it in full
  (`/home/luis/.concharc:12`, it was `.concharc:12`).
- **ctrl-r matches fuzzily**, as completion does: a history line
  matches when the query's letters come in it in order, and the best
  match by `Cfuzzy`'s score comes first, the newest of equals; ctrl-r
  goes to the next best, and a line already shown is passed over. The
  Pascal took the newest line holding the query whole, with the cursor
  on it; now the cursor is at the end.
- **A call statement has a status of its own** (2026-10-28): a
  builtin's is 0, a procedure's that of the last command statement it
  ran. The Pascal let a call keep whatever status came before it, so a
  failed capture ended an errexit script at the next `writeln`. errexit
  now names the command, file and line.
- **Stricter parsing** (2026-10-28): an assignment must end its
  statement (`x := 1 echo hi` is an error), and a procedure may be
  declared among a procedure's `var` sections.
- **unicode, chars and hex**, three builtins the Pascal lacked; `ord`
  and `chr` still work on bytes.
- **An assignment may end a && or || list** (2026-10-29, 1.0.1):
  `cmd || rc := status` keeps a failing command's status even under
  `errexit`, and the assignment leaves `status` at 0. The Pascal took
  no assignment there (`rc` was run as a command).
