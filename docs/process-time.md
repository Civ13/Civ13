# Object processing time

The legacy scheduler stores `schedule_interval` in BYOND deciseconds.
`configured_interval_seconds()` converts that configured cadence to seconds.
It does not measure elapsed wall time or compensate for lag, paused runs,
tick-budget resumes, or missed callbacks. Scheduler queuing and ordering stay
unchanged.

Objects opt into seconds by overriding `process_interval(configured_seconds)`.
The base adapter calls `process()` without forwarding arguments. This matters
for the welding tool's existing `process(mob, welding_tank)` contract. Other
legacy overrides and direct callers retain their old semantics.

Matches, ordinary/lard candles and flares consume legacy stored fuel units at
`configured_seconds / 2`. At the configured two-second object cadence their
balance is unchanged. Direct `process()` calls delegate with two seconds.
Fuel/wax/smoketime retain their save representation; fractional final units
expire at zero. Reagent transfer in smokables, damage, animation, probabilities,
and production recipes remain per-call behavior pending separate audits.
Subclasses of migrated types should override the interval method for scheduled
behavior, retaining a direct-call wrapper if needed.

The audit covered object overrides under `code/game/objects` and
`code/modules/1713`, plus process call sites across `code`. The separate
machinery, projectile, mob and scheduled-task contracts are not migrated.
No blanket argument forwarding or balance conversion applies to them.

Public reference: CM configured `wait * 0.1` processing convention at
`85161b1096019c1daf4f756b0c0b216a80da683f`,
`code/controllers/subsystem/processing/processing.dm`. This implementation uses
Civ13's legacy contracts; reference comments describing delta time do not make
the configured interval an actual lag measurement.

Run `tests/process_time/run.py --byond-bin <516.1681-bin>` and repeat with
`--negative-control units`, `legacy`, and `fuel`. Extracted production methods
run with inert graphics/deletion adapters and temporary storage. They verify
conversion, legacy typed arguments/returns, default balance, fractional fuel,
expiry, and configured rather than elapsed time. They do not establish client
rendering, production latency, or performance improvements.
