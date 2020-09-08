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
	var/team1 = "U.B.U."
	var/team2 = "C.T.F.C."
	var/list/teams = list(
						//name, score, shorts color, short stripes color, shirt color, shirt sleeves color, shirt collar color, shirt v stripes, shirt h stripes
		"U.B.U." = list("U.B.U.",0,"#262626",null,"#AE001A","#BB9634",null,null,null),
		"C.T.F.C." = list("C.T.F.C.",0,"#EBEBEA",null,"#84A2CE",null,"#CDE4FB",null,null),
	)

	var/list/scorers = list()
	
	var/stopped = FALSE
	var/list/player_count_red = list(1,2,3,4,5,6,7,8,9,10,11)
	var/list/player_count_blue = list(1,2,3,4,5,6,7,8,9,10,11)
	New()
		..()
		spawn(600)
			points_check()
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
	world << "<font size=3 color=[teams[team1][5]]><b>[teams[team1][1]]</font><font size=3 color='#FFF'> [teams[team1][2]] - [teams[team2][2]] </font><font size=3 color=[teams[team2][5]]>[teams[team2][1]]</b></font>"
	spawn(300)
		points_check()

/obj/map_metadata/football/proc/scorers_check()
	if (scorers.len)
		var/list/tmplistc = sortTim(scorers, /proc/cmp_numeric_dsc,TRUE)
		for (var/i in tmplistc)
			if ([tmplistc[i]]>1)
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
			world << "<font size=4 color=[teams[team1][5]]>[message]</font>"
			win_condition_spam_check = TRUE
			points_check()
			scorers_check()
			return FALSE

		else if (teams[team2][2] > teams[team1][2])
			message = "<b>[team2]</b> have won the match!"
			world << "<font size=4 color=[teams[team2][5]]>[message]</font>"
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
	H.civilization = "Unga Bunga United"
	if (map && istype(map, /obj/map_metadata/football))
		var/obj/map_metadata/football/FM = map
		H.team = FM.team1
	var/obj/item/clothing/under/football/red/FR = new /obj/item/clothing/under/football/red(H)
	H.equip_to_slot_or_del(FR, slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/football(H), slot_shoes)
	if (map && map.ID == MAP_FOOTBALL)
		var/obj/map_metadata/football/tmap = map
		if (!isemptylist(tmap.player_count_red))
			FR.player_number = pick(tmap.player_count_red)
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
	H.civilization = "Unga Bunga United"
	if (map && istype(map, /obj/map_metadata/football))
		var/obj/map_metadata/football/FM = map
		H.team = FM.team1
	var/obj/item/clothing/under/football/red/goalkeeper/FR = new /obj/item/clothing/under/football/red/goalkeeper(H)
	H.equip_to_slot_or_del(FR, slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/football(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/goalkeeper/red(H), slot_gloves)
	if (map && map.ID == MAP_FOOTBALL)
		var/obj/map_metadata/football/tmap = map
		if (!isemptylist(tmap.player_count_red))
			FR.player_number = pick(tmap.player_count_red)
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
	H.civilization = "Chad Town Football Club"
	if (map && istype(map, /obj/map_metadata/football))
		var/obj/map_metadata/football/FM = map
		H.team = FM.team2
	var/obj/item/clothing/under/football/blue/FB = new /obj/item/clothing/under/football/blue(H)
	H.equip_to_slot_or_del(FB, slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/football(H), slot_shoes)
	if (map && map.ID == MAP_FOOTBALL)
		var/obj/map_metadata/football/tmap = map
		if (!isemptylist(tmap.player_count_blue))
			FB.player_number = pick(tmap.player_count_blue)
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
	H.civilization = "Chad Town Football Club"
	if (map && istype(map, /obj/map_metadata/football))
		var/obj/map_metadata/football/FM = map
		H.team = FM.team2
	var/obj/item/clothing/under/football/blue/goalkeeper/FB = new /obj/item/clothing/under/football/blue/goalkeeper(H)
	H.equip_to_slot_or_del(FB, slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/football(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/goalkeeper/blue(H), slot_gloves)
	if (map && map.ID == MAP_FOOTBALL)
		var/obj/map_metadata/football/tmap = map
		if (!isemptylist(tmap.player_count_blue))
			FB.player_number = pick(tmap.player_count_blue)
			FB.update_icon()

	..()
	return TRUE