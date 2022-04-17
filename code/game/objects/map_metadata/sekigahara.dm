/obj/map_metadata/sekigahara
	ID = MAP_SEKIGAHARA
	title = "Sekigahara"
	lobby_icon_state = "medieval"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/one,/area/caribbean/no_mans_land/invisible_wall/two)
	respawn_delay = 300
	no_winner ="The fighting for sekigahara is still going on."
	faction_organization = list(
		JAPANESE,)

	roundend_condition_sides = list(
		list(JAPANESE) = /area/caribbean/colonies/british
		)
	age = "1600"
	ordinal_age = 3
	faction_distribution_coeffs = list(JAPANESE = 1)
	battle_name = "Sekigahara"
	mission_start_message = "<font size=4>The <b>Eastern Army</b> and <b>Western Army</b> are facing each other outside of Sekigahara! It will start in <b>2 minutes</b></font>"
	faction1 = JAPANESE
	songs = list(
		"Tokkutai Bushi (Koji Tsuruta):1" = "sound/music/tokkutai_bushi.ogg",)
	is_singlefaction = TRUE
	scores = list(
		"Eastern Army" = 0,
		"Western Army" = 0,
	)
	New()
		..()
		spawn(600)
			points_check()
/obj/map_metadata/sekigahara/job_enabled_specialcheck(var/datum/job/J)
	..()
	if ((J.is_samurai == TRUE && J.is_western == TRUE) || (J.is_samurai == TRUE && J.is_eastern == TRUE))
		. = TRUE
	else
		. = FALSE
/obj/map_metadata/sekigahara/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 1200 || admin_ended_all_grace_periods)


/obj/map_metadata/sekigahara/proc/points_check()
	world << "<big><b>Current Points:</big></b>"
	world << "<big>Eastern Army: [scores["Eastern Army"]]</big>"
	world << "<big>Western Army: [scores["Western Army"]]</big>"
	spawn(300)
		points_check()

/obj/map_metadata/sekigahara/update_win_condition()

	if (processes.ticker.playtime_elapsed >= 12000 || world.time >= next_win && next_win != -1)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = ""
		message = "The round has ended!"
		if (scores["Western Army"] > scores["Eastern Army"])
			message = "The battle is over! The <b>Western Army</b> were victorious over the <b>Eastern Army</b>!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			win_condition_spam_check = TRUE
			return FALSE
		else if (scores["Eastern Army"] > scores["Western Army"])
			message = "The battle is over! The <b>Eastern Army</b> were victorious over the <b>Western Army</b>!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			win_condition_spam_check = TRUE
			return FALSE
		else
			message = "The battle has ended in a <b>stalemate</b>!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			win_condition_spam_check = TRUE
			return FALSE
		last_win_condition = win_condition.hash
		return TRUE

/obj/map_metadata/sekigahara/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 1200 || admin_ended_all_grace_periods)

/obj/map_metadata/sekigahara/cross_message(faction)
	return "<font size = 4>The grace wall is lifted!</font>"

/obj/map_metadata/sekigahara/reverse_cross_message(faction)
	return ""

/obj/map_metadata/sekigahara/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/one))
			if (H.original_job.is_eastern == TRUE && !H.original_job.is_western == TRUE)
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/two))
			if (H.original_job.is_western == TRUE && !H.original_job.is_eastern == TRUE)
				return TRUE
		else
			return !faction1_can_cross_blocks()
	return FALSE