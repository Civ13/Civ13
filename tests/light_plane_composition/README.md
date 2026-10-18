# Lighting plane composition

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
