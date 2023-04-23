/obj/map_metadata/campaign_noncanon
	ID = MAP_CAMPAIGN
	title = "Campaign"
	lobby_icon = "icons/lobby/campaign.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/temperate)
	respawn_delay = 1800
	no_winner = "The battle is going on."
	victory_time = 60 MINUTES
	grace_wall_timer = 20 MINUTES
	faction_organization = list(
		PIRATES,
		CIVILIAN)

	roundend_condition_sides = list(
		list(PIRATES) = /area/caribbean/british/land,
		list(CIVILIAN) = /area/caribbean/japanese,
		)
	age = "2023"
	ordinal_age = 8
	faction_distribution_coeffs = list(PIRATES = 0.5, CIVILIAN = 0.5)
	battle_name = "Battle of Rotstadt"
	mission_start_message = "<font size=4><b>20 minutes</b> until the battle begins.</font>"
	faction1 = PIRATES
	faction2 = CIVILIAN
	valid_weather_types = list(WEATHER_WET, WEATHER_EXTREME)
	songs = list(
		"Emma:1" = "sound/music/emma.ogg",)
	artillery_count = 0
	var/list/squad_jobs_blue = list(
		"Squad 1" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 2" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 3" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Recon" = list("Sniper" = 4),
		// "Armored" = list("Crew" = 8),
		"AT" = list("Anti-Tank" = 3),
		"Engineer" = list("Engineer" = 3),
		"none" = list("Doctor" = 2, "Officer" = 3, "Commander" = 1)
	)
	var/list/squad_jobs_red = list(
		"Squad 1" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 2" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 3" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Recon" = list("Sniper" = 4),
		"Armored" = list("Crew" = 8),
		"AT" = list("Anti-Tank" = 3),
		"Engineer" = list("Engineer" = 3),
		"none" = list("Doctor" = 2, "Officer" = 3, "Commander" = 1)
	)

/obj/map_metadata/campaign_noncanon/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/civilian))
		if (J.is_event)
			. = TRUE
		else
			. = FALSE
	else if (istype(J, /datum/job/pirates))
		if (J.is_rotstadt)
			. = TRUE
		else
			. = FALSE
	else
		. = FALSE

/obj/map_metadata/campaign_noncanon/cross_message(faction)
	if (faction == PIRATES)
		return "<font size = 4><font color='red'>The battle has begun!</font>"
	else if (faction == CIVILIAN)
		return ""
	else
		return ""

/obj/map_metadata/campaign_noncanon/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= grace_wall_timer || admin_ended_all_grace_periods)

/obj/map_metadata/campaign_noncanon/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= grace_wall_timer || admin_ended_all_grace_periods)

/obj/map_metadata/campaign_noncanon/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/temperate/two))
			if (H.faction_text == faction1)
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/temperate/one))
			if (H.faction_text == faction2)
				return TRUE
		else
			return !faction1_can_cross_blocks()
	return FALSE

/obj/map_metadata/campaign_noncanon/short_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 2 MINUTES
	else
		return 2 MINUTES

/obj/map_metadata/campaign_noncanon/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 2 MINUTES
	else
		return 5 MINUTES

var/no_loop_cm2 = FALSE

