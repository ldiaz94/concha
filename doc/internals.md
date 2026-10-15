# concha internals

Six files, each depending only on those before it:

| file | lines | job |
|------|-------|-----|
| `kern.pas` | ~270 | the system calls `sys` does not wrap |
| `core.pas` | ~640 | arena, values, errors, raw output, file loading |
| `syntax.pas` | ~1200 | scanner, parser, syntax tree |
| `edit.pas` | ~1470 | line editor, history and highlighting |
| `interp.pas` | ~3340 | evaluator, expansion, processes, builtins |
| `concha.pas` | ~280 | command line, REPL, startup |

The Pascal is ulam's subset (ulam(7), ulam-port(7)), which Free Pascal
builds too: `{$H-}` (no AnsiStrings), no classes, no exceptions, no
dynamic arrays, no SysUtils, and a nested procedure uses its own locals
and the unit's variables, never those of the procedure around it. ulam
builds the concha that is installed; fpc builds the same text, and
`make test` runs the tests under both. System calls go through ulam's
`sys` (under fpc, its stand-in `rtl/fpc/sys.pas`), directories are read
with its `dir`, and what `sys` has no call for is in `kern.pas`, each a
`SysCall` with the kernel's number for amd64 and aarch64: the terminal's
settings and owner, process groups, `cd`, `umask`, `ulimit` and the time
of day.

Two units come from outside, installed under `~/.local/lib/pascal`:
`fuzzy`, wuzzy's matcher (fuzzy(3)), which ranks completions when nothing
starts with the word, and hora(3), whose zone `time()` reads for the
offset and the abbreviation at each instant (the zone `TZ` names, else
`/etc/localtime`, read at the first call).

Build with `make` (ulam) and `make build/fpc/concha` (fpc); the
`Makefile` says how to use a build tree's ulam. Test with `make test`,
or `./concha test.cn`, which runs `$CONCHA` or else `./concha`.

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

