
/obj/map_metadata/nomads_testing
	ID = MAP_NOMADS_TESTING
	title = "Nomads (Testing)"
	lobby_icon = 'icons/lobby/nomads_testing.png'
	no_winner ="The round is proceeding normally."
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 1500 // 2.5 minutes!
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
	mission_start_message = "<big>ETC13 Testing server.</big><br><b>Wiki Guide: https://new-civ13.github.io/civ13-wiki/Civilizations_and_Nomads</b>"
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = CIVILIAN
	availablefactions = list("Nomad")
	songs = list(
		"Cursed singing:1" = 'sound/music/cursed_singing.ogg',)
	research_active = TRUE
	nomads = TRUE
	gamemode = "Classic (Stone Age Start)"
	var/list/arealist_r = list()
	var/list/arealist_g = list()
/obj/map_metadata/nomads_testing/New()
	..()
	spawn(18000)
		seasons()

/obj/map_metadata/nomads_testing/cross_message(faction)
	return ""

/obj/map_metadata/nomads_testing/job_enabled_specialcheck(var/datum/job/J)
	if (J.is_nomad == TRUE)
		. = TRUE
	else
		. = FALSE

