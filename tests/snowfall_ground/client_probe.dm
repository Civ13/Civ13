// Real-client check for generated ground snow (#3594).
// Test-only: client_check.py appends it to a temporary copy of civ13.dme with
// the Gaia map, starts the daemon and connects one Dream Seeker client. The
// probe stages a small winter scene with the production snow, weather, season
// and lighting code, moves the connected client into a human there, walks and
// shovels through the client's own movement and click paths, and asks the
// runner for a screenshot of the client window at each stage.
// With `-params headless=1` no client is awaited: a rehearsal of the staging
// and shovel logic only, which can never pass the client checks.
var/global/datum/snowfall_client_probe/snowfall_client_probe = new

/datum/snowfall_client_probe
	var/list/checks = list()
	var/list/metrics = list()
	var/list/shots = list()
	var/list/heard = list()
	var/phase = "startup"
	var/started_tod = 0
	var/headless = FALSE
	var/client/C
	var/mob/living/human/H
	var/turf/floor/centre

// The connected body, or a headless stand-in: only the SSD sleep check is off
// so Life never puts a client-less rehearsal body to sleep.
/mob/living/human/snow_client_actor/ssd_check()
	return FALSE

// Records every sound actually sent to the connected client's body.
/mob/living/human/playsound_local(turf/turf_source, soundin, vol, vary, frequency, falloff, is_global)
	if(snowfall_client_probe && src == snowfall_client_probe.H && client && vol > 0)
		snowfall_client_probe.heard += list(list("world_time" = world.time, "sound" = "[soundin]"))
	return ..()

/datum/snowfall_client_probe/New()
	// Linux 516.1688 stops global_init at makeDatumRefLists before configuration
	// loads; finish the same initialisers once before world/New needs them.
	if(!all_species || !all_species.len)
		makeDatumRefLists()
	if(!config)
		load_configuration()
		initialize_chemical_reagents()
		initialize_chemical_reactions()
	if(config)
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
	started_tod = world.timeofday
	spawn(10)
		drive()

/datum/snowfall_client_probe/proc/mark(name)
	phase = name
	world.log << "SNOWCLIENT [name]"
	fdel("phase.json")
	text2file(json_encode(list("phase" = name, "world_time" = world.time, "wall_ds" = world.timeofday - started_tod)), "phase.json")

/datum/snowfall_client_probe/proc/pass(name, list/details = null)
	checks += list(list("check" = name, "passed" = TRUE, "details" = details))

/datum/snowfall_client_probe/proc/require(condition, message)
	if(!condition)
		throw EXCEPTION(message)

/datum/snowfall_client_probe/proc/wait_for(proc_name, deadline_ds, message)
	var/until = world.time + deadline_ds
	while(!call(src, proc_name)())
		if(world.time > until)
			throw EXCEPTION(message)
		sleep(5)

/datum/snowfall_client_probe/proc/game_playing()
	return ticker && ticker.current_state == GAME_STATE_PLAYING

/datum/snowfall_client_probe/proc/scheduler_ready()
	return ticker && processScheduler && processes && processes.snowfall_ground && ticker.current_state >= GAME_STATE_PREGAME

/datum/snowfall_client_probe/proc/lighting_settled()
	return created_lighting_corners_and_overlays && !processes.time_of_day_change.updating_lighting

/datum/snowfall_client_probe/proc/client_connected()
	return clients.len > 0

// Asks the runner for a picture of the client window and waits for the file.
/datum/snowfall_client_probe/proc/shot(name)
	mark("shot_[name]")
	if(headless)
		return
	sleep(30) // Let the client draw the staged state first.
	fdel("shot-request.txt")
	text2file(name, "shot-request.txt")
	var/until = world.time + 900
	while(!fexists("shots/[name].png"))
		require(world.time < until, "The runner never captured screenshot [name]")
		sleep(5)
	fdel("shot-request.txt")
	shots += name

/datum/snowfall_client_probe/proc/reach_winter()
	var/list/path = list()
	var/guard = 0
	while(season != "WINTER")
		require(++guard <= 4, "Winter not reached")
		var/from = season
		spawn(0)
			map.seasons(FALSE, TRUE, FALSE)
		var/until = world.time + 6000
		while(season == from || map.season_busy)
			require(world.time < until, "Forced season change from [from] stalled")
			sleep(5)
		path += "[from]->[season]"
	// Gaia's own season timer would otherwise leave winter part-way through.
	if(map.uses_durable_metadata())
		map.durable_timer_queue().cancel("season_loop")
	map.season_loop_scheduled = TRUE
	pass("season_winter", list("path" = path))

/datum/snowfall_client_probe/proc/snow_icon(area/A)
	return replacetext("[A.icon_state]", "rad_", "") in list("snow1", "snow2", "snow_storm")

/datum/snowfall_client_probe/proc/open_ground(turf/T)
	if(!T || T.type != /turf/floor/grass || T.density || T.weather_snow || !T.snowfall_ground_exposed())
		return FALSE
	return TRUE

// A snowing, freezing grass field wide enough for the client's view.
/datum/snowfall_client_probe/proc/find_centre()
	var/work = 0
	for(var/i = 1 to snowfall_ground.len)
		var/turf/floor/T = snowfall_ground[i]
		if(++work % 500 == 0)
			sleep(world.tick_lag)
		if(T.x < 12 || T.y < 12 || T.x > world.maxx - 12 || T.y > world.maxy - 12 || !open_ground(T))
			continue
		var/area/A = get_area(T)
		if(!snow_icon(A) || get_temp(T) > SNOWFALL_STICK_C)
			continue
		var/good = TRUE
		for(var/turf/U in range(8, T))
			if(!open_ground(U) || get_area(U) != A)
				good = FALSE
				break
		if(good)
			return T
	return null

/datum/snowfall_client_probe/proc/at(dx, dy)
	return locate(centre.x + dx, centre.y + dy, centre.z)

/datum/snowfall_client_probe/proc/overlay_count(turf/T)
	var/n = 0
	for(var/I in T.overlays) // Appearances, not /image instances.
		if(I:icon == 'icons/turf/snow.dmi' && I:icon_state == "snow" && I:layer == 2.03)
			n++
	return n

/datum/snowfall_client_probe/proc/piles(turf/T)
	var/n = 0
	for(var/obj/item/weapon/snowwall/S in T)
		n++
	return n

