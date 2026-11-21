# Turf-built vessels: the aircraft carrier

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/naval_carrier/probe.dm
```

Production sources run in the shared resource-extraction constructor fixture with ordinary game startup disabled. The fixture world is 70x60 with three levels: cave rock on z1, deep saltwater on z2 and open air (`/turf/sky/building`) on z3, standing in for Gaia's cave level, surface and standing building level.

The probe covers phase 1 of the carrier (`code/modules/naval/`):

- **Flooding controllers:** a bare `/datum/flooding_controller` is still the Submarine Commander global; a deck tile outside any vessel reports to it; a vessel's controller is its own, is ticked from `flooding_controllers`, and keeps a breached compartment's air pocket.
- **Laying down:** `carrier_lay_down()` writes 342 hangar-deck cells (hull, bulkheads, six compartments with a blast door each), 360 flight-deck cells and the 15-cell island with the helm; the flight deck overhangs the hull by one tile at each end; ladders pair hangar to flight deck and flight deck to island; `vessel_at()` finds the ship on each level and nothing beside it.
- **Compartment air:** the engine room ledger holds 28 tiles and the hangar 113 at sea-level air; the controller tracks every deck tile (222) and the SUBCOM13 controller none of them.
- **The hop:** at full ahead a hop moves the block six tiles with a crate, a sailor, a bucket in the hangar and the helm aboard; sea, rock and sky come back behind it; a hull breach and the water it let in move with the hull; a compartment keeps its thinned air; the ladders still pair; the flooding tick keeps filling the breached compartment. The hop's wall time is logged (about 40 ms in the fixture).
- **Refusals:** land off the bow stops the ship with the reason; an obstacle three tiles ahead leaves a two-tile hop and the next hop stops hard against it; no hop runs while `persistence_save_in_progress`; a ship over the map edge or over another ship is refused and writes nothing.
- **Coming about:** turning north swaps the 40x9 box about its centre, the helm and the sailor are where the island and deck now stand, and nothing is left behind.
- **Removal:** `remove()` restores every tile of sea, rock and sky, the controller forgets the decks, cargo is left in the water, and deleting the vessel clears the registries.

## Phase 2: the flight deck (`flight_deck_probe.dm`)

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/naval_carrier/flight_deck_probe.dm
```

The carrier lies bow north in the same fixture so the light plane, which is built facing south, rolls along the deck.

- **Layout:** 360 flight deck tiles of which 36 are arresting wires (stern cells u 6-9) and 32 are two 4x4 elevator platforms on the port side; the hangar keeps its 113 tiles with 32 elevator floors under the platforms; each elevator has a lever on both decks that serves only its own 16 tiles.
- **Runway:** deck, wires and platform tiles count for `aircraft_runway_at()`; the island deck, the sea and the hangar floor do not. A fuelled light plane takes off after the usual eight-tile roll and climbs to the level above the ship.
- **Hops:** a parked plane rides a hop whole, still on runway, with a crate; the plane in the air stays where it flies; moving the ship back brings them back.
- **Landing:** a descent over the wires lands and stops the plane at once (tailhook); a landing clear of the wires rolls on at taxi speed.
- **Crash barrier:** the step off the stern is refused and the plane stops; amidships it may roll. The plane that rolled over the after lever at takeoff leaves it standing (ladders and levers are neither crushed nor carried by vehicles).
- **Elevators:** the deck lever lowers a parked plane and a crate to the hangar and the hangar lever lifts them back; a plane half on the platform, a blocked hangar floor and a plane still rolling keep the elevator still; an empty elevator moves.
- **Removal:** the sea comes back under wires and platforms.

