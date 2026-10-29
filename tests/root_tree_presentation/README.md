# Per-client tree root presentation

This is an explicitly admitted, default-off #3233 composition slice. It uses
the merged authoritative LOS context and the existing V2 lighting planes.
There is no production constructor, login hook, map opt-in or global activation.
It does not replace the lighting renderer or decide interaction authority.

## Source contract

With `CIV13_GEOMETRIC_LOS_CORE`, `CIV13_ROOT_TREE_PRESENTATION` and
`LIGHTING_COMPOSITION_V2` all defined before source includes in an isolated test build:

1. Create `V = new /datum/los_context(client)` using the existing admission.
2. Register each root with `V.admit_root_tree(tree)`; check its return value.
3. Create `P = new /datum/root_tree_presenter(client, V)` and reject `P.retired`.
4. `P.refresh()` returns whether the bounded scene/policy was admitted. A false
   result keeps the viewport shutter closed. `P.invalidate()` synchronously
   closes it and blanks owned overrides before any caller-owned raw writes.
5. `P.retire()` removes only its images/screens and restores its own weather
   lease. Context retirement, logout and client deletion release ownership.
   Reconnect/load requires new context, explicit root registration and presenter.

Only exact `/obj/structure/wild/tree/live_tree` instances are admitted, at most
eight per context and two contexts. Trees retain their actual opaque trunk,
native location, original tint, layer ordering and randomized visual offsets.
Their whole 64x64 first frame receives the root tile's RGB. The committed
20-component matrix is copied, applied to the real four-channel mask texture,
and sampled at pixel (16,16); it is not a color matrix for the tree texture.
The result is uniform root-center illumination across the entire sprite.
Neighboring tile masks do not clip or recolor the canopy. Spatial variation
within the root tile is intentionally reduced to that one sample.

The same context decision used by Hover admits the root, followed by native
root-turf view membership. Hidden/stale roots receive blank image overrides;
no shared tree invisibility or opacity is changed. Images remain attached to
their original tree; visible overrides retain its mouse opacity. Native mouse
delivery and alignment still need the client acceptance described below.
Explicit lighting bypass at see_invisible >=45 and intentional fullbright turf
policy produce white; an absent/pending/foreign mask does not produce white.

The tree output uses plane 6 above the tile mask. A client-owned lease captures
the existing weather plane and replays it above trees on plane 7. Plane 5 stays
reserved for the earlier independent LOS presenter lane. HUD/chat stay above
these planes. The presenter refuses a weather plane already leased elsewhere.
Null or exactly identity native transform matrices are accepted for trees and
the game plane. All six components are compared exactly; no epsilon admits a
small translation, scale, rotation or shear. It refuses game-plane filters,
color, nonidentity transform or alpha changes: moving a tree
out of a filtered scene changes filter grouping. The ordinary game-plane drop
shadow is therefore **unsupported** in this first isolated slice.

Existing core limits remain: 21x21x1, exact human, view 7 or 15x15, eye bound to
that body, and exact plating/wall/door/human/mask contents plus the explicit tree
and fullbright admissions. No grass-map, arbitrary prop, pine/snow subtype,
cross-z, physical step offsets, transformed/filtered/animated-overlaid trees or
larger sprite admission is implied. No aiming, Interact or shared FOV behavior
changes are included.

## Invalidation and ownership

Movement/forceMove/persistence relocation, reset_view, tree update/deletion,
light-mask pending work and committed update invalidate before relevant writes.
LOS mutation tickets invalidate, and retirement tears down the presenter.
One bounded owned driver refreshes on the next tick; it stops when retired,
replaced or disconnected. It does not scan the world. Every refresh rechecks
scene admission, decisions, current appearances and current copied lighting.
No persistent cache is serialized (`should_save = FALSE`, client field tmp).

Callers that directly change eye/view/sight, opacity, appearance, area policy,
or raw `loc` outside the reviewed hooks must call `P.invalidate()` *before*
the write, and refresh after a settled mutation. There is no claim that all
production direct writers are covered. Such callers, moving offsets and
ordinary production activation remain outside this admission. No measured
CPU/memory performance acceptance is claimed for the eight-root refresh.

## Verification

Compile before focused tests, using the configured 516.1688 binary. The
compiler-only wrapper reuses `scripts/native_fixture.py` retained-handle,
one-process Job, deadline, zero-socket and memory checks. It never starts a
daemon/client and never weakens the 6 GiB host reserve.

```powershell
& $VerifiedPython tests/root_tree_presentation/compile.py --dme civ13.dme --output $FreshCompile --byond-bin $ByondBin --head $Head
& $VerifiedPython -m unittest discover -s tests/root_tree_presentation -p 'test_*.py'
```

Offline tests project actual snapshot/admission/invalidate/retire source,
exercise ownership/stale/omission controls and stage exact source/art. They do
not establish native rendering, input, runtime lifecycle or save/load acceptance.
CI registers only the three offline files; compiler/client runners are not imported.

## Consumable native pixel fixture

