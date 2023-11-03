/obj/map_metadata/twotribes
	ID = MAP_TWOTRIBES
	title = "Two Tribes"
	lobby_icon_state = "civ13"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 300

	faction_organization = list(
		REDTRIBE,
		BLUETRIBE)

	roundend_condition_sides = list(
		list(REDTRIBE) = /area/caribbean/no_mans_land/capturable/one,
		list(BLUETRIBE) = /area/caribbean/no_mans_land/capturable/one
		)
	age = "Ab immemorabili"
	ordinal_age = 0
	faction_distribution_coeffs = list(REDTRIBE = 0.5, BLUETRIBE = 0.5)
	battle_name = "Battle of the Two Tribes"
	mission_start_message = "<font size=4>The <b>Red</b> and <b>Blue</b> tribes are engaged in battle, both attempting to capture the central shrine. Prepare for battle, it will begin in <b>5 minutes</b>!</font>"
	faction1 = REDTRIBE
	faction2 = BLUETRIBE
	ambience = list('sound/ambience/jungle1.ogg')
	songs = list(
		"Words Through the Sky:1" = 'sound/music/words_through_the_sky.ogg',)

/obj/map_metadata/twotribes/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)

/obj/map_metadata/twotribes/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)


