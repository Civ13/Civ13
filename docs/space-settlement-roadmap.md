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
  The cargo hold is left for a later PR: crew carry what region travel allows.
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

### Phase 5: rovers, mining and fabrication

- Rovers from the modular vehicle frames: an open rover and a sealed rover with a
  small ledger cabin and battery drive; cargo trailers.
- Survey drones reuse the Digital Age drone controller.
- Drill rigs for regolith, ice and ore; refining into water, oxygen, metals and
  glass; off-world ore tables.
- The 3D printer prints spare parts and module kits from local feedstock, so
  settlers stop depending on mainland cargo.

### Phase 6: self-sufficiency and expansion

- Closed loops: water and air recycling efficiency, composting into greenhouse
  nutrient.
- Local propellant plant (water ice into fuel and oxidiser) enables return trips
  and supply runs to the mainland.
- More bodies as further profiles (a small airless moon, an ice body), each on
  its own shard.
- Balance pass with live data.

## Research branch

Original node names, all era 9 unless Val chooses a later age (D2):

| Node | Unlocks | Phase |
| --- | --- | --- |
| Rocketry | Launch rail, survey probe, mission console | 1 |
| Planetary Survey | Advanced survey probe | 1 |
| Crewed Flight | Launch pad, crewed lander | 2 |
| Sealed Habitats | Habitat module kits, hatches, airlock | 3 |
| Life Support | Electrolyser, scrubber, heater, water recycler | 3 |
| Pressure Suits | Suit, helmet, air tank, repair kit | 4 |
| Surface Vehicles | Open and sealed rovers, trailers | 5 |
| Off-world Mining | Drill rigs, ice melter, regolith refinery | 5 |
| Local Resources | Propellant plant, printed module kits | 6 |

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