// Walls, a roof, a tree, tall grass, a loose item and a bystander first, then
// production accumulation on every tile within four of the centre. The ring
// beyond stays bare for comparison.
/datum/snowfall_client_probe/proc/stage_scene()
	// Wild plants, loose objects and animals already on the field would hide
	// tiles or wander into the walk; the staged pieces below replace them.
	var/cleared = 0
	for(var/turf/U in range(8, centre))
		for(var/atom/movable/A in U)
			if(istype(A, /obj/structure) || istype(A, /obj/item) || istype(A, /mob/living/simple_animal))
				qdel(A)
				cleared++
	metrics["field_objects_cleared"] = cleared
	for(var/dx = -4 to -3)
		for(var/dy = -1 to 1)
			var/turf/D = at(dx, dy)
			D.ChangeTurf(/turf/floor/dirt)
	centre = locate(centre.x, centre.y, centre.z)
	new /obj/covers/wood_wall(at(-2, 3))
	new /obj/covers/wood_wall(at(-1, 3))
	new /obj/roof(at(1, 3))
	new /obj/roof(at(2, 3))
	new /obj/structure/wild/tree/live_tree(at(2, -3))
	new /obj/structure/wild/tallgrass(at(-2, -3))
	new /obj/structure/wild/tallgrass(at(-1, -3))
	new /obj/item/weapon/material/shovel/steel(at(1, 1))
	var/mob/living/human/snow_client_actor/bystander = new(at(-1, 1))
	bystander.name = "bystander"
	sleep(10)
	bystander.sleeping = 0
	bystander.resting = FALSE
	bystander.update_canmove()
	var/snowed = 0
	var/list/skipped = list()
	for(var/turf/floor/T in range(4, centre))
		if(!T.snowfall_ground_eligible())
			continue
		for(var/n in 1 to SNOWFALL_MAX_UNITS)
			T.snowfall_ground_check()
		if(T.weather_snow > 0)
			require(overlay_count(T) == 1, "Snowed tile [T.x],[T.y] has [overlay_count(T)] snow overlays")
			snowed++
		else
			skipped += "[T.x - centre.x],[T.y - centre.y]"
	var/turf/floor/dirt_site = at(-3, 0)
	var/turf/floor/roofed = at(1, 3)
	var/turf/floor/walled = at(-2, 3)
	require(centre.weather_snow == SNOWFALL_MAX_UNITS && dirt_site.type == /turf/floor/dirt && dirt_site.weather_snow == SNOWFALL_MAX_UNITS, "Grass and dirt did not both take generated snow")
	require(!roofed.weather_snow && !walled.weather_snow, "Roofed or walled tile took generated snow")
	var/image/overlay = centre.weather_snow_overlay
	pass("scene_staged", list("centre" = "[centre.x],[centre.y],[centre.z]", "area" = "[get_area(centre)]", "snowed_tiles" = snowed, "tiles_without_snow" = skipped, "get_temp" = get_temp(centre), "overlay_plane" = overlay.plane, "overlay_layer" = overlay.layer, "turf_plane" = centre.plane))

/datum/snowfall_client_probe/proc/set_daylight(name)
	spawn(0)
		update_lighting(name, null, FALSE)
	sleep(10)
	wait_for("lighting_settled", 6000, "Lighting never settled on [name]")
	require(time_of_day == name, "Time of day is [time_of_day], wanted [name]")
	sleep(20)

/datum/snowfall_client_probe/proc/take_body()
	if(headless)
		H = new /mob/living/human/snow_client_actor(centre)
		sleep(10)
	else
		mark("waiting_for_client")
		wait_for("client_connected", 18000, "No client connected within 30 minutes")
		C = clients[1]
		sleep(100)
		H = new /mob/living/human(centre)
		H.ckey = C.ckey
		sleep(50)
		C = H.client
		require(C && C.mob == H, "The client did not take the staged body")
		metrics["client"] = list("byond_version" = C.byond_version, "byond_build" = C.byond_build, "view" = "[C.view]", "connection" = "[C.connection]")
	H.sleeping = 0
	H.resting = FALSE
	H.update_canmove()
	H.a_intent = I_HELP
	H.m_intent = "walk"
	// The staged body is unclothed in a forced winter: hold its temperature so
	// cold damage does not end the walk. Nothing about snow reads it.
	spawn(0)
		while(H && !QDELETED(H))
			H.bodytemperature = H.species.body_temperature
			sleep(10)

// One tile through the client's own Move, waiting out the movement delay and
// the footstep interval so every step is allowed to make its sound.
/datum/snowfall_client_probe/proc/client_step(dir)
	var/turf/target = get_step(H, dir)
	var/until = world.time + 100
	while(H.loc != target)
		require(world.time < until, "Client could not step onto [target.x],[target.y]")
		if(movementMachine.ticks >= H.next_footstep_sound_at_movement_tick && world.time >= C.move_delay && !C.moving)
			C.Move(target, dir)
		sleep(1)
	sleep(2)
	return target

/datum/snowfall_client_probe/proc/footstep_family(sound_path)
	var/file = sound_path
	for(var/entry in snowfootsteps)
		if("[entry]" == file)
			return "snow"
	for(var/entry in grassfootsteps)
		if("[entry]" == file)
			return "grass"
	for(var/entry in dirtfootsteps)
		if("[entry]" == file)
			return "dirt"
	return null

