# Carriages

`probe.dm` is a native fixture probe for
`code/game/objects/structures/carriage.dm` and
`code/modules/craft/carriage_papers.dm`: the team's pull and top pace, load
and the pace it costs, the footprint and team lane for each facing, boarding
(reins, seats, cargo, harness), steps and what stops them (walls in the lane,
people, deep water, a bridge), turning and when it is refused, hunger and the
harness, the papers and the lock on the reins for strangers, saving the
papers and the name, getting off, a dead horse and a destroyed carriage.
It also checks the hand carts in `code/game/objects/structures/hand_cart.dm`:
an empty cart drags more easily than a crate, the load makes it harder up to
a cap, and the handles turn toward the puller and stay put on a blocked pull.

    python3 tests/ecology_spawning/run_linux.py . tests/draft_carriage/probe.dm 300

It expects `"failures": 0`. Steps are made by calling `do_move()` as the
timer would, so timing and the client's glide are not exercised here;
`tests/carriage_glide/ride.py` drives the real reins and timer in a full game
and checks that the driver, both horses and the carriage share each step's
glide. No client connects, so do_after waits, menus and Dream Seeker's
drawing are not checked.
