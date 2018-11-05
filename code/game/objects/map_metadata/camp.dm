#define NO_WINNER "No faction controls the Castle."
/obj/map_metadata/camp
	ID = MAP_CAMP
	title = "Camp (200x45x1)"
	lobby_icon_state = "medieval"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 300
	squad_spawn_locations = FALSE
//	min_autobalance_players = 90
	faction_organization = list(
		BRITISH,
		FRENCH)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(BRITISH) = /area/caribbean/island,
		list(FRENCH) = /area/caribbean/island
		)
	age = "1013"
	faction_distribution_coeffs = list(BRITISH = 0.5, FRENCH = 0.5)
	songs = list(
		"Crusaders:1" = 'sound/music/crusaders.ogg')
	battle_name = "battle of Normandy"
	mission_start_message = "<font size=4>The <b>French</b> and <b>British</b> armies are facing each other in Northern France! There is a <b>Castle</b> in the middle of the map, that must be captured and held for 8 minutes! The battle will start in <b>8 minutes</b>.</font>"
	faction1 = BRITISH
	faction2 = FRENCH
	ambience = list('sound/ambience/jungle1.ogg')

obj/map_metadata/camp/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_medieval == TRUE)
		. = TRUE
	else
		. = FALSE
/obj/map_metadata/camp/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 4800 || admin_ended_all_grace_periods)

/obj/map_metadata/camp/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 4800 || admin_ended_all_grace_periods)


/obj/map_metadata/camp/short_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 4800 // 8 minutes

/obj/map_metadata/camp/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 4800 // 8 minutes

/obj/map_metadata/camp/roundend_condition_def2name(define)
	..()
	switch (define)
		if (BRITISH)
			return "English"

/obj/map_metadata/camp/roundend_condition_def2army(define)
	..()
	switch (define)
		if (BRITISH)
			return "Kingdom of England"
		if (FRENCH)
			return "Kingdom of France"

/obj/map_metadata/camp/army2name(army)
	..()
	switch (army)
		if ("Kingdom of England")
			return "English"
		if ("Kingdom of France")
			return "French"

	#undef NO_WINNER