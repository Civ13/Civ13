/obj/map_metadata/capitol_hill
	ID = MAP_CAPITOL_HILL
	title = "Capitol Hill"
	lobby_icon = 'icons/lobby/capitol.png'
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/one,/area/caribbean/no_mans_land/invisible_wall/two)
	respawn_delay = 1200
	no_winner = "The operation is still underway."
	gamemode = "Siege"
	no_hardcore = TRUE
	can_spawn_on_base_capture = TRUE
	var/list/HVT_list = list()

	faction_organization = list(
		AMERICAN,
		CIVILIAN)

	roundend_condition_sides = list(
		list(AMERICAN) = /area/caribbean/british/land/inside/objective,
		list(CIVILIAN) = /area/caribbean/arab
		)
	age = "2021"
	ordinal_age = 8
	faction_distribution_coeffs = list(AMERICAN = 0.3, CIVILIAN = 0.7)
	battle_name = "battle for the Capitol Hill"
	//mission_start_message = "<font size=4>The <b>National Guard</b> is holding the U.S. Capitol! The <b>Militias</b> troops must capture both chambers (<b>Congress</b> and <b>Senate</b>) within <b>40 minutes</b>!<br>The round will start in <b>5</b> minutes.</font>"
	mission_start_message = ""
	faction1 = AMERICAN
	faction2 = CIVILIAN
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET)
	songs = list(
		"To Arms in Dixie:1" = 'sound/music/to_arms_in_dixie.ogg',)
	artillery_count = 0
	valid_artillery = list()
	scores = list(
		"Militia" = 0,
		"National Guard" = 0,
	)
	var/ger_points = 0
	var/sov_points = 0
	var/a1_control = "none"
	var/a2_control = "none"
	grace_wall_timer = 2400

/obj/map_metadata/capitol_hill/New()
	..()
	spawn(2500)
		if (gamemode == "Siege")
			for (var/turf/T in get_area_turfs(/area/caribbean/no_mans_land/capturable/one))
				new /area/caribbean/british/land/inside/objective(T)
			for (var/turf/T in get_area_turfs(/area/caribbean/no_mans_land/capturable/two))
				new /area/caribbean/british/land/inside/objective(T)

/obj/map_metadata/capitol_hill/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_capitol == TRUE)
		if (gamemode != "Protect the VIP")
			if (J.is_whitehouse == TRUE)
				. = FALSE
			else
				. = TRUE
		else
			. = TRUE
	else
		. = FALSE


/obj/map_metadata/capitol_hill/roundend_condition_def2name(define)
	..()
	switch (define)
		if (CIVILIAN)
			return "Militia"
		if (AMERICAN)
			return "National Guard"
/obj/map_metadata/capitol_hill/roundend_condition_def2army(define)
	..()
	switch (define)
		if (CIVILIAN)
			return "Militias"
		if (AMERICAN)
			return "National Guards"

/obj/map_metadata/capitol_hill/army2name(army)
	..()
	switch (army)
		if ("Militias")
			return "Militia"
		if ("National Guards")
			return "National Guard"


/obj/map_metadata/capitol_hill/cross_message(faction)
	if (faction == CIVILIAN)
		return "<font size = 4>The Militias may now cross the invisible wall!</font>"
	else
		return ""

/obj/map_metadata/capitol_hill/reverse_cross_message(faction)
	if (faction == CIVILIAN)
		return "<span class = 'userdanger'>The Militias may no longer cross the invisible wall!</span>"
	else
		return ""


var/no_loop_capitol = FALSE

/obj/map_metadata/capitol_hill/update_win_condition()
	var/message = ""
	switch(gamemode)
		if ("Protect the VIP")
			if (processes.ticker.playtime_elapsed >= 18000)
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
						if (H.original_job_title == "US HVT" && H.stat != DEAD)
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
				message = "The National Guard has managed to defend the Capitol! The militias retreat!"
				world << "<font size = 4><span class = 'notice'>[message]</span></font>"
				show_global_battle_report(null)
				win_condition_spam_check = TRUE
				return FALSE
			if ((current_winner && current_loser && world.time > next_win) && no_loop_capitol == FALSE)
				ticker.finished = TRUE
				message = "The Militias have captured the Capitol!"
				world << "<font size = 4><span class = 'notice'>[message]</span></font>"
				show_global_battle_report(null)
				win_condition_spam_check = TRUE
				no_loop_capitol = TRUE
				return FALSE
			// German major
			else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
				if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
					if (last_win_condition != win_condition.hash)
						current_win_condition = "The Militias control the Capitol! They will win in {time} minutes."
						next_win = world.time + short_win_time(CIVILIAN)
						announce_current_win_condition()
						current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
						current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
			// German minor
			else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
				if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
					if (last_win_condition != win_condition.hash)
						current_win_condition = "The Militias control the Capitol! They will win in {time} minutes."
						next_win = world.time + short_win_time(CIVILIAN)
						announce_current_win_condition()
						current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
						current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
			// Soviet major
			else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
				if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
					if (last_win_condition != win_condition.hash)
						current_win_condition = "The Militias control the Capitol! They will win in {time} minutes."
						next_win = world.time + short_win_time(AMERICAN)
						announce_current_win_condition()
						current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
						current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
			// Soviet minor
			else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
				if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
					if (last_win_condition != win_condition.hash)
						current_win_condition = "The Militias control the Capitol! They will win in {time} minutes."
						next_win = world.time + short_win_time(AMERICAN)
						announce_current_win_condition()
						current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
						current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
			else
				if (current_win_condition != no_winner && current_winner && current_loser)
					world << "<font size = 3>The National Guard has recaptured the Capitol!</font>"
					current_winner = null
					current_loser = null
				next_win = -1
				current_win_condition = no_winner
				win_condition.hash = 0
			last_win_condition = win_condition.hash
			return TRUE


