
/obj/map_metadata/campaign
	ID = MAP_CAMPAIGN
	title = "Campaign"
	lobby_icon = 'icons/lobby/campaign1.png'
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall, /area/caribbean/no_mans_land/invisible_wall/temperate)
	respawn_delay = 3 MINUTES
	no_winner = "The battle is going on."
	victory_time = 60 MINUTES
	grace_wall_timer = 20 MINUTES
	can_spawn_on_base_capture = TRUE
	faction_organization = list(
		REDFACTION,
		BLUEFACTION)

	roundend_condition_sides = list(
		list(REDFACTION) = /area/caribbean/faction1,
		list(BLUEFACTION) = /area/caribbean/faction2,
		)
	age = "2024"
	ordinal_age = 8
	faction_distribution_coeffs = list(REDFACTION = 0.5, BLUEFACTION = 0.5)
	battle_name = "battle of Emberburg"
	mission_start_message = "<font size=4><b>20 minutes</b> until the battle begins.</font>"
	faction1 = REDFACTION
	faction2 = BLUEFACTION
	valid_weather_types = list(WEATHER_WET, WEATHER_NONE, WEATHER_EXTREME)
	songs = list(
		"Emma:1" = 'sound/music/emma.ogg',)
	artillery_count = 0

	scores = list(
		"Redmenia" = 0,
		"Blugoslavia" = 0,
	)
	var/list/civilians_evacuated = list(
		"Redmenia" = 0,
		"Blugoslavia" = 0,
	)
	var/list/civilians_killed = list(
		"Redmenia" = 0,
		"Blugoslavia" = 0,
		"Unknown" = 0,
	)
	var/list/squad_jobs_red = list(
		"Squad 1" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 2" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 3" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Recon" = list("Sniper" = 4),
		"Armored" = list("Crew" = 8),
		"AT" = list("Anti-Tank" = 3),
		"Engineer" = list("Engineer" = 3),
		"none" = list("Commander" = 1, "Officer" = 3, "Doctor" = 2),
	)
	var/list/squad_jobs_blue = list(
		"Squad 1" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 2" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 3" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Recon" = list("Sniper" = 4),
		"Armored" = list("Crew" = 8),
		"AT" = list("Anti-Tank" = 3),
		"Engineer" = list("Engineer" = 3),
		"none" = list("Commander" = 1, "Officer" = 3, "Doctor" = 2),
	)
	var/list/capturable_equipment = list(
		/obj/structure/cannon/modern,
		/obj/structure/cannon/rocket,
		/obj/structure/cannon/rocket/loaded,
		/obj/structure/cannon/rocket/old,
		/obj/structure/cannon/mortar,
		/obj/structure/cannon/mortar/foldable/generic,
		/obj/item/weapon/gun/projectile/automatic/stationary/pkm,
	)
	var/list/captured_equipment_red = list()
	var/list/captured_equipment_blue = list()
	var/ap_mines_placed = 0
	var/at_mines_placed = 0

/obj/map_metadata/campaign/New()
	..()
	civ_collector()

/obj/map_metadata/campaign/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/redfaction))
		. = TRUE
	else if (istype(J, /datum/job/bluefaction))
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/campaign/cross_message(faction)
	for (var/datum/job/J in job_master.occupations)
		if (istype(J, /datum/job/redfaction))
			J.spawn_location = "JoinLateRed_Reinforcement"
	switch (faction)
		if (REDFACTION)
			to_chat(world, sound('sound/effects/siren_once.ogg', repeat = FALSE, wait = FALSE, volume = 50, channel = 3))
			return "<font size=4 color='red'>The battle has begun!</font>"
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
		return 5 MINUTES

/obj/map_metadata/campaign/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 2 MINUTES
	else
		return 7 MINUTES

/obj/map_metadata/campaign/proc/civ_collector()
	for(var/turf/T in get_area_turfs(/area/caribbean/faction2/collector))
		for (var/mob/living/simple_animal/civilian/CVL in T)
			if(CVL.stat != DEAD)
				if(istype(CVL, /mob/living/simple_animal/civilian/greenistani_ambassador) && CVL.stat != DEAD)
					world << "<font size=4><font color='blue'><b>Blugoslavia</b></font> has sucessfully evacuated the Greenistani Ambassador!</font></font>"
				else
					civilians_evacuated["Blugoslavia"]++
				qdel(CVL)
	for(var/turf/T in get_area_turfs(/area/caribbean/faction1/collector))
		for (var/mob/living/simple_animal/civilian/CVL in T)
			if(CVL.stat != DEAD)
				if(istype(CVL, /mob/living/simple_animal/civilian/greenistani_ambassador))
					world << "<font size=4><font color='red'><b>Redmenia</b></font> has sucessfully evacuated the Greenistani Ambassador!</font></font>"
				else
					civilians_evacuated["Redmenia"]++
				qdel(CVL)	
	spawn(600) // 1 minute
		civ_collector()
	return

