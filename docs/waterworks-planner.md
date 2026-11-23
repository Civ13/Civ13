# Waterworks Planner

Use a blank ship's draught while holding a pen or pencil and choose **Draw
waterworks on the sheet**. Draw either an aqueduct or a sewer, one route per
sheet. Select a part and add the route in order along tile edges. Use the
numbered tiles to change a part, or remove the last part and continue from
there. The board is 7 tiles square; one route may use up to 24 tiles.

- **Aqueduct:** start with an intake beside fresh water. Link it to a fountain
  or cistern with stone channels, raised timber flumes or stone arches, or
  buried clay pipe. An open channel drops the available water level to the
  ground it sits on; a raised piece keeps the level across a dip. A clay
  pipe carries the incoming level through higher ground. The preview warns
  if the visible source shows swamp water, river pollution or heat drying; it does not certify water quality.
- **Sewer:** start with a floor drain, run covered stone drains or brick
  sewers, and end with a stone drain on the water's edge. An earlier link
  beside water is another real outfall, so redraw the route away from that
  bank. Uphill sections are flagged as advice: existing sewers connect by
  adjacency, not by grade. Freshwater discharge can contaminate downstream
  water. Existing settling tanks are one mitigation, not a guarantee; they
  fill and need maintenance.

Stand at the intended south-west corner and select **Preview site**: the
checks apply to that tile and level, with north at the top of the sheet.
The planner checks the route's shape, supported dry tiles, conflicting
structures, bank access and terrain height where available. The list shows
the normal recipe materials still outstanding at that site; the part panel
lists the corresponding research. Unsurveyed parts are counted as unbuilt.
The route and relevant adjoining bank tiles must be visible in good light. Where terrain heights are unavailable, the
game treats the map as level. A site report is not a simulation of water sent
through the whole surrounding town, and the physical site can change later.

**Save to sheet** preserves the drawing. Use the saved sheet and choose **Peg
out the saved route here** from the same south-west corner when ready. The
site is checked again after marking out; an invalid site leaves old pegs alone.
Pegs indicate the exact missing pieces and disappear when those pieces are
built. They do not build, provide materials, or grant research. Build each
part with its usual craft recipe. Pegging somewhere else replaces that
sheet's earlier pegs, or you can pull them separately. The usual **Export
code** and **Import code** actions copy only the drawing (C13WATER),
not its site or pegs.

This first version has no branching, multilevel runs, separate usable sewer
hatches, flow or flooding forecast, or automatic construction. The manhole
visible on the brick sewer is part of its existing sprite. See
[Aqueducts](aqueducts.md), [River flood and sewers](river-flood.md), and
[Builders' pegs](build-markers.md) for the existing systems.
