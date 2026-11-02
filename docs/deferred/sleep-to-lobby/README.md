# Deferred: sleep-to-lobby character persistence

This is a deferred, unmerged source snapshot. It is not included in the game
build, does not change current sleeping behavior, and must not be merged or
activated without a new decision and review. The `.txt` files under `sources/`
preserve source bytes by SHA-256; `source-index.json` maps the original logical
names to each deduplicated snapshot. They are archival material, not a runnable
fixture or permission to use experimental code. Earlier versions are retained
for context and may contain known defects.

The proposed idea is to return a player to the lobby after successful timed
sleep and restore the same character, inventory and state on rejoin in the same
round, including after save/load. Ownership, graph closure, recovery, duplicate
prevention, full canonical serializer compatibility and safe handoff remain
unimplemented or unproven. No body removal or lobby handoff was implemented.

The isolated synthetic attempt [41444565318](https://github.com/Civ13/Civ13/actions/runs/41444565318)
failed during compiler-diagnostic validation; writer and reader did not run,
and the missing compiler output prevents determining the exact mismatch.
Later source-only controls and a compile-only plan were prepared but not run.
No claim of native save/load, connected-client behavior or production readiness
follows from these snapshots. Existing sleeping behavior stays unchanged.

CI is intentionally not run for this deferred archive so it cannot start
native tests. This is a hold, not a passing check or merge authorization.
