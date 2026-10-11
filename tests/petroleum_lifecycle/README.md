# Petroleum lifecycle regression

Run with BYOND 516.1681:

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<BYOND bin directory>' -Probe tests/petroleum_lifecycle/probe.dm
```

The shared launcher compiles production sources with ordinary game startup disabled and uses temporary output and save storage. The fixture closes its listening port. It checks repeated barrel restart requests, a bounded ten-unit extraction batch, null-safe unload/save, barrel return on destruction, removed springs, callback settlement, and single-chain spring refill. A real disk-backed entry round trip checks the well name, barrel petroleum, relinking and a fresh extraction deadline.

The wooden well retains its existing renewable spring behavior. This test does not establish full-world save compatibility, graphical gameplay acceptance, production memory stability, or finite hydraulic fracking. Extended CI runs this probe alongside the resource extraction fixture.
