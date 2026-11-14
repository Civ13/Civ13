# Gemstones and belt pouches

Code: `code/modules/1713/gemstones.dm`, `code/modules/1713/belt_pouches.dm`.

## Gemstones

- Every mined rock wall has an independent 2% roll for one rough gemstone
  (two in special caves), separate from the ore table in
  `docs/mining-drop-balance.md`. Weights: garnet 30, amethyst 25, topaz 20,
  emerald 10, sapphire 8, ruby 7. Rough diamonds keep their existing ore roll.
- Cutting: chisel in the active hand, hammer in the other, use the chisel on a
  rough stone (in hand-reach or on an adjacent tile). One stone per action,
  8 s scaled by dexterity, needs Regalia & Heraldry. A flaw ruins the stone
  15% of the time (less with crafting skill). Cut stones land on the tile.
- Decoration: hold a cut stone with a chisel in the other hand and use it on
  any piece of clothing (rings, crowns, belts, garments). One stone per item;
  it adds the stone's value and an examine line.

## Belt pouches

Leather belt pouch (1 leather, Basic Toolmaking) and cloth drawstring pouch
(1 cloth, Weaving). Six slots, small items only, no containers. Worn in the
belt slot or the Hip slot, carried in a pocket, or hung from a garment or a leather belt (at
most two per garment or belt; the second hangs on the left hip).

Belts: the leather belt (1 leather) is worn in the belt slot and takes up to
two pouches, drawn on the wearer; clicking the worn belt opens them. The
shoulder belt (2 leather) is a cross-body strap attached to clothing in the
sash accessory slot, so it is worn together with the waist belt without a
second belt slot; it holds two pouches, or one sword and a pouch. Both need
Basic Toolmaking.

Belt points: besides its two pouches the leather belt takes one sheath or
holster and one tool loop (1 leather, Basic Toolmaking). The loop holds one
item that can be worn in the belt slot, other than bags, clothing and guns.
A worn belt with several attachments opens the attachment strip
(`code/_onclick/hud/attachment_strip.dm`).

## Art

- `icons/obj/pocket_stronghold_gems.dmi`: ruby, sapphire (cut and rough) and
  cut diamond from Pocket Stronghold 13, CC BY-SA 3.0, pixels unchanged; see
  its `.LICENSE.md` and `tools/art_ports/pocket_stronghold_gems.py`.
- `icons/obj/gemstones.dmi`, `icons/obj/belt_pouches.dmi`,
  `icons/mob/belt_pouches.dmi`: drawn for Civ13 by placing pixels from
  `tests/sprites/create_gemstones.py` and `tests/sprites/create_belt_pouches.py`.