`Fail` prints a message and `Throw`s to the innermost `Catch`, with a
code: 1 an error, 2 more input wanted, 3 an interrupt or a stop, 4
errexit. `Catch(p)` runs the procedure `p` as a coroutine (ulam's `co`)
on a stack of its own, mapped once for each depth of `Catch` and given
pages by the kernel only as they are touched, and `Throw` transfers
straight back to the `Catch`, leaving that stack as it stands; this is
setjmp and longjmp, which ulam does not have, written down. A `Catch`
passes nothing to `p`, so what `p` needs is in variables beside it
(`RunGiven`, `SourceGiven`, `HookCall`). The REPL and the script runner
each `Catch` around the whole of their work. `Recover` then puts things
back: saved file descriptors are restored, local frames dropped, and the
control flag reset. In a forked child, `Fail` exits instead of throwing.
Free Pascal's stack checking (`-Ct`) knows only the main stack, so a
build with it fails at the first `Catch`.
Every statement and command keeps the line and file it was parsed
from (`path`, nil for typed lines and `-c`); `ExecStmt` and `Expand`
copy them to `curLine` and `curFile` for the message, and `CallProc`
puts back the caller's on return.
Two places catch an error closer in: the `complete` hook, and `source` run
by the `prompt` procedure (`SourceGuarded`), which puts back the frames
and saved descriptors it started with and returns status 1. Left to
the REPL, that error would turn the prompt procedure off for good.

A redirection that can't be opened is not a `Fail`. `Redirect` reports it
with `Warn` and returns `False`, and the command gets status 1 without
running, in the shell or in a child alike.

`break`, `continue` and `exit` never jump. They set `ctl`, which `ExecList`
and the loops check.

Jump codes: 1 is an error, 2 is incomplete input (the REPL asks for more),
3 is an interrupt or a stopped foreground job, and 4 is `errexit` (`ErrExit`). `exempt` counts the
reasons a failure may not trigger `errexit`: `RunChain` raises it around
every pipe but the last, and a capture's child raises it for good.

## Parsing: two worlds in one buffer

The parser works on the raw source, character by character, and only
statement starts decide which world it is in. `ParseStmt` looks at the
identifier under the cursor, without consuming it:

- a keyword → Pascal statement;
- an assignment (`name :=`, or `name[...] :=`) → assignment;
- anything else → `ParseAndOr`, which is command mode.

Pascal expressions are scanned into tokens with one token of lookahead.
`ExprRaw` fetches a token, parses, and then **rewinds** to the end of the
last token it used (`endPos`). Code after an expression therefore sees the
raw text again, including any newline that ends a command. `Next` never
fails on a character it doesn't know (`tOther`), because the lookahead
often lands on command syntax like `|`.

Command mode reads words as lists of parts (`TPart`): literal (quoted or
not), variable, expression, capture, `<(...)`, and home, which holds
the user of a `~user` (empty for `~`), at the start of a word or, in
`NAME=value`, after the first `=` or an unquoted `:`. `Passwd` reads `/etc/passwd` to find a user's
home; concha does not link libc, so there is no `getpwnam`. A backtick opens a capture
by calling `ParseList` recursively, so a capture holds statements.
`inBack` says whether a backtick in command mode closes a capture or opens
a new one: `ParseList`, `ParseCommand` and `TermAt` all stop at a closing
backtick. This is how `` `echo $(f(`date`))` `` nests without escaping.
A word that starts unquoted with `<(` is a process substitution, a
`ptSub` part alone in its word (`ProcSub`). Its list is parsed the same
way, with `inSub` set instead: a `)` then ends a bare word, a command
and a list (`EndsWord`). `ProcSub` clears `inBack` and `Capture` clears
`inSub`, so the innermost of the two decides what closes. With a space,
`< (` is still a redirection.

A bare `end`, `else` or `until` ends a command only if it closes something
open. `closers` holds the words that would: a `begin` or procedure body sets
it to `end` alone, a `repeat` body to `until`, a case arm to `end` and
`else`, and an `if` adds `else` to it while parsing the `then` branch. A
capture starts empty. Each of these saves and restores it, so the innermost
construct decides. `TermAt` checks it.

Heredocs: when `<<TAG` is parsed, the body is found after the end of the
current line and recorded as a *skip region*. `Adv` jumps over the region
whenever it steps past that newline. Two heredocs on one line chain their
regions. The body's interpolations are parsed right away by temporarily
moving `pos` into the region. An indented terminator sets `indent`, which
`Parts` strips after each newline.

An error at end of input sets no message when `quietEof` is on. Instead it
jumps with code 2, and that is how the REPL knows to print `. ` and read
another line.

Every syntax error goes through `SynErrAt`, which sets `curLine` and
`curCol` (core) from a byte offset and its line; the column is counted
back to the newline before it, so it is in bytes and right after a
heredoc. `SynErr` takes the scanner's place, `TokErr` the lookahead
token's (`tokPos`, `tokLine`), since `Pos` has moved past it by then;
an unterminated string names its opening quote, and an unterminated
heredoc its tag. A heredoc body is parsed with `line` set to the
body's own line. Only `-n` prints the column (`showCol`). `-q check`
sets `keepErr`, so `Warn` keeps the message in `errMsg` instead of
printing it, and `concha.pas` prints line, column and message.
`-q outline` sets `outlining`, and the parser notes (`Note`) each
`sProc` as its name is read, and each `var` or `export` name, on the
list `outline`, each with its `owner`, the proc it is inside
(`curProc`); the outline prints only the unowned vars; a procedure's last line is
filled in at its `end`. Noting as it goes, rather than walking the
tree after, gives the outline of what parsed before an error too.
`-q words` uses the same list: the variables in scope at a place are
the items before it whose owner is nil or contains it, and the
parameters (`params`) of the procs that contain it. After an error
`NoteProcsAfter` scans the remaining lines for `procedure`/`function`
names. The keyword, builtin and usage tables (`Keywords`, `BNames`,
`BUsage`, `CmdBNames`, `CmdBUsage`) are in `syntax.pas`; `test.cn`
checks each usage against the rendered `concha.1`.
A `TStmt`'s `col` is the name's byte column (`ColOf`), set for
procedures and declarations only.
Also while outlining, the parser notes each use of a name that could be
a procedure on the list `refs` (`NoteRef`): word 0 of a command when it
is one plain literal (`TCmd.col` and `len`, set only then), and an
`eCall` that is not a builtin (`TExpr.line` and `col`; `n` is its
length). Variables and the parts of a string get no position: nothing
asks where they are, and every `TExpr` and `TCmd` pays for the fields.
`-q dump`, hidden, prints the list for `test.cn`.
`-q def` finds the declaration or the use at the place, and resolves a
use's name (`Resolve`) among the outline's procedures: those owned by
the use's own procedure, then by its owner, outwards to the top, so the
innermost visible declaration wins, wherever it stands in the file.

Watch out for case: Free Pascal reads `pExpr` and `PExpr` as one name, and
ulam refuses two names that differ only in case, so each name has one
spelling, the run time library's where it has one (ulamport(1) made them
so). A local `At` shadows `At()`, and a bare `ParseStmt` inside `ParseStmt`
means its own result variable, not a call. Write `ParseStmt()` to recurse.

## Running commands

`RunAndOr` → `RunChain` (`&&`, `||`) → `RunPipe` → `RunSingle` or `RunMulti`.

Expansion always happens in the parent, before any fork. Errors and
captures therefore behave the same whether the stage is external or not.

- **Single stage, not external** (procedure, builtin, call, block): runs
  inside the shell. Redirections are applied with `SaveFd` (a `dup` above
  fd 10, close-on-exec), then undone with `RestoreFds`. The save stack is
  also unwound by `Recover` after an error. `exec` with no command sets
  `keepFds`, and `RunSingle` then keeps the redirections (`CommitFds`)
  instead of restoring them.
- **Single stage, external**: `fork`, apply redirections in the child,
  `execve` along `PATH`.
- **Several stages**: every stage is forked. An in-shell stage runs the
  interpreter in the child and exits with its status.
- **Tail exec**: a capture or background child that runs a single external
  command execs it directly instead of forking again (`tailOk`). For a
  capture, that means its list is one command statement, not in the
  background. The flag is cleared as soon as it is read, so commands nested
  in a procedure never exec over the child.

A `<(list)` is expanded by `OpenSub`, which forks as `Capture` does
but leaves the pipe's read end open in the shell (inherited, not
close-on-exec) and pushes it with the child's pid on `subs`; the word
is `/dev/fd/N`. `RunPipe` notes the depth of `subs` before the
command, and `CloseSubs` closes the read ends above it after, then
reaps the children, closing first so a writer still going dies of
`SIGPIPE` instead of blocking. Their status is dropped. `Recover`
closes them all, and a child closes those it inherited.

Heredoc and here-string input is written into a pipe. Content over 32 kB is
written by a forked writer, so the pipe cannot deadlock.

Job control is on only in the interactive shell (`jc`, set by
`JobControl` once the shell leads its own process group and holds the
terminal). The job table (`jobs`, in `interp.pas`) holds background jobs
and stopped ones, and the foreground job while it runs; entries are kept
in age order, and the last is the current job. A foreground command or
pipeline forks into a new group, which both parent and child set up
(`JoinGroup`, `ChildJob`) since either may run first; `WaitJob` waits on
the whole group and takes the terminal back. A stop leaves the job in the
table with its terminal settings and jumps to the prompt (code 3).
`ReapJobs`, before each prompt, reports what finished or stopped in the
background. `OnHup`, any shell's default for `SIGHUP`, passes it on to every
job before dying of it. Children always run with `jc` off, so their own
commands are not jobs.

