# Ping scheduler source preparation

Run `-B -m unittest discover -s tests/ping_scheduler -v` with a verified Python.
The restricted translator executes actual production fire/reset/client-helper and
shared finished control flow. List iteration/removal, clients, winset, clocks and
budgets are Python adapters. Passing is offline algorithm evidence, not native
client/DM acceptance. Unknown source instructions fail instead of being ignored.

The retained snapshot consumes every client, including nulls, inaccessible verbs,
new ckeys and ckeys waiting for the existing initial delay. Per-pass ping sum and
query count survive budget returns. The previous completed average remains public
until the final entry publishes the next value before PROCESS_TICK_CHECK.
Empty passes preserve the prior average; nonempty passes with no queried clients
publish zero. The existing day cutoff, wire command and post-winset denominator
rule remain unchanged. Additions wait for the next pass; disconnected pending
clients are consumed without a query.

Ten offline cases cover early/final budget interruption, sums/counts, delayed
clients, disconnects before/during queries, population mutations, empty passes and
the day cutoff. Controls use `historical-ping.txt`, copied byte-for-byte from
`code/processes/ping_track.dm` at `9db2b2f42a5fbbb0bdd49d50a2672da6111a7709`
(Git blob `f80707ea830352b1f733083e4b191c8612fdfe7b`), omit consumption or move finalization
after the budget check. No native runner is added or invoked.

After parent review and coordination, prepare an isolated BYOND 516.1681 fixture
using the established process-loop extraction pattern. Adapt only client queries
and clock/budget seams, then separately verify a real client's hascall/winset
dispatch if needed. Force the native check after one entry and at the final entry;
require ordered once-per-pass queries, exact averages, snapshot release and fresh
next-pass discovery through scheduler and member entry points. Exercise actual
native client disappearance, not just Python truth-value adapters. Proposed bounds
are 60 seconds compilation and 20 seconds runtime in temporary storage with
closed/refused ports, external-effect adapters and parent-reviewed containment.
No native acceptance or authorization is implied by this plan.
