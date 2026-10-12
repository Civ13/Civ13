/world
	maxx = 32
	maxy = 32
	maxz = 1
	turf = /turf/lighting_queue_probe
	area = /area/lighting_queue_probe
	fps = 20
/world/OpenPort(port)
	if(port != "none")
		return FALSE
	return ..()
/world/Error(exception/E)
	text2file("ENGINE ERROR [E.name] [E.file]:[E.line]", "result.txt")
	del(world)
/turf/lighting_queue_probe/New()
	return
/area/lighting_queue_probe
	dynamic_lighting = TRUE
/area/lighting_queue_probe/New()
	return
/obj/lighting_queue_probe/New()
	return
/proc/lighting_queue_assert(ok, message)
	if(!ok)
		throw EXCEPTION(message)
/proc/lighting_queue_drain(process/P, overlays = FALSE)
	var/passes = 0
	while((overlays ? lighting_update_overlays.len : lighting_update_lights.len) || P.current_list)
		P.run_time_tick_usage = world.tick_usage
		P.run_time_tick_usage_allowance = 1
		var/result = P.fire()
		// Mirror finished() without starting the unrelated scheduler.
		if(result != PROCESS_TICK_CHECK_RETURNED_EARLY)
			P.current = null
			P.current_list = null
		lighting_queue_assert(++passes < 10000, "queue starvation")
		sleep(world.tick_lag)
	lighting_queue_assert(!P.current && !P.current_list, "completed references")
/world/New()
	text2file("ENTER", "startup.txt")
	world.OpenPort("none")
	try
		config = new
		for(var/turf/T in world)
			for(var/i in 1 to 4)
				if(!T.corners[i])
					T.corners[i] = new /datum/lighting_corner(T, LIGHTING_CORNER_DIAGONAL[i])
			new /atom/movable/lighting_overlay(T)
		created_lighting_corners_and_overlays = TRUE
		lighting_corners_initialised = TRUE
		sleep(1)
		var/process/lighting_sources/S = new
		var/process/lighting_overlays/O = new
		var/list/owners = list()
		var/list/lights = list()
		for(var/i in 1 to 200)
			var/obj/lighting_queue_probe/A = new(locate((i*7)%30+2,(i*11)%30+2,1))
			A.light_range = 3
			A.light_power = 0.7
			A.light_color = "#cc8844"
			owners += A
			lights += new /datum/light_source(A,A)
		for(var/cycle in 1 to 5)
			for(var/i in 1 to lights.len)
				var/datum/light_source/L = lights[i]
				var/obj/A = owners[i]
				A.loc = locate((i*3+cycle)%30+2,(i*5+cycle)%30+2,1)
				A.light_power = cycle/10
				L.force_update()
			S.run_time_tick_usage = world.tick_usage
			S.run_time_tick_usage_allowance = 0
			S.fire()
			// Cancellation returns unconsumed ownership; replacement transfers it.
			if(cycle == 2)
				S.onKill()
			if(cycle == 3)
				var/process/lighting_sources/replacement = new
				replacement.copyStateFrom(S)
				S.onKill()
				S = replacement
			// Enqueues while a budgeted batch is suspended, including a destroyed source.
			var/obj/lighting_queue_probe/extra = new(locate(8,8,1))
			extra.light_range = 2
			extra.light_power = 0.3
			var/datum/light_source/cancelled = new(extra,extra)
			cancelled.destroy()
			var/datum/light_source/deleted = new(extra,extra)
			deleted.destroy()
			del(deleted)
			// An invalid queued overlay retires through the actual update callback.
			var/atom/movable/lighting_overlay/invalid = new(null,TRUE)
			invalid.needs_update = TRUE
			lighting_update_overlays += invalid
			lighting_queue_drain(S)
			lighting_queue_drain(O,TRUE)
			lighting_queue_assert(!cancelled.applied && !cancelled.needs_update, "cancelled light")
			var/list/signature = list()
			for(var/turf/T in world)
				signature += list(list(T.lighting_overlay.color,T.lighting_overlay.luminosity))
			text2file(json_encode(signature),"states.jsonl")
			for(var/datum/light_source/L in lights)
				lighting_queue_assert(!L.needs_update && L.applied, "source completion")
			for(var/turf/T in world)
				lighting_queue_assert(!T.lighting_overlay.needs_update, "overlay completion")
		text2file("PASS", "result.txt")
	catch(var/exception/E)
		text2file("FAIL [E.name] [E.file]:[E.line]", "result.txt")
	del(world)
