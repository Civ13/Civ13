# Wild West mounted raids

`python3 tests/wildwest_raid/run.py --byond-bin <BYOND bin>` first checks that
the Little Creek outlaw role puts its player in the saddle after spawning on
Big Trouble in Little Creek (TDM) and that a rider's moves call `hoof_dust()`.
It then compiles the production game with normal startup disabled plus
`probe.dm`, starts the MC timer loop the way `world/New` does, and drives
`code/modules/1713/wildwest_raid.dm` on real horses:

- off the raid map nobody is mounted;
- an outlaw takes a free, living horse within five tiles (brought to them, no
  new horse made), never a dead one; someone already riding is left alone; with
  no free horse nearby the next outlaw gets exactly one new horse;
- a ridden horse leaves a puff of dust on open ground, at most one per
  interval, none on water or indoors, and only horses do; every puff settles
  and is deleted;
- moving the rider through `Move()` takes the horse along and leaves dust where
  the horse was.

`--negative-control no-timer-loop` skips `Master.start_timer_loop()` and must
fail (the dust never settles).

Not covered: a real client riding and the look of the dust on screen. The
in-game render tool cannot draw human bodies (their icons are built at run
time), so no still is included.
