/obj/map_metadata/battleroyale
	ID = MAP_BATTLEROYALE_IMPERIAL
	title = "Battle Royale: Imperial"
	description = "The map will shrink with time. Only one can survive! Last player standing wins!"
	lobby_icon = "icons/lobby/battleroyale.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall)
	respawn_delay = 0
	is_singlefaction = TRUE
	battleroyale = TRUE
	gamemode_vote = FALSE

	no_winner ="The fighting is still going."

	faction_organization = list(PIRATES)

	roundend_condition_sides = list(
		list(PIRATES) = /area/caribbean/british/ship, //it isn't in the map so nobody wins by capture
		)
	age = "1713"
	ordinal_age = 3
	faction_distribution_coeffs = list(PIRATES = 1)
	battle_name = "Battleroyale at Isla Robusta"
	mission_start_message = "<font size=4>You and several other pirates were abandoned at this forsaken island. Only one can survive! <b>Last player standing wins!</b></font>"
	var/winner_name = "Unknown"
	var/winner_ckey = "Unknown"
	faction1 = PIRATES
	var/message = ""
	gamemode = "Battleroyale"
	required_players = 6
	grace_wall_timer = 1200
	var/zone_auto_close = TRUE

/obj/map_metadata/battleroyale/job_enabled_specialcheck(var/datum/job/J)
	if (J.is_deathmatch && J.is_1713)
		J.total_positions = 32
		J.min_positions = 32
		J.max_positions = 32
		. = TRUE
	else
		. = FALSE
	return .

/obj/map_metadata/battleroyale/cross_message(faction)
	if (faction == PIRATES)
		return "<font size = 4><b>The round has started!</b> Players may now cross the invisible wall!</font>"

/obj/map_metadata/battleroyale/update_win_condition()
	if (processes.ticker.playtime_elapsed >= 30 MINUTES)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		message = "30 minutes have passed! The battle has ended in a draw!"
		to_chat(world, "<font size = 4>[message]</font>")
		win_condition_spam_check = TRUE
		return FALSE
	if (processes.ticker.playtime_elapsed >= 2 MINUTES)
		if (alive_n_of_side(PIRATES) <= 1)
			if (win_condition_spam_check)
				return FALSE
			for (var/mob/living/human/H in player_list)
				if (H.original_job && H.stat != DEAD)
					if (H.original_job.base_type_flag() == PIRATES)
						winner_name =  H.name
						winner_ckey = H.ckey
						give_award(winner_ckey,winner_name,1)
						var/warning_sound = sound("sound/effects/siren_once.ogg", repeat = FALSE, wait = TRUE, channel = 777)
						for (var/mob/M in player_list)
							M.client << warning_sound
						message = "Winner winner chicken dinner!<br><b>[winner_ckey] has won!</b>"
						to_chat(world, "<font size = 4 color='yellow'>[message]</font>")
			ticker.finished = TRUE
			win_condition_spam_check = TRUE
			return FALSE

/obj/map_metadata/battleroyale/New()
	..()
	if (!zone_auto_close)
		return
	spawn(1000)
		closing_areas()

//////////////////SCREEN HELPERS////////////////////////////
/obj/screen/areashow
	maptext = "<center><font color='yellow'>Unknown Area</font></center>"
	maptext_width = 32*8
	maptext_x = (32*8 * -0.5)+32
	maptext_y = 32*0.75
	icon_state = "blank"
	var/currwarning = "yellow"
/obj/screen/areashow/New()
	..()
	var/area/parea = get_area(get_turf(parentmob))
	if (parea)
		maptext = "<center><font color='yellow'><b>[parea.name]</b> ([parentmob.x],[parentmob.y])</font></center>"
	else
		maptext = "<center><font color='yellow'>Unknown Area</font></center>"
	icon_state = "blank"
	spawn(30)
		update()

/obj/screen/areashow/proc/update()
	if (!parentmob || !src)
		return
	var/area/parea = get_area(get_turf(parentmob))
	if (parea)
		maptext = "<center><font color='yellow'><b>[parea.name]</b> ([parentmob.x],[parentmob.y])</font></center>"
		if (parea.name == "[map.ar_to_close_string] Area")
			maptext = "<center><font color='[currwarning]'><b>[parea.name]</b> ([parentmob.x],[parentmob.y]) (CLOSING!)</font></center>"
			if(currwarning == "yellow")
				currwarning = "red"
			else
				currwarning = "yellow"
	else
		maptext = "<center><font color='yellow'>Unknown Area</font></center>"
	spawn(5)
		update()

/obj/screen/areaclosing
	maptext = "<center><font color='green'><b>Closing:</b> None</font></center>"
	maptext_width = 96
	maptext_x = 0
	maptext_y = 32*0.75
	icon_state = "blank"

/obj/screen/areaclosing/New()
	..()
	icon_state = "blank"
	spawn(100)
		update()

