
/obj/map_metadata/campaign
	ID = MAP_CAMPAIGN
	title = "Campaign"
	lobby_icon_state = "modern"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/temperate)
	respawn_delay = 1800
	no_winner ="The battle is going on."

	faction_organization = list(
		PIRATES,
		CIVILIAN)

	roundend_condition_sides = list(
		list(PIRATES) = /area/caribbean/british/land/outside,
		list(PIRATES) = /area/caribbean/british/land/inside,
		list(CIVILIAN) = /area/caribbean/japanese
		)
	age = "2022"
	ordinal_age = 8
	faction_distribution_coeffs = list(PIRATES = 0.5, CIVILIAN = 0.5)
	battle_name = "R03 road"
	mission_start_message = "<font size=4><b>30 minutes</b> until the battle begins.</font>"
	faction1 = PIRATES
	faction2 = CIVILIAN
	valid_weather_types = list(WEATHER_WET, WEATHER_NONE, WEATHER_EXTREME)
	songs = list(
		"Fortunate Son:1" = 'sound/music/fortunate_son.ogg',)
	artillery_count = 0

	var/list/squad_jobs_blue = list(
		"Squad 1" = list("Corpsman" = 2, "Sniper" = 1, "Machinegunner" = 1),
		"Squad 2" = list("Corpsman" = 2, "Sniper" = 1, "Machinegunner" = 1),
		"Squad 3" = list("Corpsman" = 2, "Sniper" = 1, "Machinegunner" = 1),
		"none" = list("Medic" = 2, "Officer" = 3)
	)
	var/list/squad_jobs_red = list(
		"Squad 1" = list("Corpsman" = 2, "Sniper" = 1, "Machinegunner" = 1),
		"Squad 2" = list("Corpsman" = 2, "Sniper" = 1, "Machinegunner" = 1),
		"Squad 3" = list("Corpsman" = 2, "Sniper" = 1, "Machinegunner" = 1),
		"none" = list("Medic" = 2, "Officer" = 3)
	)
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
	return (processes.ticker.playtime_elapsed >= 18000 || admin_ended_all_grace_periods)

/obj/map_metadata/campaign/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 18000 || admin_ended_all_grace_periods)

/obj/map_metadata/campaign/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/two))
			if (H.faction_text == faction1)
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/one))
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
			if(findtext(job.title, "BAF Squad [job.squad] Squadleader") && MC.faction2_squad_leaders[job.squad])
				continue
			if(findtext(job.title, "BAF Squad [job.squad] Sniper") && MC.squad_jobs_blue["Squad [job.squad]"]["Sniper"]<= 0)
				continue
			if(findtext(job.title, "BAF Squad [job.squad] Machinegunner") && MC.squad_jobs_blue["Squad [job.squad]"]["Machinegunner"]<= 0)
				continue
		else if (factjob == "RDF")
			if(!findtext(job.title, "RDF"))
				continue
			if(findtext(job.title, "RDF Medic") && MC.squad_jobs_red["none"]["Medic"]<= 0)
				continue
			if(findtext(job.title, "RDF Officer") && MC.squad_jobs_red["none"]["Officer"]<= 0)
				continue
			if(findtext(job.title, "RDF Squad [job.squad] Squadleader") && MC.faction1_squad_leaders[job.squad])
				continue
			if(findtext(job.title, "RDF Squad [job.squad] Sniper") && MC.squad_jobs_red["Squad [job.squad]"]["Sniper"]<= 0)
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
				extra_span = "<font size=3>"
				end_extra_span = "</font></b><br><br>"

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
