# Large-map turf registration

Turf construction registers each tile in the global daylight registry. A list
union searched all previous tiles for every registration, producing quadratic
startup work on large maps. The registry now uses a transient per-turf flag
and appends only unregistered turfs in OpenDream, preserving duplicate protection.
Native BYOND retains its associative membership index because native turf
replacement retargets list references differently. Destroy removes registry
membership. The OpenDream flag is not a saved turf field.

Run the isolated production-constructor regression with:

```powershell
& '<verified-python>' tests/turf_registration/run.py --byond-bin '<516.1681-bin>'
```

The fixture checks initial counts, repeated constructors and native turf
replacement. It does not prove client rendering or whole-server longevity.
Local OpenDream Gaia startup was sampled in `DreamList.ContainsValue` under
`OperatorCombine` during map initialization before the fix. With direct append,
the actual Gaia server reached Ready and accepted an authenticated connection.
An associative membership index also caused quadratic insertion in the shipped
OpenDream engine: DreamList.SetValue calls ContainsValue for new keys. The
per-turf flag avoids both scans and preserves duplicate behavior. Timings are
machine-dependent.
