# Gun configuration regression

Run with the pinned BYOND 516.1681 binaries:

```powershell
./tests/gun_configuration/run.ps1 -ByondBin '<BYOND bin directory>'
./tests/gun_configuration/run.ps1 -ByondBin '<BYOND bin directory>' -NegativeControl
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

`preview.py` recreates the explicitly authored sprite pixels and preview with Pillow.
It uses no AI art or screenshot substitution.
