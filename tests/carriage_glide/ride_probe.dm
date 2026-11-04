// Headless full-game ride regression for #3627. ride.py appends it to a
// temporary copy of civ13.dme. A driver with a fixed walking glide boards
// through MouseDrop_T, hitches two horses, drives east through every gear with
// the real reins, stops and dismounts. Each leg must give the driver, both
// horses and the carriage one shared glide_size (the identified cause was a
// rider keeping its own walking glide while the carriage glided at gallop
// speed). Production movement code runs unchanged; this file only drives it.
var/global/datum/carriage_ride_probe/carriage_ride_probe = new

/mob/living/human/carriage_ride_actor/ssd_check()
	return FALSE

/datum/carriage_ride_probe
	var/list/samples = list()
	var/list/notes = list()

/datum/carriage_ride_probe/New()
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
		drive()

/datum/carriage_ride_probe/proc/ready()
	return ticker && processScheduler && ticker.current_state >= GAME_STATE_PREGAME

/datum/carriage_ride_probe/proc/playing()
	return ticker && ticker.current_state == GAME_STATE_PLAYING

/datum/carriage_ride_probe/proc/wait_for(proc_name, limit)
	var/until = world.time + limit
	while(!call(src, proc_name)())
		if(world.time > until)
			throw EXCEPTION("timeout waiting for [proc_name]")
		sleep(5)

/datum/carriage_ride_probe/proc/clear(turf/T)
	if(!istype(T, /turf/floor) || T.density || istype(T, /turf/floor/beach/water))
		return FALSE
	for(var/atom/movable/A in T)
		if(A.density || ismob(A) || istype(A, /obj/structure) || istype(A, /obj/covers))
			return FALSE
	return TRUE

/datum/carriage_ride_probe/proc/find_road()
	// Carve a plain paved road on the surface level, away from map edges.
	var/z = world.maxz >= 2 ? 2 : 1
	var/x0 = round(world.maxx / 2) - 15
	var/y0 = round(world.maxy / 2)
	for(var/dx = -3 to 60)
		for(var/dy = -3 to 4)
			var/turf/T = locate(x0 + dx, y0 + dy, z)
			if(!T)
				return null
			for(var/atom/movable/A in T)
				if(A.density || ismob(A) || istype(A, /obj/structure) || istype(A, /obj/covers))
					A.loc = null // Fixture road only; immediate, unlike queued qdel.
			if(T.type != /turf/floor/plating/road)
				T = new /turf/floor/plating/road(T)
	sleep(10)
	return locate(x0, y0, z)

/datum/carriage_ride_probe/proc/sample(label, obj/structure/vehicle/carriage/C, mob/living/human/H, list/horses)
	var/list/row = list("label" = label, "t" = world.time, "x" = C.x, "carriage" = C.glide_size, "rider" = H.glide_size, "rider_loc_same" = (H.loc == C.loc), "speed" = C.axis.currentspeed, "delay" = C.vehicle_m_delay)
	var/i = 0
	for(var/mob/living/M in horses)
		row["horse[++i]"] = M.glide_size
	samples += list(row)

