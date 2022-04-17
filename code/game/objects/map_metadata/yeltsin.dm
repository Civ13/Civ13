/obj/map_metadata/yeltsin
	ID = MAP_YELTSIN
	title = "Battle for the Russian Parliament"
	lobby_icon_state = "yeltsin"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/one,/area/caribbean/no_mans_land/invisible_wall/two)
	respawn_delay = 1200
	no_winner = "The operation is still underway."
	gamemode = "Protect the VIP."
	no_hardcore = TRUE
	var/list/HVT_list = list()

	faction_organization = list(
		CIVILIAN,
		RUSSIAN)

	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/british/land/inside/objective,
		list(RUSSIAN) = /area/caribbean/arab
		)
	age = "1993"
	ordinal_age = 7
	faction_distribution_coeffs = list(RUSSIAN = 0.3, CIVILIAN = 0.7)
	battle_name = "Battle for the Russian Parliament."
	mission_start_message = ""
	faction1 = CIVILIAN
	faction2 = RUSSIAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET)
	songs = list(
		"Kino - I Want Changes:1" = "sound/music/want_changes.ogg",)
	artillery_count = 0
	valid_artillery = list()
	scores = list(
		"Russian Army" = 0,
		"Militia" = 0,
	)
	var/ger_points = 0
	var/sov_points = 0
	var/a1_control = "none"
	var/a2_control = "none"


/obj/map_metadata/yeltsin/New()
	..()
	spawn(2500)
		if (gamemode == "Siege")
			for (var/turf/T in get_area_turfs(/area/caribbean/no_mans_land/capturable/one))
				new /area/caribbean/british/land/inside/objective(T)
			for (var/turf/T in get_area_turfs(/area/caribbean/no_mans_land/capturable/two))
				new /area/caribbean/british/land/inside/objective(T)

/obj/map_metadata/yeltsin/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_yeltsin == TRUE)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/yeltsin/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 6000 || admin_ended_all_grace_periods)

/obj/map_metadata/yeltsin/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 6000 || admin_ended_all_grace_periods)


/obj/map_metadata/yeltsin/roundend_condition_def2name(define)
	..()
	switch (define)
		if (CIVILIAN)
			return "Militia"
		if (RUSSIAN)
			return "Russian Army"
/obj/map_metadata/yeltsin/roundend_condition_def2army(define)
	..()
	switch (define)
		if (CIVILIAN)
			return "Militias"
		if (RUSSIAN)
			return "Russian Army"

/obj/map_metadata/yeltsin/army2name(army)
	..()
	switch (army)
		if ("Militias")
			return "Militia"
		if ("Russian Army")
			return "Russian Army"


/obj/map_metadata/yeltsin/cross_message(faction)
	if (faction == RUSSIAN)
		return "<font size = 4>The Russian Army may now cross the invisible wall!</font>"
	else
		return ""

/obj/map_metadata/yeltsin/reverse_cross_message(faction)
	if (faction == RUSSIAN)
		return "<span class = 'userdanger'>The Russian Army may no longer cross the invisible wall!</span>"
	else
		return ""



