/obj/map_metadata/battleroyale/hunger_games
	ID = MAP_HUNGERGAMES
	title = "Hunger Games (need staff)"
	description = ""
	gamemode_vote = TRUE
	// Zones never close on their own here; staff run the round.
	zone_auto_close = FALSE
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall, /area/caribbean/no_mans_land/invisible_wall/one)
	age = "2013"
	ordinal_age = 8
	battle_name = "hunger games"
	mission_start_message = "<font size=4>The Hunger Games will have multiple tributes competing, <b>Last standing tribute wins!</b> <br>You may step off your platforms in <b>3 minutes</b>.</font>"
	required_players = 12
	grace_wall_timer = 1800
	zone_first_close = 1800
	zone_recheck_delay = 300

/obj/map_metadata/battleroyale/hunger_games/job_enabled_specialcheck(var/datum/job/J)
	if (J.is_event_role == TRUE)
		J.total_positions = 40
		J.min_positions = 40
		J.max_positions = 40
		. = TRUE
	else
		. = FALSE
	return .

/obj/map_metadata/battleroyale/hunger_games/cross_message(faction)
	for (var/obj/item/mine/ap/armed/mine in world)
		qdel(mine)
	if (faction == PIRATES)
		return "<font size = 4><b>The hunger games have started!</b></font>"
	else
		return ""

/obj/map_metadata/battleroyale/hunger_games/update_win_condition()
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
