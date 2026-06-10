// ============================================================
// Mission Controller — generates objectives and relays
// encrypted transmissions to the sub's radio console.
// Supports: SINK_CARGO, PATROL_AREA, ESCORT, RECON, RESCUE, AMBUSH
// ============================================================

/datum/mission_controller
	var/current_objective_type = ""     // e.g. SUB_MISSION_SINK_CARGO
	var/target_x = 0
	var/target_y = 0
	var/start_x = 0                     // Sub position when mission started (for escort/rescue)
	var/start_y = 0
	var/is_completed = FALSE
	var/mission_active = FALSE
	var/datum/vessel_contact/npc/target_vessel  // Primary NPC target
	var/datum/world_map_controller/parent_map
	var/obj/structure/machinery/sub_control/radio_console/radio_console
	var/next_mission_delay = 0           // Ticks before next mission spawns
	var/missions_completed = 0          // Total missions successfully completed
	var/missions_failed = 0             // Total missions failed

	// Timers and tracking
	var/mission_timer = 0                // Generic countdown (recon duration, ambush timeout)
	var/list/ambush_hostiles = list()    // All hostile NPCs spawned for ambush mission
	var/datum/vessel_contact/npc/escort_target  // Friendly vessel to protect in escort missions

	// Mission flavor text templates
	var/list/sink_messages = list(
		"INTEL: Hostile cargo vessel spotted near coordinate %X, %Y. Recon confirms military supplies aboard. Search and destroy.",
		"PRIORITY: Enemy supply ship at %X, %Y. Intercept and sink before it reaches port. Use extreme caution.",
		"COMMAND: Hostile logistics vessel detected at grid %X, %Y. Authorization to engage and destroy. Acknowledge.",
		"ALERT: Enemy transport bearing for %X, %Y. Rules of engagement: fire at will. Do not let it escape."
	)
	var/list/patrol_messages = list(
		"ORDERS: Patrol sector from %X, %Y to the northeast. Report any contacts. Maintain radio silence.",
		"COMMAND: Sweep the area near %X, %Y for suspected submarine activity. Proceed with caution.",
		"ORDERS: Recon sweep assigned. Investigate sonar anomaly at %X, %Y. Report findings."
	)
	var/list/escort_messages = list(
		"PRIORITY: Friendly supply convoy departing from %X, %Y. Escort to waypoint ALPHA. Defend against hostile contacts.",
		"COMMAND: Merchant vessel MS-*UNNAMED* requesting escort through contested waters near %X, %Y. Provide overwatch.",
		"ORDERS: Escort friendly cargo ship transiting grid %X, %Y. Engage any hostile contacts. Do not lose the package."
	)
	var/list/recon_messages = list(
		"INTEL: Suspected enemy patrol activity at %X, %Y. Proceed to grid, maintain position for 30 ticks. Report all contacts.",
		"COMMAND: Satellite imaging inconclusive at %X, %Y. Investigate on-site. Hold position and observe.",
		"ORDERS: Forward recon requested. Navigate to %X, %Y and maintain station. Log all sonar contacts."
	)
	var/list/rescue_messages = list(
		"ALERT: Friendly submarine (*UNNAMED*) reports critical damage at %X, %Y. Proceed to rescue. Escort to safe waters.",
		"MAYDAY RELAY: Allied sub (*UNNAMED*) damaged, requesting immediate assistance at grid %X, %Y. Rescue and escort.",
		"PRIORITY: Distress signal from allied vessel at %X, %Y. Hull compromised, engines offline. Reach target and escort home."
	)
	var/list/ambush_messages = list(
		"INTEL: Enemy patrol group expected to transit grid %X, %Y within the hour. Set up ambush. Destroy all hostiles.",
		"COMMAND: Hostile flotilla moving through %X, %Y. Take up position and engage when targets are in range.",
		"ORDERS: Ambush assignment. Intercept enemy contacts at %X, %Y. Eliminate all hostile vessels. Leave no survivors."
	)

/datum/mission_controller/New(var/datum/world_map_controller/_parent)
	parent_map = _parent

// ---- Main Process Tick ----