## Phase 3: the shipyard (`shipyard_probe.dm`)

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/naval_carrier/shipyard_probe.dm
```

The probe's map metadata answers `is_node_done()` from a global toggle, so the research gate can be exercised without a faction.

- **Research:** the Naval Aviation node needs Powered Flight and Wagons & Ships; the shipyard office recipe is gated on it.
- **Office:** without research the placement refusal names the research and the missing cable but not the sea; with research only the cable. A carrier fits bow east or west on the sea north-east of the office; bow north it would run off the map; fit checks lay nothing down. Laying down costs 400 steel, 20 glass and 40 cable and leaves the ship anchored with empty bunkers; an office whose sea is under another ship lays nothing down.
- **Bunkers:** a dry ship stops with the reason; pouring a barrel takes its diesel and petroleum and leaves the water; the bunkers hold 1000 units; a hop at full ahead burns 6 and the last hop stops the ship.
- **Chart:** heading, telegraph, fuel, hops left, the map edge or rock ahead with the distance, and the last refusal.
- **Saves:** the helm records the ship's state before a save; with the vessel datum deleted and the decks left on the map, the helm rebuilds the ship where it was with its fuel, the decks and controller are its again (222 tiles, hangar at 113 with sea-level air), a stopped ship does not sail by itself, a second load builds no second ship, and the rebuilt ship hops and restores the sea, rock and every tile on removal.

## Phase 4: damage control (`damage_probe.dm`)

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/naval_carrier/damage_probe.dm
```

- **Craters:** a blast (`ex_act`) craters a flight deck or island tile instead of tearing it out; a crater is no runway until it is welded shut; craters ride hops and come back with the ship.
- **Steel:** light, medium and heavy blasts take 100, 300 and 600 off a hull wall, the heavy one breaching it so the compartment takes water, and 25, 75 and 150 off a bulkhead, buckling its seals; the turfs stay hull and bulkhead. A blast on the hangar deck starts a deck fire and leaves the deck.
- **Listing:** ten ticks of a breach fill the engine room short of flooded; a flooded compartment caps the telegraph at half ahead and ringing full gives half; a second one leaves slow ahead and slows the ship; pumping one out eases the list; the chart reports the flooding.
- **Sinking:** three flooded compartments sink her: the vessel and its controller leave the registries, the decks give way to sea, rock and sky, the sailor from the hangar deck comes up into the water, the deckhand and the crate are in the water where the deck was, the plane and the wheel go down with the ship, and five pieces of wreckage float where she sank.

## Phase 5: the fit-out (`fitout_probe.dm`)

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/naval_carrier/fitout_probe.dm
```

The carrier lies bow south so the light plane, built facing south, faces the bow from the catapult track.

- **Layout:** twelve catapult track tiles at the bow with their lever beside them; a gun tub at each corner of the deck that is no runway and that the crash barrier keeps planes off; sixteen lit deck lights along the deck edges; the radar set and two searchlights on the island either side of the wheel; the elevator levers still on both decks.
- **Deck lights:** the wheel switches them off and on and the saved state records the switch.
- **Catapult:** an empty catapult, a plane with a wheel off the track, a cold engine and a plane pointed across the deck are each refused with the reason and the plane stays put; a fuelled plane on the track is thrown into the air above the bow at full speed with no deck roll, and the track is clear and ready again.
- **Radar:** the plane in the air shows as an aircraft; a second carrier shows as a stopped vessel with its heading and a ship's rudder axis as a ship, three contacts in all; the other carrier's radar sees this one and leaves herself out; a scrapped ship drops off the screen.
- **Recipes:** shoring kits are gated on Submarines and the shipyard office on Naval Aviation.
- **Sinking:** scuttling the other carrier takes her fittings and leaves this ship's; when this ship sinks her lights, radar, searchlights and levers go down with her.

## Phase 6: arming the aircraft (`arming_probe.dm`)

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/naval_carrier/arming_probe.dm
```

The probe runs explosions at once through a stub of the call-proc scheduler, and steps projectiles by hand, since neither process runs in the fixture.

- **Magazine:** two empty bomb racks stand in the carrier's magazine compartment; the rack takes bombs and nothing else. Bomb casings are a Powered Flight recipe.
- **Filling:** a casing takes ten units of nitroglycerin from a container and refuses less.
- **Mounting:** a Madsen bolts into the light plane's nose and a second gun is refused; a magazine loads through the nose section; one bomb hangs under each wing and a second on the same wing is refused; bombs are not dropped on the ground.
- **Strafing:** the pilot fires the nose gun from the column on the deck; the round leaves the nose, not the pilot's tile, and hits a crate five tiles ahead.
- **Bombing:** after a deck roll into the air the first bomb falls away and bursts, cratering the deck under the plane and its neighbours; the gun cannot be aimed from cruise height; the second bomb follows and the wings are empty.
- **Cook-off:** two bombs racked in the magazine; a heavy blast on the rack sets off the filled one, empties the rack, and the hull wall beside the magazine takes the blast (1000 to 700); an empty rack shrugs off the blast.

