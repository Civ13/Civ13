
/obj/map_metadata/campaign
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
	battle_name = "battle of Dewsbury Village"
	mission_start_message = "<font size=4><b>20 minutes</b> until the battle begins.</font>"
	faction1 = PIRATES
	faction2 = CIVILIAN
	valid_weather_types = list(WEATHER_WET, WEATHER_NONE, WEATHER_EXTREME)
	songs = list(
		"Emma:1" = "sound/music/emma.ogg",)
	artillery_count = 0
	scores = list(
		"Blugoslavia" = 0,
		"Redmenia" = 0,
	)
	var/list/civilians_evacuated = list(
		"Blugoslavia" = 0,
		"Redmenia" = 0,
	)
	var/list/civilians_killed = list(
		"Blugoslavia" = 0,
		"Redmenia" = 0,
	)
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

/obj/map_metadata/campaign/New()
	..()
	civ_collector()

/obj/map_metadata/campaign/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/civilian))
		if (J.is_event)
			. = TRUE
		else
			. = FALSE
	else if (istype(J, /datum/job/pirates))
		if (J.is_event)
			. = TRUE
		else
			. = FALSE
	else
		. = FALSE

/obj/map_metadata/campaign/cross_message(faction)
	if (faction == PIRATES)
		return "<font size = 4><font color='red'>The battle has begun!</font>"
	else if (faction == CIVILIAN)
		return ""
	else
		return ""

/obj/map_metadata/campaign/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= grace_wall_timer || admin_ended_all_grace_periods)

/obj/map_metadata/campaign/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= grace_wall_timer || admin_ended_all_grace_periods)

/obj/map_metadata/campaign/check_caribbean_block(var/mob/living/human/H, var/turf/T)
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

/obj/map_metadata/campaign/short_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 2 MINUTES
	else
		return 2 MINUTES

/obj/map_metadata/campaign/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 2 MINUTES
	else
		return 5 MINUTES

/obj/map_metadata/campaign/proc/civ_collector()
	var/ctb = 0
	var/ctr = 0
	for(var/turf/T in get_area_turfs(/area/caribbean/japanese/land))
		for (var/mob/living/simple_animal/civilian/CVL in T)
			if(istype(CVL, /mob/living/simple_animal/civilian/greenistani_ambassador) && CVL.stat != DEAD)
				var/msg = "<font size=4><font color='blue'><b>Blugoslavia</b></font> has sucessfully evacuated the Greenistani Ambassador!</font></font>"
				world << msg
				game_log(msg)
				qdel(CVL)
			else
				if(CVL.stat != DEAD)
					qdel(CVL)
					civilians_evacuated["Blugoslavia"]++
	for(var/turf/T in get_area_turfs(/area/caribbean/pirates/land))
		for (var/mob/living/simple_animal/civilian/CVL in T)
			if(istype(CVL, /mob/living/simple_animal/civilian/greenistani_ambassador))
				var/msg = "<font size=4><font color='red'><b>Redmenia</b></font> has sucessfully evacuated the Greenistani Ambassador!</font></font>"
				world << msg
				game_log(msg)
			else
				if(CVL.stat != DEAD)
					qdel(CVL)
					civilians_evacuated["Redmenia"]++
	spawn(600)
		civ_collector()
	return "[ctb],[ctr]"

//role selector
/mob/new_player/proc/LateChoicesCampaign(factjob)
	var/list/available_jobs_per_side = list(
		CIVILIAN = FALSE,
		PIRATES = FALSE,
	)
	var/obj/map_metadata/campaign/MC = map
	src << browse(null, "window=latechoices")

	var/list/dat = list("<center>")
	dat += "<b><big>Welcome, [key].</big></b>"
	dat += "<br>"
	dat += "Round Duration: [roundduration2text_days()]"
	dat += "<br>"
	dat += "<b>Current Autobalance Status</b>: "
	if (PIRATES in map.faction_organization)
		dat += "[alive_pirates.len] Redmenians "
	if (CIVILIAN in map.faction_organization)
		dat += "[alive_civilians.len] Blugoslavians "

	dat += "<br>"
	if (istype(map, /obj/map_metadata/campaign/campaign7))
		if (factjob == "BAF")
			dat +="<b><h1><big>Blugoslavian Naval Forces</big></h1></b>"
		else if (factjob == "RDF")
			dat +="<b><h1><big>Imperial Redmenian Navy</big></h1></b>"
		for (var/datum/job/job in job_master.faction_organized_occupations)
			if (!job.is_event)
				continue
			if (factjob == "BAF")
				if(!findtext(job.title, "BNF"))
					continue
				if(findtext(job.title, "BNF Doctor") && MC.squad_jobs_blue["none"]["Doctor"]<= 0)
					continue
				if(findtext(job.title, "BNF Ensign") && MC.squad_jobs_blue["none"]["Officer"]<= 0)
					continue
				if(findtext(job.title, "BNF Captain") && MC.squad_jobs_blue["none"]["Commander"]<= 0)
					continue
				if(findtext(job.title, "BNF Squad [job.squad] Petty Officer") && MC.faction2_squad_leaders[job.squad])
					continue
				if(findtext(job.title, "BNF Marine Squadleader") && MC.faction2_squad_leaders[3])
					continue
			else if (factjob == "RDF")
				if(!findtext(job.title, "IRN"))
					continue
				if(findtext(job.title, "IRN Doctor") && MC.squad_jobs_red["none"]["Doctor"]<= 0)
					continue
				if(findtext(job.title, "IRN Ensign") && MC.squad_jobs_red["none"]["Officer"]<= 0)
					continue
				if(findtext(job.title, "IRN Captain") && MC.squad_jobs_red["none"]["Commander"]<= 0)
					continue
				if(findtext(job.title, "IRN Squad [job.squad] Petty Officer") && MC.faction1_squad_leaders[job.squad])
					continue
				if(findtext(job.title, "IRN Marine Squadleader") && MC.faction1_squad_leaders[3])
					continue
			if (job)
				var/active = processes.job_data.get_active_positions(job)
				var/extra_span = ""
				var/end_extra_span = "<br>"
				if (job.is_squad_leader)
					extra_span = "<b>"
					end_extra_span = "</b><br>"
				else if (job.is_commander)
					extra_span = "<font size=3><b>"
					end_extra_span = "</b></font><br>"
				else if (job.is_officer)
					extra_span = "<font size=3>"
					end_extra_span = "</font><br>"
				else if ((job.is_medic && !findtext(job.title, "Corpsman")))
					extra_span = "<b>"
					end_extra_span = "</b><br>"

				dat += "[extra_span]<a style=\"background-color:[job.selection_color];\" href='byond://?src=\ref[src];SelectedJob=[job.title]'>[job.title] (Active: [active])</a>[end_extra_span]"
				++available_jobs_per_side[job.base_type_flag()]
///////////////////////////////////////////////////////////////////////////////////////////////////
	else if (istype(map, /obj/map_metadata/nomads_persistence_beta))
		if (factjob == "BAF")
			dat +="<b><h1><big>Blugoslavian People</big></h1></b>"
		else if (factjob == "RDF")
			dat +="<b><h1><big>Redmenian People</big></h1></b>"
		for (var/datum/job/job in job_master.faction_organized_occupations)
			if (!job.is_event)
				continue
			if (factjob == "BAF")
				if(!findtext(job.title, "Blugoslavian Civilian"))
					continue
			else if (factjob == "RDF")
				if(!findtext(job.title, "Redmenian Civilian"))
					continue
			if (job)
				var/active = processes.job_data.get_active_positions(job)
				var/extra_span = ""
				var/end_extra_span = "<br>"
				if (job.is_squad_leader)
					extra_span = "<b>"
					end_extra_span = "</b><br>"
				else if (job.is_commander)
					extra_span = "<font size=3><b>"
					end_extra_span = "</b></font><br>"
				else if (job.is_officer)
					extra_span = "<font size=3>"
					end_extra_span = "</font><br>"
				else if ((job.is_medic && !findtext(job.title, "Corpsman")))
					extra_span = "<b>"
					end_extra_span = "</b><br>"

				dat += "[extra_span]<a style=\"background-color:[job.selection_color];\" href='byond://?src=\ref[src];SelectedJob=[job.title]'>[job.title] (Active: [active])</a>[end_extra_span]"
				++available_jobs_per_side[job.base_type_flag()]
	else
		if (factjob == "BAF")
			dat +="<b><h1><big>Blugoslavian Armed Forces</big></h1></b>"
		else if (factjob == "RDF")
			dat +="<b><h1><big>Redmenia Defense Force</big></h1></b>"
		for (var/datum/job/job in job_master.faction_organized_occupations)
			if (!job.is_event)
				continue
			if (factjob == "BAF")
				if(!findtext(job.title, "BAF"))
					continue
				if(findtext(job.title, "BAF Doctor") && MC.squad_jobs_blue["none"]["Doctor"]<= 0)
					continue
				if(findtext(job.title, "BAF Officer") && MC.squad_jobs_blue["none"]["Officer"]<= 0)
					continue
				if(findtext(job.title, "BAF Commander") && MC.squad_jobs_blue["none"]["Commander"]<= 0)
					continue
				if(findtext(job.title, "BAF Squad [job.squad] Squadleader") && MC.faction2_squad_leaders[job.squad])
					continue
				if(findtext(job.title, "BAF Armored Squadleader") && MC.faction2_squad_leaders[job.squad])
					continue
				if(findtext(job.title, "BAF Armored Crew") && MC.squad_jobs_red["Armored"]["Crew"]<= 0)
					continue
				if(findtext(job.title, "BAF Recon") && MC.squad_jobs_blue["Recon"]["Sniper"]<= 0)
					continue
				if(findtext(job.title, "BAF Anti-Tank") && MC.squad_jobs_blue["AT"]["Anti-Tank"]<= 0)
					continue
				if(findtext(job.title, "BAF Engineer") && MC.squad_jobs_blue["Engineer"]["Engineer"]<= 0)
					continue
				if(findtext(job.title, "BAF Squad [job.squad] Machinegunner") && MC.squad_jobs_blue["Squad [job.squad]"]["Machinegunner"]<= 0)
					continue
			else if (factjob == "RDF")
				if(!findtext(job.title, "RDF"))
					continue
				if(findtext(job.title, "RDF Doctor") && MC.squad_jobs_red["none"]["Doctor"]<= 0)
					continue
				if(findtext(job.title, "RDF Officer") && MC.squad_jobs_red["none"]["Officer"]<= 0)
					continue
				if(findtext(job.title, "RDF Commander") && MC.squad_jobs_red["none"]["Commander"]<= 0)
					continue
				if(findtext(job.title, "RDF Squad [job.squad] Squadleader") && MC.faction1_squad_leaders[job.squad])
					continue
				if(findtext(job.title, "RDF Armored Squadleader") && MC.faction1_squad_leaders[job.squad])
					continue
				if(findtext(job.title, "RDF Armored Crew") && MC.squad_jobs_red["Armored"]["Crew"]<= 0)
					continue
				if(findtext(job.title, "RDF Recon") && MC.squad_jobs_red["Recon"]["Sniper"]<= 0)
					continue
				if(findtext(job.title, "RDF Anti-Tank") && MC.squad_jobs_red["AT"]["Anti-Tank"]<= 0)
					continue
				if(findtext(job.title, "RDF Engineer") && MC.squad_jobs_red["Engineer"]["Engineer"]<= 0)
					continue
				if(findtext(job.title, "RDF Squad [job.squad] Machinegunner") && MC.squad_jobs_red["Squad [job.squad]"]["Machinegunner"]<= 0)
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