/datum/mission_controller/proc/process_tick()
	if(!mission_active)
		if(next_mission_delay > 0)
			next_mission_delay--
		else
			generate_new_mission()
		return

	// Type-specific completion checks
	switch(current_objective_type)
		if(SUB_MISSION_SINK_CARGO)
			check_sink_completion()
		if(SUB_MISSION_PATROL)
			check_patrol_completion()
		if(SUB_MISSION_ESCORT)
			check_escort_completion()
		if(SUB_MISSION_RECON)
			check_recon_completion()
		if(SUB_MISSION_RESCUE)
			check_rescue_completion()
		if(SUB_MISSION_AMBUSH)
			check_ambush_completion()

// ---- Completion Checks (per mission type) ----

/datum/mission_controller/proc/check_sink_completion()
	if(target_vessel)
		if(QDELETED(target_vessel) || target_vessel.hull_strength <= 0)
			complete_mission("Target vessel destroyed. Excellent work, Commander.")
	else
		complete_mission("Target vessel confirmed destroyed.")

/datum/mission_controller/proc/check_patrol_completion()
	// Patrol completes when the sub reaches the target area and survives 20 ticks
	if(!global.subcom_map || !global.subcom_map.player_sub)
		return
	var/datum/submarine/player = global.subcom_map.player_sub
	var/dist = euclidean_distance(player.x_pos, player.y_pos, target_x, target_y)
	if(dist <= 50)
		mission_timer++
		if(mission_timer >= 20)
			complete_mission("Area swept. No further contacts detected. Well done.")
	else
		mission_timer = 0  // Reset if they leave the area

/datum/mission_controller/proc/check_escort_completion()
	// Escort completes when the escorted vessel reaches the destination
	if(!escort_target || QDELETED(escort_target) || escort_target.hull_strength <= 0)
		fail_mission("Escort vessel destroyed. Mission failed.")
		return
	// Check if escorted vessel reached a safe zone (within 100nm of a friendly port)
	if(global.subcom_map)
		var/dist = euclidean_distance(escort_target.x_pos, escort_target.y_pos, global.subcom_map.start_x, global.subcom_map.start_y)
		if(dist <= 100)
			complete_mission("Escort vessel reached safe waters. Mission complete.")

/datum/mission_controller/proc/check_recon_completion()
	// Recon completes after holding position at target for SUB_MISSION_RECON_DURATION ticks
	if(!global.subcom_map || !global.subcom_map.player_sub)
		return
	var/datum/submarine/player = global.subcom_map.player_sub
	var/dist = euclidean_distance(player.x_pos, player.y_pos, target_x, target_y)
	if(dist <= 50)
		mission_timer++
		if(mission_timer >= SUB_MISSION_RECON_DURATION)
			complete_mission("Reconnaissance complete. Data transmitted to command. Good work.")
	else
		if(mission_timer > 0)
			mission_timer = 0
			send_radio_message("WARNING: You have left the recon area. Return to grid immediately.")

/datum/mission_controller/proc/check_rescue_completion()
	// Rescue completes when the damaged vessel is escorted within rescue range of start
	if(!target_vessel || QDELETED(target_vessel) || target_vessel.hull_strength <= 0)
		fail_mission("Rescue vessel destroyed. Mission failed.")
		return
	// The damaged vessel should be following the player — check if it's close to start
	var/dist = euclidean_distance(target_vessel.x_pos, target_vessel.y_pos, start_x, start_y)
	if(dist <= SUB_MISSION_RESCUE_RANGE)
		complete_mission("Rescued vessel brought to safe waters. Outstanding work, Commander.")

/datum/mission_controller/proc/check_ambush_completion()
	// Ambush completes when all hostiles are destroyed, or fails on timeout
	mission_timer--
	if(mission_timer <= 0)
		fail_mission("Time expired. Hostile contacts escaped. Mission failed.")
		return
	// Check if all ambush hostiles are destroyed
	var/all_dead = TRUE
	for(var/datum/vessel_contact/npc/N in ambush_hostiles)
		if(!QDELETED(N) && N.hull_strength > 0)
			all_dead = FALSE
			break
	if(all_dead)
		complete_mission("All hostile contacts eliminated. Ambush successful.")

// ---- Mission Generation ----

