// ============================================================
// SUBCOM13 Map Metadata — Submarine Commander game mode.
// Instantiates core datums on map load and drives round logic.
// ============================================================

/obj/map_metadata/subcom13
	ID = MAP_SUBCOM13
	title = "Submarine Commander"
	description = "Command a nuclear submarine through hostile waters. Complete missions, manage your crew, and survive."
	gamemode = "Submarine Commander"
	lobby_icon = 'icons/lobby/civ13.gif'
	caribbean_blocking_area_types = list()
	respawn_delay = 0
	faction_organization = list(AMERICAN)
	roundend_condition_sides = list()
	availablefactions = list("US Navy")
	mission_start_message = "Reporting for duty, Commander. Your submarine awaits."
	faction1 = AMERICAN
	faction2 = null
	required_players = 0
	gamemode_vote = FALSE
	is_RP = TRUE

	// Submarine-specific tracking
	var/datum/submarine/created_sub
	var/game_over = FALSE
	var/missions_completed = 0
	var/missions_failed = 0

/obj/map_metadata/subcom13/New()
	..()

	// Create the player's submarine
	created_sub = new /datum/submarine()
	global.all_submarines += created_sub

	// Create the world map controller (also creates flooding controller)
	if(!global.subcom_map)
		new /datum/world_map_controller()

	// Initialize with the sub
	if(global.subcom_map)
		global.subcom_map.initialize(created_sub)

	// Register all deck turfs with the flooding controller and populate internal_turfs
	// NOTE: set_compartment_id MUST run before register_turf so compartment_id is set
	if(global.subcom_flooding && created_sub)
		for(var/turf/floor/sub_deck/T in world)
			if(T.z == z)
				set_compartment_id(T)
				global.subcom_flooding.register_turf(T)
				created_sub.internal_turfs += T
		for(var/turf/wall/sub_hull/T in world)
			if(T.z == z)
				created_sub.internal_turfs += T

/obj/map_metadata/subcom13/proc/set_compartment_id(var/turf/floor/sub_deck/T)
	// Compartment layout for 58-wide submarine interior map.
	// Bow = low x, stern = high x.
	// Hull cap: x 1-2, Fwd Torpedo: 3-8, bulkhead: 9,
	// Fwd Battery: 10-15, bulkhead: 16, Operations: 17-23,
	// bulkhead: 24, Crew: 25-30, bulkhead: 31, Galley: 32-35,
	// bulkhead: 36, CPO: 37-42, bulkhead: 43, Aft Battery: 44-50,
	// bulkhead: 51, Reactor: 52-55, Engine: 56-58
	switch(T.x)
		if(3 to 8)
			T.compartment_id = SUB_COMP_FORWARD_TORPEDO
		if(10 to 15)
			T.compartment_id = SUB_COMP_FORWARD_BATTERY
		if(17 to 23)
			T.compartment_id = SUB_COMP_OPERATIONS
		if(25 to 30)
			T.compartment_id = SUB_COMP_CREW_QUARTERS
		if(32 to 35)
			T.compartment_id = SUB_COMP_GALLEY
		if(37 to 42)
			T.compartment_id = SUB_COMP_CPO_QUARTERS
		if(44 to 50)
			T.compartment_id = SUB_COMP_AFT_BATTERY
		if(52 to 55)
			T.compartment_id = SUB_COMP_REACTOR_ROOM
		if(56 to 58)
			T.compartment_id = SUB_COMP_ENGINE_ROOM

/obj/map_metadata/subcom13/update_win_condition()
	if(game_over)
		return

	// Check for game-over conditions
	if(created_sub)
		// Crush depth death
		if(created_sub.depth > created_sub.crush_depth)
			world << "<font size=5 color='red'><b>The submarine has been crushed at depth [round(created_sub.depth)]m!</b></font>"
			world << "<font size=3>The hull has failed. All hands lost.</font>"
			game_over = TRUE
			ticker.finished = TRUE
			return

		// Check if sub is flooding catastrophically (all compartments flooded)
		if(global.subcom_flooding)
			var/flooded = 0
			var/total = 0
			for(var/cid in global.subcom_flooding.compartment_turfs)
				total++
				if(global.subcom_flooding.is_compartment_flooded(cid))
					flooded++
			if(total > 0 && flooded >= total)
				world << "<font size=5 color='red'><b>The submarine is completely flooded!</b></font>"
				world << "<font size=3>All compartments are underwater. The boat is lost.</font>"
				game_over = TRUE
				ticker.finished = TRUE
				return

	// Update mission completion tracking
	if(global.subcom_map && global.subcom_map.missions)
		missions_completed = 0
		missions_failed = 0

/obj/map_metadata/subcom13/cross_message(faction)
	return ""

/obj/map_metadata/subcom13/reverse_cross_message(faction)
	return ""
