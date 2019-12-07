
/obj/map_metadata/nomads_divide
	ID = MAP_NOMADS_DIVIDE
	title = "Nomads (Jungle-Desert) (250x250x2)"
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
/obj/map_metadata/nomads_divide/New()
	..()
	spawn(2600)
		for (var/i = 1, i <= 30, i++)
			var/turf/areaspawn = safepick(get_area_turfs(/area/caribbean/nomads/river))
			new/obj/structure/fish/salmon(areaspawn)
	spawn(2400)
		for (var/i = 1, i <= 30, i++)
			var/turf/areaspawn = safepick(get_area_turfs(/area/caribbean/tribes/swamp))
			new/obj/structure/fish/salmon(areaspawn)
	spawn(2600)
		for (var/i = 1, i <= 40, i++)
			var/turf/areaspawn = safepick(get_area_turfs(/area/caribbean/nomads/river))
			new/obj/structure/piranha(areaspawn)
	spawn(2700)
		for (var/i = 1, i <= 15, i++)
			var/turf/areaspawn2 = safepick(get_area_turfs(/area/caribbean/nomads/forest))
			new/obj/structure/anthill(areaspawn2)

	spawn(1200)
		if (season == "SPRING") //fixes game setting the season as spring
			season = "Wet Season"
	spawn(20000)
		seasons()

/obj/map_metadata/nomads_divide/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 0 || admin_ended_all_grace_periods)

/obj/map_metadata/nomads_divide/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 0 || admin_ended_all_grace_periods)

/obj/map_metadata/nomads_divide/cross_message(faction)
	return ""

/obj/map_metadata/nomads_divide/job_enabled_specialcheck(var/datum/job/J)
	if (J.is_nomad == TRUE)
		. = TRUE
	else
		. = FALSE
