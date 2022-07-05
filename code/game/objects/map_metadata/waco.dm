/obj/map_metadata/waco
	ID = MAP_WACO
	title = "Waco Siege"
	lobby_icon = "icons/lobby/waco.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/one,/area/caribbean/no_mans_land/invisible_wall/two, /area/caribbean/no_mans_land/invisible_wall/inside)
	respawn_delay = 1200
	no_hardcore = TRUE
	var/list/HVT_list = list()

	faction_organization = list(
		CIVILIAN,
		AMERICAN)

	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/no_mans_land/capturable,
		list(AMERICAN) = /area/caribbean/japanese/land/inside/command,
		)
	age = "1993"
	ordinal_age = 7
	faction_distribution_coeffs = list(CIVILIAN = 0.3, AMERICAN = 0.7)
	battle_name = "Siege of Mount Carmel"
	mission_start_message = "<font size=4>All factions have <b>5 minutes</b> to prepare before the ceasefire ends!<br>The ATF will win if they capture the <b>Davidian leader's rooms inside the compound</b>. The Davidians will win if they manage to defend their home for <b>20 minutes!</b></font>"
	faction1 = CIVILIAN
	faction2 = AMERICAN
	grace_wall_timer = 3000
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET)
	songs = list(
		"Mad Man In Waco (David Koresh):1" = "sound/music/mad_man_in_waco.ogg",)

/obj/map_metadata/waco/New()
	..()
	spawn(2500)
		if (gamemode == "Siege")
			for (var/turf/T in get_area_turfs(/area/caribbean/british/land/inside/objective))
				new /area/caribbean/no_mans_land/capturable(T)
/obj/map_metadata/waco/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_waco == TRUE)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/waco/roundend_condition_def2name(define)
	..()
	switch (define)
		if (AMERICAN)
			return "American"
		if (CIVILIAN)
			return "Davidian"
/obj/map_metadata/waco/roundend_condition_def2army(define)
	..()
	switch (define)
		if (AMERICAN)
			return "ATF"
		if (CIVILIAN)
			return "Davidian"

/obj/map_metadata/waco/army2name(army)
	..()
	switch (army)
		if ("ATF")
			return "ATF"
		if ("Davidian")
			return "Davidian"


/obj/map_metadata/waco/cross_message(faction)
	if (faction == AMERICAN)
		return "<font size = 4>The ATF may now cross the invisible wall!</font>"
	else if (faction == CIVILIAN)
		return ""
	else
		return ""

/obj/map_metadata/waco/reverse_cross_message(faction)
	if (faction == AMERICAN)
		return "<span class = 'userdanger'>The ATF may no longer cross the invisible wall!</span>"
	else if (faction == CIVILIAN)
		return ""
	else
		return ""
var/no_loop_waco = FALSE


/obj/map_metadata/waco/update_win_condition()
	var/message = ""
	switch(gamemode)
		if ("Protect the VIP")
			if (processes.ticker.playtime_elapsed >= 12000)
				if (win_condition_spam_check)
					return FALSE
				ticker.finished = TRUE
				next_win = -1
				current_win_condition = no_winner
				win_condition.hash = 0
				last_win_condition = win_condition.hash
				message = "20 minutes have passed! The Koresh is now safe!"
				world << "<font size = 4><span class = 'notice'>[message]</span></font>"
				win_condition_spam_check = TRUE
				return FALSE
			if (processes.ticker.playtime_elapsed >= 1800)
				if (!win_condition_spam_check)
					var/count = 0
					for (var/mob/living/human/H in HVT_list)
						if (H.original_job_title == "Messiah" && H.stat != DEAD)
							count++
					if (count == 0)
						message = "The battle is over! <b>David Koresh</b> is dead!"
						world << "<font size = 4 color='yellow'><span class = 'notice'>[message]</span></font>"
						win_condition_spam_check = TRUE
						ticker.finished = TRUE
						next_win = -1
						current_win_condition = no_winner
						win_condition.hash = 0
						last_win_condition = win_condition.hash
						return FALSE
		if ("Siege")
			if (world.time >= 12000)
				if (win_condition_spam_check)
					return FALSE
				ticker.finished = TRUE
				message = "The Branch Davidians have managed to defend Mount Carmel!"
				world << "<font size = 4><span class = 'notice'>[message]</span></font>"
				show_global_battle_report(null)
				win_condition_spam_check = TRUE
				return FALSE
			if ((current_winner && current_loser && world.time > next_win) && no_loop_waco == FALSE)
				ticker.finished = TRUE
				message = "The ATF have captured Mount Carmel!"
				world << "<font size = 4><span class = 'notice'>[message]</span></font>"
				show_global_battle_report(null)
				win_condition_spam_check = TRUE
				no_loop_waco = TRUE
				return FALSE
			// German major
			else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
				if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
					if (last_win_condition != win_condition.hash)
						current_win_condition = "The ATF control the Mount Carmel! They will win in {time} minutes."
						next_win = world.time + short_win_time(CIVILIAN)
						announce_current_win_condition()
						current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
						current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
			// German minor
			else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
				if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
					if (last_win_condition != win_condition.hash)
						current_win_condition = "The ATF control the Mount Carmel! They will win in {time} minutes."
						next_win = world.time + short_win_time(CIVILIAN)
						announce_current_win_condition()
						current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
						current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
			// Soviet major
			else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
				if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
					if (last_win_condition != win_condition.hash)
						current_win_condition = "The ATF control the Mount Carmel! They will win in {time} minutes."
						next_win = world.time + short_win_time(AMERICAN)
						announce_current_win_condition()
						current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
						current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
			// Soviet minor
			else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
				if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
					if (last_win_condition != win_condition.hash)
						current_win_condition = "The ATF control the Mount Carmel! They will win in {time} minutes."
						next_win = world.time + short_win_time(AMERICAN)
						announce_current_win_condition()
						current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
						current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
			else
				if (current_win_condition != no_winner && current_winner && current_loser)
					world << "<font size = 3>The Davidians has recaptured the Mount Carmel!</font>"
					current_winner = null
					current_loser = null
				next_win = -1
				current_win_condition = no_winner
				win_condition.hash = 0
			last_win_condition = win_condition.hash
			return TRUE

/obj/map_metadata/waco/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/two))
			if (H.faction_text == faction2)
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/one))
			if (H.faction_text == faction1)
				return TRUE
		else
			return !faction2_can_cross_blocks()
	return FALSE

/obj/map_metadata/waco/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/one) && processes.ticker.playtime_elapsed <= 3000)
			if (H.faction_text == faction2 || H.faction_text == faction1)
				return TRUE
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/inside))
			if (H.faction_text == faction2)
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/two))
			if (H.faction_text == faction1)
				return TRUE
		else
			return !faction2_can_cross_blocks()
	return FALSE