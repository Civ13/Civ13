// Unformed underground level on a real production map. Test-only:
// tests/underground_level/real_map.py appends this file to a temporary copy of
// civ13.dme with one dig-down map selected. The production boot, saver and
// startup restore run unchanged; the probe digs a short tunnel the way a
// player opens cells, saves, and in a second process checks the restore.
var/global/datum/underground_real_probe/underground_real_probe = new

/datum/underground_real_probe
	should_save = FALSE
	var/phase = "startup"
	var/started_tod = 0
	var/seen_pending = FALSE
	var/list/result = list()
	var/list/checks = list()
	var/list/failures = list()

/datum/underground_real_probe/New()
	started_tod = world.timeofday
	spawn(10)
		drive()

/datum/underground_real_probe/proc/wall()
	var/elapsed = world.timeofday - started_tod
	if(elapsed < 0) elapsed += 864000
	return elapsed / 10

/datum/underground_real_probe/proc/mark(name)
	phase = name
	fdel("phase.json")
	text2file(json_encode(list("phase" = name, "wall_s" = wall())), "phase.json")
	world.log << "UNDERGROUND phase [name] at [wall()] s"

/datum/underground_real_probe/proc/check(condition, message)
	checks += message
	if(!condition)
		failures += message
		world.log << "UNDERGROUND FAIL: [message]"
	return !!condition

/datum/underground_real_probe/proc/wait_for(proc_name, deadline_ds, message)
	var/until = world.time + deadline_ds
	while(!call(src, proc_name)())
		if(world.time > until) throw EXCEPTION(message)
		sleep(10)

/datum/underground_real_probe/proc/scheduler_ready()
	return ticker && processScheduler && processes && config && ticker.current_state >= GAME_STATE_PREGAME

/datum/underground_real_probe/proc/game_playing()
	return ticker && ticker.current_state == GAME_STATE_PLAYING

/datum/underground_real_probe/proc/cave_ready()
	return dug_underground_boot_done && (!building_standing_wanted() || building_standing_present())

/datum/underground_real_probe/proc/startup_resolved()
	if(persistence_startup_recovery_status == "pending")
		seen_pending = TRUE
		return FALSE
	return seen_pending || persistence_startup_recovery_status == "unresolved"

/datum/underground_real_probe/proc/start_round()
	wait_for("scheduler_ready", 18000, "Scheduler and ticker never became ready")
	config.webhook_can_fire = FALSE
	world.visibility = 0
	result["map"] = list("id" = map.ID, "maxx" = world.maxx, "maxy" = world.maxy, "byond" = "[world.byond_version].[world.byond_build]")
	if(ticker.current_state < GAME_STATE_PLAYING)
		ticker.admin_started = TRUE
		if(ticker.pregame_timeleft > 1) ticker.pregame_timeleft = 1
	wait_for("game_playing", 18000, "Round did not reach PLAYING")

// Formed cells of the cave level and how many of them are open.
/datum/underground_real_probe/proc/census(z, name)
	var/formed = 0
	var/open = 0
	var/lit_open = 0
	var/strays = 0
	var/awake = 0
	var/area/caves = dug_underground_area()
	for(var/turf/T in block(locate(1, 1, z), locate(world.maxx, world.maxy, z)))
		// Unformed rock: the native fill, or a compiled level's own unformed type.
		if(istype(T, /turf/sky/building))
			if(T.loc != caves && T.type == /turf/sky/building) strays++
			if(!building_cell_asleep(T)) awake++
		else
			formed++
			if(!T.density)
				open++
				if(T.lighting_overlay) lit_open++
		TICK_CHECK
	var/list/row = list("formed" = formed, "open" = open, "lit_open" = lit_open, "unformed_outside_caves" = strays, "unformed_awake" = awake, "maxz" = world.maxz, "cave_z" = z)
	result[name] = row
	return row

/datum/underground_real_probe/proc/surface_spot()
	for(var/tries = 1, tries <= 200000, tries++)
		var/turf/T = locate(rand(30, world.maxx - 60), rand(30, world.maxy - 30), underground_surface_z())
		if(!istype(T, /turf/floor) || T.density || istype(T, /turf/floor/beach/water)) continue
		if(underground_above(T) || dug_underground_rock(T) == /turf/wall/rockwall) continue
		if(locate(/obj/structure/multiz) in T) continue
		var/turf/U = locate(T.x, T.y, underground_level_z())
		if(!dug_underground_unformed(U) && (U.density || !istype(U, /turf/floor))) continue
		return T
	return null