/obj/item/weapon/key/blue
	code = 932145
	name = "Blugoslavian Key"

/obj/item/weapon/key/red
	code = 668643
	name = "Redmenian Key"

/*
/obj/map_metadata/campaign/update_win_condition()
	if (world.time >= victory_time)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The [battle_name ? battle_name : "battle"] has ended in a stalemate!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if (world.time >= next_win && next_win != -1)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The [battle_name ? battle_name : "battle"] has ended in a stalemate!"
		if (current_winner && current_loser)
			message = "The battle is over! The [current_winner] was victorious [current_loser][battle_name ? "in the [battle_name]" : ""]!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		game_log(message)
		world << "<b><big>Civilians Rescued:</b> <font color='blue'>Blugoslavia</font> [civilians_evacuated["Blugoslavia"]], <font color='red'>Redmenia</font> [civilians_evacuated["Redmenia"]]</big>"
		world << "<b><big>Civilians Killed:</b> <font color='blue'>Blugoslavia</font> [civilians_killed["Blugoslavia"]], <font color='red'>Redmenia</font> [civilians_killed["Redmenia"]]</big>"
		game_log("Civilians Rescued: Blugoslavia [civilians_evacuated["Blugoslavia"]], Redmenia [civilians_evacuated["Redmenia"]]")
		game_log("Civilians Killed: Blugoslavia [civilians_killed["Blugoslavia"]], Redmenia [civilians_killed["Redmenia"]]")
		game_log("Scores: [scores["Blugoslavia"]], [scores["Redmenia"]]")
		win_condition_spam_check = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[1][1])] has captured the Objective! They will win in {time} minute{s}."
				next_win = world.time + short_win_time(roundend_condition_sides[2][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[1][1])] has captured the Objective! They will win in {time} minute{s}."
				next_win = world.time + long_win_time(roundend_condition_sides[2][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[2][1])] has captured the Objective! They will win in {time} minute{s}."
				next_win = world.time + short_win_time(roundend_condition_sides[1][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[2][1])] has captured the Objective! They will win in {time} minute{s}."
				next_win = world.time + long_win_time(roundend_condition_sides[1][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])

	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The [current_winner] has lost control of the Objective!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE
*/


var/no_loop_cm = FALSE

/obj/map_metadata/campaign/update_win_condition()
	if (world.time >= victory_time)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <b>Redmenians</b> are victorious [battle_name ? "in the [battle_name]" : ""]! The Blugoslavians halted the attack!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		world << "<b><big>Civilians Killed:</b> <font color='blue'>Blugoslavia</font> [civilians_killed["Blugoslavia"]], <font color='red'>Redmenia</font> [civilians_killed["Redmenia"]]</big>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_cm == FALSE)
		ticker.finished = TRUE
		var/message = "The <b>Blugoslavians</b> are victorious [battle_name ? "in the [battle_name]" : ""]!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		world << "<b><big>Civilians Killed:</b> <font color='blue'>Blugoslavia</font> [civilians_killed["Blugoslavia"]], <font color='red'>Redmenia</font> [civilians_killed["Redmenia"]]</big>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_cm = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Blugoslavians</b> have captured the objective! They will win in {time} minutes."
				next_win = world.time + short_win_time(PIRATES)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Blugoslavians</b> have captured the objective! They will win in {time} minutes."
				next_win = world.time + short_win_time(PIRATES)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Blugoslavians</b> have captured the objective! They will win in {time} minutes."
				next_win = world.time + short_win_time(PIRATES)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Blugoslavians</b> have captured the objective! They will win in {time} minutes."
				next_win = world.time + short_win_time(PIRATES)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The <b>Redmenians</b> have recaptured control over the objective!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

///////////arty and stuff/////////////
/obj/map_metadata/campaign/proc/napalm_strike(var/inputx, var/inputy, var/inputz)
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
						LS1.adjustBurnLoss(35)
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
				LS1.adjustBurnLoss(14)
				LS1.fire_stacks += rand(2,4)
				LS1.IgniteMob()
			new/obj/effect/fire(O)
/obj/map_metadata/campaign/proc/precision_strike(var/inputx, var/inputy, var/inputz)
	var/xoffsetmin = inputx-2
	var/xoffsetmax = inputx+2
	var/yoffsetmin = inputy-2
	var/yoffsetmax = inputy+2
	for (var/i = 1, i < 3, i++)
		var/turf/O = get_turf(locate(rand(xoffsetmin,xoffsetmax),rand(yoffsetmin,yoffsetmax),inputz))
		explosion(O,2,3,3,2)
//40-106,34-77

/obj/map_metadata/campaign/proc/city_mrl_strike()
	mrl_strike(13,60,97,34,63,2)
	spawn(100)
		mrl_strike(5,97,105,34,73,2)

