#define NO_WINNER "The round is proceeding normally."
/obj/map_metadata/nomads_jungle
	ID = MAP_NOMADS_JUNGLE
	title = "Nomads (Jungle) (300x300x2)"
	lobby_icon_state = "civ13"
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
		"Empire Earth Intro:1" = 'sound/music/words_through_the_sky.ogg',)
	research_active = TRUE
	nomads = TRUE
	gamemode = "Classic (Stone Age Start)"
	var/list/arealist_r = list()
	var/list/arealist_g = list()
	var/real_season = "wet"
/obj/map_metadata/nomads_jungle/New()
	..()
	spawn(1200)
		for (var/i = 1, i <= 180, i++)
			var/turf/areaspawn = safepick(get_area_turfs(/area/caribbean/nomads/river))
			new/obj/structure/piranha(areaspawn)
	spawn(600)
		for (var/i = 1, i <= 23, i++)
			var/turf/areaspawn2 = safepick(get_area_turfs(/area/caribbean/nomads/forest))
			new/obj/structure/anthill(areaspawn2)

	spawn(1800)
		if (season == "SPRING") //fixes game setting the season as spring
			season = "Wet Season"
	spawn(18000)
		seasons()

/obj/map_metadata/nomads_jungle/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 0 || admin_ended_all_grace_periods)

/obj/map_metadata/nomads_jungle/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 0 || admin_ended_all_grace_periods)

/obj/map_metadata/nomads_jungle/cross_message(faction)
	return ""

/obj/map_metadata/nomads_jungle/proc/seasons()
	if (real_season == "dry")
		season = "Wet Season"
		world << "<big>The <b>Wet Season</b> has started.</big>"
			change_weather_somehow()
		for (var/turf/floor/dirt/flooded/D)
			D.ChangeTurf(/turf/floor/beach/water/flooded)
		for (var/turf/floor/dirt/ploughed/flooded/D)
			for(var/obj/OB in src.loc)
				if ( istype(OB, /obj/item) || istype(OB, /obj/structure) || istype(OB, /obj/effect) || istype(OB, /obj/small_fire) )
					qdel(OB)
			D.ChangeTurf(/turf/floor/beach/water/flooded)
		real_season = "wet"
		for (var/turf/floor/dirt/jungledirt/JD)
			if (prob(50))
				JD.ChangeTurf(/turf/floor/grass/jungle)
		for (var/turf/floor/dirt/burned/BJ)
			if (prob(75))
				BJ.ChangeTurf(/turf/floor/dirt/jungledirt)
	else
		season = "Dry Season"
		world << "<big>The <b>Dry Season</b> has started.</big>"
			change_weather_somehow()
		for (var/turf/floor/beach/water/flooded/D)
			D.ChangeTurf(/turf/floor/dirt/flooded)
		real_season = "dry"
		spawn(12000)
			world << "<big>The sky starts to get cloudy... The <b>Wet Season</b> is coming in 10 minutes.</big>"

	spawn(18000)
		seasons()


/obj/map_metadata/nomads_jungle/job_enabled_specialcheck(var/datum/job/J)
	if (J.is_nomad == TRUE)
		. = TRUE
	else
		. = FALSE
#undef NO_WINNER