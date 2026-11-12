// Headless full-game pedal bicycle regression. ride.py appends it to a
// temporary copy of civ13.dme. A rider who free walked onto the bicycle's tile
// boards through MouseDrop_T, pedals with the handlebars, brakes and gets off,
// once in each cardinal direction on a road. Further legs ride loaded, over
// grass, into an obstacle and nearly exhausted. Production code runs
// unchanged; this file only drives it and records what happened.
var/global/datum/pedal_ride_probe/pedal_ride_probe = new

/mob/living/human/pedal_ride_actor/ssd_check()
	return FALSE

/datum/pedal_ride_probe
	var/list/samples = list()
	var/list/notes = list()
	var/list/frames = list()

/datum/pedal_ride_probe/New()
	if(!all_species || !all_species.len)
		makeDatumRefLists()
	if(!config)
		load_configuration()
		initialize_chemical_reagents()
		initialize_chemical_reactions()
	if(config)
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
	spawn(10)
		run_probe()

/datum/pedal_ride_probe/proc/ready()
	return ticker && processScheduler && ticker.current_state >= GAME_STATE_PREGAME

/datum/pedal_ride_probe/proc/playing()
	return ticker && ticker.current_state == GAME_STATE_PLAYING

/datum/pedal_ride_probe/proc/wait_for(proc_name, limit)
	var/until = world.time + limit
	while(!call(src, proc_name)())
		if(world.time > until)
			throw EXCEPTION("timeout waiting for [proc_name]")
		sleep(5)

/datum/pedal_ride_probe/proc/pave(turf/centre, ground)
	for(var/dx = -14 to 14)
		for(var/dy = -14 to 14)
			var/turf/T = locate(centre.x + dx, centre.y + dy, centre.z)
			if(!T)
				return FALSE
			for(var/atom/movable/A in T)
				if(A.density || ismob(A) || istype(A, /obj/structure) || istype(A, /obj/covers))
					A.loc = null // Fixture ground only; immediate, unlike queued qdel.
			if(T.type != ground)
				T = new ground(T)
	sleep(10)
	return TRUE

/datum/pedal_ride_probe/proc/frame(label, leg, obj/structure/vehicle/V, mob/living/human/R)
	frames += list(list("label" = label, "leg" = leg, "bike_x" = V.x, "bike_y" = V.y, "bike_dir" = V.dir, "bike_state" = V.icon_state, "overlays" = V.overlays.len, "rider_x" = R.x, "rider_y" = R.y, "rider_sx" = R.step_x, "rider_sy" = R.step_y, "rider_px" = R.pixel_x, "rider_py" = R.pixel_y, "rider_dir" = R.dir, "driver" = (V.driver == R)))

