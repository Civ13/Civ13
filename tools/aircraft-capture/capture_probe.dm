// Capture-only probe (tools/aircraft-capture): boots Gaia, spawns the airstrip,
// hands the connected DreamSeeker guest a pilot and flies through the
// production seat, control column, timers and movement loop, asking the
// runner for a screenshot at each stage. Never part of a game build.
var/global/datum/flight_probe/flight_probe = new

/mob/living/human/flight_pilot/ssd_check()
	return FALSE

/datum/flight_probe
	var/list/checks = list()
	var/list/log = list()
	var/phase = "startup"
	var/started_tod = 0

/datum/flight_probe/New()
	if(!all_species || !all_species.len)
		makeDatumRefLists()
	if(!config)
		load_configuration()
		initialize_chemical_reagents()
		initialize_chemical_reactions()
	if(config)
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
		config.guests_allowed = TRUE
	started_tod = world.timeofday
	spawn(10)
		drive()

/datum/flight_probe/proc/note(text)
	log += "[world.time]: [text]"
	world.log << "FLIGHT: [text]"

/datum/flight_probe/proc/check(name, condition, details = null)
	checks += list(list("check" = name, "passed" = !!condition, "details" = details))
	note("[condition ? "PASS" : "FAIL"] [name] [details ? json_encode(details) : ""]")

/datum/flight_probe/proc/game_playing()
	return ticker && ticker.current_state == GAME_STATE_PLAYING

/datum/flight_probe/proc/scheduler_ready()
	return ticker && processScheduler && ticker.current_state >= GAME_STATE_PREGAME

/datum/flight_probe/proc/standing_level()
	return multiz_level_above(2) != 0

/datum/flight_probe/proc/wait_for(proc_name, deadline_ds, message)
	var/until = world.time + deadline_ds
	while(!call(src, proc_name)())
		if(world.time > until)
			throw EXCEPTION(message)
		sleep(5)

/datum/flight_probe/proc/land_turf(turf/T)
	return istype(T, /turf/floor) && !istype(T, /turf/floor/beach/water) && !T.density

// A 5 x 18 box of dry ground with open sky above it.
/datum/flight_probe/proc/find_site()
	var/cx = round(world.maxx / 2)
	var/cy = round(world.maxy / 2)
	for (var/r = 0, r <= 120, r += 6)
		for (var/dx = -r, dx <= r, dx += 6)
			for (var/dy = -r, dy <= r, dy += 6)
				if (abs(dx) != r && abs(dy) != r)
					continue
				var/ok = TRUE
				for (var/x = cx + dx, x <= cx + dx + 4 && ok, x++)
					for (var/y = cy + dy - 30, y <= cy + dy + 4 && ok, y++)
						var/turf/T = locate(x, y, 2)
						var/turf/A = locate(x, y, 3)
						if (!land_turf(T) || !istype(A, /turf/sky/building) || (locate(/obj/covers) in A))
							ok = FALSE
				if (ok)
					return locate(cx + dx, cy + dy, 2)
	return null

/datum/flight_probe/proc/clear_box(turf/origin)
	var/n = 0
	for (var/x = origin.x, x <= origin.x + 4, x++)
		for (var/y = origin.y - 30, y <= origin.y + 4, y++)
			var/turf/T = locate(x, y, 2)
			for (var/atom/movable/M in T)
				if (istype(M, /atom/movable/lighting_overlay) || istype(M, /atom/movable/lighting_fullbright) || istype(M, /obj/covers))
					continue
				if (istype(M, /obj/structure) || istype(M, /mob/living) || (istype(M, /obj) && M.density))
					qdel(M)
					n++
	return n

/datum/flight_probe/proc/snapshot(obj/structure/vehicleparts/axis/aircraft/A, label)
	var/turf/T = get_turf(A)
	var/list/s = list("label" = label, "x" = T ? T.x : 0, "y" = T ? T.y : 0, "z" = T ? T.z : 0, "state" = A.flight_state, "gear" = A.currentspeed, "moving" = A.moving, "engine" = A.engine && A.engine.on,
		"shadows" = A.shadows ? A.shadows.len : 0, "ground_view_turfs" = A.ground_view ? A.ground_view.vis_contents.len : 0,
		"anchor" = A.ground_view_anchor ? "[A.ground_view_anchor.x],[A.ground_view_anchor.y],[A.ground_view_anchor.z]" : null, "fuel" = A.engine && A.engine.fueltank ? A.engine.fueltank.reagents.total_volume : 0)
	note("SNAP [json_encode(s)]")
	return s

