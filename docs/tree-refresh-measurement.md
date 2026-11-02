# Bounded tree identity and refresh-cost follow-up

This is a source-only acceptance plan for the current renderer. No native run,
live client action, Gaia change or optimization is authorized or performed by
this document. The offline callback trace is characterization, not proof that
movement flicker is fixed.

## Source trace and its limits

Run the registered LOS suite, or isolate the new test:

~~~powershell
& 'C:\Users\valza\AppData\Local\Programs\Python\Python313\python.exe' -B -m unittest discover -s tests/los_context -p test_entered_trace.py -v
~~~

For a source-hashed JSON witness with symbolic image/frame identities, invoke
the same file directly with --write-trace and a private output path. Its report
explicitly marks native execution, pixels and performance as unverified.

The trace executes the complete selected production /atom/movable/Move body,
the observation /atom/Entered body (including old-location and actor
invalidations and the moved event), movement invalidation, the post-move
helper, and the existing LOS presenter procedures. It reuses the LOS
storage/geometry fixture and root publication procedures.

Native Move and inherited Entered dispatch, the ownership token, fresh geometry
capture/decisions, client reconciliation glue, root scene admission and texture
baking remain explicit adapters. Root mode executes the actual invalidation,
withdrawal, frame-publication guard and frame assignment, not the complete root
scene refresh. The trace does not execute collision, lighting propagation,
other inherited Entered implementations, network delivery or native pixels.

The current-code oracle records these distinct outcomes:

| Event | Fallback tree copy | Root-owned image |
| --- | --- | --- |
| Before an admitted tile move | Allowed copy exists | Image and frame published |
| After observation Entered | Allowed copy removed | Same image, frame cleared |
| After successful fresh publication | New allowed-copy identity | Same image, frame republished |
| Denial or unavailable capture | No allowed copy | Frame remains withdrawn |
| Failed move or offset-only pulse | Existing identity retained | Existing frame retained |

A second viewer checks ownership isolation. The smooth-pulse fixture executes
the source movement branch, including distance bookkeeping. Omission controls
distinguish skipping Entered revocation from skipping post-move rebuild.
Queued matching committed light keeps its frame before movement but never
overrides a later visibility rejection. Future changes may intentionally alter
the characterization oracle; retain the conservative denial controls and
provide new evidence rather than treating this oracle as a flicker certificate.

## Proposed isolated native measurement

Use the existing pinned-toolchain provenance, per-client witness and owned
cleanup contracts as a template for a separately authorized and reviewed
isolated fixture extension. This plan does not reactivate an archived native
lane or change frozen fixtures. The historical eight-root slice supplies no
dense-scene result; source projection fixtures remain separate from native
measurement.

Keep one deterministic 64x64x1 empty test world, view 15x15, zero camera pan,
fixed tree families/states and seed, and no external hooks, saves, seasons or
world imports. Record the exact source/dirty patch, toolchain, OS/CPU, tick_lag,
actual view/radii, map dimensions and initial memory.

The first pass contains eight cases, not an open-ended stress ramp:

| Variable | Values |
| --- | --- |
| Connected fixture viewers | 1, 2 |
| Discovered roots per viewer neighborhood | 64, 256 |
| Presentation | Admitted root scene, intentional native fallback |

Record discovered/admitted/denied counts and the actual scene_active and
fallback_reason. Unexpected budget fallback invalidates the intended root case;
do not raise the 2,048-image/4,096-atom/appearance budgets to force admission.

For each case, take five warm-up events and twenty recorded events in each of
four classes: unchanged audit, one viewer tile transition, one opaque mover,
and one queued-light batch touching at most 64 roots. In the two-viewer
opaque-mover cases, put the second dirty viewer outside the affected
neighborhood; distinguish synchronous event captures from its ordinary
scheduled pass. This control is inapplicable to one-viewer cases. Use disjoint
neighborhoods with at most 512 total roots. Cap each run at 180 seconds,
800 total events and
2 GiB process RSS or the existing authorized ceiling, whichever is lower.
Allow at most three independent runs with identical inputs. Missing ceilings
or unavailable source/pin/cleanup controls mean no run; failures/timeouts are
retained, not extended or silently retried.

## Measurements and decision criteria

Instrument only the approved isolated fixture, leaving production defaults and
live controls unchanged. Per event/client, retain:

- Capture/reconcile counts and actual old/new affected-context identities.
- Discovered roots/atoms, tree admissions/denials and light-notification
  presenter/root-key visits.
- Image allocation/add/remove counts, root frame assignments, cache reuse,
  RGB sampling and icon baking. These are update proxies, not packet-byte or
  FPS measurements.
- Native tick usage at start/end of capture, presenter refresh, whole client
  reconcile and full callback event; record world.time and tick_lag at both
  endpoints, plus the actual process allowance.
- Existing scheduler last/average/highest run times and external process RSS,
  kept separate from single-client callback samples.

Use the repository's TICK_USAGE and TICK_DELTA_TO_MS definitions in
code/__defines/_tick.dm and math_physics.dm. Only subtract usage when both
samples belong to the same tick and the delta is nonnegative. A yield, tick
change or unresolved timer sample is labelled unresolved, never clamped to zero.
Do not benchmark the Python adapters or infer native cost from their duration.

Retain raw rows before reporting median, p95 and maximum for each case/event.
Twenty samples give a coarse p95, not a long-runtime guarantee. Stop and flag
a case if a single callback consumes a whole tick, the declared wall/RSS cap is
crossed, or conservative visibility/ownership controls fail. Flag any p95
single-client refresh above its recorded visibility-process allowance: the
current PROCESS_TICK_CHECK runs between clients and cannot bound one capture.
Unresolved timing prevents cost acceptance, rather than supplying a passing
number. A future comparison must use identical scenes, inputs, counters and
hardware; this plan alone establishes no speedup or acceptable scaling.

Correctness is independent of cost: once new geometry is invalidated by Entered
(or an earlier opaque pre-write hook), denied trees stay withdrawn at subsequent
publication/failure checkpoints. The pre-move allowed frame is a legitimate old
state, not proof about native interleaving before Entered. Invalid captures fail
closed, unrelated dirty clients
receive no synchronous opaque-mover refresh, and committed pending light alone
does not cause an image/frame withdrawal. Verify native hover/examine and hidden
terrain/entity controls in the approved isolated scene. Actual flicker acceptance
still needs genuine motion evidence linked to the tested native build.


## Prepared native harness

The separate [current-source native harness](../tests/tree_refresh_native/README.md) implements executable isolated preparation, real-client callback/state witnesses and fixed resource/failure cleanup contracts. Its workflow is manual-only and defaults to preparation. Native compilation/execution, pixel acceptance and dense-scene measurements remain unrun; independent review is required before execution. The frozen historical tree fixture remains unchanged.
