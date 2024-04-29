/obj/map_metadata/battle_ships
	ID = MAP_BATTLE_SHIPS
	title = "Battle Ships"
	no_winner = "The battle is still going on."
	lobby_icon = 'icons/lobby/battleships.png'
	can_spawn_on_base_capture = TRUE
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall, /area/caribbean/no_mans_land/invisible_wall/sea)
	faction_organization = list(
		REDFACTION,
		BLUEFACTION)
	roundend_condition_sides = list(
		list(REDFACTION) = /area/caribbean/faction1/ship/lower,
		list(CIVILIAN) = /area/caribbean/faction2/ship/lower,
		)
	age = "2024"
	ordinal_age = 8
	faction_distribution_coeffs = list(REDFACTION = 0.5, BLUEFACTION = 0.5)
	battle_name = "Battle over the Ocean"
	mission_start_message = "<font size=4><b>5 minutes</b> until the battle begins. Both sides have to sink eachothers ships by dealing as much damage to the bottom deck as possible!</font>"
	grace_wall_timer = 3000
	faction1 = REDFACTION
	faction2 = BLUEFACTION
	valid_weather_types = list(WEATHER_WET, WEATHER_NONE, WEATHER_EXTREME)
	songs = list(
		"In the Navy - Village People:1" = 'sound/music/inthenavy.ogg',)
	var/ship_faction1 = null
	var/ship_faction2 = null
	var/island = null

	var/faction1_engines_killed = FALSE
	var/faction1_initial_engine_amount = null
	var/faction1_engine_amount = null

	var/faction2_engines_killed = FALSE
	var/faction2_initial_engine_amount = null
	var/faction2_engine_amount = null

	var/roundend_msg = "The round has ended in a stalemate!"
	var/no_spam = FALSE

/obj/map_metadata/battle_ships/roundend_condition_def2name(define)
	..()
	switch (define)
		if (REDFACTION)
			return "Redmenian"
		if (BLUEFACTION)
			return "Blugoslavian"

/obj/map_metadata/battle_ships/roundend_condition_def2army(define)
	..()
	switch (define)
		if (REDFACTION)
			return "Imperial Redmenian Navy"
		if (BLUEFACTION)
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
	return amount_of_turfs

/obj/map_metadata/battle_ships/proc/get_sink_faction1()
	var/t_level = 0
	for (var/turf/T in get_area_all_atoms(/area/caribbean/faction1/ship/lower))
		var/found_cover = FALSE
		for (var/obj/covers/C in T)
			found_cover = TRUE
		if (!found_cover)
			t_level += 5
	if (((faction1_engine_amount / faction1_initial_engine_amount) * 100) < 25)
		t_level += 50
	return t_level

/obj/map_metadata/battle_ships/proc/check_engines_faction1()
	var/amount_of_engines = 0
	for (var/obj/structure/engine/E in get_area_all_atoms(/area/caribbean/faction1/ship/lower/engine))
		amount_of_engines++
	faction1_engine_amount = amount_of_engines

	if (!faction1_engines_killed)
		if (faction1_engine_amount <= 0)
			faction1_engines_killed = TRUE
			var/sound/uploaded_sound = sound('sound/machines/atomic_turbine_exterior_ending.ogg', repeat = FALSE, wait = TRUE, channel = 777)
			uploaded_sound.priority = 250
			for (var/mob/living/human/M in get_area_all_atoms(/area/caribbean/faction1/ship))
				to_chat(M, SPAN_DANGER("<font size=4>The ship grumbles as the last engine shut down.</font><br><font size=5>RESPAWNS ARE NOW DELAYED</font>"))
				if (M.client)
					M.client << uploaded_sound

////////////////////////// Faction 2 procs //////////////////////////
/obj/map_metadata/battle_ships/proc/get_sinkable_amount_faction2()
	var/amount_of_turfs = 0
	for (var/turf/T in get_area_turfs(/area/caribbean/faction2/ship/lower))
		amount_of_turfs++
	return amount_of_turfs

/obj/map_metadata/battle_ships/proc/get_sink_faction2()
	var/t_level = 0
	for (var/turf/T in get_area_all_atoms(/area/caribbean/faction2/ship/lower))
		var/found_cover = FALSE
		for (var/obj/covers/C in T)
			found_cover = TRUE
		if (!found_cover)
			t_level += 5
	if (((faction2_engine_amount / faction2_initial_engine_amount) * 100) < 25)
		t_level += 50
	return t_level