Not covered: a real client using the helm menu, the levers or the office, the hop timer firing from the timer subsystem, a full world save and load with the deck turfs written and read by the persistence code, projectile hits on the hull (`bullet_act` is wired but not probed), a strafing run from the air, the searchlights' beams and how the decks look on screen.

## Slipway shipbuilding (`slipway_probe.dm`)

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/naval_carrier/slipway_probe.dm
```

The fixture is the same three levels with sand ashore (x 1-20) and deep sea beyond. See `docs/slipway.md`.

- **Gating and berth:** the slipway recipe is gated on Wagons & Ships; the schooner needs Wagons & Ships and the freighter Combustion; no keel without research, facing along the shore (no water to launch into), with a solid object on the berth or across another berth.
- **Pieces:** a stack pays only the material the next piece needs and keeps the rest; the keel, ribs, hull and deck grow from stern to bow on the 62 berth frames; masts and wheel show as overlays; frames are never saved and come back after a load.
- **Launch:** a wreck on the ways blocks it; the schooner slides 15 tiles to float with a sailor and a crate aboard, the berth is sand again, her wheel and masts stand; she makes half ahead at best and sails without fuel.
- **Freighter:** a 132-tile berth reaching into the water; afloat she has 82 hold and engine room tiles in two compartments, the bunker in the engine room, paired ladders, and stays put with dry bunkers.
- **Dry dock:** a schooner built in a dug trench is refused until the trench is flooded, then floats out; abandoning a project clears the berth.

## Craft core (`craft_probe.dm`)

The shared craft core (`code/modules/craft/`, `docs/craft-core.md`): a craft
with a template body around a `datum/vessel`, its move and turn hooks, drives,
the crew register, berths and tickets, crafts carried on crafts, charts and
plane pools, and steered charts: burns, coasting, the speed limit, stop
orders, a course that arrives and stops, the chart edge, hazard countdowns and
interference, a craft's drives pushing her token, and the helm console saving
and restoring its token.

    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/craft_probe.dm 300

## Ship's papers (`papers_probe.dm`)

The crew register at the wheel (`code/modules/naval/ship_papers.dm`): an
unregistered ship answers to anyone, registering, owners and listed crew at
the wheel, a stranger chained out or forcing the wheel while an owner is
about, the levers and radar, joining, barring, giving the ship up, and the
papers saved and restored by the wheel.

    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/papers_probe.dm 300

## Player-built hulls (`built_hull_probe.dm`)

Floors laid over water commissioned at a tiller (`code/modules/craft/built_body.dm`,
`code/modules/craft/under_way.dm`, `code/modules/naval/built_hull.dm`): what is
and is not a hull, the one-tile gliding step (`code/modules/craft/glide.dm`)
with planks, cargo and crew, the water level handed
from tile to tile, obstacles, the marked path, coming about around the tiller,
refitting, papers, the hull saved and found again by the tiller, sails that
give half ahead, engines that give full ahead and burn from their tank at
every hop, and wiring that stays joined aboard while a cable to the shore
parts.

It also sails a second hull by pixels (`code/modules/craft/vehicle_offset_hull.dm`):
a pixel a pulse with deck, tiller, cargo and crew together, the path marked as
she starts to cover it, her own move half a tile on, a deckhand's walk kept,
things taken off her dropped, whole-tile hops with nobody near, squared for a
save, a turn and all stop, and stopped flush by a rock.

    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/built_hull_probe.dm 300

## Pushing a hull off by hand (`hull_push_probe.dm`)

A built hull run up against a shore (`code/modules/naval/hull_push.dm`): one
person beside a small hull pushes it a tile away from them; a bigger hull needs
the strength of several people heaving together within a few seconds; nobody can
push from her own deck, from deep water, while she is under way or on a voyage,
or into land; she keeps her heading and her cargo and crew go with her.

    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/hull_push_probe.dm 300

## Bilge water (`bilge_probe.dm`)

The hull ledger (`code/modules/naval/hull_ledger.dm`): a hull of up to twelve
tiles is a small craft and stays dry; a wooden boat of thirty tiles holds 120
bucketfuls, seeps 1.35 a minute under way and half that at anchor with a player
aboard, and does not change at all asleep; the water weighs on her drives once
it is past a damp bilge and stops at awash; an empty bucket bails from her own
deck only; a refit keeps the water; the tiller saves and restores it; a steel
hull has no seams; a struck hull leaves no ledger.

Holes and foundering: a floor shot away is a hole and a wall knocked down is
not; a hole lets in 25 bucketfuls a minute while she is awake and takes her past
awash; three quarters full she lists and makes slow ahead at best; a patch takes
two pieces of wood and a hammer, closes the hole and weeps; a holed hull cannot
be refitted; full on deep water she founders, a crew that gets ahead of the
water stops the count, and four half minutes later her floors, tiller and
fittings are lost while her crew, loose things and chests are left in the
water; full in the shallows she settles on the bottom, neither sails nor turns,
and floats again once she is patched and bailed below awash.

One-object craft (`code/modules/naval/small_craft_leaks.dm`): a sound raft
never leaks; below half her strength she leaks, the more the worse; blows leave
a hulk and never break her up; moving swamps a hulk at ten bucketfuls and a
swamped raft or canoe will not move, with her paddler still aboard; wood mends
a raft and cloth an inflatable; land vehicles are untouched.

Caulking (`code/modules/naval/hull_caulking.dm`): a new hull has sound seams;
only time under way wears them, an hour a quarter of the way; her crew is told
when they work loose and when they are open, and open seams let in twice the
water; a coil of rope and ten units of pitch make three twists of tarred oakum;
caulking needs a chisel or hammer in the other hand, her own deck, a hull lying
still and a bilge not awash; one twist tightens three tiles; on deep water she
comes back to sound and no better, in the shallows right down to tight; the
tiller saves and restores her seams; plated hulls neither wear nor caulk.

Bilge pumps (`code/modules/naval/hull_pumps.dm`): a cellar pump on her deck is
hers and one ashore is not; a fired steam pump lifts 80 bucketfuls a minute,
burns a minute of fuel and gets ahead of two holes; a sump pump idles on a dry
bilge, lifts 40 a minute on its battery and nothing switched off or flat; a
lever pump lifts nothing left alone and is worked from beside it; the tiller
counts her pumps.

Load and ballast (`code/modules/naval/hull_load.dm`): a thirty-tile boat has a
burden of fifteen; stone, crates and hands are weighed in the deck walk; past
her burden the extra is hull to push and past twice her burden she ships water
under way, up to awash and not at anchor; a fifty-tile ship with two rigged
masts and no ballast is crank and ships water under sail in a strong wind only,
and two hundred stone cure it; a small craft is not weighed.

Anchors and drift (`code/modules/naval/hull_anchors.dm`): a new boat has no
anchor and nothing holds her; empty she stays put, crewed she drifts a tile
downwind in a wind of 2 and lies quiet in a light one; a killick holds forty
tiles and an iron anchor a hundred; with her anchor up she drifts again; a
bollard within two tiles is a mooring and one at three is not; a record from
before anchors keeps an old anchor and a new record does not; a small craft
needs none.

Rigging (`code/modules/naval/hull_rigging.dm`): a mast starts with full sail;
reefed it pushes six tenths and furled nothing; furled sails survive a gale and
reefed ones a strong wind; a full sail in a strong wind tears, pushes little
until mended and does not tear twice; at anchor nothing tears.

Watch (`code/modules/naval/hull_watch.dm`): the muster names who is at the
helm, at a mast, on deck and in the bow; a lookout calls a floor eight tiles
ahead once and again at four, never at anchor and never from a small craft.

Fouling (`code/modules/naval/hull_fouling.dm`): a clean bottom drags nothing;
a day of use fouls her to four tenths of her tiles in drag; she is scraped
only lying still in the shallows, three tiles a go; fifteen sheets of copper
sheathe a thirty-tile wooden boat and cut the growth to a tenth; the bottom is
saved; a grounded hull and a small craft grow nothing.

Deck awash (`code/modules/naval/hull_awash.dm`): no film on a dry or knee-deep
deck; awash, every plank carries it once; a step never doubles it; bailing
below awash and deleting the ledger both clear it.

    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/bilge_probe.dm 300

## Upper decks on built hulls (`upper_deck_probe.dm`)

A roofed-over built hull (`code/modules/craft/built_body.dm`): fifteen roofs
over fifteen planks, each with its floor on the level above, and a ladder
between the decks; the tiller reads out both decks; a stray floor over the
water is not hers. A step east carries a sailor and a pail on the upper deck,
leaves no floor behind or doubled, keeps every roof paired with its floor and
the ladder joined, and carries the indoor areas under her roofs. A floor or
something solid in the air ahead stops her with the reason; coming about swings
the upper deck whole; crossing the sea is refused. A 200-tile hull roofed over
is past the 300-tile deck cap and refused; with half its roofs taken down
(which takes their floors) it steps four times, and the step time is logged.

    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/upper_deck_probe.dm 300

## Sea chart and harbours (`chart_probe.dm`)

The mirror sea chart and mooring posts (`code/modules/naval/craft_chart.dm`):
hails and running dark (`craft_signals.dm`), grappling and boarding lines
(`craft_grapple.dm`), weather, fog and night at the lookout (`sea_weather.dm`),
chart squares, tokens that follow real ships and posts, the chart read at a
helm with lookout range and a ship running dark, a berth asked for and
refused (too far, not welcome, promised, taken, foul), the marked slide
alongside for a built hull and a slipway ship, mooring, casting off by
sailing, guests, and what leaves the chart.

    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/chart_probe.dm 300

## Vehicles aboard (`ferry_probe.dm`)

A modular car on a built hull (`code/modules/craft/vehicle_aboard.dm`): a hop
carries every part, a turn of the ship leaves the car exactly as a turn of its
own would (compared part by part with a car ashore), it still drives and
steers afterwards, and a car parked half aboard holds the ship until it is
gone.

    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/ferry_probe.dm 300

## Freight contracts (`freight_probe.dm`)

A crate offered at one mooring post for another with a reward
(`code/modules/naval/freight.dm`, `code/modules/craft/contract.dm`): who may
offer, the post taking in crate and reward, a registered crew taking it, the
hand-in and payment at the destination, a broken seal, a lost crate written
off, a withdrawn offer, a crate finding its contract after a load, a full
board and a destroyed post. No client connects, so the post's menus are not
exercised.

    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/freight_probe.dm 300

The same probe covers the freight depot on land
(`code/modules/naval/freight_depot.dm`): it is no berth and no harbour on a
sea chart, a registered vehicle's crew takes freight at it, and a claimed
depot can keep its board to its own party.

## Depot work (`depot_jobs_probe.dm`)

A freight depot's own jobs (`code/modules/naval/depot_jobs.dm`) on a 200-tile
strip of land: which ground can hold a job, spots 60 to 220 tiles off, the
board filling three places once, a survey taken, read, driven in and paid,
lost cargo whose crate only lies out once the job is taken, the two-job
limit, a job given up, a spot that was built over and a destroyed depot. No
client connects, so the depot's menus are not exercised.

    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/depot_jobs_probe.dm 300

## The open sea (`open_sea_probe.dm`)

An open-sea world (`code/modules/naval/open_sea.dm`, `open_sea_sites.dm`,
`open_sea_chart.dm`) on a fixture of six 40-tile cells: cell geometry, tide
races nobody swims, the home island raised once, the cell pool (free means no
site, no ship and nobody there), the chart's sites saved as one text, a hull
that puts to sea, makes passage, raises an island and anchors off it, the
island staying while someone is ashore or a mooring post stands and sinking
when its count runs out, the same island rising the same, a wreck with her
hold, the site cap and the admin pause, standing off when no water is free,
ships in different waters not sighting each other, a passage saved by the
tiller and resumed, the way home, and the harbour office (`sea_office.dm`): its
board on the home island, a survey and a salvage contract taken, done,
paid and saved, a contract given up, and two ships meeting at sea and
parting company.

    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/open_sea_probe.dm 300

`python3 tools/open_sea/make_map.py --check` confirms `maps/sea/open_sea.dmm`
matches the cell size in `code/__defines/naval.dm`.

## Naval mines (`mines_probe.dm`)

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/naval_carrier/mines_probe.dm
```

