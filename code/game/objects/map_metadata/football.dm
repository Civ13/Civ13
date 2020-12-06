/obj/map_metadata/football
	ID = MAP_FOOTBALL
	title = "Football Match"
	lobby_icon_state = "futebol"
	caribbean_blocking_area_types = list(/area/caribbean/football/midfield, /area/caribbean/football/nopass)
	respawn_delay = 0
	no_winner ="The game is still going on."
	faction_organization = list(
		CIVILIAN,)

	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/colonies/british
		)
	age = "2020"
	ordinal_age = 8
	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = "football game"
	mission_start_message = "Two minutes untill the game starts!"
	ambience = list('sound/ambience/football.ogg')
	faction1 = CIVILIAN
	songs = list(
		"Forever Blowing Bubbles:1" = 'sound/music/forever_blowing_bubbles.ogg',)
	is_singlefaction = TRUE
	var/team1 = "Unga Utd."
	var/team2 = "Chad Town F.C."
	var/team1_kit = "main uniform"
	var/team2_kit = "main uniform"
	var/list/teams = list(
						//name, score, shorts color, short stripes color, shirt color, shirt sleeves color, shirt collar color, shirt v stripes, shirt h stripes
		"Chad Town F.C." = list("Chad Town F.C.",0,"main uniform" = list("shorts_color" = "#EBEBEA","shirt_color"="#84A2CE","shirt_sides_color"="#CDE4FB"),"secondary uniform" = list("shorts_color"="#84a2ce","shirt_color"="#EBEBEA","shirt_sides_color"="#84a2ce"),"goalkeeper uniform" = list("shorts_color"="#84a2ce","shirt_color"="#333333","shirt_sides_color"="#84a2ce")),
		"Unga Utd." = list("Unga Utd.",0,"main uniform" = list("shorts_color" = "#262626","shirt_color"="#AE001A","shirt_sleeves_color"="#BB9634"),"secondary uniform" = list("shorts_color"="#bb9634","shirt_color"="#ffffff","shirt_sleeves_color"="#ae001a","shirt_sides_color"="#bb9634"),"goalkeeper uniform" = list("shorts_color"="#ae001a","shirt_color"="#bb9634","shirt_sides_color"="#ae001a")),
	)

	var/list/scorers = list()
	
	var/stopped = FALSE
	var/list/player_count_red = list(1,2,3,4,5,6,7,8,9,10,11)
	var/list/player_count_blue = list(1,2,3,4,5,6,7,8,9,10,11)
	New()
		..()
		load_teams()
		spawn(600)
			points_check()
			for (var/obj/structure/banner/faction/team/team1/T1 in world)
				T1.team = team1
				T1.assign_team(team1)
			for (var/obj/structure/banner/faction/team/team2/T2 in world)
				T2.team = team2
				T2.assign_team(team2)

/obj/map_metadata/football/proc/assign_teams(client/triggerer = null)
	load_teams()
	var/list/teamlist = list()
	for (var/i in teams)
		teamlist += teams[i][1]
	if (triggerer)
		var/t_team1 = WWinput(triggerer, "Team Selection", "Select team 1:", teamlist[1], teamlist)
		var/t_team1_k = WWinput(triggerer, "Team Selection", "Which kit shall team 1 use?", "Main", list("Main","Secondary"))
		if (t_team1_k == "Main")
			team1_kit = "main uniform"
		else
			team1_kit = "secondary uniform"

		var/t_team2 = WWinput(triggerer, "Team Selection", "Select team 2:", teamlist[2], teamlist)
		var/t_team2_k = WWinput(triggerer, "Team Selection", "Which kit shall team 2 use?", "Main", list("Main","Secondary"))
		if (t_team2_k == "Main")
			team2_kit = "main uniform"
		else
			team2_kit = "secondary uniform"
		team1 = t_team1
		team2 = t_team2
		world << "<font size=4>This match will be between [team1] and [team2]!</font>"
		for (var/obj/structure/banner/faction/team/team1/T1 in world)
			T1.team = team1
			T1.assign_team(team1)
		for (var/obj/structure/banner/faction/team/team2/T2 in world)
			T2.team = team2
			T2.assign_team(team2)
	spawn(2)
		for (var/datum/job/job in job_master.faction_organized_occupations)
			if (istype(job, /datum/job/civilian/football_red/goalkeeper))
				job.title = "[teams[team1][1]] goalkeeper"
				job.selection_color = teams[team1][team1_kit]["shirt_color"]

			else if (istype(job, /datum/job/civilian/football_red))
				job.title = teams[team1][1]
				job.selection_color = teams[team1][team1_kit]["shirt_color"]

			else if (istype(job, /datum/job/civilian/football_blue/goalkeeper))
				job.title = "[teams[team2][1]] goalkeeper"
				job.selection_color = teams[team2][team2_kit]["shirt_color"]

			else if (istype(job, /datum/job/civilian/football_blue))
				job.title = teams[team2][1]
				job.selection_color = teams[team2][team2_kit]["shirt_color"]
		for (var/obj/effect/step_trigger/goal/red/GR in world)
			GR.assign()
		for (var/obj/effect/step_trigger/goal/blue/GB in world)
			GB.assign()	
