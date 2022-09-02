/obj/map_metadata/drug_bust
	ID = MAP_DRUG_BUST
	title = "The Rednikov Drug Bust"
	lobby_icon = "icons/lobby/bank_robbery.png"
	no_winner ="The drug bust is still underway."
	caribbean_blocking_area_types = list(
		/area/caribbean/no_mans_land/invisible_wall,
		/area/caribbean/no_mans_land/invisible_wall/inside)
	respawn_delay = 0

	faction_organization = list(
		CIVILIAN,
		AMERICAN,)
	

	age = "1996"
	ordinal_age = 7
	faction_distribution_coeffs = list(CIVILIAN = 0.65, AMERICAN = 0.35)
	battle_name = "Rednikov Drug Bust"
	mission_start_message = "<font size=4>The Russians have <b>5 minutes</b> to prepare SWAT raid the building!<br>The police will win if they <b>confiscate 20 stacks of cocaine!</b>. The Russians will win if they manage to hold off the police for <b>20 minutes!</b></font>"
	faction1 = CIVILIAN
	faction2 = AMERICAN
	grace_wall_timer = 3000
	gamemode = "Drug Bust"
	songs = list(
		"Little Green Bag:1" = "sound/music/little_green_bag.ogg",)
		
obj/map_metadata/drug_bust/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_heist == TRUE)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/drug_bust/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 2400 || admin_ended_all_grace_periods)

/obj/map_metadata/drug_bust/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 2400 || admin_ended_all_grace_periods)
	
/obj/map_metadata/drug_bust/cross_message(faction)
	return "<font size = 4>SWAT has started the raid!</font>"

/obj/map_metadata/drug_bust/reverse_cross_message(faction)
	return ""

/obj/map_metadata/drug_bust/update_win_condition()
	if (win_condition_spam_check)
		return FALSE
	for(var/obj/structure/money_bag/C in world)
		if (C.storedvalue >= 10000) // total value stored = 12400+. So roughly 3/4th
			var/message = "The Police have sucessfully stolen over 10.000 dollars! The robbery was successful!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			show_global_battle_report(null)
			win_condition_spam_check = TRUE
			ticker.finished = TRUE
			return TRUE
	if (processes.ticker.playtime_elapsed >= 20000)
		ticker.finished = TRUE
		var/message = "The Police have suffered enough casualties and have retreated! The Russains win!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return TRUE

/obj/map_metadata/drug_bust/check_caribbean_block(var/mob/living/human/H, var/turf/T)
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

////////////////////////////////LOOOORE//////////////////////////////////////////////////

/obj/item/weapon/paper/police/searchwarrant/drug
	icon_state = "police_warrant"
	base_icon = "police_warrant"
	name = "Search Warrant"
	var/arn = 0
	New()
		..()
		arn = rand(100,999)
		icon_state = "police_warrant"
		spawn(10)
			info = "<center>DEPARTMENT OF JUSTICE<hr><large><b>Search Warrant No. [arn]</b></large><hr><br>Law Enforcement Agencies are hereby authorized and directed to search all and every property owned by <b>Vyacheslav 'Tatarin' Grigoriev</b>. They will disregard any claims of immunity or privilege by the Suspect or agents acting on the Suspect's behalf.<br><br><small><center><i>Form Model 13-C1</i></center></small><hr>"