// Walks a row and returns one entry per tile: its cover and the footstep sent.
/datum/snowfall_client_probe/proc/walk_row(turf/start, steps)
	H.forceMove(start)
	sleep(20)
	var/list/rows = list()
	for(var/i in 1 to steps)
		var/from_index = heard.len
		var/turf/floor/T = client_step(EAST)
		var/family = null
		for(var/j = from_index + 1 to heard.len)
			var/list/entry = heard[j]
			family = footstep_family(entry["sound"]) || family
		rows += list(list("tile" = "[T.x - centre.x],[T.y - centre.y]", "type" = "[T.type]", "snow_units" = T.weather_snow, "footstep" = family))
	return rows

/datum/snowfall_client_probe/proc/expect_footsteps(list/rows, label)
	for(var/list/row in rows)
		var/want = row["snow_units"] > 0 ? "snow" : (row["type"] == "/turf/floor/dirt" ? "dirt" : "grass")
		require(row["footstep"] == want, "[label]: tile [row["tile"]] ([row["type"]], snow [row["snow_units"]]) sent the [row["footstep"] || "no"] footstep, wanted [want]")

/datum/snowfall_client_probe/proc/settle()
	var/until = world.time + 900
	sleep(3)
	while(H.shoveling || !H.may_do_after)
		require(world.time < until, "Shovel action never finished")
		sleep(2)
	sleep(3)

/datum/snowfall_client_probe/proc/dig(turf/T)
	spawn(0)
		if(C)
			H.ClickOn(T)
		else
			T.attackby(H.get_active_hand(), H)
	settle()

/datum/snowfall_client_probe/proc/check_lighting()
	set_daylight("Night")
	shot("night_no_fire")
	// A fuelled brazier lights further than it warms: tiles within its heat
	// melt on the next production check, the lit tiles beyond keep their snow.
	var/obj/structure/brazier/loaded/B = new(at(6, 0))
	sleep(20)
	var/melted = 0
	var/lit_snow = 0
	for(var/turf/floor/T in range(4, centre))
		if(T.weather_snow <= 0)
			continue
		T.snowfall_ground_check(FALSE)
		if(T.weather_snow <= 0)
			require(!overlay_count(T), "Melted tile kept its snow overlay")
			melted++
		else if(get_dist(T, B) <= 5)
			lit_snow++
	require(melted > 0 && lit_snow > 0, "Brazier scene needs melted and lit snowed tiles (melted [melted], lit [lit_snow])")
	shot("night_brazier")
	pass("night_and_fire", list("time_of_day" = time_of_day, "melted_by_heat" = melted, "snowed_tiles_in_light" = lit_snow))
	B.on = FALSE
	qdel(B)
	set_daylight("Midday")

/datum/snowfall_client_probe/proc/check_footsteps()
	if(headless)
		return
	// Row -1 runs snowed dirt, snowed grass, grass melted by the brazier and
	// the bare ring; nothing stands on it.
	var/list/rows = walk_row(at(-5, -1), 11)
	expect_footsteps(rows, "first walk")
	var/list/seen = list()
	for(var/list/row in rows)
		seen["[row["snow_units"] > 0 ? "snowed" : "bare"] [row["type"]]"] = row["footstep"]
	require(seen["snowed /turf/floor/grass"] == "snow" && seen["snowed /turf/floor/dirt"] == "snow" && seen["bare /turf/floor/grass"] == "grass", "The walk did not cover snowed grass, snowed dirt and bare grass: [json_encode(seen)]")
	pass("footsteps_follow_snow", list("steps" = rows))
	shot("after_walk")

