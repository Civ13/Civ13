# Subcom13 (Submarine Commander)

## Introduction

**Subcom13** is a submarine warfare simulation mode set on a fictional 1000x1000 nautical mile coordinate grid. You command a submarine (or crew one with other players) and must navigate the open ocean, engage hostile surface and air contacts, manage your ship's reactor and crew survival, and complete objectives relayed to you over encrypted radio.

The mode features:

- **Real-time navigation** on a virtual overworld map with heading, speed, and depth control
- **Nuclear and diesel-electric** submarine propulsion options
- **Weapons systems**: torpedoes with acoustic homing, fire control consoles
- **Sensor suites**: passive and active sonar, surface radar
- **Environmental simulation**: hull breaches, flooding, water accumulation, and atmospheric pressure
- **NPC hostile contacts**: surface combatants, aircraft, and enemy submarines with AI
- **Mission objectives**: sink cargo ships, patrol sectors, escort allies, recon, rescue, and ambush
- **Crew management**: track individual crew health, oxygen status, injuries, and assignments

---

## Getting a round

Submarine Commander is in the **PvE** group of the map vote, next to Antarctica and Lights Out. Vote for the PvE group first, then for Submarine Commander, and the next round starts aboard the boat.

## Your first watch

Assign navigation, sensors, weapons, propulsion and damage-control duties before getting underway. Check the submarine's current depth, target depth, power supply and compartment condition. Read mission orders before engaging a contact. Report flooding and oxygen problems immediately so the crew can coordinate repairs and recovery.

Depth is measured downwards: a larger target depth takes the submarine deeper. To move towards the surface, choose a smaller depth value.

## Submarine Controls

Your submarine is controlled from the bridge consoles. Each console is an `Alt+Click` interaction.

### Helm Control Station

The primary navigation console. Controls heading, speed, and depth.

| Control | Description |
| :--- | :--- |
| **Target Heading** | Set in degrees (0-359). The sub turns toward this heading automatically. |
| **Target Speed** | Set in knots. Your sub accelerates/decelerates toward this value. |
| **Target Depth** | Pre-set depth buttons: Surface (0m), Periscope (15m), Deep (150m), Crash Dive (250m). |
| **Visibility Status** | Shows "NOT VISIBLE", "PERISCOPE DEPTH", or "SURFACED" based on current depth. |
| **Diesel Throttle** | Controls diesel engine output (visible when surfaced). Adjust in ±5/±10 increments. |
| **Emergency Blow Ballast** | Vents all ballast tanks and sets target depth to surface. The sub rises at 1m/tick (25 seconds from max depth). |

```admonish tip
Diesel-only submarines can only produce propulsion power when surfaced. Submerged, you run on battery at reduced speed (8 knots max).
```

### Reactor Control Station

Manages the two nuclear reactors. Each reactor operates independently.

| Control | Description |
| :--- | :--- |
| **Control Rods** | 0-100%. Lower = more heat, more power. 100% = fully inserted (shutdown). |
| **Primary Pump** | Coolant flow rate (0-18 RPM). Higher = better heat dissipation. |
| **Secondary Pump** | Turbine steam flow (0-10 RPM). Determines power output in MW. |
| **SCRAM** | Emergency shutdown. Inserts rods to 100% instantly. |

**Reactor Meltdown**: If core temperature exceeds 1000 C, the reactor melts down. This creates an explosion in the reactor room, a lethal radiation burst, and fire. The meltdown is permanent and disables that reactor. All crew on the submarine feel the screen shake.

**Flooding Effects**: When the reactor room floods, coolant pump effectiveness degrades proportionally (100% at 0cm water, 0% at 100cm). Power output is also reduced. At 100cm water depth, both reactors are automatically SCRAMMED.

```admonish danger
Never pull control rods below 25% without sufficient primary pump speed. Heat will spiral out of control and cause a meltdown within seconds.
```

**Power Output**: You need at least 5 MW total (combined from both reactors) to run the nuclear turbines for full-speed propulsion (30 knots).

### Auxiliary Systems Console

Controls environmental systems and battery power.

| Control | Description |
| :--- | :--- |
| **O2 Generator** | Toggles electrolysis. Generates oxygen across all compartments. |
| **Battery** | Current charge / max capacity in kWh. Drains when running on electric power. |
| **Ventilation** | Per-compartment vent controls. Open/close vents to equalize air between rooms. |
| **Fire Suppression** | Activates fire suppression in a compartment. |

### Radar Console

Surface detection system. **Only works when surfaced.**

| Control | Description |
| :--- | :--- |
| **Power** | Toggle radar on/off (surface only). |
| **Range** | Toggle between Short (25km) and Long (70km). Long range uses more power. |
| **Detected Contacts** | Shows surface contacts: name, range, bearing. |

### Sonar Console

Underwater detection system. Works at any depth.

| Control | Description |
| :--- | :--- |
| **Power** | Toggle sonar on/off. |
| **Mode** | Toggle between **Passive** (stealth, detects all contacts within 25km range) and **Active** (loud ping, extended range but reveals your position). |
| **LOFAR Analysis** | Frequency analysis display. Shows three-tonal spectral display (propeller, engine, auxiliary frequencies) for vessel classification. |
| **Bearing Sweep** | Rotating sweep display showing contact amplitude spikes at their bearings. |
| **Detected Contacts** | Shows contacts: name, range, bearing, classification, and noise signature. TAG contacts for tactical map display. |
| **LAYER** | Whether the boat is above or below the thermal layer at 60 m. |

The sea has a **thermal layer at 60 m**. Sonar that has to look across it, from a boat above to a contact below or the other way round, hears only half as far, and the same goes for the enemy listening for you. Surface ships, aircraft and patrolling hostile submarines all sit above the layer, so a boat below 60 m is half as easy for them to find, and half as able to hear them. Come above the layer to listen, go below it to hide.

```admonish warning
Active sonar emits a loud ping that hostile NPCs can detect from long range. Use passive sonar when trying to remain undetected.
```

### Weapons Control Station

Torpedo fire control system.

| Control | Description |
| :--- | :--- |
| **Master Arm** | Must be ON to fire torpedoes. |
| **Tube Status** | Shows which of the 4 tubes are loaded/empty. |
| **Target Selection** | Select a detected contact as your target. Torpedoes home toward the selected target. |
| **Launch** | Fires a torpedo from a loaded tube toward the selected target. |

**Torpedo Stats**: 40 knots, 800 unit range, 250 base hull damage. Homing torpedoes track the target automatically. Different weapon types have different effects: torpedoes and missiles deal full hull damage, depth charges deal area damage across multiple hull sections, and naval guns deal 1/3 damage.

### Radio Console

Encrypted command communications. Receives mission objectives and displays mission status.

| Control | Description |
| :--- | :--- |
| **Transmission Log** | Shows all received messages with timestamps. |
| **Mission Status** | Shows current objective type, target coordinates, and target integrity. |
| **Fast Travel** | Engages 10x speed multiplier. Auto-disables when a hostile contact is nearby or if speed drops below 5 knots. |

### Compartment Status Panel

Damage control console showing the status of all submarine compartments.

| Control | Description |
| :--- | :--- |
| **Compartment List** | Shows water level, O2, CO2, and status (FLOODED/WET/DRY) for each compartment. |
| **Crew Status** | Table of all crew: name, role, health, oxygen status, and current compartment. |
| **EMERGENCY DRAIN** | Activates all bilge pumps simultaneously across the submarine. |
| **O2 INJECT ALL** | Injects oxygen into all compartments at once. |
| **SEAL BULKHEADS** | Attempts to seal all breached bulkheads. |

### Tactical Map Display

ASCII grid-based tactical map for situational awareness.