/datum/carriage_ride_probe/proc/drive()
	var/failure = null
	try
		wait_for("ready", 9000)
		ticker.admin_started = TRUE
		if(ticker.pregame_timeleft > 1)
			ticker.pregame_timeleft = 1
		wait_for("playing", 3000)
		var/turf/start = find_road()
		if(!start)
			throw EXCEPTION("no clear road found")
		notes["start"] = "[start.x],[start.y],[start.z] [start.type]"
		var/obj/structure/vehicle/carriage/C = new(start)
		C.dir = EAST
		var/mob/living/simple_animal/horse/H1 = new(locate(start.x - 1, start.y - 1, start.z))
		var/mob/living/simple_animal/horse/H2 = new(locate(start.x - 1, start.y + 1, start.z))
		var/mob/living/human/carriage_ride_actor/R = new(locate(start.x - 1, start.y, start.z))
		R.m_intent = "walk"
		R.a_intent = I_HELP
		sleep(5)
		C.MouseDrop_T(H1, R)
		C.MouseDrop_T(H2, R)
		notes["propulsion"] = C.buckled_animal_propulsion
		// A fixed walking glide, as left by a scripted walk or a walking adapter.
		R.glide_size = 4
		C.MouseDrop_T(R, R)
		if(C.driver != R)
			throw EXCEPTION("rider did not take the reins")
		var/obj/item/vehicleparts/wheel/rope/reins = R.get_active_hand()
		if(!istype(reins))
			throw EXCEPTION("no reins in hand")
		R.dir = EAST
		var/list/horses = list(H1, H2)
		var/stop_x = start.x + 50
		for(var/gear = 1 to 3)
			reins.attack_self(R)
			var/until = world.time + (gear == 3 ? 40 : 60)
			var/lastx = C.x
			while(world.time < until && C.x < stop_x)
				sleep(world.tick_lag)
				if(C.x != lastx)
					lastx = C.x
					sample("gear[gear]", C, R, horses)
			if(!C.moving || C.axis.currentspeed <= 0)
				var/list/ahead = list()
				for(var/dy = 0 to 1)
					var/turf/T = locate(C.x + 3, C.y + dy, C.z)
					ahead += "[T] [T ? T.type : null]"
					for(var/atom/movable/A in T)
						ahead += "[A.type] dense=[A.density]"
				throw EXCEPTION("gear[gear]: carriage stopped at x=[C.x]; ahead: [jointext(ahead, ", ")]")
		while(C.axis.currentspeed > 0)
			reins.secondary_attack_self(R)
			sleep(5)
		sleep(30)
		sample("stopped", C, R, horses)
		C.attack_hand(R)
		sleep(5)
		notes["after_dismount"] = list("rider_glide" = R.glide_size, "rider_lease" = ("carriage_glide_owner" in R.vars) ? !!R.vars["carriage_glide_owner"] : "absent", "driver" = "[C.driver]", "in_ontop" = (R in C.ontop))
		check(R, H1, H2, C)
	catch(var/exception/e)
		failure = "[e.name]"
	var/list/result = list("passed" = isnull(failure), "failure" = failure, "notes" = notes, "samples" = samples, "tick_lag" = world.tick_lag)
	text2file(json_encode(result), "result.json")
	world.log << "RIDE PROBE DONE [failure]"
	sleep(5)
	del(world)

/datum/carriage_ride_probe/proc/check(mob/living/human/R, mob/living/H1, mob/living/H2, obj/structure/vehicle/carriage/C)
	var/list/per_gear = list("gear1" = 0, "gear2" = 0, "gear3" = 0)
	for(var/list/row in samples)
		var/label = row["label"]
		if(!(label in per_gear))
			continue
		per_gear[label]++
		var/expected = 32 * world.tick_lag / max(row["delay"] + 1, world.tick_lag)
		if(!row["rider_loc_same"])
			throw EXCEPTION("[label] x=[row["x"]]: rider left the carriage turf")
		if(abs(row["carriage"] - expected) > 0.0001)
			throw EXCEPTION("[label] x=[row["x"]]: carriage glide [row["carriage"]] != [expected]")
		for(var/key in list("rider", "horse1", "horse2"))
			if(row[key] != row["carriage"])
				throw EXCEPTION("[label] x=[row["x"]]: [key] glide [row[key]] != carriage [row["carriage"]]")
	for(var/label in per_gear)
		if(per_gear[label] < 2)
			throw EXCEPTION("[label]: only [per_gear[label]] legs sampled")
	var/list/after = notes["after_dismount"]
	if(after["rider_glide"] != 4 || after["rider_lease"] || after["in_ontop"] || C.driver)
		throw EXCEPTION("dismount did not restore the rider's own glide")
	notes["legs"] = per_gear
