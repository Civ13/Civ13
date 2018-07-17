#define NO_WINNER "The convoy is still in transit."
/obj/map_metadata/escort
	ID = MAP_ESCORT
	title = "Escort (150x200x2)"
	lobby_icon_state = "partisan"
	prishtina_blocking_area_types = list(/area/prishtina/no_mans_land/invisible_wall)
	respawn_delay = 1800 //3 minutes
	squad_spawn_locations = FALSE
	reinforcements = FALSE
	faction_organization = list(
		GERMAN,
		POLISH_INSURGENTS)
	available_subfactions = list()
	roundend_condition_sides = list(
		list(GERMAN) = /area/prishtina/farm2,
		list(POLISH_INSURGENTS) = /area/prishtina/farm1)
	ambience = list()
	times_of_day = list("Night","Evening","Early Morning")
	faction_distribution_coeffs = list(GERMAN = 0.5, PARTISAN = 0.5)
	battle_name = "Escort the Convoy"
	meme = FALSE

/obj/map_metadata/escort/job_enabled_specialcheck(var/datum/job/J)
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
			if (istype(J, /datum/job/german/penal_ss_dirlewanger))
				J.total_positions = 8
	return .


/obj/map_metadata/escort/germans_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 6000 || admin_ended_all_grace_periods)

/obj/map_metadata/escort/soviets_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 6000 || admin_ended_all_grace_periods)

/obj/map_metadata/escort/announce_mission_start(var/preparation_time)
	world << "<font size=4>All factions have <b>10 minutes</b> to prepare before the convoy departs!<br>The German convoy must reach the destination zone (Northwest corner), partisans must prevent them.</font>"

/obj/map_metadata/escort/reinforcements_ready()
	return (germans_can_cross_blocks() && soviets_can_cross_blocks())

/obj/map_metadata/escort/update_win_condition()
	if (!win_condition_specialcheck())
		return FALSE
	if (world.time >= next_win && next_win != -1)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The convoy escort as ended in a stalemate."
		if (current_winner && current_loser)
			message = "The battle is over! The [current_winner] was victorious over [current_loser]!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Waffen-SS Convoy</b> has reached his destination or eliminated the partisan threat! The <b>Germans</b> have won!"
				next_win = world.time + short_win_time(roundend_condition_sides[2][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Waffen-SS Convoy</b> has reached his destination or eliminated the partisan threat! The <b>Germans</b> have won!"
				next_win = world.time + long_win_time(roundend_condition_sides[2][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>partisans</b> have prevented the convoy from reaching its destination! The <b>partisans</b> have won!"
				next_win = world.time + short_win_time(roundend_condition_sides[1][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>partisans</b> have prevented the convoy from reaching its destination! The <b>partisans</b> have won!"
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

/obj/map_metadata/escort/short_win_time(faction)
	return 200

/obj/map_metadata/escort/long_win_time(faction)
	return 200

/obj/map_metadata/escort/win_condition_specialcheck()
	return (!alive_n_of_side(SOVIET) || !alive_n_of_side(GERMAN))