| Control | Description |
| :--- | :--- |
| **Zoom In/Out** | Adjust display range from 2.5km to 200km. |
| **Legend** | Color-coded contact types: player (white), tagged contacts (yellow), untagged (grey). |
| **Tagged Contacts** | Contacts tagged via sonar or radar appear with name, range, and bearing labels. |

```admonish tip
Tag important contacts on sonar or radar first. They will then appear on your tactical map with full identification.
```

---

## Flooding & Water Physics

When your submarine takes damage (torpedo hits, depth charges, crush depth), hull breaches can occur, flooding compartments with seawater.

### How Flooding Works

1. **Hull Breach**: A damaged hull wall loses integrity. When it fails, water begins pouring in.
2. **Water Accumulation**: Deck tiles accumulate water measured in centimeters (0 = dry, 200 = fully flooded).
3. **Water Spreading**: Water flows to adjacent tiles within the same compartment, equalizing depth.
4. **Bulkhead Containment**: Internal bulkheads are watertight by default. A bulkhead that has **buckled** (below half health) or **crumpled** (destroyed) lets water through to the next compartment at 10% of water depth per tick (max 3cm). A buckled bulkhead can be shored or welded back to watertight; a crumpled one must be welded.
5. **Blast Doors**: Open blast doors allow water to flow between compartments. Closed blast doors block water flow.

### Water Depth Effects

| Depth | Effect |
| :--- | :--- |
| 1-29 cm | Thin film. No gameplay effect. |
| 30-99 cm | Water covers the deck. Minor sloshing. |
| 100-149 cm | **Drowning begins**. Breathing difficulty, losebreath accumulates. |
| 150-199 cm | **Chest deep**. Heavy damage, severe drowning, CO2 buildup. |
| 200 cm | **Fully flooded**. Tile is underwater. |

### Flooding Interactions

- **Engine Room Flooding**: When water reaches 50cm in the engine room, diesel engines are forcibly shut down. Diesel throttle is forced to 0.
- **Reactor Room Flooding**: Water degrades coolant pump effectiveness. At 100cm, both reactors are automatically SCRAMMED and power output drops to zero.
- **Fire Extinguishing**: Water above 50cm automatically extinguishes fires on that tile.

### Bilge Pumps

Located in various compartments. Activate by clicking them.

- **Standard Bilge Pump**: Drains water from its tile and adjacent tiles. Uses 15 kW.
- **Emergency Bilge Pump**: Drains water from a single tile only. Uses 8 kW.

```admonish note
Bilge pumps require battery power. If your battery is dead, the pumps will not function. Prioritize keeping the diesel generators running if your reactors are offline.
```

### Hull Breach Sealant Sprayer

An automated device that scans for breached hull walls and seals them with fast-curing polymer. Each use consumes one unit of sealant (100 units total). Requires power to operate.

### Damage control by hand

Every footlocker aboard holds two **shoring kits**: timber shores and a canvas patch. Use one on a breached hull wall to wedge the breach to a slow seep in a few seconds, or on a buckled bulkhead to force its seals shut. A shored breach still lets a little water in until someone **welds** it, and a hard knock can tear the shoring loose again. Welding a breach with a welding tool is the full repair and restores the hull to half integrity; welding also mends cracked hull and bulkhead damage. Crumpled bulkheads cannot be shored.

A breached hull below the surface does not vent the compartment's air, but a sea at depth keeps pouring in. Surface or shore first, then weld.

---

## Atmospheric System

Each compartment has independent atmospheric simulation:

- **Oxygen (O2)**: Consumed by breathing. Depleted O2 causes suffocation. Replenished by the O2 generator.
- **Carbon Dioxide (CO2)**: Produced by breathing. High levels cause respiratory distress and CO2 poisoning.
- **Pressure**: Normal = 1 atm (101.325 kPa).

### Ventilation Ducts

Link compartments together for air sharing. All ducts with the same vent ID form a network. Air gradually equalizes across the network.