/datum/pedal_ride_probe/proc/ride(turf/start, direction, leg, load = 0, obstacle = FALSE, stamina = null)
	var/obj/structure/vehicle/bicycle/V = new(start)
	V.dir = direction
	var/mob/living/human/pedal_ride_actor/R = new(start)
	R.m_intent = "walk"
	R.a_intent = I_HELP
	sleep(5)
	if(load)
		var/obj/item/weapon/wrench/cargo = new(R)
		cargo.weight = load
	var/obj/structure/vehicle/bicycle/wall = null
	if(obstacle)
		var/turf/ahead = start
		for(var/i = 1 to 4)
			ahead = get_step(ahead, direction)
		wall = new(ahead)
	// A player who free-walked onto the tile keeps a pixel offset and a walking glide.
	R.step_x = 13
	R.step_y = 11
	R.human_subtile_offset_owned = TRUE
	R.dir = direction
	R.glide_size = 4
	frame("before_mount", leg, V, R)
	V.MouseDrop_T(R, R)
	if(V.driver != R)
		throw EXCEPTION("[leg]: rider did not take the handlebars")
	R.dir = direction
	V.update_icon()
	frame("mounted", leg, V, R)
	var/list/summary = list("mounted_sx" = R.step_x, "mounted_sy" = R.step_y, "mounted_overlays" = V.overlays.len)
	var/obj/item/vehicleparts/wheel/handle/bicycle/handle = R.get_active_hand()
	if(!istype(handle))
		throw EXCEPTION("[leg]: no handlebars in hand")
	if(!isnull(stamina))
		R.stats["stamina"][1] = stamina
	var/spent = 0
	var/last_stamina = R.stats["stamina"][1]
	handle.attack_self(R)
	if(!V.moving)
		throw EXCEPTION("[leg]: pedaling did not start")
	var/start_x = V.x
	var/start_y = V.y
	var/until = world.time + 150
	var/lastx = V.x
	var/lasty = V.y
	var/first_arrival = null
	var/last_arrival = null
	var/arrivals = 0
	var/low_stamina = R.stats["stamina"][1]
	while(world.time < until && abs(V.x - start_x) + abs(V.y - start_y) < 8 && V.moving)
		sleep(world.tick_lag)
		low_stamina = min(low_stamina, R.stats["stamina"][1])
		// Count only drops, so natural recovery does not hide the cost.
		spent += max(0, last_stamina - R.stats["stamina"][1])
		last_stamina = R.stats["stamina"][1]
		if(V.x != lastx || V.y != lasty)
			lastx = V.x
			lasty = V.y
			arrivals++
			if(isnull(first_arrival))
				first_arrival = world.time
			last_arrival = world.time
			samples += list(list("leg" = leg, "t" = world.time, "x" = V.x, "y" = V.y, "bike_glide" = V.glide_size, "rider_glide" = R.glide_size, "same_loc" = (R.loc == V.loc), "rider_sx" = R.step_x, "rider_sy" = R.step_y, "driver" = (V.driver == R), "delay" = V.vehicle_m_delay))
			if(arrivals == 2)
				frame("riding", leg, V, R)
	summary["travelled"] = abs(V.x - start_x) + abs(V.y - start_y)
	summary["interval"] = arrivals > 1 ? (last_arrival - first_arrival) / (arrivals - 1) : null
	summary["set_delay"] = V.vehicle_m_delay
	summary["stamina_used"] = spent
	summary["low_stamina"] = low_stamina
	summary["still_moving"] = V.moving
	summary["driver_after"] = (V.driver == R)
	summary["brute"] = R.getBruteLoss()
	summary["bike_health"] = V.health
	if(V.moving)
		handle.secondary_attack_self(R)
	summary["braked"] = !V.moving
	var/turf/braked_at = get_turf(V)
	sleep(10)
	summary["rolled_after_brake"] = (get_turf(V) != braked_at)
	if(V.driver == R)
		V.attack_hand(R)
		sleep(10)
	summary["after_dismount_glide"] = R.glide_size
	summary["after_dismount_driver"] = "[V.driver]"
	summary["after_dismount_overlays"] = V.overlays.len
	summary["handlebars_home"] = (handle.loc == V)
	summary["rider_flags"] = "[R.driver]/[R.driver_vehicle]/[R.buckled]"
	notes[leg] = summary
	qdel(V)
	if(wall)
		qdel(wall)
	R.loc = null
	sleep(5)

/datum/pedal_ride_probe/proc/run_probe()
	var/failure = null
	try
		wait_for("ready", 9000)
		ticker.admin_started = TRUE
		if(ticker.pregame_timeleft > 1)
			ticker.pregame_timeleft = 1
		wait_for("playing", 3000)
		var/turf/start = locate(round(world.maxx / 2), round(world.maxy / 2), world.maxz >= 2 ? 2 : 1)
		if(!start || !pave(start, /turf/floor/plating/road))
			throw EXCEPTION("no clear square found")
		notes["start"] = "[start.x],[start.y],[start.z] [start.type]"
		var/list/dirs = list("east" = EAST, "north" = NORTH, "west" = WEST, "south" = SOUTH)
		for(var/dirname in dirs)
			ride(start, dirs[dirname], dirname)
		ride(start, EAST, "loaded", 59)
		ride(start, EAST, "blocked", 0, TRUE)
		ride(start, EAST, "tired", 177, FALSE, 0.4)
		if(!pave(start, /turf/floor/grass))
			throw EXCEPTION("could not lay grass")
		ride(start, EAST, "grass")
		check()
	catch(var/exception/e)
		failure = "[e.name]"
	var/list/result = list("passed" = isnull(failure), "failure" = failure, "notes" = notes, "samples" = samples, "frames" = frames, "tick_lag" = world.tick_lag)
	text2file(json_encode(result), "result.json")
	world.log << "PEDAL PROBE DONE [failure]"
	sleep(5)
	del(world)