Linux: `python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/mines_probe.dm`. Blasts are recorded instead of set off (the fixture has no explosion config).

- **Signature:** a freighter is worth 140, a carrier 600, a schooner 0; the reading words; a magnetic mine feels a freighter from 3 tiles but not 4, a carrier from 4 but never 5, a 30 boat only beside it, a wooden hull never; a contact mine only under a hull.
- **Laying:** not on sand or on a hull, yes on open water; a mine is a heavy item.
- **Wooden hull:** worth nothing and the tiller says so; she sails over a magnetic mine, which stays where it was laid and is not counted aboard; a contact mine under her goes off, with the blast on the hull tile over it.
- **Steel hull:** twenty steel plates are worth 20 ("strong"); a magnetic mine three tiles off her course stays quiet, one tile off it goes off under her nearest plate.
- **Submarine:** a Scout is worth 30, the systems report reads it, and a magnetic mine beside her springs two leaks.

## Degaussing (`degaussing_probe.dm`)

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/naval_carrier/degaussing_probe.dm
```

The probe answers the wiping station's wired power itself.

- **Wiping:** the station on the beach finds a steel hull alongside; it asks for cable, takes thirty lengths, does nothing without power, and with power wipes 70% off for twenty lengths (20 shows as 6, "faint", and the tiller says so); ten lengths are not enough for another; the tiller keeps the wipe for a save.
- **Wear:** the wiped hull passes a magnetic mine one tile off her course; ten tiles wear 1% off; with the wipe gone the same mine goes off.
- **Coil:** a running coil takes 80% off; with no engine aboard a built hull trips it out on the next move. On a Scout submarine the coil is switched on by hand, takes 30 to 6, costs a battery unit a tile and trips out on a flat battery; the axis saves the wipe.

## Minesweeping (`sweeping_probe.dm`)

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/naval_carrier/sweeping_probe.dm
```

