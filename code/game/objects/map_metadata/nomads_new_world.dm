
/obj/map_metadata/nomads_new_world
	ID = MAP_NOMADS_NEW_WORLD
	title = "Nomads (New World)"
	no_winner ="The round is proceeding normally."
	lobby_icon_state = "civ13"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/sea)
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
	mission_start_message = "<big>Human population is expanding fast, and this continent feels small to you - Maybe there is more land to the West? What dangers will it hold? It's up to you to find out, if you dare...</big><br><b>Wiki Guide: https://civ13.github.io/civ13-wiki/Civilizations_and_Nomads</b>"
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
/obj/map_metadata/nomads_new_world/New()
	..()

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

