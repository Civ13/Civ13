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
		if(T.type == /turf/sky/building)
			if(T.loc != caves) strays++
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
		var/turf/T = locate(rand(30, world.maxx - 60), rand(30, world.maxy - 30), DUG_SURFACE_Z)
		if(!istype(T, /turf/floor) || T.density || istype(T, /turf/floor/beach/water)) continue
		if(dug_underground_rock(T) == /turf/wall/rockwall) continue
		return T
	return null

/datum/underground_real_probe/proc/write()
	start_round()
	mark("boot-level")
	var/started = world.timeofday
	wait_for("cave_ready", 6000, "The cave and standing levels were never added")
	result["levels_ready_s"] = (world.timeofday - started) / 10
	var/z = dug_underground_z()
	if(!check(z == building_base_maxz() + 1, "write: the cave is the first added level ([z])")) return
	check(multiz_level_below(DUG_SURFACE_Z) == z && multiz_level_above(z) == DUG_SURFACE_Z, "write: the cave lies under the surface")
	var/list/fresh = census(z, "fresh")
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
		if(next.density && !istype(next, /turf/wall/rockwall/bedrock))
			next = next.ChangeTurf(/turf/floor/dirt)
		head = locate(next.x, next.y, next.z)
	var/list/dug = census(z, "dug")
	result["tunnel_end"] = "[head.x],[head.y]"
	var/exposed = 0
	for(var/turf/T in block(locate(1, 1, z), locate(world.maxx, world.maxy, z)))
		if(T.type == /turf/sky/building || T.density) continue
		for(var/d in alldirs)
			if(dug_underground_unformed(get_step(T, d))) exposed++
		TICK_CHECK
	check(!exposed, "write: no open cell touches unformed rock ([exposed])")
	check(dug["open"] >= 1 && dug["lit_open"] == dug["open"], "write: open cells are lit ([dug["lit_open"]] of [dug["open"]])")
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
	var/z = dug_underground_z()
	if(!check(z, "read: the restored world has its cave")) return
	var/list/restored = census(z, "restored")
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
