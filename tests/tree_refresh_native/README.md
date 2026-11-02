# Current-source native tree callback and refresh measurement harness

This separate harness implements the plan in docs/tree-refresh-measurement.md.
It is prepared for independent review. No compiler, daemon, client, workflow
execution, pixel acceptance or performance measurement has been run for it.
The frozen tests/root_tree_presentation native fixture remains unchanged.

The manual workflow is .github/workflows/tree-refresh-native.yml. It has no
push, PR, schedule or automatic native consumer. Ordinary CI runs only the
registered offline preparation/protocol tests. Default workflow mode is prepare:
download the exact pinned Windows installer as data, verify its size/SHA256,
extract it with hosted 7-Zip without installation, and stage exact committed
source. This is not permission to dispatch either mode before Main review.

## Actual engine boundaries

The new DME contains the complete current game sources and assets, excluding
maps. It reuses the existing two startup-isolation adaptations and only the
previous initialization helper body. It replaces fixture client creation,
Topic and disconnect boundaries, provides a tiny fixture HUD using actual
production plane-master types, and suppresses world Export/Import/Reboot/Topic.
It never loads player preferences, accounts, production data, admin control or
saves. World dimensions are64x64x1, view15x15, fps20, pan0, guest-only loopback.
The fixture resets rand_seed to13013 before actors/trees and records actual map,view,fps,tick_lag,icon_size and both engine builds, together with host OS/CPU and sampled process resources. Inputs seed the four photometric corners; update_overlay, the mask snapshot,
RGB/icon operations, LOS capture and geometric decisions are real production DM.
This does not exercise natural lamp propagation or the lighting process queue.

Instrumentation is added only to the staged copies, with before/after hashes.
The real human SelfMove uses the actual production client/body authority check
with the fixture input controller setting moving/canmove, actual smooth pulses,
generic Move, the engine's native parent Move, actual observation Entered,
pre/post invalidation, reconciliation, geometry capture, root scene admission,
root and fallback presenters, native images/icons and committed lighting.
Native parent-return rows retain result,x/y,step offsets,time,phase count and
the first pulse's real image state. Offset callbacks are observed, not assumed
identical to the modeled offset adapter. Entered and post-move witnesses retain
native refs, client image membership, icon presence, published frame identity,
plane/override/mouse flags and actual affected-context refs. Up to64 actual witnessed image/icon objects are retained only through the event to prevent native ref recycling from masquerading as stable identity; they are never re-added to client.images. This bounded observational retention affects GC timing and is disclosed in cost/RSS interpretation.

These are server-side engine and render-state observations, not client pixels,
packet delivery, native mouse dispatch or flicker acceptance. Genuine video on
a fresh isolated real client is still needed to judge continuous canopies,
root-source lighting, shadows/weather overlap, movement timing and popup/hover.
No current Gaia or existing user session may be touched. The runner refuses a
self-hosted/desktop environment; fresh GitHub-hosted Windows manual attempt1 is
required. Fresh private profiles are used for daemon and DreamSeeker processes;
non-Guest clients are rejected. Launch/guest/DirectX availability on that runner
is unverified and must fail with retained evidence rather than using another
user's client, authenticated session or a permissive fallback.

## Fixed workload and resource contract

Eight cases:1/2 actual connected clients x64/256 discovered roots per disjoint
neighborhood x admitted root scene/intentional foreground-induced fallback.
One client is launched initially; the second is launched only after all four
one-viewer cases. At most512 roots exist. A real low-alpha foreground world
object deliberately induces the known fallback reason. Budget fallback fails
the intended root case; no renderer audit limit is raised.

Each case runs5 warm and20 recorded events for each of four classes: audit,
smooth viewer tile move, opaque object Move, and queued committed-light batch
of at most64 roots. Exactly800 total events/640 recorded. The two-viewer opaque
control marks the remote viewer dirty but requires zero synchronous captures;
a real production visibility process pass is recorded separately. Its actual
fixture priority allowance and last/highest/last20 scheduler durations are saved.
This fixture contains only the visibility process, so its allowance is not the
full production scheduler mix. Instrumentation adds bounded overhead; metrics
must not be presented as uninstrumented production timing or a speedup.