///////////arty and stuff/////////////
/obj/map_metadata/campaign_noncanon/proc/napalm_strike(var/inputx, var/inputy, var/inputz)
	var/xoffsetmin = inputx-4
	var/xoffsetmax = inputx+4
	var/yoffsetmin = inputy-4
	var/yoffsetmax = inputy+4
	for (var/i = xoffsetmin, i <= xoffsetmax, i++)
		for(var/yi = yoffsetmin, yi <= yoffsetmax, yi++)
			if(prob(86))
				var/turf/O = get_turf(locate(i,yi,inputz))
				if(prob(7))
					explosion(O,0,1,1,3)
				spawn(rand(15,50))
					for (var/mob/living/LS1 in O)
						LS1.adjustFireLoss(35)
						LS1.fire_stacks += rand(9,13)
						LS1.IgniteMob()
					new/obj/effect/fire(O)
	spawn(10)
		xoffsetmin = inputx-4
		xoffsetmax = inputx+4
		yoffsetmin = inputy-4
		yoffsetmax = inputy+4
		for (var/i = 1, i < 18, i++)
			var/turf/O = get_turf(locate(rand(xoffsetmin,xoffsetmax),rand(yoffsetmin,yoffsetmax),inputz))
			for (var/mob/living/LS1 in O)
				LS1.adjustFireLoss(14)
				LS1.fire_stacks += rand(2,4)
				LS1.IgniteMob()
			new/obj/effect/fire(O)
/obj/map_metadata/campaign_noncanon/proc/precision_strike(var/inputx, var/inputy, var/inputz)
	var/xoffsetmin = inputx-2
	var/xoffsetmax = inputx+2
	var/yoffsetmin = inputy-2
	var/yoffsetmax = inputy+2
	for (var/i = 1, i < 3, i++)
		var/turf/O = get_turf(locate(rand(xoffsetmin,xoffsetmax),rand(yoffsetmin,yoffsetmax),inputz))
		explosion(O,2,3,3,2)
//40-106,34-77

/obj/map_metadata/campaign_noncanon/proc/city_mrl_strike()
	mrl_strike(13,60,97,34,63,2)
	spawn(100)
		mrl_strike(5,97,105,34,73,2)

/obj/map_metadata/campaign_noncanon/proc/mrl_strike(var/strikenum = 18, var/xoffsetmin, var/xoffsetmax, var/yoffsetmin, var/yoffsetmax, var/inputz)
	var/sound/uploaded_sound = sound('sound/weapons/Explosives/mrls.ogg', repeat = FALSE, wait = TRUE, channel = 777)
	uploaded_sound.priority = 250
	for (var/mob/M in player_list)
		if (!new_player_mob_list.Find(M))
			M.client << uploaded_sound
			M << "<font size=4>You hear the blood-curdling sound of rocket artillery being fired!</font>"
	spawn(40)
		for (var/i = 1, i <= strikenum, i++)
			spawn(i*4)
				var/turf/O = get_turf(locate(rand(xoffsetmin,xoffsetmax),rand(yoffsetmin,yoffsetmax),inputz))
				explosion(O,2,3,3,3)

///////////////////////////////////////////////////////////////////////
/obj/map_metadata/campaign_noncanon/rotstadt
	victory_time = 36000
	grace_wall_timer = 9000
	mission_start_message = "<font size=4><b>15 minutes</b> until the battle begins.</font>"
	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/british,
		list(PIRATES) = /area/caribbean/japanese/land/inside,
		)
obj/map_metadata/campaign_noncanon/rotstadt/job_enabled_specialcheck(var/datum/job/J)
	if (istype(J, /datum/job/civilian))
		if (J.is_event)
			. = TRUE
		else
			. = FALSE
	else if (istype(J, /datum/job/pirates))
		if (J.is_rotstadt)
			. = TRUE
		else
			. = FALSE
	else
		. = FALSE
/obj/map_metadata/campaign_noncanon/rotstadt/update_win_condition()

	if (world.time >= victory_time || round_finished)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <b>Rotstadt People's Republic</b> has successfully defended the city! The battle is over!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_cm2 == FALSE)
		ticker.finished = TRUE
		var/message = "The <b>Blugoslavs</b> have succeeded in their latest counter-terrorist operation in Rotstadt! The battle is over!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_cm = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Blugoslavs</b> have captured the Redmenian stronghold! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Blugoslavs</b> have captured the Redmenian stronghold! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Blugoslavs</b> have captured the Redmenian stronghold! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Blugoslavs</b> have captured the Redmenian stronghold! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The <b>Redmenians</b> have recaptured their stronghold!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE
