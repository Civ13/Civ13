
/obj/map_metadata/clash
	ID = MAP_CLASH
	title = "Clash"
	lobby_icon = "icons/lobby/clash.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 300
	no_hardcore = TRUE
	faction_organization = list(
		ROMAN,
		GREEK)

	roundend_condition_sides = list(
		list(GREEK) = /area/caribbean/greek,
		list(ROMAN) = /area/caribbean/colonies,
		)
	age = "1013"
	ordinal_age = 3
	faction_distribution_coeffs = list(GREEK = 0.5, ROMAN = 0.5)
	battle_name = "Clan war"
	mission_start_message = "<font size=4>The <b>Bear</b> clan are sieging the <b>Raven</b> base hidden away in the snowy hills! The Bear clan will win if they manage to hold the king's cabin for 5 minutes. <br> The siege will start in <b>6 minutes</b>.</font>"
	faction1 = GREEK
	faction2 = ROMAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET)
	ambience = list('sound/ambience/jungle1.ogg')
	songs = list(
		"Warbringer (Filip Lackovic):1" = "sound/music/warbringer.ogg",)
	gamemode = "Siege"
/obj/map_metadata/clash/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 36000 || admin_ended_all_grace_periods)

/obj/map_metadata/clash/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3600 || admin_ended_all_grace_periods)

/obj/map_metadata/clash/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_clash == TRUE)
		. = TRUE
	else
		. = FALSE

var/no_loop_clash = FALSE

/obj/map_metadata/clash/update_win_condition()

	if (world.time >= 3000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The Raven clan have managed to defend the King's cabin!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_rom == FALSE)
		ticker.finished = TRUE
		var/message = "The Bear clan has captured the King's cabin! The remaining Raven clan have surrendered!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_rom = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The Bear clan have control over the king's cabin! They will win in {time} minutes."
				next_win = world.time +  short_win_time(GREEK)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The Bear clan have control over the king's cabin! They will win in {time} minutes."
				next_win = world.time +  short_win_time(GREEK)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition =  "The Bear clan have control over the king's cabin! They will win in {time} minutes.."
				next_win = world.time +  short_win_time(ROMAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The Bear clan have control over the king's cabin! They will win in {time} minutes.."
				next_win = world.time + short_win_time(ROMAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The Raven clan recaptured the king's cabin!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/clash/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/one))
			if (H.faction_text == faction1)
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/inside/two))
			if (H.faction_text == faction2)
				return TRUE
		else
			return !faction1_can_cross_blocks()
	return FALSE

