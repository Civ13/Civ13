# Petroleum lifecycle regression

Run with BYOND 516.1681:

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<BYOND bin directory>' -Probe tests/petroleum_lifecycle/probe.dm
```

The shared launcher compiles production sources with ordinary game startup disabled and uses temporary output and save storage. The fixture closes its listening port. It checks repeated barrel restart requests, a bounded ten-unit extraction batch, full/deleted barrels, null-safe unload/save, barrel return on destruction, removed springs, callback settlement, and single-chain spring refill. Real disk-backed entry and populated-turf round trips check well identity, both connected/spare barrels, petroleum, relinking and a fresh extraction deadline. Empty saved wells must never claim unrelated floor barrels.

Click an empty wooden well to connect a nearby non-full barrel. Saving stops extraction while retaining the barrel in native contents; unloading or destroying the well returns the live barrel to the turf.

The wooden well retains its existing renewable spring behavior. This test does not establish full-world save compatibility, graphical gameplay acceptance, production memory stability, or finite hydraulic fracking. Extended CI runs this probe alongside the resource extraction fixture.