/obj/map_metadata/football/proc/save_teams()
	var/F = file("SQL/sports_teams.txt")
	if (fexists(F))
		fdel(F)
	for (var/i in teams)
		var/txtexport = "[teams[i]["name"]]|||[list2params(teams[i]["main_uniform"])]===[list2params(teams[i]["secondary_uniform"])]===[list2params(teams[i]["goalkeeper_uniform"])]"
		text2file(txtexport,F)
	return
/obj/map_metadata/football/proc/load_teams()
	var/F = file("SQL/sports_teams.txt")
	var/list/teamlist = list()
	if (fexists(F))
		teams = list()
		var/list/temp_stats1 = file2list(F,"\n")
		for (var/i = 1, i <= temp_stats1.len, i++)
			if (findtext(temp_stats1[i], "|||"))
				var/list/temp_stats2 = splittext(temp_stats1[i], "|||")
				var/list/temp_stats3 = splittext(temp_stats2[2], "===")
				var/list/main_uni = params2list(temp_stats3[1])
				var/list/sec_uni = params2list(temp_stats3[2])
				var/list/gk_uni = params2list(temp_stats3[3])

				teams += list(temp_stats2[1] = list(temp_stats2[1],0,"main uniform" = main_uni,"secondary uniform" = sec_uni,"goalkeeper uniform" = gk_uni))
				teamlist += temp_stats2[1]
				world.log << "Finished loading teams."
	return
/obj/map_metadata/football/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_football == TRUE)
		. = TRUE
	else
		. = FALSE
/obj/map_metadata/football/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 1200 || admin_ended_all_grace_periods)


/obj/map_metadata/football/proc/points_check()
	world << "<font size=4 color='yellow'><b>Current Score:</font></b>"
	world << "<font size=3 color=[teams[team1][team1_kit]["shirt_color"]]><b>[teams[team1][1]]</font><font size=3 color='#FFF'> [teams[team1][2]] - [teams[team2][2]] </font><font size=3 color=[teams[team2][team2_kit]["shirt_color"]]>[teams[team2][1]]</b></font>"
	spawn(300)
		points_check()

/obj/map_metadata/football/proc/scorers_check()
	if (scorers.len)
		var/list/tmplistc = sortTim(scorers, /proc/cmp_numeric_dsc,TRUE)
		for (var/i in tmplistc)
			if (tmplistc[i]>1)
				world << "<font size=3>[i]: <b>[tmplistc[i]]</b> goals</font>"
			else
				world << "<font size=3>[i]: <b>[tmplistc[i]]</b> goal</font>"
/obj/map_metadata/football/update_win_condition()
	if (!win_condition_specialcheck())
		return FALSE
	if (processes.ticker.playtime_elapsed >= 13200 || world.time >= next_win && next_win != -1)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = ""
		message = "The round has ended!"
		if (teams[team1][2] > teams[team2][2])
			message = "<b>[team1]</b> have won the match!"
			world << "<font size=4 color=[teams[team1][team1_kit]["shirt_color"]]>[message]</font>"
			win_condition_spam_check = TRUE
			points_check()
			scorers_check()
			return FALSE

		else if (teams[team2][2] > teams[team1][2])
			message = "<b>[team2]</b> have won the match!"
			world << "<font size=4 color=[teams[team2][team2_kit]["shirt_color"]]>[message]</font>"
			win_condition_spam_check = TRUE
			points_check()
			scorers_check()
			return FALSE
		else
			message = "The match ended in a draw!"
			world << "<font size=4>[message]</font>"
			win_condition_spam_check = TRUE
			points_check()
			scorers_check()
			return FALSE
		last_win_condition = win_condition.hash
		return TRUE

