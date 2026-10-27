# Outdoor crop bootstrap and water

Small bushes yield seeds when harvested with a knife using Help intent. A bush
then waits 10 minutes before offering seeds again. The yield is random, not a
promise that a particular food crop is available immediately.

On Continental, Pangea, New World, Mediterranean, Gaia and Europe Nomads maps,
foraged seeds are selected for the area's biome. Eight biome catalogs are
nonempty: sea, temperate, tundra, taiga, desert, semiarid, savanna and jungle.
Pangea's checked-in map has direct seed stacks and no placed small bushes; catalog
selection alone does not establish a bush-foraging route there. See
[the placed map inventory](outdoor-map-inventory.md). Fixed-era maps retain their
generic bush seed catalog. A compatible seed still
needs a ploughed plot and suitable growing conditions. Season restrictions remain
in effect on climate-restricted Nomads maps; planting does not guarantee growth.

Healing herbs use their existing jungle-bush forage and herb-stack planting
route, not a randomly foraged herb seed. Planting consumes one input unit.
Harvesting a herb crop produces its existing three-unit base stack before
nutrition-dependent multipliers. Medicine owns the remedy behavior.

Rain adds 15 water per crop water check, capped at the crop's existing capacity.
Without an accepted water source, temperate crops lose 15 water per check;
desert, savanna and semiarid crops lose 25. Heat waves cost another 10.
Fresh water within two tiles refills the crop. Empty channels and saltwater do
not irrigate; flooded fresh channels and trenches do. Mushrooms retain their
water exemption. Natural water sources do not have a consumable volume here.

This milestone fixes Europe's catalog selection and finite crop rain storage.
Map-level reachability, research-gated irrigation construction, seasonal survival
and channel propagation still need acceptance before treating outdoor bootstrap
as complete. Modern trays and perennials remain later milestones with explicit
state ownership, finite inputs, power loss and save/load contracts.

## Natural bootstrap route still requiring acceptance

The production global recipe/research checks establish these gates at a Stone
Age faction baseline. They do not supply the missing player walkthrough.

| Step | Production route | Acceptance still needed |
| --- | --- | --- |
| Harvest tool | Two raw wood units offer the wooden knife recipe without Basic Agriculture. | Obtain the wood and craft/equip the knife through normal play. |
| Plank tool | Two stone units offer the Stone Age hatchet recipe through baseline Basic Tools. | Obtain the stone and craft/equip the hatchet. |
| Planks | Wood attackby accepts a hatchet; two raw wood units yield one plank per completed split. A saw has a different conversion. | Obtain the wood and perform the timed splitting actions. |
| Study bench | Eight planks offer the starter research bench. | Craft/place and claim it as a faction with authorised researchers connected. |
| Basic Agriculture | A tier-zero bench can select the node with no prerequisites. Production accounting completes it at 95 study ticks, not 94. | Earn the ticks through the normal researcher/bench scheduler, including permission and faction checks. |
| Plough | Completion offers a four-plank wooden plough. Raw logs do not match this global recipe. | Craft/equip it and prepare reachable suitable soil. |
| Seeds and crop | Help-intent knife forage or the map's direct seed stacks supply the existing seed route. | Reach a compatible source and plot from spawn, then plant, grow and harvest without admin-created inputs. |
| Later irrigation | Basic Agriculture is its prerequisite and a tier-one bench is required. Modern era does not grant this specialist node. | Earn research and bench upgrades, then construct and test water-source and connected irrigation behavior. |

The hatchet route requires 24 raw wood units to make the 12 planks for one bench
and one plough, in addition to the two-unit knife recipe. This is recipe arithmetic,
not measured gathering cost, timing or a promise that resources are accessible.
The source paths are `code/modules/materials/material_sheets.dm` for splitting,
`config/crafting/material_recipes_global.txt` for recipes, and
`code/modules/research_tree/research_node.dm`, `research_faction.dm` and
`research_bench.dm` for the research gates. The compiled check and local omission
control are documented in [the crafting checks](../tests/crafting/README.md).

A factionless Bronze Age player receives the Main-tree Basic Agriculture baseline.
An established Stone Age faction does not receive it merely because another
faction advances the world. The route above describes the default global catalog;
map-specific overrides, other modes and loaded faction state must be checked in
an actual walkthrough. The six-map placed-resource inventory does not establish
walking access or this material/research chain. Keep #3048 and #3049 open.

Full-game save evidence from #3073 also contains an independent native startup
Bad ref diagnostic tracked in #3075. These isolated recipe checks bypass normal
startup and do not resolve or establish the impact of that diagnostic.