//role selector
/mob/new_player/proc/LateChoicesCampaign(factjob)
	var/list/available_jobs_per_side = list(
		BLUEFACTION = FALSE,
		REDFACTION = FALSE,
	)
	var/obj/map_metadata/campaign/MC = map
	src << browse(null, "window=latechoices")

	var/list/dat = list("<center>")
	dat += "<b><big>Welcome, [key].</big></b>"
	dat += "<br>"
	dat += "Round Duration: [roundduration2text_days()]"
	dat += "<br>"
	dat += "<b>Current Autobalance Status</b>: "
	if (BLUEFACTION in map.faction_organization)
		dat += "[alive_bluefaction.len] Blugoslavians "
	if (REDFACTION in map.faction_organization)
		dat += "[alive_redfaction.len] Redmenians "

	dat += "<br>"
	if (istype(map, /obj/map_metadata/nationsrp/coldwar_cmp))
		switch (factjob)
			if ("blue")
				dat +="<b><h1><big>Blugoslavian People</big></h1></b>"
			if ("red")
				dat +="<b><h1><big>Redmenian People</big></h1></b>"
		for (var/datum/job/job in job_master.faction_organized_occupations)
			switch (factjob)
				if ("blue")
					if(!findtext(job.title, "Blugoslavian Civilian"))
						continue
				if ("red")
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
		switch (factjob)
			if ("blue")
				dat +="<b><h1><big>Blugoslavian Armed Forces</big></h1></b>"
			if ("red")
				dat +="<b><h1><big>Redmenia Defense Force</big></h1></b>"
		for (var/datum/job/job in job_master.faction_organized_occupations)
			switch (factjob)
				if ("blue")
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
				if ("red")
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

/obj/item/weapon/key/redfaction
	code = 668643
	name = "Redmenian Key"

/obj/item/weapon/key/bluefaction
	code = 932145
	name = "Blugoslavian Key"

// For a single objective that needs to be captured by both factions
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

// For capturing a base
var/no_loop_ca = FALSE
/obj/map_metadata/campaign/update_win_condition()
	// Win when timer reaches zero
	if (world.time >= victory_time)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = SPAN_RED("The <b>Redmenians</b> are victorious [battle_name ? "in the [battle_name]" : "the battle"]! The Redmenians halted the attack!")
		to_chat(world, SPAN_NOTICE("<font size = 4>[message]</font>"))
		
		after_round_checks()
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_ca == FALSE)
		ticker.finished = TRUE
		var/message = "The [battle_name ? battle_name : "battle"] has ended in a stalemate!"
		if (current_winner && current_loser)
			message = SPAN_BLUE("The <b>Blugoslavians</b> are victorious [battle_name ? "in the [battle_name]" : "the battle"]!")
		to_chat(world, SPAN_NOTICE("<font size = 4>[message]</font>"))

		after_round_checks()
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_ca = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Blugoslavians</b> have captured the objective! They will win in {time} minutes."
				next_win = world.time + short_win_time(BLUEFACTION)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Blugoslavians</b> have captured the objective! They will win in {time} minutes."
				next_win = world.time + short_win_time(BLUEFACTION)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Blugoslavians</b> have captured the objective! They will win in {time} minutes."
				next_win = world.time + short_win_time(BLUEFACTION)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Blugoslavians</b> have captured the objective! They will win in {time} minutes."
				next_win = world.time + short_win_time(BLUEFACTION)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The <b>Redmenians</b> have retaken control over the objective!</font>"
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
	var/sound/uploaded_sound = sound('sound/weapons/Explosives/mrls.ogg', repeat = FALSE, wait = TRUE, channel = 780)
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

/area/caribbean/captured_equipment
	name = "captured equipment zone"
	icon_state = "green1"

/area/caribbean/captured_equipment/faction1
	name = "red captured equipment zone"
	icon_state = "red3"
