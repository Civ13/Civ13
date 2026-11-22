# Dungeon floor palettes

A room should use a small, related set of surfaces instead of a random set of
materials. Pick a field, an edge, and an accent; use one or two close variants
when they communicate a different function. Reserve stained or broken surfaces
for areas that have a reason to look worn.

## Cobble transitions

Use `/obj/covers/cobblestone/sill` for a one-tile doorway. Across a three-tile
opening, place `sill/cap_left`, `sill`, and `sill/cap_right` in order using the
same facing. These are traversable floor covers: use stock doors or frames on
top when needed, or leave the threshold open. For a longer sill, repeat the
center between the ends. Do not overlap two cover pieces on the same cell.

Run `/obj/covers/cobblestone/trim` along the sides of an approach. Use
`trim/inside` and `trim/outside` to continue the line around corridor turns or
recesses and `trim/stop` or its mirrored `trim/stop/reverse` to end the line before
another surface. The SOUTH
config has a horizontal sill and a south-side border. Rotate all pieces in a
span together, and preserve their left-to-right order relative to SOUTH.
Directions are single-frame BYOND S, N, E, W.

The sill and border come in two tones. The plain types sit on the light
cobblestone floors; the `/dark` types (`sill/dark`, `sill/dark/cap_left`,
`trim/dark`, `trim/dark/inside` and so on) sit on the default and dark crosswise
cobblestone floors. Keep one tone per room.

The four cobblestone floor states are drawn by `scripts/draw_cobble_floors.py`
and the two kits by `scripts/draw_cobble_floor_trim.py --tone light|dark`. Run
the floor script first: the kits take their field and stone colour from it.

## Terracotta

The `/obj/covers/stone/slab/decorative/terracotta` family comprises the field,
`edge`, `inside`, `outside`, and `inset`. Use the patterned inset at a
landing, under a point of interest, or as a deliberate repeating accent.
Do not alternate it randomly with unrelated stone. The edge and both corners
are directional; the field and inset are fixed.

Both palettes are available to map authors and do not change map generation,
physics, doors, or loot.

Players build the terracotta set too. Clay is shaped into unfired terracotta
tiles (Pottery & Cookware), fired in a kiln into a stack of terracotta tiles,
and the tiles lay the field, border, corners and inset through normal floor
placement. Border and corner pieces go down facing south; **Rotate Terracotta
Border** from beside one turns it. The same tiles lay herringbone brick paving
(`/obj/covers/brick_paving`, Brickmaking), which is tougher than the tile floor.
Terracotta is fireproof but takes less damage than cut stone before it breaks.

## Verification

```sh
python3 scripts/check_floor_palette_assets.py
python3 scripts/draw_cobble_floors.py --repo-root . --check
python3 scripts/draw_cobble_floor_trim.py --repo-root . --tone light --output icons/turf/flooring/cobble_trim.dmi --check
python3 scripts/draw_cobble_floor_trim.py --repo-root . --tone dark --output icons/turf/flooring/cobble_trim_dark.dmi --check
```

The check compares the 32-pixel DMI state, frames and direction metadata against
the mapped floor cover declarations. Visually check a one-cell and a three-cell
sill, a turn, and a decorated terracotta room as assemblies rather than
judging the individual tiles alone.

## Matching pieces players can build

The Crafting Atlas exposes 11 existing wood patterns, three more cobblestone
patterns, mossy old stone, and five framed tatami mats. They use normal floor
placement, the same materials as their comparable recipes, and existing
Primitive Construction or Stone Masonry gates. The framed tatami is one mat,
not a second cover. Lay it from bamboo and use **Rotate Tatami Trim** from
beside the installed mat to align a directional border. The fully framed mat
does not need rotation. Wood recipes use distinct construction types with
the same sprites, so old mapped floors do not acquire new salvage.

## Refreshed stock floors

`scripts/draw_floor_refresh.py` redraws mossy old stone, the plain marble floor
and the three raw pink marble slabs, darkens the dark tatami, and moves wood
patterns 1, 7 and 8 onto the warm brown hues of the other wood floors. The pink
slabs share their edge crossings, so the random pick per tile never shows a
break. The eleven wood patterns carry descriptive names (narrow plank,
basketweave, herringbone, parquet and so on) in place of numbers.

## Iron floors

`/obj/covers/iron_plate` and `/obj/covers/iron_grating` are laid from iron
(Iron Smithing), one bar each. Both are fireproof and count as an iron floor
for foundations and wall weathering. The plate is the hardest floor before
steel. The grating lets blood and spills fall through when someone walks on
it; gibs, writing, cobwebs and molten metal stay. The art is drawn by
`scripts/draw_iron_floors.py` (`--check` compares it with the sheet).

## Flagstone, metal, glass, rush and obsidian floors, and pelt rugs

`code/modules/1713/extra_floors.dm` adds eight floors, one unit of material
each, laid through normal floor placement:

| Floor | Material | Research | Health | Notes |
| --- | --- | --- | --- | --- |
| rush matting | leaves | Primitive Construction | 30 | the only one that burns |
| glass block floor | glass | Glassworking | 45 | no blast resistance |
| lead sheet floor | lead | Bronze Working | 70 | soft |
| obsidian tile floor | obsidian | Imperial Architecture | 80 | hard but no blast resistance |
| copper plate floor | copper | Bronze Working | 100 | |
| flagstone floor | stone | Stone Masonry | 120 | cheap paving beside cobblestone |
| bronze tile floor | bronze | Bronze Working | 140 | |
| steel tread plate | steel | Reinforced Concrete | 220 | toughest floor |

Pelt rugs (`/obj/structure/pelt_rug` and its black, white, wolf and white wolf
subtypes, Weaving) take two pelts, lie on top of the floor already there, count as a
covered floor for home comfort, burn, and return both pelts through the Take
Up Rug verb. The art for all of it is drawn by `scripts/draw_extra_floors.py`
(`--check` compares it with the sheets).
