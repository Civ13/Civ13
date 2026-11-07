// Level read-back benchmark (tools/savestream/bench/run_level_bench.sh).
// Builds a level shaped like a populated Gaia level (one object per turf
// holding lists, nested lists, list aliases and shared datums), saves it, then
// times the save, the full preflight walk and the import. Run once per format
// to compare: stream=1 (format 5), low_memory=1 (format 4), neither (format 3).
// Writes bench.json beside the .dmb. Overrides roundtrip.dm's world/New.
/obj/item/test/bench
	var/list/tags
	var/list/table
	var/datum/test/owner_note

/world/New()
	OpenPort("none")
	var/list/result = list("format" = world.params["stream"] ? 5 : world.params["low_memory"] ? 4 : 3)
	try
		var/map_storage/initial_storage = map_storage
		map_storage = new /map_storage/roundtrip_fixture(initial_storage.game_id)
		qdel(initial_storage)
		var/size = text2num(world.params["size"]) || 100
		world.maxx = size
		world.maxy = size
		result["size"] = size
		if(world.params["low_memory"] || world.params["stream"])
			map_storage.low_memory_override = TRUE
		// The stream module probes its library on its own: pin the choice.
		map_storage.vars["stream_level_saves_override"] = !!world.params["stream"]
		map = new /obj/map_metadata(locate(1,1,1))
		var/count = 0
		var/datum/test/shared
		for(var/z = 1, z <= world.maxz, z++)
			for(var/y = 1, y <= world.maxy, y++)
				for(var/x = 1, x <= world.maxx, x++)
					var/turf/T = locate(x, y, z)
					T.name = "tile [x]"
					var/obj/item/test/bench/O = new(T)
					O.number = x * y
					O.items = list("a" = x, "b" = y, "c" = list(x, y, "deep" = list(z)))
					O.tags = list("t[x % 7]", "u[y % 5]", x)
					O.table = list("weight" = x + y, "name" = "item [x]", "nested" = list("k" = list(1, 2, 3)))
					O.alias = O.items
					if(count % 16 == 0)
						shared = new /datum/test
						shared.value = count
					O.reference = shared
					if(x % 3 == 0)
						var/obj/item/test/bench/inner = new(O)
						inner.number = count
						inner.items = list("inner" = count)
						inner.reference = shared
					count++
		result["objects"] = count
		var/started = world.timeofday
		if(world.params["profile"]) world.Profile(PROFILE_START | PROFILE_CLEAR)
		check(map_storage.Save_World(), "export failed")
		if(world.params["profile"])
			text2file(world.Profile(PROFILE_STOP | PROFILE_REFRESH, "json"), "profile_save.json")
		result["save_s"] = (world.timeofday - started) / 10
		var/bytes = 0
		for(var/name in flist("map_saves/"))
			if(copytext(name, max(1, length(name) - 3)) == ".sav") bytes += length(file("map_saves/[name]"))
		result["save_bytes"] = bytes
		started = world.timeofday
		if(world.params["profile"]) world.Profile(PROFILE_START | PROFILE_CLEAR)
		check(map_storage.validate_world_save(), "full preflight rejected the save")
		if(world.params["profile"])
			text2file(world.Profile(PROFILE_STOP | PROFILE_REFRESH, "json"), "profile_preflight.json")
		result["preflight_s"] = (world.timeofday - started) / 10
		result["preflight_note"] = map_storage.last_validation_note
		map_storage.ClearMap()
		started = world.timeofday
		if(world.params["profile"]) world.Profile(PROFILE_START | PROFILE_CLEAR)
		check(map_storage.Load_World(), "import failed")
		if(world.params["profile"])
			text2file(world.Profile(PROFILE_STOP | PROFILE_REFRESH, "json"), "profile_load.json")
		result["load_s"] = (world.timeofday - started) / 10
		var/obj/item/test/bench/probe = locate(/obj/item/test/bench) in locate(world.maxx, world.maxy, 2)
		check(probe && probe.number == world.maxx * world.maxy && probe.alias == probe.items && probe.table["nested"]["k"][3] == 3, "bench object lost after import")
		check(!errors.len, "unexpected errors")
		result["ok"] = TRUE
	catch(var/exception/e)
		result["error"] = "[e] at [e.file]:[e.line]"
	text2file(json_encode(result), "bench.json")
	world.log << json_encode(result)
	shutdown()