/obj/map_metadata/football/faction1_can_cross_blocks()
	return ((processes.ticker.playtime_elapsed >= 1200 || admin_ended_all_grace_periods) && !stopped)

/obj/map_metadata/football/cross_message(faction)
	var/warning_sound = sound('sound/effects/football_whistle.ogg', repeat = FALSE, wait = TRUE, channel = 777)
	for (var/mob/M in player_list)
		M.client << warning_sound
	return "<font size=4>The match has started!</font>"

/obj/map_metadata/football/reverse_cross_message(faction)
	return ""

/obj/map_metadata/football/proc/reset_ball()
	stopped = TRUE
	for (var/mob/living/human/H in player_list)
		var/turf/spawnpoint = null
		var/list/turfs = latejoin_turfs[H.original_job.spawn_location]
		spawnpoint = pick(turfs)
		H.loc = spawnpoint
	for (var/obj/item/football/FB in world)
		var/turf/spawnpoint = null
		var/list/turfs = latejoin_turfs["football"]
		spawnpoint = pick(turfs)
		if (FB.owner)
			FB.owner.football = null
			FB.last_owner = FB.owner
			FB.owner = null
		FB.loc = spawnpoint
	spawn(200)
		stopped = FALSE

///////////////////////////////////////////////////
/mob/living/human/var/team = null
/datum/job/civilian/football_red
	title = "Unga Bunga United"
	en_meaning = ""
	rank_abbreviation = ""
	spawn_location = "JoinLateCivA"
	min_positions = 10
	max_positions = 10
	is_football = TRUE
	selection_color = "#AE001A"

/datum/job/civilian/football_red/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	if (map && istype(map, /obj/map_metadata/football))
		var/obj/map_metadata/football/FM = map
		H.team = FM.team1
		H.civilization = FM.team1
		var/obj/item/clothing/under/football/custom/FR = new /obj/item/clothing/under/football/custom(H)
		H.equip_to_slot_or_del(FR, slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/football(H), slot_shoes)
		FR.assign_style(FM.teams[FM.team1][1],FM.teams[FM.team1][FM.team1_kit]["shorts_color"],FM.teams[FM.team1][FM.team1_kit]["shirt_color"],FM.teams[FM.team1][FM.team1_kit]["shorts_sides_color"],FM.teams[FM.team1][FM.team1_kit]["shirt_sleeves_color"],FM.teams[FM.team1][FM.team1_kit]["shirt_sides_color"],FM.teams[FM.team1][FM.team1_kit]["shirt_vstripes_color"],FM.teams[FM.team1][FM.team1_kit]["shirt_hstripes_color"],0)
		if (!isemptylist(FM.player_count_red))
			FR.player_number = pick(FM.player_count_red)
			FR.update_icon()
	..()
	return TRUE

/datum/job/civilian/football_red/goalkeeper
	title = "Unga Bunga United Goalkeeper"
	en_meaning = ""
	rank_abbreviation = ""
	spawn_location = "JoinLateCivA"
	min_positions = 1
	max_positions = 1
	is_football = TRUE
	selection_color = "#AE001A"

