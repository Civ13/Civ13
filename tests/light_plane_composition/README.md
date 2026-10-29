## Current Linux headless runner (516.1688)

The selected ordinary CI lane uses `run_current.py --byond-bin ...
--byond-archive ... --output <fresh-directory>`. It verifies the central pinned
Linux archive and all four installed members at admission, immediately before
compiler/daemon launches and after execution. Only the exact 516.1688 banner is
accepted. Child loader paths point to the verified installation; LD_PRELOAD and
LD_AUDIT are refused. This follows the existing sprite/runtime verification
contract and does not claim complete system dependency closure.

The historical `run.py`, startup runner, pixel checker, rejected source and old
receipts remain unchanged. Source preparation and the complete 13-case CI matrix
are reused verbatim, including all four area causal controls in both modes.
Compiler/daemon deadlines remain 60/20 seconds, with the same flags and runtime
diagnostic checks. Fresh per-case receipts retain source/tree/generated hashes,
archive/member identity and partial execution logs on failure; temporary compiled
worlds are cleaned. CI uploads the receipts for seven days. Existing output is
never overwritten. Offline tests mock every child; they do not establish native
acceptance. The prior 5b0c1e9 CI banner failure remains historical evidence.

This migration covers only the selected headless lighting lane. Historical
startup/exclusion native runners and the renderer receipt keep their 1681
contracts. No client pixels or full production lifecycle are accepted by this
change; V2 remains disabled and the PR remains draft.

# Disabled second-generation composition candidate

Production now defaults to the legacy compositor (`LIGHTING_COMPOSITION_V2=0`).
The known-regressing first prototype is no longer active by default. The source
under `rejected/` is frozen to the historical hashes in `render-results.json`;
`counterexamples.json` remains unchanged. Those receipts describe rejected source,
not this new implementation. No new native pixel acceptance is claimed.

The opt-in implementation separates weather on plane 3 from tile RGB on plane 4.
The latter is multiplied once after weather. Intentionally mask-free visible
cells have explicit opaque white coverage on plane 4. Coverage is rooted on its
own turf, carries no light luminosity, has no corners or light-source membership,
and cannot broaden native visibility. A missing mask on an ordinary dynamic cell
is never classified as fullbright. An actual mask wins over the fullbright policy.

Coverage refreshes after bulk startup, runtime turf creation/replacement, area
changes, mask construction/clearing and turf import. It is unsaved, rejected on
legacy import, preserved with the other runtime renderers through ClearMap, and
excluded from building-sky falling. Repeated refreshes retain one owner and detach
obsolete/duplicate appearances before deferred deletion. OpenDream keeps its old
path. Runtime direct mutations outside those lifecycle paths, unexpected area
subtypes, pooling and full-map weather lifecycle still require integration review.

## Verification and remaining gates

Offline preparation tests bind the frozen rejected evidence and new exact source.
The existing native CI runner now checks both disabled legacy and enabled separate
plane modes, explicit fullbright allocation/retirement, excluded-z policy,
mask precedence and bypass cycles. Its coverage-omission mutation must fail at
`explicit fullbright coverage`. These headless assertions cannot prove pixels.
The small fixture's deletion and turf/area adapters are declared in `probe.dm`
and `area_probe.dm`;
they do not constitute full production save/import or client HUD lifecycle proof.

Area transitions now run the verbatim production `ChangeArea` entry point and
lighting hook. The 2x1x1 fixture checks native area membership, existing occupant
notification order, dynamic/fullbright transitions, location invalidation,
same-area no-op behavior and rejection of an invalid destination. A one-shot
`get_area` adapter supplies an absent old area, since native map turfs already
have one. Overlay allocation/clear operations are counted adapters; build wait
and eligibility logic and coverage use their production implementations. Each
mode adds 64 assertions, including a yielding occupant notification that starts
newer transitions, an away-and-back case,
direct membership mutation and native turf replacement. A temporary request
identity rejects stale outer dispatch even when the destination matches again;
it is explicitly excluded from custom save export/import. The `area-owner`
control removes only identity validation and must fail at
`superseded away-and-back skips outer hook`. The `area-change`
mutation removes only the helper's hook dispatch and must fail at
`ChangeArea dispatches turf hook`, including with V2 disabled. This is headless
fixture coverage, not production corner-graph or rendered-pixel acceptance.
Same-fullbright supersession must clear an inherited dynamic overlay; its inverse
must build the missing overlay despite matching intermediate/final area policy.
Both invalidate the coefficient even when area location values match. Independent
`area-policy` and `area-policy-dynamic` controls detect these stale-state cases.
Startup waiters additionally exercise the real build procedure against a changed
fullbright destination and two waiting dynamic requests sharing one final overlay.
The current runner expects 287 enabled or eight disabled mode checks plus these
64 transition checks. Local verification of this area-change fix is offline;
its new native cases require exact-head CI results before being counted as passed.