/obj/screen/areaclosing/proc/update()
	if (!parentmob || !src)
		return
	if (map && map.ar_to_close_string != "" && map.ar_to_close_string != "None")
		if (map.ar_to_close_timeleft > 0 && (map.ar_to_close_timeleft>30))
			maptext = "<center><font color='green'><b>Closing:</b> [round(map.ar_to_close_timeleft*2)] secs</font></center>"
		else if (map.ar_to_close_timeleft > 0 && (map.ar_to_close_timeleft>15))
			maptext = "<center><font color='yellow'><b>Closing:</b> [round(map.ar_to_close_timeleft*2)] secs</font></center>"
		else if (map.ar_to_close_timeleft > 0)
			maptext = "<center><font color='red'><b>Closing:</b> [round(map.ar_to_close_timeleft*2)] secs</font></center>"
		else
			maptext = "<center><font color='green'><b>Closing:</b> None</font></center>"
	else
		maptext = "<center><font color='green'><b>Closing:</b> None</font></center>"
	spawn(10)
		update()

/obj/screen/playersleft
	maptext = "<center><font color='yellow'>Alive: <b>N/A</b></font></center>"
	maptext_width = 64
	maptext_x = 64
	maptext_y = 32*0.75
	icon_state = "blank"

/obj/screen/playersleft/New()
	..()
	icon_state = "blank"
	spawn(100)
		update()

/obj/screen/playersleft/proc/update()
	if (!parentmob || !src)
		return
	maptext = "<center><font color='yellow'>Alive: <b>[alive_n_of_side(PIRATES)]</b></font></center>"
	spawn(50)
		update()

/obj/map_metadata/battleroyale/two
	ID = MAP_BATTLEROYALE_MODERN
	title = "Battle Royale: Modern"
	lobby_icon = "icons/lobby/battleroyale_arab.png"

	age = "2013"
	ordinal_age = 8
	faction_distribution_coeffs = list(PIRATES = 1)
	battle_name = "Battleroyale at Arab Town"
	mission_start_message = "<font size=4><b>Last player standing wins!</b><br>TWO MINUTES UNTIL THE INVISIBLE WALL DISAPPEARS!</font>"

/obj/map_metadata/battleroyale/two/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/pirates/battleroyale/modern))
		J.total_positions = 32
		J.min_positions = 32
		J.max_positions = 32
		. = TRUE
	else
		. = FALSE
	return .
/obj/map_metadata/battleroyale/three
	ID = MAP_BATTLEROYALE_MEDIEVAL
	title = "Battle Royale: Medieval"

	age = "1013"
	ordinal_age = 2
	faction_distribution_coeffs = list(PIRATES = 1)
	battle_name = "Battleroyale at Camp"
	mission_start_message = "<font size=4><b>Last player standing wins!</b><br>TWO MINUTES UNTIL THE INVISIBLE WALL DISAPPEARS!</font>"

/obj/map_metadata/battleroyale/three/job_enabled_specialcheck(var/datum/job/J)
	if (istype(J, /datum/job/pirates/battleroyale/medieval))
		J.total_positions = 32
		J.min_positions = 32
		J.max_positions = 32
		. = TRUE
	else
		. = FALSE
	return .

/obj/map_metadata/battleroyale/four
	ID = MAP_BATTLEROYALE_WILDWEST
	title = "Battle Royale: Wild West"
	age = "1873"
	ordinal_age = 4
	faction_distribution_coeffs = list(PIRATES = 1)
	battle_name = "Battleroyale at Little Creek"
	mission_start_message = "<font size=4><b>Last player standing wins!</b><br>TWO MINUTES UNTIL THE INVISIBLE WALL DISAPPEARS!</font>"

/obj/map_metadata/battleroyale/four/job_enabled_specialcheck(var/datum/job/J)
	if (istype(J, /datum/job/pirates/battleroyale/wildwest))
		J.total_positions = 32
		J.min_positions = 32
		J.max_positions = 32
		. = TRUE
	else
		. = FALSE
	return .

/obj/map_metadata/battleroyale/save_awards()
	var/F = file("SQL/awards_br.txt")
	if (!awards.len || awards.len <= 12)
		return
	for (var/i = 1, i <= awards.len, i++)
		if (awards[i][1]!="")
			awards[i][6] = awards.len
			var/txtexport = list2text(awards[i])
			text2file(txtexport,F)
			var/place2text = ""
			if(awards[i][3] == 1)
				place2text = "1st"
			else if(awards[i][3] == 2)
				place2text = "2nd"
			else if(awards[i][3] == 3)
				place2text = "3rd"
			else
				place2text = "[awards[i][3]]th"
			to_chat(world, "[awards[i][2]] ([awards[i][1]]) placed <b>[place2text]</b>!")
	return TRUE

/obj/map_metadata/battleroyale/give_award(var/_ckey, var/charname, var/place)
	awards += list(list(_ckey,charname,place,time2text(world.realtime, "YYYY/MM/DD"),src.title))
	return
