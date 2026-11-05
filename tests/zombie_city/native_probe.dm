// Headless zombie city generation probe. Test-only: native_probe.py appends
// it to a temporary copy of civ13.dme with maps/zombie_city/zombie_city.dmm
// selected. It generates one city from the seed in world.params, writes the
// layout manifest, the ASCII grid and a result record, then shuts the world
// down. No client, no round, no saves.
var/global/datum/zombie_city_probe/zombie_city_probe = new

/datum/zombie_city_probe
	var/started_tod = 0

/datum/zombie_city_probe/New()
	if (!all_species || !all_species.len)
		makeDatumRefLists()
	if (!config)
		load_configuration()
		initialize_chemical_reagents()
		initialize_chemical_reactions()
	if (config)
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
	started_tod = world.timeofday
	spawn(10)
		drive()

/datum/zombie_city_probe/proc/scheduler_ready()
	return ticker && processScheduler && processes && ticker.current_state >= GAME_STATE_PREGAME

/datum/zombie_city_probe/proc/drive()
	var/failure = null
	var/list/result = list()
	try
		var/until = world.time + 9000
		while (!scheduler_ready())
			if (world.time > until)
				throw EXCEPTION("Scheduler/ticker never became ready")
			sleep(5)
		var/obj/map_metadata/nomads/zombie_city/M = map
		if (!istype(M))
			throw EXCEPTION("map is [map ? map.type : "null"], not zombie_city")
		if (!M.zombie_city)
			throw EXCEPTION("map.zombie_city is not set")
		var/seed = text2num(world.params["seed"])
		if (isnull(seed))
			seed = 1
		var/before = world.timeofday
		var/datum/zombie_city_layout/L = zombie_city_generate(seed, 1, 0)
		var/elapsed = world.timeofday - before
		if (!L)
			throw EXCEPTION("zombie_city_generate returned null for seed [seed]")
		if (zombie_city_generate(seed + 1, 1, 0) != L)
			throw EXCEPTION("a second call did not return the existing layout")
		var/list/manifest = L.manifest()
		manifest["ascii"] = L.ascii_rows
		fdel("layout.json")
		text2file(json_encode(manifest), "layout.json")
		fdel("grid.txt")
		var/grid = ""
		for (var/row in L.ascii_rows)
			grid += row + "\n"
		text2file(grid, "grid.txt")
		var/markers = 0
		for (var/obj/effect/zombie_city/E in world)
			if (E.z == 1)
				markers++
		var/blocks = 0
		if (zombie_horde)
			blocks = zombie_horde.blocks.len
		result = list("seed" = seed, "attempt" = L.attempt, "generation_ds" = L.generation_ds, "probe_elapsed_ds" = elapsed, "markers_in_world" = markers, "horde_blocks" = blocks, "counts" = L.counts)
	catch (var/exception/e)
		failure = "[e.name] ([e.file]:[e.line])"
	result["passed"] = isnull(failure)
	result["failure"] = failure
	result["wall_ds"] = world.timeofday - started_tod
	fdel("result.json")
	text2file(json_encode(result), "result.json")
	world.log << (failure ? "FAIL: zombie city probe: [failure]" : "PASS: zombie city probe")
	sleep(5)
	del(world)
