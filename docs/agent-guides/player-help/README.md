# Player help: scoped agent notes

Read only the entries relevant to the paths or behavior being changed.
Code paths and commands below are relative to the repository root unless
shown as Markdown links. These dated notes preserve subsystem contracts
and historical evidence; they are not a task-wide completion checklist.
Use the root [PR completion policy](../../../CODEX.md) for the finish line.

Explicit restrictions on live actions, held runners, credentials and feature
activation still apply to those actions. Missing native, graphical or
save/load evidence belongs in the report and never blocks a source fix.
Do not turn an evidence limitation into a new approval requirement.

<!-- 2026-10-20: bronze Help retrieval -->
Keep reviewed bronze production and availability evidence in one retrieval record;
separate ranking let iron-ingot excerpts displace bronze research gates. The route
uses copper/tin ore in fired blacksmith pots/jugs, then mold pouring and anvil work.
Ovens fire clay molds; kilns alloy the loaded ores. Preserve map and actual node
checks, and never infer a player's completed research from era metadata alone.

<!-- 2026-10-18: private Help conversation boundary -->
Help history belongs to an authenticated client session, never a saved mob.
`conversation_probe.dm` is included by the existing isolated Help fixture;
conversation generation and action-token negative controls check stale replies
and copied links. The role-free worker contract derives only user/assistant
turns, bounded by UTF-8 history and complete ASCII-JSON request bytes. Spool
cleanup is not encryption or guaranteed crash-time erasure. Server and worker
updates require separately coordinated restarts; offline checks do not prove them.
<!-- 2026-10-18: native help spool format -->
Native DM can interpolate world.realtime in scientific notation, and text2file
adds LF/CRLF to ready markers. The help bridge validates bounded opaque IDs and
removes exactly one native line ending at admission and completion. Run
tests/player_help/run-spool-controls.py for the three old-defect controls;
all model transports in these spool checks are injected and offline.

<!-- 2026-10-18: native Help line endings -->
BYOND 516.1681 rejects the DM string escape `\r`; use `ascii2text(13)` for
carriage-return normalization. `\n` is supported. JSON-decoded CRLF test data
must still exercise the actual native renderer, not only a Python equivalent.

<!-- 2026-11-02: wiki guide re-pins -->
Reviewed wiki guides are pinned by LF-normalized SHA-256 plus
WIKI_REVIEWED_REVISION in scripts/player_help_bridge.py; a changed page is
silently dropped from Help. After a civ13-wiki merge that edits a pinned guide,
run `python3 scripts/agent_preflight.py wiki-pins --wiki-root <wiki checkout> --write`,
review the changed pages and open a re-pin PR. Deployment also needs the
worker's wiki_root updated and a worker restart.

<!-- 2026-11-05: automated re-pins -->
`.github/workflows/wiki-repin.yml` does that refresh automatically: the wiki's
master push dispatches `wiki-updated` (civ13-wiki `.github/workflows/repin-dispatch.yml`,
needs the wiki secret CIV13_DISPATCH_TOKEN), a weekly schedule and manual
dispatch are the fallbacks. It runs `wiki-pins --write` (which now also updates
the revision and hash literals in tests/player_help/test_wiki_guides.py), the
focused tests, and opens or updates the rolling PR from branch
`automation/wiki-repin`. Without the optional WIKI_REPIN_TOKEN secret GitHub
starts no workflows on that PR, so the workflow dispatches test.yml on the
branch itself (comparison_base = master head); those check runs attach to the
PR head and satisfy the required aggregate.

<!-- 2026-11-05: field care, trails and limb states -->
`medical_knowledge()` and `region_travel_knowledge()` in scripts/player_help_bridge.py
are compact reviewed records with marker checks over medical.dm, organ_external.dm,
organ.dm, heart.dm, predefines.dm, the silver reagent and region_travel.dm; a
changed marker fails the worker at startup, so re-review the record when those
files change. The server snapshot's body_damage rows now carry the limb states a
player sees on self-examine (bleeding, artery_cut, tourniquet, broken, splinted);
either a field-care question or a reported state puts the medical record first.
`agent_preflight.py wiki-pins` also lists guide and game-mode pages that are not
pinned yet. The Factory Automation guide from civ13-wiki#138 is not pinned until
that PR merges; add it with aliases during the re-pin.
