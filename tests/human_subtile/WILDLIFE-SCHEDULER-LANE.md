# Paired insect scheduler lane (review draft)

This manual-only lane compiles one staged full-source fixture DME and starts two
sequential DreamDaemon processes in separate fresh runtime directories, first
legacy and then smooth. Both use the same fixture source, seed, subject-scoped
headless adapter, and stimuli. The fixture runs the real mob scheduler, not
hand-driven `Life()` calls. Each daemon observes mosquito and vampire bat in
both chase and suppression scenarios for 80 deciseconds each; the existing
per-daemon 90-second, shared 600-second, CPU, memory, PID, network, and scratch
limits remain in force. Both resource caches are independent; no fixture save
is reused. These are isolated synthetic targets, not actual player clients.

Chase keeps seek choices deterministic and follows a target that steps east at
20, 40, and 60 deciseconds. The oracle requires recorded target intent, real
`Move` traces and tick-spaced physical samples through the 80-decisecond end.
It derives settled arrival and hold time independently of bites, requires
physical travel and reacquisition after every target step, and compares the two
traces with a one-tick timing and 2-pixel travel tolerance. A bite need not
occur in the initial 20-decisecond epoch. Positive damage, infection calls,
false bite decisions and lack of duplicate or unsettled damage are checked.
Target movement is established by its recorded physical displacement; the
native movement return is retained as an observation, not treated as a proxy
for displacement. Natural target healing may occur between bites. The paired
oracle compares bite times, positive per-bite damage deltas, and final health.
Those strict parity checks can fail; no observed runtime outcome is assumed.

Suppression includes false seek and bite decisions. Since native `walk_rand`
chooses directions inside the engine, the two random trajectories are not
compared. Each trace is independently checked for ownership, decision timing,
and absence of suppressed, duplicated, or unsettled bites. Infection outcomes
are checked when calls occur. This does not establish random-walk parity.
Nested native movement callbacks are paired in stack order and only leaf
displacements contribute to travel, so diagonal steps are not counted twice.

The host independently validates the two complete receipt hashes and reruns
the paired oracle before reporting success. Failure still retains the bounded
normal evidence package and must never be reported as a pass. Predator,
passive, save/reload, inherited species, actual client, multi-tile, facing,
and full-game acceptance remain outside this lane. The present cadence candidate
has not been compiled or executed and must be reviewed at its exact commit
before launch. The earlier paired run 41179534700 failed first-bite timing and
remains independent evidence.

The candidate removes movement waits tied to Life. Bite probabilities, current
range checks and settled-only damage remain in Life; an in-flight Life cannot
damage. Reaffirming the same valid owner does not reset its due time. The
proposed lag-3 insect chase period is 3 ds at tick_lag 0.5 ds, as observed in
that prior native run; other tick rates and contact timing remain unverified.

Exclusive movement ownership intentionally suppresses competing parent-Life
wandering. The host reports total travel and each traced legacy detour with its
departure and return. Every legacy post-arrival segment must be attributed to
such a parent-Life departure and monotonic return; staged post-arrival travel
is capped at 2 px. It compares pursuit travel through first arrival and keeps
the existing one-tick arrival and bite limits. Detour holds are handled only
for the documented traced case, requiring the staged animal to hold through
the rest of that target epoch. This is not acceptance of other timing changes.

The subsequent paired run 41191623671 corrected first-bite timing but failed
final reacquisition: the legacy actor settled at 61 ds after the target moved
at 60, while the staged actor started at 62.5 and was observed settled at 64.5.
The 64 ds Life bite roll occurred during the staged transaction and produced
no damage. Other recorded target changes at 20 and 40 produced staged starts
at 20.5 and 41.5, and observed arrivals at 22.5 and 43.5, respectively.

The next, unrun candidate leaves an already-due start slot open while the
actor is settled on the target's turf, for up to the original full transit
interval. It rechecks only at world ticks. A target change in that window may
start one normally authorized transaction with the unchanged transit interval;
expiry advances the original period without moving, and delayed workers skip
elapsed slots rather than burst. A replacement clears the old slot. Blocked
moves still use the normal period, and neither Life nor attack work is queued.
For the recorded last move, a model predicts an admission at 60 instead of
62.5, but the full 1.5 ds transit and cleanup/observation quantization remain.
It is not proved that arrival or the 64 ds bite will match legacy. A target
change exactly at expiry is conservatively treated as outside the old slot.
The next fixture records owner, due, idle-window end, revision, generation,
pending intent and recovery alongside the original movement observations.
Its timing changes and any remaining phase difference require native evidence;
no comparison threshold is widened.