/datum/mission_controller/proc/generate_new_mission()
	// Weighted random type selection: SINK 30, PATROL 25, ESCORT 20, RECON 15, AMBUSH 8, RESCUE 2
	var/total_weight = 30 + 25 + 20 + 15 + 8 + 2
	var/roll = rand(1, total_weight)
	if(roll <= 30)
		current_objective_type = SUB_MISSION_SINK_CARGO
	else if(roll <= 55)
		current_objective_type = SUB_MISSION_PATROL
	else if(roll <= 75)
		current_objective_type = SUB_MISSION_ESCORT
	else if(roll <= 90)
		current_objective_type = SUB_MISSION_RECON
	else if(roll <= 98)
		current_objective_type = SUB_MISSION_AMBUSH
	else
		current_objective_type = SUB_MISSION_RESCUE

	target_x = rand(100, 900)
	target_y = rand(100, 900)
	mission_timer = 0

	// Record sub start position for escort/rescue return
	if(global.subcom_map && global.subcom_map.player_sub)
		start_x = global.subcom_map.player_sub.x_pos
		start_y = global.subcom_map.player_sub.y_pos
	else
		start_x = global.subcom_map ? global.subcom_map.start_x : 500
		start_y = global.subcom_map ? global.subcom_map.start_y : 500

	// Clean up previous mission refs
	cleanup_previous_mission()

	switch(current_objective_type)
		if(SUB_MISSION_SINK_CARGO)
			spawn_sink_mission()
		if(SUB_MISSION_PATROL)
			spawn_patrol_mission()
		if(SUB_MISSION_ESCORT)
			spawn_escort_mission()
		if(SUB_MISSION_RECON)
			spawn_recon_mission()
		if(SUB_MISSION_RESCUE)
			spawn_rescue_mission()
		if(SUB_MISSION_AMBUSH)
			spawn_ambush_mission()

	mission_active = TRUE
	is_completed = FALSE

// ---- Spawn: Sink Cargo ----

/datum/mission_controller/proc/spawn_sink_mission()
	target_vessel = spawn_enemy_npc(/datum/subcom_enemy/cargo_ship, target_x, target_y)
	if(target_vessel)
		target_vessel.nationality = SUB_NATION_HOSTILE
		target_vessel.patrol_min_x = target_x - 50
		target_vessel.patrol_min_y = target_y - 50
		target_vessel.patrol_max_x = target_x + 50
		target_vessel.patrol_max_y = target_y + 50
		if(global.subcom_map)
			global.subcom_map.active_vessels += target_vessel
	var/msg = pick(sink_messages)
	msg = replacetext(msg, "%X", "[target_x]")
	msg = replacetext(msg, "%Y", "[target_y]")
	send_radio_message(msg)

// ---- Spawn: Patrol ----

/datum/mission_controller/proc/spawn_patrol_mission()
	var/datum/vessel_contact/npc/patrol_enemy = spawn_random_enemy(target_x, target_y)
	if(global.subcom_map)
		global.subcom_map.active_vessels += patrol_enemy
	// Give the enemy patrol waypoints around the area
	patrol_enemy.patrol_min_x = target_x - 80
	patrol_enemy.patrol_min_y = target_y - 80
	patrol_enemy.patrol_max_x = target_x + 80
	patrol_enemy.patrol_max_y = target_y + 80
	var/msg = pick(patrol_messages)
	msg = replacetext(msg, "%X", "[target_x]")
	msg = replacetext(msg, "%Y", "[target_y]")
	send_radio_message(msg)

// ---- Spawn: Escort ----

/datum/mission_controller/proc/spawn_escort_mission()
	// Spawn the friendly cargo vessel near the sub
	var/escort_x = start_x + rand(-30, 30)
	var/escort_y = start_y + rand(-30, 30)
	escort_x = clamp(escort_x, 50, 950)
	escort_y = clamp(escort_y, 50, 950)
	escort_target = spawn_enemy_npc(/datum/subcom_enemy/cargo_ship, escort_x, escort_y)
	escort_target.nationality = SUB_NATION_FRIENDLY
	escort_target.name = pick("MS Pacific Vanguard", "SS Northern Star", "MV Atlantis", "TS Enterprise")
	if(global.subcom_map)
		global.subcom_map.active_vessels += escort_target
	// Spawn hostile interceptors along the route
	var/list/interceptor_types = list(
		/datum/subcom_enemy/destroyer,
		/datum/subcom_enemy/frigate,
		/datum/subcom_enemy/corvette
	)
	var/num_interceptors = rand(1, 3)
	for(var/i = 1 to num_interceptors)
		var/int_x = escort_x + rand(-100, 100)
		var/int_y = escort_y + rand(-100, 100)
		int_x = clamp(int_x, 50, 950)
		int_y = clamp(int_y, 50, 950)
		var/datum/vessel_contact/npc/interceptor = spawn_enemy_npc(pick(interceptor_types), int_x, int_y)
		if(global.subcom_map)
			global.subcom_map.active_vessels += interceptor
	// Set waypoints for the escort: from start to a point near target
	escort_target.patrol_min_x = start_x - 20
	escort_target.patrol_min_y = start_y - 20
	escort_target.patrol_max_x = start_x + 20
	escort_target.patrol_max_y = start_y + 20
	var/msg = pick(escort_messages)
	msg = replacetext(msg, "%X", "[escort_x]")
	msg = replacetext(msg, "%Y", "[escort_y]")
	send_radio_message(msg)

