
/obj/map_metadata/chad_jungle
	ID = MAP_JUNGLE_OF_THE_CHADS
	title = "JUNGLE OF THE CHADS"
	description = "Starting Chad Mode +. Starting epoch is the Stone Age, research is done by sacrificing players. Reduced starting items and more hostile conditions."

	respawn_delay = 6000 // 10 minutes!
	has_hunger = TRUE


	faction_organization = list(
		CIVILIAN,)

	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/british
		)
	age = "5000 B.C."
	civilizations = TRUE
	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = "battle of the chads"
	mission_start_message = "<font color=#CECE00><big>Starting <b>Chad Mode +</b>. Starting epoch is the Stone Age, research is done by sacrificing players. Reduced starting items and more hostile conditions.</big></font>"
	ambience = list("sound/ambience/jungle1.ogg")
	faction1 = CIVILIAN
	availablefactions = list("Nomad")
	songs = list(
		"Words Through the Sky:1" = "sound/music/words_through_the_sky.ogg",)
	research_active = TRUE
	nomads = TRUE
	gamemode = "Chad Mode +"

	chad_mode = TRUE
	chad_mode_plus = TRUE
	gamemode_vote = FALSE

/obj/map_metadata/chad_jungle/New()
	..()
	spawn(18000)
		seasons()

/obj/map_metadata/chad_jungle/cross_message(faction)
	return ""
