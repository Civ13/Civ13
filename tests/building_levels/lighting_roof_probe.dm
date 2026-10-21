/world
	maxx = 10
	maxy = 10
	maxz = 1
	turf = /turf/floor/dirt
	area = /area/caribbean
	hub = ""
	hub_password = ""

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/roof_lighting_tester/New()
	return

/proc/roof_lighting_assert(condition, message)
	if (!condition)
		throw EXCEPTION(message)

/proc/roof_lighting_state(turf/T)
	var/list/renderers = list()
	for (var/atom/movable/lighting_overlay/O in T)
		renderers += list(list("canonical"=(T.lighting_overlay == O), "z"=O.z, "color"=O.color, "last_color"=O.last_color, "luminosity"=O.luminosity))
	var/corner_count = 0
	for (var/datum/lighting_corner/C in T.corners)
		corner_count++
	return list("z"=T.z, "type"="[T.type]", "corners"=corner_count, "renderers"=renderers)

/proc/roof_lighting_count(turf/T)
	var/count = 0
	for (var/atom/movable/lighting_overlay/O in T)
		count++
	return count

/proc/roof_lighting_red(turf/T)
	var/total = 0
	for (var/datum/lighting_corner/C in T.corners)
		total += C.lum_r
	return total

/proc/roof_lighting_drain()
	var/process/lighting_sources/S = new
	var/process/lighting_overlays/O = new
	for (var/pass = 1 to 100)
		if (!lighting_update_lights.len && !lighting_update_overlays.len && !O.current_list)
			return
		S.run_time_tick_usage = world.tick_usage
		S.run_time_tick_usage_allowance = 100
		S.fire()
		O.run_time_tick_usage = world.tick_usage
		O.run_time_tick_usage_allowance = 100
		O.fire()
		sleep(1)
	throw EXCEPTION("lighting queues did not drain")

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.stat_set_event = new
		GLOB.name_set_event = new
		map = new /obj/map_metadata/roof_lighting_tester
		world_z_budget = new /datum/world_z_budget/fixture_admission
		create_lighting("Midday")
		roof_lighting_assert(created_lighting_corners_and_overlays, "production lighting startup completed")
		var/turf/site = locate(3,3,1)
		var/turf/distant = locate(8,8,1)
		var/atom/movable/lighting_overlay/distant_renderer = distant.lighting_overlay
		roof_lighting_assert(roof_lighting_count(distant) == 1 && distant_renderer, "baseline distant lighting owner")
		text2file(json_encode(list("phase"="before_roof", "distant"=roof_lighting_state(distant))), "fixture.jsonl")
		new /obj/structure/roof_support(site)
		var/obj/roof/R = building_construct_roof(site, /obj/roof/wood, null)
		roof_lighting_assert(R && world.maxz == 2, "first roof allocated level")
		sleep(7)
		text2file(json_encode(list("phase"="after_roof", "distant"=roof_lighting_state(distant), "above_distant"=roof_lighting_state(locate(8,8,2)))), "fixture.jsonl")
		// Missing upper corners are recorded independently; this patch only prevents
		// renderer gravity. It does not claim to repair upper lighting initialization.
		roof_lighting_assert(roof_lighting_count(distant) == 1, "distant unroofed tile keeps one lighting overlay")
		roof_lighting_assert(distant.lighting_overlay == distant_renderer && distant_renderer.loc == distant, "first roof preserves distant canonical renderer")
		for (var/turf/T in block(locate(1,1,1), locate(10,10,1)))
			roof_lighting_assert(roof_lighting_count(T) == 1, "first roof preserves ground overlay count")
		var/red_before = roof_lighting_red(distant)
		var/obj/item/flashlight/torch/torch = new(distant)
		torch.on = TRUE
		torch.update_icon()
		roof_lighting_drain()
		text2file(json_encode(list("phase"="torch_on", "corner_red_before"=red_before, "corner_red_after"=roof_lighting_red(distant), "distant"=roof_lighting_state(distant))), "fixture.jsonl")
		roof_lighting_assert(torch.light && torch.light.applied, "actual torch light applied")
		roof_lighting_assert(roof_lighting_red(distant) > red_before, "torch brightens unroofed ground corners")
		roof_lighting_assert(distant_renderer.last_luminosity, "torch-lit ground renderer has positive matrix luminosity")
		torch.on = FALSE
		torch.update_icon()
		roof_lighting_drain()
		roof_lighting_assert(abs(roof_lighting_red(distant) - red_before) < 0.0001, "torch off releases corner light")
		text2file("PASS: first roof lighting", "result.txt")
	catch (var/exception/E)
		world.log << "ROOF LIGHTING exception: [E] at [E.file]:[E.line]"
		text2file("FAIL: [E.name]", "result.txt")
	shutdown()