// ---- Spawn: Recon ----

/datum/mission_controller/proc/spawn_recon_mission()
	mission_timer = 0
	// Spawn a few hostile patrols in the area (they don't know you're there yet)
	var/num_contacts = rand(1, 3)
	for(var/i = 1 to num_contacts)
		var/c_x = target_x + rand(-80, 80)
		var/c_y = target_y + rand(-80, 80)
		c_x = clamp(c_x, 50, 950)
		c_y = clamp(c_y, 50, 950)
		var/datum/vessel_contact/npc/contact = spawn_random_enemy(c_x, c_y)
		contact.patrol_min_x = c_x - 40
		contact.patrol_min_y = c_y - 40
		contact.patrol_max_x = c_x + 40
		contact.patrol_max_y = c_y + 40
		if(global.subcom_map)
			global.subcom_map.active_vessels += contact
	var/msg = pick(recon_messages)
	msg = replacetext(msg, "%X", "[target_x]")
	msg = replacetext(msg, "%Y", "[target_y]")
	send_radio_message(msg)

// ---- Spawn: Rescue ----

/datum/mission_controller/proc/spawn_rescue_mission()
	// Spawn a damaged friendly sub at the target coordinates
	target_vessel = spawn_enemy_npc(/datum/subcom_enemy/sub_diesel, target_x, target_y)
	target_vessel.nationality = SUB_NATION_FRIENDLY
	target_vessel.name = pick("K-218", "K-447", "K-315", "K-524")
	target_vessel.hull_strength = rand(80, 150)  // Critically damaged
	target_vessel.max_hull_strength = 700
	// Make it very slow — engines damaged
	target_vessel.max_speed = 3
	target_vessel.patrol_speed = 2
	target_vessel.attack_speed = 0
	// Give it minimal patrol waypoints (it's barely moving)
	target_vessel.patrol_min_x = target_x - 5
	target_vessel.patrol_min_y = target_y - 5
	target_vessel.patrol_max_x = target_x + 5
	target_vessel.patrol_max_y = target_y + 5
	if(global.subcom_map)
		global.subcom_map.active_vessels += target_vessel
	// Spawn hostile ASW units hunting the damaged sub
	var/list/hunter_types = list(
		/datum/subcom_enemy/patrol_boat,
		/datum/subcom_enemy/frigate
	)
	var/num_hunters = rand(1, 2)
	for(var/i = 1 to num_hunters)
		var/h_x = target_x + rand(-60, 60)
		var/h_y = target_y + rand(-60, 60)
		h_x = clamp(h_x, 50, 950)
		h_y = clamp(h_y, 50, 950)
		var/datum/vessel_contact/npc/hunter = spawn_enemy_npc(pick(hunter_types), h_x, h_y)
		hunter.patrol_min_x = target_x - 50
		hunter.patrol_min_y = target_y - 50
		hunter.patrol_max_x = target_x + 50
		hunter.patrol_max_y = target_y + 50
		if(global.subcom_map)
			global.subcom_map.active_vessels += hunter
	var/msg = pick(rescue_messages)
	msg = replacetext(msg, "%X", "[target_x]")
	msg = replacetext(msg, "%Y", "[target_y]")
	send_radio_message(msg)

// ---- Spawn: Ambush ----