/datum/pedal_ride_probe/proc/near(value, expected)
	// Each arrival lands on a server tick; the average over a leg stays close.
	return !isnull(value) && abs(value - expected) <= world.tick_lag / 2

/datum/pedal_ride_probe/proc/check()
	var/list/problems = list()
	for(var/leg in notes)
		if(leg == "start")
			continue
		var/list/s = notes[leg]
		if(s["mounted_sx"] || s["mounted_sy"])
			problems += "[leg]: seated at offset [s["mounted_sx"]],[s["mounted_sy"]]"
		if(!s["mounted_overlays"] || s["after_dismount_overlays"])
			problems += "[leg]: rider overlay [s["mounted_overlays"]] mounted, [s["after_dismount_overlays"]] after"
		if(!s["driver_after"])
			problems += "[leg]: rider fell off"
		if(s["brute"] > 0 || s["bike_health"] < 100)
			problems += "[leg]: damage ([s["brute"]] brute, bicycle [s["bike_health"]])"
		if(!s["braked"] || s["rolled_after_brake"])
			problems += "[leg]: did not stay stopped"
		if(s["after_dismount_glide"] != 4)
			problems += "[leg]: dismount left glide [s["after_dismount_glide"]]"
		if(!s["handlebars_home"] || s["after_dismount_driver"] != "" || s["rider_flags"] != "0//")
			problems += "[leg]: dismount left [s["after_dismount_driver"]] [s["rider_flags"]] handlebars home [s["handlebars_home"]]"
		if(s["low_stamina"] < 0)
			problems += "[leg]: stamina went negative"
	for(var/leg in list("east", "north", "west", "south"))
		var/list/s = notes[leg]
		if(s["travelled"] < 8)
			problems += "[leg]: stopped after [s["travelled"]] tiles"
		if(s["set_delay"] != 1.5 || !near(s["interval"], 1.5))
			problems += "[leg]: [s["interval"]] ds per tile, expected 1.5"
		if(s["stamina_used"] <= 0)
			problems += "[leg]: pedaling was free"
	var/list/loaded = notes["loaded"]
	var/list/east = notes["east"]
	if(loaded["travelled"] < 8 || loaded["set_delay"] < 2.5 || !near(loaded["interval"], loaded["set_delay"]))
		problems += "loaded: [loaded["travelled"]] tiles at [loaded["interval"]] ds, set [loaded["set_delay"]]"
	if(loaded["stamina_used"] <= east["stamina_used"])
		problems += "loaded: used [loaded["stamina_used"]] stamina, unloaded [east["stamina_used"]]"
	var/list/grass = notes["grass"]
	if(grass["travelled"] < 8 || !near(grass["interval"], 1.875) || grass["set_delay"] != 1.875)
		problems += "grass: [grass["travelled"]] tiles at [grass["interval"]] ds, expected 1.875"
	var/list/blocked = notes["blocked"]
	if(blocked["travelled"] != 3 || blocked["still_moving"])
		problems += "blocked: went [blocked["travelled"]] tiles, moving [blocked["still_moving"]]"
	var/list/tired = notes["tired"]
	// One step can be paid for by a natural recovery tick landing first.
	if(tired["travelled"] > 1 || tired["still_moving"])
		problems += "tired: went [tired["travelled"]] tiles, moving [tired["still_moving"]]"
	for(var/list/row in samples)
		if(!row["driver"])
			continue
		if(!row["same_loc"])
			problems += "[row["leg"]] [row["x"]],[row["y"]]: rider off the bicycle tile"
		if(row["rider_sx"] || row["rider_sy"])
			problems += "[row["leg"]] [row["x"]],[row["y"]]: rider offset [row["rider_sx"]],[row["rider_sy"]]"
		if(row["rider_glide"] != row["bike_glide"])
			problems += "[row["leg"]] [row["x"]],[row["y"]]: rider glide [row["rider_glide"]] != bicycle [row["bike_glide"]]"
	if(problems.len)
		notes["problems"] = problems
		throw EXCEPTION(jointext(problems, "; "))
