/obj/map_metadata/battle_ships
	ID = MAP_BATTLE_SHIPS
	title = "Battle Ships"
	no_winner = "The battle is still going on."
	lobby_icon = "icons/lobby/battleships.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall, /area/caribbean/no_mans_land/invisible_wall/sea)
	faction_organization = list(
		PIRATES,
		CIVILIAN)
	roundend_condition_sides = list(
		list(PIRATES) = /area/caribbean/faction1/ship/lower,
		list(CIVILIAN) = /area/caribbean/faction2/ship/lower,
		)
	age = "2024"
	ordinal_age = 8
	faction_distribution_coeffs = list(PIRATES = 0.5, CIVILIAN = 0.5)
	battle_name = "Battle over the Ocean"
	mission_start_message = "<font size=4><b>5 minutes</b> until the battle begins. Both sides have to sink eachothers ships by dealing as much damage to the bottom deck as possible!</font>"
	grace_wall_timer = 3000
	faction1 = PIRATES
	faction2 = CIVILIAN
	valid_weather_types = list(WEATHER_WET, WEATHER_NONE, WEATHER_EXTREME)
	songs = list(
		"Emma:1" = "sound/music/emma.ogg",)
	var/ship_faction1
	var/ship_faction2
	var/roundend_msg = "The round has ended in a stalemate!"
	var/no_spam = FALSE

/obj/map_metadata/battle_ships/roundend_condition_def2name(define)
	..()
	switch (define)
		if (PIRATES)
			return "Redmenian"
		if (CIVILIAN)
			return "Blugoslavian"

/obj/map_metadata/battle_ships/roundend_condition_def2army(define)
	..()
	switch (define)
		if (PIRATES)
			return "Imperial Redmenian Navy"
		if (CIVILIAN)
			return "Blugoslavian Naval Forces"

/obj/map_metadata/battle_ships/army2name(army)
	..()
	switch (army)
		if ("Imperial Redmenian Navy")
			return "Redmenian"
		if ("Blugoslavian Naval Forces")
			return "Blugoslavian"

/obj/map_metadata/battle_ships/proc/get_sink_faction1()
	var/t_level = 0
	for(var/obj/effect/flooding/F in get_area_all_atoms(/area/caribbean/faction1/ship/lower))
		t_level += F.flood_level*2
	for(var/obj/effect/flooding/F in get_area_all_atoms(/area/caribbean/faction1/ship/lower/storage/kitchen))
		t_level += F.flood_level*2
	for(var/obj/effect/flooding/F in get_area_all_atoms(/area/caribbean/faction1/ship/lower/storage))
		t_level += F.flood_level*2
	for(var/obj/effect/flooding/F in get_area_all_atoms(/area/caribbean/faction1/ship/lower/storage/magazine))
		t_level += F.flood_level*2
	for(var/obj/effect/flooding/F in get_area_all_atoms(/area/caribbean/faction1/ship/lower/engine))
		t_level += F.flood_level*2
	return t_level

/obj/map_metadata/battle_ships/proc/get_sink_faction2()
	var/t_level = 0
	for(var/obj/effect/flooding/F in get_area_all_atoms(/area/caribbean/faction2/ship/lower))
		t_level += F.flood_level*2
	for(var/obj/effect/flooding/F in get_area_all_atoms(/area/caribbean/faction2/ship/lower/storage/kitchen))
		t_level += F.flood_level*2
	for(var/obj/effect/flooding/F in get_area_all_atoms(/area/caribbean/faction2/ship/lower/storage))
		t_level += F.flood_level*2
	for(var/obj/effect/flooding/F in get_area_all_atoms(/area/caribbean/faction2/ship/lower/storage/magazine))
		t_level += F.flood_level*2
	for(var/obj/effect/flooding/F in get_area_all_atoms(/area/caribbean/faction2/ship/lower/engine))
		t_level += F.flood_level*2
	return t_level

/obj/map_metadata/battle_ships/proc/check_roundend_conditions()
	//sinking
	if (get_sink_faction1() >= 100)
		roundend_msg = "The Redmenian ship has sank due to flooding in the lower decks!<br><font color='blue'><h2>The Blugoslavians have won!</h2></font>"
		map.next_win = world.time - 100
		return
	if (get_sink_faction2() >= 100)
		roundend_msg = "The Blugoslavian ship has sank due to flooding in the lower decks!<br><font color='red'><h2>The Redmenians have won!</h2></font>"
		map.next_win = world.time - 100
		return
	//everyone dead
	if(processes && processes.ticker && processes.ticker.playtime_elapsed >= 6000) //10 mins
		var/found_faction1 = FALSE
		var/found_faction2 = FALSE
		for(var/mob/living/human/H in mob_list)
			if (H.stat == CONSCIOUS)
				if (H.faction_text == faction1)
					found_faction1 = TRUE
				if (H.faction_text == faction2)
					found_faction2 = TRUE
		if (!found_faction1)
			roundend_msg = "The whole Redmenian crew has succumbed!<br><font color='blue'><h2>The Blugoslavians have won!</h2></font>"
			map.next_win = world.time - 100
			return
		if (!found_faction2)
			roundend_msg = "The whole Blugoslavian crew has succumbed!<br><font color='red'><h2>The Redmenians have won!</h2></font>"
			map.next_win = world.time - 100
			return