/area/caribbean/captured_equipment/faction2
	name = "blue captured equipment zone"
	icon_state = "blue3"

/obj/map_metadata/campaign/proc/get_faction1_captured_equipment()
	for(var/obj/I in get_area_all_atoms(/area/caribbean/captured_equipment/faction1))
		if(locate(I) in capturable_equipment)
			captured_equipment_red += I.name
	to_chat(world, "<big><b><font color='red'>Captured equipment Redmenia:</font></b></big>")
	if(captured_equipment_red.len)
		to_chat(world, "<big>[jointext(captured_equipment_red,"\n")]</big>")
	else
		to_chat(world, "<big>No equipment was captured.</big>")

/obj/map_metadata/campaign/proc/get_faction2_captured_equipment()
	for(var/obj/I in get_area_all_atoms(/area/caribbean/captured_equipment/faction2))
		if(locate(I) in capturable_equipment)
			captured_equipment_blue += I.name
	to_chat(world, "<big><b><font color='blue'>Captured equipment Blugoslavia:</font></b></big>")
	if(captured_equipment_blue.len)
		to_chat(world, "<big>[jointext(captured_equipment_blue,"\n")]</big>")
	else
		to_chat(world, "<big>No equipment was captured.</big>")


/obj/map_metadata/campaign/proc/after_round_checks()
	to_chat(world, "Civilians Rescued:</b> <font color='blue'>Blugoslavia</font> [civilians_evacuated["Blugoslavia"]], <font color='red'>Redmenia</font> [civilians_evacuated["Redmenia"]]</big>")
	to_chat(world, "<big><b>Civilians Killed:</b> <font color='blue'>Blugoslavia</font> [civilians_killed["Blugoslavia"]], <font color='red'>Redmenia</font> [civilians_killed["Redmenia"]], <font color='grey'>Unknown</font> [civilians_killed["Unknown"]]</big>")
	spawn(5 SECONDS)
		to_chat(world, "<big><b>AP mines placed: [ap_mines_placed]</b></big>")
		to_chat(world, "<big><b>AT mines placed: [at_mines_placed]</b></big>")
		get_faction1_captured_equipment()
		get_faction2_captured_equipment()

///////////Map Specific Objects///////////
/obj/structure/altar/heads
	name = "Mr. Taislenko's Collection"
	desc = "To be filled with his requests."
	icon = 'icons/obj/storage.dmi'
	icon_state = "wood_chest"
	flammable = FALSE
	health = 1000000

/obj/structure/altar/heads/attackby(obj/item/W, mob/living/human/user)
	if (istype(W, /obj/item/organ/external/head) && map.ID == MAP_CAMPAIGN)
		var/obj/map_metadata/campaign/AW = map
		if (!AW)
			return
		var/obj/item/organ/external/head/HD = W
		var/head_nationality = HD.nationality
		qdel(W)
		if (!head_nationality)
			return

		to_chat(user, SPAN_NOTICE("You place the head in the chest."))
		switch(head_nationality)
			if("Blugoslavia")
				AW.scores["Blugoslavia"] += 1
				user << "Total heads inside: <b>[AW.scores["Blugoslavia"]]</b>"
			if("Redmenia")
				AW.scores["Redmenia"] += 1
				user << "Total heads inside: <b>[AW.scores["Redmenia"]]</b>"
		return

/obj/structure/altar/heads/examine(mob/user, distance)
	. = ..()
	if(ishuman(user) && map && map.ID == MAP_CAMPAIGN)
		var/mob/living/human/H = user
		var/obj/map_metadata/campaign/AW = map
		switch(H.faction_text)
			if(BLUEFACTION)
				to_chat(user, "Total heads inside: <b>[AW.scores["Blugoslavia"]]</b>")
			if(REDFACTION)
				to_chat(user, "Total heads inside: <b>[AW.scores["Redmenia"]]</b>")

/obj/item/weapon/telephone/mobile/campaign
	name = "telephone"
	icon_state = "telephone"
	anchored = TRUE
	update_icon()
		icon_state = "telephone"

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

/obj/item/weapon/telephone/mobile/campaign/red
	name = "Red Command telephone"
	phonenumber = 1111
	desc = "Used to communicate with the opposite faction. Number is 1111."
	New()
		..()
		phone_numbers += phonenumber
		update_icon()
		contacts += list(list("Blue Command",9999))


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
