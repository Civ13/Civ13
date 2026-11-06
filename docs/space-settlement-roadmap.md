# Space travel and off-world settlement: phased roadmap

Status: **design only, nothing implemented.** Written 2026-11-05 against master
`e069aae` (after #3745). Val asked (2026-11-05) for the roadmap to include going
to space, building a base and living there, with the feature set of a
Mars-colony simulator such as Bohemia Interactive's *Take On Mars*. No phase
starts until Val picks one. This document does not authorize merging,
deployment, live-server work or feature activation.

It replaces the "Advanced-era space mode" row of the
[roadmap completion plan](roadmap-completion-plan.md), which was waiting on an
altitude/orbital model design.

## Ground rules

- **Mechanics only.** The reference game is a checklist of systems, not a source.
  Civ13 uses its own names, rules, numbers, maps, sprites and sounds. No names,
  vehicles, mission text, UI layout, art or audio from that game or its studio.
  New art is drawn with graphic tools or reuses Civ13 art; no image generation.
- **Civ13's identity stays.** Things are physical items with material, quality
  and condition. Bases can be raided, sabotaged and starved. Power comes from
  fuel, weather and reactors. Nothing is solved by a menu that a structure could
  do instead.
- **Fictional destination.** The settled world is an original, unnamed-in-code
  "barren world" profile (cold, thin unbreathable air, dust, ice under the
  regolith). A Mars-like look is fine; real NASA/ESA hardware names are not used.
- **Default off.** Every phase lands behind a config flag or an inactive map
  entry until Val turns it on.

## Feature checklist

The genre's systems, and where each lands:

| System | What players do | Phase |
| --- | --- | --- |
| Uncrewed probes | Build a probe, launch it, drive it remotely, photograph and sample sites | 1 |
| Science from samples | Analyse samples for research progress and site knowledge | 1 |
| Launch and landing | Build a launch site and a crewed lander, fuel it, choose a landing site | 2 |
| Habitat modules | Place pressurised modules: living quarters, airlock, greenhouse, workshop, store | 3 |
| Life support | Keep oxygen, CO2, pressure, heat, power, water and food in balance | 3 |
| Power | Solar panels, battery banks, an isotope generator for night and storms | 3 |
| EVA suits | Pressure suit with air tank, heater battery, suit integrity and repair | 4 |
| Surface hazards | Dust storms, extreme cold, radiation events, small meteor strikes | 4 |
| Rovers and drones | Pressurised and open rovers, survey drones, trailers | 5 |
| Mining and refining | Drill regolith, ice and ore; refine into water, gases, metals | 5 |
| On-site fabrication | Print parts and modules from local feedstock | 5 |
| Self-sufficiency | Closed-loop recycling, local propellant, return trips, more bodies | 6 |
| Co-operative colony | Several players share and defend one base | All (Civ13 is multiplayer by default) |

## What Civ13 already has

| Need | Existing source | Gap |
| --- | --- | --- |
| A separate world to settle | Shard groups (#3694), playable generated maps (#3697), procedural surface/oceanic/cavern profiles (#3331, #3338, #3617) | No barren-world generator profile |
| Getting there | Region gates and character transfer (#3715), fast travel journal (#3720), goods via trade post (#3655) | Gates are admin-placed; player-built trail gates (admin-approved) are next on the sharding track |
| Living there | One home world per account, mainland start, bed keeps the home (#3740) | Nothing specific to hostile worlds |
| Research gating | Research tree nodes, Digital Age ordinal 9 (#3736), 3D printer (#3743), drones and consumer electronics (#3745) | No space branch |
| Power | Cable grid and batteries (`code/modules/1713/machinery/`), renewables (#3603), nuclear generation | No storm/night coupling for solar off-world |
| Food | Hydroponics design and trays ([design](hydroponics-design.md)) | Off-world nutrient and water supply |
| Atmosphere | Inherited `xgm` gas mixtures (`code/modules/xgm/`); submarine compartments now each hold one habitat air ledger (`code/modules/submarine/`) | `xgm` not reused: Val asked (2026-11-05) for a streamlined, highly efficient system instead of SS13-style atmospherics. Habitats and submarines use the module ledger (below) |
| Vehicles | Modular vehicle frames and car workshop (`code/modules/1713/machinery/modular_vehicles/`) | No sealed cabin or battery drive |
| Chemistry and fuel | Chemistry processing and automation ([design](chemistry-automation-design.md)), fracking, refining | No cryogenic propellant |
| Mining | Resource extraction, dug underground (#3742) | No off-world ore or ice tables |

## World model

**The barren world is its own shard.** It is a region in a shard group with a new
generated-map profile, not extra levels on Gaia. This keeps Gaia's 32-bit load
peak unchanged (currently ~1.9 GB at worst) and fits the one-home-world-per-account
rule: a settler's home becomes the barren world only when they claim a bed in a
pressurised habitat there; with no claimed bed, death sends them back to the
mainland like any other region.

- **Size.** Start at about 200 x 200 x 2 (surface plus one dug level), roughly a
  quarter of Gaia's cells, and measure load peak before growing.
- **Terrain.** A barren skin over the validated surface family of
  `tools/procedural_maps`: regolith plains, dry channels, ridges and frozen
  lakes, no vegetation, no wildlife. Ore seams and buried ice come with mining
  in phase 5. Turfs are cold and have no breathable air.
- **Outside air.** No per-turf gas simulation outdoors. "Outside" is a turf
  property (`outside_air_breathable()` and `outside_ambient_c()` on `/turf`),
  so the outdoor world costs nothing per tick.
- **Atmospherics.** Deliberately not SS13 atmospherics: no per-turf gas
  mixtures, no zone merging or tile-to-tile flow, no pipe gas networks and no
  dependence on `code/modules/xgm`. A whole base is a few ledgers of plain
  numbers, each updated once per step while the world has players, so cost
  scales with modules, not tiles. Breaches vent and modules cool whether or
  not anyone is inside (a leak does not stop because the crew went out to
  patch it); only breathing counts the people in the module. Nothing ticks
  while the world is empty. Machines (electrolyser, scrubber, heater, tanks)
  act on a ledger directly, and hatches mix two ledgers.
- **Inside air.** Each sealed habitat is a **module ledger**: one small datum per
  connected pressurised volume with oxygen, CO2, pressure and temperature as
  plain numbers. Turfs ask their module for air through a module id stamped on
  the turf, as submarine decks carry a compartment id, never a reference to
  the ledger datum. This avoids the unsolved per-turf atmosphere save problem:
  the ledger saves as a few scalar fields on the module's anchor structure, and
  on load each anchor flood-fills the turfs it encloses and stamps them, so
  turfs save nothing new.
- **No saved world.time.** Life support, suit tanks and timers store remaining
  amounts, never `world.time` stamps (restored stamps have broken things before).
- **Saves policy.** The barren world follows the project rule: autosave only when
  empty or host-only, otherwise admin save or a player vote at most every 30
  minutes. Because a crash loses up to that window, life support never ticks
  while no player is connected, and a frozen or sleeping world (the
  freeze-dd.exe plan) resumes without catching up on the clock gap.

## Travel rules

- **Launch sites are trail gates with rockets.** A launch site is a player-built
  structure that stays inactive until an admin approves it, exactly like the
  planned trail gates. The destination is fixed per approved site.
- **Departures are region travel.** A launch sends the crew as character
  payloads through the existing transfer agent and journal; cargo goes through
  the goods path with a mass limit per lander. The vehicle itself does not
  travel; a matching landed-lander structure is placed at the destination.
- **Landing.** The crew picks a landing zone from surveyed sites (phase 1 probes
  reveal sites). Unsurveyed landing has a higher chance of a rough landing that
  damages cargo.
- **Home and death.** A settler's home moves to the barren world only through a
  claimed bed (#3740). Because nobody can fly back before phase 6, a settler who
  dies with no claimed bed there, or whose last bed is destroyed, respawns on the
  mainland with no way back to the base. So the landed lander carries a
  claimable bunk and counts as pressurised for bed claims: claiming home is the
  first thing a crew can do after landing.
- **Propellant.** Rocket propellant is mixed from hydrazine and nitric acid
  (2:1, both from the chemistry line). Since phase 2 the launch rail and the
  crewed lander burn only propellant; phase 1 probes burned gasoline or diesel
  as a placeholder.
- **Return.** A return trip needs propellant at the landing site, produced
  locally from phase 6 on. Whether propellant carried as cargo may also allow
  earlier returns is decision D3; the recommendation is no, so early settlers
  stay. Without propellant, settlers stay.
- **No default shuttle.** As with ferries, there is no free service between the
  mainland and the barren world; players build and fuel every trip.

## Phases

Each phase is one or more PRs with its own tests, compiled and run through
`scripts/agent_preflight.py all --write`, with a filled `Changelog:` line once
players can see it.

### Phase 0: foundations (inactive)

Val chose phase 0 then phase 1 on 2026-11-05.

- Habitat air ledger (`code/modules/space/habitat_ledger.dm`), barren ground
  turfs and the barren outdoor area (`code/modules/space/barren_world.dm`), tested by
  `tests/space_settlement/probe.dm`. Nothing places barren ground yet; submarine
  compartments (SUBCOM13) are the first ledger users, one ledger per compartment.
- The Spaceflight research branch moves to phase 1, where its first nodes
  unlock the probe recipes, so players never see empty nodes.
- Barren region maps: `preset --barren` and `playable --skin barren` in
  `tools/procedural_maps` turn the validated surface family into regolith
  plains, frozen lakes and sea, dry channels and bare ridges, with rocks only
  ([procedural maps guide](procedural-maps.md#barren-worlds)). A region
  runs one with `kind` `OTHER`, never as the mainland.
- Memory measurement of a 200 x 200 x 2 barren world on the pinned compiler.

Measured 2026-11-05 with the headless memory probe (fresh round, no save, no
clients, pinned 516.1688 on Linux, same build for both maps):

| Map | Turfs | Objects | Map loaded | Playing, +3 min |
| --- | --- | --- | --- | --- |
| Barren, 200 x 200 x 2 (`preset --barren`, seed `barren-0`) | 80,000 | 45,752 | 197 MB | 231 MB |
| Gaia, 500 x 350 x 2 | 350,000 | 9,568 | 256 MB | 423 MB |

The barren world adds about 86 MB to the 145 MB both runs used at global init,
about a third of what Gaia adds (278 MB). Most of its objects
are the dense basalt of the underground reserve plane. At the barren rate
(about 1.1 KB per turf) a 350 x 350 x 2 barren world would reach roughly
410 MB, still under Gaia, so steady-state memory does not limit the size. Save and
load peaks were not measured, because the world has no saved state yet; they
come with phase 3, when there is something to save.

### Phase 1: probes and surveys

- Craft a small lander probe and a launch rail; the probe departs and lands
  on the survey map.
- A mission console shows a survey map of the barren world (drawn from a
  barren bundle's terrain, no extra level); the player drives the probe across
  it, photographs sites and takes samples. Batteries and comms range limit
  each sortie.
- Samples return as research material for the Spaceflight branch and mark
  landing sites as surveyed.
- Built (phase 1): Rocketry unlocks the launch rail, survey probe and mission
  console. A rail takes a probe and 60 units of fuel (gasoline or diesel in
  phase 1, rocket propellant since phase 2) and launches it to an idle console
  within 7 tiles. It lands anywhere flat, or, when the rail is aimed, on a plain
  within 2 cells of the aimed cell. Survey maps are keyed by destination region
  (`config/space/survey/<region>.json`, `barren` for now; the rail's
  `destination` var picks one) and record the source bundle's `ir_sha256`;
  `survey_map_matches_bundle()` and `survey-check` compare it with a region
  bundle. Region groups ship `.dmm` maps, not bundles, so the game cannot see
  the bundle; whoever generates a barren region runs `survey-check` on its
  bundle before admins approve launch pads to it.
- Driving: moves cost 1 battery on plains, 2 in channels and 3 on ice, ridges
  block, and the probe stays within 12 cells of its landing site. Solar panels
  give back one point every 3 seconds (a tmp clock, so no backlog after a
  restart). Each move risks an 8% relay dropout that loses the command and 1
  battery, and a 3% dust gust that halves recharge for the rest of the sortie;
  the advanced probe's hardened relay never drops commands.
- Photographs print a survey record; the drill takes up to 3 samples
  (regolith, rock beside ridges, sediment, ice); the ascent stage at the
  landing site drops the samples by the console and ends the mission. The
  console keeps a survey record across missions (cells seen, sites cored and
  photographed, landing sites) for phase 2 to pick landing zones from; it
  resets only when the survey map changes, and a cored site stays cored.
- The console analyses a sample into research notes on Planetary Survey,
  worth 1.5x ordinary notes for ice, 1.25x for rock, 1x for sediment and 0.75x
  for regolith, and half again for the first sample of each kind. Planetary
  Survey unlocks the advanced probe (160 battery, 18-cell hardened relay, wider
  camera, 5 samples). It is an ordinary node, not a prototype node, because
  prototype nodes are the era-changing capstones. Later phases can ask for a
  sample kind as a recipe gate (an ice core for the ice melter).
- D1, decided 2026-11-05: a console survey map, not a real level. An extra
  level costs Gaia about 150 MB on a server that peaks near the 32-bit limit
  at load.

### Phase 2: launch and landing

- Launch site construction (admin-approved), crewed lander with seats and a cargo
  hold, propellant from the refinery and chemistry lines.
- Crew and cargo transfer to the barren world with the travel rules above.
- A landed lander is a small sealed shelter with a few hours of air and power:
  enough to set up the first module, not to live in. It holds one claimable
  bunk so the crew can make the barren world home at once (see travel rules).
- Propellant reagent and recipes replace the probe rail's gasoline.
- Built (phase 2, `code/modules/space/lander.dm`): Crewed Flight (after
  Planetary Survey) unlocks the launch pad and the crewed lander. A launch pad
  is a trail marker that can only lead to a region with a survey map
  (`config/space/survey/<region>.json`); the first player to use it asks for
  a destination and an admin approves it, as with trails. A crewed lander built
  beside an approved pad takes 300 units of rocket propellant and seats four:
  crew strap in on its tile and any of them launches, choosing a probe landing
  site from a mission console within 7 tiles or "anywhere flat". Each crew
  member then travels as an ordinary region traveller (what they wear and
  carry, under the usual travel rules), and the payload adds the lander id,
  the landing survey cell and whether the site was surveyed. A rough landing
  (5% on a surveyed site, 50% unsurveyed) costs each crew member 15 brute.
  The cargo hold takes up to 20 stowed items (use an item on the lander;
  Unload hold sets them down): anything region travel allows, plus glass,
  plastic, electronics and water ice stacks, module kits, hull and suit patch
  kits, suit air tanks, survey probes and rover batteries. The hold rides in
  the first departing crew member's payload as `cargo` entries and is
  unpacked in a crate beside them on arrival (or back at the pad if the trip
  is refused). Anything that can no longer fly is left on the pad.
- The first arrival of a flight builds the landed lander in its survey cell
  (one cell is 5x5 tiles; the first spot in the cell with a clear 3x3, else
  its middle) on the top barren level; later arrivals join it. It lays a 3x3
  sealed deck with a bunk that can be claimed as a home bed. The deck turfs
  answer the outside-air hooks from the core's cabin ledger (volume 9), so
  there is no per-tile air. The core holds three hours of power and enough
  oxygen and scrubber reserve for four people over that time; with power it
  tops the oxygen back to 21 kPa, scrubs CO2 below 0.4 kPa and holds 20 C.
  Without power the cabin goes stale and cools toward -60 C. The cabin saves
  as plain numbers on the core and ticks only while someone is connected.

### Phase 3: habitat and life support

- Habitat modules built from prefabricated kits: quarters, airlock, greenhouse,
  workshop, storage. Modules connect through hatches and share a ledger when open.
- Oxygen from electrolysis of water, CO2 scrubbers, heaters, leak sealing and
  breach repair.
- Power: solar panels, battery banks and an isotope generator from the nuclear
  line. Night and dust storms cut solar output.
- Water: melt mined ice, recycle grey water. Food: hydroponics trays inside the
  greenhouse, using the hydroponics design.
- Beds inside a pressurised module can be claimed, which makes the barren world
  the settler's home. The greenhouse ledger ticks with nobody inside, so plants
  breathe and the module cools like any other.
- Built (phase 3, `code/modules/space/habitat_modules.dm`): Sealed Habitats
  (after Crewed Flight) unlocks module kits (quarters with two bunks,
  greenhouse with two hydroponics trays, workshop with a bench, storage with
  two crates, airlock) and the hull patch kit; Life Support unlocks the
  electrolyser, CO2 scrubber and heater. A kit used where you stand unfolds a
  5x5 module around you: a 16-tile hull around a 3x3 floor with a core in the
  middle, pressurised with sea-level air. Within 6 tiles of a module it snaps
  to dock beside it; docked modules share a wall with a hatch in its middle.
  An airlock's outer hatch faces away from the module it docks to.
- Each module is one ledger saved as plain numbers on its core; floor tiles
  ask the core beside them (hatch tiles a neighbouring core), so no tile
  carries gas and nothing is stamped on load. Every core ticks while players
  are connected. A hull tile that is not wall or a closed hatch is a breach;
  an open hatch into a docked module mixes the two ledgers. The airlock core's
  hand pump moves its air into the module next door (pump down) and back
  (pressurise), keeping 95% each way, and needs every hatch shut. A hull patch
  kit closes a breach.
- Life support machines inside a module draw cable power (cable comes in
  through an open hatch): the electrolyser makes 0.1 kPa-tiles of oxygen a
  second from 0.5 units of water each, up to 21 kPa; the scrubber removes 0.1
  of CO2 a second down to 0.4 kPa; the heater warms 0.5 C a second up to
  20 C. Each growing plant in a module turns 0.005 of CO2 into oxygen a
  second, half a person's breathing. Power comes from the existing grid, and
  the existing solar controllers already lose output at night and in dust
  storms (extreme weather in the barren desert climate). Not built yet: water
  from ice (phase 5), grey water recycling, an isotope generator, and roofs
  over modules.

### Phase 4: EVA and hazards

- Pressure suit, helmet, air tank and heater battery; suit integrity drops from
  hits and sharp terrain and is patched with a repair kit.
- Exposure: no suit outside means suffocation and cold; low tank and low
  battery warnings on the HUD. The exposure step already exists
  (`code/modules/space/outside_exposure.dm`): the human life tick reads the
  turf's `outside_air_breathable()` and `outside_ambient_c()`, and a suit
  overrides `sealed_against_outside()`. Suffocation knocks a conscious person
  out in about a minute (D4), so crewmates can drag them inside.
- Hazards: dust storms (vision and solar loss), cold snaps, radiation events
  (shelter indoors), small meteor strikes that can breach modules.
- Built (phase 4, `code/modules/space/pressure_suits.dm` and
  `surface_hazards.dm`): Pressure Suits (after Sealed Habitats) unlocks the
  pressure suit, pressure helmet, suit air tank and suit patch kit. Suit,
  helmet and a tank with air on the back seal the wearer: each life tick on
  unbreathable ground draws 2 seconds from a 30-minute tank, and the suit's
  two-hour heater battery holds 20 C (a flat heater still insulates 30 C).
  Hits of 3 or more brute or burn take half their damage off the suit's
  integrity, and crater rubble sometimes scrapes it; at 25% the suit leaks
  (the tank empties three times as fast) and at 0 it no longer seals. A patch
  kit restores 50%. The tank refills from a module core (only the oxygen
  above the breathable minimum) or a landed lander's reserve; the heater
  recharges at a powered habitat heater. Warnings come at 5 and 1 minute of
  air and at 10 minutes of heater, and the Status panel shows integrity,
  heater and air. Hazards roll once a minute while a module or lander is
  ticking: dust storms (10 min) blur sight on open ground and cut barren
  solar to a fifth, cold snaps (15 min) drop the surface 35 C, solar flares
  (4 min) irradiate people on open ground (the suit blocks 60%, a module or
  lander all of it), and meteorites hole a barren-area module's hull with a
  patchable breach. Hazard timers are not saved; a restart ends them. The
  suits reuse the existing astronaut sprites and the tank has no worn sprite.

### Phase 5: rovers, mining and fabrication

- Rovers from the modular vehicle frames: an open rover and a sealed rover with a
  small ledger cabin and battery drive; cargo trailers.
- Survey drones reuse the Digital Age drone controller.
- Drill rigs for regolith, ice and ore; refining into water, oxygen, metals and
  glass; off-world ore tables.
- The 3D printer prints spare parts and module kits from local feedstock, so
  settlers stop depending on mainland cargo.
- Built (phase 5 mining, `code/modules/space/surface_mining.dm`): any
  industrial drill on regolith uses the barren ore table (iron, water ice,
  sand, stone, copper, sulphur; no gold, silver, tin, coal or lead).
  Off-world Mining (after Pressure Suits) unlocks a regolith drill rig (60
  power, open regolith only) and an ice melter (5 power, one piece of ice
  makes 20 units of water, 400 unit tank, draw with an open container). The
  electrolyser also takes ice directly. Local iron smelts into steel and sand
  into glass with the usual chains, and the 3D printer prints hull and suit
  patch kits (plastic), suit air tanks (steel) and habitat, greenhouse and
  airlock module kits (steel and glass, after Off-world Mining).
- Built (phase 5 rovers, `code/modules/space/surface_rovers.dm`): combustion
  engines no longer start where there is no air to burn. Surface Vehicles
  (after Off-world Mining) unlocks a rover assembly bay (a car workshop that
  builds only rovers, each with a charged battery pack) and a cabled rover
  charger that adds 150 charge to a parked rover's 450-unit battery per use.
  Both rovers use the existing four-tile jeep body and an electric drive
  that runs on battery charge. The open rover has a cargo bed; the sealed
  rover's cabin is one habitat ledger on its axis shared by everyone on its
  frame tiles, with open doors counted as breaches. While the battery has
  charge the cabin panel tops oxygen up from a reserve (four person-hours
  when built, refilled by emptying suit air tanks into the panel), scrubs
  CO2 and holds 20 C. On breathable ground the cabin is ignored. A cargo
  trailer (Surface Vehicles, 20 steel) is a 40-capacity crate that hitches
  to any car or rover beside it and closes up a tile behind after each move;
  it comes loose if it falls more than 3 tiles behind. Not built: dedicated
  survey drones (the existing drone controller works on any map).

### Phase 6: self-sufficiency and expansion

- Closed loops: water and air recycling efficiency, composting into greenhouse
  nutrient.
- Local propellant plant (water ice into fuel and oxidiser) enables return trips
  and supply runs to the mainland.
- More bodies as further profiles (a small airless moon, an ice body), each on
  its own shard.
- Balance pass with live data.
- Built (phase 6 loops and propellant, `code/modules/space/self_sufficiency.dm`):
  Life Support adds a water recycler (5 power) that reclaims 0.02 units of
  water per occupant per second into a 200-unit tank, tops up the module's
  electrolysers first and gives the rest to an open container or to pipes
  (electrolysers are pipe sinks, so modules can share water), and an oxygen
  reclaimer (15 power) that scrubs CO2 like the scrubber and returns half of
  it as oxygen. Composting into greenhouse nutrient already worked in module
  trays. Local Resources (after Surface Vehicles) unlocks a propellant plant
  (30 power) that holds 100 pieces of water ice and cracks one piece into 5
  units of rocket propellant per tick while someone is playing, into a
  300-unit tank, enough for one lander. A launch pad on a mapped world can be
  pointed home at the mainland region; that flight needs no survey map and
  lands like any traveller at the mainland's arrival point. Not built: the
  balance pass, which needs Val.
- Built (second body): the barren region is Mars, and the Moon is its own
  world (`code/modules/space/moon_world.dm`, region id `moon`,
  `maps/space/moon.dmm`): grey lunar regolith at -100 C, no weather and no
  dust storms, with every phase 1-6 system working there unchanged because
  its ground, area and map settings are barren subtypes. A launch rail picks
  its destination among the shipped survey maps, and a mission console keeps
  a survey record per world. Epochs (Val, 2026-11-06): the Moon is reachable
  from 1969 and Mars from 2026, for probes and crewed flights alike; flights
  home are never closed. Several Moon colonies linked by trains and paths
  are planned in [connected regions](connected-regions-plan.md).

## Research branch

Original node names, all era 9 unless Val chooses a later age (D2):

| Node | Unlocks | Phase |
| --- | --- | --- |
| Rocketry | Launch rail, survey probe, mission console | 1 |
| Planetary Survey | Advanced survey probe | 1 |
| Crewed Flight | Launch pad, crewed lander | 2 |
| Sealed Habitats | Habitat module kits (hatches come with docking), airlock, hull patch kit | 3 |
| Life Support | Electrolyser, scrubber, heater, water recycler, oxygen reclaimer | 3, 6 |
| Pressure Suits | Suit, helmet, air tank, repair kit | 4 |
| Surface Vehicles | Open and sealed rovers, rover charger | 5 |
| Off-world Mining | Regolith drill rig, ice melter, printed module kits | 5 |
| Local Resources | Propellant plant | 6 |

## Decisions for Val

1. **Which phase to start.** Decided 2026-11-05: phase 0, then phase 1. Probes give
   players something to do before the hard life-support work, and phase 0's
   load measurement decides the world size.
2. **D1 - where probes drive.** Decided 2026-11-05: a console survey map with
   no extra level (an extra level costs Gaia about 150 MB). Rejected: a
   survey level in the launching world, and driving on the real barren shard
   (needs cross-shard remote control).
3. **D2 - which age.** Recommended: Spaceflight as a branch of the 2026 Digital
   Age (ordinal 9). Alternative: a new ordinal 10 "Space Age", which needs the
   same age-addition work as #3736.
4. **D3 - one-way or return trips first.** Recommended: return trips only after
   phase 6 local propellant, so early settlers commit to living there.
5. **D4 - how deadly suit failure is.** Recommended: unconsciousness and heavy
   damage over about a minute, giving crewmates time to drag someone inside,
   rather than instant death.