- **Oropesa:** a sweep must be bolted down and on a deck to stream; under way on a wooden hull it cuts a contact mine two tiles off her side up to the surface, leaves a far one moored, and a surfaced mine still goes off under a hull.
- **Magnetic:** with no engine aboard a built hull the reel goes dead and is wound in; streamed aboard a Scout submarine it sets off a magnetic mine six tiles off, not one nine tiles off or a contact mine, for a battery unit a tile, and goes dead on a flat battery.

## Torpedoes (`torpedo_probe.dm`)

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/naval_carrier/torpedo_probe.dm
```

The probe steps each torpedo itself instead of waiting on timers.

- **Tube:** trained a quarter turn by hand while unbolted; will not fire unbolted or pointed inland.
- **Contact:** strikes a steel hull's side and goes off under it; one tile off her side it runs past and sinks after 40 tiles.
- **Magnetic:** two tiles off a steel hull it does not feel her, one tile off it goes off under her nearest plate, and wiped she lets it run past; it passes close by a wooden hull but still fires on striking her.
- **Own ship:** fired from her deck it leaves past her bow, never goes off under her, even when she looks for mines, and runs past a moored mine; a hull that runs onto a torpedo sets it off.

## Boat davits (`deck_berth_probe.dm`)

    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/deck_berth_probe.dm 300

A davit ashore, a cradle past the deck, a boat out of reach, too big, under way, a blocked cradle and a ship under way are each refused in words. A 3 by 2 boat is hoisted whole with her sailor and crate, is berthed at the davit and carried by the ship, shows as "In her davits" on the chart, cannot sail off the deck, rides a hop and a turn (the cradle turns with the deck), and is lowered over a side with open water, further out when a rock lies where she would land. A destroyed davit lets her go; a vehicle parked wholly in a cradle is carried; crafts nest without rings; a registered ship's davit works only for her crew.

Not covered: the davit's menu in a client, a save and load with a boat in the cradle, a davit on a template ship's deck, and how the lift looks on screen (the boat jumps).

## Chart hazards and sectors (`hazards_probe.dm`)

    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/hazards_probe.dm 300

A harbour sector keeps standing, passing and drifting hazards out by their whole size. A field warns a crew once, strikes a craft above half her top speed and halves it, and leaves a craft lying at a place alone; a strike batters one plank of a built hull to a quarter and never holes her. A squall sets a ship along its wind up to half again her top speed, muddies sensors inside it, drifts, turns back from the chart's edge and the haven, and goes when its countdown ends. A wormhole opens a far twin, throws a craft across, rests, and closes with its twin. Passing hazards come from the chart's table up to its cap and not at all when switched off. The open sea lays the same five reefs every time and the orbit chart four asteroid fields. A sector that forbids boarding stops a grapple.

Not covered: hazards met by a real ship on passage in a running world (the timer), and how any of it reads in a client.


## Berths (`berth_probe.dm`)

Berth upkeep (`code/modules/naval/berth.dm`, docs/berths.md): a wooden hull
lying wholly in a boathouse slip over deep water is held by the boathouse, can
be caulked right down to tight and scraped, and her patches planked over with
one wood or plated with one steel sheet; the same hull out at sea is told to
find the shallows or a berth. The boathouse survey lists her work with costs.
A dugout stored in the boathouse dries three times as fast.

    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/berth_probe.dm 300

## The boathouse (`boathouse_probe.dm`)

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/naval_carrier/boathouse_probe.dm
```

