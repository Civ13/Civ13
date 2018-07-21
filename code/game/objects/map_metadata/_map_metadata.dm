#define NO_WINNER "Neither side has captured the other side's base."

var/global/obj/map_metadata/map = null

/obj/map_metadata
	name = ""
	icon = 'icons/mob/screen1.dmi'
	icon_state = "x2"
	anchored = TRUE
	simulated = FALSE
	invisibility = 101
	var/ID = null // MUST be text, or aspects will break
	var/title = null
	var/lobby_icon_state = "1"
	var/list/caribbean_blocking_area_types = list()
	var/list/allow_bullets_through_blocks = list()
	var/last_crossing_block_status[3]
	var/admin_ended_all_grace_periods = FALSE
	var/uses_supply_train = FALSE
	var/uses_main_train = FALSE
	var/event_faction = null
	var/min_autobalance_players = 0
	var/respawn_delay = 3000
	var/list/valid_weather_types = list(WEATHER_RAIN, WEATHER_SNOW)
	var/reinforcements = TRUE
	var/custom_loadout = TRUE // set to false to prevent people to spawn with guns and ammo on POW Camp map
	var/squad_spawn_locations = TRUE
	var/no_subfaction_chance = TRUE
	var/subfaction_is_main_faction = FALSE
	var/list/faction_organization = list()
	var/list/initial_faction_organization = list()
	var/list/faction_distribution_coeffs = list(INFINITY) // list(INFINITY) = no hard locks on factions
	var/list/available_subfactions = list()
	var/list/roundend_condition_sides = list(
		list(PIRATES) = /area/caribbean/pirates,
		list(BRITISH) = /area/caribbean/british)
	var/list/ambience = list('sound/ambience/ship1.ogg')
	var/list/songs = list(
	"He's a Pirate:1" = 'sound/music/hes_a_pirate.ogg')

	// stuff ported from removed game mode system
	var/required_players = 2
	var/time_both_sides_locked = -1
	var/time_to_end_round_after_both_sides_locked = 6000
	var/admins_triggered_roundend = FALSE
	var/admins_triggered_noroundend = FALSE

	// win conditions 3.0 - Kachnov
	var/datum/win_condition/win_condition = null
	var/current_win_condition = NO_WINNER
	var/last_win_condition = null // this is a hash
	var/current_winner = null
	var/current_loser = null
	var/next_win = -1
	var/last_reinforcements_next_win = -1
	var/win_condition_spam_check = FALSE

	// lighting
	var/list/times_of_day = list("Early Morning", "Morning", "Afternoon", "Midday", "Evening", "Night", "Midnight")
	var/list/zlevels_without_lighting = list()
	var/list/areas_without_lighting = list()

	// fluff
	var/meme = FALSE
	var/battle_name = null

	//front (western europe, eastern europe, pacific, etc)
	var/front = "Eastern"

/obj/map_metadata/New()
	..()
	map = src
	icon = null
	icon_state = null

	initial_faction_organization = faction_organization.Copy()

	// get a subfaction, just one, for this round
	var/subfaction = null
	for (var/faction in available_subfactions)
		if (prob(available_subfactions[faction]))
			subfaction = faction
			break

	if (!no_subfaction_chance && available_subfactions.len)
		subfaction = pick(available_subfactions)

	qdel_list(available_subfactions)
	available_subfactions = list()

	if (subfaction)
		available_subfactions += subfaction

	// makes win condition helper datum
	win_condition = new

// called from the map process
/obj/map_metadata/proc/tick()

	if (last_crossing_block_status[PIRATES] == FALSE)
		if (pirates_can_cross_blocks())
			world << cross_message(PIRATES)
			// let new players see the reinforcements links
			for (var/np in new_player_mob_list)
				if (np:client)
					np:new_player_panel_proc()

	else if (last_crossing_block_status[PIRATES] == TRUE)
		if (!pirates_can_cross_blocks())
			world << reverse_cross_message(PIRATES)
			// let new players see the reinforcements links
			for (var/np in new_player_mob_list)
				if (np:client)
					np:new_player_panel_proc()

	if (last_crossing_block_status[event_faction] == FALSE)
		if (specialfaction_can_cross_blocks())
			world << cross_message(event_faction)
	else if (last_crossing_block_status[event_faction] == TRUE)
		if (!specialfaction_can_cross_blocks())
			world << reverse_cross_message(event_faction)

	last_crossing_block_status[BRITISH] = british_can_cross_blocks()
	last_crossing_block_status[PIRATES] = pirates_can_cross_blocks()

	if (event_faction)
		last_crossing_block_status[event_faction] = specialfaction_can_cross_blocks()

	update_win_condition()

