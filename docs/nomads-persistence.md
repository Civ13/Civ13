# Durable saves on Nomads maps

All 26 declared Nomads metadata types have explicit recovery profiles, including
the base Temperate map. Admission uses exact types: a new descendant needs an
audited field/timer contract before it inherits durable save, bed-return or
save/restart support. The 25 authored files in `maps/nomads` are bound to their
actual IDs in `supervisor.NOMADS_MAPS`. Both updater paths select the configured
map, and cached/startup binaries must match it. They never substitute Europe for
another ID. This change does not select a map or update a running installation.
The reviewed conditional selected-map block is replaced only in staged copies.
Malformed blocks, unknown directives and additional map includes fail closed;
legacy single-include source trees remain supported.

| Profiles | Additional durable state and callbacks |
| --- | --- |
| Temperate, Gaia, Europe, Asia, Karafuto, New World, North America, Oceania, Pangea, UK | Shared metadata, environment, weather, research and season callbacks; Asia retains its serialized flooding completion hook |
| Desert, Divide, Jungle, Stranded | Initial wet-season callback and `real_season` |
| Mountain | Wet/dry state, serialized terrain work and its independent 30-minute cycle |
| Ice Age | Winter/summer state; owned weather/freeze/thaw phases and 45/15-minute winter/summer deadlines |
| Africa, Island | Eruption enablement, check and warning-to-eruption deadlines; Island also retains initial wet-season setup |
| Continental, Mediterranean | One-shot fish seeding; Continental also owns one-shot piranha seeding |
| Extended / Oil Rush | Oil target and recurring oil-status checks |
| Persistence Beta | Civilization names, research/faction data and delayed respawn-policy change |
| Wasteland, Wasteland II/III, Frozen Wasteland | Nuke/zombie flags, startup/poll/impact/supply deadlines, chosen nuke threshold and scalar target coordinates |

Every new profile also retains common Nomads flags, civilization names and the
respawn-delay policy. Timers retain remaining server time, not old process clocks.
Repeated load cancels prior queue rows; callbacks wait while save/load owns the
world or startup recovery is held. Restoring completed one-shot work does not run
the constructor work again.
Mutating eruption/nuke callbacks retain a save/import barrier through actual child
completion: queued explosions, delayed fallout, recursive radiation pulses, lava
spread, drying and delayed lava casualties. Each child registers before scheduling;
elapsed time and an empty queue alone do not release the barrier. Any child failure
latches it even after other children drain. Failed Mountain/Ice Age transitions and
delayed phases also latch a separate barrier when the season worker retires.
Recovery means reloading a validated prior generation with fresh metadata; clearing
the flag on a partially mutated world is not recovery. Unowned transient lava from
older or map-authored sources conservatively blocks save/import until it dries.
Current-world barriers also apply when the incoming save is legacy spatial-only.

The 132-field shared inventory and its existing 131-field `faction_renames`
migration remain unchanged. Gaia/Europe keep their existing envelope. Newly
supported durable profiles require `nomads_profile` version 1 with an exact,
typed subtype inventory. Missing fields, extra fields, future versions, foreign
callbacks, invalid calendar pairs and out-of-world targets reject before clearing
the world. Imports do not rewrite saved metadata, markers or transaction identity.
Old spatial-only saves still use the existing legacy import path; their absent
calendar/event history cannot be reconstructed or claimed as durable history.
Older binaries reject new extended envelopes; retain original generations for
rollback rather than rewriting them for compatibility.

Bed ownership remains a scalar account claim in the world save. The existing
safe-destination, unique-claim, fallback and protected-sleep rules now apply to
the audited profiles. This does not create a separate character store or change
dead-body, guest, account or respawn rules. Saved-world/profile identity and the
existing operation/restart transaction checks remain mandatory.

## Verification and limits

`tests/nomads_persistence/run.py --byond-bin <516.1688-bin>` uses production map
constructors, metadata graph/preflight/restore, calendar work and timer callbacks
in a disposable 4x4x2 world. It checks every declared profile, typed omissions and
corruption, custom-calendar mismatch, callback ownership/repeated load, event
failure barriers and rejected imports without mutation. `--negative-control
profile` and `--negative-control timer-restore` must hit their named assertions.
`--spatial` runs 26 sequential fresh-process real world-save/import roundtrips,
including nested objects, aliases/cycles, bed ownership/return/fallback and exact
generation preservation. Normal game startup and external integrations are
disabled; real metadata constructors and the GC registration dependency remain.
The current legacy migration fixture runs separately. The dedicated Nomads
workflow runs these native tests on the exact PR head; the offline CI registry
also checks subtype/catalog completeness and injected updater builds.
`--events` tests nuke-tail completion and failure, actual lava propagation/drying,
and injected errors after Mountain/Ice Age terrain mutation. It uses a yielding
blast-body adapter and accelerates lava delays by 100 while retaining production
phase bodies and ownership. The `nuke-tail`, `calendar-failure` and `lava-tail`
negative controls must fail the corresponding named ownership assertions.
The `legacy-import` control proves incoming legacy metadata cannot bypass a
current-world event barrier. Lava constructors retain their inherited flooring
argument; the runtime event owner is passed separately and excluded from saves.

The daemon uses loopback and closes/refuses its port, but may briefly listen and
attempt BYOND pager login before `World/New`. This synthetic runner does not
provide OS network isolation and must never be used for a private production save.
Each native child has a finite deadline, with a 15-minute spatial-matrix ceiling;
this is not a hard memory or descendant-containment guarantee.

Wasteland III has metadata but no authored DMM: its runtime profile can roundtrip,
but the updater refuses that ID until a reviewed source binding exists. WIP/custom
map files are not inferred from a shared ID; add an explicit reviewed binding.
Tiny fixtures do not establish authored-map capacity, cold-start recovery,
connected-client behavior, visual weather/lighting fidelity, full blast damage or
long-run memory stability. Spatial save/import occurs within each daemon. The
event fixture covers the named direct descendants, not arbitrary gameplay scripts
spawned by every possible damage hook. Existing dimension, roof/topology and host-growth admission
limits remain enforced. No live save, map, deployment or restart is part of this
source change.
