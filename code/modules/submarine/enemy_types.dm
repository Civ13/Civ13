// ============================================================
// SUBCOM13 Enemy Vessel Type Definitions
// Central registry of all NPC vessel archetypes.
// Used by the mission controller and world map to spawn contacts.
// ============================================================

// Base type — all enemy stats live here
/datum/subcom_enemy
	var/name = "Unknown"
	var/contact_type = SUB_CONTACT_SURFACE   // "Surface", "Submerged", "Air"
	var/nationality = SUB_NATION_HOSTILE

	// Movement
	var/max_speed = 20           // Knots
	var/patrol_speed = 10
	var/hunt_speed = 18
	var/attack_speed = 15

	// Survivability
	var/hull_strength = 500
	var/max_hull_strength = 500

	// Sensors
	var/sensor_range = 30000     // Meters — how far this vessel can detect others
	var/sonar_range = 20000      // Meters — underwater detection
	var/radar_cross_section = 1.0 // Multiplier for how visible on radar (1.0 = normal)
	var/passive_sonar_threshold = 20  // NPC detects player if player noise > this value

	// Weapons: list of /datum/subcom_weapon
	var/list/weapons = list()

	// Acoustic signature (LOFAR tonals in Hz)
	var/sig_low = 0              // Propeller blade rate (10-200 Hz)
	var/sig_mid = 0              // Main engines (500-900 Hz)
	var/sig_high = 0             // Auxiliary machinery (1000-2000 Hz)
	var/classification = "Unknown" // Short class name for LOFAR display

	// Loot dropped on sink (optional)
	var/loot_type = null

/datum/subcom_enemy/New()
	if(max_hull_strength > 0)
		hull_strength = max_hull_strength

// ---- Weapon definition ----

/datum/subcom_weapon
	var/name = "Unknown Weapon"
	var/damage = 100
	var/range = 20000            // Meters
	var/weapon_type = "missile"  // "missile", "torpedo", "depth_charge", "gun"
	var/cooldown = 30            // Ticks between firings
	var/speed = 40               // Projectile speed (knots) — only for torpedoes
	var/homing = FALSE           // Whether the projectile tracks

/datum/subcom_weapon/New(var/_name, var/_dmg, var/_range, var/_type, var/_cd)
	if(_name) name = _name
	if(_dmg) damage = _dmg
	if(_range) range = _range
	if(_type) weapon_type = _type
	if(_cd) cooldown = _cd

// ============================================================
// SURFACE COMBATANTS
// ============================================================

/datum/subcom_enemy/destroyer
	name = "Oliver Hazard Perry-class FFG"
	contact_type = SUB_CONTACT_SURFACE
	nationality = SUB_NATION_HOSTILE
	max_speed = 30
	patrol_speed = 12
	hunt_speed = 25
	attack_speed = 20
	hull_strength = 800
	max_hull_strength = 800
	sensor_range = 40000
	sonar_range = 25000
	passive_sonar_threshold = 20
	radar_cross_section = 1.0
	sig_low = 170
	sig_mid = 840
	sig_high = 1890
	classification = "Frigate (ASW)"

/datum/subcom_enemy/destroyer/New()
	..()
	weapons += new /datum/subcom_weapon("RGM-84 Harpoon", 350, 50000, "missile", 45)
	weapons += new /datum/subcom_weapon("Mk 46 Torpedo", 200, 15000, "torpedo", 30)

/datum/subcom_enemy/cruiser
	name = "Kirov-class CGN"
	contact_type = SUB_CONTACT_SURFACE
	nationality = SUB_NATION_HOSTILE
	max_speed = 28
	patrol_speed = 10
	hunt_speed = 22
	attack_speed = 18
	hull_strength = 1200
	max_hull_strength = 1200
	sensor_range = 50000
	sonar_range = 30000
	passive_sonar_threshold = 15
	radar_cross_section = 1.3
	sig_low = 120
	sig_mid = 490
	sig_high = 920
	classification = "Cruiser (Heavy)"

