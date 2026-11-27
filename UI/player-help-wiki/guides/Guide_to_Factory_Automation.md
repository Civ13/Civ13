# Factory Automation

From the industrial eras on, a faction can build production lines that run without anyone standing at the machines. Belts carry loose items, powered arms move items between belts, crates and machines, fabricators turn parts into goods, and pipe networks move liquids and gases between wells, gas works, refineries, tanks and reaction vessels.

Everything here is built from the crafting menu and needs research on your faction's [tech tree](Guide_to_Research.md). Most pieces need cable power; see [Power & Batteries](Guide_to_Power.md) for generators.

## Research and parts

| Research | Unlocks |
| --- | --- |
| **Factories** | Tanning drum, barrel station, fluid pipe, pipe valve, fluid pump, holding tank, reaction vessel, water intake, water tap, piped shower, piped washing machine |
| **Assembly Line** | Factory belt, parts bin, belt drive, assembly fabricator |
| **Automation** | Feeder arm, sorting arm, sorting gate, reagent gate, belt splitter, belt tunnel entrance and exit, fast factory belt, factory monitor, automated fabricator, bottler, fast reaction vessel, pipe meter |
| **Digital Computing** | Stack arm, computerized fabricator, industrial reaction vessel |
| **3D Printing** | 3D printer |
| **Pharmacology** | Automatic tablet press |

Belts, drives, bins, gates, splitters, tunnels, fabricators and all the pipe machines are crafted from steel. Arms, the factory monitor and the higher fabricators also need electronics.

Arms, fabricators, belt drives, the factory monitor, pipes, pumps, tanks, bottlers and the other pipe machines can be unfastened with a wrench and moved, then wrenched down again. An unfastened part does no work: an unfastened pipe joins nothing, and an unfastened tank or pump drops out of its network until it is fastened again. Switch an arm off before wrenching it.

## Belts

A **factory belt** carries loose items toward its arrow and hands them to the next belt, a machine or a crate in front of it. Each belt tile holds up to four items, and items move about two tiles a second. Items on a belt are ordinary floor items, so you can pick them up or examine them at any time.

- Craft a belt, then use it on an adjacent floor tile to lay it running away from you. Turn a laid belt with a wrench; pry it up with a crowbar.
- Belts only run near a running **belt drive**. One drive, cabled and switched on, runs every belt within seven tiles. Belts outside the range of a running drive stand still.
- A **fast factory belt** moves items twice as fast as a plain belt.
- Belts and their direction are kept across server restarts.

### Routing

| Piece | What it does |
| --- | --- |
| **Sorting gate** | Items that match its filter leave by the side; everything else goes straight on. Hold an item and use the **Set Gate Filter** verb to choose the filter. A screwdriver swaps the side. |
| **Reagent gate** | Like a sorting gate, but it sorts containers by the main reagent inside them. Set the filter while holding a container; an empty container makes it sort out empties. |
| **Belt splitter** | Sends items alternately straight on and to the side. A screwdriver swaps the side. |
| **Belt tunnel** | A tunnel entrance carries items underground to a tunnel exit facing the same way, up to six tiles ahead. Use it to cross another line or a wall. |

## Arms and bins

An arm takes items from the tile behind it and sets them down on the tile in front: onto a belt, into a crate or machine, or onto the floor (up to twelve loose items). Wrench it in place, cable it, then click it to switch it on. While it is off, right-click it and use **Rotate Left** or **Rotate Right** to turn it.

| Arm | Moves |
| --- | --- |
| **Feeder arm** | One item of anything per swing. |
| **Sorting arm** | One item per swing, only of its filter kind. Hit it with an item to set the filter; it moves nothing until a filter is set. Use **Clear Filter** to reset it. |
| **Stack arm** | Up to ten items of one kind per swing. It can be given a filter the same way, or left without one to move anything. |

A **parts bin** is a steel crate for a production line. Once it holds something, it only accepts more of the same kind, so each bin stays sorted.

Arms can load and unload:

