
/obj/map_metadata/nomads_island
	ID = MAP_NOMADS_ISLAND
	title = "Nomads (Island) (200x200x2)"
	lobby_icon_state = "civ13"
	no_winner ="The round is proceeding normally."
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
	mission_start_message = "<big>After ages as hunter-gatherers, people are starting to form groups and settling down. Will they be able to work together?</big><br><b>Wiki Guide: http://civ13.com/wiki/index.php/Nomads</b>"
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = CIVILIAN
	availablefactions = list("Nomad")
	songs = list(
		"Words Through the Sky:1" = 'sound/music/words_through_the_sky.ogg',)
	research_active = TRUE
	nomads = TRUE
	gamemode = "Classic (Stone Age Start)"
	var/list/arealist_r = list()
	var/list/arealist_g = list()
	var/real_season = "wet"
/obj/map_metadata/nomads_island/New()
	..()
	spawn(1200)
		for (var/i = 1, i <= 180, i++)
			var/turf/areaspawn = safepick(get_area_turfs(/area/caribbean/nomads/river))
			new/obj/structure/piranha(areaspawn)
	spawn(600)
		for (var/i = 1, i <= 23, i++)
			var/turf/areaspawn2 = safepick(get_area_turfs(/area/caribbean/nomads/forest))
			new/obj/structure/anthill(areaspawn2)
	spawn(2000)
		eruption_check()
	spawn(1800)
		if (season == "SPRING") //fixes game setting the season as spring
			season = "Wet Season"
	spawn(18000)
		seasons()

/obj/map_metadata/nomads_island/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 0 || admin_ended_all_grace_periods)

/obj/map_metadata/nomads_island/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 0 || admin_ended_all_grace_periods)

/obj/map_metadata/nomads_island/cross_message(faction)
	return ""

/obj/map_metadata/nomads_island/job_enabled_specialcheck(var/datum/job/J)
	if (J.is_nomad == TRUE)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/nomads_island/proc/eruption_check()
	spawn(rand(72000,126000))
		do_eruption()
		eruption_check()
/obj/map_metadata/nomads_island/proc/do_eruption()
	if (clients.len>5)
		world << "<big><b>The mountain rumbles, while clouds of smoke emerge from the top... An eruption might be coming...</big></b>"
		spawn(rand(4800,6000))
			if (clients.len>5)
				volcano_eruption()
				return TRUE
			else
				return FALSE
	else
		return FALSE