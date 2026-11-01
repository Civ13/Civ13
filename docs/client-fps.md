# Client FPS target and prospective acceptance

The account's Global preferences select a client animation target: 30, 60, 100,
120, 144, 165 or 240 FPS. New and legacy accounts default to 100 when no valid
saved choice exists. Reconnect and preference reload apply the saved target.
Lower choices remain available for slower computers. Smooth movement owns only
body/camera glide and never raises or restores client FPS. Choosing a client
target at or below server FPS can reduce legacy pixel interpolation smoothness.

This changes no simulation tick rate, movement cost, AI cadence or visibility
policy. A configured target is a limit/request, not measured rendering capacity.
There is no automatic FPS promise or hardware-dependent adaptation.

## Checks and limits

`tests/human_subtile/test_client_fps.py` checks the source-derived scalar policy,
numeric persistence wiring, initial/cached login application, post-prompt owner
validation and the absence of movement FPS writes. Existing diagonal contracts
retain glide ownership checks. These are offline Python projections/contracts,
not actual DM execution, connected-client preference round trips or frame data.
The ordinary CI human-subtile source-test step discovers this test.

Compile the full source with the canonical manifest's 516.1688 compiler before
publication. Native preference save/reload, body transitions and rendered movement
need separate bounded acceptance. No native runtime/profiling is authorized by
this document, and no production preference or Gaia setting is changed here.

## Proposed frame-time experiment - not executed

Freeze baseline/candidate commits and artifact hashes. Use the same physical
machine, GPU, monitor/refresh/sync state, Windows build, DreamSeeker 516.1688,
map-control pixel dimensions, map/view, preferences and resource-cache state.
Do not alter drivers, security settings or production. Use a local isolated
server with a fixed scene/population and record actual simulation tick rate,
load and network conditions. A monitor below 100 Hz cannot establish 100 distinct
visible updates per second; report client render cadence separately.

Compare baseline at its actual target, baseline explicitly at 100 in the approved
diagnostic fixture, and candidate at 100. The equal-target comparison isolates
capacity from the policy change. Verify 30/60 user choices independently across
move/stop, smooth opt-out, death, body handoff, reconnect and preference reload.

For each 100-target case warm resources for 30 seconds, then record three
60-second traces, alternating baseline/candidate order. Exclude only the stated
warm-up; retain all stalls and report individual runs plus pooled distributions.
Scenarios: stationary and fixed-path movement on open ground; stationary and
moving in a fixed dense forest; those forest cases with animated weather; fixed
nearby animal movement and a fixed nearby-player workload; normal 15x15 view,
a fixed larger view and a fixed scope pan. Keep time of day/light sources and
spawned entities identical. Record compositor active/fallback state in each case.

Measure actual client frame/present intervals using a validated capture method
that can observe DreamSeeker's renderer. A game/server counter, polling clock,
screen recording FPS or configured `client.fps` alone is insufficient. Establish
the measurement method's own overhead and confirm it is observing the correct
process/window before any performance conclusion.

Report median, p95, p99 and maximum frame time (milliseconds), achieved frames
per elapsed second, percentage above 10/12.5/20/50 ms, longest stall and each
run's 1-second-window FPS distribution. A proposed practical 100-target gate is
at least 99 frames/second in every measured 1-second window, p95 <= 10.5 ms,
p99 <= 12.5 ms and no frame > 50 ms, in every declared supported scenario/run.
This allows small scheduling jitter; it is not a strict every-frame 10 ms claim.
Agree the supported hardware/view/workload and gate before testing. Report
failures per scenario rather than hiding them in a whole-run average.

Record server tick drift/usage and visibility/lighting/movement proc costs,
client CPU/GPU utilization if supported, RTT and appearance/resource traffic on
separate timelines. Healthy client cadence with late entity moves points toward
simulation/update cadence or transport. Falling render cadence with healthy
server timing points toward client rendering/composition. Correlation alone
does not establish causation; approve isolated component controls before using
them, and preserve LOS correctness in all diagnostic variants.

Required decisions before execution: bounded isolated runtime/session authority,
specific test machine and supported view/load, validated frame-time capture
method, exact source/artifact pair, duration/resource/output limits and approved
storage destination. No runtime measurement has been performed by this patch.
