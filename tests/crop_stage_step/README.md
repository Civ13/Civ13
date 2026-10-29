# Shared crop-stage boundary: offline parity

This slice extracts only `advance_stage_if_allowed(allow_stage)` from the ordinary
crop's existing post-wait stage/terminal boundary. The caller retains all soil,
water, map, climate, season, constructor and wait ownership. The helper preserves
virtual `stageGrowth()` dispatch and the terminal check on the no-advance path.
It introduces no hydroponics activation, new plant, recipe, quantity/payment,
research, weather/death tuning, registry or save field.

Run from a complete checkout, or the isolated source export used for this review:

```powershell
py -3 -I -S tests/crop_stage_step/test_source.py
```

Use `--only test_method_name` for a focused repair. The test uses Python's standard
library and does not launch a compiler, game, client, network or subprocess.

`baseline_growth.json` retains the actual growth proc from the exact commit in
`source.json`, including its whitespace. Replacing only the new growth proc/helper with this baseline must
reconstruct the full original farming file's Git blob. That protects every other
definition, subtype, constructor, harvest/resource proc and field byte-for-byte.

The tests project the actual before/after callback, base stage proc and selected
subtype overrides through a restricted, fail-closed syntax adapter. They compare
ordered calls, stages, RNG requests and termination over the six approved ordinary
crop definitions, six restricted maps plus a fixed-era map, climate/season cases,
nutrition thresholds, readiness/death boundaries and indoor/outdoor areas.
Additional cases cover pending dead/static/deleted plants, missing turf/area,
mushroom indoor exceptions, turnip shelter rejection, plump-helmet probability,
timber's separate scheduler and terminal checking when advancement is refused.
Four in-memory mutation controls bypass eligibility, bypass virtual dispatch,
omit terminal appearance or double-advance; each must differ on its named witness.

Native location/type checks, random draws, `set_dead` effects and recursive entry
are injected observers. The unchanged pre-wait body is protected by exact source
comparison, not executed here. This is offline source parity evidence, not DM
compilation, native callback timing, actual weather, save/load or graphical proof.

The plant-lifecycle native extractor now conditionally includes the new helper;
its historical `-Revision` baselines retain the old proc list. No native fixture
was executed. That historical runner still checks compiler516.1681, whereas the
current main toolchain is516.1688; resolving any admitted native packet remains
Main's responsibility. This slice does not update pinned native runtime tooling.
The offline suite is registered in `scripts/ci_baseline.py`; changes to shared
`farming.dm` retain the conservative all-suite fallback. The registry imports only
the stdlib source projection, never the native lifecycle runner.

Fragile-crop shortage thresholds and poor-weather timing remain unsettled. The
existing outdoor age/death behavior is preserved; no tray holding/death policy
is implemented by this extraction.