/obj/map_metadata/battle_ships/proc/clear_map()
	//North
	for(var/turf/T in get_area_turfs(/area/caribbean/sea/top))
		for (var/mob/living/M in T)
			qdel(M)
		for (var/obj/O in T)
			qdel(O)
		if (!istype(T,/turf/floor/beach/water/deep/saltwater))
			for(var/atom/movable/lighting_overlay/LO in T)
				qdel(LO)
			var/turf/floor/beach/water/deep/saltwater/newturf = new/turf/floor/beach/water/deep/saltwater(T)
			for (var/i = 1 to 4)
				if (newturf.corners[i])
					continue
				newturf.corners[i] = new/datum/lighting_corner(newturf, LIGHTING_CORNER_DIAGONAL[i])
		for (var/atom/movable/lighting_overlay/LO in T)
			LO.update_overlay()
	sleep(1)
	for(var/turf/T1 in get_area_turfs(/area/caribbean/sea/top/roofed))
		for (var/mob/living/M in T1)
			qdel(M)
		for (var/obj/O in T1)
			qdel(O)
		if (!istype(T1,/turf/floor/beach/water/deep/saltwater))
			for(var/atom/movable/lighting_overlay/LO in T1)
				qdel(LO)
			var/turf/floor/beach/water/deep/saltwater/newturf = new/turf/floor/beach/water/deep/saltwater(T1)
			for (var/i = 1 to 4)
				if (newturf.corners[i])
					continue
				newturf.corners[i] = new/datum/lighting_corner(newturf, LIGHTING_CORNER_DIAGONAL[i])
		new/area/caribbean/sea/top(T1)
		for (var/atom/movable/lighting_overlay/LO in T1)
			LO.update_overlay()
	sleep(1)
	//South
	for(var/turf/T2 in get_area_turfs(/area/caribbean/sea/bottom))
		for (var/mob/living/M in T2)
			qdel(M)
		for (var/obj/O in T2)
			qdel(O)
		if (!istype(T2,/turf/floor/beach/water/deep/saltwater))
			for(var/atom/movable/lighting_overlay/LO in T2)
				qdel(LO)
			var/turf/floor/beach/water/deep/saltwater/newturf = new/turf/floor/beach/water/deep/saltwater(T2)
			for (var/i = 1 to 4)
				if (newturf.corners[i])
					continue
				newturf.corners[i] = new/datum/lighting_corner(newturf, LIGHTING_CORNER_DIAGONAL[i])
		for (var/atom/movable/lighting_overlay/LO in T2)
			LO.update_overlay()
	sleep(1)
	for(var/turf/T3 in get_area_turfs(/area/caribbean/sea/bottom/roofed))
		for (var/mob/living/M in T3)
			qdel(M)
		for (var/obj/O in T3)
			qdel(O)
		if (!istype(T3,/turf/floor/beach/water/deep/saltwater))
			for(var/atom/movable/lighting_overlay/LO in T3)
				qdel(LO)
			var/turf/floor/beach/water/deep/saltwater/newturf = new/turf/floor/beach/water/deep/saltwater(T3)
			for (var/i = 1 to 4)
				if (newturf.corners[i])
					continue
				newturf.corners[i] = new/datum/lighting_corner(newturf, LIGHTING_CORNER_DIAGONAL[i])
		new/area/caribbean/sea/bottom(T3)
		for (var/atom/movable/lighting_overlay/LO in T3)
			LO.update_overlay()

/obj/map_metadata/battle_ships/update_win_condition()
	if (world.time >= next_win && next_win != -1)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		world << "<font size=4>[roundend_msg]</font>"
		win_condition_spam_check = TRUE
		return FALSE

////////////////////////////////////////////////////////////////
//////////////////LOADING PARTIAL MAPS//////////////////////////
/obj/map_metadata/battle_ships/proc/load_map(mapname = "ship1", location = "random")
	if (location == "random")
		location = pick("south","north")
	var/y_offset = 0 //for north maps
	if (location == "north")
		y_offset = 66
	var/dmm_file = "maps/zones/battle_ships/[location]/[mapname].dmm"
	if (!isfile(file(dmm_file)))
		var/newName_p1 = splittext(mapname,"_")
		var/newName = newName_p1[1]
		dmm_file = "maps/zones/battle_ships/[location]/[newName].dmm"
	var/dmm_text = file2text(dmm_file)
	var/dmm_suite/suite = new()
	suite.read_map(dmm_text, 1, y_offset, 1)
	if (location == "south")
		ship_faction1 = capitalize(mapname)
		world << "<font size=4 color='red'>The Redmenian ship in this battle is the [ship_faction1].</font>"
	if (location == "north")
		ship_faction2 = capitalize(mapname)
		world << "<font size=4 color='blue'>The Blugoslavian ship in this battle is the [ship_faction2].</font>"

/obj/map_metadata/battle_ships/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/civilian))
		if (J.is_event && J.is_navy)
			. = TRUE
		else
			. = FALSE
	else if (istype(J, /datum/job/pirates))
		if (J.is_event && J.is_navy)
			. = TRUE
		else
			. = FALSE
	else
		. = FALSE

/obj/map_metadata/battle_ships/New()
	..()
			

/obj/map_metadata/battle_ships/cross_message()
	return "<font size = 4><font color='red'>The battle has begun!</font>"
/obj/map_metadata/battle_ships/reverse_cross_message()
	return ""