| Object | Function |
| :--- | :--- |
| **Ventilation Duct** | Passive air equalization. Click to open/close. |
| **CO2 Scrubber** | Active CO2 removal. Optionally injects O2. Uses 25 kW. |

```admonish tip
If a compartment is flooding, the water displaces oxygen. A fully flooded compartment will have almost no breathable air. Prioritize evacuation or O2 injection.
```

---

## Fire System

Fires can start from explosions, reactor meltdowns, or admin commands. Fire spreads across deck tiles and damages crew.

### Fire Mechanics

- **Ignition**: Fires start on internal deck tiles. Each fire burns for a set duration.
- **Spread**: Each tick, fire has a 5-8% chance of spreading to adjacent sub_deck turfs within the same compartment.
- **Damage**: Mobs on burning tiles take 3-8 burn damage per tick (15% chance per tick).
- **Smoke**: Random smoke effects spawn on burning tiles.
- **Extinction**: Water above 50cm automatically extinguishes fires. Fires do not spread through watertight bulkheads or closed blast doors.

---

## Vessel Roster

### Player Submarine

| Stat | Nuclear Sub | Diesel Sub |
| :--- | :--- | :--- |
| **Max Speed (surfaced)** | 30 knots | 18 knots |
| **Max Speed (submerged)** | 30 knots | 8 knots (battery) |
| **Propulsion** | Nuclear reactors | Diesel generators (surfaced only) |
| **Battery** | 3000 kWh | 3000 kWh |
| **Diesel Fuel** | 40000 L (backup) | 40000 L (primary) |
| **Crush Depth** | 300m | 300m |
| **Torpedo Tubes** | 4 | 4 |

### Hostile Surface Combatants

| Vessel | Type | Speed | Hull | Sensors | Weapons |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Oliver Hazard Perry FFG** | Frigate | 30 kts | 800 | Sensor 40km, Sonar 25km | Harpoon Missiles, Mk 46 Torpedoes |
| **Kirov CGN** | Battlecruiser | 28 kts | 1200 | Sensor 50km, Sonar 30km | P-700 Granit, SS-N-14 Silex, 53-65 Torpedoes |
| **Krivak FFG** | Frigate | 26 kts | 600 | Sensor 35km, Sonar 20km | RBU-6000 Depth Charges, SET-65 Torpedoes |
| **Nanuchka Corvette** | Corvette | 32 kts | 450 | Sensor 25km, Sonar 15km | P-120 Malakhit, 40mm CIWS |
| **Grisha MPK** | Patrol Boat | 24 kts | 350 | Sensor 20km, Sonar 18km | RBU-2500 Depth Charges, SA-N-4 Gecko |

### Hostile Submarines

| Vessel | Type | Speed | Hull | Sensors | Weapons |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Kilo-class SSK** | Diesel Sub | 18 kts | 700 | Sensor 30km, Sonar 35km | TEST-71 Torpedoes, Type 65-76 Torpedoes |
| **Akula-class SSN** | Nuclear Sub | 30 kts | 900 | Sensor 40km, Sonar 45km | SS-N-16 Stallion, 53-65K Torpedoes |
| **Delta III SSBN** | Ballistic Sub | 22 kts | 1100 | Sensor 25km, Sonar 30km | R-29 Vysota SLBM, 53-65M Torpedoes |

### Hostile Aircraft

| Aircraft | Type | Speed | Hull | Sensors | Weapons |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Tu-22M Backfire** | Bomber | 50 kts | 400 | Sensor 80km | AS-4 Kitchen, AS-6 Kingfish |
| **Su-24 Fencer** | Strike | 45 kts | 300 | Sensor 60km | AS-7 Kerry, FAB-500 Bombs |
| **Il-38 May** | ASW Patrol | 38 kts | 350 | Sensor 70km, Sonar 10km | RGB-1N Torpedoes, RGB-2 Depth Charges |

### Neutral / Mission Targets

