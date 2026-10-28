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
