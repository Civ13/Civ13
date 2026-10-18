// Full production callbacks, isolated startup and temporary native storage.
// Prepared only: compile/runtime and signatures are not yet accepted evidence.
/world
	hub = ""
	hub_password = ""
	maxx = 16
	maxy = 16
	maxz = 1
	turf = /turf/reserved_lighting_probe
	area = /area/reserved_lighting_probe
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/turf/reserved_lighting_probe/New()
	return
/turf/reserved_lighting_probe/replaced
/area/reserved_lighting_probe
	dynamic_lighting = TRUE
/area/reserved_lighting_probe/New()
	return
/obj/reserved_lighting_probe/New()
	return
/proc/reserved_assert(ok, message)
	if (!ok)
		text2file("FAIL: [message]", "result.txt")
		CRASH(message)
/proc/reserved_drain()
	var/process/lighting_sources/S = new
	var/process/lighting_overlays/O = new
	var/passes = 0
	while (lighting_update_lights.len || lighting_update_overlays.len || O.current_list)
		reserved_assert(++passes < 1000, "queue did not settle")
		S.run_time_tick_usage = world.tick_usage
		S.run_time_tick_usage_allowance = 100
		S.fire()
		O.run_time_tick_usage = world.tick_usage
		O.run_time_tick_usage_allowance = 100
		O.fire()
		sleep(1)
/proc/reserved_snapshot(label)
	var/list/rows = list()
	for (var/turf/T in world)
		// Interior is intentionally not visible. Compare normal cells and halo.
		if (T.x >= 6 && T.x <= 11 && T.y >= 6 && T.y <= 11)
			continue
		var/list/lums = list()
		for (var/datum/lighting_corner/C in T.corners)
			lums += list(list(C.x, C.y, C.lum_r, C.lum_g, C.lum_b, C.active, C.masters.len, C.affecting.len))
		rows += list(list(T.x,T.y,T.lighting_overlay ? T.lighting_overlay.color : null,lums,T.affecting_lights ? T.affecting_lights.len : 0))
	text2file(json_encode(list("label"=label,"rows"=rows)), "states.jsonl")
/world/New()
	OpenPort("none")
	try
		reserved_assert(!world.port && !OpenPort(0), "PORT_OPEN")
		config = new
		map = null
		var/candidate = world.params["reserved"] == "1"
		for (var/turf/T in world)
			turfs |= T
			if (candidate && T.x >= 5 && T.x <= 12 && T.y >= 5 && T.y <= 12)
				T.lighting_reserved = TRUE
		create_lighting("Midday")
		var/overlays = 0
		var/list/unique_corners = list()
		for (var/turf/T in world)
			if (T.lighting_overlay)
				overlays++
			for (var/datum/lighting_corner/C in T.corners)
				unique_corners |= C
		reserved_assert(overlays == (candidate ? 220 : 256), "overlay allocation count")
		reserved_assert(unique_corners.len == 289, "unchanged full corner grid")
		var/obj/reserved_lighting_probe/torch = new(locate(3,8,1))
		torch.light_range = 14
		torch.light_power = 0.7
		torch.light_color = "#cc8844"
		torch.light = new /datum/light_source(torch,torch)
		reserved_drain()
		reserved_snapshot("torch")
		var/process/time_of_day_change/P = new
		processes.time_of_day_change = P
		time_of_day = "Night"
		P.apply_daylight("Night", P.lighting_revision)
		reserved_snapshot("night")
		torch.loc = locate(13,8,1)
		torch.light.force_update()
		reserved_drain()
		reserved_snapshot("moved")
		var/turf/occluder = locate(4,8,1)
		occluder.opacity = TRUE
		occluder.recalc_atom_opacity()
		occluder.reconsider_lights()
		reserved_drain()
		reserved_snapshot("opacity")
		occluder.opacity = FALSE
		occluder.recalc_atom_opacity()
		occluder.reconsider_lights()
		reserved_drain()
		var/turf/center = locate(8,8,1)
		center.activate_reserved_lighting()
		reserved_drain()
		if (candidate)
			for (var/turf/T in range(1,center))
				reserved_assert(T.lighting_overlay, "activation reconstructs halo overlay")
				reserved_assert(T.lighting_overlay.TOD == time_of_day, "activation current TOD")
		// Native replacement must fail open and preserve shared corner identities.
		var/turf/target = locate(10,10,1)
		target.ChangeTurf(/turf/reserved_lighting_probe/replaced)
		reserved_assert(!target.lighting_reserved && target.lighting_overlay, "replacement activates")
		// Actual production entry save/import, no live or existing saves.
		var/map_storage/storage = new
		var/savefile/F = new("reserved-roundtrip.sav")
		storage.saving_z = 1
		var/index = storage.BuildVarDirectory(F,center)
		// Historical/malformed runtime fields cannot restore a reservation.
		F.cd = storage.entry_path(F,index)
		F["lighting_reserved"] << TRUE
		storage.clear_bookkeeping()
		var/turf/destination = locate(7,7,1)
		storage.Load_Entry(F,index,destination)
		reserved_assert(!destination.lighting_reserved && destination.lighting_overlay, "import activates")
		reserved_snapshot("activated")
		text2file("PASS", "result.txt")
	catch (var/exception/E)
		text2file("FAIL: [E]", "result.txt")
	shutdown()
