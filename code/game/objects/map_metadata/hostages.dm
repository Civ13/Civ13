#define NO_WINNER "The operation is still underway."
/obj/map_metadata/hostages
	ID = MAP_HOSTAGES
	title = "Hostage Rescue (100x100x2)"
	lobby_icon_state = "coldwar"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 1200
	squad_spawn_locations = FALSE
//	min_autobalance_players = 90
	faction_organization = list(
		AMERICAN,
		ARAB)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(AMERICAN) = /area/caribbean/greek,
		list(ARAB) = /area/caribbean/greek
		)
	age = "2014"
	ordinal_age = 6
	faction_distribution_coeffs = list(AMERICAN = 0.2, ARAB = 0.8)
	battle_name = "hostage rescue"
	mission_start_message = "<font size=4>The insurgents are holding <b>American</b> embassy staff hostage! The Special Forces must rescue them within <b>20 minutes</b>. If all of them die, both teams lose.<br>Each team gets <b>1</b> point per hostage kept alive and in their control by the end of the 20 minutes.</font>"
	faction1 = AMERICAN
	faction2 = ARAB
	valid_weather_types = list(WEATHER_NONE, WEATHER_SANDSTORM)
	songs = list(
		"Fortunate Son:1" = 'sound/music/fortunate_son.ogg',)
	artillery_count = 0

	var/total_hostages = 5
	var/rescued_hostages = 0
	var/held_hostages = 0
	var/dead_hostages = 0

	faction1_points = 0
	faction2_points = 0

/obj/map_metadata/hostages/New()
	..()
	mission_start_message = "<font size=4>The insurgents are holding [total_hostages] <b>American</b> embassy staff hostage! The Special Forces must rescue them within <b>20 minutes</b>. If all of them die, both teams lose.<br>Each team gets <b>1</b> point per hostage kept alive and in their control by the end of the 20 minutes.</font>"
	spawn(3000)
		hostage_msg()

obj/map_metadata/hostages/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_specops == TRUE)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/hostages/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 30000 || admin_ended_all_grace_periods)

/obj/map_metadata/hostages/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)


/obj/map_metadata/hostages/roundend_condition_def2name(define)
	..()
	switch (define)
		if (ARAB)
			return "Insurgent"
		if (AMERICAN)
			return "SOF Team"
/obj/map_metadata/hostages/roundend_condition_def2army(define)
	..()
	switch (define)
		if (ARAB)
			return "Insurgents"
		if (AMERICAN)
			return "SOF Team"

/obj/map_metadata/hostages/army2name(army)
	..()
	switch (army)
		if ("Insurgents")
			return "Insurgent"
		if ("SOF Team")
			return "SOF Team"

/obj/map_metadata/hostages/cross_message(faction)
	if (faction == AMERICAN)
		return "<font size = 4>The SOF may now cross the invisible wall!</font>"
	else if (faction == ARAB)
		return ""
	else
		return ""

/obj/map_metadata/hostages/reverse_cross_message(faction)
	if (faction == AMERICAN)
		return "<span class = 'userdanger'>The SOF may no longer cross the invisible wall!</span>"
	else if (faction == ARAB)
		return ""
	else
		return ""

/obj/map_metadata/hostages/update_win_condition()
	if (world.time < 3000)
		return
	if (win_condition_spam_check)
		return FALSE
	var/message = ""
	var/win_result = check_hostages()
	if (win_result == "early victory")
		message = "All hostages have been rescued! The SOF team has won!"
		current_winner = AMERICAN
		current_loser = ARAB
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		ticker.finished = TRUE
		win_condition_spam_check = TRUE
		return FALSE
	else if (win_result == "early failure")
		message = "All hostages are dead! The mission was a failure and both sides are defeated!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		ticker.finished = TRUE
		win_condition_spam_check = TRUE
		return FALSE
	else
		if (world.time >= 15000)
			if (win_condition_spam_check)
				return FALSE
			message = "The Operation is over!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			show_global_battle_report(null)
			win_condition_spam_check = TRUE
			if (win_result == AMERICAN)
				current_winner = AMERICAN
				current_loser = ARAB
				message = "The SOF team has rescued [rescued_hostages] hostages and won!"
				world << "<font size = 4><span class = 'notice'>[message]</span></font>"
				ticker.finished = TRUE
				return FALSE
			else if (win_result == ARAB)
				current_winner = ARAB
				current_loser = AMERICAN
				message = "The Insurgents have held [held_hostages] hostages and won!"
				world << "<font size = 4><span class = 'notice'>[message]</span></font>"
				ticker.finished = TRUE
				return FALSE
			else if (win_result == "failure" || win_result == "draw")
				message = "Both sides have the same amount of hostages. The round is a draw."
				world << "<font size = 4><span class = 'notice'>[message]</span></font>"
				ticker.finished = TRUE
			else
				message = "It is impossible to determine who won."
				world << "<font size = 4><span class = 'notice'>[message]</span></font>"
				ticker.finished = TRUE
			return FALSE

	return TRUE

/obj/map_metadata/hostages/proc/check_hostages()
	rescued_hostages = 0
	held_hostages = 0
	dead_hostages = 0
	for (var/mob/living/simple_animal/hostage/DH in world)
		if (DH.stat != DEAD)
			var/area/currarea = get_area(DH)
			if (istype(currarea, /area/caribbean/british))
				rescued_hostages++
			else if (istype(currarea, /area/caribbean/british))
				held_hostages++
		else if (DH.stat == DEAD)
			dead_hostages++
	total_hostages = dead_hostages+rescued_hostages+held_hostages
	faction1_points = rescued_hostages
	faction2_points = held_hostages

	if (rescued_hostages >= total_hostages)
		return "early victory"

	if (dead_hostages == total_hostages)
		return "early failure"

	if (faction1_points > faction2_points)
		return AMERICAN
	else if (faction2_points > faction1_points)
		return ARAB
	else if (faction1_points == faction2_points)
		return "draw"

	return "failure"
/obj/map_metadata/hostages/proc/hostage_msg()
	check_hostages()
	spawn(1)
		world << "<font size = 4><span class = 'notice'><b>Current Status:</b></font><br><font size = 3>Hostages Rescued: [rescued_hostages]/[total_hostages].<br>Hostages Held: [held_hostages]/[total_hostages].<br>Hostages Dead: [dead_hostages]/[total_hostages].</span></font>"
	spawn(3000)
		hostage_msg()
#undef NO_WINNER