`verify_render.py` requires NEW source-bound native PNGs for nine explicit pixel
cases: weather, intentional fullbright, both policy transitions, replacement,
save/import, bypass, restored ordinary sight, and oversized-occluder clipping.
Every pixel must match its independently established reference. The oversized
reference must preserve visible content and black only the uncovered overhang;
reference construction and native view membership need independent review.
Synthetic oracle controls detect 1, 283 and 1024 changed pixels; they do not replace
DreamSeeker captures. There is no accepted new capture packet yet. Keep this PR
draft and the production flag zero until native rendering and integration gates
are independently satisfied. No live world or user computer was touched.

## Historical rejected prototype and evidence


**BLOCKED: not a general fix and not suitable for merge/deployment.** The ordinary-lighting candidate fixes the isolated canopy defect, but final native counterexamples remove weather pixels and darken intentionally mask-free cells. Source/CI success is not renderer acceptance. See `counterexamples.json`.


An opaque object's root can remain visible while it occludes neighboring turf roots. Its oversized icon and plane shadow can draw pixels over those neighbors, but the neighbors' turf-local lighting masks are culled by native visibility. The existing lighting master is itself invisible to living sight (45 versus 25), so those uncovered pixels escape the ordinary per-tile multiplication.

The candidate keeps the tile masks, luminosity, corner graph and native visibility. Masks compose their RGB with `BLEND_OVERLAY`; one eligible `BLEND_MULTIPLY` plane master then applies that light surface. Its color matrix makes uncovered pixels opaque black. No hidden turf, mob or object is added to sight or client images. Artwork is unchanged. `get_lumcount()` continues to read the same corner data and outside coefficient; no saver or restore source changes.

The old eligible-master behavior also bypasses lighting for sight levels at least 45 (NVG/dead/observer modes). Preserve that behavior explicitly with a white multiply surface. HUD creation/refresh calls the existing `backdrop()` seam; living vision updates and ghost sight toggles refresh the same per-client master. An unchanged mode retains its matrix. This is presentation state, not saved state or authority to change sight.

## Evidence

BYOND 516.1681 native DreamSeeker captures in a separate verified official installation reproduced the defect and tested the actual candidate plane source plus extracted production mask constructor/update code. The 21x21 scene uses imposed corner values, not production light propagation. Thirty final captures form fifteen baseline/candidate pairs:

- Opaque pine, palm and totem: 1947, 730 and 617 uncovered pixels become black; no pixels rooted on visible tiles change.
- Clear pine/palm/totem and a clear 32x32 control: pixel-exact before/after.
- Opaque 32x32 control: only 112 pixels in its plane's shadow extending into an occluded tile change; its visible tile is unchanged.
- Both tested view-edge flag cases are pixel-exact.
- Sight 45 and 60 bypasses, then ordinary sight restored: pixel-exact.
- A marker behind the opaque root remains outside native view. Original mask color/alpha/luminosity, corner values, viewer sight and native view membership remain equal.

The black-scene mechanism test removes all 1947 unlit pixels. The fully covered warm scene is pixel-exact through candidate/restoration/reapplication. The simpler eligible-master-only candidate failed and was rejected because it blacked out the warm scene. No broad visibility change was used to fix it.

`render-results.json` binds the accepted capture receipt, source bytes and pair results. Genuine captures and full private native receipts remain in the local evidence bundle; they are not uploaded by CI. No production UI, save, restart or deployment occurred. No full-map propagation, visual HUD lifecycle, persistence roundtrip, timing or memory claim is made. OpenDream remains outside this verification.

## Regression commands

Run offline preparation with:

```
py -3 -B -m unittest discover -s tests/light_plane_composition -p "test_*.py" -v
```

The original introduced-suite CI step compiled the exact production plane source and exercised 276 mode/cache/isolation assertions, plus two causal mutations (ordinary mode forced on or bypass forced off). It reused `tests/lighting_startup/run.py`'s bounded subprocess seam. Those historical headless assertions did not establish rendered pixels; the separate client captures described above apply only to that rejected prototype.

## Why this prototype is blocked

`/area` draws weather on lighting plane 3, layer 10; existing masks sit above it at layer 13. Composing opaque tile colors with OVERLAY replaces lower-plane weather instead of preserving its prior multiplication. A frozen actual `rain1` frame at the production plane/layer loses 283 pixels in the candidate. Separately, `supports_lighting_overlays()` deliberately excludes non-dynamic areas (including sewers/sky). A visible mask-free tile changes by all 1024 pixels when the new plane fills its transparent hole with black. Both old-renderer restorations are pixel-exact. The weather control is one frozen area-appearance proxy, not a weather-controller integration test.

These failures expose a real ambiguity: a transparent hole can mean a culled lighting mask or intentionally fullbright content. Plane alpha alone cannot distinguish them. No additional source changes or client experiments are allocated to hide that distinction.

A bounded next design would need a light-only surface separated from weather and an explicit fullbright-coverage representation, with lifecycle/import and boundary tests. An alternative is per-client clipping of visible oversized appearances; that requires complete appearance bounds and view-change/retirement handling. Neither is a safe one-field fix. Do not bypass native sight or send hidden gameplay objects to make masks appear.
