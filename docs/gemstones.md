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

## Lanyards and wrist loops

`code/modules/1713/lanyards.dm`. Each tether fits only what it was made for
(history reviewed by Fable, 2026-11-14):

| Item | Material, research | Fits | Worn |
| --- | --- | --- | --- |
| Wrist thong | 1 leather, Basic Toolmaking | hatchet, machete, knife, club, mace, hammer | bound to the tool |
| Sword knot | 1 leather, Steel Blades | one-handed swords | bound to the sword |
| Neck cord | 1 rope, Weaving | knife, whistle, key | outfit (decor) |
| Fob chain | 1 brass, Optics & Instruments | compass, key | outfit or leather belt |
| Pistol lanyard | 1 rope, Cartridge Firearms | revolver, pistol, whistle, compass, knife | outfit (decor) |
| Retention lanyard | 1 plastic, Synthetic Fabrics | pistol, knife, compass, key, whistle, small tools | outfit or leather belt |

A wrist loop is bound to a tool held in the other hand (use the loop). The
Wrist Loop verb slips the hand in or out (1 s / 0.5 s). While looped, a
dropped or knocked away tool returns to the hand with a short regrip delay.
A lanyard ties the item stowed on it; when that item is dropped it goes back
into the lanyard instead of the ground. Untie Lanyard (1 s) frees it.
Tethered items cannot be thrown. Putting the item in another container or
another person's hands, or the holder dying, releases the tether. Only
boolean vars are kept on the item (`wrist_loop`, `wrist_looped`,
`lanyard_tied`), so saves hold no tether pointers. One lanyard per garment.
Long guns, bows, spears, flintlock pistols and two-handed weapons are left
out on purpose. Cutting a lanyard from someone else is not implemented.

## Art

- `icons/obj/pocket_stronghold_gems.dmi`: ruby, sapphire (cut and rough) and
  cut diamond from Pocket Stronghold 13, CC BY-SA 3.0, pixels unchanged; see
  its `.LICENSE.md` and `tools/art_ports/pocket_stronghold_gems.py`.
- `icons/obj/gemstones.dmi`, `icons/obj/belt_pouches.dmi`,
  `icons/mob/belt_pouches.dmi`: drawn for Civ13 by placing pixels from
  `tests/sprites/create_gemstones.py` and `tests/sprites/create_belt_pouches.py`.
- `icons/obj/lanyards.dmi`, `icons/mob/lanyards.dmi`: drawn for Civ13 from
  `tests/sprites/create_lanyards.py`.
