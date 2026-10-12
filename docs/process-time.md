# Object processing time

The legacy scheduler stores `schedule_interval` in BYOND deciseconds.
`configured_interval_seconds()` converts that configured cadence to seconds.
It does not measure elapsed wall time or compensate for lag, paused runs,
tick-budget resumes, or missed callbacks. Scheduler queuing and ordering stay
unchanged.

Objects opt into seconds by overriding `process_interval(configured_seconds)`.
The base adapter calls `process()` without forwarding arguments. This matters
for compatibility with typed legacy signatures, including the historical
commented welding-tool `process(mob, welding_tank)` example. Other
legacy overrides and direct callers retain their old semantics.

Matches, ordinary/lard candles and flares consume legacy stored fuel units at
`configured_seconds / 2`. At the configured two-second object cadence their
balance is unchanged. Direct `process()` calls delegate with two seconds.
Fuel/wax/smoketime retain their save representation; fractional final units
expire at zero. Noose/gallows oxygen loss becomes 2.5 units per configured second;
neck-snap probability uses independent-event survival composition calibrated
to the original 5% per two-second callback. At two seconds the original 5%
is returned exactly. Direct `fire()` calls retain their two-second default.
Cosmetic movement/message chances, reagent transfer, other damage/probabilities,
and production recipes remain per-call behavior pending separate audits.
Subclasses of migrated types should override the interval method for scheduled
behavior, retaining a direct-call wrapper if needed.

At base `aa675de6dbade0f3740c516dc4b5945c5c9a43c7`, the comment-stripped
lexical audit found 78 active object `process()`
declarations across `code`, all with empty signatures. It also inventoried
explicit and implicit direct calls. These include organ/human Life, HUD,
submarine, projectile, factory, oven and furnace dispatch. The separate
machinery, projectile, mob and scheduled-task contracts are not migrated.
No blanket argument forwarding or balance conversion applies to them.

| Declaration family | Count | Disposition |
| --- | ---: | --- |
| `code/game/objects` | 24 | Four flame lifetime overrides migrated; remaining legacy dispatch retained |
| `code/modules/1713` | 13 | Noose/gallows damage and neck-snap chance migrated; remaining overrides retained |
| `code/_onclick/hud` | 14 | HUD callback contract retained |
| `code/modules/submarine` | 10 | Separate submarine process loop retained |
| `code/modules/organs` | 9 | Human Life/organ direct calls retained |
| `code/modules/magic` | 5 | Existing magic callbacks retained |
| `code/modules/projectiles` | 2 | Projectile/targeting contracts retained |
| `code/game/mob` | 1 | Grab callback retained |

The counts are declarations in comment-stripped source, not a compiler-resolved
call graph. Some subtypes inherit callbacks and some sources are excluded by
the DME. The full build verifies the selected compilation environment.

Public reference: CM configured `wait * 0.1` processing convention at
`85161b1096019c1daf4f756b0c0b216a80da683f`,
`code/controllers/subsystem/processing/processing.dm`. This implementation uses
Civ13's legacy contracts; reference comments describing delta time do not make
the configured interval an actual lag measurement.

Run `tests/process_time/run.py --byond-bin <516.1681-bin>` and repeat with
`--negative-control units`, `legacy`, `fuel`, `damage`, `probability`, and
`dispatch`. Extracted production methods
run with inert graphics/deletion adapters and temporary storage. They verify
conversion, legacy typed arguments/returns, default balance, fractional fuel,
expiry, damage, probability composition, production-loop dispatch/kill/error
handling, snapshot removal and budget-yield/resume behavior. RNG calls use an injected recording adapter;
the arithmetic is tested deterministically. The configured-time contract is
verified by source/argument assertions, without simulating lag. These tests
do not establish client rendering, production latency, or performance improvements.