- belts, crates, parts bins and fabricators;
- **bloomeries and blast furnaces**, which take iron ore and fuel and start smelting on their own once both are loaded;
- **steelworks** (coke banks, finery forges, cementation, puddling and open hearth furnaces, Bessemer converters and electric arc furnaces), which take their charge and fuel and fire on their own once the charge is full (a Bessemer converter still needs someone to tip it, and a puddling furnace someone to stir it);
- the **powered saw mill**, which holds up to 20 logs and cuts one log a second into planks while powered;
- the **tanning drum** (see [Tanning drum](#tanning-drum)), which takes hides and bark and leaves leather;
- the **powered stamp mill** (see [Stone crushing](#stone-crushing));
- **train wagons and shopping carts**, with the same limits as a person filling them by hand;
- **barrels**, to and from oil wells, refineries, engines and barrel stations.

Machines leave their output on their own tile for an arm to collect. They wait once about twelve stacks have piled up.

## Fabricators

A fabricator turns belt-fed parts into goods from a fixed factory recipe list. Wrench it in place, cable it, then click it to choose a recipe; you can only choose recipes your faction has researched. Arms and belts fill its input buffer, it consumes inputs only when a cycle finishes, and a power cut pauses it without losing anything. Output is left on its tile.

| Fabricator | Research | Speed | Recipes |
| --- | --- | --- | --- |
| Assembly fabricator | Assembly Line | Normal | Tier 1 |
| Automated fabricator | Automation | 25% faster | Tiers 1-2 |
| Computerized fabricator | Digital Computing | Twice as fast | Tiers 1-3 |
| 3D printer | 3D Printing (Digital Age) | Half speed | Printing recipes only |

| Recipe | Makes | From | Tier | Research |
| --- | --- | --- | --- | --- |
| Rolled steel | 4 steel | 5 pig iron | 1 | Assembly Line |
| Barbwire | 3 barbwire | 2 iron | 1 | Assembly Line |
| Bronze | 4 bronze | 3 copper, 1 tin | 1 | Assembly Line |
| Brass | 3 brass | 2 copper, 1 zinc | 1 | Assembly Line |
| Glass | 1 glass | 2 sand | 1 | Assembly Line |
| Metal rods | 2 rods | 1 steel | 1 | Assembly Line |
| Cable coil | 30 cable | 2 copper | 1 | Assembly Line |
| Rifle casings | 3 casings | 1 copper | 1 | Assembly Line |
| Pistol casings | 3 casings | 1 copper | 1 | Assembly Line |
| Iron bullets | 3 bullets | 1 iron | 1 | Assembly Line |
| Ammo clips | 1 empty clip | 1 copper | 1 | Assembly Line |
| Stone bricks | 2 stone bricks | 2 stone | 1 | Assembly Line |
| Wrench | 1 wrench | 5 iron | 1 | Assembly Line |
| Screwdriver | 1 screwdriver | 2 iron | 1 | Assembly Line |
| Claw hammer | 1 hammer | 3 iron | 1 | Assembly Line |
| Wirecutters | 1 wirecutters | 4 steel | 1 | Assembly Line |
| Synthetic leather | 2 synthetic leather | 1 cloth, 1 plastic | 1 | Synthetic Fabrics |
| Electronic circuits | 3 electronics | 2 copper, 1 plastic | 2 | Automation |
| Ammo belt | 1 empty belt | 7 copper | 2 | Automation |
| Electronic components | 1 component | 3 electronics, 1 gold | 3 | Digital Computing |

Synthetic leather is plastic-coated cloth. It crafts everything ordinary leather does, but it does not stack with tanned leather.

Examine a fabricator to see its recipe, inputs and cycle time.

### 3D printer

The **3D printer** (12 electronics) prints plastic goods. Wrench it down, cable it, choose what to print, then load plastic sheets by hand or with arms and belts. Prints are left in front of it. You can make plastic in a [bakelizer](Guide_to_Crafting.md#bakelizer).

| Print | Makes | Plastic |
| --- | --- | --- |
| Screwdriver | 1 | 1 |
| Dice (d20) | 2 | 1 |
| Bug swatter | 1 | 1 |
| Bottle | 2 | 1 |
| Gallon jug | 1 | 2 |
| Pill pack | 2 | 1 |
| Blood bag (empty) | 1 | 1 |
| Surgical mask | 2 | 1 |
| Bag valve mask | 1 | 2 |
| Hard hat | 1 | 3 |
| Gas mask | 1 | 3, plus 1 glass |
| Traffic cone | 1 | 2 |

### Plastics molding machine

**Industrial Plastics** (World War II) follows Assembly Line, Combustion Engine and Electricity. It unlocks the **plastics molding machine** (15 steel, production category). Wrench it down, cable it and click it to pick a die, then load thermoplastic pellets by hand or with arms and belts. It holds pellets for two runs. Products are left on its tile. It only runs its own dies, and losing power pauses it without using up pellets. Clearing the recipe gives back buffered pellets.

Make pellets in a [bakelizer](Guide_to_Resins_and_Fabrics.md#the-bakelizer-and-its-resins) from crude petroleum, or at the laboratory reaction bench from polyethylene or polypropylene.

| Die | Makes | Pellets |
| --- | --- | --- |
| Extrusion | Plastic sheet | 1 |
| Injection | Plastic tool handle (fits tool heads like a wooden handle) | 2 |
| Injection | Plastic comb | 1 |
| Blow molding | Empty plastic bottle | 1 |
| Blow molding | Plastic play ball | 1 |
| Film forming | Reusable plastic bag | 1 |

## Factory monitor

The **factory monitor** is a terminal that lists every arm, fabricator, belt drive and belt within seven tiles, with what each one is doing (running, waiting, unpowered) and how many items it moves or makes a minute. Use it to find the bottleneck in a line.

The monitor also lists each pipe network within seven tiles once: how many pipes it has, how many of its pumps are running, whether anything is flowing and how many units moved on the last pump cycle. A network you have just built or changed shows up after its next pump cycle. For one machine's details, use a pipe meter.

## Stone crushing

Crush **ore-bearing rubble** from a blasted rock cluster to recover one unit of its named ore per chunk. The ore depends on where the rock was quarried, not where you crush it. Ordinary mined stone can yield sand, but it does not give a second chance at ore. Old or unmarked stone still works and uses Gaia's trace-ore table. Gold-bearing quartz and silver lode ore still yield crushed ore for washing.

- The **stone crusher** is a hand-worked stone wheel (Resource Processing research, 10 stone). Anchor it and use your held stack on it. It works one unit at a time until the stack runs out or you stop. Clear the output before twelve stacks pile up.
- The **powered stamp mill** (Electricity research) holds up to fifty units of mixed feed, needs 150 cable power and works one unit every four seconds. It recovers sand more often, but extracts the same amount of ore from each chunk of named rubble. Arms can load it.

The **primitive saw mill** works the same way as the hand crusher: it keeps cutting your held log stack one log at a time until the stack or the blade runs out, or you stop.

## Tanning drum

The **tanning drum** makes leather without scraping, washing, rack drying and tanning each hide by hand. It is a powered wooden drum on a steel frame, crafted from **10 steel** with **Factories** research. Using it also needs Resource Processing.

1. Wrench it down and connect it to cable power. It uses 3 power.
2. Load hides: raw hides, pelts, scraped hides, wet hides or dry hides, up to **30 pieces** in any mix. Use a held stack on it, or let an arm feed it.
3. Load up to **20 pieces of bark**, and fill it with **water** and **tannin**, up to 100 units of each. Pour them from any open container, or pipe them in from a pumped network. Other liquids are refused.
4. While powered, it turns one hide into **one leather sheet every two seconds** and leaves the leather on its own tile, where an arm can collect it.

Each hide costs **5 tannin**, plus **5 water** if the hide has not been washed yet, the same as by hand. Washed and dried hides go first. When tannin runs short, the drum soaks one piece of bark in 10 water for 10 tannin by itself, so a drum fed with bark and piped water needs no tannin from you. Examine the drum to see what it holds and why it is waiting. Click it with an empty hand to empty the hopper; the hides come back as they went in. Pelts loaded into the drum become leather, so keep the ones you want for fur clothing.

## Pipe networks

Pipes move liquids and gases between machines. There is no separate gas pipe: hydrogen, helium and oxygen travel through the same pipes, pumps and valves as water or oil. A pipe network does nothing until a **powered pump** on it is switched on, or a hand pump on it is being worked; then, every two seconds, machines that want a liquid or gas pull it from machines that offer it.

- **Sources** offer liquid or gas: oil wells, water intakes (set beside open water), refinery output, barrel stations set to drain, steel barrels fitted to a pipe, and the hydrogen generator, electrolysis tank, water-gas retort and helium separator.
- **Holding tanks** store liquid or gas, and a **gas holder** stores a large amount of one gas. Hold a container and use **Set Tank Filter** to keep a tank to one reagent. Tanks never feed other tanks.
- **Sinks** take liquid or gas: gas compressors, refinery feed, engine fuel tanks, barrel stations set to fill, bottlers, reaction vessels, the automatic tablet press, water taps, piped showers and piped washing machines.
- A **pipe valve** splits the network in two while closed. Click it to open or close it.
- A **pipe meter** clamped on a pipe reports that network's pumps, what moved and each machine's state. Its dial lights while anything is moving.

Contents of tanks and machines are held inert, so they do not react while stored.

### Barrels and the barrel station

Barrels ride belts and arms like any item. Arms can hand barrels to oil wells (which hand them back once full), refineries and engines. A **barrel station** drains barrels that automation brings it into its own tank, or fills them from it, then hands each barrel back out. Use **Switch Station Mode** to choose. A **reagent gate** sorts barrels by their contents.

### Water supply

A **water tap** and a **piped shower** run on whatever the pipes bring them, and go dry when the network stops supplying them. Fill a container at a tap, drink from it on grab intent, or wash your hands in it. A tap gives exactly what came down the pipe, so river water from an intake is still unboiled at the tap. A piped shower only takes water.

### Pipes of other materials and plumbing before electricity

Pipe does not have to be steel. From **Basic Toolmaking** you can make pipe by hand from bamboo, logs, lead, copper or iron, and it joins steel pipe and every pipe machine in the usual way.

| Pipe | Made from | Carries |
| --- | --- | --- |
| Lead pipe | 1 lead | 45% of a pump's flow |
| Bamboo pipe | 1 bamboo | 55% |
| Bored log pipe | 2 wood | 65% |
| Copper pipe | 1 copper | 75% |
| Iron pipe | 1 iron | 90% |
| Fluid pipe (steel) | 1 steel | 100% |

- A network moves only as fast as its **weakest pipe**. One length of bamboo in a steel line slows the whole line. Examine any pipe to see what its network is held back by.
- **Lead pipe poisons the water.** While liquid moves through a network with any lead pipe on it, a little lead now and then ends up in its tanks, troughs and taps, and lead slowly harms whoever drinks it. Every pipe on such a network warns you when examined.
- Bamboo and log pipes burn.

Four wooden pieces let you pipe water long before electricity:

| Piece | Research | Made from | What it does |
| --- | --- | --- | --- |
| Hand pump | Workshops | 6 wood and a shaft | Pumps while you work the handle: click it and stay beside it. A turning treadwheel, horse gin, mill wheel or windmill next to it works it for you. It takes no cable. |
| Wooden water intake | Cooperage | 4 wood | A water intake: set it beside open water. |
| Wooden cistern | Cooperage | 10 wood | A holding tank. |
| Water trough | Cooperage | 4 wood | A water tap: fill a container, drink on grab intent or wash your hands. |

From **Bronze Working** a smith can also raise a **metal holding tank** from 10 copper, bronze, lead or iron. It works like any holding tank, with two cautions:

- A **lead tank** slowly poisons what is piped into it, the same way lead pipe does. Do not drink from it.
- **Acid eats iron.** An iron tank loses a little of any strong acid piped into it. Keep acid in copper, bronze or steel.

Examine a tank to see either warning.

A simple supply is an intake at the river, a run of pipe, a hand pump beside the pipe and a trough in the village. Water from a river is still unboiled at the trough.

A **piped washing machine** (8 steel) also needs the pipes: each wash takes 20 units of pumped water, and it will not start while it is disconnected or short of water, even with water left inside. Examine it to see how much it holds. Washing machines already placed on a map have their own supply and need no pipes.

To feed the network from a barrel, stand a **steel barrel** on or next to a fastened pipe and use a wrench on it. A fitted barrel offers everything it holds to the network while a pump runs, but it never fills from the pipes. Moving or picking up the barrel, or using the wrench on it again, detaches it. An open barrel left outdoors with nothing overhead catches rain, and dew on clear nights, so a fitted steel barrel can keep a tap supplied. Wood barrels and jerrycans do not fit pipes.

### Reaction vessels

Pipe a **reaction vessel** to your tanks and choose a laboratory recipe. It draws a full batch of that recipe's inputs in the right ratio, reacts them with power, then lets everything except the catalysts out to the network. Use holding-tank filters to separate the product from leftovers. Fast (Automation) and industrial (Digital Computing) reaction vessels work bigger batches faster. See [Chemistry](Guide_to_Chemistry.md) for the recipes.

### Packaging

- The **bottler** takes open containers from belts and arms, fills each one with its chosen reagent from the pipes and hands it back full. Hold a filled container and use **Set Bottler Reagent** to choose the reagent.
- The **automatic tablet press** draws calcium carbonate and aspirin from its pipes and presses aspirin tablets onto its tile for arms to take.
