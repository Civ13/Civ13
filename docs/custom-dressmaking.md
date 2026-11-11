# Custom dressmaking

Make a **dressmaking project** in the cloth crafting menu under **Feminine Clothing**.
It costs four cloth sheets; existing woolcloth substitution accepts wool sheets
at the same cost. It shares the existing dresses' Fine Garments research and
personal-knowledge gate, where enabled. Existing dress recipes are unchanged.

1. Hold the project and use it. Choose **Layered**, **Buttoned**, or **Laced**.
2. Set individual panel colors. Layered has sleeves, skirt and bodice; Buttoned
   has sleeves/skirt and bodice/stripes; Laced has dress and underskirt with fixed
   gold trim. Colors are cosmetic, opaque RGB. Changing cut retains your palette.
3. **Preview** shows front and back garment sprites without a wearer. Close the
   preview and use the project again to keep designing. Nothing is spent here.
4. Confirm **Cut fabric**. After three seconds, the design is locked into cut
   pieces. This is the deliberate commit point, with a default of Keep designing.
5. Choose **Sew dress** on the held pieces. After six seconds, the project becomes
   one wearable dress. No further fabric is charged. Interrupted actions preserve
   the project and the last completed stage. Do not move or drop it while working.

Finished dresses accept the same ordinary accessories as other uniforms,
including sashes, aprons, capes, ties and bows supported by those accessory items.
The cut and colors are fixed after cutting; there is no free recoloring of a
finished dress. Projects and finished designs use normal persistence.

## Scope

This is a sprite-based adaptation of designing panels, previewing, cutting and
sewing, inspired by [Dressmaker](https://store.steampowered.com/app/4019220/Dressmaker/).
All sprites are existing Civ13 art. No external assets were copied. Pattern
placement, fabric grain, freehand cutting, cloth physics, a sewing-machine
minigame, NPC orders and a new fabric/dye economy are not implemented. Cloth and
woolcloth remain recipe substitutes, without separate garment statistics or
fiber provenance. Tools/thread/dye are abstracted, consistent with existing dress
recipes. The nominal project preparation is 25 ticks, then 30 cutting and 60
sewing ticks; generic stack crafting still applies its existing time modifiers.

## Verification

- `python3 -B -m unittest discover -s tests/dressmaking -v` executes the complete
  production cutting/sewing branches through the repository's audited DM subset
  adapter with fake engine boundaries. It checks happy paths, wrong stage,
  cancellation, late invalidity, competing finish, failed transfer and a missing
  post-wait guard control. Source checks cover menus, research and persistence;
  sprite checks read actual DMI pixels and directions.
- `python3 scripts/check-recipes.py` includes `tests/crafting/dressmaking.dm`.
  This native fixture checks actual cloth/wool payment, valid/invalid colors,
  cuts/layers, production transitions with controlled waits, interrupted work,
  custom disk-entry round trips and decoration/blood rebuilding. Actor physiology
  and HUD are isolated; it does not establish real-client interaction.
- `python3 scripts/agent_preflight.py all --write` runs the full offline registry
  and regenerates the crafting atlas and recipe audit index. The atlas includes
  both project acquisition and the project-to-dress procedure.

Compiler, native fixture, hosted CI, and connected-client outcomes belong in the
PR verification report. A fixture's existence is not evidence that it ran.
