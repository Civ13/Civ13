// Headless full-game motorcycle ride regression. ride.py appends it to a
// temporary copy of civ13.dme. For each cardinal direction a rider who free
// walked onto the bike's tile (so it still carries a pixel offset) boards
// through MouseDrop_T, starts the engine with the handles, drives a few tiles,
// brakes and dismounts. The rider must sit squarely on the bike, never collide
// with itself, keep the reins, and glide with the bike on every leg. Production
// movement code runs unchanged; this file only drives it.
var/global/datum/motorcycle_ride_probe/motorcycle_ride_probe = new

/mob/living/human/motorcycle_ride_actor/ssd_check()
	return FALSE

/datum/motorcycle_ride_probe
	var/list/samples = list()
	var/list/notes = list()
	var/list/frames = list()

/datum/motorcycle_ride_probe/New()
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

/datum/motorcycle_ride_probe/proc/ready()
	return ticker && processScheduler && ticker.current_state >= GAME_STATE_PREGAME

/datum/motorcycle_ride_probe/proc/playing()
	return ticker && ticker.current_state == GAME_STATE_PLAYING

/datum/motorcycle_ride_probe/proc/wait_for(proc_name, limit)
	var/until = world.time + limit
	while(!call(src, proc_name)())
		if(world.time > until)
			throw EXCEPTION("timeout waiting for [proc_name]")
		sleep(5)

/datum/motorcycle_ride_probe/proc/carve_square()
	// A plain paved square on the surface level, away from map edges.
	var/z = world.maxz >= 2 ? 2 : 1
	var/cx = round(world.maxx / 2)
	var/cy = round(world.maxy / 2)
	for(var/dx = -14 to 14)
		for(var/dy = -14 to 14)
			var/turf/T = locate(cx + dx, cy + dy, z)
			if(!T)
				return null
			for(var/atom/movable/A in T)
				if(A.density || ismob(A) || istype(A, /obj/structure) || istype(A, /obj/covers))
					A.loc = null // Fixture road only; immediate, unlike queued qdel.
			if(T.type != /turf/floor/plating/road)
				T = new /turf/floor/plating/road(T)
	sleep(10)
	return locate(cx, cy, z)

/datum/motorcycle_ride_probe/proc/frame(label, dirname, obj/structure/vehicle/V, mob/living/human/R)
	var/list/f = list("label" = label, "dir" = dirname, "bike_x" = V.x, "bike_y" = V.y, "bike_sx" = V.step_x, "bike_sy" = V.step_y, "bike_dir" = V.dir, "bike_state" = V.icon_state, "bike_layer" = V.layer, "rider_x" = R.x, "rider_y" = R.y, "rider_sx" = R.step_x, "rider_sy" = R.step_y, "rider_px" = R.pixel_x, "rider_py" = R.pixel_y, "rider_dir" = R.dir, "rider_layer" = R.layer, "rider_lying" = R.lying, "driver" = (V.driver == R))
	frames += list(f)
	return f

/datum/motorcycle_ride_probe/proc/sample(label, obj/structure/vehicle/V, mob/living/human/R)
	samples += list(list("label" = label, "t" = world.time, "x" = V.x, "y" = V.y, "bike_glide" = V.glide_size, "rider_glide" = R.glide_size, "same_loc" = (R.loc == V.loc), "rider_sx" = R.step_x, "rider_sy" = R.step_y, "driver" = (V.driver == R), "brute" = R.getBruteLoss(), "delay" = V.vehicle_m_delay))

