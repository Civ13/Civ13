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
The small fixture's deletion and turf/area adapters are declared in `probe.dm`;
they do not constitute full production save/import or client HUD lifecycle proof.

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

The automatic introduced-suite CI step compiles the exact production plane source and exercises 276 mode/cache/isolation assertions, plus two causal mutations (ordinary mode forced on or bypass forced off). It reuses `tests/lighting_startup/run.py`'s bounded subprocess seam. The native world closes/refuses its listener and rejects clients. These headless assertions do not establish rendered pixels; the separate client captures do.

## Why this prototype is blocked

`/area` draws weather on lighting plane 3, layer 10; existing masks sit above it at layer 13. Composing opaque tile colors with OVERLAY replaces lower-plane weather instead of preserving its prior multiplication. A frozen actual `rain1` frame at the production plane/layer loses 283 pixels in the candidate. Separately, `supports_lighting_overlays()` deliberately excludes non-dynamic areas (including sewers/sky). A visible mask-free tile changes by all 1024 pixels when the new plane fills its transparent hole with black. Both old-renderer restorations are pixel-exact. The weather control is one frozen area-appearance proxy, not a weather-controller integration test.

These failures expose a real ambiguity: a transparent hole can mean a culled lighting mask or intentionally fullbright content. Plane alpha alone cannot distinguish them. No additional source changes or client experiments are allocated to hide that distinction.

A bounded next design would need a light-only surface separated from weather and an explicit fullbright-coverage representation, with lifecycle/import and boundary tests. An alternative is per-client clipping of visible oversized appearances; that requires complete appearance bounds and view-change/retirement handling. Neither is a safe one-field fix. Do not bypass native sight or send hidden gameplay objects to make masks appear.