Compiler:120seconds plus at most30seconds cleanup. Native world/client phase:
180seconds including connection waits, plus at most30seconds cleanup. Total
runner ceiling360seconds before cleanup reserve; authorization reserves390seconds.
One daemon and at most two clients share a retained-handle Windows Job with
three active processes,1920MiB aggregate private-memory hard ceiling and sampled
aggregate RSS ceiling,128MiB watcher ceiling and6GiB free-memory floor. That free
floor may block a standard hosted VM; do not relax it without review. Process
membership and cumulative creation counts reject unexpected children. Generated
logs/state cap16MiB; native event input read cap12MiB;64 spans/16 callback phases
per event;32 native returns/affected-context samples. At most three independently
reviewed runs, one per invocation, no automatic retries. Main must enforce the
cross-dispatch run ledger; run_index alone is not a global execution counter.
The current user window ends2026-11-02T13:23:00Z and is enforced by request.json.

Only this fixture's IPv4 loopback port59479 is admitted by sampled socket
inventory. No firewall, credential or global security setting changes occur.
This sampled oracle does not prove continuous absence of transient connections.
No external hooks are enabled. Owned Job kill-on-close and retained exit waits
provide cleanup, and failures retain original cause, native rows, compiler logs,
resource/socket observations and secondary cleanup/retention errors. No cleanup
removes source/artifacts or unrelated processes.

## Review and later execution

1. Review the source/runner/workflow, including native launch and cleanup.
2. If Main authorizes preparation, dispatch manual prepare on one full source
   SHA. Inspect the exact staged instrumented source and installer/bin manifest;
   retain the emitted manifest SHA256. No engine runs in prepare mode.
3. Only after independent acceptance, dispatch execute at the same immutable
   source/workflow SHA with that exact manifest hash, an approved run_index and
   a deadline within the current window. Regenerated manifest must match. A
   source/toolchain/input mismatch, missing ceiling, expiry or other failure
   stops; no alternate route or silent retry.
4. Preserve all failures. Native compilation and first execution remain pending.
   A source-only green PR cannot upgrade them to native acceptance.

Preparation CLI (source must be committed and clean):

    py -3 -B tests/tree_refresh_native/prepare.py --source-commit FULL_SHA --output NEW_PRIVATE_PATH

Offline contracts:

    py -3 -B tests/tree_refresh_native/test_harness.py -v

The receipt oracle requires complete800-event case identities, actual native
fractional parent returns, Entered withdrawal, root identity retention/fallback
identity replacement, unrelated-viewer isolation, hidden hover/examine denials,
owned denial masks, mutation-induced capture failure, and matching pending-light
identity retention. It measures actual TICK_USAGE endpoints and source
TICK_DELTA_TO_MS conversion. Cross-tick/negative deltas are unresolved, never
zero. Same-tick whole-tick spans stop and retain the failed event. Summaries use
only20 recorded events per case/class; per-client reconcile p95 is compared to
its actual recorded allowance. Unresolved timers or over-budget samples prevent
cost acceptance. Smooth multi-tick whole-event timers will remain unresolved;
per-capture/reconcile values remain individually useful, with that limitation.
No result proves long-running stability, pixel delivery or acceptable dense live
server scaling.

An execution with valid native dispatch but unresolved/over-budget cost is marked measurement_incomplete and exits nonzero after owned cleanup. It is not reported as an overall native measurement pass. Raw per-capture/reconcile timings remain available for review. The derived retained launcher is the committed current-pin implementation with only its binary-allowlist import replaced; its suspended assignment, stripped private environment and handle/Job creation remain intact and are separately reviewable.

Synchronous and scheduled per-client spans/counters are retained separately, including the remote viewer capture count and unfinished process snapshot. Identity details are bounded to the first two roots per client; admission/owned-image and allocation counters cover the full discovered scene. This controls evidence size and is not an assertion about every canopy pixel.