/obj/map_metadata/capitol_hill/proc/points_check()
	if (processes.ticker.playtime_elapsed > 4800)
		var/c1 = 0
		var/c2 = 0
		var/prev_control = a1_control
		var/cust_color = "white"
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/one))
				if (H.faction_text == "AMERICAN" && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == "CIVILIAN" && H.stat == CONSCIOUS)
					c2++
		if (c1+c2<=0 || c1 == c2)
			a1_control = "none"
		else if (c1 > c2)
			a1_control = "National Guard"
			cust_color="blue"
			ger_points++
		else if (c2 > c1)
			a1_control = "Militias"
			cust_color="red"
			sov_points++
		if (a1_control != prev_control)
			if (prev_control != "none")
				world << "<big><font color='[cust_color]'>[prev_control]</font> lost the <b>House</b>!</big>"
			else
				world << "<big><font color='[cust_color]'>[a1_control]</font> captured the <b>House</b>!</big>"
		c1 = 0
		c2 = 0
		prev_control = a2_control
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/two))
				if (H.faction_text == "AMERICAN" && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == "CIVILIAN" && H.stat == CONSCIOUS)
					c2++
		if (c1+c2<=0 || c1 == c2)
			a2_control = "none"
		else if (c1 > c2)
			a2_control = "National Guard"
			cust_color="blue"
			ger_points++
		else if (c2 > c1)
			a2_control = "Militias"
			cust_color="red"
			sov_points++
		if (a2_control != prev_control)
			if (prev_control != "none")
				world << "<big><font color='[cust_color]'>[prev_control]</font> lost the <b>Senate</b>!</big>"
			else
				world << "<big><font color='[cust_color]'>[a2_control]</font> captured the <b>Senate</b>!</big>"
	world << "<big><b>Current Points:</big></b>"
	world << "<big>National Guard: [scores["National Guard"]]</big>"
	world << "<big>Militia: [scores["Militia"]]</big>"
//	world << "<big>Militia: [ger_points]</big>"
//	world << "<big>Soviet Army: [sov_points]</big>"
	spawn(300)
		points_check()


/obj/map_metadata/capitol_hill/check_caribbean_block(var/mob/living/human/H, var/turf/T)
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

/////////CHINESE//////////
/obj/map_metadata/capitol_hill/pla_offensive
	ID = MAP_CAPITOL_HILL_PLA
	title = "PLA Offensive on the Capitol Hill"
	lobby_icon = 'icons/lobby/capitolchina.png'
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/one,/area/caribbean/no_mans_land/invisible_wall/two)
	respawn_delay = 600
	no_winner = "The operation is still underway."
	no_hardcore = TRUE
	gamemode = "Protect the VIP"
	faction_organization = list(
		AMERICAN,
		CHINESE)

	roundend_condition_sides = list(
		list(AMERICAN) = /area/caribbean/british/land/inside/objective,
		list(CHINESE) = /area/caribbean/arab
		)
	age = "2022"
	faction_distribution_coeffs = list(AMERICAN = 0.4, CHINESE = 0.6)
	battle_name = "Battle for the Capitol Hill"
	mission_start_message = ""
	faction1 = AMERICAN
	faction2 = CHINESE
	songs = list(
		"Red Sun Up in the Sky (Phonk Remix):1" = 'sound/music/redphonkinthesky.ogg',)
	valid_artillery = list()
	scores = list(
		"Peoples Liberation Army" = 0,
		"National Guard" = 0,
	)

/obj/map_metadata/capitol_hill/pla_offensive/job_enabled_specialcheck(var/datum/job/J)
	..()
	if(istype(J, /datum/job/american))
		if (J.is_capitol == TRUE && !(J.title == "US HVT"))
			. = TRUE
		else
			if (istype(J, /datum/job/american/hvt/specials))
				. = TRUE
			else
				. = FALSE
	else if (istype(J, /datum/job/chinese/pla))
		. = TRUE

/obj/map_metadata/capitol_hill/pla_offensive/roundend_condition_def2name(define)
	..()
	switch (define)
		if (CHINESE)
			return "China"
		if (AMERICAN)
			return "USA"
/obj/map_metadata/capitol_hill/pla_offensive/roundend_condition_def2army(define)
	..()
	switch (define)
		if (CHINESE)
			return "Chinese"
		if (AMERICAN)
			return "Americans"

/obj/map_metadata/capitol_hill/pla_offensive/army2name(army)
	..()
	switch (army)
		if ("Chinese")
			return "China"
		if ("Americans")
			return "USA"


/obj/map_metadata/capitol_hill/pla_offensive/cross_message(faction)
	if (faction == CHINESE)
		return "<font size = 4>The PLA may now cross the invisible wall!</font>"
	else
		return ""

/obj/map_metadata/capitol_hill/pla_offensive/reverse_cross_message(faction)
	if (faction == CHINESE)
		return "<span class = 'userdanger'>The PLA may no longer cross the invisible wall!</span>"
	else
		return ""

/obj/map_metadata/capitol_hill/pla_offensive/update_win_condition()
	var/message = ""
	if (processes.ticker.playtime_elapsed >= 18000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
		last_win_condition = win_condition.hash
		message = "25 minutes have passed! The HVTs are now safe!"
		to_chat(world, SPAN_NOTICE("<font size = 4>[message]</font>"))
		win_condition_spam_check = TRUE
		return FALSE
	if (processes.ticker.playtime_elapsed >= 3000)
		if (!win_condition_spam_check)
			var/count = 0
			for (var/mob/living/human/H in HVT_list)
				if (istype(H.original_job, /datum/job/american/hvt/specials) && H.stat != DEAD)
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