/datum/underground_real_probe/proc/write()
	start_round()
	mark("boot-level")
	var/started = world.timeofday
	wait_for("cave_ready", 6000, "The cave and standing levels were never added")
	result["levels_ready_s"] = (world.timeofday - started) / 10
	var/z = underground_level_z()
	var/compiled = map.underground_compiled_z
	if(!check(compiled ? z == compiled : z == building_base_maxz() + 1, "write: the cave is the compiled level or the first added level ([z])")) return
	check(multiz_level_below(underground_surface_z()) == z && multiz_level_above(z) == underground_surface_z(), "write: the cave lies under the surface")
	var/list/fresh = census(z, "fresh")
	if(!compiled)
		check(fresh["formed"] == 1 && !fresh["unformed_outside_caves"] && !fresh["unformed_awake"], "write: a fresh cave is unformed rock in the cave area, asleep, with only its marker formed")
	mark("dig")
	var/turf/surface = surface_spot()
	if(!check(surface, "write: found diggable ground")) return
	result["dig_at"] = "[surface.x],[surface.y]"
	var/turf/below = dug_underground_open_below(null, surface, TRUE)
	check(below && !below.density, "write: digging down opens the cell below")
	var/turf/head = below
	for(var/i = 1 to 24)
		var/turf/next = dug_underground_form(get_step(head, EAST))
		if(!next) break
		if(next.density && !istype(next, /turf/wall/rockwall/bedrock))
			next = next.ChangeTurf(/turf/floor/dirt)
		head = locate(next.x, next.y, next.z)
	var/list/dug = census(z, "dug")
	result["tunnel_end"] = "[head.x],[head.y]"
	var/exposed = 0
	for(var/turf/T in block(locate(1, 1, z), locate(world.maxx, world.maxy, z)))
		if(istype(T, /turf/sky/building) || T.density) continue
		for(var/d in alldirs)
			if(dug_underground_unformed(get_step(T, d))) exposed++
		TICK_CHECK
	check(!exposed, "write: no open cell touches unformed rock ([exposed])")
	check(dug["open"] >= 1 && dug["lit_open"] == dug["open"], "write: open cells are lit ([dug["lit_open"]] of [dug["open"]])")
	// --deep N: shafts down to depth N, each with a short tunnel, the way a
	// player digs on from the deepest level.
	var/deep = text2num(world.params["deep"])
	if(deep > 1)
		mark("deep")
		var/list/deep_rows = list()
		var/turf/shaft = below
		for(var/depth = 2 to deep)
			var/started_dig = world.timeofday
			if(!check(underground_create(depth), "write: depth [depth] is admitted ([world_z_budget.last_error])")) break
			var/dz = underground_z_at(depth)
			check(dz == world.maxz && underground_depth_of(dz) == depth && multiz_level_below(underground_z_at(depth - 1)) == dz, "write: depth [depth] lies under depth [depth - 1]")
			var/create_s = (world.timeofday - started_dig) / 10
			// Find a spot near the shaft that is open rock below.
			var/turf/next_below
			for(var/r = 0, r <= 12 && !next_below, r++)
				for(var/turf/C in range(r, shaft))
					if(get_dist(C, shaft) != r || C.density || C.x < 3 || C.y < 3 || C.x > world.maxx - 30 || C.y > world.maxy - 3) continue
					next_below = dug_underground_open_below(null, C, TRUE, depth)
					if(next_below)
						shaft = C
						break
			if(!check(next_below && !next_below.density, "write: digging down opens a cell on depth [depth]")) break
			var/turf/dhead = next_below
			for(var/i = 1 to 12)
				var/turf/dnext = dug_underground_form(get_step(dhead, EAST))
				if(!dnext) break
				if(dnext.density && !istype(dnext, /turf/wall/rockwall/bedrock))
					dnext = dnext.ChangeTurf(/turf/floor/dirt)
				dhead = locate(dnext.x, dnext.y, dnext.z)
			var/list/row = census(dz, "deep[depth]")
			row["create_s"] = create_s
			deep_rows["[depth]"] = row["formed"]
			check(row["lit_open"] == row["open"] && !row["unformed_awake"], "write: depth [depth] open cells lit, unformed asleep")
			shaft = next_below
		result["deep"] = deep_rows
	// --storeys N: grow the open-air levels a roof would add, up to N built.
	var/storeys = text2num(world.params["storeys"])
	if(storeys)
		mark("storeys")
		while(building_levels_built() < storeys)
			if(!check(building_allocate_level(world.maxz + 1), "write: open-air level [world.maxz + 1] is admitted ([world_z_budget.last_error])")) break
		result["storeys"] = building_levels_built()
	result["maxz"] = world.maxz
	var/obj/item/stone = new(below)
	check(!dug_underground_unformed(locate(1, 2, z)) || !locate(2, 2, z).Enter(stone), "write: unformed rock refuses entry")
	qdel(stone)
	mark("save")
	started = world.timeofday
	var/saved = ticker.savemap()
	result["save_s"] = (world.timeofday - started) / 10
	check(saved, "write: the world save completed ([map_storage.last_error])")

