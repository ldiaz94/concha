# What raz lacks, or makes awkward

Found while porting concha from Free Pascal, for raz's owner. Each says
what was wanted, what concha does instead, and how much it cost.
`~/r/sauce/RAZ-NOTES.md` has what the port before this one found.

## The library

- **What a shell needs of `Sys`**, fork and exec, moving fds, a
  handler for a signal, a terminal's modes for each job, the process
  group and the rest, was proposed in two parts and is in raz 0.16.0;
  `Ckern` went with it.

## The language

- **A slice's pointer can't be had.** The report gives a slice's
  layout, `ptr` and `len`, but only `LEN` reaches it; `ADR(s[0])` is
  the pointer, and fails its check when `s` is empty. `Ccore` keeps a
  value as a kind, a length and a pointer, as the Pascal did, and each
  place that makes one from a `Buf` or a `Vec` tests for the empty one
  first (`bufVal`, `listVal`). Proposed as `PTR(s)` in raz's
  `PROPOSALS.md`, "A slice's pointer".

## The compiler

- **A `try` in a loop's condition, and another way out of its body,
  crash it in a procedure with a `defer`.** raz 0.17.0 stops with a
  bad address in `X64.fixLinkTo` (from `Gen.endProc`) compiling either
  of these, `t` returning `(BOOL, ERROR)`:

      proc f: ERROR;
      begin
          defer n := 0;
          while try t() do _ := try t(); end;
          return nil;
      end;

      proc g: ERROR;
      begin
          defer n := 0;
          repeat
              if n = 2 then break; end;
          until try t();
          return nil;
      end;

  Without the `defer` both compile, and so do `repeat _ := try t();
  until try t();` and a `try` in an `if` of the body. `Cinterp.execStmt`
  writes its `while` and `repeat` statements as `while true do`, the
  test an `if` in the body; no cost.
