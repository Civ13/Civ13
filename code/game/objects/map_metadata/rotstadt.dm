/obj/map_metadata/rotstadt
	ID = MAP_ROTSTADT
	title = "Rotstadt Counter Insurgency"
	lobby_icon = 'icons/lobby/rotstadt.png'
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/temperate)
	respawn_delay = 1800
	no_winner = "The battle is still going on."
	victory_time = 24000
	grace_wall_timer = 4800
	mission_start_message = "<font size=4>The Blugoslavian Armed Forces are launching an counter-insurgency operation in the occupied city of Rotstadt.<br>Their objective is to capture the RPR militia's <b>Commanding Bunker</b> in the <b>North-West corner</b> of the map.<br>The operation will begin in <b>8 minutes</b>.</font>"

	roundend_condition_sides = list(
		list(REDFACTION) = /area/caribbean/japanese/land/inside,
		list(BLUEFACTION) = /area/caribbean/british,
		)

	faction_organization = list(
		REDFACTION,
		BLUEFACTION)

	age = "2023"
	ordinal_age = 8
	faction_distribution_coeffs = list(REDFACTION = 0.5, BLUEFACTION = 0.5)
	battle_name = "Battle of Rotstadt"
	faction1 = REDFACTION
	faction2 = BLUEFACTION
	valid_weather_types = list(WEATHER_WET, WEATHER_EXTREME)
	songs = list(
		"Noisia - Shellshock:1" = 'sound/music/shellshock.ogg',)
	artillery_count = 0
	no_hardcore = TRUE
	var/list/squad_jobs_blue = list(
		"Squad 1" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 2" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 3" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Recon" = list("Sniper" = 4),
		"Armored" = list("Crew" = 4),
		"AT" = list("Anti-Tank" = 3),
		"Engineer" = list("Engineer" = 3),
		"none" = list("Doctor" = 2, "Officer" = 3, "Commander" = 1)
	)
	var/list/squad_jobs_red = list(
		"none" = list("Doctor" = 2, "Commander" = 1)
	)

/obj/map_metadata/rotstadt/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/bluefaction))
		if (J.is_event)
			if(findtext(J.title, "BAF"))
				. = TRUE
			else
				. = FALSE
	else if (istype(J, /datum/job/redfaction))
		if (J.is_rotstadt)
			. = TRUE
		else
			. = FALSE
	else
		. = FALSE

/obj/map_metadata/rotstadt/cross_message(faction)
	if (faction == REDFACTION)
		return "<font size = 4><font color='red'>The battle has begun!</font>"
	else if (faction == BLUEFACTION)
		return ""
	else
		return ""

/obj/map_metadata/rotstadt/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= grace_wall_timer || admin_ended_all_grace_periods)

/obj/map_metadata/rotstadt/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= grace_wall_timer || admin_ended_all_grace_periods)

/obj/map_metadata/rotstadt/check_caribbean_block(var/mob/living/human/H, var/turf/T)
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

/obj/map_metadata/rotstadt/short_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 1 MINUTES
	else
		return 2 MINUTES

/obj/map_metadata/rotstadt/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 1 MINUTES
	else
		return 5 MINUTES

///////////////////////////////////////////////////////////////////////
var/no_loop_rot = FALSE

/obj/map_metadata/rotstadt/update_win_condition()
	if (world.time >= victory_time || round_finished)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <b>Rotstadt People's Republic</b> has successfully defended the city! The battle is over!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_rot == FALSE)
		ticker.finished = TRUE
		var/message = "The <b>Blugoslavians</b> have succeeded in their latest counter-terrorist operation in Rotstadt! The battle is over!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_rot = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Blugoslavians</b> have captured the Redmenian stronghold! They will win in {time} minutes."
				next_win = world.time + short_win_time(BLUEFACTION)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Blugoslavians</b> have captured the Redmenian stronghold! They will win in {time} minutes."
				next_win = world.time + short_win_time(BLUEFACTION)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Blugoslavians</b> have captured the Redmenian stronghold! They will win in {time} minutes."
				next_win = world.time + short_win_time(BLUEFACTION)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Blugoslavians</b> have captured the Redmenian stronghold! They will win in {time} minutes."
				next_win = world.time + short_win_time(BLUEFACTION)
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

