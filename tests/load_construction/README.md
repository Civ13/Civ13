# Saveable types built the way a load builds them

`python3 tests/load_construction/run.py --byond-bin <BYOND bin>` compiles the
production game with normal startup disabled and constructs every saveable
`/datum` type on a 40x40x1 world, the way `Load_Entry` does. Atoms use
`new type(loc)` while `persistence_saved_atom_construction` is set, and other
datums use `new type()`.

A constructor that throws aborts the whole import, as the vending product
record did on Gaia on 2026-11-05 (#3681). A constructor that keeps
rescheduling itself in the same tick, such as a spawner with `timer = 0`,
stalls the server.

The run fails in any of these cases:

- a type fails that `known_failures.txt` does not list;
- a listed type now constructs cleanly (remove it from the list);
- the sweep does not finish within `--timeout` seconds.

Progress lines in the evidence `runtime.log` (one every 200 types) narrow a
stall down. Use `--range START STOP` to bisect it.

Negative controls each revert one fix and must fail:

- `--negative-control zero-timer` stalls on the Professor Snip spawner.
- `--negative-control vehicle-names` runs out of Soviet vehicle names.

The sweep takes about a minute after compilation. It only covers construction.
Field restoration and `after_load` are covered by the world save tests and the
focused load probes, such as `tests/vending_load`.
