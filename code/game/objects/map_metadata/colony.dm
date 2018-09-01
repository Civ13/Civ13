#define NO_WINNER "The round is proceeding normally."
/obj/map_metadata/colony
	ID = MAP_COLONY
	title = "Colony (155x225x2)"
	lobby_icon_state = "colony2"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 7200 // 12 minutes!
	squad_spawn_locations = FALSE
	faction_organization = list(
		INDIANS,
		CIVILIAN,
		PIRATES,
		SPANISH)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(INDIANS) = /area/caribbean/british,
		list(CIVILIAN) = /area/caribbean/british,
		list(PIRATES) = /area/caribbean/british,
		list(SPANISH) = /area/caribbean/british,
		)
	front = "Pacific"
	faction_distribution_coeffs = list(INDIANS = 0.4, CIVILIAN = 0.4, PIRATE = 0.1, SPANISH = 0.1)
	battle_name = "jungle raid"
	mission_start_message = "<big>Europeans</b> has reached the shore! The <b>Natives</b> and the <b>Colonists</b> must build their villages. The ship will depart after 25 minutes, and the gracewall will be up by then.</big><br><span class = 'notice'><i>THIS IS A RP MAP - NATIVES AND COLONISTS ARE FRIENDLY BY DEFAULT.</b> No griefing will be tolerated. If you break the rules, you will be banned from this gamemode!<i></span>" // to be replaced with the round's main event
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = INDIANS
	faction2 = CIVILIAN
	single_faction = FALSE
	songs = list(
		"Nassau Shores:1" = 'sound/music/nassau_shores.ogg',
		"Black Sails:1" = 'sound/music/black_sails.ogg')
	var/first_event_done = FALSE
	var/do_first_event = 600//20 mins

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
		first_event_done = TRUE
//		world << "Deleting unused stuff..."
		var/area1 = /area/caribbean/transport/one
		for (var/obj/A in area1)
			if (!civilians_toggled)
				if (!istype(A, /obj/structure/railing))
					if (!istype(A, /obj/covers))
//						world << "Deleting brit stuff..."
						qdel(A)
		var/area2 = /area/caribbean/transport/two
		for (var/obj/A in area2)
			if (!spanish_toggled)
				if (!istype(A, /obj/structure/railing))
					if (!istype(A, /obj/covers))
//						world << "Deleting spanish stuff..."
						qdel(A)

		var/area3 = /area/caribbean/transport/three
		for (var/obj/A in area3)
			if (!pirates_toggled)
				if (!istype(A, /obj/structure/railing))
					if (!istype(A, /obj/covers))
//						world << "Deleting pirate stuff..."
						qdel(A)
		return TRUE
	else
		return FALSE

/obj/map_metadata/colony/New() // since DM doesn't want to attribute random vars at the beggining...
	..()
	do_first_event = 600
#undef NO_WINNER