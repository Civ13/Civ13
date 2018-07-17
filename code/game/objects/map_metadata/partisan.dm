#define NO_WINNER "Neither side has captured the other's base."
/obj/map_metadata/partisan
	ID = MAP_PARTISAN
	title = "Partisan (150x200x2)"
	lobby_icon_state = "partisan"
	prishtina_blocking_area_types = list(/area/prishtina/no_mans_land/invisible_wall)
	respawn_delay = 1800 //3 minutes
	squad_spawn_locations = FALSE
	reinforcements = FALSE
	event_faction = POLISH_INSURGENTS
	no_subfaction_chance = FALSE
	subfaction_is_main_faction = TRUE
	faction_organization = list(
		GERMAN,
		POLISH_INSURGENTS)
	available_subfactions = list(
		POLISH_INSURGENTS)
	roundend_condition_sides = list(
		list(GERMAN) = /area/prishtina/german/ss_armory,
		list(POLISH_INSURGENTS) = /area/prishtina/houses)

	ambience = list()
	times_of_day = list("Night","Evening","Early Morning")
	faction_distribution_coeffs = list(GERMAN = 0.5, POLISH_INSURGENTS = 0.5)
	battle_name = "Partisan Hunting"
	songs = list(
	 "Partisan's Song:1" = 'sound/music/partisans_song.ogg',
	 "Bella Ciao:1" = 'sound/music/bella_ciao.ogg')
	meme = FALSE

/obj/map_metadata/partisan/job_enabled_specialcheck(var/datum/job/J)
	. = TRUE
	if (istype(J, /datum/job/polish))
		if (!J.is_partisan)
			. = FALSE
		else
			if (istype(J, /datum/job/polish/soldier))
				J.total_positions = max(10, round(clients.len*1.4))
			if (istype(J, /datum/job/polish/commander))
				J.total_positions = max(1, round(clients.len*0.1))
	else if (istype(J, /datum/job/soviet))
		. = FALSE
	if (istype(J, /datum/job/german))
		if (!J.is_dirlewanger)
			. = FALSE
		else
			if (istype(J, /datum/job/german/soldier_ss_dirlewanger))
				J.total_positions = max(10, round(clients.len*1.4))
			if (istype(J, /datum/job/german/squad_leader_ss_dirlewanger))
				J.total_positions = max(1, round(clients.len*0.1))
			if (istype(J, /datum/job/german/penal_ss_dirlewanger))
				J.total_positions = 8
	return .


/obj/map_metadata/partisan/germans_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 6000 || admin_ended_all_grace_periods)

/obj/map_metadata/partisan/soviets_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 6000 || admin_ended_all_grace_periods)

/obj/map_metadata/partisan/announce_mission_start(var/preparation_time)
	world << "<font size=4>All factions have <b>10 minutes</b> to prepare for battle before combat will begin!</font>"

/obj/map_metadata/partisan/reinforcements_ready()
	return (germans_can_cross_blocks() && soviets_can_cross_blocks())

/obj/map_metadata/partisan/update_win_condition()
	if (!win_condition_specialcheck())
		return FALSE
	if (world.time >= next_win && next_win != -1)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <b>SS-Sturmbrigade Dirlewanger</b> hunt for partisans has ended in a <b>stalemate</b>"
		if (current_winner && current_loser)
			message = "The battle is over! The [current_winner] was victorious over the [current_loser] in the <b>SS-Sturmbrigade Dirlewanger</b> hunt for partisans!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Waffen-SS</b> has captured the <b>partisan</b> base! They will win in {time} minute{s}."
				next_win = world.time + short_win_time(roundend_condition_sides[2][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Waffen-SS</b> has captured the <b>partisan</b> base! They will win in {time} minute{s}."
				next_win = world.time + long_win_time(roundend_condition_sides[2][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>partisans</b> have captured the <b>Waffen-SS</b> base! They will win in {time} minute{s}."
				next_win = world.time + short_win_time(roundend_condition_sides[1][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>partisans</b> have captured the <b>Waffen-SS</b> base! They will win in {time} minute{s}."
				next_win = world.time + long_win_time(roundend_condition_sides[1][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else if (win_condition.check(list("REINFORCEMENTS"), list(), list(), 1.0, TRUE))
		if (last_win_condition != win_condition.hash)

			// let us know why we're changing to this win condition
			if (current_win_condition != NO_WINNER && current_winner && current_loser)
				world << "<font size = 3>The [current_winner] has lost control of the [army2name(current_loser)] base!</font>"

			current_win_condition = "Both sides are out of reinforcements; the round will end in {time} minute{s}."

			if (last_reinforcements_next_win != -1)
				next_win = last_reinforcements_next_win
			else
				next_win = world.time + long_win_time(null)
				last_reinforcements_next_win = next_win

			announce_current_win_condition()
			current_winner = null
			current_loser = null
	else
		if (current_win_condition != NO_WINNER && current_winner && current_loser)
			world << "<font size = 3>The [current_winner] has lost control of the [army2name(current_loser)] base!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = NO_WINNER
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE