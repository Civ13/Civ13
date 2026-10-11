# Outdoor crop bootstrap and water

Small bushes yield seeds when harvested with a knife using Help intent. A bush
then waits 10 minutes before offering seeds again. The yield is random, not a
promise that a particular food crop is available immediately.

On Continental, Pangea, New World, Mediterranean, Gaia and Europe Nomads maps,
foraged seeds are selected for the area's biome. Eight biome catalogs are
nonempty: sea, temperate, tundra, taiga, desert, semiarid, savanna and jungle.
Fixed-era maps retain their generic bush seed catalog. A compatible seed still
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