/obj/map_metadata/yeltsin/update_win_condition()
	var/message = ""
	switch(gamemode)
		if ("Protect the VIP")
			if (processes.ticker.playtime_elapsed >= 24000)
				if (win_condition_spam_check)
					return FALSE
				ticker.finished = TRUE
				next_win = -1
				current_win_condition = no_winner
				win_condition.hash = 0
				last_win_condition = win_condition.hash
				message = "25 minutes have passed! The HVT is now safe!"
				world << "<font size = 4><span class = 'notice'>[message]</span></font>"
				win_condition_spam_check = TRUE
				return FALSE
			if (processes.ticker.playtime_elapsed >= 3000)
				if (!win_condition_spam_check)
					var/count = 0
					for (var/mob/living/human/H in HVT_list)
						if (H.original_job_title == "Soviet Supreme Chairman" && H.stat != DEAD)
							count++
					if (count == 0)
						message = "The battle is over! All the <b>HVT</b>s are dead!"
						world << "<font size = 4 color='yellow'><span class = 'notice'>[message]</span></font>"
						win_condition_spam_check = TRUE
						ticker.finished = TRUE
						next_win = -1
						current_win_condition = no_winner
						win_condition.hash = 0
						last_win_condition = win_condition.hash
						return FALSE
		if ("Area Capture")
			if (processes.ticker.playtime_elapsed > 4800)
				if (sov_points < 40 && ger_points < 40)
					return TRUE
				if (sov_points >= 40 && sov_points > ger_points)
					if (win_condition_spam_check)
						return FALSE
					ticker.finished = TRUE
					message = "The <b>Soviets</b> have reached [sov_points] points and won!"
					world << "<font size = 4><span class = 'notice'>[message]</span></font>"
					show_global_battle_report(null)
					win_condition_spam_check = TRUE
					return FALSE
				if (ger_points >= 40 && ger_points > sov_points)
					if (win_condition_spam_check)
						return FALSE
					ticker.finished = TRUE
					message = "The <b>Germans</b> have reached [ger_points] points and won!"
					world << "<font size = 4><span class = 'notice'>[message]</span></font>"
					show_global_battle_report(null)
					win_condition_spam_check = TRUE
					return FALSE
			return TRUE

		if ("Siege")
			if (world.time >= 24000)
				if (win_condition_spam_check)
					return FALSE
				ticker.finished = TRUE
				message = "The Militia has managed to defend the Parliament! The Russian Army retreats!"
				world << "<font size = 4><span class = 'notice'>[message]</span></font>"
				show_global_battle_report(null)
				win_condition_spam_check = TRUE
				return FALSE
			if ((current_winner && current_loser && world.time > next_win) && no_loop_capitol == FALSE)
				ticker.finished = TRUE
				message = "The Russian Army has captured the Parliament!"
				world << "<font size = 4><span class = 'notice'>[message]</span></font>"
				show_global_battle_report(null)
				win_condition_spam_check = TRUE
				no_loop_capitol = TRUE
				return FALSE
			// German major
			else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
				if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
					if (last_win_condition != win_condition.hash)
						current_win_condition = "The Russian Army controls the Parliament! They will win in {time} minutes."
						next_win = world.time + short_win_time(RUSSIAN)
						announce_current_win_condition()
						current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
						current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
			// German minor
			else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
				if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
					if (last_win_condition != win_condition.hash)
						current_win_condition = "The Russian Army controls the Parliament! They will win in {time} minutes."
						next_win = world.time + short_win_time(RUSSIAN)
						announce_current_win_condition()
						current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
						current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
			// Soviet major
			else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
				if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
					if (last_win_condition != win_condition.hash)
						current_win_condition = "The Russian Army controls the Parliament! They will win in {time} minutes."
						next_win = world.time + short_win_time(CIVILIAN)
						announce_current_win_condition()
						current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
						current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
			// Soviet minor
			else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
				if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
					if (last_win_condition != win_condition.hash)
						current_win_condition = "The Russian Army controls the Parliament! They will win in {time} minutes."
						next_win = world.time + short_win_time(CIVILIAN)
						announce_current_win_condition()
						current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
						current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
			else
				if (current_win_condition != no_winner && current_winner && current_loser)
					world << "<font size = 3>The Militia has recaptured the Parliament!</font>"
					current_winner = null
					current_loser = null
				next_win = -1
				current_win_condition = no_winner
				win_condition.hash = 0
			last_win_condition = win_condition.hash
			return TRUE

		if ("Kills")
			if (processes.ticker.playtime_elapsed >= 24000 || world.time >= next_win && next_win != -1)
				if (win_condition_spam_check)
					return FALSE
				ticker.finished = TRUE
				message = "The round has ended!"
				if (scores["Militia"] > scores["Russian Army"])
					message = "The battle is over! The <b>Militia</b> was victorious over the <b>Russian Army</b>!"
					world << "<font size = 4><span class = 'notice'>[message]</span></font>"
					win_condition_spam_check = TRUE
					return FALSE
				else if (scores["Russian Army"] > scores["Militia"])
					message = "The battle is over! The <b>Russian Army</b> was victorious over the <b>Militia</b>!"
					world << "<font size = 4><span class = 'notice'>[message]</span></font>"
					win_condition_spam_check = TRUE
					return FALSE
				else
					message = "The battle has ended in a <b>stalemate</b>!"
					world << "<font size = 4><span class = 'notice'>[message]</span></font>"
					win_condition_spam_check = TRUE
					return FALSE
				last_win_condition = win_condition.hash
				return TRUE



/obj/map_metadata/yeltsin/proc/points_check()
	if (processes.ticker.playtime_elapsed > 4800)
		var/c1 = 0
		var/c2 = 0
		var/prev_control = a1_control
		var/cust_color = "white"
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/one))
				if (H.faction_text == "CIVILIAN" && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == "RUSSIAN" && H.stat == CONSCIOUS)
					c2++
		if (c1+c2<=0 || c1 == c2)
			a1_control = "none"
		else if (c1 > c2)
			a1_control = "Militias"
			cust_color="blue"
			ger_points++
		else if (c2 > c1)
			a1_control = "Russian Army"
			cust_color="red"
			sov_points++
		if (a1_control != prev_control)
			if (prev_control != "none")
				world << "<big><font color='[cust_color]'>[prev_control]</font> lost the <b>Central Processing</b>!</big>"
			else
				world << "<big><font color='[cust_color]'>[a1_control]</font> captured the <b>Central Processing</b>!</big>"
		c1 = 0
		c2 = 0
		prev_control = a2_control
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/two))
				if (H.faction_text == "RUSSIAN" && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == "CIVILIAN" && H.stat == CONSCIOUS)
					c2++
		if (c1+c2<=0 || c1 == c2)
			a2_control = "none"
		else if (c1 > c2)
			a2_control = "Militias"
			cust_color="blue"
			ger_points++
		else if (c2 > c1)
			a2_control = "Russian Army"
			cust_color="red"
			sov_points++
		if (a2_control != prev_control)
			if (prev_control != "none")
				world << "<big><font color='[cust_color]'>[prev_control]</font> lost the <b>Parliamental Hall</b>!</big>"
			else
				world << "<big><font color='[cust_color]'>[a2_control]</font> captured the <b>Parliamental Hall</b>!</big>"
	world << "<big><b>Current Points:</big></b>"
	world << "<big>Militia: [scores["Militia"]]</big>"
	world << "<big>Russian Army: [scores["Russian Army"]]</big>"
//	world << "<big>Militia: [ger_points]</big>"
//	world << "<big>Soviet Army: [sov_points]</big>"
	spawn(300)
		points_check()




/obj/map_metadata/yeltsin/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/one))
			if (H.faction_text == faction1)
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/two))
			if (H.faction_text == faction2 && gamemode != "Protect the VIP")
				return TRUE
		else
			return !faction1_can_cross_blocks()
	return FALSE
