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
Those strict parity checks can fail; no observed runtime outcome is assumed.

Suppression includes false seek and bite decisions. Since native `walk_rand`
chooses directions inside the engine, the two random trajectories are not
compared. Each trace is independently checked for ownership, decision timing,
and absence of suppressed, duplicated, or unsettled bites. Infection outcomes
are checked when calls occur. This does not establish random-walk parity.

The host independently validates the two complete receipt hashes and reruns
the paired oracle before reporting success. Failure still retains the bounded
normal evidence package and must never be reported as a pass. Predator,
passive, save/reload, inherited species, actual client, multi-tile, facing,
and full-game acceptance remain outside this lane. This draft has not been
compiled or executed and must be reviewed at its exact commit before launch.
