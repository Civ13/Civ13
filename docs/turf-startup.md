# Large-map turf registration

Turf construction registers each tile in the global daylight registry. A list
union searched all previous tiles for every registration, producing quadratic
startup work on large maps. The registry now uses an associative membership
index and appends only absent turfs, preserving duplicate protection. Destroy
removes the turf from both lists.

Run the isolated production-constructor regression with:

```powershell
& '<verified-python>' tests/turf_registration/run.py --byond-bin '<516.1681-bin>'
```

The fixture checks initial counts, repeated constructors and native turf
replacement. It does not prove client rendering or whole-server longevity.
Local OpenDream Gaia startup was sampled in `DreamList.ContainsValue` under
`OperatorCombine` during map initialization before the fix. With direct append,
the actual Gaia server reached Ready and accepted an authenticated connection.
The durable membership-index revision additionally preserves duplicate behavior
and passes the native replacement fixture. Timings are machine-dependent.
