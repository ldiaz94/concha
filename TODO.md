# TODO

Findings for the user to schedule.

- `exec 3< <(list)`: after the command the shell waits for the list,
  which blocks while the list still has more to write than the pipe
  holds and nobody reads fd 3. Left on purpose (Luis, 2026-10-06):
  rare.