The fixture is sand ashore (x 1-10) and deep sea beyond, with the boathouse at 10,5 on the shore.

- **Slip:** Wagons & Ships gates the recipe; the slip is the 49 tiles of the 7x7 square diagonally north-east of the office.
- **Putting away:** a 3 by 2 boat of ship frames in the slip is offered by name; under way or with a sailor aboard she is refused; a boat lying outside the slip is not offered. Put away, no frame is left in the slip, her axis and the rope on her deck are inside the office, and she is off `ship_axes`.
- **Submarine:** a Scout lying in the slip is offered; submerged or with floodlights on she is refused; stored she leaves `ship_axes` and `player_submarines`, and stays off them when the office's `after_load()` runs after the axis registers itself again.
- **Small boats:** a raft and an outrigger in the slip are offered; the outrigger is put away and a full office (three boats) refuses the raft.
- **Taking out:** a rock or another boat in her tiles keeps a boat in; the Teal comes back on the same six tiles with her cargo where it lay and is a boat afloat again; the submarine comes back with her name, battery and all 15 hull frames; the outrigger comes back where it lay.
- **Wrench:** an office with boats stored does not turn; an empty one turns its slip to the next corner clockwise.

## Ships between worlds (`crossing_probe.dm`)

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/naval_carrier/crossing_probe.dm
```

- **Packing:** a 12-tile hull with a rigged mast, a crate of 20 planks and a crowbar packs into a record; an animal somebody plays keeps her in port and is named, while a rock (a structure) does not.
- **Records:** unknown types, a repeated tile and an overfull stack are refused; a crew payload with her decodes, one with a bad ship does not, and a long payload without a ship is refused.
- **Leaving:** stripped, nothing of her is left and the water is open sea again; planks floating beside her stay.
- **Arriving:** an anchorage is found off a chosen edge (past the sand to deep water); she is built named, at anchor, 12 tiles bow east, with the mast rigged, the crate holding exactly 20 planks and the crowbar where it lay; she is not built twice on the same water; a crew member of her voyage comes aboard, and another voyage's carrier builds her own ship.

## Ships as cargo carriers (`cargo_probe.dm`)

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/naval_carrier/cargo_probe.dm
```

