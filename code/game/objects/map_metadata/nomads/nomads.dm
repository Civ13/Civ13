
/obj/map_metadata/nomads
	ID = MAP_NOMADS
	title = "Nomads (Temperate)"
	lobby_icon = ""
	no_winner ="The round is proceeding normally."
	//there isn't really an invisible wall on nomads but still
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 6000 // 10 minutes!

	faction1 = CIVILIAN
	availablefactions = list("Nomad")
	faction_distribution_coeffs = list(CIVILIAN = 1)
	faction_organization = list(CIVILIAN)
	//non-existent to prevent rounds from ending
	roundend_condition_sides = list(list(CIVILIAN) = /area/caribbean/british)

	age = "5000 B.C."
	civilizations = TRUE
	nomads = TRUE
	has_hunger = TRUE
	research_active = TRUE
	gamemode = "Classic (Stone Age Start)"

	battle_name = "conflict of the nomads"
	mission_start_message = "<big>After ages as hunter-gatherers, people are starting to form groups and settle down. Will they be able to work together?</big><br><b>Wiki Guide: https://civ13.github.io/civ13-wiki/gamemodes/Civilizations_and_Nomads</b>"

	ambience = list('sound/ambience/jungle1.ogg')
	songs = list("Words Through the Sky:1" = 'sound/music/words_through_the_sky.ogg')

/obj/map_metadata/nomads/New()
	..()
	spawn(18000)
		seasons()

/obj/map_metadata/nomads/cross_message(faction)
	return ""

