# Gun configuration regression

Run with the pinned BYOND 516.1681 binaries:

```powershell
./tests/gun_configuration/run.ps1 -ByondBin '<BYOND bin directory>'
./tests/gun_configuration/run.ps1 -ByondBin '<BYOND bin directory>' -NegativeControl
./tests/gun_configuration/run.ps1 -ByondBin '<BYOND bin directory>' -FeedbackNegativeControl install
```

The runner compiles production sources with normal world startup disabled and
uses temporary runtime storage. It caps compilation at 120 seconds, runtime at
90 seconds, working set at 512 MB and CPU at 40 seconds, cleaning only owned
processes and uniquely named probe files. Evidence remains in its printed temporary
directory. Configuration waits and actor inventory are injected adapters.

Assertions cover incompatible mounts/calibers, required tools, loaded ammunition,
post-wait ownership, cancellation, concurrent reservations, reversible cycles,
native firing dispersion, cleaning thresholds, bench costs and production serializer
round trips including legacy SVD migration. This is isolated runtime evidence,
not a graphical or live-service acceptance claim.

`feedback.dm` exercises the production gun/bench `attackby`, attachment removal,
and configuration/maintenance completion paths. Only the outgoing chat sink is
captured: assertions check the actor recipient, actual item names and exactly one
message, plus no success on cancellation/ownership loss or during constructor
installation and recomputation. Public rejection keeps its existing single warning.
`-FeedbackNegativeControl install`, `remove`, and `service` remove completion
messages from generated source; `premature` inserts an install message before the
wait. Each must fail its named regression without a runtime error. CI runs all four
when this suite is selected. This does not exercise connected-client chat rendering.

`preview.py` recreates the explicitly authored sprite pixels and preview with Pillow.
It uses no AI art or screenshot substitution.
