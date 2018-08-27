#define NO_WINNER "The round is proceeding normally."
/obj/map_metadata/colony
	ID = MAP_COLONY
	title = "Colony (155x225x3)"
	lobby_icon_state = "colony2"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 3000 // 5 minutes!
	squad_spawn_locations = FALSE
//	min_autobalance_players = 90
	faction_organization = list(
		INDIANS,
		CIVILIAN)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(INDIANS) = /area/caribbean/british,
		list(CIVILIAN) = /area/caribbean/british,
		)
	front = "Pacific"
	faction_distribution_coeffs = list(INDIANS = 0.5, CIVILIAN = 0.5)
	battle_name = "jungle raid"
	mission_start_message = "<big>An European ship has reached the shore! The <b>Natives</b> and the <b>Colonists</b> must build their villages. The ship will depart after 25 minutes, and the gracewall will be up by then.</big>" // to be replaced with the round's main event
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = INDIANS
	faction2 = CIVILIAN
	single_faction = FALSE
	songs = list(
		"Nassau Shores:1" = 'sound/music/nassau_shores.ogg',
		"Black Sails:1" = 'sound/music/black_sails.ogg')
	var/first_event_done = FALSE
	var/do_first_event = 12000//25 mins
obj/map_metadata/colony/job_enabled_specialcheck(var/datum/job/J)
	if (istype(J, /datum/job/pirates/battleroyale))
		. = FALSE
	else if (istype(J, /datum/job/indians/tribes))
		. = FALSE
	else
		. = TRUE
/obj/map_metadata/colony/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 15000 || admin_ended_all_grace_periods)

/obj/map_metadata/colony/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 15000 || admin_ended_all_grace_periods)

/obj/map_metadata/colony/cross_message(faction)
	return ""


/obj/map_metadata/colony/check_events()
	if ((world.time >= do_first_event) && !first_event_done)
		world << "<big>The ship will depart in <b>5</b> minutes! Finish unloading it and get ashore!</big>"
		first_event_done = TRUE
		spawn(3000)
			for (var/obj/effect/area_teleporter/AT)
				if (AT.id == "one")
					AT.Activated()
					world << "<big>The ship is departing!</big>"
					return TRUE
	else return FALSE


/obj/map_metadata/colony/New() // since DM doesn't want to attribute random vars at the beggining...
	..()
	do_first_event = 12000

#undef NO_WINNER