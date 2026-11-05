# Wildlife spawner caps

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/wildlife_spawner/probe.dm
```

Map mob spawners save only their field allowlist, so their head count
(`current_number`) never survived a load. Each restart refilled every spawner
on top of its restored animals, and long-lived worlds such as Gaia piled up
many times the intended population near each spawner.

Production sources run in the shared constructor fixture with ordinary game
startup disabled. A probe gorilla skips AI start-up but joins the real
`living_mob_list`; a probe spawner skips its timer loop so the probe drives
`spawnerproc()` directly.

It checks that spawned animals register with their spawner, deaths free a slot,
the head count is runtime-only, restored animals rebuild it from their saved
`origin` in `after_load()`, the once-per-load cull removes only untamed animals
above the quota (farthest first), and unowned animals of the same kind near a
spawner keep it quiet until they die or wander off.

Not established: a real Gaia save/load cycle, client visibility during the
cull, or how the population settles on a live server.
