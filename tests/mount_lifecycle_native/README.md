# Consolidated mount lifecycle native acceptance proposal

Status: fixture clock correction after native attempt 41368187879 at
cae81ac363a926bf8cb6f5d00f28657d30e61630. The positive fixture compiled on
516.1688 with zero errors/warnings, then passed only the three startup checks
before startup.external_ack_timeout. No lifecycle case or negative control ran.
The exact native clock value was not captured; source and float32 modeling
identify loss of the 50-decisecond interval in world.realtime + 50.
The failed receipt and logs remain preserved. Final socket rows were unavailable
on the exited retained leader, with waitid exit confirmation and an earlier
zero-owned-socket sample; final process groups/native censuses were empty.

The dedicated manual workflow defaults to preparation without native acquisition
or execution. Ordinary push/PR CI runs only the three named offline fixture,
supervisor and hosted-entry files. The corrected native fixture still requires
new exact-head preparation/artifact review and a separately admitted attempt.

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
After closing, the fixture waits at most five seconds for an external closed-port
acknowledgement. The Linux supervisor writes it only after a zero-owned-socket
sample. No case executes before this acknowledgement.
The fixture measures the same 50 deciseconds using modulo-day world.timeofday,
so a midnight rollover is handled without large epoch arithmetic. timeofday is
wallclock, not monotonic; clock changes can fail the fixture early. The unchanged
host-monotonic five-second startup, 30-second daemon and 900-second attempt
limits remain the safety bounds. Offline clock regressions project the actual
fixture declaration/predicate with synthetic float32 readings; they establish
boundary arithmetic, not corrected native behavior.

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
The concrete run_linux.py orchestrator calls the existing human_subtile/run.py
run_process with retain_leader=True, monitor and on_event. It reuses the existing
current_runtime.py archive/install verifier, human_spatial_run.py memory/output
monitor and nomads Linux identity/process/owned-socket census functions. It does
not call run-diagonal main or that lane's unrelated fixture/oracle. Its compiler
oracle requires one 516.1688
banner and exactly zero errors/warnings. Use one fresh runtime directory per
variant with only its recorded DMB/RSC and tracked config; retain artifact hashes.
Parameters are `tested_commit=SHA;fixture_variant=VARIANT`. It uses fixed loopback
port 59474, -trusted, -close, -nowebclient and the closed-entry witness/log policy.
Read every runtime log,
including unexpected exceptions swallowed by the observer's own catch path.
The receipt validator alone does not prove containment, exit or diagnostic absence.

The existing Windows no-sampled-sockets startup rejection remains a hold. This
proposal does not retry it, change the guard or switch execution routes to evade
it. A Linux hosted selection requires Main's explicit review of the existing
process-group/deadline/loopback application-closure scope; it does not establish
Windows containment or continuous OS network isolation. Neither -close nor the
DM port check proves socket prevention. No host firewall/security changes,
privileged namespaces, credentials or paid services. Execute mode uses only the
existing pinned Linux CI acquisition and its existing i386 package set; prepare
mode does not acquire a toolchain or install packages.

The dedicated hosted workflow is workflow_dispatch only, with contents: read,
pinned checkout/artifact actions and persisted checkout credentials disabled.
Its default mode=prepare requires the full source_sha to equal both the branch
dispatch SHA and workflow implementation SHA. It runs offline contracts and stages
the exact committed source, then uploads the manifest, five entrypoints and
fixture source for review. No compiler or daemon is acquired or launched.

After independent source and prepared-artifact review, a separately authorized
manual mode=execute dispatch must use that same immutable head, its reviewed
Linux manifest_sha256, execution_approved=true and the renewed specific
authorized_until deadline. These are identity and intent fields, not permission.
A moved branch or different workflow implementation is rejected before checkout.
Execution restages source and must reproduce the reviewed canonical manifest
before acquiring the pinned toolchain. The toolchain and all staging/runtime
outputs use private RUNNER_TEMP directories; acquisition does not dirty source.

The guarded native step invokes:

```
/usr/bin/python3 -B tests/mount_lifecycle_native/run_linux.py --prepared "$PREPARED" --output "$OUTPUT" --byond-bin "$TOOLCHAIN/byond/bin" --archive "$TOOLCHAIN/pinned.zip" --expected-head "$SOURCE_SHA" --manifest-sha256 "$MANIFEST_SHA" --authorized-until "$AUTHORIZED_UNTIL"
```

The runner rechecks the dedicated workflow path, event, implementation/source
SHA, exact clean checkout, private paths and full remaining 900-second window
after tool acquisition. The job cap is 35 minutes, allowing bounded checkout/preparation/acquisition
and final artifact upload without shortening the native cleanup allowance; the native step cap is 16
minutes, while the actual attempt remains 900 seconds. Artifact retention is
always selected, including partial compiler/supervision/runtime evidence on
failure. The corrected clock has not been dispatched for native execution;
the historical failed attempt above remains unaccepted.

It refuses other active native engines, foreign/extra session members, changed
birth identities, UDP/connected/external sockets, occupied port and all sockets
after closure. Final socket observation occurs while the leader is retained;
after reap it requires empty owned group and native-engine census, without
querying a reused PID for sockets. Sampling is detection, not an egress sandbox
or a guarantee that a short-lived escaped descendant could never exist.

Run serially: positive first, then the four controls; stop on an unexpected
failure, diagnose, preserve it and obtain review of any correction before rerun.
Cap compile at 120 seconds/variant, the entire daemon phase at 30 seconds/variant,
reserve 15 seconds for each phase's owned cleanup and cap the complete attempt at
900 seconds. Source preparation has the existing 30-second Git archive and
2GiB/8000-file bounds, separately from native deadlines. Check memory/disk budgets
and remaining authorization before launch. The former testing window ended
2026-11-01 23:46:26 UTC and its 23:31:26 admission cutoff passed without a
native attempt. Any later attempt requires a valid specifically approved testing
window and Main source/admission review before execution.
Elapsed time is not permission and no execution has been admitted by this file.

On success/failure/timeout, clean only owned processes through the existing
retained process-group/Job mechanism. Verify retained identity, reaping, no extra
members and final process/socket census. Preserve complete logs, partial receipts,
compiler artifacts, hash manifests and failures. Do not delete source packets,
branches, shared outputs or historical failures. No Gaia, restart or deployment.
