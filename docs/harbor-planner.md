# Harbor Planner

Hold a blank ship's draught and a writing tool, then choose **Draw a harbor
on the sheet**. Pick a project and use **Rotate** to align it at the current
tile. **Survey from here** moves the plan to the tile where you now stand,
facing the way you face. Keep holding the sheet and writing tool while using
the planner. Red tiles and findings identify likely problems; the checks do
not grant construction permission or promise that a ship fits.

| Project | Mark on the plan | Start the real build |
| --- | --- | --- |
| Timber pier | A straight one-tile route from firm ground across shallows | Build and secure a pile driver. Fit one timber pier span at a time, from the shore or completed deck. |
| Steel pier | The same route, which can cross deep surface water | Fit steel bridge spans one tile at a time. The plan cannot support or place them. |
| Shipbuilding slipway | The chosen schooner or freighter's rectangular surface envelope and its bow direction | Build the actual slipway post, face it toward water with a wrench, then use the post to lay a keel and pay for work in stages. |
| Boathouse slip | The actual 7-by-7 corner of water for small or modular boats | Build the boathouse and turn it to that corner. Bring a stopped boat wholly inside; this is not a berth for full slipway ships. |
| Drydock | One gate with water behind it, then a rectangular basin inland | Dig a basin and put gates on the flooded mouth. Sail in, shut every gate and pump out the basin. Open the sluices before sailing out. |

**Save on sheet**, **Export**, and **Import** use the usual draught workflow.
The code holds dimensions, project and hull choice; it does not carry a
region, coordinates, supplies, findings or a permission to build. Another
player can take the same layout to a different site. The marks are on the
sheet only; the planner does not place world pegs, consume materials, move
ships, alter water, or replace the normal building interactions.

Survey only shows tiles presently visible to your character from the anchor.
Unseen tiles are marked `?` and are neither clear nor obstructed; inspect
the site in-game if the footprint, perimeter or whole launch route is not
visible. Remote camera views are not used. Depth is the game's terrain
class, not a numerical measurement. The rectangular slipway survey is
conservative about surface room and does not
model the exact tapered hull or the hold below it. Final launch clearance
still comes from the slipway. The drydock preview tests the proposed
rectangle and nearby open water, including diagonal leaks. Only the actual
gate surveys every connected trench tile and the final gates. Buildings,
crafting research, tool and map-catalog rules still apply.

See [Slipway](slipway.md), [Berths](berths.md) and [Design checks](design-checks.md).
