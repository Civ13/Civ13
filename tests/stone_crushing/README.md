# Stone crushing

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/stone_crushing/probe.dm
```

Production sources run in the shared resource-extraction constructor fixture with ordinary game startup disabled. Only the hand crusher's action wait is replaced, through a probe subtype, so the production crushing loop runs unchanged. A real cable/engine reservation powers the stamp mill.

The probe checks the per-age odds tables and weighted roll, one-stone payment per roll, output congestion refusing before any stone is spent, the worked loop and its distance and anchoring guards, the stamp mill hopper limit, start/stop/toggle callbacks, the four-second stamping interval, power release, empty-hopper stop, the inherited load hook, unloading, research gates and the actual recipe catalog, and the reused DMI states.

Both machines reuse existing art: the grindstone state in `icons/obj/structures.dmi` and the industrial drill states in `icons/obj/machines/mining_drill.dmi`. Runtime fixture checks do not establish graphical interaction, full-world persistence or live balance.
