# Air support you can see

`python3 tests/air_support/run.py --byond-bin <BYOND bin>` first checks that
`turf/try_airstrike` shows the jet on all three strike paths (plain, admin and
after evading a SAM), that rockets trail smoke, and that Syria's Delta Force
operators carry a laser designator. It then compiles the production game with
normal startup disabled plus `probe.dm`, starts the MC timer loop the way
`world/New` does, and sends real jets through `air_support_jet_pass()`
(`code/modules/1713/weapons/air_support_jet.dm`):

- aircraft without art (P-47, Stuka, IL-2) and unknown directions draw nothing;
- a mid-map strike starts the jet on the attack line behind the target, drawn
  as the right aircraft, above roofs and trees, with its shadow on the ground,
  reaches the release point when the payload leaves, flies on and deletes
  itself and its shadow;
- near a map edge the launch waits off the map, so the jet still crosses the
  target on time; deleting a jet mid-flight takes its shadow;
- a rocket's smoke trail puts puffs behind it on its track, and every puff
  fades and is deleted.

`--negative-control no-timer-loop` skips `Master.start_timer_loop()` and must
fail (no jet moves and no puff appears). The run takes about 20 seconds after
compilation.

Not covered: how the jet looks in a real client (the in-game render tool shows
a staged still only) and a full strike called from a designator by a player.
