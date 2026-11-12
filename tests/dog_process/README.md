# Dog process offline regression

Run `python -B -m unittest discover -s tests/dog_process -v` with a verified
Python interpreter. The checked-in `historical-fire.dm` is the original fire
procedure from base commit `29cd340e`; it is a fixed fixture and does not read
Git history. The test translates a closed vocabulary from both procedures,
preserving indentation and loop `continue` scope. Unsupported statements fail.

The Python adapters represent coordinates, object density, deletion, and the
result of the ecology and target-type checks as inputs. `step` is recorded as an
attempt, not successful movement. Scheduler macros are recorded as reached; list
mutation, budget returns, DM iteration, exceptions, callbacks, collisions and
the engine's movement semantics are not simulated. In particular the existing
stale-mob and dense-turf outer continues bypass both scheduler checks. This test
does not compile or run BYOND, establish gameplay, or measure performance.