| Vessel | Type | Speed | Hull | Sensors | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Bulk Cargo Freighter** | Cargo | 15 kts | 500 | Sensor 15km | Large radar signature. Common mission target. |
| **Fleet Oil Tanker** | Tanker | 12 kts | 400 | Sensor 12km | Very large signature. Catastrophic explosion on death. |

---

## AI Behavior

Hostile NPCs use a three-state AI with tactical movement:

| State | Behavior |
| :--- | :--- |
| **PATROL** | Moves between random waypoints at patrol speed. Non-hostile until detection. |
| **HUNT** | Triggered when the NPC detects the player. Moves toward the player's last known position at attack speed. |
| **ATTACK** | When within weapon range, the NPC **circle-strafes** around the player while firing weapons. Maintains a tight orbit to avoid torpedo lock. Reverts to HUNT if the player moves out of range. |

**Detection Triggers**:
- **Passive Sonar**: NPC detects you if your noise level exceeds their threshold. Noise increases with speed and active sonar use.
- **Active Sonar Ping**: If you use active sonar within the NPC's sonar range, they instantly know your position.

**Tactical Behavior**:
- NPCs circle in a random direction around you while attacking
- They fire one weapon at a time with cooldown management
- If you move too far away, they switch to HUNT to chase you

```admonish tip
Stay deep and slow to minimize your noise signature. A submarine running at 5 knots at 200m depth is extremely difficult to detect passively.
```

---

## Crew Management

The submarine tracks individual crew members and their status. Crew are automatically detected when they board the submarine.

### Crew Member Status

Each crew member is tracked with:

| Stat | Description |
| :--- | :--- |
| **Health** | Current health percentage (0-100) |
| **Total Damage** | Sum of all damage types |
| **Conscious** | Whether the crew member is conscious; check unconscious crew immediately. |
| **Injured** | Has significant damage |
| **Oxygen Status** | "Nominal", "Low O2", "Suffocating", or "Drowning" |
| **Compartment** | Current location (e.g., "Operations", "Reactor Room") |
| **Assignment** | Job title (Captain, Officer, Crewman) |
| **Role** | Command role (Captain, Officer, or Crew) |

### Crew Tracking

The submarine automatically:
- Detects crew members when they board
- Updates their health, oxygen, and location status
- Removes dead crew from tracking

---

## Mission System

Missions are relayed to you over the radio console. Complete objectives to earn mission points and progress through the game.

### Mission Types

| Type | Objective | Completion | Failure |
| :--- | :--- | :--- | :--- |
| **Sink Cargo** | Destroy a hostile cargo vessel at target coordinates | Sink the target vessel | Target escapes or time runs out |
| **Patrol Area** | Navigate to and patrol a sector | Reach coordinates and survive | Take too much damage or time runs out |
| **Escort** | Protect a friendly cargo vessel to waypoint | Cargo survives to destination | Cargo is destroyed |
| **Recon** | Investigate coordinates and observe | Reach target and maintain position | Take damage or leave area |
| **Rescue** | Find and escort a damaged allied submarine | Escort sub to safe waters | Allied sub is destroyed |
| **Ambush** | Set up and eliminate a hostile patrol group | Destroy all hostiles | Fail to eliminate all or time runs out |

### Mission Frequency

Missions arrive periodically with a brief delay between objectives. Check your radio console regularly for new orders.

```admonish note
Some mission types are rarer than others. Sink and patrol missions are most common, while rescue missions are extremely rare.
```

---

## Physical Machinery (Interior)

These objects exist on the submarine's interior and can be interacted with directly.