/obj/map_metadata/proc/check_caribbean_block(var/mob/living/carbon/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (caribbean_blocking_area_types.Find(A.type))
		if (!H.original_job)
			return FALSE
		else
			switch (H.original_job.base_type_flag())
				if (PIRATES)
					return !pirates_can_cross_blocks()
				if (BRITISH)
					return !british_can_cross_blocks()
	return FALSE

/obj/map_metadata/proc/pirates_can_cross_blocks()
	return TRUE

/obj/map_metadata/proc/british_can_cross_blocks()
	return TRUE

/obj/map_metadata/proc/specialfaction_can_cross_blocks()
	return TRUE

/obj/map_metadata/proc/announce_mission_start(var/preparation_time = 0)
	return TRUE

/obj/map_metadata/proc/game_really_started()
	return (pirates_can_cross_blocks() && british_can_cross_blocks())

/obj/map_metadata/proc/job_enabled_specialcheck(var/datum/job/J)
	return TRUE

/obj/map_metadata/proc/cross_message(faction)
	return "<font size = 4>The [faction_const2name(faction)] may now cross the invisible wall!</font>"

/obj/map_metadata/proc/reverse_cross_message(faction)
	return "<span class = 'userdanger'>The [faction_const2name(faction)] may no longer cross the invisible wall!</span>"

/obj/map_metadata/proc/reinforcements_ready()
	return game_started

// old game mode stuff
/obj/map_metadata/proc/can_start()

	var/playercount = 0
	var/only_client_is_host = FALSE
	for (var/mob/new_player/player in new_player_mob_list)
		if (player.client)
			if (!player.client.is_minimized())
				++playercount
			if (player && player.key == world.host) // client.is_minimized() takes a while, so the player may not still exist
				only_client_is_host = TRUE

	if (playercount >= required_players || only_client_is_host)
		return TRUE

	return FALSE

/obj/map_metadata/proc/update_win_condition()
	if (!win_condition_specialcheck())
		return FALSE
	if (world.time >= next_win && next_win != -1)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The [battle_name ? battle_name : "battle"] has ended in a stalemate!"
		if (current_winner && current_loser)
			message = "The battle is over! The [current_winner] was victorious over the [current_loser][battle_name ? " in the [battle_name]" : ""]!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		win_condition_spam_check = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[1][1])] has captured the [roundend_condition_def2name(roundend_condition_sides[2][1])] base! They will win in {time} minute{s}."
				next_win = world.time + short_win_time(roundend_condition_sides[2][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[1][1])] has captured the [roundend_condition_def2name(roundend_condition_sides[2][1])] base! They will win in {time} minute{s}."
				next_win = world.time + long_win_time(roundend_condition_sides[2][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[2][1])] has captured the [roundend_condition_def2name(roundend_condition_sides[1][1])] base! They will win in {time} minute{s}."
				next_win = world.time + short_win_time(roundend_condition_sides[1][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[2][1])] has captured the [roundend_condition_def2name(roundend_condition_sides[1][1])] base! They will win in {time} minute{s}."
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

/obj/map_metadata/proc/has_occupied_base(side)

	// hack
	if (current_win_condition == NO_WINNER)
		return FALSE

	var/list/soldiers = list(
		CIVILIAN = 0,
		PARTISAN = 0,
		BRITISH = 0,
		PIRATES = 0)

	if (!soldiers.Find(side))
		soldiers[side] = 0

	var/s1 = 0
	var/s2 = 0

	for (var/mob/living/carbon/human/H in human_mob_list)

		var/datum/job/job = H.original_job

		if (!job)
			continue

		if (H.stat != DEAD && H.stat != UNCONSCIOUS && !H.restrained() && ((H.weakened+H.stunned) == 0) && H.client)
			if (soldiers.Find(job.base_type_flag()))
				var/H_area = get_area(H)
				if (roundend_condition_sides[1].Find(job.base_type_flag()))
					if (istype(H_area, roundend_condition_sides[roundend_condition_sides[2]]))
						++s1
				else if (roundend_condition_sides[2].Find(job.base_type_flag()))
					if (istype(H_area, roundend_condition_sides[roundend_condition_sides[1]]))
						++s2
			else
				var/M = "WARNING: could not find '[job.base_type_flag()]' in local list soldiers in proc '/obj/map/proc/has_occupied_base()'. Please contact a coder."
				log_admin(M)
				message_admins(M)
				log_debug(M)

	if (roundend_condition_sides[1].Find(side))
		return s2 > s1
	else if (roundend_condition_sides[2].Find(side))
		return s1 > s2

	return FALSE

/obj/map_metadata/proc/next_win_time()
	return round((next_win - world.time)/600)

/obj/map_metadata/proc/current_stat_message()
	var/next_win_time = max(0, next_win_time())
	. = current_win_condition
	. = replacetext(., "{time}", next_win_time)
	if (next_win_time == 1)
		. = replacetext(., "{s}", "")
	else
		. = replacetext(., "{s}", "s")
	return .

/obj/map_metadata/proc/announce_current_win_condition()
	world << "<font size = 3>[current_stat_message()]</font>"

/obj/map_metadata/proc/short_win_time(faction)
	if (clients.len >= 20)
		return 6000 // 10 minutes
	else
		return 3000 // 5 minutes

/obj/map_metadata/proc/long_win_time(faction)
	if (clients.len >= 20)
		return 9000 // 15 minutes
	else
		return 6000 // 10 minutes

/obj/map_metadata/proc/win_condition_specialcheck()
	return TRUE

/obj/map_metadata/proc/roundend_condition_def2name(define)
	switch (define)
		if (PARTISAN)
			return "Partisan"
		if (BRITISH)
			return "British"
		if (PIRATES)
			return "Pirate"

/obj/map_metadata/proc/roundend_condition_def2army(define)
	switch (define)
		if (PARTISAN)
			return "Partisan Group"
		if (BRITISH)
			return "Royal Navy"
		if (PIRATES)
			return "Pirate group"

/obj/map_metadata/proc/army2name(army)
	switch (army)
		if ("Royal Navy")
			return "British"
		if ("Pirate group")
			return "Pirate"

/obj/map_metadata/proc/special_relocate(var/mob/M)
	return FALSE

#undef NO_WINNER