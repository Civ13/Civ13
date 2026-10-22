# Heater discovery: offline review evidence

Base: `9db2b2f42a5fbbb0bdd49d50a2672da6111a7709` (master fetched 2026-10-22).
No `.agents/skills` or nested AGENTS.md is tracked at that base.

Run with Python 3.10+ (use a verified absolute executable on Windows):

```
python -B -m unittest discover -s tests/local_discovery -p test_temperature.py -v
```

Tests translate the complete production `get_temp` from the local immutable Git
base and candidate. They compare 18,522 environmental combinations and 12,636
heater-state/threshold combinations, plus radius/z/subtype/order cases. The
environment matrix includes seasons, climates, time, weather intensities, storms,
inside/outside, Antarctica, other and absent maps, with rotating heater scenarios.
Separate null-atom/area checks retain the 20C default. Independent expectations
preserve Antarctica's 19C oven and later heaters' ability to raise it to 22C.
Two generated-source controls reject a 22C oven and an incorrect 19C heater gate.
Whole-file projection proves everything outside the heater block is unchanged;
no proc return was introduced, so the existing final return remains in place.

| Synthetic scenario | Base range calls | Candidate range calls |
| --- | ---: | ---: |
| Outdoor at least 22C | 4 | 0 |
| Cold, no active heater | 4 | 4 |
| Cold, first active heater family (brazier/heatsource/fireplace/engine) | 4 | 1/2/3/4 |
| Antarctica inside, cold, oven only | 5 | 5 |
| Antarctica inside, cold, oven then brazier | 5 | 2 |
| Antarctica inside, 19C, no active heater | 5 | 4 |
| Antarctica inside, 22C | 5 | 0 |

The adapter injects inclusive Chebyshev range, explicit type inheritance and
plain state records; it is not a DM compiler or native range/type oracle. Its
numeric rounding adapter does not establish BYOND arithmetic compatibility.
Identical pre-heater source and shared arithmetic adapters support differential
parity, not independent native numeric acceptance. Counts are synthetic calls,
not measured engine cost or speedup. No wall-time or memory claims are made.
BYOND 516.1681 compilation, the existing weather fixture and any needed graphical
acceptance remain pending separate capacity/authorization. No native game
process, OpenDream, client, port or external-effect adapter runs.