/datum/job/civilian/football_red/goalkeeper/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	if (map && istype(map, /obj/map_metadata/football))
		var/obj/map_metadata/football/FM = map
		H.team = FM.team1
		H.civilization = FM.team1
		var/obj/item/clothing/under/football/custom/FR = new /obj/item/clothing/under/football/custom(H)
		H.equip_to_slot_or_del(FR, slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/football(H), slot_shoes)
		var/obj/item/clothing/gloves/goalkeeper/red/RG = new/obj/item/clothing/gloves/goalkeeper/red(H)
		RG.color = FM.teams[FM.team1]["goalkeeper uniform"]["shorts_color"]
		H.equip_to_slot_or_del(RG, slot_gloves)
		FR.assign_style(FM.teams[FM.team1][1],FM.teams[FM.team1]["goalkeeper uniform"]["shorts_color"],FM.teams[FM.team1]["goalkeeper uniform"]["shirt_color"],FM.teams[FM.team1]["goalkeeper uniform"]["shorts_sides_color"],FM.teams[FM.team1]["goalkeeper uniform"]["shirt_sleeves_color"],FM.teams[FM.team1]["goalkeeper uniform"]["shirt_sides_color"],FM.teams[FM.team1]["goalkeeper uniform"]["shirt_vstripes_color"],FM.teams[FM.team1]["goalkeeper uniform"]["shirt_hstripes_color"],0)
		if (!isemptylist(FM.player_count_red))
			FR.player_number = pick(FM.player_count_red)
			FR.update_icon()
	..()
	return TRUE


/datum/job/civilian/football_blue
	title = "Chad Town Football Club"
	en_meaning = ""
	rank_abbreviation = ""
	spawn_location = "JoinLateCivB"
	min_positions = 10
	max_positions = 10
	is_football = TRUE
	selection_color = "#6f8bb6"


/datum/job/civilian/football_blue/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	if (map && istype(map, /obj/map_metadata/football))
		var/obj/map_metadata/football/FM = map
		H.team = FM.team2
		H.civilization = FM.team2
		var/obj/item/clothing/under/football/custom/FB = new /obj/item/clothing/under/football/custom(H)
		H.equip_to_slot_or_del(FB, slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/football(H), slot_shoes)
		FB.assign_style(FM.teams[FM.team2][1],FM.teams[FM.team2][FM.team2_kit]["shorts_color"],FM.teams[FM.team2][FM.team2_kit]["shirt_color"],FM.teams[FM.team2][FM.team2_kit]["shorts_sides_color"],FM.teams[FM.team2][FM.team2_kit]["shirt_sleeves_color"],FM.teams[FM.team2][FM.team2_kit]["shirt_sides_color"],FM.teams[FM.team2][FM.team2_kit]["shirt_vstripes_color"],FM.teams[FM.team2][FM.team2_kit]["shirt_hstripes_color"],0)
		if (!isemptylist(FM.player_count_blue))
			FB.player_number = pick(FM.player_count_blue)
			FB.update_icon()

	..()
	return TRUE

/datum/job/civilian/football_blue/goalkeeper
	title = "Chad Town Football Club Goalkeeper"
	en_meaning = ""
	rank_abbreviation = ""
	spawn_location = "JoinLateCivB"
	min_positions = 1
	max_positions = 1
	is_football = TRUE
	selection_color = "#6f8bb6"


/datum/job/civilian/football_blue/goalkeeper/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	if (map && istype(map, /obj/map_metadata/football))
		var/obj/map_metadata/football/FM = map
		H.team = FM.team2
		H.civilization = FM.team2
		var/obj/item/clothing/under/football/custom/FB = new /obj/item/clothing/under/football/custom(H)
		H.equip_to_slot_or_del(FB, slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/football(H), slot_shoes)
		var/obj/item/clothing/gloves/goalkeeper/blue/BG = new/obj/item/clothing/gloves/goalkeeper/blue(H)
		BG.color = FM.teams[FM.team2]["goalkeeper uniform"]["shorts_color"]
		H.equip_to_slot_or_del(BG, slot_gloves)
		FB.assign_style(FM.teams[FM.team2][1],FM.teams[FM.team2]["goalkeeper uniform"]["shorts_color"],FM.teams[FM.team2]["goalkeeper uniform"]["shirt_color"],FM.teams[FM.team2]["goalkeeper uniform"]["shorts_sides_color"],FM.teams[FM.team2]["goalkeeper uniform"]["shirt_sleeves_color"],FM.teams[FM.team2]["goalkeeper uniform"]["shirt_sides_color"],FM.teams[FM.team2]["goalkeeper uniform"]["shirt_vstripes_color"],FM.teams[FM.team2]["goalkeeper uniform"]["shirt_hstripes_color"],0)
		if (!isemptylist(FM.player_count_blue))
			FB.player_number = pick(FM.player_count_blue)
			FB.update_icon()

	..()
	return TRUE