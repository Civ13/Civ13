// ============================================================
// World Map Controller - singleton managing the 1000x1000
// virtual nautical coordinate grid, all active vessels, and
// the overworld simulation tick loop.
// ============================================================

var/global/datum/world_map_controller/subcom_map

/datum/world_map_controller
	var/list/active_vessels = list()      // All /datum/vessel_contact/npc instances
	var/list/active_torpedoes = list()    // All /datum/projectile/torpedo instances
	var/datum/submarine/player_sub        // Direct reference to the player's sub datum
	var/datum/mission_controller/missions // Mission system reference
	var/tick_counter = 0
	var/start_x = 500                     // Sub spawn X coordinate
	var/start_y = 500                     // Sub spawn Y coordinate

/datum/world_map_controller/New()
	..()
	global.subcom_map = src
	missions = new /datum/mission_controller(src)
	if(!global.subcom_flooding)
		new /datum/flooding_controller()

/datum/world_map_controller/proc/initialize(var/datum/submarine/_player_sub)
	player_sub = _player_sub
	if(player_sub)
		start_x = player_sub.x_pos
		start_y = player_sub.y_pos
	load_npc_types()
	spawn_initial_contacts()

// ---- Main Process Loop (called on SUB_MAP_TICK_INTERVAL cadence) ----

/datum/world_map_controller/proc/process_tick()
	tick_counter++

	// 0. Update noise level BEFORE detection so NPCs see current values
	update_player_noise()

	// 1. Update the player submarine's virtual position
	if(player_sub)
		player_sub.process_tick()

	// 2. Process all NPC vessels
	for(var/datum/vessel_contact/npc/NPC in active_vessels)
		if(QDELETED(NPC))
			active_vessels -= NPC
			continue
		// NPC checks player detection (passive/active sonar)
		NPC.check_player_detection(player_sub)
		// NPC AI movement and combat
		NPC.process_tick()

	// 3. Process all active torpedoes
	for(var/datum/projectile/torpedo/T in active_torpedoes)
		if(QDELETED(T))
			active_torpedoes -= T
			continue
		T.process_tick()

	// 4. Process mission controller
	if(missions)
		missions.process_tick()

// ---- Player Noise Calculation ----

/datum/world_map_controller/proc/update_player_noise()
	if(!player_sub)
		return

	// Base noise from speed
	var/speed_noise = player_sub.speed * 5

	// Active sonar is very loud
	if(player_sub.sonar_active && player_sub.sonar_mode == SUB_SONAR_ACTIVE)
		speed_noise += SUB_NOISE_ACTIVE_SONAR

	// Depth reduces noise (surface = full noise, deep = attenuated)
	if(player_sub.depth > 0)
		speed_noise = speed_noise * max(0.2, 1 - (player_sub.depth / 300))

	player_sub.noise_level = round(speed_noise)

// ---- Contact Spawning ----

/datum/world_map_controller/proc/spawn_initial_contacts()
	var/datum/vessel_contact/npc/NPC
	NPC = spawn_enemy_npc(/datum/subcom_enemy/destroyer)
	if(NPC) active_vessels += NPC
	NPC = spawn_enemy_npc(/datum/subcom_enemy/destroyer)
	if(NPC) active_vessels += NPC
	NPC = spawn_enemy_npc(/datum/subcom_enemy/frigate)
	if(NPC) active_vessels += NPC
	NPC = spawn_enemy_npc(/datum/subcom_enemy/cargo_ship, rand(600, 800), rand(600, 800))
	if(NPC) active_vessels += NPC

/datum/world_map_controller/proc/spawn_npc(var/enemy_type_path, var/spawn_x, var/spawn_y)
	var/datum/vessel_contact/npc/NPC = spawn_enemy_npc(enemy_type_path, spawn_x, spawn_y)
	if(NPC)
		active_vessels += NPC
	return NPC

// ---- Cleanup ----

/datum/world_map_controller/proc/remove_vessel(var/datum/vessel_contact/npc/NPC)
	active_vessels -= NPC
	qdel(NPC)

/datum/world_map_controller/proc/remove_torpedo(var/datum/projectile/torpedo/T)
	active_torpedoes -= T
	qdel(T)
