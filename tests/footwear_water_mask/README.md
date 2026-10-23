# Footwear water mask regression

The worn footwear path is `update_inv_shoes` in
`code/game/mob/living/carbon/human/update_icons.dm`. It constructs a boot image
at `human.layer + 0.01`, using `icon_override` or `body_build.shoes_icon`, then
adds the species blood mask's `shoeblood` image with `shoes.blood_color`.
Neither image specifies a separate plane, so both inherit the wearer's plane.
The item/inventory `blood_overlay` is a different appearance; it is not copied
into the worn boot. Bare-foot blood uses `shoeblood` directly in the same slot.

Mud movement in `mob_movement.dm` sets `blood_color = "#70543E"` and initializes
`blood_DNA`; blood decal crossing sets the same fields with its blood color.
Both therefore reach the same worn stain. `dirtyness` drives clothing examine
text, not a separate worn dirt sprite. The supplied examine text alone does not
identify which stain pixels are visible. Library resolved the two supplied PNGs
(`libfile_5e78891fc0348191895c22535dca8fd4`, 5541 bytes, and
`libfile_e064364b0f9c8191902d5f7d3f6a5cf0`, 2472 bytes), but the supported helper
failed both byte transfers, including the permitted retry. No bytes or pixels
were inspected and no visual reproduction is claimed.

`handle_drowning` sets drowning/wading state for uncovered beach water,
flooded trenches and flooded sub decks, with the existing ice/cover/boat rules.
It calls `update_fire` from the living-human Life path. The mask selection is
unchanged: ordinary wading uses `seashallow_over2`, drowning uses
`seashallow_over3`, and sub-deck depths >0, >=30 and >=100 use over1/2/3.
Zero depth returns no mask. This patch retains the existing environmental
refresh cadence and eligibility rules.

Before the fix, `update_fire` filtered the human and each top-level cached
image. A filter on the boot alone does not clip its nested stain. BYOND's
[appearance flag](https://www.byond.com/docs/ref/#/atom/var/appearance_flags)
and [filter](https://www.byond.com/docs/ref/#/atom/var/filters) contracts specify
that KEEP_TOGETHER applies filters after composing children. This patch groups
only the footwear image while masked, then removes grouping on dry refresh.
It does not group the whole mob or change planes, visibility, lighting, layers,
direction, transforms, durable stains, cleaning or footprint accounting.

`update_inv_shoes` also applies the current mask before publishing a replacement
image, including when its `update_icons` flag is false. `update_fire` refreshes
that grouping for depth/entry/exit updates. `update_icons` still publishes the
cached images and applies the existing standing/prone/lying transform. Suit
hiding, clean equipment and bare-foot branches retain their original behavior.
Other nested clothing overlays may have the same general filtering limitation;
this footwear fix deliberately does not change those compositions.

## Checks

Run offline with a verified Python executable (no BYOND, network or game):

```powershell
& '<verified-python>' -B -m unittest discover -s tests/footwear_water_mask -v
```

These source contracts compare the unchanged shoe construction and mask
selection against deployed commit `77c14940584bedfa6241ecf1e0642a53ca6df0c7`.
The baseline must already exist in Git; tests never fetch it. They reject the
historical ungrouped path and five generated-source omissions, check both
refresh boundaries and ensure the helpers do not write stain data or geometry.
This is source evidence, not DM execution or rendered-pixel verification.

Prepare an independent, fresh directory and compile its tiny fixture:

```powershell
& '<verified-python>' -B tests/footwear_water_mask/prepare.py --output '<fresh-absolute-directory>'
& '<BYOND-516.1681-bin>\dm.exe' -max_errors 0 '<fresh-absolute-directory>\probe.dme'
```

The packet copies the exact production procs and real DMI resources, recording
hashes, checkout HEAD and dirty diff. Its `probe.dm` uses adapted inert types
in a 3x3x1 world, with client rejection and a refused OpenPort override. Preparation
does not start a compiler or runtime; compiling does not run the assertions.
There is no automatic DreamDaemon launcher. A separately approved native run
must use `-trusted`, offline temporary storage and an external zero-listener
census; it must inspect runtime diagnostics and `result.json` (no failures).
Headless assertions cover composition/refresh state, blood/brown mud, all four
directions, standing/lying/prone, repeated depth boundaries, deferred shoe
refresh, overrides, clean replacement, suit hiding and bare feet. The adapted
fixture does not exercise production equipment dispatch, persistence saves,
environment eligibility or client rendering.

## Native visual acceptance still required

Use an authorized isolated game at the reviewed patch commit, with real client
captures and map/coordinates recorded. Do not use the live installation or
another branch's captures. Use `/obj/item/clothing/shoes/leatherboots`
(`sailorboots2`), clean/blood/mud variants and a tinted/override variant:

1. On dry land, compare original boot and stain pixels in all four directions.
2. Enter/leave shallow water and a flooded trench; submerged boot and stain
   pixels must disappear together, with the stain returning on land unchanged.
3. On a sub deck, change depth in place through 0, 1, 29, 30, 99, 100 and back
   down; compare boot/stain at every mask boundary. Include drowning and a
   lifejacket, covered water, ice and existing boat exceptions.
4. Turn, stand, lie and go prone; capture video for the transitions. Equip,
   remove and replace footwear while submerged, including blood acquisition,
   clean shoes, a shoe-hiding suit and bare feet. Check immediately and after
   the next environmental refresh for stale or accumulating filters.
5. Check ordinary lighting against the same scene; this patch does not touch
   lighting planes or the separate oversized-sprite lighting investigation.

No full-game launch, DreamDaemon run, native client capture, live change, merge
or deployment is part of the recorded local verification. OpenDream remains
paused. Passing offline checks or compilation leaves these visual gates open.
