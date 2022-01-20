
/obj/map_metadata/african_warlords
	ID = MAP_AFRICAN_WARLORDS
	title = "African Warlords"
	lobby_icon_state = "coldwar"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/jungle,/area/caribbean/no_mans_land/invisible_wall/jungle/one,/area/caribbean/no_mans_land/invisible_wall/jungle/two,/area/caribbean/no_mans_land/invisible_wall/jungle/three)
	respawn_delay = 300
	no_winner ="No warband has won yet."
	lobby_icon_state = "africanwarlords"
	faction_organization = list(INDIANS)

	roundend_condition_sides = list(
		list(INDIANS) = /area/caribbean/british,
		)
	age = "1984"
	is_singlefaction = TRUE
	ordinal_age = 7
	faction_distribution_coeffs = list(INDIANS = 1)
	battle_name = "skull competition"
	mission_start_message = "<font size=4>Three African warlords are fighting for the control of this area. They will need to collect <b>50 enemy skulls</b> and bring them to their shaman hut.<br><b>DO NOT KILL THE UN DOCTORS!</b></font>"
	faction1 = INDIANS
	valid_weather_types = list(WEATHER_WET, WEATHER_NONE, WEATHER_EXTREME)
	songs = list(
		"Fortunate Son:1" = 'sound/music/fortunate_son.ogg',)
	scores = list(
		"Blugisi" = 0,
		"Yellowagwana" = 0,
		"Redkantu" = 0
	)
	New()
		..()
		spawn(600)
			points_check()
obj/map_metadata/african_warlords/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_warlords && J.title != "warlord (do not use)")
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/african_warlords/cross_message(faction)
	return "<font size = 4>All factions may cross the grace wall now!</font>"

/obj/map_metadata/african_warlords/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 1200 || admin_ended_all_grace_periods)

/obj/map_metadata/african_warlords/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 1200 || admin_ended_all_grace_periods)

/obj/map_metadata/african_warlords/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/jungle/one))
			if (H.nationality != "Redkantu")
				return TRUE
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/jungle/two))
			if (H.nationality != "Blugisi")
				return TRUE
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/jungle/three))
			if (H.nationality != "Yellowagwana")
				return TRUE
		else
			return !faction1_can_cross_blocks()
	return FALSE

/obj/map_metadata/african_warlords/proc/points_check()
	world << "<big><b>Current Points:</big></b>"
	world << "<big>Yellowagwana: [scores["Yellowagwana"]]</big>"
	world << "<big>Redkantu: [scores["Redkantu"]]</big>"
	world << "<big>Blugisi: [scores["Blugisi"]]</big>"
	spawn(300)
		points_check()

/obj/map_metadata/african_warlords/update_win_condition()

	if (world.time >= next_win && next_win != -1)
		if (win_condition_spam_check)
			return FALSE
		if (scores["Yellowagwana"] < 25 && scores["Blugisi"] < 25 && scores["Redkantu"] < 25)
			return
		ticker.finished = TRUE
		var/message = ""
		message = "The round has ended!"
		if (scores["Yellowagwana"] > scores["Blugisi"] && scores["Yellowagwana"] > scores["Redkantu"])
			message = "The battle is over! The <font color='yellow'><b>Yellowagwana</b></font> were victorious over the other militias!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			win_condition_spam_check = TRUE
			return FALSE
		else if (scores["Blugisi"] > scores["Yellowagwana"] && scores["Blugisi"] > scores["Redkantu"])
			message = "The battle is over! The <font color='blue'><b>Blugisi</b></font> were victorious over the other militias!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			win_condition_spam_check = TRUE
			return FALSE
		else if (scores["Redkantu"] > scores["Blugisi"] && scores["Redkantu"] > scores["Yellowagwana"])
			message = "The battle is over! The <font color='red'><b>Redkantu</b></font> were victorious over the other militias!"
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

///////////map specific objs/////////
/obj/structure/altar/darkstone/sacrifice
	name = "shaman's altar"
	icon_state = "blood_altar"
	flammable = FALSE
	health = 1000000
	var/faction = "none"

/obj/structure/altar/darkstone/sacrifice/attackby(obj/item/W, mob/living/human/user)
	if(faction != user.nationality)
		return
	if (istype(W, /obj/item/organ/external/head) && map.ID == MAP_AFRICAN_WARLORDS)
		var/obj/map_metadata/african_warlords/AW = map
		if (!W)
			return
		qdel(W)
		var/obj/item/organ/external/head/HD = W
		if (faction == HD.nationality || faction != user.nationality)
			return
		switch(faction)
			if("Blugisi")
				AW.scores["Blugisi"] += 1
			if("Yellowagwana")
				AW.scores["Yellowagwana"] += 1
			if("Redkantu")
				AW.scores["Redkantu"] += 1
		user << "You place the head on the shaman's altar."
		return