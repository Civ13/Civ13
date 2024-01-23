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
		"In the Navy - Village People:1" = "sound/music/inthenavy.ogg",)
	var/ship_faction1
	var/ship_faction2
	var/faction1_engine_amount = 6
	var/faction2_engine_amount = 6
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

////////////////////////// Faction 1 procs //////////////////////////
/obj/map_metadata/battle_ships/proc/get_sinkable_amount_faction1()
	var/amount_of_turfs = 0
	for (var/turf/T in get_area_turfs(/area/caribbean/faction1/ship/lower))
		amount_of_turfs++
	amount_of_turfs = Floor(amount_of_turfs * 0.6)
	return amount_of_turfs

/obj/map_metadata/battle_ships/proc/get_sink_faction1()
	var/t_level = 0
	for (var/obj/effect/flooding/F in get_area_all_atoms(/area/caribbean/faction1/ship/lower))
		t_level += F.flood_level*2
	return t_level

/obj/map_metadata/battle_ships/proc/pump_faction1()
	check_engines_faction1()
	if (faction1_engine_amount > 0)
		for(var/obj/effect/flooding/F in get_area_all_atoms(/area/caribbean/faction1/ship/lower))
			F.flood_level--
			if (F.flood_level <= 0)
				qdel(F)
	else
		var/sound/uploaded_sound = sound('sound/machines/atomic_turbine_exterior_ending.ogg', repeat = FALSE, wait = TRUE, channel = 777)
		uploaded_sound.priority = 250
		for (var/mob/M in get_area_turfs(/area/caribbean/faction1/ship))
			M << SPAN_DANGER("<font size=4>The ship grumbles as the water pumps shut down.</font>")
			if (M.client)
				M.client << uploaded_sound

/obj/map_metadata/battle_ships/proc/check_engines_faction1()
	var/amount_of_engines = 0
	for (var/obj/structure/engine/E in get_area_all_atoms(/area/caribbean/faction1/ship/lower/engine))
		amount_of_engines++
	faction1_engine_amount = amount_of_engines



////////////////////////// Faction 2 procs //////////////////////////
/obj/map_metadata/battle_ships/proc/get_sinkable_amount_faction2()
	var/amount_of_turfs = 0
	for (var/turf/T in get_area_turfs(/area/caribbean/faction2/ship/lower))
		amount_of_turfs++
	amount_of_turfs = Floor(amount_of_turfs * 0.6)
	return amount_of_turfs

/obj/map_metadata/battle_ships/proc/get_sink_faction2()
	var/t_level = 0
	for (var/obj/effect/flooding/F in get_area_all_atoms(/area/caribbean/faction2/ship/lower))
		t_level += F.flood_level*2
	return t_level

/obj/map_metadata/battle_ships/proc/pump_faction2()
	check_engines_faction2()
	if (faction2_engine_amount > 0)
		for (var/obj/effect/flooding/F in get_area_all_atoms(/area/caribbean/faction2/ship/lower))
			F.flood_level--
			if (F.flood_level <= 0)
				qdel(F)
	else
		var/sound/uploaded_sound = sound('sound/machines/atomic_turbine_exterior_ending.ogg', repeat = FALSE, wait = TRUE, channel = 777)
		uploaded_sound.priority = 250
		for (var/mob/M in get_area_turfs(/area/caribbean/faction2/ship))
			M << SPAN_DANGER("<font size=4>The ship grumbles as the water pumps shut down.</font>")
			if (M.client)
				M.client << uploaded_sound

/obj/map_metadata/battle_ships/proc/check_engines_faction2()
	var/amount_of_engines = 0
	for(var/obj/structure/engine/E in get_area_all_atoms(/area/caribbean/faction2/ship/lower/engine))
		amount_of_engines++
	faction2_engine_amount = amount_of_engines


