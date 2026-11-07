# Persistence status reports

Run `python3 -m unittest discover -s tests/persistence_status -v` or
`python3 scripts/ci_baseline.py unit --suite persistence_status --output /tmp/persistence-status-tests.json`.

Persistence reports take a fresh census of registered human bodies on each
request. Living includes heavily injured/unconscious humans as a subset; dead
bodies count only while present. The report groups by original job faction,
retains the normal admin-area/decorative-corpse exclusions, and skips incomplete
restores, unlocated and jobless humans. It does not depend on client login,
Life/death callbacks, round UIDs, or the session's historic casualty lists.

A failed or active load does not publish a partial census. Both public and
private reports explain that these are current-world counts, not cumulative
deaths or a lifetime mortality rate. A deleted/gibbed/removed body cannot be
reconstructed from a save. Non-persistent reports retain their existing
historical accounting and mortality calculation.

Largest Faction counts non-DEAD humans in registered custom factions, matching
the Faction List. Unconscious and clientless members count; all-dead factions
do not win; ties retain the existing first-registered behavior. This tally is
separate from the job-faction census and keeps its existing map eligibility.

The offline fixture executes the complete production census/formatting helpers,
the largest-faction tally block and the load gate, through the repository's
source adapter. Engine registration, areas, type queries, job datums, DM lists
and string interpolation have explicit test adapters. It checks fresh/repeated
load snapshots, stale session UIDs, death/revival/removal, health states, all 29
report routes, empty/tied/unregistered custom factions, preserved history, and
controls restoring corpse-majority selection and omitting the dead branch.

The registered offline suite is selected for these production paths without
narrowing their existing conservative selection. Ordinary PR CI selects the
full game build and offline baseline. No native fixture or workflow is added;
this is source-control-flow evidence, not engine compilation, actual disk
save/load, connected-client output, or live-world acceptance.
