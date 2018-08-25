#define NO_WINNER "The round is proceeding normally."
/obj/map_metadata/tribes
	ID = MAP_TRIBES
	title = "Tribes (225x225x2)"
//	lobby_icon_state = "pirates"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 6000 // 10 minutes!
	squad_spawn_locations = FALSE
	reinforcements = FALSE
//	min_autobalance_players = 90
	faction_organization = list(
		INDIANS,
		PIRATES)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(INDIANS) = /area/caribbean/indians,
		list(INDIANS) = /area/caribbean/pirates,
		)
	front = "Pacific"
	faction_distribution_coeffs = list(INDIANS = 0.6, PIRATES = 0.3)
	battle_name = "Tribal village"
	mission_start_message = "A ship of europeans has reached the shores! The <b>Natives</b> must fortify their village and the <b>Pirates</b> must establish a base inland. The ship will depart after 25 minutes, and the gracewall will be up by then." // to be replaced with the round's main event
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = INDIANS
	faction2 = PIRATES
	single_faction = TRUE
	var/first_event_done = FALSE
	var/do_first_event = 600//25 mins
obj/map_metadata/tribes/job_enabled_specialcheck(var/datum/job/J)
	if ((istype(J, /datum/job/indians)))
		if (!(istype(J, /datum/job/indians/tribes)))
			. = FALSE
	else
		. = TRUE
	return .
/obj/map_metadata/tribes/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 15000 || admin_ended_all_grace_periods)

/obj/map_metadata/tribes/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 15000 || admin_ended_all_grace_periods)

/obj/map_metadata/tribes/cross_message(faction)
	return ""

/obj/map_metadata/tribes/reinforcements_ready()
	return (faction2_can_cross_blocks() && faction1_can_cross_blocks())

/obj/map_metadata/tribes/check_events()
	if ((world.time >= do_first_event) && !first_event_done)
		world << "The ship will depart in <b>5</b> minutes! Finish unloading it and get ashore!"
		first_event_done = TRUE
		spawn(3000)
			for (var/obj/effect/area_teleporter/AT)
				if (AT.id == "one")
					AT.Activated()
					world << "The ship is departing!"
					return TRUE
	else return FALSE


/obj/map_metadata/tribes/New() // since DM doesn't want to attribute random vars at the beggining...
	..()
	do_first_event = 600

#undef NO_WINNER