/datum/snowfall_client_probe/proc/check_shovel()
	H.forceMove(centre)
	sleep(10)
	var/obj/item/shovel = new /obj/item/weapon/material/shovel/steel(H.loc)
	H.drop_item()
	require(H.put_in_active_hand(shovel) && H.get_active_hand() == shovel, "Could not hold the shovel")
	var/turf/floor/T = at(0, 1)
	require(T.type == /turf/floor/grass && T.weather_snow == SNOWFALL_MAX_UNITS, "Shovel tile is not fully snowed grass")
	H.dir = NORTH
	dig(T)
	require(at(0, 1) == T && T.type == /turf/floor/grass && T.weather_snow == 1 && piles(T) == 1 && overlay_count(T) == 1, "First dig: type [T.type], units [T.weather_snow], piles [piles(T)]")
	shot("shovel_one_pile")
	dig(T)
	require(at(0, 1) == T && T.type == /turf/floor/grass && T.weather_snow == 0 && piles(T) == 2 && !overlay_count(T), "Second dig: type [T.type], units [T.weather_snow], piles [piles(T)]")
	shot("shovel_snow_cleared")
	pass("shovel_snow_keeps_grass", list("piles" = piles(T), "type" = "[T.type]"))
	// With the snow gone the same shovel works the ground as it always did.
	dig(T)
	var/turf/after = at(0, 1)
	require(after.type != /turf/floor/grass, "Shovel left the grass layer in place after the snow was gone")
	shot("shovel_grass_removed")
	pass("shovel_bare_grass_removed", list("type_after" = "[after.type]"))
	if(headless)
		return
	// Footsteps stop being snow where it was shovelled away.
	for(var/obj/item/weapon/snowwall/S in after)
		qdel(S)
	var/list/rows = walk_row(at(-2, 1), 3)
	expect_footsteps(rows, "after shovelling")
	var/list/cleared = rows[2]
	require(cleared["tile"] == "0,1" && cleared["footstep"] != "snow", "Shovelled tile still sent the snow footstep")
	pass("footsteps_stop_after_shovel", list("steps" = rows))

/datum/snowfall_client_probe/proc/drive()
	var/failure = null
	var/failed_phase = null
	headless = world.params["headless"] ? TRUE : FALSE
	try
		mark("startup")
		wait_for("scheduler_ready", 9000, "Scheduler/ticker never became ready")
		ticker.admin_started = TRUE
		if(ticker.pregame_timeleft > 1)
			ticker.pregame_timeleft = 1
		wait_for("game_playing", 3000, "Round did not reach PLAYING")
		// The probe's explicit production change_weather() call sets the weather;
		// the weather and snow workers are paused so the staged scene holds still.
		if(processes.weather)
			processes.weather.disable()
		processes.snowfall_ground.disable()
		metrics["map"] = list("id" = map.ID, "byond_version" = world.byond_version, "byond_build" = world.byond_build, "tested_commit" = world.params["tested_commit"], "headless" = headless)
		mark("winter")
		reach_winter()
		change_weather(WEATHER_WET, TRUE)
		mark("daylight")
		set_daylight("Midday")
		mark("scene")
		centre = find_centre()
		require(centre, "No clear snowing grass field found (season [season], weather [weather])")
		stage_scene()
		take_body()
		shot("day_overview")
		mark("lighting")
		check_lighting()
		mark("footsteps")
		check_footsteps()
		mark("shovel")
		check_shovel()
		shot("final")
	catch(var/exception/e)
		failure = "[e.name]"
		failed_phase = phase
	mark("finished")
	var/list/result = list("passed" = isnull(failure), "failure" = failure, "failed_phase" = failed_phase, "checks" = checks, "metrics" = metrics, "shots" = shots, "sounds_sent" = heard.len, "wall_ds" = world.timeofday - started_tod)
	fdel("result.json")
	text2file(json_encode(result), "result.json")
	world.log << (failure ? "FAIL: snowfall client probe: [failure]" : "PASS: snowfall client probe")
	sleep(20)
	del(world)
