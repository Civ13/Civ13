
/obj/map_metadata/campaign
	ID = MAP_CAMPAIGN
	title = "Campaign"
	lobby_icon_state = "modern"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/taiga)
	respawn_delay = 1800
	no_winner ="The battle is going on."

	faction_organization = list(
		PIRATES,
		CIVILIAN)

	roundend_condition_sides = list(
		list(PIRATES) = /area/caribbean/british/land/inside/objective,
		list(CIVILIAN) = /area/caribbean/british/land/inside/objective
		)
	age = "2022"
	ordinal_age = 8
	faction_distribution_coeffs = list(PIRATES = 0.5, CIVILIAN = 0.5)
	battle_name = "battle of Rozenia"
	mission_start_message = "<font size=4><b>15 minutes</b> until the battle begins.</font>"
	faction1 = PIRATES
	faction2 = CIVILIAN
	valid_weather_types = list(WEATHER_WET, WEATHER_NONE, WEATHER_EXTREME)
	songs = list(
		"Fortunate Son:1" = 'sound/music/fortunate_son.ogg',)
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
		"Squad 1" = list("Corpsman" = 2, "Machinegunner" = 1, "Des. Marksman" = 2),
		"Squad 2" = list("Corpsman" = 2, "Machinegunner" = 1, "Des. Marksman" = 2),
		"Squad 3" = list("Corpsman" = 2, "Machinegunner" = 1, "Des. Marksman" = 2),
		"Recon" = list("Sniper" = 4),
		"Armored" = list("Crew" = 8),
		"AT" = list("Anti-Tank" = 2),
		"Engineer" = list("Engineer" = 3),
		"none" = list("Medic" = 2, "Officer" = 3, "Commander" = 1)
	)
	var/list/squad_jobs_red = list(
		"Squad 1" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 2" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 3" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Recon" = list("Sniper" = 4),
		"Armored" = list("Crew" = 8),
		"AT" = list("Anti-Tank" = 2),
		"Engineer" = list("Engineer" = 3),
		"none" = list("Medic" = 2, "Officer" = 3, "Commander" = 1)
	)

/obj/map_metadata/campaign/New()
	..()
	civ_collector()

obj/map_metadata/campaign/job_enabled_specialcheck(var/datum/job/J)
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
	return "<font size = 4>All factions may cross the grace wall now!</font>"

/obj/map_metadata/campaign/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 9000 || admin_ended_all_grace_periods)

/obj/map_metadata/campaign/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 9000 || admin_ended_all_grace_periods)

/obj/map_metadata/campaign/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/taiga/two))
			if (H.faction_text == faction1)
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/taiga/one))
			if (H.faction_text == faction2)
				return TRUE
		else
			return !faction1_can_cross_blocks()
	return FALSE

/obj/map_metadata/campaign/short_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 1200
	else
		return 3000 // 5 minutes

/obj/map_metadata/campaign/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 1200
	else
		return 4200 // 7 minutes

/obj/map_metadata/campaign/proc/civ_collector()
	var/ctb = 0
	var/ctr = 0
	for(var/turf/T in get_area_turfs(/area/caribbean/japanese/land))
		for (var/mob/living/simple_animal/civilian/CVL in T)
			if(CVL.stat != DEAD)
				qdel(CVL)
				civilians_evacuated["Blugoslavia"]++
	for(var/turf/T in get_area_turfs(/area/caribbean/pirates/land))
		for (var/mob/living/simple_animal/civilian/CVL in T)
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
			if(findtext(job.title, "BAF Medic") && MC.squad_jobs_blue["none"]["Medic"]<= 0)
				continue
			if(findtext(job.title, "BAF Officer") && MC.squad_jobs_blue["none"]["Officer"]<= 0)
				continue
			if(findtext(job.title, "BAF Commander") && MC.squad_jobs_blue["none"]["Commander"]<= 0)
				continue
			if(findtext(job.title, "BAF Squad [job.squad] Squadleader") && MC.faction2_squad_leaders[job.squad])
				continue
			if(findtext(job.title, "BAF Armored Commander") && MC.faction2_squad_leaders[4])
				continue
			if(findtext(job.title, "BAF Recon") && MC.squad_jobs_blue["Recon"]["Sniper"]<= 0)
				continue
			if(findtext(job.title, "BAF Anti-Tank") && MC.squad_jobs_blue["AT"]["Anti-Tank"]<= 0)
				continue
			if(findtext(job.title, "BAF Engineer") && MC.squad_jobs_blue["Engineer"]["Engineer"]<= 0)
				continue
			if(findtext(job.title, "BAF Squad [job.squad] Machinegunner") && MC.squad_jobs_blue["Squad [job.squad]"]["Machinegunner"]<= 0)
				continue
			if(findtext(job.title, "BAF Squad [job.squad] Des. Marksman") && MC.squad_jobs_blue["Squad [job.squad]"]["Des. Marksman"]<= 0)
				continue
		else if (factjob == "RDF")
			if(!findtext(job.title, "RDF"))
				continue
			if(findtext(job.title, "RDF Medic") && MC.squad_jobs_red["none"]["Medic"]<= 0)
				continue
			if(findtext(job.title, "RDF Officer") && MC.squad_jobs_red["none"]["Officer"]<= 0)
				continue
			if(findtext(job.title, "RDF Commander") && MC.squad_jobs_red["none"]["Commander"]<= 0)
				continue
			if(findtext(job.title, "RDF Squad [job.squad] Squadleader") && MC.faction1_squad_leaders[job.squad])
				continue
			if(findtext(job.title, "RDF Armored Commander") && MC.faction1_squad_leaders[4])
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

/obj/map_metadata/campaign/update_win_condition()
	var/victory_time = 45000
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
			message = "The battle is over! The [current_winner] was victorious over the [current_loser][battle_name ? " in the [battle_name]" : ""]!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		world << "<b><big>Civilians Rescued:</b> <font color='blue'>Blugoslavia</font> [civilians_evacuated["Blugoslavia"]], <font color='red'>Redmenia</font> [civilians_evacuated["Redmenia"]]</big>"
		world << "<b><big>Civilians Killed:</b> <font color='blue'>Blugoslavia</font> [civilians_killed["Blugoslavia"]], <font color='red'>Redmenia</font> [civilians_killed["Redmenia"]]</big>"
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

///////////map specific objs/////////
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
		
		user << "You place the head in the chest."
		switch(head_nationality)
			if("Redmenia")
				AW.scores["Blugoslavia"] += 1
				user << "Total heads inside: <b>[AW.scores["Blugoslavia"]]</b>"
			if("Blugoslavia")
				AW.scores["Redmenia"] += 1
				user << "Total heads inside: <b>[AW.scores["Redmenia"]]</b>"
		return

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