- **One rule:** ghosts and flick overlays are never cargo (`craft_cargo()`), a laid mine stays where it was laid, and crates, machines and animals are cargo.
- **Sailing:** a 12-tile hull with a two-tile hold and a ladder down steps one tile east carrying a crate, a raft, a shopping cart, a microscope, a goat and a crowbar on deck and a cask and planks in the hold; the ghost and the flick overlay on deck stay behind; the ladder stays paired.
- **Packing:** with a hold she packs; the record holds both hold tiles, the raft, cart, microscope and both ladder ends; a hold tile under no deck tile and a ladder entry that is no ladder are refused; a loaded raft keeps her in port.
- **Leaving:** stripped, nothing is left on the water or in the hold and the rock closes where the hold was.
- **Arriving:** an anchorage with rock under her hold is found; she is built with her two hold tiles, the ladder paired, the planks and the cask (still holding its water) in the hold and the raft, cart, microscope and goat on deck; she sails on with her hold. Over dirt she is built without a hold, the hold's cargo is stowed on the deck above, and no ladder is left leading to nothing.
- **Engines:** a 5000cc diesel with its barrel of 200 diesel no longer keeps a hull in port; the record holds an engine entry, a tank offset past one tile is refused, and she is rebuilt with the same engine (size, power, name), stopped, coupled to its barrel with the diesel, and fitted as a drive. `slipway_probe.dm` also packs the freighter with her 82-tile hold and diesel.
- **Whole cargo:** a raft, dugout, outrigger, shopping cart, carriage, microscope and washing machine each round-trip as a deck cargo record.