/datum/underground_real_probe/proc/read()
	mark("startup-load")
	wait_for("startup_resolved", 36000, "Startup recovery never resolved")
	result["startup_load_s"] = wall()
	result["startup_status"] = persistence_startup_recovery_status
	if(!check(isnull(persistence_startup_recovery_status), "read: startup restored the save ([map_storage.last_error])")) return
	start_round()
	var/z = underground_level_z()
	if(!check(z, "read: the restored world has its cave")) return
	var/deep = text2num(world.params["deep"])
	if(deep > 1)
		check(underground_levels().len == deep, "read: all [deep] underground levels came back ([underground_levels().len])")
		var/list/expect_deep = list()
		for(var/pair in splittext(world.params["deep_formed"], "-"))
			var/list/kv = splittext(pair, ".")
			if(kv.len == 2) expect_deep[kv[1]] = text2num(kv[2])
		for(var/depth = 2 to deep)
			var/dz = underground_z_at(depth)
			if(!check(dz && multiz_level_below(underground_z_at(depth - 1)) == dz, "read: depth [depth] lies under depth [depth - 1]")) continue
			var/list/row = census(dz, "restored_deep[depth]")
			check(row["formed"] == expect_deep["[depth]"], "read: depth [depth] formed cells came back ([row["formed"]] of [expect_deep["[depth]"]])")
			check(!row["unformed_outside_caves"] && !row["unformed_awake"] && row["lit_open"] == row["open"], "read: depth [depth] unformed asleep in the cave area, open cells lit")
	var/list/restored = census(z, "restored")
	if(world.params["maxz"])
		check(world.maxz == text2num(world.params["maxz"]), "read: every added level came back ([world.maxz] of [world.params["maxz"]])")
	var/expected = text2num(world.params["formed"])
	check(restored["formed"] == expected, "read: every formed cell came back ([restored["formed"]] of [expected])")
	check(!restored["unformed_outside_caves"], "read: unformed cells are back in the cave area ([restored["unformed_outside_caves"]])")
	check(!restored["unformed_awake"], "read: unformed cells stay asleep ([restored["unformed_awake"]])")
	check(restored["lit_open"] == restored["open"], "read: open cells are lit after the load ([restored["lit_open"]] of [restored["open"]])")
	mark("resave")
	var/started = world.timeofday
	var/saved = ticker.savemap()
	result["resave_s"] = (world.timeofday - started) / 10
	check(saved, "read: the second save completed ([map_storage.last_error])")

/datum/underground_real_probe/proc/drive()
	var/failure
	var/mode = world.params["real_mode"]
	try
		switch(mode)
			if("write") write()
			if("read") read()
			else throw EXCEPTION("Unknown mode")
	catch(var/exception/e)
		failure = "[e] at [e.file]:[e.line]"
		world.log << "UNDERGROUND EXCEPTION: [failure]"
	mark("finished")
	result["mode"] = mode
	result["passed"] = !failure && !failures.len
	result["failure"] = failure
	result["checks"] = checks
	result["failed_checks"] = failures
	result["wall_s"] = wall()
	fdel("result.json")
	text2file(json_encode(result), "result.json")
	world.log << (result["passed"] ? "PASS: underground real-map [mode]" : "FAIL: underground real-map [mode]")
	sleep(5)
	del(world)