/datum/motorcycle_ride_probe/proc/ride(turf/start, direction, dirname)
	var/obj/structure/vehicle/motorcycle/m125/full/V = new(start)
	V.dir = direction
	sleep(10) // engine, axis and fuel wiring finish on spawn().
	var/mob/living/human/motorcycle_ride_actor/R = new(start)
	R.m_intent = "walk"
	R.a_intent = I_HELP
	sleep(5)
	// A player who free-walked onto the bike's tile: still on that tile, but
	// shifted right and up by a free-movement offset.
	R.step_x = 13
	R.step_y = 11
	R.human_subtile_offset_owned = TRUE
	R.dir = direction
	R.glide_size = 4 // a walking glide left by the free-movement adapter
	frame("before_mount", dirname, V, R)
	V.MouseDrop_T(R, R)
	if(V.driver != R)
		throw EXCEPTION("[dirname]: rider did not take the handles")
	R.dir = direction
	V.update_icon()
	var/list/mounted = frame("mounted", dirname, V, R)
	var/obj/item/vehicleparts/wheel/handle = R.get_active_hand()
	if(!istype(handle))
		throw EXCEPTION("[dirname]: no handles in hand")
	handle.attack_self(R) // engine on
	sleep(5)
	handle.attack_self(R) // first gear
	sleep(2)
	var/start_x = V.x
	var/start_y = V.y
	var/until = world.time + 60
	var/lastx = V.x
	var/lasty = V.y
	while(world.time < until && abs(V.x - start_x) + abs(V.y - start_y) < 8)
		sleep(world.tick_lag)
		if(V.x != lastx || V.y != lasty)
			lastx = V.x
			lasty = V.y
			sample(dirname, V, R)
			if(V.driver == R && abs(V.x - start_x) + abs(V.y - start_y) == 2)
				frame("riding", dirname, V, R)
		if(V.driver != R)
			break
	var/travelled = abs(V.x - start_x) + abs(V.y - start_y)
	var/list/summary = list("travelled" = travelled, "mounted_sx" = mounted["rider_sx"], "mounted_sy" = mounted["rider_sy"], "driver_after" = (V.driver == R), "brute" = R.getBruteLoss(), "weakened" = R.weakened)
	while(V.axis.currentspeed > 0 && V.driver == R)
		handle.secondary_attack_self(R)
		sleep(5)
	sleep(10)
	if(V.driver == R)
		V.attack_hand(R)
		sleep(10)
	summary["after_dismount_glide"] = R.glide_size
	summary["after_dismount_driver"] = "[V.driver]"
	notes[dirname] = summary
	qdel(V)
	R.loc = null
	sleep(5)

/datum/motorcycle_ride_probe/proc/run_probe()
	var/failure = null
	try
		wait_for("ready", 9000)
		ticker.admin_started = TRUE
		if(ticker.pregame_timeleft > 1)
			ticker.pregame_timeleft = 1
		wait_for("playing", 3000)
		var/turf/start = carve_square()
		if(!start)
			throw EXCEPTION("no clear square found")
		notes["start"] = "[start.x],[start.y],[start.z] [start.type]"
		var/list/dirs = list("east" = EAST, "north" = NORTH, "west" = WEST, "south" = SOUTH)
		for(var/dirname in dirs)
			ride(start, dirs[dirname], dirname)
		check()
	catch(var/exception/e)
		failure = "[e.name]"
	var/list/result = list("passed" = isnull(failure), "failure" = failure, "notes" = notes, "samples" = samples, "frames" = frames, "tick_lag" = world.tick_lag)
	text2file(json_encode(result), "result.json")
	world.log << "MOTORCYCLE PROBE DONE [failure]"
	sleep(5)
	del(world)

/datum/motorcycle_ride_probe/proc/check()
	var/list/problems = list()
	for(var/dirname in list("east", "north", "west", "south"))
		var/list/s = notes[dirname]
		if(s["mounted_sx"] || s["mounted_sy"])
			problems += "[dirname]: seated at offset [s["mounted_sx"]],[s["mounted_sy"]]"
		if(s["travelled"] < 8)
			problems += "[dirname]: bike stopped after [s["travelled"]] tiles"
		if(!s["driver_after"])
			problems += "[dirname]: rider fell off"
		if(s["brute"] > 0)
			problems += "[dirname]: rider hurt ([s["brute"]] brute)"
		if(s["after_dismount_glide"] != 4)
			problems += "[dirname]: dismount left glide [s["after_dismount_glide"]]"
	for(var/list/row in samples)
		if(!row["driver"])
			continue
		if(!row["same_loc"])
			problems += "[row["label"]] [row["x"]],[row["y"]]: rider off the bike tile"
		if(row["rider_sx"] || row["rider_sy"])
			problems += "[row["label"]] [row["x"]],[row["y"]]: rider offset [row["rider_sx"]],[row["rider_sy"]]"
		if(row["rider_glide"] != row["bike_glide"])
			problems += "[row["label"]] [row["x"]],[row["y"]]: rider glide [row["rider_glide"]] != bike [row["bike_glide"]]"
	if(problems.len)
		notes["problems"] = problems
		throw EXCEPTION(jointext(problems, "; "))
