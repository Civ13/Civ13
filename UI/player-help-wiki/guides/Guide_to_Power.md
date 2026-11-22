# Power & Batteries

Use an [engine and cable network](Guide_to_Crafting.md#engines) to run electrical machinery. Batteries provide limited cable power; they are not mechanical engines and cannot propel modular vehicles. For vehicle construction, use the [Crafting guide](Guide_to_Crafting.md) and [Tanks guide](Guide_to_Tanks.md).

## Choose a battery

These recipes are in the global crafting catalog. Map catalogs, era and character skill requirements still apply; do not assume a Carib or other specialized map offers them. Tech-tree cable recipes require **Electricity**, so an early battery recipe alone does not create a usable electrical network.

| Device | Crafting and commissioning | Capacity / output limit |
| --- | --- | --- |
| Baghdad-style jar cell | Craft an assembly from 2 copper. Fit a fired clay vase, then 1 iron sheet and 10 units of grape juice. | 167 Wh / 1 kW |
| Iron-copper voltaic-style pile | Craft from 5 copper, then add 5 iron sheets and 50 units of grape juice. | 833 Wh / 5 kW |
| Lead-acid accumulator | Craft from 5 lead. Add 20 units of sulfuric acid to commission it; it remains empty until electrically charged. | 3.33 kWh / 10 kW; charge limit 10 kW |
| Lithium-ion battery bank | Digital Age, Consumer Electronics research. Craft from 25 electronics. It arrives sealed and commissioned, but empty: charge it like the accumulator. | 13.33 kWh / 40 kW; charge limit 40 kW |

Output and demand are shown in kilowatts (kW) and stored energy in watt-hours (Wh, kWh).

## Wind, water and solar generators

These feed the cable grid from the weather instead of fuel. Build them outdoors under open sky; they produce nothing indoors.

| Generator | Era and research | Built from | Peak output |
| --- | --- | --- | --- |
| Wind charger | Early Modern, Electricity | 15 iron | 12 kW |
| Waterwheel generator | Early Modern, Electricity | 15 iron | 12 kW while its river flows |
| Photovoltaic panel | Cold War, Automation | 10 electronics | 10 kW in daylight, nothing at night |
| Wind turbine | Modern, Digital Computing | 30 steel | 45 kW |

Wind output follows the wind speed where the generator stands, shown when you examine it. Hilltops and coasts catch more wind than sheltered valleys. The wind charger gives nothing in calm air, its full output in a strong wind, and furls to a fraction of it in a gale. The wind turbine reaches full output in strong winds and keeps it in a gale. Two rotors closer than three tiles share the same air and each loses half its output, so space them out.

The **waterwheel generator** runs on a river current. Rivers flow on North America, South America, Gaia, Europe, Jungle and Asia; lakes, ponds, swamps and the sea are still. Examine the water to see which way it flows. To build a wheel, stand on the bank, face a flowing river tile and craft it: the wheel goes into the water in front of you and turns to face the current. It gives its full output day and night as long as its own tile flows, and nothing in still water. Use a cable coil on the wheel from the bank to run the cable ashore.

**LED panels** (Digital Age, Consumer Electronics, 2 electronics) are light fixtures built like a [light tube](Guide_to_Construction.md#lighting). They light a little farther than a tube, with a whiter light, on a third of the power, and take ordinary replacement tubes.

Machines that use the cable grid include [hydroponics trays](Guide_to_Farming.md#hydroponics) and the belts, arms and fabricators in [Factory Automation](Guide_to_Factory_Automation.md).

## Connect and operate

1. Assemble and commission the battery. Use a wrench to secure it.
2. Stand beside it and use a cable coil on it, then continue the cable network from there (see [Laying cable](#laying-cable)). A cable merely lying nearby does not establish a connection.
3. Click the battery to select its mode. Primary cells cycle **off → discharge → off**. The accumulator and the lithium-ion bank cycle **off → charge → discharge → off**.
4. Examine it to read stored energy, output limit and mode. Switch it off when finished: discharge consumes energy each second even when no machine uses it.

The jar and pile cannot recharge electrically. When empty, switch off, replace the iron electrode and grape juice using the amounts above. The accumulator charges from spare output of running engines on its cable network, after machine loads; another battery cannot charge it.

Cut its cable before unanchoring. Moving or disconnecting a battery turns it off. After a world save is loaded, stored chemical state is retained, but mode, output and wiring must be rebuilt by players. This describes battery save behavior where server world saves are enabled; it does not promise that every round or server retains your settlement.

## Laying cable

Hold a cable coil and use it in hand to lay a piece on your tile, pointing the way you face. Walk on and lay the next piece to continue a straight run; pieces join wherever their ends meet.

To turn a corner, stand on the corner tile facing the new direction and lay the piece there. When the run arrives from the side and nothing waits behind you, the piece bends into a corner and joins both ways. A straight run that crosses another one stays separate. Use a **cable connector** (1 copper) on the tile to join a T-junction, a crossing or runs of different colors.

### Cable of other metals

Copper cable loses no power. With Electricity research you can also make cable coils from iron, aluminium, silver or gold, one ingot for a 10-piece coil like copper, in the **electrical** section.

| Cable | Power lost for every tile of it |
| --- | --- |
| Copper, silver | None |
| Gold | 0.2% of the grid's supply |
| Aluminium | 0.3% |
| Iron | 2.4% |

- Every tile of such cable anywhere on a grid counts, so iron suits short runs: twenty tiles of it waste about half the supply. A grid never loses more than nine tenths.
- Cable of one metal only joins cable of the same metal. Use a **cable connector** to join two metals, as for two colors.
- Examine a cable to see its metal and the grid's total loss. Cutting a cable gives back a piece of the same metal.

### Wire drawing bench

<img src="../images/Wire_drawing_bench.png">

A **wire drawing bench** makes far more cable from the same metal. Build it from **8 wood**, with **4 iron** and **1 shaft** held or at your feet; you need Electricity research. Fasten it with a wrench, then use copper, iron, aluminium, silver or gold on it. Each unit of metal becomes a **25 metre** coil, where working it by hand gives 10, and it is quicker too. The bench keeps drawing until the metal in your hand runs out or you step away.

A treadwheel, horse gin, mill wheel or windmill turning next to the bench speeds it up. See [Mechanical power](Guide_to_Pottery_and_Lime.md#mechanical-power).

## Transformers, outlets, poles and power meters

A **distribution transformer** (10 iron, Electricity research) powers machines without running a cable to each one. Lay a cable, put the transformer on that tile and fasten it with a wrench. Every machine within 5 tiles that draws power then runs from that cable, as long as no wall, closed door or window stands on the straight line between them. Machines built or moved into its reach join by themselves. Machines that move out of reach, or that lose sight of the transformer when it is unfastened, lose its power. Click it to look for machines again, and examine it to see how many it feeds. A machine that already has its own cable keeps it.

A **wall outlet** (2 copper, Electricity research) works like a small transformer for a room. Lay a cable beside a wall, put the outlet on that tile and fasten it with a wrench: it turns to face the wall, does not block the way, and powers machines within 3 tiles in the same way.

A **utility pole** (6 wood, Electricity research) also powers machines within 3 tiles, and carries **overhead wires** to other poles. Fasten each pole on a cable, then use a cable coil on one pole and then on another within 8 tiles: the wire costs one piece of cable per tile and joins the two grids into one, across roads, fields or rivers. A pole holds up to four wires. Wirecutters take a pole's wires down and give the cable back; unfastening or moving the pole does the same.

A **power meter** (3 iron, Electricity research) shows what a grid is doing. Fasten it on a cable with a wrench, then click it. It shows the grid's supply, demand and load, with a chart of the last minute that keeps updating while you stand next to it. Examine it for a quick reading.

## Power between floors

A cable grid stays on one level until you join it with **cable risers**. Craft a riser from 2 copper in the **electrical** section (Electricity research on the tech tree). Lay a cable on the tile, then stand on it and use the riser in hand, or drop it there and fasten it with a wrench. Put a second riser on a cabled tile at exactly the same spot on the floor above or below. Every cable on the two tiles then joins one grid, so an engine in the cellar can run machines upstairs. A riser also joins every cable on its own tile, like a cable connector. Stack more pairs to carry power up several floors; examine a riser to see whether it has found its partner.

Risers rejoin by themselves after a world save is loaded. Unfastening a riser, or cutting a cable on either tile, splits the grid again.

A **bus tie switch** (2 copper, same section) is a connector you can open and close by hand. Secure it where two runs meet: closed, it joins every cable on its tile; open, it joins none. Click it with an empty hand to switch it.

## Troubleshooting

- **No power:** check commissioning, anchoring, cable attachment, mode and remaining energy. For an accumulator, adding acid does not supply charge.
- **A corner did not join:** lay the corner piece while standing on the corner tile and facing the new direction, with the incoming cable beside you. Otherwise use a cable connector there.
- **A machine near a transformer, outlet or pole has no power:** check it is within reach (5 tiles for a transformer, 3 for an outlet or pole), with no wall, closed door or window on the straight line, and click the transformer, outlet or pole to look for machines again.
- **Overhead wire does nothing:** both poles must be fastened on a cable; examine a pole to count its wires.
- **Nothing upstairs:** a riser needs a secured partner at the same spot on the next floor, and a cable on both tiles.
- **Machine exceeds output:** one accumulator supplies at most 10 kW. The laboratory centrifuge requires 30 kW, so one battery cannot run it. Provide sufficient connected generation; stored capacity alone does not raise output.
- **Cannot craft cables:** check the map catalog, era, skill and Electricity research. Battery availability does not bypass those gates.
- **Engine will not run a vehicle:** inspect its accepted fuel and installation. The chemistry guide's [9:1 blend](Guide_to_Chemistry.md#engine-fuel) is accepted by internal engines that already accept gasoline; it does not add compatibility to diesel-only engines.
