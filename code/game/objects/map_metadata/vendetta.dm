/obj/map_metadata/clash2
	ID = MAP_VENDETTA
	title = "Vendetta"
	lobby_icon = "icons/lobby/vendetta.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	victory_time = 21600
	no_winner = "The fort is still held by the Bear Clan."
	respawn_delay = 300
	no_hardcore = TRUE
	faction_organization = list(
		DANISH,
		NORWEGIAN)

	roundend_condition_sides = list(
		list(NORWEGIAN) = /area/caribbean/greek,
		list(DANISH) = /area/caribbean/colonies,
		)

	age = "1013"
	ordinal_age = 3
	faction_distribution_coeffs = list(DANISH = 0.5, NORWEGIAN = 0.5)
	battle_name = "Clan War"
	mission_start_message = "<font size=4>The <b>Raven</b> clan is sieging the <b>Bear</b> clan's fort hidden away in the snowy fjords! The Raven clan will win if they manage to <b>capture the Bear King's Cabin</b>.<br> The Bear Clan must <b>defend their fort for 30 minutes</b>.<br> The siege will start after <b>6 minutes</b>.</font>"
	faction1 = NORWEGIAN
	faction2 = DANISH
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET)
	songs = list(
		"Danheim - Ivar's Revenge:1" = "sound/music/ivars_revenge.ogg",)
	gamemode = "Siege"

/obj/map_metadata/clash2/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_clash == TRUE)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/clash2/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 21600 || admin_ended_all_grace_periods)

/obj/map_metadata/clash2/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3600 || admin_ended_all_grace_periods)

/obj/map_metadata/clash2/short_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 1200 // 2 minutes

/obj/map_metadata/clash2/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/clash2/cross_message(faction)
	if (faction == NORWEGIAN)
		return "<font size = 4>The Raven Clan may now cross the invisible wall!</font>"
	else if (faction == DANISH)
		return "<font size = 4>The Raven Clan may now cross the invisible wall!</font>"
	else
		return ""

var/no_loop_clash2 = FALSE
/obj/map_metadata/clash2/update_win_condition()
	if (world.time >= victory_time)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The Bear clan has managed to defend their fort!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_clash2 == FALSE)
		ticker.finished = TRUE
		var/message = "The Raven clan has captured the King's cabin! The remaining Bear clansmen have surrendered!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_clash = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The Raven clan has control over the Bear King's cabin! They will win in {time} minutes."
				next_win = world.time +  short_win_time(NORWEGIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The Raven clan has control over the Bear King's cabin! They will win in {time} minutes."
				next_win = world.time +  short_win_time(NORWEGIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition =  "The Raven clan has control over the Bear King's cabin! They will win in {time} minutes."
				next_win = world.time +  short_win_time(NORWEGIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The Raven clan has control over the Bear King's cabin! They will win in {time} minutes."
				next_win = world.time + short_win_time(NORWEGIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The Bear clan has recaptured the King's cabin!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE
