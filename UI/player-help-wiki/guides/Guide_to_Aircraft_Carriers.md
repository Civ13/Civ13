# Aircraft Carriers

An aircraft carrier is a ship forty tiles long and nine wide that is laid down whole at a **shipyard office** and sails as one block across the ocean. It has three decks on three levels: a **hangar deck** below the waterline with six watertight compartments, the **flight deck** at the surface, which is a runway from stern to bow, and an **island** on the level above with the ship's wheel. [Light planes](Guide_to_Aircraft.md) take off from the deck, land on its arresting wires and ride two elevators down to the hangar. Carriers need a world with a level below the sea and open sky above it: at the moment that is only **[Gaia](../maps/Gaia.md)**, one of the persistent lands. North and South America have no level below the sea.

## Research and materials

| Part | Cost | [Tech tree](Guide_to_Research.md) node | [Legacy research](../gamemodes/Civilizations_and_Nomads.md#research) |
| --- | --- | --- | --- |
| Shipyard office | 60 steel | Naval Aviation | Industrial 150 |
| Aircraft carrier | 400 steel, 20 glass, 40 cable | Laid down at the office | Laid down at the office |
| Shoring kit | 6 soft wood | Submarines | Industrial 126 |

**Naval Aviation** is an Industrial node in the Vehicles line. It needs **Powered Flight** and **Submarines**. The office is in the **production** crafting category and only works for a faction that has finished the node. Shoring kits are a plain soft wood recipe once Submarines is researched; keep a few aboard for [damage control](#damage-control).

## Laying the ship down

1. Stand on the shore with the open sea to your **north-east**, lay a power cable, and craft the shipyard office from 60 steel. The ship's stern corner goes on the tile diagonally north-east of the office, and from there it needs a clear box of **deep sea** 40 tiles long and 9 wide along the heading you pick: bow east or west for a box lying east to west, bow north or south for one lying north to south. The office is not built if the research, the cable or the sea is missing, and you are told which heading fails and why.
2. Feed steel, glass and cable stacks into the office, and drag an adjacent laid cable onto it to connect a network with **20 available power**, as for the automobile workshop. Examine the office to see what it holds.
3. Click the office and choose **Aircraft carrier, bow** east, north, west or south. Stay next to it while it works. Nothing is spent until the ship is laid down, and **Unload inputs** returns the stock.
4. The carrier appears anchored, with empty bunkers. Walk onto the flight deck from the shore, or row out to it, climb the ladder on the **starboard** side amidships to the island, and go down the hatch ladder amidships to the hangar deck.

## The decks

- **Hangar deck** (one level down): from stern to bow the engine room, the fuel bunker with the **bunker filling point**, the crew quarters, the hangar, the **magazine** with its two bomb racks, and the forward compartment, each behind a steel bulkhead with a blast door on the centreline. The two **aircraft elevator** floors are on the port side of the hangar, with a lever beside each. The hangar deck keeps its own air pocket: a hull breach floods the compartment but the ship does not vent.
- **Flight deck** (the surface): steel plating that counts as runway from stern to bow. The **arresting wires** cross the after deck four tiles wide; the two 4x4 **elevator platforms** lie on the port side with their levers beside them; the **catapult** track, three wide and four long, lies on the port side at the bow with its firing lever beside it; a **gun tub** stands at each of the four corners of the deck; **deck lights** line both edges; a hatch ladder amidships goes down to the hangar and a ladder on the starboard side goes up to the island.
- **Island** (one level up): a 5x3 superstructure on the starboard side with the **ship's wheel**, the **radar set** beside it and a **searchlight** at each after corner.

## Sailing

The ship moves in **hops**: every 30 seconds it shifts along its heading by 2 tiles at slow ahead, 4 at half and 6 at full, with everything and everyone aboard, and the sea closes behind it. Click the **ship's wheel** on the island:

| Choice | What it does |
| --- | --- |
| **Chart** | Position, heading, telegraph, anchor, fuel and hops left, what lies up to 12 tiles ahead of the bow, and why the ship last stopped; then the [sea chart](Guide_to_Boats.md#harbours-and-the-sea-chart) with nearby ships and every harbour |
| **Make for a berth** | Slides her alongside a [mooring post](Guide_to_Boats.md#harbours-and-the-sea-chart) within 20 tiles |
| **Hail a ship** | Calls across to a ship the lookout sees; her whole crew reads it (see [Hails and running dark](Guide_to_Boats.md#hails-and-running-dark)) |
| **Run dark / Show her lights** | Other ships see an unknown contact instead of her name. The deck lights go out and slow ahead is all she makes |
| **Grapple a ship** | Throws lines at a ship within 3 tiles: both are held fast and the crews can cross (see [Grappling and boarding](Guide_to_Boats.md#grappling-and-boarding)) |
| **Ship's papers** | The crew register: who owns the ship and who may take the wheel (see [Ship's papers](#ships-papers)) |
| **Full / Half / Slow ahead**, **All stop** | Ring down a speed; the ship sails only with the anchor up and fuel in the bunkers |
| **Head north / east / south / west** | Come about on the spot; the ship turns about its centre and needs clear sea for the new box. The water she will swing over is marked in yellow and she turns five seconds later. Everything aboard turns with her: guns, chairs, loose cargo and the crew keep facing the same way relative to the bow |
| **Weigh anchor / Drop anchor** | A ship at anchor never hops, whatever the telegraph says |
| **Deck lights on / off** | Switches the lights along the flight deck edges; the setting is kept with the ship |

Five seconds before each hop the water the ship is about to cover is **marked in yellow**, and anyone swimming there is warned. Get clear: anything solid still in the way stops the ship.

The ship stops by itself, with the reason sent to everyone aboard, when land, a pier, another ship or the edge of the world lies in its way, when the bunkers run dry, and while the world is being saved. A blocked full hop tries shorter ones first, so the ship closes up to an obstacle instead of stopping short of it.

### Ship's papers

A ship nobody has registered sails for whoever stands at the wheel. To make her yours, click the wheel, choose **Ship's papers** and **Register her to** your faction (or to yourself if you have none). You become her **captain**. This works on every ship steered from a ship's wheel, including the schooner and the freighter.

Once she is registered:

- **Owners** (every member of the faction she is registered to) and listed crew who are **captain** or **helmsman** use the wheel as before.
- **Anyone else** can still **force the wheel**. It takes about 15 seconds of standing at the wheel and everyone aboard is told who is doing it. On Gaia this remains possible even when no owner is in the world; elsewhere it requires an owner to be present.
- Away from Gaia, with **no owner in the world**, the wheel is chained, and so are the elevator and catapult levers and the radar. On Gaia, outsiders can work the levers and radar even when the owners are away.
- Listed crew of any role can always work the levers and the radar.

Owners and the captain keep the papers at the wheel:

| Choice | What it does |
| --- | --- |
| **Sign on crew** | Pick someone standing within three tiles of the wheel and give them a role: captain, helmsman, engineer, gunner or hand |
| **Change a role or strike off** | Change a listed crew member's role or remove them |
| **Who may join** | Anyone may sign on as a hand, new crew must ask, or she takes no new crew (the default) |
| **Answer a request** | Accept or refuse someone who asked to join |
| **Bar someone** / **Lift a bar** | A barred person leaves the crew and cannot ask to join |
| **Write the memo** | A note every crew member can read in the papers |
| **Give up the ship** | Owners only: strikes her from the register so anyone may sail or register her |

Someone who is not crew sees who owns her and can choose **Ask to join** when she is taking crew. The papers are kept with the ship.

### Fuel

The bunkers hold **1000 units** of fuel oil and every hop burns **2 units per telegraph step**: 6 at full ahead, so a full load is about 170 hops at full speed. Pour **diesel** or **petroleum** from any container into the **bunker filling point** in the fuel bunker compartment on the hangar deck; other liquids stay in the container. Examine the valve or read the chart for the level. A dry ship will not take a speed at the wheel until it is bunkered again.

## Flying from the deck

The flight deck is a runway, so the [usual rules](Guide_to_Aircraft.md#flying) apply with a few differences:

- **Take-off:** line up along the deck with 8 clear tiles ahead at full throttle. Keep to the port side of the deck: the island stands on the level you climb into, and a plane lined up under it is refused its climb until it rolls clear.
- **Catapult:** taxi the plane fully onto the catapult track at the bow, nose to the bow, with the engine running, and pull the **catapult lever** beside it. The plane is thrown straight into the air above the bow at full speed, with no deck roll, so the rest of the deck can stay parked up. The lever tells you why it refuses: a plane with a wheel off the track, pointed across the deck, with a cold engine, or something in the air above it.
- **Landing:** fly down the deck in low flight at second gear or slower and **Descend** over the after deck. A plane that touches down on the **arresting wires** is caught by its tailhook and stops at once. One that lands beyond them rolls on at taxi speed, and the **crash barrier** stops it at the deck edge instead of letting it roll into the sea.
- **Elevators:** taxi the plane fully onto one of the 4x4 platforms, switch off, and pull the **lever** beside it. The platform takes the plane and anything else on it down to the hangar; the lever in the hangar brings it back up. The elevator refuses a plane that is half on the platform or still rolling, and a blocked hangar floor below.
- **Gun tubs:** the four corner sponsons are not runway and the crash barrier keeps planes off them. Stay clear of them when lining up.
- **Arming:** [arm the planes](Guide_to_Aircraft.md#arming-the-plane) on the hangar deck or the flight deck: bolt a light machine gun into the nose and hang a filled bomb under each wing. The **bomb racks** in the magazine compartment hold the bombs between sorties; click a rack to open it.
- **Hops:** parked planes, crew and cargo ride every hop with the deck. A plane in the air over the ship does not, so land before the ship moves far.

## Radar and lights

- **Radar:** click the **radar set** on the island to sweep 40 tiles around the ship. It lists every ship, other carrier, player-built hull and aircraft in range with its distance, bearing and heading, whether it is stopped, and whether a plane flies low or high. Examining the set tells you how many contacts are on the screen. A ship running dark shows as an unknown contact. The ship herself is left out.
- **Searchlights:** the two searchlights on the island work like [searchlights ashore](Guide_to_Construction.md#lighting): click one to switch it on, and turn it a quarter turn from its right-click menu, to light the deck and the water alongside at night.
- **Deck lights:** sixteen low lamps along the deck edges, switched together from the ship's wheel. Switch them off when you do not want the ship seen at night.

## Damage control

The carrier is hurt the way a [Submarine Commander](../gamemodes/subcom.md) boat is, and the same tools mend it.

- **Flight deck:** a shell or bomb that bursts on the deck **craters** the plating. A crater is not runway: a plane cannot take off over it and the wires do not count where it lies, so weld the crater shut with a **welding tool** before the next landing. Craters move with the ship. The island deck craters the same way.
- **Hull:** blasts against the hull below the waterline crack it, and a heavy one **breaches** it. Seawater pours through a breach into that compartment. Close the **blast door** on the bulkhead to keep the water in one compartment, wedge the breach to a seep with a **shoring kit**, and **weld** it shut with a welding tool; welding takes a while, so start early. Bulkheads buckle under heavy blasts and leak until welded.
- **Magazine:** a heavy blast that reaches a bomb rack sets off every filled bomb in it, and the burst cracks the hull beside the magazine. Keep the magazine's blast door shut, fill bombs only when they are about to be hung, and do not store them anywhere else aboard.
- **Fire:** a blast on the hangar deck sets the deck alight. Fire spreads along the deck, hurts anyone standing in it and burns out on its own after a while; water over the deck puts it out.
- **Listing:** read the chart at the wheel. Every compartment that is flooded to the deckhead takes one telegraph step off the ship: with one flooded she makes half ahead at most, with two only slow ahead. Pump a compartment out and the list eases.
- **Sinking:** with **three** compartments flooded the ship goes down. Everyone aboard ends up in the sea where the decks were, loose cargo floats with them, and the wheel, the elevators and any aircraft aboard are lost. Five pieces of wreckage mark the spot. Abandon ship before the third compartment fills, or close the doors and pump.

## Tips

- Drop anchor before flying operations: a hop in the middle of a landing roll moves the deck under the plane.
- Keep diesel aboard. The bunker filling point is in the fuel bunker, the second compartment from the stern.
- The carrier survives world saves where it lies, with its fuel, heading, telegraph and damage. Planes left on the deck are saved on it.