/mob/new_player/proc/LateChoicesRotstadt()
	var/list/available_jobs_per_side = list(
		BLUEFACTION = FALSE,
		REDFACTION = FALSE,
	)
	var/obj/map_metadata/rotstadt/MR = map
	src << browse(null, "window=latechoices")

	var/list/dat = list("<center>")
	dat += "<big><b>Welcome, [key].</b></big>"
	dat += "<br>"
	dat += "Round Duration: [roundduration2text_days()]"
	dat += "<br>"
	dat += "<b>Current Autobalance Status</b>: "
	if (BLUEFACTION in map.faction_organization)
		dat += "[alive_bluefaction.len] Blugoslavians "
	if (REDFACTION in map.faction_organization)
		dat += "[alive_redfaction.len] Redmenians "

	dat += "<br>"

	for (var/datum/job/job in job_master.faction_organized_occupations)
		if (!job.is_event)
			continue
		if (istype(job, /datum/job/bluefaction))
			if(!findtext(job.title, "BAF"))
				continue
			if(findtext(job.title, "BAF Doctor") && MR.squad_jobs_blue["none"]["Doctor"]<= 0)
				continue
			if(findtext(job.title, "BAF Officer") && MR.squad_jobs_blue["none"]["Officer"]<= 0)
				continue
			if(findtext(job.title, "BAF Commander") && MR.squad_jobs_blue["none"]["Commander"]<= 0)
				continue
			if(findtext(job.title, "BAF Squad [job.squad] Squadleader") && MR.faction2_squad_leaders[job.squad])
				continue
			if(findtext(job.title, "BAF Armored Squadleader") && MR.faction2_squad_leaders[job.squad])
				continue
			if(findtext(job.title, "BAF Armored Crew") && MR.squad_jobs_blue["Armored"]["Crew"]<= 0)
				continue
			if(findtext(job.title, "BAF Recon") && MR.squad_jobs_blue["Recon"]["Sniper"]<= 0)
				continue
			if(findtext(job.title, "BAF Anti-Tank") && MR.squad_jobs_blue["AT"]["Anti-Tank"]<= 0)
				continue
			if(findtext(job.title, "BAF Engineer") && MR.squad_jobs_blue["Engineer"]["Engineer"]<= 0)
				continue
			if(findtext(job.title, "BAF Squad [job.squad] Machinegunner") && MR.squad_jobs_blue["Squad [job.squad]"]["Machinegunner"]<= 0)
				continue
		if (istype(job, /datum/job/redfaction))
			if (!job.is_rotstadt)
				continue
			if(findtext(job.title, "RPR Commander") && MR.squad_jobs_red["none"]["Commander"]<= 0)
				continue
			if(findtext(job.title, "RPR Doctor") && MR.squad_jobs_red["none"]["Doctor"]<= 0)
				continue

		if (job)
			var/active = processes.job_data.get_active_positions(job)
			var/extra_span = "<b>"
			var/end_extra_span = "</b>"
			if (job.is_squad_leader)
				extra_span = "<br><b><font size=2>"
				end_extra_span = "</font></b>"
			else if (job.is_commander)
				extra_span = "<br><font size=3>"
				end_extra_span = "</font>"
			else if ((job.is_medic && !findtext(job.title, "Corpsman")) || !findtext(job.title, "Squad"))
				extra_span = "<br>"
				end_extra_span = ""

			dat += "[extra_span]<a style=\"background-color:[job.selection_color];\" href='byond://?src=\ref[src];SelectedJob=[job.title]'>[job.title] (Active: [active])</a>[end_extra_span]"
			++available_jobs_per_side[job.base_type_flag()]

	dat += "</center>"

	var/data = ""
	for (var/line in dat)
		if (line != null)
			if (line != "<br>")
				data += "<span style = 'font-size:2.0rem;'>[line]</span>"
			data += "<br>"

	data = {"
		<br>
		<html>
		<head>
		[common_browser_style]
		</head>
		<body>
		[data]
		</body>
		</html>
		<br>
	"}

	spawn (1)
		src << browse(data, "window=latechoices;size=600x640;can_close=1")