/datum/subcom_enemy/cruiser/New()
	..()
	weapons += new /datum/subcom_weapon("P-700 Granit", 400, 60000, "missile", 55)
	weapons += new /datum/subcom_weapon("SS-N-14 Silex", 250, 25000, "missile", 40)
	weapons += new /datum/subcom_weapon("53-65 Torpedo", 220, 20000, "torpedo", 35)

/datum/subcom_enemy/frigate
	name = "Krivak-class FFG"
	contact_type = SUB_CONTACT_SURFACE
	nationality = SUB_NATION_HOSTILE
	max_speed = 26
	patrol_speed = 14
	hunt_speed = 20
	attack_speed = 16
	hull_strength = 600
	max_hull_strength = 600
	sensor_range = 35000
	sonar_range = 20000
	passive_sonar_threshold = 25
	radar_cross_section = 0.9
	sig_low = 240
	sig_mid = 930
	sig_high = 1520
	classification = "Frigate (Patrol)"

/datum/subcom_enemy/frigate/New()
	..()
	weapons += new /datum/subcom_weapon("RBU-6000 Depth Charge", 180, 8000, "depth_charge", 15)
	weapons += new /datum/subcom_weapon("SET-65 Torpedo", 180, 12000, "torpedo", 22)

/datum/subcom_enemy/corvette
	name = "Nanuchka-class corvette"
	contact_type = SUB_CONTACT_SURFACE
	nationality = SUB_NATION_HOSTILE
	max_speed = 32
	patrol_speed = 16
	hunt_speed = 28
	attack_speed = 24
	hull_strength = 450
	max_hull_strength = 450
	sensor_range = 25000
	sonar_range = 15000
	passive_sonar_threshold = 30
	radar_cross_section = 0.7
	sig_low = 210
	sig_mid = 760
	sig_high = 1650
	classification = "Corvette (Light)"

/datum/subcom_enemy/corvette/New()
	..()
	weapons += new /datum/subcom_weapon("P-120 Malakhit", 300, 40000, "missile", 35)
	weapons += new /datum/subcom_weapon("40mm CIWS", 60, 5000, "gun", 8)

/datum/subcom_enemy/patrol_boat
	name = "Grisha-class MPK"
	contact_type = SUB_CONTACT_SURFACE
	nationality = SUB_NATION_HOSTILE
	max_speed = 24
	patrol_speed = 12
	hunt_speed = 20
	attack_speed = 15
	hull_strength = 350
	max_hull_strength = 350
	sensor_range = 20000
	sonar_range = 18000
	passive_sonar_threshold = 28
	radar_cross_section = 0.6
	sig_low = 190
	sig_mid = 680
	sig_high = 1440
	classification = "Patrol Boat (ASW)"

/datum/subcom_enemy/patrol_boat/New()
	..()
	weapons += new /datum/subcom_weapon("RBU-2500 Depth Charge", 140, 6000, "depth_charge", 12)
	weapons += new /datum/subcom_weapon("SA-N-4 Gecko", 200, 15000, "missile", 25)

// ============================================================
// CARGO / AUXILIARY
// ============================================================

/datum/subcom_enemy/cargo_ship
	name = "Bulk Cargo Freighter"
	contact_type = SUB_CONTACT_SURFACE
	nationality = SUB_NATION_NEUTRAL  // Will be set to Hostile by mission controller
	max_speed = 15
	patrol_speed = 8
	hunt_speed = 0                    // Cannot chase
	attack_speed = 0                  // Unarmed
	hull_strength = 500
	max_hull_strength = 500
	sensor_range = 15000
	sonar_range = 5000
	passive_sonar_threshold = 40
	radar_cross_section = 2.0         // Large radar signature
	sig_low = 170
	sig_mid = 840
	sig_high = 1890
	classification = "Merchant (Cargo)"
	loot_type = "supplies"

/datum/subcom_enemy/tanker
	name = "Fleet Oil Tanker"
	contact_type = SUB_CONTACT_SURFACE
	nationality = SUB_NATION_NEUTRAL
	max_speed = 12
	patrol_speed = 6
	hunt_speed = 0
	attack_speed = 0
	hull_strength = 400
	max_hull_strength = 400
	sensor_range = 12000
	sonar_range = 3000
	passive_sonar_threshold = 50
	radar_cross_section = 2.5
	sig_low = 130
	sig_mid = 620
	sig_high = 1350
	classification = "Merchant (Tanker)"
	loot_type = "fuel"

/datum/subcom_enemy/tanker/New()
	..()
	max_hull_strength = 400  // Explodes catastrophically when hit

// ============================================================
// AIR UNITS
// ============================================================

/datum/subcom_enemy/tu22m
	name = "Tu-22M Backfire"
	contact_type = SUB_CONTACT_AIR
	nationality = SUB_NATION_HOSTILE
	max_speed = 50
	patrol_speed = 35
	hunt_speed = 45
	attack_speed = 40
	hull_strength = 400
	max_hull_strength = 400
	sensor_range = 80000
	sonar_range = 0                  // No underwater sensors
	passive_sonar_threshold = 0      // Air units detect via radar, not sonar
	radar_cross_section = 0.5

/datum/subcom_enemy/tu22m/New()
	..()
	weapons += new /datum/subcom_weapon("AS-4 Kitchen ASM", 500, 80000, "missile", 80)
	weapons += new /datum/subcom_weapon("AS-6 Kingfish ASM", 350, 60000, "missile", 60)

/datum/subcom_enemy/su24
	name = "Su-24 Fencer"
	contact_type = SUB_CONTACT_AIR
	nationality = SUB_NATION_HOSTILE
	max_speed = 45
	patrol_speed = 30
	hunt_speed = 40
	attack_speed = 35
	hull_strength = 300
	max_hull_strength = 300
	sensor_range = 60000
	sonar_range = 0
	passive_sonar_threshold = 0
	radar_cross_section = 0.6

/datum/subcom_enemy/su24/New()
	..()
	weapons += new /datum/subcom_weapon("AS-7 Kerry ASM", 250, 45000, "missile", 50)
	weapons += new /datum/subcom_weapon("FAB-500 Bomb", 400, 3000, "missile", 30)

/datum/subcom_enemy/Il38
	name = "Il-38 May"
	contact_type = SUB_CONTACT_AIR
	nationality = SUB_NATION_HOSTILE
	max_speed = 38
	patrol_speed = 28
	hunt_speed = 35
	attack_speed = 30
	hull_strength = 350
	max_hull_strength = 350
	sensor_range = 70000
	sonar_range = 10000              // Has magnetic anomaly detector for sub hunting
	passive_sonar_threshold = 0
	radar_cross_section = 0.7

/datum/subcom_enemy/Il38/New()
	..()
	weapons += new /datum/subcom_weapon("RGB-1N Torpedo", 220, 12000, "torpedo", 35)
	weapons += new /datum/subcom_weapon("RGB-2 Depth Charge", 160, 5000, "depth_charge", 20)

// ============================================================
// SUBSURFACE UNITS
// ============================================================

/datum/subcom_enemy/sub_diesel
	name = "Kilo-class SSK"
	contact_type = SUB_CONTACT_SUBMERGED
	nationality = SUB_NATION_HOSTILE
	max_speed = 18
	patrol_speed = 8
	hunt_speed = 15
	attack_speed = 12
	hull_strength = 700
	max_hull_strength = 700
	sensor_range = 30000
	sonar_range = 35000
	passive_sonar_threshold = 10     // Very quiet -- hard to detect
	radar_cross_section = 0.3        // Small sonar/radar signature
	sig_low = 380
	sig_mid = 720
	sig_high = 1200
	classification = "Submarine (Diesel)"

/datum/subcom_enemy/sub_diesel/New()
	..()
	weapons += new /datum/subcom_weapon("TEST-71 Torpedo", 220, 25000, "torpedo", 35)
	weapons += new /datum/subcom_weapon("Type 65-76 Torpedo", 300, 30000, "torpedo", 45)

