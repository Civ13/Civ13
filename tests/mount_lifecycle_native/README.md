# Consolidated mount lifecycle native acceptance proposal

Status: source/preparation for Main review, not native acceptance. No compiler,
daemon, client, live world or save has been used. There is deliberately no new
native execution CLI or workflow admission. Existing offline lifecycle behavior
suites are not duplicated here; test_prepare.py checks only composition, selectors,
mutation identities and strict receipt rejection using synthetic receipt data.
Only that explicit preparation test file enters the offline baseline registry.
No native compile/run step or manual dispatch is added to test.yml.

## Source and entry selector

Pin the reviewed commit and tools/byond/version.json at 516.1688. Run the
prepare-only command with the exact source commit and a new private output:

```
py -3 tests/mount_lifecycle_native/prepare.py --source-commit FULL_SHA --output NEW_DIRECTORY
```

Preparation uses tests/human_subtile/run-npc.py prepare_source, its bounded
exact-Git on-disk tar, existing two normal-startup isolation seams, source hash
census and current full-source fixture initializer. The canonical pin is checked.
One asset/source tree serves five small DME entrypoints. The retained upstream
probe world entry is renamed; human_subtile.dme becomes the positive mount entry.
Maps are excluded and this last fixture declaration bounds the map to 8x8x1.
OpenPort/Topic/client rejection are inherited from the existing probe. Normal
server startup, global-controller initialization, real clients/accounts, webhooks,
AI processing loops, saves and game input are not enabled.

Production qdel, finalize_qdel, both human Destroy layers, the animal/mob/atom/
datum parent chain, destroyed-event dispatcher and human/horse constructors are
compiled from the full source. They are not replaced by Python models or fake
qdel/parent implementations. Fixture subtypes log before/after native parent
calls and inject explicitly labelled synthetic callbacks. Destroyed-event
callbacks use the actual synchronous production observer dispatcher.
That event occurs inside the parent chain, before movable Destroy's later
contents/pull cleanup and forceMove(null) return. It is not an after-all-cleanup
signal. The fixture distinguishes turf forceMove observations from that native
teardown forceMove(null); neither is replaced or omitted.

Separation selects the exact outer riding branch from human_life.dm into a native
fixture-only proc. The selector requires one anchor and the complete known release
block, preserves every source statement and rejects drift. It does not run the
unrelated remainder of human Life or claim full Life-entry integration.

## Native cases and controls

| Operation | Cases | Native observations |
| --- | --- | --- |
| Animal death | matching, foreign, retiring human, forceMove reassignment | Real death chain, native forceMove return/position, detached link before movement |
| Separation branch | matching, foreign, retiring mount, forceMove reassignment, icon reassignment | Actual no-op forceMove and update_icons parents, captured ownership and no late flag overwrite |
| Mount qdel | matching, foreign, absent, retiring human, destroyed-event reassignment/reentry | Actual qdel marker, complete Destroy chain, synchronous destroyed event, native ref disappearance |
| Rider qdel | matching, foreign, absent, retiring mount, destroyed-event reassignment/reentry | Actual qdel marker, both human layers, mount release before event, native ref disappearance |

Retirement is obtained by nesting the tested operation inside an actual counterpart
Destroy entry. The fixture never writes gc_destroyed/gcDestroyed. The reentry
calls actual qdel on the already-retiring target; subtype entry counts must stay
one. Reassignment is injected by fixture hooks, not a real MouseDrop/do_after
gesture. Headless forceMove returns and coordinates are native observations;
animation appearance, client hit testing and visual smoothness remain unproven.

Death's legacy foreign-pointer case still clears the human riding flag while
preserving its foreign mount pointer. The oracle characterizes that behavior;
it does not claim all foreign death effects are identity-safe. Likewise clearing
stop_automated_movement is flag cleanup, not a universal AI pause/resume guarantee.
Active wildlife transactions/pending-intent integration remain outside this pin.

The candidate requires 19 cases, four ordered checks per case plus three startup
checks: 79 exact positive assertions. Values and native/synthetic phase labels are
retained. Cleanup asserts native disappearance of each case's four captured mob
refs; it does not claim arbitrary queued datums or all collectors have drained.

Four generated-copy compile controls conditionally omit only the merged fix:
death owned-link clear, separation reciprocal release, mount Destroy human clear,
or rider Destroy release. The source blocks remain byte-identical inside #ifndef
wrappers for the positive variant. Each control must compile cleanly, produce no
unexpected runtime, and fail exactly its named operation.matching.state assertion
after the correct passing prefix. Compiler errors, missing receipts, timeouts or
earlier assertions are failed attempts, never successful negative controls.
The failing case still qdels its owned mobs with callbacks disarmed, without
adding post-failure assertion rows. A separate cleanup error retains the original
assertion and makes the whole attempt fail. Host-owned cleanup remains mandatory.

## Proposed execution envelope, not admission

Review the final manifest, five generated DME hashes, prepared source adaptations,
receipt oracle, engine archive/executable identities and selected platform first.
Execution must use the existing current-pin run-diagonal.py run_phase/Session
boundaries, not a new Popen bypass. Its compiler oracle requires one 516.1688
banner and exactly zero errors/warnings. Use one fresh runtime directory per
variant with only its recorded DMB/RSC and tracked config; retain artifact hashes.
Parameters must be `tested_commit=SHA;fixture_variant=VARIANT`. Use -trusted and
the existing no_port_args/closed-entry witness/log policy. Read every runtime log,
including unexpected exceptions swallowed by the observer's own catch path.
The receipt validator alone does not prove containment, exit or diagnostic absence.

The existing Windows no-sampled-sockets startup rejection remains a hold. This
proposal does not retry it, change the guard or switch execution routes to evade
it. A Linux hosted selection requires Main's explicit review of the existing
process-group/deadline/loopback application-closure scope; it does not establish
Windows containment or continuous OS network isolation. Neither -close nor the
DM port check proves socket prevention. No host firewall/security changes,
privileged namespaces, credentials, paid services or dependency installation.

Run serially: positive first, then the four controls; stop on an unexpected
failure, diagnose, preserve it and obtain review of any correction before rerun.
Cap compile at 120 seconds/variant, post-entry runtime at 30 seconds/variant,
owned cleanup at 15 seconds/variant and the complete five-variant attempt at
900 seconds. Source preparation has the existing 30-second Git archive and
2GiB/8000-file bounds, separately from native deadlines. Check memory/disk budgets
and remaining authorization before launch. The present testing window ends
2026-11-01 23:46:26 UTC; do not begin the 15-minute attempt after 23:31:26 UTC.
Elapsed time is not permission and no execution has been admitted by this file.

On success/failure/timeout, clean only owned processes through the existing
retained process-group/Job mechanism. Verify retained identity, reaping, no extra
members and final process/socket census. Preserve complete logs, partial receipts,
compiler artifacts, hash manifests and failures. Do not delete source packets,
branches, shared outputs or historical failures. No Gaia, restart or deployment.
