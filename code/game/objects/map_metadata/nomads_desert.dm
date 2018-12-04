#define NO_WINNER "The round is proceeding normally."
/obj/map_metadata/nomads_desert
	ID = MAP_NOMADS
	title = "Nomads (Desert) (225x225x2)"
	lobby_icon_state = "civilizations"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 6000 // 10 minutes!
	squad_spawn_locations = FALSE
//	min_autobalance_players = 90
	faction_organization = list(
		CIVILIAN,)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/british
		)
	age = "5000 B.C."
	civilizations = TRUE
	var/tribes_nr = 1
	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = "the civilizations"
	mission_start_message = "<big>After ages as hunter-gatherers, people are starting to form groups and settling down. Will they be able to work together?</big><br><b>Wiki Guide: http://1713.eu/wiki/index.php/Civilizations</b>"
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = CIVILIAN
	availablefactions = list("Nomad")
	songs = list(
		"Empire Earth Intro:1" = 'sound/music/empire_earth_intro.ogg',)
	research_active = TRUE
	age1_lim = 110
	age1_done = 0
	age1_top = 35
	age2_lim = 170
	age2_done = 0
	age2_timer = 40000
	age2_top = 65
	age3_lim = 300
	age3_done = 0
	age3_timer = 42000
	nomads = TRUE

	var/real_season = "wet"
/obj/map_metadata/nomads_desert/New()
	..()
	spawn(1800)
		if (season == "Spring") //fixes game setting the season as spring
			season = "Wet Season"
	spawn(18000)
		seasons()

/obj/map_metadata/nomads_desert/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 0 || admin_ended_all_grace_periods)

/obj/map_metadata/nomads_desert/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 0 || admin_ended_all_grace_periods)

/obj/map_metadata/nomads_desert/cross_message(faction)
	return ""

/obj/map_metadata/nomads_desert/proc/seasons()
	if (real_season == "dry")
		season = "Wet Season"
		world << "<big>The <b>Wet Season</b> has started.</big>"
			change_weather(WEATHER_RAIN, TRUE)
		for(var/obj/structure/sink/S)
			if (istype(S, /obj/structure/sink/well) || istype(S, /obj/structure/sink/puddle))
				S.dry = FALSE
				S.update_icon()
		for (var/turf/floor/plating/beach/drywater/D)
			D.ChangeTurf(/turf/floor/plating/beach/water/swamp)
		real_season = "wet"
	else
		season = "Dry Season"
		world << "<big>The <b>Dry Season</b> has started.</big>"
			change_weather(WEATHER_NONE, TRUE)
		for(var/obj/structure/sink/S)
			if (istype(S, /obj/structure/sink/well) || istype(S, /obj/structure/sink/puddle))
				S.dry = TRUE
				S.update_icon()
		for (var/turf/floor/plating/beach/water/swamp/D)
			D.ChangeTurf(/turf/floor/plating/beach/drywater)
		real_season = "dry"

	spawn(18000)
		seasons()

/obj/map_metadata/nomads_desert/tick()
	..()
	if (age1_done == FALSE)
		var/count = 0
		for(var/i = 1, i <= custom_faction_nr.len, i++)
			count = custom_civs[custom_faction_nr[i]][1]+custom_civs[custom_faction_nr[i]][2]+custom_civs[custom_faction_nr[i]][3]
			if (count > age1_lim && world.time > 36000)
				age = "313 B.C."
				set_ordinal_age()
				age1_done = TRUE
				age2_timer = (world.time + age2_timer)
				break

	else if (age2_done == FALSE)
		var/count = 0
		for(var/i = 1, i <= custom_faction_nr.len, i++)
			count = custom_civs[custom_faction_nr[i]][1]+custom_civs[custom_faction_nr[i]][2]+custom_civs[custom_faction_nr[i]][3]
			if (count > age2_lim && world.time >= age2_timer)
				age = "1013"
				set_ordinal_age()
				age2_done = TRUE
				age3_timer = (world.time + age3_timer)
				break

	else if (age3_done == FALSE)
		var/count = 0
		for(var/i = 1, i <= custom_faction_nr.len, i++)
			count = custom_civs[custom_faction_nr[i]][1]+custom_civs[custom_faction_nr[i]][2]+custom_civs[custom_faction_nr[i]][3]
			if (count > age3_lim && world.time >= age3_timer)
				age = "1713"
				set_ordinal_age()
				age3_done = TRUE
				break

/obj/map_metadata/nomads_desert/job_enabled_specialcheck(var/datum/job/J)
	if (J.is_nomad == TRUE)
		. = TRUE
	else
		. = FALSE
#undef NO_WINNER