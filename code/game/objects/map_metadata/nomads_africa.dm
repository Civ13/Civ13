/obj/map_metadata/nomads_africa
	ID = MAP_NOMADS_AFRICA
	title = "Nomads (Africa)"
	lobby_icon = 'icons/lobby/civilizations.gif'
	no_winner ="The round is proceeding normally."
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 6000 // 10 minutes!
	has_hunger = TRUE
	faction_organization = list(
		CIVILIAN,)

	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/british
		)
	age = "5000 B.C."
	civilizations = TRUE
	var/tribes_nr = 1
	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = "the civilizations"
	mission_start_message = "<big>After ages as hunter-gatherers, people are starting to form groups and settle down. Will they be able to work together?</big><br><b>Wiki Guide: https://civ13.github.io/civ13-wiki/Civilizations_and_Nomads</b>"
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = CIVILIAN
	availablefactions = list("Nomad")
	songs = list(
		"Words Through the Sky:1" = "sound/music/words_through_the_sky.ogg",)
	research_active = TRUE
	nomads = TRUE
	gamemode = "Classic (Stone Age Start)"
	var/list/arealist_r = list()
	var/list/arealist_g = list()

	var/eruptions_enabled = TRUE

/obj/map_metadata/nomads_africa/New()
	..()
	spawn(2000)
		eruption_check()
	spawn(18000)
		seasons()

/obj/map_metadata/nomads_africa/cross_message(faction)
	return ""

/obj/map_metadata/nomads_africa/job_enabled_specialcheck(var/datum/job/J)
	if (J.is_nomad == TRUE)
		. = TRUE
	else
		. = FALSE


/obj/map_metadata/nomads_africa/proc/eruption_check()
	spawn(rand(33000,40000))
		if (eruptions_enabled)
			do_eruption()
		eruption_check()
/obj/map_metadata/nomads_africa/proc/do_eruption()
	if (eruptions_enabled)
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
	else
		return FALSE

/obj/map_metadata/nomads_africa/volcano_eruption()
	for(var/turf/wall/rockwall/lavaspawner/L in world)
		L.start_lava_flow()
	world << "<font color='red'><big><b>The volcano erupts, with lava flowing down the mountain!</b></big></font>"
	return TRUE