/datum/mission_controller/proc/spawn_ambush_mission()
	mission_timer = SUB_MISSION_AMBUSH_TIMEOUT
	ambush_hostiles = list()
	// Spawn a group of hostiles that will transit the area
	var/list/group_types = list(
		/datum/subcom_enemy/destroyer,
		/datum/subcom_enemy/frigate,
		/datum/subcom_enemy/corvette,
		/datum/subcom_enemy/patrol_boat
	)
	var/num_hostiles = rand(2, 4)
	for(var/i = 1 to num_hostiles)
		var/h_x = target_x + rand(-100, 100)
		var/h_y = target_y + rand(-100, 100)
		h_x = clamp(h_x, 50, 950)
		h_y = clamp(h_y, 50, 950)
		var/datum/vessel_contact/npc/hostile = spawn_enemy_npc(pick(group_types), h_x, h_y)
		hostile.patrol_min_x = target_x - 30
		hostile.patrol_min_y = target_y - 30
		hostile.patrol_max_x = target_x + 30
		hostile.patrol_max_y = target_y + 30
		ambush_hostiles += hostile
		if(global.subcom_map)
			global.subcom_map.active_vessels += hostile
	var/msg = pick(ambush_messages)
	msg = replacetext(msg, "%X", "[target_x]")
	msg = replacetext(msg, "%Y", "[target_y]")
	send_radio_message(msg)

// ---- Mission Completion ----

/datum/mission_controller/proc/complete_mission(var/flavor_msg)
	mission_active = FALSE
	is_completed = TRUE
	missions_completed++

	var/msg = flavor_msg || "Objective complete. Well done, Commander. Returning to patrol status."
	send_radio_message("COMMAND: [msg] Next orders incoming shortly.")

	cleanup_previous_mission()
	next_mission_delay = rand(SUB_MISSION_SUCCESS_DELAY_MIN, SUB_MISSION_SUCCESS_DELAY_MAX)

// ---- Mission Failure ----

/datum/mission_controller/proc/fail_mission(var/reason)
	mission_active = FALSE
	is_completed = FALSE
	missions_failed++

	send_radio_message("COMMAND: Mission failed. [reason] Regroup and await new orders.")

	cleanup_previous_mission()
	next_mission_delay = SUB_MISSION_FAIL_DELAY

// ---- Cleanup ----

/datum/mission_controller/proc/cleanup_previous_mission()
	if(target_vessel)
		target_vessel = null
	if(escort_target)
		escort_target = null
	ambush_hostiles = list()
	mission_timer = 0

// ---- Radio Relay ----

/datum/mission_controller/proc/send_radio_message(var/message)
	if(!radio_console)
		for(var/obj/structure/machinery/sub_control/radio_console/RC in world)
			radio_console = RC
			break
	if(radio_console)
		radio_console.add_log(message)

// ---- Mission Status Query ----

/datum/mission_controller/proc/get_status_text()
	if(!mission_active)
		return "NO ACTIVE ORDERS"
	var/msg = "MISSION: [current_objective_type]\n"
	msg += "TARGET: [target_x], [target_y]\n"
	switch(current_objective_type)
		if(SUB_MISSION_SINK_CARGO)
			if(target_vessel)
				msg += "TARGET INTEGRITY: [target_vessel.hull_strength]%\n"
			else
				msg += "TARGET STATUS: DESTROYED\n"
		if(SUB_MISSION_PATROL)
			msg += "PATROL AREA: HOLD POSITION\n"
		if(SUB_MISSION_ESCORT)
			if(escort_target)
				msg += "ESCORT VESSEL: [escort_target.name]\n"
				msg += "ESCORT HULL: [escort_target.hull_strength]%\n"
			else
				msg += "ESCORT STATUS: LOST\n"
		if(SUB_MISSION_RECON)
			msg += "OBSERVATION TIME: [mission_timer]/[SUB_MISSION_RECON_DURATION]\n"
		if(SUB_MISSION_RESCUE)
			if(target_vessel)
				msg += "RESCUE VESSEL: [target_vessel.name] (HULL: [target_vessel.hull_strength]%)\n"
				var/dist = euclidean_distance(target_vessel.x_pos, target_vessel.y_pos, start_x, start_y)
				msg += "DISTANCE TO SAFE WATERS: [round(dist)]nm\n"
			else
				msg += "RESCUE VESSEL: LOST\n"
		if(SUB_MISSION_AMBUSH)
			var/alive = 0
			for(var/datum/vessel_contact/npc/N in ambush_hostiles)
				if(!QDELETED(N) && N.hull_strength > 0)
					alive++
			msg += "HOSTILES REMAINING: [alive]\n"
			msg += "TIME REMAINING: [mission_timer] ticks\n"
	return msg
