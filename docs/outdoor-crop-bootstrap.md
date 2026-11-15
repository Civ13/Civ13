# Outdoor crop bootstrap and water

Small bushes yield seeds when harvested with a knife using Help intent. A bush
then waits 10 minutes before offering seeds again. The yield is random, not a
promise that a particular food crop is available immediately.

On Continental, Pangea, New World, Mediterranean, Gaia, Europe and both Americas
Nomads maps, foraged seeds are selected for the area's biome. Eight biome catalogs are
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

Map-level reachability is audited per map and climate in
[the placed map inventory](outdoor-map-inventory.md). Research-gated irrigation
construction and channel propagation are separate work. Modern trays and
perennials remain later milestones with explicit state ownership, finite inputs,
power loss and save/load contracts.

## Natural bootstrap route

On a persistent book research world a new character knows no chapters, so the
old wooden-plough route through a faction study bench no longer applies. The
route below is the one the full-game walkthrough takes on the North America
map, from empty hands, with player actions only
([tests/natural_bootstrap](../tests/natural_bootstrap/README.md)).

| Step | Production route |
| --- | --- |
| Reach water | Walk to fresh water with ploughable ground within two tiles. Plain grass and dirt plough; jungle grass, jungle dirt, dust, sand and seasonally flooded dirt do not. |
| First book | Found a faction (Faction > Create Faction). The founder receives the Stone Age master book and a writing slate. |
| Basic Toolmaking | Use the book in hand and study the chapter. It takes about a minute and needs daylight or another light. |
| Flint knife | Search a rock on Grab intent for flint (twice, one per hand), then strike one flint with the other and choose Flint knife. A failed strike shatters the flint; search again. |
| Wood | Cut a tree down with the knife (about ten cuts) and pick up the logs. |
| Digging stick | Craft it from two wood with Basic Toolmaking known. |
| Plough | Use the digging stick on grass (it becomes dirt) and again on the dirt (it becomes a ploughed plot). |
| Seed | Use the knife on a wild small bush on Help intent. Each bush gives one seed for the area's biome, then rests ten minutes. |
| Plant and grow | Use the seed on the ploughed plot. Within two tiles of fresh water the crop needs no watering. A stage takes a minute; most crops are ready at the seventh. |
| Harvest and replant | Use the knife on the ready crop. It leaves produce and at least two seeds; the plot stays ploughed, so a seed goes straight back in. |

The walkthrough saves the world while the crop is growing, restarts the server,
and checks that the character, its learned chapter and tools, each crop's stage
and its soil come back before it harvests and replants. Season restrictions
still apply outside jungle, desert and savanna: a crop planted out of season
waits. The walkthrough does not cover irrigation building, winter survival, or
what a client draws.
