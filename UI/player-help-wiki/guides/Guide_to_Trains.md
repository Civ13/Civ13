# Trains

Rails and steam trains move people, fuel and cargo along a fixed track. The parts are made from the crafting menu's **trains** section, mostly from iron, once your faction has the research. Track itself is laid by hand, one tile at a time.

## Research

| Mode | Rails, rail switchers, rotator platform, lever | Steam locomotive, tender, cabin, flatbed and transport wagons |
| --- | --- | --- |
| [Tech tree](Guide_to_Research.md) | **Rail & Steam** node (Vehicles line) | Industrial research **101** |
| [Legacy research](../gamemodes/Civilizations_and_Nomads.md#research) | Industrial research **93** | Industrial research **101** |

The wooden mining cart needs Industrial research **93** in either mode.

A wooden wagonway comes earlier (see [Early rails](#early-rails)): railway sleepers, wooden rails and the chaldron wagon need the **Wagons & Ships** node, or Industrial research **22**.

Overhead line masts, the electric locomotive and the tram (see [Electric railways](#electric-railways)) need the **Electricity** node, or Industrial research **105**.

Platform car kits (see [Platform cars](#platform-cars)):

| Mode | Platform car, passenger coach | Sleeper, dining and storage cars |
| --- | --- | --- |
| [Tech tree](Guide_to_Research.md) | **Rail & Steam** node | **Assembly Line** node |
| [Legacy research](../gamemodes/Civilizations_and_Nomads.md#research) | Industrial research **101** | Industrial research **140** |

Wartime cars (see [Wartime cars](#wartime-cars)):

| Mode | Railway gun car, armored locomotive | Armored wagon, flak car |
| --- | --- | --- |
| [Tech tree](Guide_to_Research.md) | **Field Artillery** node | **Automatic Weapons** node |
| [Legacy research](../gamemodes/Civilizations_and_Nomads.md#research) | Industrial **101** and military **109** | Industrial **101** and military **125** |

## What you can build

| Piece | Cost | Notes |
| --- | --- | --- |
| Railway sleepers | 1 wood | The wooden ties for one tile of track. |
| Rails | 1 iron | A pair of rails for one tile of track. A [rolling mill](Guide_to_Metallurgy.md#rolling-mill) makes two pairs from one iron, or three from one steel. |
| Wooden rails | 2 wood | A pair of timber rails for one tile of wagonway. No good under an engine (see [Early rails](#early-rails)). |
| Rail switcher (to left or right) | 2 iron | A junction that a lever can switch between going straight and turning off. |
| Rail rotator platform | 3 iron | Turns whatever wagon is standing on it. |
| Turntable | 20 iron | Turns a whole engine or car on a bridge over a pit (see [Turntables](#turntables)). |
| Large turntable | 40 iron | A turntable long enough for a main-line engine with its tender. |
| Train lever | 1 iron | Flips every switcher within two tiles. |
| Mining cart | 10 soft wood | Small storage cart (7 slots). |
| Steam locomotive | 18 iron | The engine. Burns coal or wood. |
| Coal tender | 6 iron | Small fuel wagon (15 slots) for coal, wood planks and branches, with a little water. A fireman shovels from it. |
| Tender kit | 24 iron | Builds a full-size tender with far more coal and water (see [Tenders and water stops](#tenders-and-water-stops)). |
| Water tower | 30 wood | Holds water beside the track and fills engines and tenders. |
| Water crane | 8 iron | A standpipe that fills engines and tenders from a water tower nearby. |
| Fusible plug | 1 lead | Spare safety plug for a steam locomotive's boiler. |
| Train coupling | 4 iron | Spare coupling for a car end. |
| Brake wheel | 6 iron | A handbrake you can work while the train is moving. Bolt it to the deck of a platform car (see [Brakes](#brakes)). |
| Cabin wagon | 4 iron | A covered seat for the driver or passengers. |
| Flatbed wagon | 4 iron | Carries people, crates and structures. |
| Transport wagon | 5 iron | A covered storage wagon (8 slots). |
| Rail warehouse office | 15 iron | Stores cars and whole trains (see [Rail warehouse](#rail-warehouse)). |

Switchers, rotators, levers and wagons are placed facing the way **you** face, so stand looking along the line before you build them. Plain track shapes itself (see below).

A **crowbar** takes a mining cart, small locomotive, coal tender, hand car or wagon apart again and gives back half of what it cost. It must be stopped, uncoupled and empty, with nobody buckled to it and no animal in harness, and a locomotive must be shut down first. A locomotive's fuel and water are lost.

## Laying track

Each tile of track is built in three steps:

1. **Sleepers.** Use the railway sleepers on the tile next to you, or use them in your hand to lay them on the tile in front of you. The ground must be firm, dry and clear.
2. **Rails.** Use the rails on the sleepers.
3. **Spikes.** Hit the rails with a **hammer** to spike them down. Only now is the tile track that trains can run on.

You never choose which way a tile points. It lines up with the track around it:

- A line carries on straight. Keep laying tiles ahead of the last one.
- For a corner, lay the line one tile past where it should turn, then lay the next tile to the side. The end of the line bends into a curve to meet it, even if it was already spiked.
- A tile on its own runs the way you face while laying it.
- **Leave room between bends.** Railway cars are long and take a corner one section at a time, so two corners close together would fold a car in half. The hammer won't spike down a corner fewer than **four tiles** from the next corner along the line. Under **eight tiles** you're warned: four-tile cars and engines manage it, but long bogie cars and main-line engines need eight. One-tile wagons and mine carts take any corner.
- Tiles in the middle of a line never change, so a new line can run right alongside an old one. Build the main line first, then sidings and branches beside it.

Use switchers for branches and a lever within two tiles of each switcher you want to control. A switcher set to split moves a wagon sideways onto the track beside it, so lay that track first; with nothing there the wagon carries straight on. Put a **rotator platform** at the end of a line or in a yard to turn wagons around. Click it to rotate it a quarter turn, or right-click it for **Rotate Left** and **Rotate Right**.

Keep the track clear. A moving train stops when it hits anything solid, and it smashes what it hits.

### Wide curves

A sharp corner is slow: trains take it at no more than about 110 km/h. Easing it into a **wide curve** lets them keep up speed, and long cars sweep round it smoothly.

1. Lay the corner as usual, with plain straight track running on from it on both sides: **four tiles** each side for a gentle curve, **eight** for a wide one. Leave the ground inside the corner clear.
2. Hold a **hammer**, right-click the corner and choose **Ease the Curve**, then pick the size.
3. The corner and the straights beside it are lifted and relaid as one curve. It uses the same number of tiles, so you gain and lose no rail.

| Curve | Straight track needed each side | Fastest safe speed |
| --- | --- | --- |
| Sharp corner | none | about 110 km/h |
| Gentle (4) | 4 tiles | about 145 km/h |
| Wide (8) | 8 tiles | about 220 km/h |

Corners eased into curves don't count as corners for the spacing rule. A **crowbar** on a curve relays it as the sharp corner and its straights again. Pry those again to take them apart. Nothing is relaid while a wagon stands on it.

### Planning a line

A [ship's draught](Guide_to_Boats.md#ships-draughts) (1 wood, Papermaking) can hold a **rail plan**. Drawing one costs nothing and lays nothing: it shows you where the hammer will refuse to spike track before you spend any rails.

- Hold a blank ship's draught with a pen, pencil or pigment in your other hand. Use the sheet and choose **Draw a railway on the sheet**. The window shows a 40 by 40 tile sheet, north to the top.
- With **Track**, click or drag to draw the line tile by tile. Where it turns a right angle it makes a sharp corner. **Erase**, or a right-click with any tool, lifts track.
- With **Ease curve**, click a corner to mark it as a gentle (4) or wide (8) curve. The curve is drawn where it will lie.
- The **Checks** panel lists what is wrong:
  - corners fewer than four tiles apart (an error), or fewer than eight (a warning);
  - curves without their straight track or without room to lie;
  - places where lines meet. There you lay a switch by hand.
  Click a finding to ring its tiles. The figures count the tiles, sleepers and rails you'll need.
- **Save to the sheet** keeps the plan. **Export code** and **Import code** share it as a design code. See [Sharing plans as design codes](Guide_to_Boats.md#sharing-plans-as-design-codes).
- **Pegging it out:** stand where the south-west corner of the drawing should go. Use the rail plan and choose **Peg it out on the ground**. Every tile of the line gets a builder's peg, and a peg comes up by itself once finished track lies on its tile. A corner to be eased carries a note saying how wide a curve to make. Pull that peg yourself once the curve is in. **Pull up the pegs and forget the site** takes every peg up.

### Taking track apart

A **crowbar** takes track apart one step at a time, giving the parts back: first it pulls the spikes (the rails sit loose on their sleepers again), then it lifts the rails off, then it pries up the sleepers. Switchers and rotators come apart in one go and return their iron. Nothing comes apart while a wagon stands on the tile. If a tile turned the wrong way, pry it up and lay it again.

### Track wear and platelaying

![Three stretches of track: in good order, worn with weeds between the rails, and in a bad way with split sleepers](../images/civ13-train-trackwear.png)

Trains wear the track they run on. Heavy trains wear it faster, fast trains faster still, and curves and switches wear twice as fast as straight track. A line nobody uses stays as it is.

| Track | How you tell | What it means |
| --- | --- | --- |
| Good order | Nothing to see. | Any speed the rest of the line allows. |
| Getting rough | The cab is told the engine rides rough. | A warning only. Pack it soon. |
| Worn | Weeds and sunk patches between the rails; the cab is warned. | Keep under about 180 km/h on the cab's speed readout, or the train [leaves the rails](#leaving-the-rails). |
| In a bad way | Split sleepers as well; the cab is warned. | Keep under about 70 km/h, a crawl. |

Examine any piece of track to see how it stands.

**Keeping it up.** This is the platelayer's job, and on a long line it is work for a gang.

- Use a **hammer** on rough or worn track to pack the sleepers and drive the spikes home. It takes a few seconds a tile. One round puts rough track right; worn track may want two.
- Track in a bad way won't hold packing. Use a set of **railway sleepers** on it to put new ones in: that tile is then as good as new. Sleepers work on worn track too.
- Neither can be done while a train stands on the tile.

## Bridges over water

Track needs firm ground, so to cross a river, lake or the open sea you first build a bridge and then lay the track on it the same way as on land.

| Span | Cost | Tech tree | Legacy research |
| --- | --- | --- | --- |
| Timber pier span | 8 wood | **Imperial Architecture** node | Industrial research **70** |
| Steel bridge span | 4 steel | **Reinforced Concrete** node | Industrial research **96** |
| Concrete bridge span | 6 concrete blocks | **Reinforced Concrete** node | Industrial research **103** |

Each span covers one tile of water. Steel and concrete spans cross the deep sea too; a timber pier span only stands in shallow water:

1. Stand on the shore, in the shallows or at the end of the bridge built so far, facing the water. You can't build while swimming or from a boat.
2. Use the span in your hand to build on the tile in front of you, or use it on the water tile next to you.
3. Keep going tile by tile. You can walk, drive and craft on the deck. Steel and concrete decks don't sink or burn; a timber deck doesn't sink either, but it is much weaker.

#### Timber piers and the pile driver

A timber pier span needs its log piles driven into the bed, so it only goes down on **shallow water** within **two tiles of a pile driver**. Deep water takes a steel or concrete span.

| | Station | Cost | Tech tree |
| --- | --- | --- | --- |
| <img src="../images/Pile_driver.png"> | **Pile driver** | 14 wood | **Imperial Architecture** node |

1. Build the pile driver at the water's edge and make sure it is fastened (use a wrench).
2. Lay timber pier spans on shallow water within two tiles of it, the same way as any other span.
3. To go further out, unfasten the driver with a wrench, pull it onto the new deck and fasten it again.

The pile driver can stand on the shore, in the shallows or on a deck. Hit it with a hammer on **Harm intent** to take it apart.

Lay sleepers, rails and spikes on the deck as usual. Track on a bridge joins the rest of the line, so a bridge can carry a line to a station or to the edge of the map. You can also build a road on the deck for cars.

Ships can't pass a bridge. To take a span down again, clear the track, road, vehicles and people off it and hit it with a **hammer**. You get the span back. If a bridge is destroyed by an explosion, any track on that tile falls into the water.

## Early rails

You don't need steam to use a railway. A wagon on rails rolls so easily that one horse can draw a whole string of them, and a small car can be pumped along by hand.

![A hand car on iron track, seen from the side and from the end, and a string of three chaldron wagons on a wooden wagonway](../images/civ13-train-early-rails.png)

### Wooden wagonway

**Wooden rails** (2 wood) are laid exactly like iron ones: sleepers first, wooden rails on top, then spike them down with a hammer (see [Laying track](#laying-track)). The finished track is brown and is called a wagonway. A crowbar takes it up again and gives the timber back.

- Hand cars and wagons drawn by animals **do a wagonway no harm**, however often they run.
- **An engine ruins it.** A locomotive wears wooden rails eight times as fast as iron, so a wagonway is rough after a few trains and soon not safe at any speed (see [Track wear and platelaying](#track-wear-and-platelaying)). Relay the line in iron before you put steam on it.
- Wooden and iron track join end to end, so a line can be relaid in iron a tile at a time.

The **chaldron wagon** (12 wood) is the wagon for it: a light wooden wagon with ten spaces for cargo. Couple a string of them like any other wagons.

### Drawing a train with a horse or an ox

A horse or an ox can draw any train that has no engine on it.

1. Bring the animal next to the wagon at **one end** of the train.
2. **Drag the wagon onto the animal**, or right-click the wagon and choose **Harness Animal**. It takes a few seconds.
3. **Lead or ride the animal along the track.** Each time it gets ahead, the train rolls one tile after it. The train stops when the animal stops.
4. To go back the other way, take the animal out of the traces (**Harness Animal** again), walk it round to the other end and harness it there.

- A **horse** draws a train of up to **8** in weight, an **ox** up to **4**. An empty one-tile wagon weighs 1 and a chaldron wagon a little over half that; cargo and riders add to it. A starving animal draws half as much.
- The heavier the train, the slower a ridden animal goes.
- **Let every handbrake off first.** The animal comes out of the traces if a brake is on, if it walks more than two tiles away or off the line, or if the train has become too heavy.
- An animal can't pull a cart and a train at once, and harnesses don't last through a server restart: harness it again afterwards.

### Hand car

A **hand car** (6 iron, **Rail & Steam** node or Industrial research **101**) is a small one-tile car with a pump beam, for inspecting the line or getting a couple of people down it without raising steam.

1. Put it on the track and **climb on**: drag yourself onto it.
2. **Face the way you want to go** and click the car to pump. Each click is one stroke.
3. **Keep pumping.** The car rolls on by itself between strokes but slows down, so it needs a stroke every second or two to keep its speed.
4. **To slow down, face the other way and pump.** A few strokes stop it. To leave it standing, right-click it and pin down its **Handbrake**.

- **Two riders pumping go half as fast again** as one.
- It can tow a light wagon, but not much: more than 4 in weight, riders included, and it won't move.
- It is a rail vehicle like any other. It hits what is in its way, and a train will hit it, so keep off a line that engines are using or agree it with the [signalman](#signals-and-single-lines).

## Fuel

Click the locomotive with fuel to load its combustion chamber, which holds 100 units. The big steam engines are fired from the firebox door in the cab (see [Cab crew](#cab-crew)).

| Fuel | Units per piece |
| --- | --- |
| Coal | 15 |
| Wood planks | 3 |
| Branch | 3 |

If a stack would overfill the chamber, it is refused, so split it into a smaller stack. Examine the locomotive to see how full it is ("full", "sufficiently fueled", "stable", "emptying", "almost empty"). When the fuel runs out, the engine stalls and the train rolls on until it slows to a stop.

How much fuel a tile takes depends on the throttle and the load. Idling along costs a quarter of a unit, and full throttle with a fully loaded train costs one unit. An overloaded train costs more. That is about a hundred tiles of hard running per full chamber.

For long routes couple a **tender** next to the engine and shovel from it as you go (see [Tenders and water stops](#tenders-and-water-stops)).

## Steam, water and the boiler

A steam locomotive runs on **steam pressure**, made by boiling water over the fire. Click the engine to see its gauges: the fire, the **pressure**, the **water in the glass** (the boiler itself) and the **tank**. Diesel engines have none of this.

- **Raising steam.** A new engine comes filled and in steam. One that has stood with its fire out goes cold in about twenty minutes. Light the fire and wait: from cold it takes about two minutes to reach full pressure, four on a heavy locomotive. A firebox less than half full makes steam more slowly.
- **Pressure is power.** From 60% up the engine gives everything it has. Below that it gets slower, and under 15% the throttle won't open at all.
- **Don't wind the engine.** A train at the engine's rated load holds its pressure at full throttle. A heavier train uses steam faster than the fire makes it, so the pressure sinks and the train slows. Ease the throttle down a notch and let it recover.
- **Keep the fire up.** With the firebox under half full the pressure falls as you run. A lit fire also burns a little fuel while the engine stands, so drop the fire if you park it for long.
- **Water.** Working boils the water away. The **injector**, one of the engine's controls, feeds the boiler from the tank as you go and is on to start with. It costs a little steam, so a fireman can turn it off on a hard pull and back on when the driver eases off. Fill the tank by clicking the engine with a bucket or any open vessel of water. A tank lasts about 240 tiles of hard running, a heavy locomotive's about 600.
- **Never let the boiler run dry.** Everyone nearby is warned when the water is low in the glass. If it runs out with the fire lit, the **fusible plug** melts: steam puts the fire out and the engine is dead where it stands. Nothing explodes. Make a new **fusible plug** (1 lead; **Rail & Steam** node, or industrial research **101**), click the engine with it, then pour in water before you light the fire again. With the engine cold, water goes into the boiler first and then the tank.

## Tenders and water stops

A tender carries the coal and water an engine can't. It must be coupled **directly to the engine**, in front of it or behind it.

![A steam locomotive and its tender standing under a water tower, with an open wagon behind and a water crane further along the line](../images/civ13-train-water-stop.png)

- **Coal tender**: the small one-tile wagon. Its fuel is whatever coal and wood is in its storage, and it carries a little water.
- **Tender**: built from a **tender kit** on four tiles of straight track, like a platform car. It has a plate at the front to stand on, a coal bunker and a water tank, and holds as much as fifteen fireboxes of fuel and ten engine tanks of water. Click any part of it with coal, wood or a bucket of water to load it. Examine it to see how full it is.

**Nothing feeds the fire for you.** Click the engine with a **shovel** in your hand, standing at the firebox door on the big engines, to throw a load of fuel from the tender into the firebox. Each stroke is about two pieces of coal and you can shovel about once a second, on a moving train too. That is the fireman's job. You can still put fuel in by hand.

The tender's **water** runs to the engine by itself.

To fill up at the trackside:

1. Build a **water tower** next to the line, close enough that the track is within three tiles of it.
2. Fill the tower. Pour buckets of water into it, or build it within two tiles of fresh water and click it with an empty hand to work its pump. It holds a great deal.
3. Stop the engine or tender beside the tower and click the tower with an empty hand. Everything within reach is filled.
4. A **water crane** does the same anywhere within twelve tiles of a tower. Stand it within two tiles of the track. A wrench turns it.

## Building a train

1. Place the locomotive on the rail, facing the way you want to go.
2. Place each wagon on the rail behind it. Wagons, cars and engines can face either way along the track: a car coupled in back to front keeps facing the way it does and simply runs tail first.
3. Right-click a wagon and choose **Hitch** to couple it to the wagon in front of it, or to the wagon behind it if there is nothing in front. Use **Hitch** again to uncouple it. Hitched wagons follow the one ahead.

The locomotive doesn't have to be at the front. Hitched in behind wagons it **pushes** them, and in the middle of a train it drives the wagons on both sides of it.

### Building a whole train at a rail works

Instead of assembling every car from its own kit, you can draw the whole train on paper and have a **rail works** build it in one go, coupled and furnished.

![The train designer: the train as a strip of cars at the top, stock cars to add on the left, the plan of a drawn car in the middle, and the part description and checks on the right](../images/civ13-train-designer.png)

1. **Draw the train.** Hold a blank **ship's draught** and a pen or pencil, use the draught and choose **Draw a train on the sheet**. Add cars from the front: any locomotive, tender or car that has a kit, or a **drawn car** of your own. A drawn car is three tiles wide and four or eight long: pick its floor and roof, put a wall, window, door, railing or other side along each outer edge, close its ends, and stand a fitting on any tile (seats, berths, booths, tables, a stove, sink or fridge, cabinets, crates, a brake wheel, an ice bunker and cold lockers). Click any part to read what it is, what it is for and how it is made. The checks list what would stop the train being built or make it run badly, and **Save to the sheet** keeps it. A train can have up to 16 cars and 120 tiles.
2. **Build the rail works** (30 iron; **Rail & Steam**) facing the track, with **one tile between it and the rails**, like a rail warehouse office.
3. **Stock it** with iron, steel, wood, glass and cloth. Each stock car costs what its kit costs; a drawn car costs its frame (12 iron, or 22 for an eight-tile car) plus every floor, roof, side and fitting drawn on it.
4. **Use the train sheet on the works** and choose which way along the track the train should head. Its front car is built on the rail tile in front of the works and the rest of the train behind it, so you need that much **straight track** with a **clear tile either side** all along it. The works also needs the research for every car on the sheet.

The train comes out coupled up, with its engines cold and empty: fuel and water them before driving. A drawn car behaves like any other car: it can be taken apart into a kit, stored in a rail warehouse and put back together.

To copy a train, stand it on the track in front of the works, hold a blank sheet of paper and use the works: **Draw the train on the track** draws it onto the sheet. Train sheets export and import as design codes like every other plan, from the sheet menu or with **Export code** and **Import code** in the window (see [Sharing plans as design codes](Guide_to_Boats.md#sharing-plans-as-design-codes)).

## Couplings

Every wagon, car and engine has a **coupling** at each end. You can see it on the end of the car: a hook with its link hanging free, or a brass screw drawn tight between two hitched cars.

![A train with made couplings between its cars, a broken coupling on the last car, and a car standing apart with one coupling taken off and a spare on the ground](../images/civ13-train-couplings.png)

| You want to | Do this, standing next to the coupling |
| --- | --- |
| Couple two cars | Click the coupling with an empty hand. The cars must stand end to end. |
| Uncouple | Click it with an empty hand and wait a moment. It won't come undone while an engine is pulling: shut the throttle first. |
| Check it | Shift-click it. |
| Break it | Hit it with a weapon on harm intent. Each blow wears it down. |
| Mend it | Use a welding tool on it. |
| Take it off | Uncouple it, then use a wrench on it. You get the coupling as an item. |
| Fit one | Click the empty end with a **train coupling** in your hand. Spares cost 4 iron (**Rail & Steam** node, or industrial research **101**). |

Right-click, **Hitch** still works too.

- A **broken coupling parts the train**. The engine runs on with whatever is still hitched to it, and the rest is left standing on the line.
- Two cars couple only if **both** couplings that meet are whole. A car with a broken or missing coupling can still be hitched by its other end.
- Explosions damage the couplings of the cars they catch.

### Shunting

Making up a train is called shunting, and a yard does it all day.

- **Come up slowly and you buffer up.** A train that creeps up to standing cars at a crawl stops against them, and nothing is damaged. Open the throttle one notch, then close it and let the train roll the last few tiles. Faster than a crawl it is a bump, and faster still the cars are knocked rolling (see [Runaway cars](#runaway-cars)).
- **Then couple by hand**, or let automatic couplers do it.

#### Automatic couplers

An **automatic coupler** is a steel knuckle that takes the place of the hook and screw link. It costs 6 steel (**Assembly Line** node, or industrial research **140**).

![A train joined by automatic couplers, a broken one on the last car, a car standing apart with its couplers open, and a spare on the ground](../images/civ13-train-automatic-couplers.png)

- **Fitting one**: click the free end of a car with the coupler in your hand. It changes places with the coupling that was there, which drops at your feet. It wears, breaks, mends and comes off like any coupling.
- **They lock by themselves.** Push two automatic couplers together slowly and they couple, and the train stops there. Nobody has to stand between the cars. Too fast and they do not catch: the cars are knocked away instead.
- **Rolling cars couple too.** A car let go down a siding locks onto the cars it rolls up against.
- **The lever lets go at once.** Click a locked automatic coupler and the cars part straight away, with no wait. It still won't let go while an engine is pulling. On a coasting train the cars you let go roll on by themselves, which is how a shunter sends cars into a siding without stopping.
- Both ends that meet must be automatic. An automatic coupler and a hook and screw link still couple, but only by hand.

## Driving

**Click the locomotive** to open its controls. On the big steam engines the controls are shared between three places in the cab (see [Cab crew](#cab-crew)).

- **Start the engine** or **Stop the engine**. On a steam locomotive these are **Light the fire** and **Drop the fire**. It needs fuel to start, and a steam locomotive needs water in its boiler.
- **Injector on** or **Injector off**, on steam locomotives. See [Steam, water and the boiler](#steam-water-and-the-boiler).
- **Throttle up** and **Throttle down** move between notches 0 and 3. Each notch is a third of the engine's top speed. A train creeps away and gathers speed gradually: a light steam train takes about ten seconds to reach full speed, and a train at its engine's full load about twice as long.
- **Brake** closes the throttle and puts the engine's own brake on. It holds the engine only, so a long train also needs its handbrakes (see [Brakes](#brakes)). Closing the throttle without braking lets the train coast.
- **Sand the rails** drops sand under the wheels for the next few tiles so they grip (see [Wheel slip and sand](#wheel-slip-and-sand)).
- **Reverser** sets forward or backward, and only works while the train is standing. Forward is always the way **that engine** faces, wherever it is in the train. Backing up moves the train with the far end leading. Set the levers for the way that end of the train will go.

Examine the locomotive to see its notch, reverser, speed, a steam locomotive's pressure and water, and whether the train is too heavy for it.

### Speed, load and stopping

- A steam locomotive at full throttle is faster than a carriage or any tank, about as fast as a running person. The armored locomotive is a little slower.
- Every wagon and car adds weight, and so does what it carries: people, cargo, stored items and furniture. A locomotive pulls its own rated load at full speed. Over that, the train is slower, and a train far too heavy for its engine won't start at all: the wheels just spin.
- **Two engines** make a heavier train fast again. Hitch a second running locomotive anywhere in the train, at the front, in the middle or pushing at the back. It adds its pull and burns its own fuel. The engine whose throttle was opened first drives the train; the other's controls take over once it has stopped.
- **What leads the train sets its top speed.** A locomotive running forward at the head gets full speed. A locomotive running backward gets three quarters. Wagons pushed ahead of the engine, forward or backing up, get half, unless a running locomotive is at their head.
- **An engine at each end**, each facing out, lets a train run at full speed both ways without turning anything round. Drive from the engine that faces the way you want to go.
- **Trains don't stop on the spot.** A train loses speed gradually: an engine on its own brakes to a stand in a few tiles, a long, heavy train needs many more, and a coasting train rolls a long way. Start braking well before a station or a junction.

### Wheel slip and sand

An engine can only pull as hard as its wheels grip the rails. Open the throttle too far on a heavy train that is standing or crawling and the wheels spin: you are told they are slipping, the train gains no speed, and the engine burns fuel for nothing.

- **Start a heavy train gently.** A train near its engine's full load starts on notch 2 and takes notch 3 once it is rolling. A train much too heavy for its engine has to start on notch 1. A light engine or a short train never slips.
- **Rain and snow make the rails slippery.** In wet weather use a notch lower than you would in the dry.
- **Sand the rails** when you need the grip: the wheels hold for the next eight tiles, which is enough to get a heavy train moving. Once the train is rolling at a fair speed it no longer slips.
- **The sandbox holds 20 uses.** The engine's controls show how many are left. Use **sand** on the locomotive to fill it up again.

### Snow on the line

Snow that falls and settles on the track slows a train. The car at the front pushes into it, and the train keeps to **three quarters** of its speed in light snow and **half** in deep snow until it is back on clear track.

![A snowplough on the front of a steam engine heading east and one heading north, and a snowplough standing on the ground](../images/civ13-train-snowplough.png)

A **snowplough** (10 iron, on the **Rail & Steam** node or industrial research **101**) clears the snow off each tile as the train passes, so the train keeps its speed and the line behind it is open for the next one.

- **To fit it**, stop the train and click the **coupling** at a free end of an engine or car with the snowplough.
- **It only works at the end that leads the train.** Fit it to the front of the engine for running forward. A train that backs up a long way wants one on its last car as well.
- **To take it off**, click that coupling with a **wrench**.

### Runaway cars

Cars keep rolling. Nothing stops a wagon just because it is no longer coupled to an engine.

- **A train that parts on the move leaves cars rolling.** If a coupling breaks while the train is running, or someone uncouples a car while the train coasts, the part without the engine rolls on by itself the way it was going. It slows down over many tiles, sooner if it is light.
- **Hit standing cars and they roll away.** Run into cars at more than a crawl and they are knocked rolling down the line, unless a handbrake holds them. To couple up, pin down a handbrake on the cars first, or come up to them very slowly.
- **A runaway hits whatever is in its way** like any other train, and at speed that is a crash.
- **Stopping one takes a brake wheel.** A handbrake cannot be pinned down from the ground on a moving car. Someone riding a runaway can wind a brake wheel on, which is one more reason to keep a brake van on the back of the train.

### Brakes

A train stops by how much of its weight is braked. The driver's **Brake** grips the engine and nothing else. That stops a lone engine quickly, but with a dozen cars pushing from behind, the engine's brake is a small part of the train and the stop is long. The rest of the braking is on the cars.

- **Every wagon and car has a handbrake.** Right-click the car and choose **Handbrake** to pin it down or let it off. It takes a couple of seconds, you must be next to the car, and it only works while the train is **standing**. Examining a car tells you when its handbrake is on.
- **A brake wheel works on the move.** Click a brake wheel to wind the brake of the car it stands on hard on, and click again to wind it off. Its tell-tale shows red when the brake is on and green when it is off.
- **The more weight is braked, the shorter the stop.** With every car braked, a train stops about as fast as an engine on its own.
- **Braking always beats speeding up.** Even with only the engine's brake on, a train loses speed at least twice as fast as it can gather it, so it stops in well under the time it took to get up to speed.
- **Let the brakes off before you leave.** A handbrake left on drags like several extra cars: the train is slow, and with enough of them on it won't start at all. The engine's controls list how many handbrakes are on in the train.
- **Park with a handbrake on.** A train with any handbrake on cannot be pushed along the line by hand.

#### Brake van

The **brake van** is the guard's car. It has an open veranda at the front and a cabin behind it with a **brake wheel** and a seat. It is built heavy, about twice the weight of an ordinary car, so its brake holds twice as much. Couple one at the back of a train and put a guard in it: when the driver brakes, the guard winds the wheel on, and winds it off again before the train starts.

![A goods train seen from above with a red-roofed brake van at the back, the van with its roof off showing the brake wheel in the cabin, and close views of the wheel wound off with a green tell-tale and wound on with a red one](../images/civ13-brake-van.png)

| Piece | Cost | What you get |
| --- | --- | --- |
| Brake van kit | 24 iron | A four-tile guard's van with a veranda, a cabin, a brake wheel and a seat. Built like any other car kit (see [Putting a car together](#putting-a-car-together)). |
| Brake wheel | 6 iron | A brake wheel on its own. Build it on the deck of any platform car to give that car a brake a rider can work on the move. A **wrench** unbolts it, once its brake is off, so it can be dragged away. |

A long train can carry more than one: a van at the back, and a brake wheel on a car or two further up for extra hands.

### The conductor

A long train needs somebody in charge behind the engine. The conductor, or guard, rides at the back and works with four tools, all from the **Rail & Steam** node.

![The conductor's things: a black guard's journal with a pencil, a steel carriage key, a red ticket book, a ticket, a punched ticket, a ticket punch and a pair of red and green signal flags](../images/civ13-train-conductor.png)

| Item | Cost | What it does |
| --- | --- | --- |
| Guard's journal | 1 leather | Use it in your hand aboard or beside a train. It lists the whole train from the front: how many vehicles, how long, its weight against what its engines can pull at full speed, and for each vehicle whether its engine is running, its handbrake is on, an axle box is dry, hot or seized, it is wrecked, or it has locked doors. |
| Carriage key | 1 iron | Use it on a closed car door to lock or unlock it. One key fits every car. |
| Ticket book | 1 leather | Use it in your hand to write out a ticket: where to, and the fare you were paid. A book holds 40 tickets. |
| Ticket punch | 1 iron | Use it on a ticket to punch it, so it can't be used twice. Examine a ticket to see where it is to, the fare, who wrote it and who punched it. |
| Pair of signal flags | 2 cloth | Use them in your hand and pick a signal. Everyone who can see you sees it, and so does everyone in a cab of the train you are on or beside, however long the train is. |

- **Before leaving**, walk the train with the journal. A handbrake left on, a hot axle box or a train too heavy for its engines all show up in the list.
- **Locked doors** keep people out of a mail van, a boxcar or a coach they have no ticket for. A locked door still opens by hand from its own tile inside the car, so nobody can be shut in, and that unlocks it. A **crowbar** forces a locked door from outside, slowly and noisily.
- **Tickets** are between players. Agree a fare, take it by hand, write the ticket and punch it on board.
- **Flag signals:** green held high is *right away*, red waved is *stop*, green waved slowly from side to side is *set back*, green held steady is *come on slowly*, and red waved hard above the head is *danger, stop at once*.

### Signals and single lines

Signals keep trains apart. They need people off the train: a signalman at the post or in a signal box, and somebody at each end of a single line. Everything here is from the **Rail & Steam** node.

![A semaphore signal at danger and at clear, a lever frame, a token instrument, a brass token, a section board and a coil of signal wire](../images/civ13-train-signals.png)

| Item | Cost | What it does |
| --- | --- | --- |
| Semaphore signal | 4 iron | A post beside the track with a red arm. Arm level is *danger*: stop. Arm lowered is *clear*. Click it with an empty hand to move the arm. |
| Lever frame | 10 iron | Works up to 8 signals and switch levers from one place, up to 40 tiles away. |
| Coil of signal wire | 2 iron | Joins signals and switch levers to a lever frame, and pairs token instruments. It is not used up. |
| Token instrument | 8 iron | One at each end of a single line. The pair gives out one token between them. |
| Section board | 3 wood | A board beside the track where a single line begins. |

**Placing signals.** Stand a signal or a board beside the track, on the first tile that a passing train's side leaves clear. Any further out and trains don't read it. Each speaks to trains running one way only: examine it to see which, and use a **wrench** on it to turn it.

**Reading them.** Everyone in a cab is told what a signal shows when the train comes within ten tiles of it. Nothing stops the train for you: the driver has to brake. A train that runs past a signal at danger is seen to do it by everyone nearby, the signal keeps count, and examining it shows how often.

**The signal box.** Use the signal wire on a lever frame, then on each signal and switch lever it is to work. Using the wire on one again takes it off. Click the frame with an empty hand and pick a lever to pull it; examine the frame to see how every lever stands.

- A signal or switch that is wired to a frame no longer moves by hand.
- Two signals that face each other along the same line can't both be clear, so the frame can't send two trains at each other.
- A switch can't be moved while a signal within ten tiles of it is clear. Put the signal back to danger first.
- If a train passes one of its signals at danger, a bell rings at the frame.

**Single lines.** Where trains run both ways on one track, work it by token.

1. Build a token instrument at each end. Use the signal wire on one and then on the other to pair them; they can be up to 150 tiles apart.
2. Build a section board at each end, facing trains about to enter the single line. Use the wire on an instrument and then on the board to mark it.
3. Click an instrument with an empty hand to draw the token and give it to the engine crew. While it is out, neither instrument gives another.
4. At the far end, use the token on the instrument there to put it back. The line is then free for the next train, in either direction.

A cab coming up to a section board is told whether the token is on the engine: in a crew member's pocket or hand, or lying on the engine's floor. A train that passes the board without it is seen to, and the board keeps count.

### Stations, whistle and lamps

![A white station name board on two posts, and a hand lamp shown out, white, red and green](../images/civ13-train-stations.png)

| Item | Cost | What it does |
| --- | --- | --- |
| Station name board | 4 wood | Stand it beside the track at a station, on the first tile a passing train's side leaves clear, and use a **pen** on it to write the station's name. Everybody aboard a train that comes within ten tiles of it, from either direction, is told where the train is coming into. |
| Hand lamp | 2 iron | Use it in your hand to turn the shade: white, red, green, then out. It lights the ground around you in that colour. |

Both are from the **Rail & Steam** node. A platform needs nothing special: car decks are level with the ground, so lay any floor you like beside the track.

**At the driver's stand** there are three more controls:

- **Sound the whistle** (a horn on diesels). The engine has to be running, and a steam engine needs steam. Players up to forty tiles away who can't see the engine are told which way the sound came from. Whistle before a crossing, before you start and when you come into a station.
- **Ring the bell.** A short-range warning for a yard or a station.
- **Light the headlamp** and **Put out the headlamp.** The headlamp throws a much wider light ahead of the engine while it moves.

**Running at night.** In the dark a train needs a light at its leading end, or it runs blind at half speed and the cab is told why.

- When an engine leads, light its headlamp.
- When cars are pushed ahead of the engine, have somebody stand on the leading car with a hand lamp showing **white**, or set the lamp down there.
- Hang a **red** hand lamp on the last car as a tail lamp: set it down on the deck or have the guard hold it. The guard's journal says whether the tail lamp is showing. A train that passes with no tail lamp may have left part of itself behind.
- Flags can't be seen in the dark, so the guard signals with the lamp: green held steady is *right away*, white swung across the body is *stop*, red is *danger*.

### Buffer stops and level crossings

Both are from the **Rail & Steam** node.

![A line ending at a red buffer stop, and a level crossing with boards between the rails and a white gate on the road two tiles out at each side, open to the road and then shut across it](../images/civ13-train-trackworks.png)

| Item | Cost | What it does |
| --- | --- | --- |
| Buffer stop | 4 iron | Ends a line. Build it on the last tile of rails; use a **wrench** to turn it. |
| Crossing boards | 2 wood | Boards between the rails where a road crosses. Build them on the rail tile; a wrench turns them. |
| Crossing gate | 4 wood | A gate across the road at a crossing. Build it two tiles from the rails. |

**Buffer stops.** A train brought up to a buffer stop slowly comes to rest against it, and nothing is hurt. It also holds a train that runs into it fairly hard, and examining the stop shows how many hard blows it has taken. A train that hits it at speed smashes it to scrap and is wrecked as in any [crash](#crashes); the rails stay, so build a new stop. Without a stop, a train that runs off the end of the rails at any speed above a crawl [leaves them](#leaving-the-rails).

**Level crossings.** Where a road crosses the line, lay crossing boards on the rail tile and build a gate on the road at each side, two tiles from the rails: leave one clear tile between the gate and the rails, because wide cars and big engines overhang the track by a tile each side and would hit a shut gate any nearer. Use a wrench on a gate until it faces the rails (examine it to check).

- Click a gate with an empty hand to swing the gates. All the gates within four tiles of each other move together.
- **Shut across the road**, a gate is solid: nobody walks or drives through it. **Open to the road**, it is out of the way. The gates don't stop trains either way.
- The gates won't shut while someone or something solid is standing in one of them.
- Everyone in a cab is told how the gates stand when the train comes within ten tiles of the crossing. A train that runs over a crossing with its gates open to the road is seen to do it, and the gate keeps count.

**From the signal box.** Use the [signal wire](#signals-and-single-lines) on a lever frame and then on one gate: the whole crossing is then worked by one lever, and no longer by hand. The frame locks it with its signals. A signal that stands up to 20 tiles before the crossing can't be put to clear while the gates are open to the road, and the gates can't be opened to the road while that signal is clear.

### Turntables

![A small turntable: a bridge of rails across a round brick pit with a line leading up to it, then turned a quarter away from that line](../images/civ13-train-turntable.png)

A turntable turns an engine to face the other way, or onto a line that leaves at a right angle. It is a pivot with a bridge of rails across a pit, pushed round by hand.

| Item | Cost | What it takes |
| --- | --- | --- |
| Turntable | 20 iron | Five tiles of bridge in a pit five tiles square: a heavy locomotive, a short car or a small engine with a wagon. |
| Large turntable | 40 iron | Eleven tiles of bridge in a pit eleven tiles square: a main-line engine with its tender, or a long car. |

Both are from the **Rail & Steam** node.

**Building one.**

1. Pick open, firm, dry ground with nothing solid and no track inside the square, and build the turntable on the middle tile.
2. Use a **wrench** on it to choose whether the bridge will lie north and south or east and west (examine it to check).
3. Click it with an empty hand to lay the bridge.
4. Lay your lines up to the edge of the pit, in line with the pivot. A line can come in on any of the four sides. Don't lay track inside the pit.

**Turning.**

1. Run the engine onto the bridge and stop. Everything coupled together has to be on the bridge, so uncouple what won't fit.
2. Click the pivot or any part of the bridge with an empty hand, from on the bridge or beside it, and choose a quarter turn to the left, a quarter turn to the right, or right round.
3. Wait while you push. A heavy engine takes longer than an empty bridge, and a second person standing at an end of the bridge halves the time.

- The crew can stay in the cab: people and cargo on the engine or on the bridge go round with it.
- It won't turn while the train is moving or off the rails, while anyone is standing in the pit off the bridge, or while something solid is in the pit.
- A line only joins the table while the bridge is lined up with it. Drive at a pit with the bridge turned away and the train [runs off the end of the rails](#leaving-the-rails).
- The bridge can't be prised up or bent like ordinary track. To move a turntable, clear it and use a **crowbar** on the pivot to take the bridge up.

### Hitting things

- The faster and heavier the train, the harder it hits. A train creeping along shoves a person off the rails with a bruise and stops in front of crates and furniture without breaking them.
- At speed it throws people clear of the track, badly hurt or worse, and keeps going. It smashes anything solid in its way and stops there. A wall, pillar, door or barricade on the line takes the blow like a ram: a fast train breaks through a weak wall and keeps going, while a strong one stops it. A broken wall can bring down the roof it held.
- Set the levers before you leave. A switcher set to split sends the train onto the side track. With no track laid beside it, a split switcher lets the train carry straight on. Look before you start, and warn people near the line.

### Crashes

A train that is stopped dead at speed is wrecked. It happens when a running train hits another train, a strong wall or anything else it cannot push through. A light train crashes from a little over half its top speed, and a long, heavy one from much less. Slower than that it only bumps and stops.

- **The front of the train takes the worst of it.** The car that hits takes the full blow, the one behind it half, the third a third, and so on down the train.
- **Cars come off the rails.** A hard crash derails the leading car, a harder one the first two or three. The train that was hit can lose a car the same way. A derailed car or engine stops its whole train until it is welded: one pass with a **welding tool** on each wrecked section of a car, or one on a heavy locomotive, puts it back. A small one-tile locomotive stays on the rails but its fire goes out.
- **Couplings break.** The couplings between the leading cars are strained and can snap, which parts the train there. Mend or replace them as usual (see [Couplings](#couplings)).
- **Riders are thrown.** Everyone aboard is hurt, knocked off their feet and thrown towards the front of the train, hardest in the leading cars. Walls, doors and furniture stop them. Someone buckled into a seat is hurt half as much and stays put, so the back of the train, sitting down, is the safest place to be.
- **Cargo shifts.** Loose crates and other cargo slide forward and can go over the end of an open car. In a hard crash, cargo secured to a transport wagon breaks loose as well.
- **The train stops.** Every engine is left standing with its throttle shut.

Watch the line ahead, keep your speed down where you cannot see far, and start braking early: a heavy train needs a long way to stop.

### Leaving the rails

Speed puts a train on the ground without hitting anything.

![A boxcar off the rails with sprung deck boards, the same car back on the track, and a red rerailing jack](../images/civ13-train-derailed.png)

- **Curves and switches.** A train that takes a sharp corner, or the branch of a switch, at more than about 110 km/h on the cab's speed readout leaves the rails. A gentle curve holds it to about 145 km/h and a wide one to about 220 km/h. See [Wide curves](#wide-curves). The first throttle notch of every engine is slow enough for any curve; small one-tile locomotives never get that fast. Shut off and brake well before the curve, because a heavy train takes a long way to slow down.
- **Worn track.** Worn track taken at more than about 180 km/h, or track in a bad way at more than about 70 km/h, spreads under the train and puts its leading car off. See [Track wear and platelaying](#track-wear-and-platelaying).
- **Bends too close together.** A train won't run onto corners that are closer together than its longest car is long: it stops short and the cab is told. Driven at them faster than a crawl (about 35 km/h), its leading cars leave the rails instead. Relay the line with longer straights between the corners.
- **The end of the track.** Running off the end of the rails at more than about 70 km/h derails the leading car. So does a rail somebody has lifted out of the line. Creep up to the end of a siding, or build a buffer stop there.
- **What comes off.** The leading car or engine, two of them at one and a half times the limit, three at twice. Riders are thrown about as in a mild crash. Nothing is smashed, but the train can't move until every derailed car is back on the rails. Examine a car to see whether it is off.
- **Rerailing a car.** Make a **rerailing jack** (6 iron, **Rail & Steam**) and use it on each derailed section of the car in turn. If the rail under a section is gone, lay the track again first.
- **Rerailing a heavy locomotive.** It is far too heavy for a jack alone. Bring a [crane car](#crane-car) to within five tiles, lower its outriggers and fuel its crane, then use the jack on the engine. The lift uses one haul of the crane's fuel and puts the whole engine back at once.

## Servicing

A train wears as it runs. None of it is urgent on a short trip, but a train that is never looked after gets slower and at last stops.

![Three ash pits between the rails, one empty, one with ash and one full, a fire rake on the ground and a steam engine standing over a pit](../images/civ13-train-servicing.png)

### Oiling

Every wagon, car and engine runs on the oil in its **axle boxes**. One oiling lasts about **600 tiles**.

- **To oil a car**, stand next to it while the train is standing and click it with an open vessel holding at least 5 units of **fat oil, olive oil, corn oil, lard or petroleum**. One go oils the whole car, however long it is.
- **Examine a car** to check it. It says so when its axle boxes are running dry, which is the time to oil it.
- **A hot box.** A car that runs out of oil runs hot. Smoke curls from the axle box every so often, and the car drags like two. Anyone riding at the back of the train should watch for the smoke. Stop and oil it.
- **A seized axle.** Keep running a hot box for about 150 tiles and the axle seizes. The car is then held as if its handbrake were on, and oil alone won't free it. Use a **wrench** on the car to change the bearing, which takes a while, then oil it.

### Cleaning the fire

A steam engine's fire slowly fills with **clinker**. After a few fireboxes of fuel the engine's controls say the fire is **dirty**, and it makes steam more slowly. Left alone it ends up **choked**, making half the steam it should.

1. Build an **ash pit** on a track tile (6 iron) and make a **fire rake** (2 iron). Both are on the **Rail & Steam** node, or industrial research **101**.
2. Stop the engine over the ash pit.
3. Stand at the firebox door and click the engine with the fire rake.

The clinker drops into the pit and a little of the fire goes with it, so put some fuel on afterwards. An ash pit holds ten cleanings. When it is full, move the engine off it and dig it out with a **shovel**.

### Brake shoes

A brake wears its **shoes** whenever the train moves with it on: a handbrake left pinned down, a brake van's brake wound on down a hill, or the driver's brake on the engine. A set lasts about **300 tiles** of braking.

- **Examine a car or engine** to check. It says when the shoes are worn thin.
- **Worn out**, the brake grinds metal on metal and holds less than a third of what it should, so the train takes much longer to stop.
- **To change them**, make a **set of brake shoes** (3 iron), let the handbrake off, and click the standing car with the set.

### Washing out the boiler

The water a steam engine boils leaves **scale** in its boiler. After about a dozen tanks of water the controls say the boiler is **scaling up**, and the fire makes less steam than it should. Left alone the boiler ends up **thick with scale**.

1. Stop the engine beside a **water crane** or **water tower** that holds at least 300 units of water.
2. Drop the fire and let the boiler cool until the pressure is 25% or lower. From full pressure that takes about a quarter of an hour.
3. On the fireman's side of the cab, choose **Wash out the boiler**. It takes about half a minute.

The scale is hosed out and the boiler is left clean and full of cold water, ready for the fire to be lit.

### Overhaul

An engine that has worked about **5,000 tiles** starts to knock and blow, and pulls a little less with every trip after that, down to seven tenths of its strength. Examining it says when it is due for an overhaul.

1. Stand the engine in the bay of a [rail warehouse](#rail-warehouse), the stretch of track beside the office post, and stop it.
2. Hold a **wrench**, with **10 iron or steel** in your other hand for the new parts.
3. Click the engine with the wrench. The work takes about a minute.

An engine can be overhauled early, from half that distance on.

Overhauled with **5 Inconel** instead of iron or steel (see [Metallurgy](Guide_to_Metallurgy.md#alloy-steels)), the new parts stand the heat and the engine wears half as fast until its next overhaul.

### Coaling stage and sand bin

Two structures beside the track save carrying fuel and sand to every engine by hand. Both serve whatever stands within two tiles of them. Like the brake shoes, they are on the **Rail & Steam** node, or industrial research **101**.

![A coaling stage empty, part filled and piled high, a sand bin empty and full, a set of brake shoes, and a steam engine standing beside a stage and a bin](../images/civ13-train-depot.png)

- **Coaling stage** (20 wood): click it with **coal or wood** to tip the fuel onto its heap. Stop a steam engine or a walk-on tender beside it and click the stage with an empty hand to fill the tender's bunker and the engine's firebox.
- **Sand bin** (8 wood): click it with **sand** to fill it. Stop an engine beside it and click the bin with an empty hand to fill the engine's sandbox.

## Carrying passengers and cargo

- **Storage wagons** (mining cart, tender, transport wagon): click to open their storage, or drag items onto them.
- **Flatbed and cabin wagons:** drag a person onto the wagon to bring them aboard, or drag yourself to climb in. Standing on the wagon with someone, you can buckle them in. Drag a loose crate or structure onto a flatbed to secure it for the ride, and right-click the wagon and choose **Unsecure** to release it at the other end.

## Platform cars

Platform cars are full-size railway carriages: **three tiles wide and four tiles long**, with the track down the middle. You can walk around inside them while the train is moving, and everything on the deck rides along with the car: people, furniture, crates and anything you set down. A car bends round curves, and its furniture turns with it.

![Five platform cars pulled round a curve: storage car, dining car, sleeper car and passenger coach behind a steam locomotive, with an open platform car still on the straight](../images/civ13-platform-cars-curve.png)

| Kit | Cost | What you get |
| --- | --- | --- |
| Platform car kit | 12 iron | An open plank deck with railings at each end, for cargo, crates and machines. |
| Passenger coach kit | 16 iron | Six seats either side of a carpeted aisle, windows, side doors and end doors. |
| Sleeper car kit | 20 steel | Three private compartments a side, each with a bed and a sliding door. |
| Dining car kit | 20 steel | A galley with a stove, sink, fridge and counter, and two booths. |
| Storage car kit | 18 steel | Cabinets and large crates, each behind its own compartment door. |

### Long cars

Long cars are **eight tiles long**, twice the length of the others, and weigh twice as much. They are built, coupled and ridden the same way.

![Two trains of long cars: a steam locomotive with a boxcar, an open wagon and a bogie flatcar, and a diesel locomotive with two bogie coaches and a boxcar with its roof off](../images/civ13-long-cars.png)

| Kit | Cost | What you get |
| --- | --- | --- |
| Bogie flatcar kit | 22 iron | A long open plank deck with railings at each end, for machines, vehicles and long loads. |
| Open wagon kit | 26 iron | Plank sides all round to keep loose cargo aboard. The drop doors in the middle of each side open for loading. Carries ore, coal or sand in bulk (see [Bulk freight](#bulk-freight)). |
| Boxcar kit | 30 iron | A roofed goods van with closed ends. The sliding doors in the middle of each side open for loading. |
| Bogie coach kit | 26 steel | Twelve seats either side of a carpeted aisle, with a vestibule and doors at each end. |
| Stock car kit | 30 iron | A livestock van with slatted sides for air and straw on the floor (see [Stock car, ice car and mail van](#stock-car-ice-car-and-mail-van)). |
| Ice car kit | 34 iron | An insulated white van with an ice bunker and eleven cold lockers for food. |
| Baggage and mail van kit | 30 iron | Sorting tables and cabinets at the front, side doors in the middle and a baggage room of crates and cabinets behind. |
| Bogie sleeper car kit | 30 steel | Twelve private compartments, each with a bed and a sliding door, and a vestibule at each end. |
| Bogie dining car kit | 30 steel | A galley with a stove, sink, fridge and counter, then four tables and six booths. |

![A long sleeper car and a long dining car, each shown with its roof off and on](../images/civ13-train-long-sleeper-dining.png)

### Stock car, ice car and mail van

![A stock car, an ice car and a baggage and mail van, each with its roof off and on, and the ice car's bunker and cold locker shut and open](../images/civ13-train-special-stock.png)

**Stock car.** Open a sliding door in the middle of either side, lead your animals in and shut the door behind them. The slatted sides keep them aboard while the train runs.

**Ice car.** The ice car carries food a long way without it spoiling.

1. Find the **ice bunker**, the grey chest at the front left corner of the car.
2. Pack it with **snow piles** or **blocks of ice**, the same as an [ice house](Guide_to_Cooking.md#food-storage). Each snow pile is good for an hour of cold and each block for three, up to twenty hours.
3. Put the food in the white **cold lockers** down both sides of the car.

While the bunker has ice in it, food in the lockers keeps as long as it would in a cold ice house. The car's insulated body makes the ice last four times as long as it would in the open, the same as an ice house underground. If you click a locker with snow or ice, it goes into the bunker for you. Examine a locker to see whether the bunker is still cold, and examine the bunker to see how long its ice will last. When the ice has all melted, the lockers keep food no better than a crate.

**Baggage and mail van.** A van for a passenger train. It comes fitted, and you can rearrange it like any other car.

### Bulk freight

Ore, coal and sand don't have to ride as loose piles. An **open wagon** or a **hopper wagon** takes them in bulk: the load becomes one heap in the car, shown from above, and a full wagon carries far more than you could stack on a deck.

![An open wagon full of coal, a hopper wagon empty, part loaded with sand and full of ore, and a drop pit empty and holding coal, ore and sand](../images/civ13-train-bulk-freight.png)

| Car | Holds | How it unloads |
| --- | --- | --- |
| Open wagon | 600 | Dug out with a shovel. |
| Hopper wagon (kit: 28 iron, six tiles long) | 800 | Drops its whole load through the floor, or is dug out with a shovel. |

- **To load**, click the car with a stack of ore, coal, charcoal, sand or another mined mineral. The whole stack is tipped in.
- **One kind at a time.** A car loaded with coal takes only coal until it is empty.
- **To dig a load out**, click the car with a **shovel**. Each go puts up to 50 on the ground beside you.
- **A loaded car is heavy.** A full open wagon weighs nearly twice what it does empty, so count it when you plan the train.
- **Examine the car** to see what it carries and how much.

**Dropping a hopper's load.** A hopper is built with a **door lever** at its front left corner. Stop the train and pull the lever: the load rumbles out through the floor and lies on the track under the wagon.

To catch it, build a **drop pit** (8 iron) on a track tile and stop the hopper over it. The load then falls into the pit, which holds **3,000** of one kind. Dig the pit out with a shovel from beside the track. If the pit is full or holds something else, the lever tells you and the load stays in the wagon.

The hopper wagon kit, a spare door lever (4 iron) and the drop pit are on the **Rail & Steam** node, or industrial research **101**.

### Tank car

A **tank car** (kit: 30 iron, six tiles long) carries liquid by the trainload: water for a dry water stop, oil, fuel, milk or drink. Its tank holds **3,600** units, as much as a dozen or more barrels.

![A tank car heading east and one heading north, each with a black riveted tank between two running boards and a red valve wheel on its front platform, and the valve on its own](../images/civ13-train-tank-car.png)

The tank stands down the middle of the car. You can't walk through it, but a running board with a handrail runs along each side, and both ends are open platforms.

- **To fill it**, click the tank with an open vessel such as a bucket or barrel. Everything in the vessel is poured in.
- **One plain liquid at a time.** A tank holding water takes only water until it is empty, and it won't take a mixture.
- **To draw off by hand**, click the tank with an empty open vessel. It comes away full.
- **A full tank is heavy.** A full tank car weighs three times what it does empty.
- **Examine the car** to see what it holds and how much. A car with liquid in it can't be packed back into a kit: drain it first.

**The valve.** A tank car is built with a **valve** and hose at the front left corner of its end platform. Stop the train and use the valve with an empty hand to run the tank out:

- **Water** runs into a [water tower](#tenders-and-water-stops) within three tiles, so a tank car can supply a tower that has no water of its own.
- **Diesel or biodiesel** runs into a [heavy diesel locomotive](#heavy-locomotives) standing within three tiles, until its fuel tank is full.

You can also hold a vessel to the valve to fill or empty the tank the same way as at the tank itself.

**Filling from a tower.** A water tower or water crane fills a tank car standing beside it, as it fills a tender, as long as the tank is empty or already holds water.

The tank car kit and a spare valve (4 iron) are on the **Rail & Steam** node, or industrial research **101**.

### Crane car

A **crane car** (kit: 40 iron, four tiles long) carries a steam **rail crane**, so you can take a hoist anywhere the track goes. It is ballasted and weighs twice as much as an ordinary car of its length.

![A crane car heading east at rest, the same car hauling with its lever thrown, and a crane car heading north](../images/civ13-train-crane-car.png)

1. **Stop the train** and wait a moment for it to settle.
2. **Pull the outrigger lever** at the front left corner of the car. The crane won't lift until the outriggers are down, and while they are down the whole train stays where it is.
3. **Stoke the crane.** Use coal, charcoal or wood on it, the same as a [steam crane](Guide_to_Construction.md#hoisting-heavy-loads). Each haul burns one haul of fuel and it holds 40.
4. **Stand next to the crane and drag the load onto it.** The load must be unfastened and within **five tiles** of the crane. It doesn't have to be beside it.
5. **Choose where it goes:**
   - **Swing it onto** another car: the load lands on the nearest clear deck tile of a car beside the crane car.
   - **Set it down beside the track:** the load lands on the nearest clear ground off the rails.
   - **Raise** or **lower** it one level through open air, as any crane does.
6. **Pull the lever again** to raise the outriggers before you set off.

Click the crane with an empty hand to haul up something lying on the level below. Examine it to see how much fuel it has and whether it is ready to lift.

The crane car kit and a spare rail crane are on the **Rail & Steam** node, or industrial research **101**.

### Goods yard

A goods yard is what a yard crew builds beside the track so that loading a train is quick work. All of it is on the **Rail & Steam** node, or industrial research **101**.

![Loading stages empty and heaped with coal, ore and sand, a goods crane at rest and hauling, a loading stage beside a hopper wagon, and a livestock ramp at the door of a stock car](../images/civ13-train-goods-yard.png)

**Loading stage** (24 wood). A raised stage with a chute, built beside the track like a [coaling stage](#coaling-stage-and-sand-bin). It holds up to **3,000** of one kind of ore, coal or sand.

- **Heap it up between trains.** Click the stage with a stack to tip it on. It takes one kind at a time.
- **Load the train.** Stop [open wagons or hoppers](#bulk-freight) within two tiles of the stage and click it with an empty hand. After a few seconds the heap runs down the chute into them. A wagon that already holds something else takes nothing, and a full wagon takes only what it has room for; the rest stays on the stage.
- **Take it back off** with a shovel, up to 50 a go.

At the other end of the trip, a hopper drops its load into a [drop pit](#bulk-freight).

**Goods crane** (12 iron). A hand crane on an iron post for crates, barrels and machines. Stand it beside the track, then stand next to it and drag an unfastened load within **three tiles** onto it. Choose:

- **Swing it onto** a car: the load lands on the nearest clear deck tile of a car within reach.
- **Set it down beside the track:** the load comes off a car onto the nearest clear ground.
- **Raise** or **lower** it one level, as [any hoist](Guide_to_Construction.md#hoisting-heavy-loads) does.

**Livestock ramp** (6 wood). A cleated ramp for getting animals on and off a train without leading them one by one.

1. Build the ramp **two tiles from the rails**, where the door of a [stock car](#stock-car-ice-car-and-mail-van) will stop. Turn it with a wrench until its head faces the track. Examine it to see which way it faces.
2. Pen your animals within **three tiles** behind the ramp.
3. Stop the car with its door at the head of the ramp, and **open the door**.
4. Click the ramp with an empty hand and choose **Drive the animals aboard**. They go up into the car, as many as it has room for. Shut the door behind them.
5. At the far end, stop at another ramp, open the door and choose **Drive the animals off the car**. They come down into the pen behind it.

The ramp moves farm and wild animals. It leaves people, animals that are out for blood, and any mount with a rider on it.

**Destination cards.** Every car and engine has a card holder. Click a car with a **pen** and write where it is bound or what it carries, in one short line. Examine the car to read its card, and the [guard's journal](#the-conductor) lists each car's card beside it, so a yard crew can see at a glance which cars come off where. Write a blank card to take the old one out.

### Putting a car together

1. Carry or drag the kit onto the track. A car needs **four tiles of straight track**, and a long car **eight**: the tile under the kit and the rest behind it. Examine a kit to see how long its car is.
2. Leave a **clear tile on both sides** of those tiles for the deck.
3. Stand facing the way the car should point and hit the kit with a **hammer**. A car can face either way in a train.

To couple the car, right-click its front end and choose **Hitch** to join the car ahead, or its rear end to join the car behind. The middle of a car can't be unhitched.

### Riding and doors

- Click a door to open or close it. Side doors are at the front end of each enclosed car, and end doors let you walk from one car to the next.
- A door can be locked with a [carriage key](#the-conductor).
- Walls and windows keep you from walking through them, but they don't stop bullets. Armor plate on wartime cars does.
- Track for platform cars needs a clear tile on each side all the way along, including on curves. If a car's deck would hit a wall, a tree or another train, the whole train grinds to a halt before it moves. People standing beside the track aren't hurt. The deck slides under them and they end up on board.

### Wartime cars

![An armored train standing still: armored locomotive, armored wagon, railway gun car, flak car, a second armored wagon and an open platform car](../images/civ13-wartime-train.png)

| Kit | Cost | What you get |
| --- | --- | --- |
| Railway gun car kit | 60 steel | A long-range gun on a turntable, an outrigger lever and a shell rack. |
| Armored wagon kit | 40 steel | Armor plate with firing doors. Bring your own machine guns. |
| Flak car kit | 45 steel | A low armored wall and ammunition crates. Bring your own autocannons. |
| Armored locomotive | 30 steel | A steam locomotive cased in steel plate. |

- **Bracing the railway gun.** The gun only fires while its car is braced. Stop the train, wait a moment for it to settle, then pull the **outrigger lever** on the car. While the outriggers are down the whole train stays where it is; pull the lever again to raise them before you set off.
- **Guns.** The kits come unarmed. Forge [emplaced machine guns](Guide_to_Weapons.md#emplaced-machine-guns) and 30mm autocannons at an anvil and push them aboard. A **wrench** unbolts a gun nobody is manning so it can be moved, and bolts it down again. Autocannons come off the anvil bolted down.
- **Armor.** Armor plate stops bullets coming from outside the car, but the crew inside can shoot out through it. Open an armor door to get on or off.
- **Explosions.** Shells and bombs damage platform cars; armored cars take much less. A car blown off the rails stops its whole train. Weld it with a **welding tool** until it is back on the rails.
- **Armored locomotive.** Bullets do nothing to it. Heavy explosions wear its plating down, and once its boiler is holed the engine dies and won't start again until it has been welded.

### Taking a car apart

Stop the train, uncouple the car from the cars on both sides and clear everything off its deck, furniture included. Then use a **crowbar** on the car to pack it back into a kit. A kit that was taken apart comes back without furniture, so keep the furniture you removed and put it back aboard. A full-size tender packs into its kit the same way, but any coal and water still in it are lost.

## Heavy locomotives

Heavy locomotives are full-size engines, three tiles wide and four long. They are driven with the same controls as the small locomotive and are no faster, but each pulls about twice the train, carries more fuel and survives explosions.

![The three heavy locomotives seen from above, each shown with its cab open and with its cab roof on: green steam locomotive, blue diesel locomotive and camouflaged armored locomotive](../images/civ13-heavy-locomotives.png)

| Kit | Cost | Research | Fuel | Notes |
| --- | --- | --- | --- | --- |
| Heavy steam locomotive kit | 45 steel | **Rail & Steam** node, or industrial research **101** | Coal, wood planks, branches (holds 250) | Boiler in front, cab third, coal bunker at the back. |
| Heavy diesel locomotive kit | 50 steel | **Combustion Engine** node, or industrial research **115** | Diesel or biodiesel (holds 300 units) | The fastest engine. Cab at the front, with a walkway down each side of the hood. |
| Heavy armored locomotive kit | 80 steel | **Field Artillery** node, or industrial **101** and military **109** | Coal, wood planks, branches (holds 300) | The strongest puller and the slowest. Bullets do nothing to it, and its cab doors stop bullets from outside. |

- **Assemble** the kit like a platform car: put it on straight track with three more straight tiles behind it and a clear tile either side, face the way the engine should point and hit it with a **hammer**.
- **Drive from the cab.** The rest of the body is solid, apart from the diesel's walkways. Step into the diesel's cab, or stand beside it, and click the locomotive to open the controls. The steam engines have a [cab crew](#cab-crew).
- **Fuel.** Click the diesel with a container of diesel from anywhere beside it. The steam engines are fired from the firebox door in the cab. Water goes into a steam engine from anywhere beside it.
- **Couple** wagons and cars to it with **Hitch**, as with any locomotive. It can pull from the front, push from the back or help another engine.
- **Keep clear of the line.** A heavy locomotive is as wide as a platform car, and it hits anyone standing beside the rails as well as on them.
- **Damage.** Explosions wear the engine and its body down. A wrecked engine dies and a wrecked body section stops the train until it is welded. A **welding tool** repairs both.

A **crowbar** packs a heavy locomotive back into its kit. Stop it, shut it down, uncouple it at both ends and get everyone and everything out of the cab first. Its fuel and water are lost. A [rail warehouse](#rail-warehouse) takes it whole instead.

### Cab crew

The cab of a heavy steam, heavy armored or main-line locomotive is three tiles wide, and each tile is a place of work. Click the locomotive from the tile you stand on to work what is there.

| Where you stand | Looking forward | What you work |
| --- | --- | --- |
| **Driver's stand** | Right side of the cab | Throttle, brake and reverser. |
| **Firebox door** | Middle of the cab | **Light the fire** and **Drop the fire**. Coal and wood go in here by hand, the shovel fires from the tender here, and a new fusible plug is fitted here. |
| **Fireman's side** | Left side of the cab | The injector. |

A driver and a fireman run the engine properly: one keeps a hand on the regulator and the brake while the other feeds the fire and watches the water. One person can do it all, but has to step away from the brake to shovel. The small steam locomotive and the diesel are still worked from one place.

### Main-line steam locomotive

The main-line steam locomotive is the big express engine: six tiles long, faster than any other steam engine and able to pull twice the train of the heavy steam locomotive.

![A green main-line steam locomotive with its tender and a coach seen from above, the engine shown from both ends, and a close view of its cab with the fireman's injector wheels on the left, the firebox door in the middle and the driver's regulator on the right](../images/civ13-mainline-locomotive.png)

| Kit | Cost | Research | Fuel |
| --- | --- | --- | --- |
| Main-line steam locomotive kit | 90 steel | **Rail & Steam** node, or industrial research **101** | Coal, wood planks, branches (firebox holds 400) |

- **Assemble** it like the heavy locomotives, on **six** tiles of straight track. The cab is the last section.
- **It needs a tender.** It has no coal bunker and almost no water of its own. Build a [tender](#tenders-and-water-stops) behind it and couple the two, so the tender's plate meets the back of the cab. The tender's water runs to the engine, and the fireman at the firebox door shovels from the tender.
- **Raising steam** from cold takes about six minutes on a good fire, so keep the fire in between runs.
- It has the same [cab crew](#cab-crew) as the heavy steam engines, takes damage and is repaired the same way, and a crowbar packs it back into its kit like them.

### Main-line diesel locomotive

The main-line diesel is the big engine of the diesel age: six tiles long with a **cab at each end**, twice the pull of the heavy diesel and twice the fuel. It needs no fire, no water and no fireman, so one driver can run a long train.

![Two maroon main-line diesel locomotives coupled together ahead of a coach, seen from above, then one locomotive facing north and south with its cab roofs off and on, and a close view of a cab with its desk, two seats and brake handle](../images/civ13-train-mainline-diesel.png)

| Kit | Cost | Research | Fuel |
| --- | --- | --- | --- |
| Main-line diesel locomotive kit | 100 steel | **Combustion Engine** node, or industrial research **115** | Diesel or biodiesel (holds 600 units) |

- **Assemble** it like the heavy locomotives, on **six** tiles of straight track. Fuel it from a container or from a [tank car](#tank-car).
- **Two cabs.** Click the locomotive from either cab to drive it. A walkway down each side of the hood joins them. Drive from the cab that leads: with nobody in the leading cab the train keeps to three quarters of its speed, so walk to the other end before you run back.
- It takes damage and is repaired like the heavy locomotives, and a crowbar packs it back into its kit like them.

### Diesels in multiple

Heavy and main-line diesel locomotives that are **coupled next to each other** work as one. Their controls join with the couplings, so nothing else has to be connected. A wagon or car between two diesels breaks the link.

- **Start the engine** or **Stop the engine** in any of their cabs and every linked unit starts or stops with it. A unit with an empty tank or a wrecked engine stays off, and you are told which.
- **Drive from any cab.** The throttle, brake and reverser in every linked cab work the same train, and the brake holds all the linked units instead of one.
- Each unit burns its own fuel, so fill them all.
- Examine a diesel to see how many units are linked.

### Dead-man's handle

Every heavy and main-line diesel has a dead-man's handle. While the train moves, somebody awake and able has to stand in a cab of the working units. If the cabs stay empty, or the driver is knocked out, the power shuts off and the brakes go on within about a dozen tiles. The engine's brake alone stops a long train slowly, so a guard at a [brake van](#brake-van) still matters.

## Electric railways

An electric engine carries no fuel and needs no fire or water. It takes its power from a wire hung over the track, and the wire takes it from the same grid that runs your machines (see [Power](Guide_to_Power.md)). The masts, the electric locomotive and the tram are on the **Electricity** node, or industrial research **105**.

![A cream-roofed tram and a green electric locomotive on a track under an overhead wire carried by two masts, then the locomotive and the tram seen from above with their roofs off and on, and a mast with its arm over a second track](../images/civ13-train-electric.png)

| Craft | Cost | What it is |
| --- | --- | --- |
| Overhead line mast | 4 steel | A steel mast with an arm that hangs the wire over the track. |
| Electric locomotive kit | 55 steel | Four tiles long with a cab at each end. Pulls more than a heavy diesel and is as fast. |
| Tram kit | 30 steel | Four tiles long. A driving platform at each end, four seats between, and a roof over all of it. |

### Putting up the line

1. Stand an **overhead line mast** two tiles from the rails, square to the track, and use a **wrench** on it. It turns its arm to the track and hangs its wire over the rails for four tiles either way.
2. Put up another mast every **nine tiles** along the line. Wires that meet join into one line. A wider gap is a stretch with no power.
3. Feed the line. Stand a **distribution transformer**, a **wall outlet** or a **utility pole** on a powered cable within its reach of any one mast (see [Transformers, outlets, poles and power meters](Guide_to_Power.md#transformers-outlets-poles-and-power-meters)). One fed mast makes the whole line live.
4. Click or examine a mast to read the line: how many masts it has, how many are fed, how much the trains are drawing and whether the wire is live.

A wrench takes a mast down again. The masts stand clear of the cars, so a train passes them freely.

### Driving under the wire

Build the kit on straight track like any [heavy locomotive](#heavy-locomotives), under the wire. The controls are the same as a diesel's, with one difference:

- **Raise the pantograph** (the bow collector on a tram) where a diesel has Start the engine. It refuses where there is no wire overhead or the line is dead.
- The engine draws from the grid **by its throttle**: about 5 kW standing with the pantograph up and up to **155 kW** at full throttle for the locomotive, about 2 kW and up to **42 kW** for the tram. Size your generators for every train that will run at once.
- If the grid can't carry one more engine, that engine gets no power and the trains already running keep theirs. Ease the throttle down a notch and it may take.
- **Off the end of the wire, or under a dead one, the train coasts.** You can still brake. It picks the power up again by itself under the next live wire, so a short gap costs only a little speed.
- **Lower the pantograph** when you leave the engine, so it stops drawing.

The electric locomotive is driven from the cab that leads, works [in multiple](#diesels-in-multiple) with other units coupled next to it and has a [dead-man's handle](#dead-mans-handle), like the main-line diesel. It is damaged and repaired like the heavy locomotives.

### The tram

The tram is a small train in one piece, made for a town line. Passengers step on at the open sides of either driving platform and walk through to the seats. It is about as fast as a steam locomotive and has the pull for itself and one trailer car. Drive it from the platform that leads, and change ends to go back.

### The live wire

Don't ride on a car roof under a live wire. When the car moves you touch the wire: you are burned, knocked down and thrown off.

## Rail warehouse

A rail warehouse stores cars and locomotives off the line, together with everything on board, so a yard doesn't need long sidings. Trains drive straight through it: unload cars from the back of a train, or couple stored cars back on to make up a new one.

![A train standing in a rail warehouse: a locomotive pulling a storage car, a passenger coach and a loaded platform car, with the office post in the wall beside the track](../images/civ13-rail-warehouse.png)

1. **Build the office** (15 iron; **Rail & Steam** node, or industrial research **101**) facing the track, with **one tile between the office and the rails**. The track running past it, **six tiles each way**, is the warehouse bay (13 tiles, room for three platform cars and a locomotive, or one long car and one platform car). Use a wrench on an empty office to turn it. The bay track must be plain straight track, with no switchers, curves or rotators in it. Build walls and a roof around the bay if you like, but leave the track open at both ends and keep a clear tile either side of the rails.
2. **Drive the train in** and stop it with the cars you want to put away inside the bay. Get everyone off them.
3. **Use the office.** Choose a car to put away, or **Put away the whole train**. Cars always come off the **back** of the train: whatever is standing on a car goes with it, crates and their contents included.
4. **Couple a car back on** from the same menu. It rolls onto the track behind the train in the bay, facing the way the train heads, and is hitched to it. If either of the two drawbars that meet has no coupling, or a broken one, the car rolls out but stays unhitched. If the bay is empty, it rolls to the far end.

The office holds 8 cars or locomotives. It won't take a moving train, a car that sticks out of the bay, a car with people aboard, a derailed car, or a railway gun car or crane car with its outriggers down.

A **heavy locomotive** goes away whole: the engine and the sections behind it count as one of the 8, and all of it has to stand inside the bay with the engine shut down. A main-line engine is six tiles long, so it fits with room for its four-tile tender behind it. It comes out as it went in, with its fuel, water, sand and wear, and with whatever was standing in its cab.

## Through station and service loop

This example separates an eastbound main line, a passenger platform track and a cargo/service loop. It uses straight track, four corners, two left switchers, two right switchers and a rotator, plus four levers.

The platform and cargo stopping positions allow **eight vehicles including the locomotive and tender**. Extend the straight stopping tracks for a longer train.

### Layout views

![The station layout, showing the passenger platform north of the main line and service loop south of it](../images/civ13-station-game-sprites.png)

The main line continues beyond both station ends. [Open the full-size sprite render](../images/civ13-station-game-sprites.png).

![Coordinate schematic showing the four switchers, four corners, rotator, levers and mandatory forward guard rails](../images/civ13-station-plan.png)

Construction schematic; use the coordinates below when placing track. The arrows indicate a continuing main line, not buffer stops: keep whole-train staging space to the west and exit rail through at least `x=44` to the east. [Open the full-size schematic](../images/civ13-station-plan.png). Sprite assets come from the [Civ13 game source](https://github.com/Civ13/Civ13/tree/ec86e58fa67fdd7baea265d8716a64ae6f9a2d99), under its [game-source license](https://github.com/Civ13/Civ13/blob/ec86e58fa67fdd7baea265d8716a64ae6f9a2d99/LICENSE).

### Coordinates and track plan

Choose a clear area and treat any convenient tile as `(0,0)`. Increasing `x` is east; increasing `y` is north. All ranges below include both endpoints. Lay the main line first, then the passenger track and the depot loop. Facing means the direction to face when building a switcher or the rotator; plain track shapes itself. Use one piece per listed tile; switches and the rotator replace the straight track at their coordinates.

| Section | Tiles and pieces |
| --- | --- |
| Main line | Horizontal rail along `y=0`, except the two entrance switchers below. The drawn `x=0..40` segment is part of a continuing eastbound route, not two buffer stops. Continue west far enough to stage the whole train before the first entrance, and east through **at least `x=44`** for this eight-vehicle layout. Longer trains need longer clear approach and exit tracks. |
| Passenger entrance | **Left switcher, facing east**, at `(4,0)`. Its split route shifts to `(4,1)`. Lever at `(4,2)`. |
| Passenger track | Horizontal rail from `(4,1)` to `(17,1)`, except the exit switcher. |
| Passenger platform | Build alongside the track from `(6,2)` to `(13,2)`; stop the eight-vehicle train beside it on `x=6..13, y=1`. Keep both approaches clear. |
| Passenger exit | **Right switcher, facing east**, at `(16,1)`. Its split route shifts to `(16,0)`. Lever at `(16,3)`. **Keep horizontal rail at `(17,1)`.** |
| Depot entrance | **Right switcher, facing east**, at `(22,0)`. Its split route shifts to `(22,-1)`. Lever at `(22,-2)`. |
| Depot approach | Horizontal rail at `(22,-1)` and `(23,-1)`, leading to the first turn at `(24,-1)`. |
| West leg | Vertical rail at `x=24, y=-2..-7`, except the rotator at `(24,-4)`. |
| Cargo straight | Horizontal rail from `(25,-8)` to `(33,-8)`. An eight-vehicle stopping position is `x=25..32`; leave `x=33` clear. Put the cargo apron alongside at `y=-9`. |
| East leg | Vertical rail at `x=34, y=-7..-2`. |
| Depot exit approach | Horizontal rail from `(35,-1)` to `(37,-1)`, except the exit switcher. |
| Depot exit | **Left switcher, facing east**, at `(36,-1)`. Its split route shifts to `(36,0)`. Lever at `(36,-3)`. **Keep horizontal rail at `(37,-1)`.** |
| Rotator | Replace the west-leg rail at `(24,-4)` with a **rotator facing south** for through traffic. |
| Optional service spur | A separate horizontal track from `(25,-4)` to `(28,-4)`, beside the rotator. Use it only for an unhitched vehicle. |

The four depot corners form by themselves: lay each leg one tile past the corner, then lay the next tile of the following leg, and the corner tile bends to meet it.

| Corner | Incoming travel | Outgoing travel |
| --- | --- | --- |
| `(24,-1)` | East | South |
| `(24,-8)` | South | East |
| `(34,-8)` | East | North |
| `(34,-1)` | North | East |

### Switches and guard rails

A split switcher moves the vehicle **one tile sideways without changing its heading**. The passenger route enters and leaves its parallel track while continuing to face east; the depot uses actual turns for its loop.

**Keep the forward guard rails at `(17,1)` and `(37,-1)`, even though normal exit traffic leaves sideways.** A switcher needs rail straight ahead before it will take its split route.

A lever changes **every switcher within two tiles**, rather than linking to one selected switch. The four lever positions above keep the intended controls apart. If you move a lever or add another nearby switcher, check which switches it reaches and inspect their settings before admitting a train.

### Operating the routes

| Route | Passenger entrance at `(4,0)` | Passenger exit at `(16,1)` | Depot entrance at `(22,0)` | Depot exit at `(36,-1)` |
| --- | --- | --- | --- | --- |
| Express bypass | Forward | Not used | Forward | Not used |
| Passenger stop | Split | Split | Forward | Not used |
| Cargo/service loop | Forward | Not used | Split | Split |

1. Keep people, cargo and other trains off the intended route. Confirm the main line and the exit merge are clear.
2. Set the required switches **before** the train enters. Leave the settings alone until the **whole train**, including the last wagon, has cleared the switches.
3. For a passenger stop, use the north platform track and stop the locomotive manually with the train beside the platform.
4. For cargo, follow the depot loop in this order: east into the approach, south down the west leg, east along the cargo straight, north up the east leg, then east to the main-line exit. Stop manually alongside the cargo apron.
5. Before rejoining the main line, wait for a clear merge and have an operator keep other traffic out. For this eight-vehicle train leaving the depot at `(36,0)`, continue until the locomotive reaches at least `(44,0)` and the last wagon has cleared the exit switch. Keep that exit track clear; the drawing ends before the required clearance does. Restore entrance switches to forward after the whole train is clear if through traffic is next.

There is **no automatic station stop, signalling or route reservation** in this plan. A bypass track does not protect a train entering at the exit merge. Use manual dispatch, allow stopping distance and run only traffic the operators can keep separated.

### Using the rotator

The rotator changes the heading of vehicles **on its own tile**. It does not turn an entire coupled train or reverse a whole consist.

Stop and unhitch the individual vehicle before turning it toward the optional east-facing spur. Clear the surrounding tracks, rotate the vehicle into the required direction and use the short spur only for detached-vehicle handling. Restore the rotator to **south** before another train uses the west leg. Do not rotate it beneath a moving or coupled train.