/datum/subcom_enemy/sub_nuclear
	name = "Akula-class SSN"
	contact_type = SUB_CONTACT_SUBMERGED
	nationality = SUB_NATION_HOSTILE
	max_speed = 30
	patrol_speed = 12
	hunt_speed = 25
	attack_speed = 20
	hull_strength = 900
	max_hull_strength = 900
	sensor_range = 40000
	sonar_range = 45000
	passive_sonar_threshold = 8      // Extremely quiet
	radar_cross_section = 0.25
	sig_low = 140
	sig_mid = 350
	sig_high = 880
	classification = "Submarine (Nuclear)"

/datum/subcom_enemy/sub_nuclear/New()
	..()
	weapons += new /datum/subcom_weapon("SS-N-16 Stallion", 280, 35000, "torpedo", 40)
	weapons += new /datum/subcom_weapon("53-65K Torpedo", 250, 20000, "torpedo", 30)

/datum/subcom_enemy/sub_ballistic
	name = "Delta III SSBN"
	contact_type = SUB_CONTACT_SUBMERGED
	nationality = SUB_NATION_HOSTILE
	max_speed = 22
	patrol_speed = 6
	hunt_speed = 18
	attack_speed = 14
	hull_strength = 1100
	max_hull_strength = 1100
	sensor_range = 25000
	sonar_range = 30000
	passive_sonar_threshold = 12
	radar_cross_section = 0.35
	sig_low = 150
	sig_mid = 380
	sig_high = 950
	classification = "Submarine (Ballistic)"

/datum/subcom_enemy/sub_ballistic/New()
	..()
	weapons += new /datum/subcom_weapon("R-29 Vysota SLBM", 600, 80000, "missile", 120)
	weapons += new /datum/subcom_weapon("53-65M Torpedo", 200, 18000, "torpedo", 35)

// ============================================================
// HELPER: Spawn an NPC from type definition
// ============================================================

/proc/spawn_enemy_npc(var/enemy_type_path, var/spawn_x, var/spawn_y)
	var/datum/subcom_enemy/E = new enemy_type_path()
	var/datum/vessel_contact/npc/NPC = new(E.name, spawn_x || rand(200, 800), spawn_y || rand(200, 800))

	// Transfer stats from type definition to NPC instance
	NPC.max_speed = E.max_speed
	NPC.patrol_speed = E.patrol_speed
	NPC.attack_speed = E.hunt_speed
	NPC.hull_strength = E.hull_strength
	NPC.max_hull_strength = E.hull_strength
	NPC.sensor_range = E.sensor_range
	NPC.sonar_range = E.sonar_range
	NPC.passive_sonar_threshold = E.passive_sonar_threshold
	NPC.contact_type = E.contact_type
	NPC.nationality = E.nationality
	NPC.radar_cross_section = E.radar_cross_section
	NPC.sig_low = E.sig_low
	NPC.sig_mid = E.sig_mid
	NPC.sig_high = E.sig_high
	NPC.classification = E.classification
	NPC.enemy_type_ref = E

	// Transfer weapons
	for(var/datum/subcom_weapon/W in E.weapons)
		var/list/weapon_data = list(
			"name"     = W.name,
			"damage"   = W.damage,
			"range"    = W.range,
			"type"     = W.weapon_type,
			"cooldown" = W.cooldown,
			"speed"    = W.speed,
			"homing"   = W.homing
		)
		NPC.weapons += list(weapon_data)
		NPC.weapon_timers += 0

	qdel(E)
	return NPC

// ============================================================
// HELPER: Random hostile spawn from the type pool
// ============================================================

/proc/spawn_random_enemy(var/spawn_x, var/spawn_y)
	var/list/hostile_pool = list(
		/datum/subcom_enemy/destroyer,
		/datum/subcom_enemy/frigate,
		/datum/subcom_enemy/corvette,
		/datum/subcom_enemy/patrol_boat,
		/datum/subcom_enemy/sub_diesel
	)
	return spawn_enemy_npc(pick(hostile_pool), spawn_x, spawn_y)
