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
private-byte samples every 20ms. Engine tick-usage differences and OS CPU seconds
are distinct observations; do not convert the former into measured OS CPU time.
Windows process CPU seconds include startup,
allocation and teardown. Final private
bytes are a teardown sample, not settled retained memory. Linux uses smaps private
bytes. Memory and CPU measurements are observations, not assertions about OOM,
whole-server latency, client rendering or long-runtime stability.

`--negative-control skip` must fail the missing/duplicate callback contract.
`--negative-control retain` must fail consumed-reference release. Both mutate only
generated source and require the expected diagnostic, not any arbitrary failure.

`run_native.py --byond-bin <bin> --baseline --output <baseline.json>` compiles full
production sources with ordinary startup and maps disabled. Then run without
`--baseline`, with `--compare <baseline.json> --output <current.json>`. It compares
every overlay color and luminosity over five cycles. Defaults are a 32x32 fixture
with 200 moving lights; use `--size 128 --lights 2000` for the overload comparison.
Production corners, light check/remove/apply,
dirty flags and overlay calculations are unchanged. Dynamic enqueues, destroyed
and deleted sources, invalid-overlay retirement, cancellation and batch transfer
exercise budget boundaries. This is native lighting-state parity, not a graphical
client or production benchmark. A sandbox daemon startup failure is not a pass;
use the authorized isolated execution context and require completion plus clean
engine diagnostics. Both runners require zero compiler errors and warnings.
Native phase metrics omit fixture construction and the first forced-budget source
and overlay callback in each cycle; process CPU includes them. Native sources retain their
ordinary bounded corner/turf references; completed queue references must be zero.

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

Civ13 overlays instead detach a prefix of at most 2000 entries and retain only
unfinished batch ownership across the existing process budget return. Overlay
caps remain 1000/2000. Source batching was evaluated and rejected because native
source drain did not improve; the source process remains unchanged. New dirty
work remains on the live queue. Cancellation
prepends unfinished entries; scheduler replacement transfers the batch. No Life
schedule, scheduler budget, caches, engine version or client behavior is changed.

## Measured adoption

`measurements.json` records hashes and normal/overload observations from the
immutable baseline and candidate `b73db0020b469adff1d9a0960bd4f4aa807c46cc`.
The final overlay implementation is identical to that measured candidate.
Across five native overload cycles, mean overlay drain fell from 30.2 to 19.2
ticks, summed engine tick usage from 305.264 to 173.800 units, and mean peak usage
from 10.648% to 10.063%. Maximum heartbeat gap remained one tick. Every final
color/luminosity array matched, queues drained and native source references
remained bounded. Normal native drain was 2.2 versus 2.0 ticks, too small to claim
a meaningful normal-load gain. Trivial 20000-entry overlay bookkeeping also
improved, but those adapter timings are not native callback or server timings.

Source batching made the clean native overload source drain slower (243.6 versus
260.8 ticks), so it was removed. Candidate whole-process CPU fell from 2.047 to
1.297 seconds, but this included both changes and is not a final-patch CPU claim.
Candidate sampled peak private bytes rose from 159.383 to 160.391 MiB; there is
no native memory-saving claim. A reversed-order repeat had unrelated equipment
probes overlap the baseline and is excluded from performance conclusions.
The final correctness probe exercises overlay cancellation/transfer instead of
the rejected source batch. CI reruns native parity for that final patch.
