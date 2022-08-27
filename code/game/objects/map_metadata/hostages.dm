
/obj/map_metadata/hostages
	ID = MAP_HOSTAGES
	title = "Hostage Rescue"
	lobby_icon = "icons/lobby/modern.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/desert)
	respawn_delay = 1200
	no_hardcore = TRUE
	min_autobalance_players = 100
	no_winner ="The operation is still underway."
	faction_organization = list(
		ARAB,
		AMERICAN)

	roundend_condition_sides = list(
		list(AMERICAN) = /area/caribbean/greek,
		list(ARAB) = /area/caribbean/greek
		)
	age = "2014"
	ordinal_age = 8
	faction_distribution_coeffs = list(ARAB = 0.6, AMERICAN = 0.4)
	battle_name = "hostage rescue"
	mission_start_message = "<font size=4>The insurgents are holding <b>American</b> embassy staff hostage! The Special Forces must rescue them within <b>35 minutes</b>. If all of them die, both teams lose.<br>Each team gets <b>1</b> point per hostage kept alive and in their control by the end of the 20 minutes.</font>"
	faction1 = ARAB
	faction2 = AMERICAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_EXTREME)
	songs = list(
		"Al-Qussam:1" = "sound/music/alqassam.ogg",)
	artillery_count = 0

	var/total_hostages = 6
	var/rescued_hostages = 0
	var/held_hostages = 0
	var/dead_hostages = 0


	var/faction1_prisoners = 0
	var/faction2_prisoners = 0

	faction1_points = 0
	faction2_points = 0

/obj/map_metadata/hostages/New()
	..()
	mission_start_message = "<font size=4>The insurgents are holding [total_hostages] <b>American</b> hostages! The Special Forces must rescue them within <b>35 minutes</b>. If all of them die, both teams lose.<br>Each team gets <b>5</b> points per hostage kept alive and in their control by the end of the 20 minutes. Americans also get <b>1</b> point per prisoner alive and handcuffed in their prison. Insurgents get <b>3</b> points per prisoner alive and handcuffed in their prisons.</font>"
	spawn(3000)
		hostage_msg()

obj/map_metadata/hostages/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/american))
		if (J.is_specops && !J.is_modernday)
			. = TRUE
	else
		if (J.is_specops)
			. = TRUE
		else
			. = FALSE

/obj/map_metadata/hostages/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 30000 || admin_ended_all_grace_periods)

/obj/map_metadata/hostages/faction2_can_cross_blocks()
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
		message = "All hostages have been rescued! The <b>SOF team</b> has won!"
		current_winner = AMERICAN
		current_loser = ARAB
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		ticker.finished = TRUE
		win_condition_spam_check = TRUE
		return FALSE
	else if (win_result == "early failure")
		message = "All hostages are dead! The mission was a failure and <b>both sides are defeated</b>!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		ticker.finished = TRUE
		win_condition_spam_check = TRUE
		return FALSE
	else
		if (world.time >= 24000 || (world.time > next_win && next_win != -1))
			if (win_condition_spam_check)
				return FALSE
			message = "The Operation is over!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			show_global_battle_report(null)
			win_condition_spam_check = TRUE
			if (win_result == AMERICAN)
				current_winner = AMERICAN
				current_loser = ARAB
				message = "The <b>SOF team</b> has [faction1_points] victory points and won the round!"
				world << "<font size = 4><span class = 'notice'>[message]</span></font>"
				ticker.finished = TRUE
				return FALSE
			else if (win_result == ARAB)
				current_winner = ARAB
				current_loser = AMERICAN
				message = "The <b>Insurgents</b> have [faction2_points] victory points and won the round!"
				world << "<font size = 4><span class = 'notice'>[message]</span></font>"
				ticker.finished = TRUE
				return FALSE
			else if (win_result == "failure" || win_result == "draw")
				message = "Both sides have the same amount of victory points. The round is a draw."
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
	faction1_points = 0
	faction2_points = 0
	faction1_prisoners = 0
	faction2_prisoners = 0

	for (var/mob/living/simple_animal/hostage/DH in world)
		if (DH.stat != DEAD)
			var/area/currarea = get_area(DH)
			if (istype(currarea, /area/caribbean/british))
				rescued_hostages++
			else if (istype(currarea, /area/caribbean/arab))
				held_hostages++
		else if (DH.stat == DEAD)
			dead_hostages++
	if (dead_hostages+held_hostages+rescued_hostages < total_hostages)
		dead_hostages = total_hostages-held_hostages-rescued_hostages
	faction1_points = rescued_hostages*5
	faction2_points = held_hostages*5

	for (var/mob/living/human/PR in world)
		if (PR.stat != DEAD && PR.handcuffed)
			var/area/currarea2 = get_area(PR)
			if (istype(currarea2, /area/caribbean/british/land/inside/objective))
				faction1_prisoners++
			else if (istype(currarea2, /area/caribbean/arab/caves/prison))
				faction2_prisoners++
	faction1_points += faction1_prisoners
	faction2_points += faction2_prisoners*3

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
		world << "<font size = 4><span class = 'notice'><b>Current Status:</b></font><br><font size = 3>Hostages Rescued: [rescued_hostages]/[total_hostages]<br>Hostages Held: [held_hostages]/[total_hostages]<br>Hostages Dead: [dead_hostages]/[total_hostages]<br>U.S. SOF Points: [faction1_points] - Insurgent Points: [faction2_points]</span></font>"
	spawn(3000)
		hostage_msg()
