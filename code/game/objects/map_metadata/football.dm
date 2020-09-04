/obj/map_metadata/football
	ID = MAP_FOOTBALL
	title = "Football Match"
	lobby_icon_state = "taotd"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
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
	faction1 = CIVILIAN
	songs = list(
		"Woke Up This Morning:1" = 'sound/music/woke_up_this_morning.ogg',)
	is_singlefaction = TRUE
	scores = list(
		"U.B.U." = 0,
		"C.T.F.C." = 0,
	)
	New()
		..()
		spawn(600)
			points_check()
/obj/map_metadata/football/job_enabled_specialcheck(var/datum/job/J)
	..()
	if ((J.is_football == TRUE)
		. = TRUE
	else
		. = FALSE
/obj/map_metadata/football/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 1200 || admin_ended_all_grace_periods)


/obj/map_metadata/football/proc/points_check()
	world << "<font size=4 color='yellow'><b>Current Score:</font></b>"
	world << "<font size=3 color='#AE001A'><b>UBU [scores["U.B.U."]]</font><font size=3 color='#FFF'> - </font><font size=3 color='#84A2CE'[scores["C.T.F.C."]] CTFC</b></font>"
	spawn(300)
		points_check()

/obj/map_metadata/football/update_win_condition()
	if (!win_condition_specialcheck())
		return FALSE
	if (processes.ticker.playtime_elapsed >= 13200 || world.time >= next_win && next_win != -1)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = ""
		message = "The round has ended!"
		if (scores["U.B.U."] > scores["C.T.F.C."])
			message = "<b>Unga Bunga United</b> have won the match!"
			world << "<font size = 4 color='#AE001A'><span class = 'notice'>[message]</span></font>"
			win_condition_spam_check = TRUE
            points_check()
			return FALSE
		else if (scores["C.T.F.C."] > scores["U.B.U."])
			message = "<b>Chad Town Football Club</b> have won the match!"
			world << "<font size = 4 color='#84A2CE'><span class = 'notice'>[message]</span></font>"
			win_condition_spam_check = TRUE
            points_check()
			return FALSE
		else
			message = "The match ended in a draw!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			win_condition_spam_check = TRUE
            points_check()
			return FALSE
		last_win_condition = win_condition.hash
		return TRUE

/obj/map_metadata/football/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 1200 || admin_ended_all_grace_periods)

/obj/map_metadata/football/cross_message(faction)
	return "<font size = 4>The match has started!</font>"

/obj/map_metadata/football/reverse_cross_message(faction)
	return ""

///////////////////////////////////////////////////
/datum/job/civilian/football_red
	title = "Unga Bunga United"
	en_meaning = ""
	rank_abbreviation = ""
	spawn_location = "JoinLateCivA"
	min_positions = 10
	max_positions = 10
	is_football = TRUE

/datum/job/civilian/football_blue
	title = "Chad Town Football Club"
	en_meaning = ""
	rank_abbreviation = ""
	spawn_location = "JoinLateCivB"
	min_positions = 10
	max_positions = 10
	is_football = TRUE