////////////////////////// Round control //////////////////////////
/obj/map_metadata/battle_ships/proc/check_roundend_conditions()
	// Sinking
	if (get_sink_faction1() >= get_sinkable_amount_faction1())
		roundend_msg = "The Redmenian ship has sank due to flooding in the lower decks! <br><h2><font color='blue'>The <b>Blugoslavians</b> have won!</font></h2>"
		map.next_win = world.time - 100
		return
	if (get_sink_faction2() >= get_sinkable_amount_faction2())
		roundend_msg = "The Blugoslavian ship has sank due to flooding in the lower decks! <br><h2><font color='red'>The <b>Redmenians</b> have won!</font></h2>"
		map.next_win = world.time - 100
		return
	// Everyone is dead
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
			roundend_msg = "The whole Redmenian crew has succumbed! <br><h2><font color='blue'>The <b>Blugoslavians</b> have won!</font></h2>"
			map.next_win = world.time - 100
			return
		if (!found_faction2)
			roundend_msg = "The whole Blugoslavian crew has succumbed! <br><h2><font color='red'>The <b>Redmenians</b> have won!</font></h2>"
			map.next_win = world.time - 100
			return
	spawn(300)
		check_roundend_conditions()

/obj/map_metadata/battle_ships/proc/announce_sink_status()
	spawn(600)
		var/ship_status_faction1 = "The <b><font color='red'>Redmenian</font> [ship_faction1]</b> has been flooded for <b>[get_sink_faction1() / get_sinkable_amount_faction1() * 100]/100%</b>"
		if (faction1_engine_amount > 0)
			pump_faction1()
		var/ship_status_faction2 = "The <b><font color='blue'>Blugoslavian</font> [ship_faction2]</b> has been flooded for <b>[get_sink_faction2() / get_sinkable_amount_faction2() * 100]/100%</b>"
		if (faction2_engine_amount > 0)
			pump_faction2()
		to_chat(world, "<font size=4>[ship_status_faction1]</font>")
		to_chat(world, "<font size=4>[ship_status_faction2]</font>")
		announce_sink_status()

/obj/map_metadata/battle_ships/update_win_condition()
	if (world.time >= next_win && next_win != -1)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		to_chat(world, "<font size=4>[roundend_msg]</font>")
		win_condition_spam_check = TRUE
		return FALSE

////////////////////////// Loading Partial Maps //////////////////////////
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
		to_chat(world, "<font size=4 color='red'>The Redmenian ship in this battle is the <b>[ship_faction1]</b>.</font>")
	if (location == "north")
		ship_faction2 = capitalize(mapname)
		to_chat(world, "<font size=4 color='blue'>The Blugoslavian ship in this battle is the <b>[ship_faction2]</b>.</font>")

/obj/map_metadata/battle_ships/proc/clear_map_faction1()
	//South
	for (var/turf/T in get_area_turfs(/area/caribbean/sea/bottom))
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
	for (var/turf/T in get_area_turfs(/area/caribbean/sea/bottom/roofed))
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
		new/area/caribbean/sea/bottom(T)
		for (var/atom/movable/lighting_overlay/LO in T)
			LO.update_overlay()

/obj/map_metadata/battle_ships/proc/clear_map_faction2()
	//North
	for (var/turf/T in get_area_turfs(/area/caribbean/sea/top))
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
	for (var/turf/T in get_area_turfs(/area/caribbean/sea/top/roofed))
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
		new/area/caribbean/sea/top(T)
		for (var/atom/movable/lighting_overlay/LO in T)
			LO.update_overlay()

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
	spawn(100)
		load_new_recipes("config/crafting/material_recipes_battle_ships.txt")
		override_global_recipes = "battle_ships"

/obj/map_metadata/battle_ships/cross_message(faction)
	switch (faction)
		if (PIRATES)
			check_roundend_conditions()
			announce_sink_status()
			to_chat(world, sound('sound/effects/siren_once.ogg', repeat = FALSE, wait = FALSE, volume = 50, channel = 3))
			return "<font size=4 color='red'>The battle has begun!</font>"
		else
			return ""

/obj/map_metadata/battle_ships/reverse_cross_message()
	return ""