/datum/flight_probe/proc/wait_state(obj/structure/vehicleparts/axis/aircraft/A, state, deadline_ds)
	var/until = world.time + deadline_ds
	while (A.flight_state != state)
		if (world.time > until)
			return FALSE
		sleep(2)
	return TRUE

/datum/flight_probe/proc/client_present()
	for (var/client/C in clients)
		return TRUE
	return FALSE

// Ask the runner for a screenshot and wait until it has one.
/datum/flight_probe/proc/shot(name)
	sleep(15)
	fdel("shot-[name].done")
	text2file(name, "shot-[name].req")
	var/until = world.time + 300
	while (!fexists("shot-[name].done") && world.time < until)
		sleep(2)
	note("shot [name] [fexists("shot-[name].done") ? "taken" : "TIMED OUT"]")

/datum/flight_probe/proc/drive()
	var/failure = null
	try
		wait_for("scheduler_ready", 9000, "Scheduler never ready")
		ticker.admin_started = TRUE
		if(ticker.pregame_timeleft > 1)
			ticker.pregame_timeleft = 1
		wait_for("game_playing", 3000, "Round did not reach PLAYING")
		wait_for("standing_level", 1200, "Standing building level never added")
		var/turf/origin = find_site()
		if (!origin)
			throw EXCEPTION("No clear site found")
		note("site [origin.x],[origin.y],[origin.z] [origin.type], cleared [clear_box(origin)] objects")
		var/obj/structure/vehicleparts/axis/aircraft/A = build_airstrip(origin)
		check("airstrip_built", istype(A) && A.on_runway())
		update_lighting("Midday", null, FALSE)
		text2file("ready", "cloud-ready.txt")
		wait_for("client_present", 3000, "No client connected")
		var/client/C = clients[1]
		var/obj/structure/bed/chair/drivers/aircraft/seat
		for (var/obj/structure/vehicleparts/frame/F in A.frames())
			seat = seat || (locate(/obj/structure/bed/chair/drivers/aircraft) in get_turf(F))
		var/mob/living/human/flight_pilot/H = new(get_turf(seat))
		sleep(10)
		H.ckey = C.ckey
		sleep(20)
		check("client_is_pilot", C.mob == H, list("mob" = "[C.mob]"))
		var/obj/structure/engine/internal/E = A.engine
		E.fueltank.reagents.add_reagent(E.fuels[1], 300, safety = TRUE)
		seat.buckle_mob(H)
		var/obj/item/vehicleparts/wheel/modular/aircraft/W = A.wheel
		shot("1-parked-on-runway")
		W.attack_self(H)
		sleep(20)
		for (var/i = 1, i <= 5, i++)
			W.attack_self(H)
			sleep(3)
		check("took_off", wait_state(A, AIRCRAFT_LOW, 400), snapshot(A, "after_roll"))
		sleep(10)
		snapshot(A, "low_flight")
		shot("2-low-flight")
		A.climb(H)
		shot("3-cruise")
		A.wheel.turndir(H, "left")
		sleep(20)
		snapshot(A, "after_turn")
		shot("4-cruise-after-turn")
		A.descend(H)
		shot("5-low-flight-again")
		W.secondary_attack_self(H)
		W.secondary_attack_self(H)
		W.secondary_attack_self(H)
		// Lay runway under the plane right before it descends onto it.
		var/turf/c = get_turf(A)
		for (var/x = c.x - 10, x <= c.x + 10, x++)
			for (var/y = c.y - 10, y <= c.y + 10, y++)
				var/turf/G = locate(x, y, 2)
				if (G && !(locate(/obj/covers/roads/modern/runway) in G))
					for (var/obj/structure/wild/wild in G)
						qdel(wild)
					new /obj/covers/roads/modern/runway(G)
		check("landed", A.descend(H) && !A.airborne(), snapshot(A, "landed"))
		W.secondary_attack_self(H)
		shot("6-landed")
	catch(var/exception/e)
		failure = "[e.name] [e.file]:[e.line]"
		note("EXCEPTION [failure]")
	var/failed = 0
	for (var/list/row in checks)
		if (!row["passed"])
			failed++
	text2file(json_encode(list("passed" = isnull(failure) && !failed, "failure" = failure, "failed" = failed, "checks" = checks, "log" = log, "wall_ds" = world.timeofday - started_tod)), "result.json")
	text2file("done", "capture-done.txt")
