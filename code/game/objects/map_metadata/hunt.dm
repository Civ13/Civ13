#define NO_WINNER "The round is proceeding normally."
/obj/map_metadata/hunt
	ID = MAP_HUNT
	title = "Hunt (175x175x2)"
	lobby_icon_state = "imperial"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 6000 // 10 minutes!
	squad_spawn_locations = FALSE
	faction_organization = list(
		INDIANS,
		PIRATES)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(INDIANS) = /area/caribbean/british,
		list(PIRATES) = /area/caribbean/british,
		)
	age = "1713"
	ordinal_age = 3
	faction_distribution_coeffs = list(INDIANS = 0.5, PIRATE = 0.5)
	battle_name = "marooned pirates"
	mission_start_message = "<big>After a major storm, a Pirate shipwreck has come ashore in an unknown Island. However, they are not alone...<br> The gracewall will be up after <b>45 minutes</b>.</big><br><span class = 'notice'><i>THIS IS A RP MAP - NATIVES AND PIRATES ARE FRIENDLY BY DEFAULT.</b> No griefing will be tolerated. If you break the rules, you will be banned from this gamemode!<i></span>" // to be replaced with the round's main event
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = INDIANS
	faction2 = PIRATES
	songs = list(
		"Nassau Shores:1" = 'sound/music/nassau_shores.ogg',)
	gamemode = "Survival RP"

/obj/map_metadata/hunt/New()
	..()
	spawn(1200)
		for (var/i = 1, i <= 50, i++)
			var/turf/areaspawn = safepick(get_area_turfs(/area/caribbean/island/river))
			new/obj/structure/piranha(areaspawn)

obj/map_metadata/hunt/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/pirates))
		if (istype(J, /datum/job/pirates/marooned))
			. = TRUE
		else
			. = FALSE
	if (istype(J, /datum/job/indians))
		if (istype(J, /datum/job/indians/tribes/red))
			. = TRUE
		else
			. = FALSE
/obj/map_metadata/hunt/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 27000 || admin_ended_all_grace_periods)

/obj/map_metadata/hunt/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 27000 || admin_ended_all_grace_periods)

/obj/map_metadata/hunt/cross_message(faction)
	return "The gracewall is now removed."


#undef NO_WINNER