| Object | Location | Interaction |
| :--- | :--- | :--- |
| **Reactor Core** | Reactor Room | Visual indicator of reactor status. Emits radiation if damaged. |
| **Coolant Pump** | Reactor Room | Degrades with damage. Damaged pumps reduce cooling efficiency. |
| **Steam Turbine** | Engine Room | Caps max speed based on health. Makes noise at high speeds. |
| **Diesel Engine** | Engine Room | Carbon buildup at low throttle. Overheats at high throttle. |
| **Diesel Propulsion Motor** | Engine Room (diesel only) | Converts diesel power to thrust. Has motor temperature. Overheats above 80C, seizes if health reaches 0. |
| **Torpedo Tube** | Forward/Aft Torpedo Room | Load/unload torpedoes. Click with a torpedo item to load, crowbar to unload. |
| **HTP Fuel Tank** | Torpedo Room | High-test peroxide storage. Volatile if damaged or heated. Explodes when destroyed (devastation 1, heavy 2, light 4). |
| **Bunk Bed** | Crew Quarters | Rest area. |
| **Galley** | Galley | Food processor. Produces nutritional rations when clicked. |
| **Emergency Supply Vendor** | Various | Contains gas masks, NBC suits, geiger counters, fire extinguishers, and basic tools. |
| **Stern Plane** | External | Affects steering efficiency. Must be repaired while surfaced. |
| **Bilge Pump** | Various Compartments | Drains water from tiles. |
| **Hull Breach Sealant Sprayer** | Various Compartments | Seals breached hull walls. |
| **Shoring Kit** | Footlockers | Hand-carried. Wedges a hull breach to a seep or reseals a buckled bulkhead until it is welded. |
| **Ventilation Duct** | Various Compartments | Equalizes air between compartments. Click to open/close. |
| **CO2 Scrubber** | Various Compartments | Removes CO2, optionally injects O2. |
| **Ballast Control Valve** | Operations | Controls ballast tank flooding/venting for depth control. |

---

## Quick Reference

| Situation | Action |
| :--- | :--- |
| Taking on water | Shore the breach with a shoring kit from a footlocker, then weld it. Activate bilge pumps. Close blast doors to contain flooding. |
| Running out of air | Turn on O2 generator. Open ventilation ducts. |
| Reactor overheating | Increase primary pump speed. Insert control rods. SCRAM if critical. |
| Reactor room flooding | Water degrades pumps. Evacuate and seal bulkheads. Flooding at 100cm force-SCRAMS reactors. |
| Engine room flooding | Diesel engines auto-shutdown at 50cm water. Surface and seal. |
| Fire started | Fires spread to adjacent tiles. Flood the area (>50cm water extinguishes). Evacuate crew. |
| Enemy detected on sonar | Go deep (150m+), below the 60 m thermal layer, reduce speed to 5 knots, go silent. |
| Need to fire torpedoes | Master Arm ON. Select target from sonar contacts. Load tube. Launch. |
| Battery dead | Surface and engage diesel throttle to recharge. Lights go dark when battery is empty. |
| Crush depth warning | Set a shallower target depth (a smaller depth value). Check ballast. Emergency blow if needed. |
| Crew member injured | Check crew status via compartment panel. Move to medical bay. |
| Crew suffocating | Check oxygen status. Inject O2 into compartment or evacuate. |
| NPC attacking | Go deep and slow. Use passive sonar. Avoid active sonar pings. |
| Mission received | Check radio console for coordinates. Navigate to target area. |
| Multiple hull breaches | Emergency blow to surface. Activate all bilge pumps. Seal breaches. |
| Need situational awareness | Tag contacts on sonar/radar. Check tactical map display for overview. |
| Compartment status | Use Compartment Status Panel to monitor water, O2, CO2 across all compartments. |

---

## Lighting

The submarine has two types of interior lights:

- **Normal lights** (`alwayson/sub`): Respond to submarine battery power. When battery is charged, lights are on. When battery is empty, all normal lights go dark.
- **Emergency red lights** (`alwayson/red`): Always on regardless of power state. These serve as battle-station lighting and emergency illumination.
- **Emergency strobes** (`alwayson/red/emergency`): Brighter red lights that blink on/off as emergency beacons. Used in critical areas.
