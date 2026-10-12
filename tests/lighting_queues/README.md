# Lighting queue verification

Pinned engine: BYOND 516.1681. All tests use temporary offline storage, close the
daemon port at startup and reject reopening. No ordinary game startup or maps run.

`run.py --byond-bin <bin> --size 500 --output <json>` compiles unchanged production
lighting process bodies with trivial callback adapters. Repeat with `--baseline`
and sizes 500 and 20000 for comparable normal/overload queue bookkeeping. Five
drain/disposal cycles check one callback per entry, FIFO completion, no starvation,
completed queue ownership, reentry rejection and immediate consumed-slot release.
The immutable baseline is `4e6211fe1a50519f91104fa32da32990baf0f4d4`.

Reports record summed/peak `world.tick_usage` differences, drain duration,
oldest-entry completion lateness, an independent nominal tick heartbeat and OS
private-byte samples every 20ms. At 20fps one tick-percent unit is approximately
0.5ms of engine-measured execution. Windows process CPU seconds include startup,
allocation and teardown; they are not the per-phase CPU estimate. Final private
bytes are a teardown sample, not settled retained memory. Linux uses smaps private
bytes. Memory and CPU measurements are observations, not assertions about OOM,
whole-server latency, client rendering or long-runtime stability.

`--negative-control skip` must fail the missing/duplicate callback contract.
`--negative-control retain` must fail consumed-reference release. Both mutate only
generated source and require the expected diagnostic, not any arbitrary failure.

`run_native.py --byond-bin <bin> --baseline --output <baseline.json>` compiles full
production sources with ordinary startup and maps disabled. Then run without
`--baseline`, with `--compare <baseline.json> --output <current.json>`. It compares
every overlay color and luminosity over five cycles on a 32x32 fixture with 200
moving/recolored-power light sources. Production corners, light check/remove/apply,
dirty flags and overlay calculations are unchanged. Dynamic enqueues, destroyed
and deleted sources, invalid-overlay retirement, cancellation and batch transfer
exercise budget boundaries. This is native lighting-state parity, not a graphical
client or production benchmark. A sandbox daemon startup failure is not a pass;
use the authorized isolated execution context and require completion plus clean
engine diagnostics. Both runners require zero compiler errors and warnings.

CI selects this registered suite only when executable tests are introduced in a
PR or extensive regressions are explicitly enabled. It gates correctness, not
noisy performance thresholds.

## Public implementation comparison

Reviewed 2026-10-12: [CM lighting](https://github.com/cmss13-devs/cmss13/blob/master/code/controllers/subsystem/lighting.dm)
walks queue indices and cuts processed prefixes, splitting work budgets among
lighting stages. [Bay lighting](https://github.com/Baystation12/Baystation12/blob/dev/code/controllers/subsystems/lighting.dm)
uses resumable indices and cuts prefixes after budget breaks.
[TG timers](https://github.com/tgstation/tgstation/blob/master/code/controllers/subsystem/timer.dm)
detach a timer before invoking its callback and check deletion before reinserting
looping work. These are design comparisons; no subsystem, timer framework or
upstream implementation is imported.

Civ13 instead detaches a prefix of at most 2000 entries and retains only unfinished
batch ownership across the existing process budget return. Overlay caps remain
1000/2000. Source passes are now also bounded at 2000, so trivial low-cost source
backlogs may take additional passes; overload measurements must include drain
latency and FIFO fairness. New dirty work remains on the live queue. Cancellation
prepends unfinished entries; scheduler replacement transfers the batch. No Life
schedule, scheduler budget, caches, engine version or client behavior is changed.
