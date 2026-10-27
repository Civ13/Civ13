# Paid prone and crawl movement

The supported slice is conscious, unlinked client-owned human bodies with normal
32px bounds, aligned or at an adapter-owned offset. It preserves `proning()` and
`scramble()` admission, including limb/incapacitation/grace checks, `scrambling`,
facing, injury/weight-sensitive `get_prone_delay()` and the captured weakened
scramble factor. First eligible prone input uses the safe default setter; an
explicit opt-out keeps the legacy path. NPC and linked-body integration belongs
to a separate follow-up. True teleports/map transitions keep their existing paths.

An aligned crawl performs at most sixteen native collision-checked 2px pulses,
at start + i * captured duration / 16, i=1..16. Offset recovery stops each moving
axis at its next alignment and distributes its smaller pulse count through the
same paid duration. Native diagonal collision remains authoritative; crawling
does not inherit the standing movement diagonal cooldown multiplier. No walking
nutrition/water/stamina/velocity/trait costs are imported. Living/human completion
hooks execute once for a physical attempt, including a dense-object block;
an interrupted partial crawl also completes once. Native turf/Move callbacks
still occur at their physical boundaries.

This intentionally changes intermediate gameplay: physical overlap and distance
change during the old stationary wait. Newly encountered collision boundaries, posture exit, lost
authority, disabling the adapter, new restraint/links/incapacitation/limb loss,
saving, grace walls and hanging stop later pulses. The already-paid partial
position is retained, without snapping back or continuing from an external
teleport. The transaction and scrambling lock remain until the captured deadline;
the client move deadline also prevents free standing movement after posture exit.
Key release does not cancel an admitted crawl. Reverse input after the deadline
can recover an owned partial offset with normal collision checking.

Body glide and client FPS/glide use the existing compare-and-restore ownership.
Interrupted travel releases visuals within the next server tick, while retaining
the admission lock; logout, death and body handoff retain their existing release
hooks. No world FPS change, client prediction, cosmetic pixel offset or collision
bypass is introduced. This costs at most sixteen top-level Move calls per full
crawl, plus bounded per-tick cancellation checks; no performance benchmark is
claimed.

## Retained fixture and acceptance limits

`crawl.dm` executes actual proning/scramble and human/living/native Move through
an explicit headless authority adapter. It covers all eight directions, both
postures, weakened scramble, injury-sensitive prone timing, mid-interval physical
reach, dynamic blockers, cancellation, external displacement, lock retention,
once-only hooks, cost preservation, default activation, opt-out and owned-offset
recovery. `run-crawl.py` stages exact Git objects and verifies compiler/runtime
516.1688, closed port, diagnostics, bounded processes and assertion counts.
`late-start` must fail the intermediate-progress oracle; `lost-lock` must fail the
cancelled-attempt paid-interval oracle. Failed evidence is retained.

The initial dynamic-blocker fixture was invalid: it created a full-tile object
eight pixels inside the body after that turf had already been entered. Native
516.1688 trace at `86c72a7d3237b5129d6adba8b4986330694bedbc` shows insertion
distance -8, then sixteen native 2px results and the full 9ds paid interval.
Legacy Enter/Cross admission does not retroactively re-enter that overlapping
turf. The corrected collision case introduces a 24px-wide obstacle starting at
the body's leading edge (bound_x 8), requires native Cross denial, and retains
the original five-attempt/eight-pixel-stop/full-cooldown assertions. The old
overlapped insertion remains an explicit separate native semantics regression;
production collision behavior is unchanged. Traces are saved before assertions.

```
# Offline staging; no native executable resolution or launch:
<verified-python> -B tests/human_subtile/run-crawl.py --prepare-only --output <fresh-dir>
# Compile-only, using the existing Windows owned-Job envelope:
<verified-python> -B tests/human_subtile/run-crawl.py --compile-only --byond-bin <bin> --output <fresh-dir>
```

The existing opt-in hosted human-subtile lane runs the fixture and two controls.
Ordinary PR checks may compile without selecting this native lane. A successful
compile or Python source/schedule test does not prove native collision behavior,
connected-client timing, restoration or visible smoothness. No local world or
client launch is authorized by this source. The unchanged Windows runtime policy
still rejects sampled startup sockets; retain its earlier failed evidence.

## Connected-client playtest source (pending separate execution)

Use the exact reviewed source/compiled artifact and an authorized isolated map.
Record engine/head/map, actual scene duration, body/client settings before/after
and a genuine video showing tile boundaries and camera movement. Keep captures
local until sharing is authorized. Do not use a live TDM instance.

1. Compare three cardinal and three diagonal crawls with smooth movement disabled
   and enabled. Repeat deliberate prone, lying scramble and weakened scramble,
   injured/heavy bodies, keyboard input and adjacent floor clicks. Compare elapsed
   intervals and nutrition/water/stamina/velocity; the diagonal paid duration stays
   equal to cardinal. Capture first-ever prone input without a prior standing step.
2. Stop/hold/repeat input against a dense object, corner and closing door. Change a
   blocker during a crawl. Verify partial native progress and inability to retry
   before the original deadline. Check native slide/corner behavior with diagonals.
3. Stand, become stunned/restrained/linked, lose limbs or externally relocate at
   early and late pulse boundaries. Confirm no further crawl relative to the new
   state/location; reverse to recover retained offsets after restrictions clear.
   Save/load a partial owned position and confirm there is no replayed worker.
4. Record body glide and client FPS/glide restoration on interruption, posture
   exit, opt-out at alignment, logout, death/respawn and native body handoff. Change
   preferences while owned and verify compare-and-restore preserves them.
5. Inspect actual crawl/camera rendering through the first/last pulse and tile
   normalization. Headless coordinates alone cannot establish smoothness here.
