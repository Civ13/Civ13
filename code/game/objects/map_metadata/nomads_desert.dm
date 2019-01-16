#define NO_WINNER "The round is proceeding normally."
/obj/map_metadata/nomads_desert
	ID = MAP_NOMADS_DESERT
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
	mission_start_message = "<big>After ages as hunter-gatherers, people are starting to form groups and settling down. Will they be able to work together?</big><br><b>Wiki Guide: http://1713.eu/wiki/index.php/Nomads</b>"
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = CIVILIAN
	availablefactions = list("Nomad")
	songs = list(
		"Empire Earth Intro:1" = 'sound/music/empire_earth_intro.ogg',)
	research_active = TRUE
	age1_lim = 75
	age1_done = 0
	age1_top = 35
	age2_lim = 150
	age2_done = 0
	age2_timer = 40000
	age2_top = 65
	age3_lim = 240
	age3_done = 0
	age3_timer = 42000
	age3_top = 85
	age4_lim = 315
	age4_done = 0
	age4_timer = 42000
	age4_top = 120
	age5_lim = 360
	age5_done = 0
	age5_timer = 42000
	age5_top = 140
	nomads = TRUE
	gamemode = "Classic (Stone Age Start)"
	var/real_season = "wet"
/obj/map_metadata/nomads_desert/New()
	..()
	spawn(1800)
		if (season == "SPRING") //fixes game setting the season as spring
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
			change_weather_somehow()
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
			change_weather_somehow()
		for(var/obj/structure/sink/S)
			if (istype(S, /obj/structure/sink/well) || istype(S, /obj/structure/sink/puddle))
				S.dry = TRUE
				S.update_icon()
		for (var/turf/floor/plating/beach/water/swamp/D)
			D.ChangeTurf(/turf/floor/plating/beach/drywater)
		real_season = "dry"

	spawn(18000)
		seasons()


/obj/map_metadata/nomads_desert/job_enabled_specialcheck(var/datum/job/J)
	if (J.is_nomad == TRUE)
		. = TRUE
	else
		. = FALSE
#undef NO_WINNER