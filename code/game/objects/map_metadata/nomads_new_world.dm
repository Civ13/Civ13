
/obj/map_metadata/nomads_new_world
	ID = MAP_NOMADS_NEW_WORLD
	title = "Nomads (New World) (430x200x2)"
	no_winner ="The round is proceeding normally."
	lobby_icon_state = "civ13"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/sea)
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
	mission_start_message = "<big>Human population is expanding fast, and this continent feels small to you - Maybe there is more land to the West? What dangers will it hold? It's up to you to find out, if you dare...</big><br><b>Wiki Guide: http://civ13.com/wiki/index.php/Nomads</b>"
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
/obj/map_metadata/nomads_new_world/New()
	..()
	var/list/totalturfs = get_area_turfs(/area/caribbean/nomads/forest/Jungle)
	totalturfs += get_area_turfs(/area/caribbean/nomads/forest/savanna)
	spawn(1200)
		for (var/i = 1, i <= 100)
			var/turf/areaspawn = safepick(totalturfs)
			if (istype(areaspawn,/turf/floor/beach/water/jungle))
				new/obj/structure/piranha(areaspawn)
				i++
	spawn(600)
		for (var/i = 1, i <= 23)
			var/turf/areaspawn2 = safepick(totalturfs)
			if (istype(areaspawn2,/turf/floor/grass) || istype(areaspawn2,/turf/floor/dirt))
				new/obj/structure/anthill(areaspawn2)
				i++
	spawn(18000)
		seasons()

/obj/map_metadata/nomads_new_world/faction2_can_cross_blocks()
	return (ordinal_age >= 2)

/obj/map_metadata/nomads_new_world/faction1_can_cross_blocks()
	return (ordinal_age >= 2)

/obj/map_metadata/nomads_new_world/cross_message(faction)
	if (faction == CIVILIAN)
		return "<big><b>As the world technological level advances, new shipbuilding techniques make us at last be able to navigate the oceans...</b></big>"

/obj/map_metadata/nomads_new_world/job_enabled_specialcheck(var/datum/job/J)
	if (J.is_nomad == TRUE)
		. = TRUE
	else
		. = FALSE