/obj/map_metadata/campaign/proc/mrl_strike(var/strikenum = 18, var/xoffsetmin, var/xoffsetmax, var/yoffsetmin, var/yoffsetmax, var/inputz)
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
/obj/map_metadata/campaign/campaign5
	victory_time = 48000
	grace_wall_timer = 12000
	mission_start_message = "<font size=4><b>20 minutes</b> until the battle begins.</font>"
	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/british/land/outside/objective,
		list(PIRATES) = /area/caribbean/japanese
		)
/obj/map_metadata/campaign/campaign5/update_win_condition()

	if (world.time >= victory_time || round_finished)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <b>Blugoslavians</b> have sucessfuly defended the road! The Redmenians have failed to encircle the 12th Brigade!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_cm == FALSE)
		ticker.finished = TRUE
		var/message = "The <b>Redmenians</b> have captured the road and encircled the 12th Brigade to the West! The battle is over!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_cm = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Redmenians</b> have captured the road! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Redmenians</b> have captured the road! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Redmenians</b> have captured the road! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Redmenians</b> have captured the road! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The <b>Blugoslavians</b> have recaptured the road!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

///////////////////////////////////////////////////////////////////////
/obj/map_metadata/campaign/campaign6
	victory_time = 36000
	grace_wall_timer = 9000
	mission_start_message = "<font size=4><b>15 minutes</b> until the battle begins.</font>"
	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/british,
		list(PIRATES) = /area/caribbean/japanese/land,
		)
/obj/map_metadata/campaign/campaign6/job_enabled_specialcheck(var/datum/job/J)
	if (istype(J, /datum/job/civilian))
		if (J.is_event)
			. = TRUE
		else
			. = FALSE
	else if (istype(J, /datum/job/pirates))
		if (J.is_event)
			. = TRUE
		else
			. = FALSE
	else
		. = FALSE
/obj/map_metadata/campaign/campaign6/update_win_condition()

	if (world.time >= victory_time || round_finished)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <b>Redmenians</b> have sucessfuly defended Woodling! The Blugoslavians have retreated!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		win_condition_spam_check = TRUE
		show_global_battle_report(null)
		world << "<b><big>Civilians Killed:</b> <font color='blue'>Blugoslavia</font> [civilians_killed["Blugoslavia"]], <font color='red'>Redmenia</font> [civilians_killed["Redmenia"]]</big>"
		game_log("Civilians Killed: Blugoslavia [civilians_killed["Blugoslavia"]], Redmenia [civilians_killed["Redmenia"]]")
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_cm == FALSE)
		ticker.finished = TRUE
		var/message = "The <b>Blugoslavians</b> have captured the eastern side of the river! The battle is over!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		world << "<b><big>Civilians Killed:</b> <font color='blue'>Blugoslavia</font> [civilians_killed["Blugoslavia"]], <font color='red'>Redmenia</font> [civilians_killed["Redmenia"]]</big>"
		game_log("Civilians Killed: Blugoslavia [civilians_killed["Blugoslavia"]], Redmenia [civilians_killed["Redmenia"]]")
		no_loop_cm = TRUE
		return FALSE
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Blugoslavians</b> have control over the eastern side of the river! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Blugoslavians</b> have control over the eastern side of the river! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Blugoslavians</b> have control over the eastern side of the river! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Blugoslavians</b> have control over the eastern side of the river! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The <b>Redmenians</b> have recaptured the eastern side of the river!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/campaign/campaign6/proc/paradrop()
	for(var/turf/T in list(locate(137,48,1),locate(125,48,1),locate(137,37,1),locate(124,37,1),locate(131,38,1),locate(131,47,1)))
		var/obj/item/weapon/grenade/smokebomb/SB = new/obj/item/weapon/grenade/smokebomb(T)
		SB.activate()
	sleep(40)
	for(var/turf/floor/plating/ironsand/SF in world)
		for(var/mob/living/human/H in SF)
			var/turf/newloc = pick(paradrop_landmarks)
			H.x = newloc.x
			H.y = newloc.y
			H.z = newloc.z
			var/image/I = image('icons/effects/parachute.dmi', H, layer = MOB_LAYER + 1.0)
			I.pixel_x = -16
			I.pixel_y = 16

			H.overlays += I
			playsound(get_turf(H), 'sound/effects/bamf.ogg', 20)
			shake_camera(H, 2)
			spawn (60)
				H.overlays -= I
				qdel(I)

		for(var/obj/O in SF)
			var/turf/newloc = pick(paradrop_landmarks)
			O.x = newloc.x
			O.y = newloc.y
			O.z = newloc.z


///////////////////////////////////////////////////////////////////////
/obj/map_metadata/campaign/campaign7
	victory_time = 24000
	grace_wall_timer = 6000
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/sea)
	mission_start_message = "<font size=4><b>10 minutes</b> until the battle begins.</font>"
	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/japanese/land,
		list(PIRATES) = /area/caribbean/british/land,
		)
/obj/map_metadata/campaign/campaign7/job_enabled_specialcheck(var/datum/job/J)
	if (istype(J, /datum/job/civilian))
		if (J.is_event && findtext(J.title, "BNF"))
			. = TRUE
		else
			. = FALSE
	else if (istype(J, /datum/job/pirates))
		if (J.is_event && findtext(J.title, "IRN"))
			. = TRUE
		else
			. = FALSE
	else
		. = FALSE


