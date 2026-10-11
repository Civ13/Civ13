# Conveyor snapshot regression and benchmark

Conveyors kept each movement tick's `loc.contents - src` list in an instance field after delayed movement completed. Switching a belt off left this snapshot referenced indefinitely, until another active tick or belt destruction. The fix keeps it local to the queued tick and skips the delayed task when that snapshot is empty. It preserves the one-tick delay, direction lookup at execution, source-location check, anchored filtering, iteration order and ten-object limit.

## Reproduce

Use BYOND 516.1681, matching `.github/workflows/test.yml`. In PowerShell:

```powershell
./tests/conveyor/run.ps1 -ByondBin '<BYOND bin>' -Revision 0d38999d5f9f987a944493f11c456537f39ac2f6
./tests/conveyor/run.ps1 -ByondBin '<BYOND bin>' -RequireReleasedSnapshot
./tests/conveyor/run-game.ps1 -ByondBin '<BYOND bin>'
```

The fixture compiles the actual production `process()` verbatim from the selected revision. Its minimal adapters supply movable objects, the belt fields and the base `process()` declaration. It checks delayed east movement, reverse movement, anchored/departed cargo, stopped and unplaced belts, and the ten-object cap. The optional snapshot assertion fails on the baseline.

Both runners use unique temporary directories and hidden task-owned console Dream Daemon processes. They stop only the process they created on failure or timeout. The full-game runner compiles a separate environment, copies public config/UI files, disables optional outbound hooks, and uses temporary storage. It exercises real conveyor and knife constructors in Nomads, checks movement/anchoring/stop and absence of the instance snapshot field, then closes the world. Its adapter is excluded from production `civ13.dme`. Probe turfs are changed only in the disposable test world.

Fixture outputs include compile/runtime logs, `metadata.json` and `memory.csv`; the full-game run prints its directory containing `probe_metadata.json`, `game_result.txt` and startup/runtime logs. Memory sampling is every 200 ms: private bytes, working set bytes and cumulative process CPU milliseconds. Phase labels distinguish the two-second pre-processing baseline, three-second stopped-belt settling period, and empty-belt workload. Peak memory is the maximum observed sample, not a guaranteed instantaneous peak. CPU and elapsed observations include the fixture workload and scheduler overhead; do not equate them with production tick performance.

## Evidence and limits

The matching 32x32x1 fixture contains 400 occupied belts with 40 anchored objects each. Baseline retains 16,000 list entries after movement; patched retains zero. A subsequent 100,000 empty-belt calls preserve the tick delay/cadence. The stress load is larger than the checked-in Pepelsibirsk map's 45 belts and two switches (118,803 mapped turfs). Ordinary Nomads has no mapped belts: this is a focused industrial/construction path improvement, not a general world-footprint or season-OOM fix.

Reference release does not establish an OS-memory reduction, collection of live cargo, or long-runtime stability. Cargo remains live on the map. Process-memory and CPU results must be compared across repeated runs; short noisy measurements are not a production performance promise. No production save, server setting, deployment or restart is involved. A bounded read-only SSH process snapshot attempt timed out.

Source review, production-proc regressions and real-game assertions establish this
fix without a graphical acceptance gate under the current human policy. Screenshots
or video are optional when they resolve a material uncertainty. Historical real
client stills are pinned to their original head; failed, late and wrong-surface
recordings are excluded. No accepted movement video or production RAM gain is
claimed. Public uploads must be verified by accessibility and hash before local
media cleanup.

## Coordinator capture turn

Optional: only the exclusively assigned capture owner may start visual mode. Run
`./tests/conveyor/run-game.ps1 -ByondBin '<516.1681 bin>' -Visual -TimeoutSeconds 600`.
The hidden server prints its unique run directory, task PID and localhost port
(default 18328). After `game_result.txt` reports PASS, connect Dream Seeker to that
address, select **Local Verification / Inspect conveyor probe**, and capture the
real sprites plus commit/map/PASS text. Record **Run conveyor capture sequence**:
forward, reverse and stop each show a two-second before state, execute the real
belt/switch processing, assert cargo position and anchoring, then show the result
for three seconds. Capture final stopped state and PASS text. This opt-in adapter
controls processing explicitly so the one-tick conveyor contract can be observed
without unrelated scheduler activity. It does not measure normal round throughput.

Visual mode stops its own daemon after the requested bound and always cleans
unique worktree DME/DMB/RSC outputs. End the task-owned client as well; verify both
exits before releasing the coordinator turn. Upload screenshots/video directly
as PR attachments and verify them before deleting task-generated local media.
Do not use the stress-fixture reference count as evidence of OS RAM savings.

Before requesting the capture turn, `-ExerciseCapture` runs that same sequence
without a client and checks each position/anchoring result. This is offline
sequence validation, not a substitute for actual screenshot/video capture.

For a short assigned capture turn, add `-AutoScene`: after a local client connects,
the opt-in world closes its lobby panel, displays the commit scene, waits eight
seconds, then runs the same real forward/reverse/stop sequence automatically.
Start recording immediately after connecting and retain at least 30 seconds.
The test belt supplies a local light so cargo is visible; this affects only the
capture adapter's disposable scene, not production lighting or movement.
