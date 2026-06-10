// ============================================================
// Mission Controller — generates objectives and relays
// encrypted transmissions to the sub's radio console.
// ============================================================

/datum/mission_controller
	var/current_objective_type = ""     // e.g. SUB_MISSION_SINK_CARGO
	var/target_x = 0
	var/target_y = 0
	var/is_completed = FALSE
	var/mission_active = FALSE
	var/datum/vessel_contact/npc/target_vessel  // NPC we must destroy/escort
	var/datum/world_map_controller/parent_map
	var/obj/structure/machinery/sub_control/radio_console/radio_console
	var/next_mission_delay = 0           // Ticks before next mission spawns

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

	// Check if the target vessel has been sunk
	if(target_vessel)
		if(QDELETED(target_vessel) || target_vessel.hull_strength <= 0)
			complete_mission()
	else
		// Target was qdel'd externally
		complete_mission()

// ---- Mission Generation ----

/datum/mission_controller/proc/generate_new_mission()
	// Pick a random objective type
	var/list/possible_types = list(SUB_MISSION_SINK_CARGO, SUB_MISSION_SINK_CARGO, SUB_MISSION_PATROL)
	current_objective_type = pick(possible_types)

	target_x = rand(100, 900)
	target_y = rand(100, 900)

	switch(current_objective_type)
		if(SUB_MISSION_SINK_CARGO)
			// Spawn a cargo ship at the target coordinates
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

		if(SUB_MISSION_PATROL)
			// Spawn a random hostile in the patrol area
			var/datum/vessel_contact/npc/patrol_enemy = spawn_random_enemy(target_x, target_y)
			if(global.subcom_map)
				global.subcom_map.active_vessels += patrol_enemy
			var/msg = pick(patrol_messages)
			msg = replacetext(msg, "%X", "[target_x]")
			msg = replacetext(msg, "%Y", "[target_y]")
			send_radio_message(msg)

	mission_active = TRUE
	is_completed = FALSE

// ---- Mission Completion ----

/datum/mission_controller/proc/complete_mission()
	mission_active = FALSE
	is_completed = TRUE
	target_vessel = null

	send_radio_message("COMMAND: Objective complete. Well done, Commander. Returning to patrol status. Next orders incoming shortly.")

	// Delay before next mission
	next_mission_delay = rand(30, 60)  // 30-60 ticks (1-2 minutes)

// ---- Radio Relay ----

/datum/mission_controller/proc/send_radio_message(var/message)
	if(!radio_console)
		// Try to find the radio console
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
	if(target_vessel)
		msg += "TARGET INTEGRITY: [target_vessel.hull_strength]%\n"
	else
		msg += "TARGET STATUS: DESTROYED\n"
	return msg
