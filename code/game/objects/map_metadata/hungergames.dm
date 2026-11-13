/obj/map_metadata/hunger_games
	ID = MAP_HUNGERGAMES
	title = "Hunger Games (need staff)"
	lobby_icon = "icons/lobby/battleroyale.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall, /area/caribbean/no_mans_land/invisible_wall/one)
	respawn_delay = 0
	is_singlefaction = TRUE
	battleroyale = TRUE

	no_winner ="The fighting is still going."

	faction_organization = list(PIRATES)

	roundend_condition_sides = list(
		list(PIRATES) = /area/caribbean/british/ship, //it isn't in the map so nobody wins by capture
		)
	age = "2013"
	ordinal_age = 8
	faction_distribution_coeffs = list(PIRATES = 1)
	battle_name = "hunger games"
	mission_start_message = "<font size=4>The Hunger Games will have multiple tributes competing, <b>Last standing tribute wins!</b> <br>You may step off your platforms in <b>3 minutes</b>.</font>"
	var/winner_name = "Unknown"
	var/winner_ckey = "Unknown"
	faction1 = PIRATES
	var/message = ""
	gamemode = "Battleroyale"
	required_players = 12
	grace_wall_timer = 1800
	zone_first_close = 1800
	zone_recheck_delay = 300

/obj/map_metadata/hunger_games/job_enabled_specialcheck(var/datum/job/J)
	if (J.is_event_role == TRUE)
		J.total_positions = 40
		J.min_positions = 40
		J.max_positions = 40
		. = TRUE
	else
		. = FALSE
	return .

/obj/map_metadata/hunger_games/cross_message(faction)
	for (var/obj/item/mine/ap/armed/mine in world)
		qdel(mine)
	if (faction == PIRATES)
		return "<font size = 4><b>The hunger games have started!</b></font>"
	else
		return ""

/obj/map_metadata/hunger_games/update_win_condition()
	if (processes.ticker.playtime_elapsed >= 54000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
		last_win_condition = win_condition.hash
		message = "90 minutes have passed! The hunger games have ended without a winner!"
		to_chat(world, "<font size = 4><span class = 'notice'>[message]</span></font>")
		win_condition_spam_check = TRUE
		return FALSE
	if (processes.ticker.playtime_elapsed >= 1800)
		if (alive_n_of_side(PIRATES) <= 1 && !win_condition_spam_check)
			for (var/mob/living/human/H in player_list)
				if (H.original_job && H.stat != DEAD)
					if (H.original_job.base_type_flag() == PIRATES)
						winner_name =  H.name
						winner_ckey = H.ckey
						give_award(winner_ckey,winner_name,1)
						var/warning_sound = sound("sound/effects/siren.ogg", repeat = FALSE, wait = TRUE, channel = 777)
						for (var/mob/M in player_list)
							M.client << warning_sound
						message = "The hunger games are over! <b>[winner_ckey]</b> is the victor!"
						to_chat(world, "<font size = 4 color='yellow'><span class = 'notice'>[message]</span></font>")
						win_condition_spam_check = TRUE
			ticker.finished = TRUE
			next_win = -1
			current_win_condition = no_winner
			win_condition.hash = 0
			last_win_condition = win_condition.hash
			return FALSE

/obj/map_metadata/hunger_games/save_awards()
	var/F = file("SQL/awards_br.txt")
	if (!awards.len || awards.len <= 12)
		return
	for (var/i = 1, i <= awards.len, i++)
		if (awards[i][1]!="")
			awards[i][6] =  awards.len
			var/txtexport = list2text(awards[i])
			text2file(txtexport,F)
			var/place2text = ""
			if(awards[i][3] == 1)
				place2text = "1st"
			else if(awards[i][3] == 2)
				place2text = "2nd"
			else if(awards[i][3] == 3)
				place2text = "3rd"
			else if(awards[i][3] == 4)
				place2text = "4th"
			else if(awards[i][3] == 5)
				place2text = "5th"
			else
				place2text = "[awards[i][3]]th"
			to_chat(world, "[awards[i][2]] ([awards[i][1]]) placed <b>[place2text]</b>!")
	return TRUE

/obj/map_metadata/hunger_games/give_award(var/_ckey, var/charname, var/place)
	awards += list(list(_ckey,charname,place,time2text(world.realtime, "YYYY/MM/DD"),src.title))
	return