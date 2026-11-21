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

## Terracotta

The `/obj/covers/stone/slab/decorative/terracotta` family comprises the field,
`edge`, `inside`, `outside`, and `inset`. Use the patterned inset at a
landing, under a point of interest, or as a deliberate repeating accent.
Do not alternate it randomly with unrelated stone. The edge and both corners
are directional; the field and inset are fixed.

Both new palettes are available to map authors. They do not change map generation,
physics, doors, or loot, and do not change the existing crafting and firing
process for clay. A player route for the new terracotta set is separate from art
and mapper integration.

## Verification

```sh
python3 scripts/check_floor_palette_assets.py
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