/obj/map_metadata/battle_ships/proc/check_engines_faction2()
	var/amount_of_engines = 0
	for(var/obj/structure/engine/E in get_area_all_atoms(/area/caribbean/faction2/ship/lower/engine))
		amount_of_engines++
	faction2_engine_amount = amount_of_engines
	
	if (!faction2_engines_killed)
		if (faction2_engine_amount <= 0)
			faction2_engines_killed = TRUE
			var/sound/uploaded_sound = sound('sound/machines/atomic_turbine_exterior_ending.ogg', repeat = FALSE, wait = TRUE, channel = 777)
			uploaded_sound.priority = 250
			for (var/mob/living/human/M in get_area_all_atoms(/area/caribbean/faction2/ship))
				to_chat(M, SPAN_DANGER("<font size=4>The ship grumbles as the last engine shut down.<br><font size=5>RESPAWNS ARE NOW DELAYED</font>"))
				if (M.client)
					M.client << uploaded_sound

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
	spawn(600) // 1 minute 
		check_engines_faction1()
		var/ship_status_faction1 = "The <b><font color='red'>Redmenian</font> [ship_faction1]</b> has been flooded for <b>[get_sink_faction1() / get_sinkable_amount_faction1() * 100]/100%</b>"
		
		check_engines_faction2()
		var/ship_status_faction2 = "The <b><font color='blue'>Blugoslavian</font> [ship_faction2]</b> has been flooded for <b>[get_sink_faction2() / get_sinkable_amount_faction2() * 100]/100%</b>"

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
	var/y_offset = 0
	switch (location)
		if ("random")
			location = pick("south","north")
		if ("north")
			y_offset = 66
		if ("middle")
			y_offset = 29

	var/dmm_file = "maps/zones/battle_ships/[location]/[mapname].dmm"
	if (!isfile(file(dmm_file)))
		var/newName_p1 = splittext(mapname,"_")
		var/newName = newName_p1[1]
		dmm_file = "maps/zones/battle_ships/[location]/[newName].dmm"
	var/dmm_text = file2text(dmm_file)
	var/dmm_suite/suite = new()
	suite.read_map(dmm_text, 1, y_offset, 1)

	switch (location)
		if ("south")
			check_engines_faction1()
			faction1_initial_engine_amount = faction1_engine_amount
			ship_faction1 = capitalize(replacetext(mapname, "_", " "))
			to_chat(world, "<font size=4 color='red'>The Redmenian ship in this battle is the <b>[ship_faction1]</b>.</font>")
		if ("middle")
			island = mapname
		if ("north")
			check_engines_faction2()
			faction2_initial_engine_amount = faction2_engine_amount
			ship_faction2 = capitalize(replacetext(mapname, "_", " "))
			to_chat(world, "<font size=4 color='blue'>The Blugoslavian ship in this battle is the <b>[ship_faction2]</b>.</font>")

/obj/map_metadata/battle_ships/proc/clear_faction1()
	ship_faction1 = null
	// South
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
		new/area/caribbean/sea/bottom(T)
		for (var/atom/movable/lighting_overlay/LO in T)
			LO.update_overlay()
	sleep(1)
	for (var/turf/T in get_area_turfs(/area/caribbean/faction1))
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
	sleep(1)
	for (var/turf/T in get_area_turfs(/area/caribbean/sea/bottom))
		for (var/obj/effect/flooding/F in T)
			qdel(F)

/obj/map_metadata/battle_ships/proc/clear_faction2()
	ship_faction2 = null
	// North
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
		for (var/obj/effect/flooding/F in T)
			qdel(F)
		new/area/caribbean/sea/top(T)
		for (var/atom/movable/lighting_overlay/LO in T)
			LO.update_overlay()
	sleep(1)
	for (var/turf/T in get_area_turfs(/area/caribbean/faction2))
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
		for (var/obj/effect/flooding/F in T)
			qdel(F)
		new/area/caribbean/sea/top(T)
		for (var/atom/movable/lighting_overlay/LO in T)
			LO.update_overlay()
	sleep(1)
	for (var/turf/T in get_area_turfs(/area/caribbean/sea/top))
		for (var/obj/effect/flooding/F in T)
			qdel(F)

/obj/map_metadata/battle_ships/proc/clear_middle()
	island = null
	// Middle
	for (var/turf/T in get_area_turfs(/area/caribbean/sea/middle))
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
		for (var/obj/effect/flooding/F in T)
			qdel(F)
		new/area/caribbean/sea/middle(T)
		for (var/atom/movable/lighting_overlay/LO in T)
			LO.update_overlay()
	sleep(1)
	for (var/turf/T in get_area_turfs(/area/caribbean/sea/middle))
		for (var/obj/effect/flooding/F in T)
			qdel(F)

/obj/map_metadata/battle_ships/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/redfaction))
		if (J.is_navy)
			. = TRUE
		else
			. = FALSE
	else if (istype(J, /datum/job/bluefaction))
		if (J.is_navy)
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
		if (prob(80))
			var/islands = list(
				"island1",
				"island2",
			)
			load_map(pick(islands), "middle")
		spawn(3000)
			check_roundend_conditions()
			announce_sink_status()


/obj/map_metadata/battle_ships/cross_message(faction)
	switch (faction)
		if (REDFACTION)
			to_chat(world, sound('sound/effects/siren_once.ogg', repeat = FALSE, wait = FALSE, volume = 50, channel = 3))
			return "<font size=4 color='red'>The battle has begun!</font>"
		else
			return ""

/obj/map_metadata/battle_ships/reverse_cross_message()
	return ""
