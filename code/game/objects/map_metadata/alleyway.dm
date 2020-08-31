/obj/map_metadata/alleyway
	ID = MAP_ALLEYWAY
	title = "Alleyway"
	lobby_icon_state = "taotd"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 300
	faction_organization = list(
		JAPANESE,)

	roundend_condition_sides = list(
		list(JAPANESE) = /area/caribbean/colonies/british
		)
	age = "1989"
	ordinal_age = 8
	faction_distribution_coeffs = list(JAPANESE = 1)
	battle_name = "Yama-ichi gang fight"
	mission_start_message = "<font size=4>The <b>Yamaguchi-gumi Clan</b> and <b>Ichiwa-Kai Clan</b> are facing each other the streets of Kobe! It will start in <b>2 minutes</b></font>"
	faction1 = JAPANESE
	songs = list(
		"Woke Up This Morning:1" = 'sound/music/woke_up_this_morning.ogg',)
	is_singlefaction = TRUE
	scores = list(
		"Yamaguchi-gumi" = 0,
		"Ichiwa-kai" = 0,
	)

/obj/map_metadata/alleyway/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_yakuza == TRUE)
		. = TRUE
	else
		. = FALSE
/obj/map_metadata/fields/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 1200 || admin_ended_all_grace_periods)


/obj/map_metadata/alleyway/proc/points_check()
	world << "<big><b>Current Points:</big></b>"
	world << "<big>Yamaguchi-gumi: [scores["yamaguchi-gumi"]]</big>"
	world << "<big>Ichiwa-kai: [scores["Ichiwa-kai"]]</big>"
	spawn(300)
		points_check()

/obj/map_metadata/stalingrad/update_win_condition()
	if (processes.ticker.playtime_elapsed > 6000)
		if (sov_points < 40 && ger_points < 40)
			return TRUE
		if (sov_points >= 40 && sov_points > ger_points)
			if (win_condition_spam_check)
				return FALSE
			ticker.finished = TRUE
			var/message = "The <b>Soviets</b> have reached [sov_points] points and won!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			show_global_battle_report(null)
			win_condition_spam_check = TRUE
			return FALSE
		if (ger_points >= 40 && ger_points > sov_points)
			if (win_condition_spam_check)
				return FALSE
			ticker.finished = TRUE
			var/message = "The <b>Germans</b> have reached [ger_points] points and won!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			show_global_battle_report(null)
			win_condition_spam_check = TRUE
			return FALSE
	return TRUE