/obj/map_metadata/campaign/campaign7/update_win_condition()
	if (world.time >= next_win && next_win != -1)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = ""
		if (!map.civilizations)
			message = "The battle has ended in a stalemate!"
		else
			message = "The round has ended!"
		if (current_winner && current_loser)
			message = "The battle is over! The [current_winner] was victorious over the [current_loser][battle_name ? " in the naval engagement at Azula coast!" : ""]!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		win_condition_spam_check = TRUE
		return FALSE
	if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[1][1])] have captured the [roundend_condition_def2name(roundend_condition_sides[2][1])] ship! They will win in {time} minute{s}."
				next_win = world.time + short_win_time(roundend_condition_sides[2][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[1][1])] have captured the [roundend_condition_def2name(roundend_condition_sides[2][1])] ship! They will win in {time} minute{s}."
				next_win = world.time + long_win_time(roundend_condition_sides[2][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[2][1])] have captured the [roundend_condition_def2name(roundend_condition_sides[1][1])] ship! They will win in {time} minute{s}."
				next_win = world.time + short_win_time(roundend_condition_sides[1][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The [roundend_condition_def2army(roundend_condition_sides[2][1])] have captured the [roundend_condition_def2name(roundend_condition_sides[1][1])] ship! They will win in {time} minute{s}."
				next_win = world.time + long_win_time(roundend_condition_sides[1][1])
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The [current_winner] has lost control of the [army2name(current_loser)] ship!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

///////////////////////////////////////////////////////////////////////
/obj/map_metadata/campaign/campaign8
	victory_time = 36000
	grace_wall_timer = 9000
	mission_start_message = "<font size=4><b>15 minutes</b> until the battle begins.</font>"
	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/british,
		list(PIRATES) = /area/caribbean/japanese/land/inside,
		)
obj/map_metadata/campaign/campaign8/job_enabled_specialcheck(var/datum/job/J)
	if (istype(J, /datum/job/civilian))
		if (J.is_event)
			. = TRUE
		else
			. = FALSE
	else if (istype(J, /datum/job/pirates))
		if (J.is_event)
			. = TRUE
		else
			. = FALSE
	else
		. = FALSE
/obj/map_metadata/campaign/campaign8/update_win_condition()

	if (world.time >= victory_time || round_finished)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The <b>Blugoslavians</b> have sucessfuly defended the RADAR station! The Redmenians have retreated!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		win_condition_spam_check = TRUE
		show_global_battle_report(null)
		world << "<b><big>Civilians Killed:</b> <font color='blue'>Blugoslavia</font> [civilians_killed["Blugoslavia"]], <font color='red'>Redmenia</font> [civilians_killed["Redmenia"]]</big>"
		game_log("Civilians Killed: Blugoslavia [civilians_killed["Blugoslavia"]], Redmenia [civilians_killed["Redmenia"]]")
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_cm == FALSE)
		ticker.finished = TRUE
		var/message = "The <b>Redmenians</b> have captured the RADAR station! The battle is over!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		world << "<b><big>Civilians Killed:</b> <font color='blue'>Blugoslavia</font> [civilians_killed["Blugoslavia"]], <font color='red'>Redmenia</font> [civilians_killed["Redmenia"]]</big>"
		game_log("Civilians Killed: Blugoslavia [civilians_killed["Blugoslavia"]], Redmenia [civilians_killed["Redmenia"]]")
		no_loop_cm = TRUE
		return FALSE
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Redmenians</b> have control over the RADAR station! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Redmenians</b> have control over the RADAR station! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Redmenians</b> have control over the RADAR station! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Redmenians</b> have control over the RADAR station! They will win in {time} minutes."
				next_win = world.time + short_win_time(RUSSIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The <b>Blugoslavians</b> have recaptured the eastern side of the river!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE


///////////Map Specific Objects///////////
/obj/structure/altar/heads
	name = "Mr. Taislenko's Collection"
	desc = "To be filled with his requests."
	icon = 'icons/obj/storage.dmi'
	icon_state = "wood_chest"
	flammable = FALSE
	health = 1000000

/obj/structure/altar/heads/attackby(obj/item/W, mob/living/human/user)
	if (istype(map, /obj/map_metadata/campaign/campaign6))
		var/obj/map_metadata/campaign/campaign6/AW = map
		if(istype(W, /obj/item/weapon/book/holybook) || istype(W,/obj/item/clothing/suit/armor/royal) || istype(W,/obj/item/weapon/goldsceptre) || istype(W,/obj/item/clothing/head/helmet/gold_crown_diamond))
			user << "You place the [W] in the chest."
			qdel(W)
			AW.scores["Blugoslavia"] += 1
			user << "Total treasures inside: <b>[AW.scores["Blugoslavia"]]</b>"
			return
	if (istype(W, /obj/item/organ/external/head) && map.ID == MAP_CAMPAIGN)
		var/obj/map_metadata/campaign/AW = map
		if (!AW)
			return
		var/obj/item/organ/external/head/HD = W
		var/head_nationality = HD.nationality
		qdel(W)
		if (!head_nationality)
			return

		user << "You place the head in the chest."
		switch(head_nationality)
			if("Redmenia")
				AW.scores["Redmenia"] += 1
				user << "Total heads inside: <b>[AW.scores["Redmenia"]]</b>"
			if("Blugoslavia")
				AW.scores["Blugoslavia"] += 1
				user << "Total heads inside: <b>[AW.scores["Blugoslavia"]]</b>"
		return

/obj/structure/altar/heads/examine(mob/user, distance)
	. = ..()
	if(ishuman(user) && map && map.ID == MAP_CAMPAIGN && !istype(map, /obj/map_metadata/campaign/campaign6))
		var/mob/living/human/H = user
		var/obj/map_metadata/campaign/AW = map
		switch(H.nationality)
			if("Redmenia")
				user << "Total heads inside: <b>[AW.scores["Redmenia"]]</b>"
			if("Blugoslavia")
				user << "Total heads inside: <b>[AW.scores["Blugoslavia"]]</b>"

/obj/item/weapon/telephone/mobile/campaign
	name = "telephone"
	icon_state = "telephone"
	anchored = TRUE
	update_icon()
		icon_state = "telephone"

/obj/item/weapon/telephone/mobile/campaign/red
	name = "Red Command telephone"
	phonenumber = 1111
	desc = "Used to communicate with the opposite faction. Number is 1111."
	New()
		..()
		phone_numbers += phonenumber
		update_icon()
		contacts += list(list("Blue Command",9999))

/obj/item/weapon/telephone/mobile/campaign/blue
	name = "Blue Command telephone"
	phonenumber = 9999
	desc = "Used to communicate with the opposite faction. Number is 9999."
	icon_state = "telephone_blue"
	update_icon()
		icon_state = "telephone_blue"
	New()
		..()
		phone_numbers += phonenumber
		update_icon()
		contacts += list(list("Red Command",1111))


/obj/item/weapon/telephone/mobile/campaign/attack_self(var/mob/user as mob)
	if (!connected && !ringing)
		var/tgtnum = 0
		if (phonenumber == 9999)
			tgtnum = 1111
		else if (phonenumber == 1111)
			tgtnum = 9999
		else
			return

		ring_phone(tgtnum,phonenumber, src, user)
		spawn(200)
			if (!connected || !origincall)
				user << "<b><font size=2 color=#FFAE19>\icon[getFlatIcon(src)] [src]:</b> </font>Nobody picked up the phone at [tgtnum]."
				return
	else if (connected)
		connected = FALSE
		if (origincall)
			user << "<b><font size=2 color=#FFAE19>\icon[getFlatIcon(src)] [src]:</b> </font>You hang up the phone."
			if (ishuman(origincall.loc))
				origincall.loc << "<b><font size=2 color=#FFAE19>\icon[getFlatIcon(src)] [src]:</b> </font>Someone hangs up the phone."
			else
				origincall.visible_message("<b><font size=2 color=#FFAE19>\icon[getFlatIcon(src)] [src]:</b> </font>Someone hangs up the phone.")
			origincall.connected = FALSE
			origincall.origincall = null
			origincall = null
	else if (ringing && !ringingnum)
		user << "<b><font size=2 color=#FFAE19>\icon[getFlatIcon(src)] [src]:</b> </font>You hang up the phone."
		ringing = FALSE
		if (origincall)
			if (ishuman(origincall.loc))
				origincall.loc << "<b><font size=2 color=#FFAE19>\icon[getFlatIcon(src)] [src]:</b> </font>Someone hangs up the phone."
			else
				origincall.visible_message("<b><font size=2 color=#FFAE19>\icon[getFlatIcon(src)] [src]:</b> </font>Someone hangs up the phone.")
			origincall.origincall = null
			origincall.connected = FALSE
			origincall = null
	else if (ringing && ringingnum)
		ringing = FALSE
		connected = ringingnum
		if (origincall)
			origincall.connected = phonenumber
			origincall.ringing = FALSE
			origincall.origincall = src
			user << "<b><font size=2 color=#FFAE19>\icon[getFlatIcon(src)] [src]:</b> </font>You pick up the phone."
			if (ishuman(origincall.loc))
				origincall.loc << "<b><font size=2 color=#FFAE19>\icon[getFlatIcon(src)] [src]:</b> </font>Someone picks up the phone."
			else
				origincall.visible_message("<b><font size=2 color=#FFAE19>\icon[getFlatIcon(src)] [src]:</b> </font>Someone picks up the phone.")



///////////Aircraft Code///////////

/obj/item/weapon/attachment/scope/adjustable/binoculars/campaign_laser_designator
	name = "laser designator"
	desc = "A laser designator for marking airstrikes. <b>You have some amount of airstrikes left.</b>"
	icon_state = "laser_designator"
	max_zoom = ZOOM_CONSTANT*4
	attachable = FALSE
	value = 15
	w_class = ITEM_SIZE_SMALL
	var/checking = FALSE
	var/debounce = FALSE

/obj/item/weapon/attachment/scope/adjustable/binoculars/campaign_laser_designator/examine(mob/living/human/H)
	..()
	switch (H.faction_text)
		if ("PIRATES") // Redmenia
			desc = "A laser designator for marking airstrikes. <b>You have [airstrikes_remaining_red] airstrikes left.</b>"
			return
		if ("CIVILIAN") // Blugoslavia
			desc = "A laser designator for marking airstrikes. <b>You have [airstrikes_remaining_blue] airstrikes left.</b>"
			return

/obj/item/weapon/attachment/scope/adjustable/binoculars/campaign_laser_designator/proc/rangecheck(var/mob/living/human/H, var/atom/target)
	switch (H.faction_text)
		if ("PIRATES") // Redmenia
			if (!checking && aircraft_red)
				if (airstrikes_remaining_red > 0)
					if (debounce <= world.time)
						checking = TRUE
						var/dist1 = abs(H.x-target.x)
						var/dist2 = abs(H.y-target.y)
						var/distcon = max(dist1,dist2)
						var/gdir = get_dir(H, target)
						H << SPAN_DANGER("<big>You lasing the target, stay still...</big>")
						var/input = WWinput(H, "Strafe in what direction?", "Close Air Support", "Cancel", list("Cancel", "NORTH", "EAST", "SOUTH", "WEST"))
						if (input != "Cancel")
							if (do_after(H, 80, src, can_move = FALSE))
								H << "<big><b><font color='#ADD8E6'>Calling in airstrike: [distcon] meters [dir2text(gdir)].</font></b></big>"
								checking = FALSE

								var/turf/T = locate(target.x,target.y,target.z)
								airstrike(T,H,input)
								debounce = world.time + aircraft_calltime_red
							else
								H << "<big><b><font color='#ADD8E6'>Canceling airstrike.</font></b></big>"
								checking = FALSE
						else
							H << "<big><b><font color='#ADD8E6'>Canceling airstrike.</font></b></big>"
							return
					else
						H << "<big><b><font color='#ADD8E6'>Close Air Support is making their way back around, try again in [(debounce - world.time)/10] seconds.</font></b></big>"
						return
				else
					H << SPAN_DANGER("<big><b>Close Air Support is out of ammunition and returning to base.</big></b>")
					return
		if ("CIVILIAN") // Blugoslavia
			if (!checking && aircraft_blue)
				if (airstrikes_remaining_blue > 0)
					if (debounce <= world.time)
						checking = TRUE
						var/dist1 = abs(H.x-target.x)
						var/dist2 = abs(H.y-target.y)
						var/distcon = max(dist1,dist2)
						var/gdir = get_dir(H, target)
						H << SPAN_DANGER("<big>You lasing the target, stay still...</big>")
						var/input = WWinput(H, "Strafe in what direction?", "Close Air Support", "Cancel", list("Cancel", "NORTH", "EAST", "SOUTH", "WEST"))
						if (input != "Cancel")
							if (do_after(H, 80, src, can_move = FALSE))
								H << "<big><b><font color='#ADD8E6'>Calling in airstrike: [distcon] meters [dir2text(gdir)].</font></b></big>"
								checking = FALSE

								var/turf/T = locate(target.x,target.y,target.z)
								airstrike(T,H,input)
								debounce = world.time + aircraft_calltime_blue
							else
								H << "<big><b><font color='#ADD8E6'>Canceling airstrike.</font></b></big>"
								checking = FALSE
								return
						else
							H << "<big><b><font color='#ADD8E6'>Canceling airstrike.</font></b></big>"
							return
					else
						H << "<big><b><font color='#ADD8E6'>Close Air Support is making their way back around, try again in [(debounce - world.time)/10] seconds.</font></b></big>"
						return
				else
					H << SPAN_DANGER("<big><b>Close Air Support is out of ammunition and returning to base.</big></b>")
					return
		else
			H << SPAN_WARNING("<b>There are no friendly aircraft in the Area of Operations.</b>")
			return

/obj/item/weapon/attachment/scope/adjustable/binoculars/campaign_laser_designator/proc/airstrike(var/turf/T, mob/living/human/user as mob,var/direction)
	message_admins("[user.name] ([user.ckey]) ([user.faction_text]) called in an airstrike with \the [src] at ([T.x],[T.y],[T.z])(<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[T.x];Y=[T.y];Z=[T.z]'>JMP towards</a>)", user.ckey)
	log_game("[user.name] ([user.ckey]) ([user.faction_text]) called in an airstrike with \the [src] at ([T.x],[T.y],[T.z])(<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[T.x];Y=[T.y];Z=[T.z]'>JMP</a>)")

	switch(user.faction_text)
		if ("PIRATES") // Redmenia
			airstrikes_remaining_red--
			new /obj/effect/plane_flyby/f16_no_message(T)
			world << SPAN_DANGER("<font size=4>A Redmenian [aircraft_red] cuts through the air and fires off a burst of rockets!</font>")
		if ("CIVILIAN") // Blugoslavia
			airstrikes_remaining_blue--
			new /obj/effect/plane_flyby/su25_no_message(T)
			world << SPAN_DANGER("<font size=4>A Blugoslavian [aircraft_blue] cuts through the air and fires off a burst of rockets!</font>")
	spawn(15)
		switch(user.faction_text)
			if ("PIRATES") // Redmenia
				var/xoffset = 0
				var/yoffset = 0

				var/direction_xoffset = 0
				var/direction_yoffset = 0
				for (var/i = 1, i <= airstrike_number_red, i++)
					switch (direction)
						if ("NORTH")
							direction_yoffset += 3
							xoffset = rand(-2,2)
							yoffset = rand(0,1)
						if ("EAST")
							direction_xoffset += 3
							xoffset = rand(0,1)
							yoffset = rand(-2,2)
						if ("SOUTH")
							direction_yoffset -= 3
							xoffset = rand(-2,2)
							yoffset = rand(0,1)
						if ("WEST")
							direction_xoffset -= 3
							xoffset = rand(0,1)
							yoffset = rand(-2,2)
					spawn(i*8)
						explosion(locate((T.x + xoffset + direction_xoffset),(T.y + yoffset + direction_yoffset),T.z),0,1,5,3,sound='sound/weapons/Explosives/FragGrenade.ogg')
				spawn (12 SECONDS)
					sam_check("PIRATES")

			if ("CIVILIAN") // Blugoslavia
				var/xoffset = 0
				var/yoffset = 0

				var/direction_xoffset = 0
				var/direction_yoffset = 0
				for (var/i = 1, i <= airstrike_number_blue, i++)
					switch (direction)
						if ("NORTH")
							direction_yoffset += 3
							xoffset = rand(-2,2)
							yoffset = rand(0,1)
						if ("EAST")
							direction_xoffset += 3
							xoffset = rand(0,1)
							yoffset = rand(-2,2)
						if ("SOUTH")
							direction_yoffset -= 3
							xoffset = rand(-2,2)
							yoffset = rand(0,1)
						if ("WEST")
							direction_xoffset -= 3
							xoffset = rand(0,1)
							yoffset = rand(-2,2)
					spawn(i*8)
						explosion(locate((T.x + xoffset + direction_xoffset),(T.y + yoffset + direction_yoffset),T.z),0,1,5,3,sound='sound/weapons/Explosives/FragGrenade.ogg')
				spawn (12 SECONDS)
					sam_check("CIVILIAN")

/obj/item/weapon/attachment/scope/adjustable/binoculars/campaign_laser_designator/proc/sam_check(var/faction)
	switch(faction)
		if ("PIRATES") // Redmenia
			if (prob(0))
				var/sound/uploaded_sound = sound('sound/effects/aircraft/sa6_sam_site.ogg', repeat = FALSE, wait = FALSE, channel = 777)
				uploaded_sound.priority = 250
				aircraft_hit_check("PIRATES")
				for (var/mob/M in player_list)
					if (!new_player_mob_list.Find(M))
						M << SPAN_DANGER("<b>A Blugoslavian SAM site fires at the [aircraft_red]!</b>")
						M.client << uploaded_sound

		if ("CIVILIAN") // Blugoslavia
			if (prob(0))
				var/sound/uploaded_sound = sound('sound/effects/aircraft/sa6_sam_site.ogg', repeat = FALSE, wait = FALSE, channel = 777)
				uploaded_sound.priority = 250
				aircraft_hit_check("CIVILIAN")
				for (var/mob/M in player_list)
					if (!new_player_mob_list.Find(M))
						M << SPAN_DANGER("<b>A Redmenian SAM site fires at the [aircraft_blue]!</b>")
						M.client << uploaded_sound

/obj/item/weapon/attachment/scope/adjustable/binoculars/campaign_laser_designator/proc/aircraft_hit_check(var/faction)
	spawn(4 SECONDS)
		switch(faction)
			if ("PIRATES") // Redmenia
				if (aircraft_red_countermeasures) // Check if the aircraft has countermeasures
					world << SPAN_NOTICE("<font size=2>The [aircraft_red] deploys it's countermeasures!</font>")
					aircraft_red_countermeasures = null
					if (prob(95)) // Evade the SAM
						world << SPAN_NOTICE("<font size=3>The countermeasures have succesfully tricked the SAM!</font>")
						return
					else
						world << SPAN_NOTICE("<font size=3>The countermeasures were ineffective!</font>")

				if (prob(90)) // Shoot down the jet
					var/sound/uploaded_sound = sound((pick('sound/effects/aircraft/effects/metal1.ogg','sound/effects/aircraft/effects/metal2.ogg')), repeat = FALSE, wait = FALSE, channel = 777)
					uploaded_sound.priority = 250
					for (var/mob/M in player_list)
						if (!new_player_mob_list.Find(M))
							M << SPAN_DANGER("<font size=3>The SAM directly hits the [aircraft_red], shooting it down!</font>")
							M.client << uploaded_sound
					aircraft_red = null
					message_admins("Redmenian aircraft [aircraft_red] has been shot down.")
					log_game("Redmenian aircraft [aircraft_red] has been shot down.")
				else // Evade the SAM
					var/sound/uploaded_sound = sound((pick('sound/effects/aircraft/effects/missile1.ogg','sound/effects/aircraft/effects/missile2.ogg')), repeat = FALSE, wait = FALSE, channel = 777)
					uploaded_sound.priority = 250
					for (var/mob/M in player_list)
						if (!new_player_mob_list.Find(M))
							M << SPAN_NOTICE("<font size=3>The SAM misses the [aircraft_red]!</font>")
							M.client << uploaded_sound

			if ("CIVILIAN") // Blugoslavia
				if (aircraft_blue_countermeasures) // Check if the aircraft has countermeasures
					world << SPAN_NOTICE("<font size=3>The [aircraft_blue] deploys it's countermeasures!</font>")
					aircraft_blue_countermeasures = null
					if (prob(95)) // Evade the SAM
						world << SPAN_NOTICE("<font size=3>The countermeasures have succesfully tricked the SAM!</font>")
						return
					else
						world << SPAN_NOTICE("<font size=3>The countermeasures were ineffective!</font>")

				if (prob(90)) // Shoot down the jet
					var/sound/uploaded_sound = sound((pick('sound/effects/aircraft/effects/metal1.ogg','sound/effects/aircraft/effects/metal2.ogg')), repeat = FALSE, wait = FALSE, channel = 777)
					uploaded_sound.priority = 250
					for (var/mob/M in player_list)
						if (!new_player_mob_list.Find(M))
							M << SPAN_DANGER("<font size=3>The SAM directly hits the [aircraft_blue], shooting it down!</font>")
							M.client << uploaded_sound
					aircraft_blue = null
					message_admins("A Blugoslavian aircraft [aircraft_blue] has been shot down.")
					log_game("A Blugoslavian aircraft [aircraft_blue] has been shot down.")
				else // Evade the SAM
					var/sound/uploaded_sound = sound((pick('sound/effects/aircraft/effects/missile1.ogg','sound/effects/aircraft/effects/missile2.ogg')), repeat = FALSE, wait = FALSE, channel = 777)
					uploaded_sound.priority = 250
					for (var/mob/M in player_list)
						if (!new_player_mob_list.Find(M))
							M << SPAN_NOTICE("<font size=3>The SAM misses the [aircraft_blue]!</font>")
							M.client << uploaded_sound
