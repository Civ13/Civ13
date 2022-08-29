/obj/map_metadata/bank_robbery
	ID = MAP_BANK_ROBBERY
	title = "The Goldstein Bank Heist"
	lobby_icon = "icons/lobby/taotd.png"
	no_winner ="The robbery is still underway."
	caribbean_blocking_area_types = list(
		/area/caribbean/no_mans_land/invisible_wall,
		/area/caribbean/no_mans_land/invisible_wall/inside)
	respawn_delay = 1200

	faction_organization = list(
		CIVILIAN,
		AMERICAN,)

	
	age = "1996"
	ordinal_age = 7
	faction_distribution_coeffs = list(CIVILIAN = 0.5, AMERICAN = 0.5)
	battle_name = "Goldstein Bank Heist"
	mission_start_message = "<font size=4>The robbers have <b>5 minutes</b> to prepare before the negotiations end!<br>The police will win if they capture the <b>Vault room inside the bank</b>. The Robbers will win if they manage to extract 10.000 from the vault within <b>20 minutes!</b></font>"
	faction1 = CIVILIAN
	faction2 = AMERICAN
	grace_wall_timer = 3000
	gamemode = "Bank Robbery"
	songs = list(
		"Woke Up This Morning:1" = "sound/music/woke_up_this_morning.ogg",)
		
obj/map_metadata/bank_robbery/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_heist == TRUE)
		if (J.title == "Police Officer" || J.title == "Bank Robber" )
			. = TRUE
		else if (J.is_cowboy == TRUE)
			. = FALSE
		else if (J.is_civil_war == TRUE)
			. = FALSE
		else
			. = FALSE
	else
		. = FALSE

/obj/map_metadata/bank_robbery/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 2400 || admin_ended_all_grace_periods)
	
/obj/map_metadata/bank_robbery/cross_message(faction)
	return "<font size = 4>The Police Department has started the raid!</font>"

/obj/map_metadata/bank_robbery/reverse_cross_message(faction)
	return ""

/obj/map_metadata/bank_robbery/update_win_condition()
	if (win_condition_spam_check)
		return FALSE
	for(var/obj/structure/carriage_tdm/C in world)
		if (C.storedvalue >= 10000) // total value stored = 13600+. So roughly 3/4tj
			var/message = "The Robbers have sucessfully stolen over 10.000 dollars! The robbery was successful!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			show_global_battle_report(null)
			win_condition_spam_check = TRUE
			ticker.finished = TRUE
			return TRUE
	if (processes.ticker.playtime_elapsed >= 20000)
		ticker.finished = TRUE
		var/message = "The police department has succesfully aprehended and delivered justice to the robbers!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return TRUE

/obj/map_metadata/bank_robbery/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/one))
			if (H.original_job.is_outlaw == TRUE && !H.original_job.is_law == TRUE)
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/two))
			if (H.original_job.is_law == TRUE && !H.original_job.is_outlaw == TRUE)
				return TRUE
		else
			return !faction1_can_cross_blocks()
	return FALSE