## Voyages on the world chart (`voyage_probe.dm`)

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/naval_carrier/voyage_probe.dm
```

- **The crew's chart:** a crew sails for their faction; the seen mask shows only that owner's tiles; only a seen land with a coast is offered, with its size, biome and voyage time from this world's pinned tile; scouting turns round within the chart.
- **Setting out:** no voyages outside a region group or from a land across the sea; she sets out at anchor, and the tiller tells how long is left.
- **Landfall:** with no answer, while the land is being opened, or while its world does not answer, she waits off the coast; she turns back after waiting too long or at once when the course is refused.
- **Sea routes between the continents (`sea_lanes.dm`):** distances and compass bearings from the shared layout; unknown lands have no route and a land with no coast is not offered, nor a stopped one; an up one is, with its name, bearing, region and sailing time; landfall tries the coasts facing where she came from first; she sets out with no chart owner, the lookout sights nothing on a route, she waits off a coast whose world is down and turns back after waiting too long.
- **A land across the sea:** voyages sail on from the land's own chart tile; a settled land is on every chart and the land she lies off is not offered; settling needs a mooring post and 3 beds slept in by different people within 40 tiles of it; a settled land, or the mainland, is never undecided.

## Holding her course for a woken land (`voyage_hold_probe.dm`)

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/naval_carrier/voyage_hold_probe.dm
```

The host doorman, peer polls, the transfer agent and the sea-crossing gate's departures are stubbed in the probe and counted; nothing is woken or sent.

- **Two crews, two lands:** while the doorman is asked for Far One the other crew member's crossing to Far Two, a stale Leave these waters prompt, a stale voyage prompt and Turn back are refused; once the slow wake is accepted the tiller shows "Bound for Far One", a second crossing to the same land waits on the first, failed polls keep her waiting, and when Far One answers both crew (logged out, but aboard when she set out) leave on the same voyage. Far Two gets zero wake requests.
- **Refusal:** a definite doorman refusal holds nothing, Turn back works again and the crew may choose another land.
- **Stale continuation:** a crossing whose hold was replaced comes back "called off", without moving her or clearing the newer hold.
- **Lost reply:** no doorman reply holds her for Far One and Far Two is not asked; when the wake runs out she is free and still there.
- **Late readiness:** after a wake ran out her voyage still holds Far One, and when it answers late she crosses with no second wake.
- **Retry:** a crew problem after the wake keeps her bound (no Turn back); the retry crosses on the first wake.
- **Courses:** while a course is plotted another course or crossing waits; with no answer she sails on it unconfirmed and asks again under way with the same voyage id; Turn back before landfall and scouting are unchanged.

## Sea lighting behind a ship (`sea_lighting_probe.dm`)

```bash
python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/sea_lighting_probe.dm 300
```

A slipway schooner hops three tiles north over lit deep sea. Every tile of sea she leaves still has its lighting overlay once deep water's six-second sinking delay has passed, and a dropped item still sinks. Before the fix deep water sank the overlays carried onto the restored turfs, and the water behind her drew black.