`prepare.py --output <fresh-directory>` only copies exact current source/art,
extracts the production mask update/bypass/fullbright procedures, and writes
source hashes, `fixture.dme` and `fixture.dmf`. It never launches anything.
Compile that DME with the same compiler-only wrapper. Keep each failed receipt.
The fixture is a separate 21x21 world using actual tree/mask art and real opaque
trunks; it has no game startup, live data, account credentials or test commands
exposed through a game transport. It accepts one guest client only. Its movable
plane explicitly matches production GAME_PLANE 1. Original #3394 native runs
failed phase-2 admission; their nine acknowledgments/identical images are not
presenter or pixel acceptance. Preserve those failures and diagnostic patches.

The existing scene/capture owner can use its reviewed retained-handle loopback
and window-bound capture controller; this folder creates no duplicate launcher.
Any existing expired run allowance remains expired. A new client run needs the
coordinator's concrete run admission and exclusive screen turn. Use the fixed
600x600 window, 480x480 map at (44,62), view 7, eye (11,8). The magenta 32x32
calibration square at WEST,SOUTH establishes the map origin independently of
window decorations. Do not move/resize the window during samples.

Before launching, call `protocol.initialize(stage, exact_head)` in the fresh
prepared/compiled directory. It validates staged source hashes, binds DMB/RSC
and creates a unique `run.binding.json`; the fixture refuses a missing binding.
Use `failure_control="runtime"` and `"admission"` in separate fresh negative
runs: phase 2 must fail, never be acknowledged or reported as a pass.

After `client-ready.txt` says READY, write the next integer to `phase.request`.
Use `PhaseGate(stage, exact_head, runtime_logs=[actual_owned_runtime_log,
actual_owned_stderr_log])` from `protocol.py` in the existing capture controller.
Poll `gate.phase(n)` before capture, treating `Pending` as a bounded wait and
`Rejected` as terminal. Logs must exist; missing logs are not clean logs.
Five ticks settle each sample. Schema-2 receipts carry the unique run, manifest,
source head, actual admitted renderer/root counts and native identity controls.

`/world/Error` marks failure sticky, removes ready/complete files and records
`fixture.failed.json`. The caller requires an explicit TRUE phase result and a
fresh settled checkpoint before writing any acknowledgment. Phase 2 executes
20 native checks: null/default/explicit identity, real translation/scale/shear/
rotation for trees, constructor rejection for game-plane changes, and refresh
rejection with a closed shutter followed by restored identity acceptance.

After each capture, `gate.record_pixels(n, normalized_map_rgb_bytes)` rescans
the native logs and rejects identical map pixels for required visual transitions
(including phase 2 -> 3). Supply actual registered map pixels excluding labels,
window decorations and calibration; a changing label is not a visual oracle.
This detects the reported identical-image false green, but does not replace
independent RGB/overlap/visibility comparisons.

After the existing owner has verified its retained process exits, call
`gate.finish(pixel_checks, cleanup_verified=actual_owned_exit_verification)`.
`pixel_checks` must contain exactly the True results named by `PIXEL_CHECKS`,
including both renderer negative controls. No captures, missing oracles, runtime
errors, changed source, incomplete native identity controls or unknown cleanup
can return pass. The gate launches/terminates no processes and reuses existing
ownership/capture infrastructure. `complete.txt` means only that the native
sequence ended; acknowledgments alone never establish pixel acceptance.

Read `phase.ready.json` by bound phase, not mtime.
Retain full uncropped original captures and the source manifest. A renderer or
admission failure prevents any later phase acknowledgment. Phase 9 deliberately rejects an unrelated hidden atom and closes the
shutter. The fixture does not write a pixel-pass verdict itself.

| Phase | Native pixel acceptance |
| --- | --- |
| 1 | Native identity-light baseline, original sprite positions and overlap order. |
| 2 | All 20 native matrix controls pass; presenter owns three visible frames. Identity light has zero shift/shape/alpha/order differences; the occluded fourth root is wholly absent. |
| 3 | First root red (1,.2,.1), second green (.1,1,.2), third dim (.12,.18,.24). Their entire sprites follow their own root; black neighbor (9,13) does not cut the red canopy. Cyan weather remains over the overlapping sprites. |
| 4 | First tree moves from (9,12) to (8,12), changes to blue root light (.2,.3,1), leaves no stale proxy at its old root. |
| 5 | Delete second tree: no stale canopy/target remains; first and third stay correct. |
| 6 | View changes from numeric 7 to equivalent 15x15: same registration, ownership and colors. |
| 7 | Explicit native lighting bypass: whole remaining sprites become identity-lit without altering visibility or weather. |
| 8 | Third root loses its mask under explicit fullbright area policy: that sprite stays identity-lit; other root regains its committed RGB; native fullbright coverage stays white. |
| 9 | Unrelated invisible atom appears: capture fails closed, viewport black, HUD calibration remains visible. No foreign atom is made visible. |

Compare visible canopy pixels against the actual native baseline and independent
per-channel RGB multiplication, allowing only the recorded native mask-sample
rounding. Check overlap ordering separately, not just a global pixel count.
Include a negative control with neighbor-mask composition restored: it must
fail the red canopy check. A second control omitting the root visibility guard
must reveal the otherwise hidden fourth tree and fail. These are fixture-only
controls, never production activation. Hover/Examine target delivery, two-client
isolation, reconnect/load rebuilding and uninstrumented direct writes remain
separate acceptance items; screenshots alone cannot establish them.