A background list is a process group of its own, with or without job
control, led by the child shell that runs it (`RunAndOr`), or by the
program that shell execs for a lone command. That child
catches `SIGHUP`, `SIGTERM`, `SIGUSR1` and `SIGUSR2` with `PassOn`,
which resets the signal and sends it to the whole group, itself
included: so `kill $lastpid` stops every stage of a background
pipeline, and `wait` sees the child die of the signal. `SIGINT` and
`SIGQUIT` are not passed on, since the terminal already sends them to
the whole group, or they are ignored.

Without job control `WaitFor` waits for one pid with `WUNTRACED`. A
stopped child is sent `SIGCONT`, because nobody could resume it, unless
the waiter is itself part of a job (`jobChild`): then it stops itself
too, and `fg` or `bg` continue the whole group.

`GiveTerm` gives the terminal with the ioctl, which wants a pointer to
the group (Free Pascal's `TCSetPGrp` passed the group itself, and failed).

`SIGINT` sets `intr` without `SA_RESTART`. `ExecStmt` checks the flag
before every statement and jumps (code 3), so Ctrl-C breaks loops that run
inside the shell. Children reset their signals to the defaults. `WaitFor`
waits and sees, like bash: if the child it reaped was not killed by
`SIGINT`, it caught the Ctrl-C, and `WaitFor` clears `intr`. In a pipeline
the last stage decides; `intSeen` remembers a Ctrl-C an earlier stage
absorbed. Under job control the terminal sends `SIGINT` to the
foreground job, not the shell, and `WaitJob` sets `intr` if the job's last
process died of it.

`trap` keeps a small table, entry 0 being `EXIT`. A trapped signal's
handler (`OnTrap`) only sets `pend` and `trapPending`; `ExecStmt` runs
the procedures (`RunTraps`) next to its `intr` check. `ChildSignals`
forgets trap procedures but keeps ignored signals ignored. Every exit
of the shell goes through `Leave`, which runs the `EXIT` procedure once.

## Variables

The globals and the local stack are growable arrays of `TVarRec`.
`CallProc` pushes the parameters, `args` and `result` above `base`, runs
the body, and pops. The lookup order is the current frame, then the
globals. There is no access to enclosing frames. The names in `TVarRec` point
into permanent memory (the syntax tree or `PermStr`), so a frame costs no
name copies.

A pointer to a `TVarRec` is invalid after anything that can create a
variable, because the array may be reallocated. Look a variable up, use
it, and let the pointer go.

## Line editor

`EditLine` switches to raw mode, then asks the terminal for the cursor
position (`ESC [6n`, with a 0.2 s timeout). Everything is drawn relative to
that column. The editor never needs to know the prompt's width, so
coloured or procedural prompts cost nothing. Typed-ahead bytes that arrive
before the terminal's answer are pushed back.

`Refresh` works on offsets. The cursor's position is
`startCol + width(text before cursor)`. Dividing by the terminal width
gives the row and column. The editor remembers which row the cursor is on,
so a redraw moves up to the first row, clears to the end of the screen,
writes the line, and moves back. When the text ends exactly at the right
margin, it writes an explicit `CR LF`, so the terminal's deferred wrap
can't confuse the arithmetic. Widths count UTF-8 lead bytes.

With colour on, `Paint` draws the line through `Classify`, a small scanner
that gives every byte a class (comment, string, variable, keyword, ...).
Escapes go only into the output buffer; widths and the cursor are always
worked out from the raw text, so colour cannot upset the arithmetic.
The command word is coloured by the `known` hook, which `concha.pas`
points at `interp.KnownCommand`; `Runnable` remembers the last word asked
about, so typing elsewhere on the line looks nothing up.

History is an array of heap strings, capped at 1000. `Draw` shows a
suggestion, the rest of the newest entry that starts with the line, as
`Refresh`'s dim suffix; `Plain` draws without one, for the final draw
of an entered or cancelled line. `EditLine` is told whether the line is
a continuation, which gets no suggestion. Ahead of history comes
`offer`, a corrected line: `interp.Correct` sees, before forking, that
an external command at the prompt will not be found and calls
`Propose` with its "did you mean", which swaps the word in the newest
history line and keeps the result in `fixed`; the next `EditLine`
moves it to `offer`, so it lasts one line. Each entered line is
appended to `~/.concha_history` right away, so concurrent shells interleave
rather than overwrite. The file is rewritten, trimmed, when loading finds
it more than half again over the cap.

Tab completion is split in two. `edit` scans the line up to the cursor to
find the current word, whether it sits in a quote, and its context:
`cxCommand` where a command belongs (at the start, after `|`, `;`, `&`,
`` ` ``, `(`, or after `then`, `do`, `else`, `begin`, `repeat`),
`cxExpr` in a Pascal expression (after `:=`, after a keyword that takes
one, or inside a parenthesis opened right after a word, which covers
calls and `$(`), `cxDir` for the arguments of a `cd`, and `cxArg`
elsewhere. `Scan` keeps one bit per open
parenthesis to know what a `)` returns to. It also notes where the
command's words lie (`TSpans`), leaving out redirections. It unquotes
the word, and those, and hands them to the `completer` hook, which
`concha.pas` points at `interp.Complete`: that knows the keywords,
`PATH`, the builtins, the procedures and the variables. If nothing
starts with the word it tries again with `FuzzyScore` and hands back
the matches ranked (`Rank`), which `edit` then leaves unsorted. For an
argument it first calls the user's `complete` function (`Hook`), with
fds 0 to 2 on `/dev/null`, `status` kept, and its own `Catch` so an
error in it is only an empty answer. Candidates come back
unquoted, and `edit` sorts them and inserts the common prefix,
re-escaped for the quote it is in (`Take`). `Candidates` does the
finding, for Tab and for the `completions` builtin alike: `Completions`
points the scanner at the given line, the cursor at its end, and puts
the edited line and `wd` back after, since a `complete` function may
call it while Tab waits. When there is nothing to insert, `Menu`
runs a loop of its own, as `^R` does: it draws the candidates below
the line through `Show`, the one drawing routine,
which writes rows after the line and moves back up, so the next redraw's
clear to the end of the screen wipes the menu. Stepping through it
replaces the word with each candidate; the first key it has no use
for goes back to `EditLine`.

After the user's `complete`, an argument looks for the command's
completion file, concha-complete(5) (`SpecFind`, under the XDG data
directories). It is read on every Tab, into the arena, as a list of
fields per line (`SpecLines`), and nothing in it can run anything:
Tab must never start a process. `SpecSays` walks the words before the
cursor, keeping the scope, the operand count, whether `--` has been
seen and an option waiting for its value, then says what the word
may be: names to offer (subcommands, options, `one` and `in` words),
plus a `ck...` kind that `Complete` turns into its usual rules
(`file`, `dir`), nothing more (`word`), or a command line of its own
(`command`), which it completes by calling itself on the words from
there on. A value after `--name=` is completed the same way, alone,
and `--name=` put back in front.

`^X^E` works the same way: `edit` writes the line to a file in `/tmp`, and
the `editor` hook, `interp.EditFile`, runs `$VISUAL` or `$EDITOR` on it
through `RunArgs`, so the editor may be a procedure and gets the
terminal as a foreground job.

Every key but undo first pushes the line on a small undo stack (64
steps, oldest dropped), and pops it again if the key changed nothing;
a run of typed characters shares one step. Kills go to one buffer,
`killBuf`, which kills in a row extend.

The terminal is back in cooked mode before a line runs, so commands see a
normal tty and Ctrl-C works. `EditReset` also runs during error recovery,
in case a `prompt` procedure fails while the editor is redrawing.

## Adding a builtin

- **Routine:** add its name to `BNames` and a `b...` constant in
  `syntax.pas`, then a case to `Builtin` in `interp.pas`. Use `Need` to
  check the argument count, and `ArgVal`/`ArgS` to evaluate arguments.
- **Command:** add a `cb...` constant and its name to `CmdBNames`, then a
  case to `RunCmdBuiltin`. It receives the expanded words, with element 0
  being its own name.
