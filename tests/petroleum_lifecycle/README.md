# Petroleum lifecycle regression

Run with the BYOND pin in `tools/byond/version.json` (currently 516.1688):

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<BYOND bin directory>' -Probe tests/petroleum_lifecycle/probe.dm
```

The shared launcher compiles production sources with ordinary game startup disabled and uses temporary output and save storage. The fixture closes its listening port. It checks repeated barrel restart requests, a bounded ten-unit extraction batch, full/deleted barrels, null-safe unload/save, barrel return on destruction, removed springs, callback settlement, and single-chain spring refill. Real disk-backed entry and populated-turf round trips check well identity, both connected/spare barrels, petroleum, relinking and a fresh extraction deadline. Empty saved wells must never claim unrelated floor barrels.

Click an empty wooden well to connect a nearby non-full barrel. Saving stops extraction while retaining the barrel in native contents; unloading or destroying the well returns the live barrel to the turf.

The wooden well retains its existing renewable spring behavior. This test does not establish full-world save compatibility, graphical gameplay acceptance, production memory stability, or finite hydraulic fracking. Extended CI runs this probe alongside the resource extraction fixture.

## Orphan barrel recovery

`python3 -m unittest discover -s tests/petroleum_lifecycle -p 'test_*.py' -v`
executes the complete production ownership helpers with fake engine boundaries,
including controls that restore the old full-barrel filter and single-barrel
destruction. The registered `oilwell_barrels` suite is offline evidence only.

The native probe also saves and reloads a turf containing a well with four
unlinked barrels (two full, one empty and one part-filled with water), plus an
unrelated floor barrel. It verifies exact counts and reagent totals, original
object identity during manual/automated removal, pipe output, refusal of another
insert, and destruction both with and without a runtime link. The shared
chemistry probe adds automatic acceptance/offer/take checks for a full orphan.

A well recovers one contained barrel at a time, regardless of capacity. Repeated
manual removals or automation requests expose the remaining barrels; destruction
returns every contained barrel to the turf. No replacement barrel or reagent is
created. An unrelated floor barrel is only selected by explicit floor loading.
These entry/turf fixtures do not establish full-world or live-save acceptance.

## Offshore drilling rigs

`tests/petroleum_lifecycle/offshore_probe.dm` runs through the same launcher
(`-Probe tests/petroleum_lifecycle/offshore_probe.dm`; on Linux
`python3 tests/ecology_spawning/run_linux.py . tests/petroleum_lifecycle/offshore_probe.dm`).
It pins the seabed field model to independently computed values (richness per
eight-tile square, about one square in three), checks that only deep saltwater
holds offshore oil, the build refusals (no deck, dry seabed, second rig), a
thirty-unit cycle on a rich field, save/load relinking, unloading, a rig over
dry seabed pumping nothing, and barrel return on destruction. It does not
establish graphical or live-save acceptance.
