
/obj/map_metadata/testing
	ID = MAP_TESTING
	title = "Test Map"
	no_winner ="The round is proceeding normally."
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 0

	faction_organization = list(
		CIVILIAN,)

	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/british
		)
	age = "2013"

	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = ""
	mission_start_message = ""
	ambience = list("sound/ambience/desert.ogg")
	faction1 = CIVILIAN
	is_singlefaction = TRUE
	songs = list(
		"Words Through the Sky:1" = "sound/music/words_through_the_sky.ogg",)
	gamemode = "Testing"
	ordinal_age = 8
	default_research = 230
	research_active = FALSE
	gamemode_vote = FALSE

	New()
		..()
		spawn(30)
			while (!ticker)
				sleep(1)
			ticker.pregame_timeleft = 5

	update_win_condition()
		return