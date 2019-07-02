#define NO_WINNER "The ship is on the way."
/obj/map_metadata/voyage
	ID = MAP_VOYAGE
	title = "Voyage (75x75x4)"
//	lobby_icon_state = "imperial"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 0
	squad_spawn_locations = FALSE
//	min_autobalance_players = 90
	faction_organization = list(
		BRITISH)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(BRITISH) = /area/caribbean/british/ship/lower,
		)
	age = "1713"
	ordinal_age = 3
	faction_distribution_coeffs = list(BRITISH = 1)
	battle_name = "Transatlantic Voyage"
	mission_start_message = "<font size=4>The travel is starting. Hold the ship against the pirates!</font>"

	var/first_event_done = FALSE
	var/second_event_done = FALSE
	var/third_event_done = FALSE
	var/fourth_event_done = FALSE
	var/fifth_event_done = FALSE
	var/do_first_event = 1000
	var/do_second_event = 1000
	var/do_third_event = 1000
	var/do_fourth_event = 1000
	var/do_fifth_event = 1000
/obj/map_metadata/voyage/check_events()
	if ((world.time >= do_first_event) && !first_event_done)
		world << "Pirates are approaching!"
		first_event_done = TRUE
		spawn(200)
			for (var/obj/effect/area_teleporter/AT)
				if (AT.id == "one")
					AT.Activated()
					world << "Pirates are trying to board the ship!"
					return TRUE
	if ((world.time >= do_second_event) && !second_event_done)
		world << "Pirates are approaching!"
		second_event_done = TRUE
		spawn(200)
			for (var/obj/effect/area_teleporter/AT)
				if (AT.id == "two")
					AT.Activated()
					world << "Pirates are trying to board the ship!"
					return TRUE
	if ((world.time >= do_third_event) && !third_event_done)
		world << "Pirates are approaching!"
		third_event_done = TRUE
		spawn(200)
			for (var/obj/effect/area_teleporter/AT)
				if (AT.id == "three")
					AT.Activated()
					world << "Pirates are trying to board the ship!"
					return TRUE
	if ((world.time >= do_fourth_event) && !fourth_event_done)
		world << "Pirates are approaching!"
		fourth_event_done = TRUE
		spawn(200)
			for (var/obj/effect/area_teleporter/AT)
				if (AT.id == "fourth")
					AT.Activated()
					world << "Pirates are trying to board the ship!"
					return TRUE
	if ((world.time >= do_fifth_event) && !fifth_event_done)
		world << "Pirates are approaching!"
		fifth_event_done = TRUE
		spawn(200)
			for (var/obj/effect/area_teleporter/AT)
				if (AT.id == "fifth")
					AT.Activated()
					world << "Pirates are trying to board the ship!"
					return TRUE
	else return FALSE

/obj/map_metadata/voyage/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 100000 || admin_ended_all_grace_periods)

/obj/map_metadata/voyage/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 100000 || admin_ended_all_grace_periods)

/obj/map_metadata/voyage/New() // since DM doesn't want to attribute random vars at the beggining...
	..()
	do_first_event = rand(600,960)
	do_second_event = do_first_event  + rand(6000,9600)
	do_third_event = do_second_event  + rand(6000,9600)
	do_fourth_event = do_third_event  + rand(5000,8000)
	do_fifth_event = do_fourth_event  + rand(4000,7000)

#undef NO_WINNER