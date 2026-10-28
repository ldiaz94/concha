# TODO

Findings for the user to schedule.

- `exec 3< <(list)`: after the command the shell waits for the list,
  which blocks while the list still has more to write than the pipe
  holds and nobody reads fd 3. Left on purpose (Luis, 2026-10-06):
  rare.
- No hex formatting and no UTF-8 decoding: there is no `hex` or
  `format`, and `length`, `ord` and `copy` work on bytes (`ord('─')`
  is 226). So a script can't write a character as a JSON `\uXXXX`
  escape; cyk's `test/cast.cn` writes raw UTF-8 instead (2026-10-20).
  oku's `test/cast.cn` counts screen columns with a helper of its
  own that reads `ord` byte by byte (2026-10-22).
