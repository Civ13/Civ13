// Real-map zone persistence measurement (#3590). Test-only: real_map.py appends
// this file to a temporary copy of civ13.dme with one production map selected.
// The production saver, validator, startup recovery, ticker.loadmap and area
// constructors run unchanged; the probe starts the round, builds a few roofs
// and spawn groups, drives the saves and loads and records what it saw.
var/global/datum/zone_real_probe/zone_real_probe = new

#define ZONE_REAL_MOD 65521
#define ZONE_REAL_GROUP_EMPTY "zone3590-emptied"
#define ZONE_REAL_GROUP_KEPT "zone3590-kept"

/datum/zone_real_probe
	should_save = FALSE
	var/mode
	var/phase = "startup"
	var/started_tod = 0
	var/clearmap_calls = 0
	var/seen_pending = FALSE
	var/list/result = list()
	var/list/checks = list()
	var/list/failures = list()

/datum/zone_real_probe/New()
	started_tod = world.timeofday
	world.Profile(PROFILE_START)
	// The lag capture (time_track.dm) clears and stops a profile it believes
	// it started; a save or load always looks like lag to it.
	profile_dump_running = TRUE
	spawn(10)
		drive()

// Counts map clears so a rejected save can be shown to stop before the first.
/map_storage/ClearMap()
	if(zone_real_probe) zone_real_probe.clearmap_calls++
	return ..()

/datum/zone_real_probe/proc/wall()
	var/elapsed = world.timeofday - started_tod
	if(elapsed < 0) elapsed += 864000
	return elapsed / 10

/datum/zone_real_probe/proc/mark(name)
	phase = name
	fdel("phase.json")
	text2file(json_encode(list("phase" = name, "wall_s" = wall())), "phase.json")
	world.log << "ZONE3590 phase [name] at [wall()] s"

/datum/zone_real_probe/proc/check(condition, message)
	checks += message
	if(!condition)
		failures += message
		world.log << "ZONE3590 FAIL: [message]"
	return !!condition

/datum/zone_real_probe/proc/wait_for(proc_name, deadline_ds, message)
	var/until = world.time + deadline_ds
	while(!call(src, proc_name)())
		if(world.time > until) throw EXCEPTION(message)
		sleep(10)

/datum/zone_real_probe/proc/scheduler_ready()
	return ticker && processScheduler && processes && config && ticker.current_state >= GAME_STATE_PREGAME

/datum/zone_real_probe/proc/game_playing()
	return ticker && ticker.current_state == GAME_STATE_PLAYING

// Startup marks an existing save "pending" before it imports it; the import
// leaves null (restored) or "unresolved" (held).
/datum/zone_real_probe/proc/startup_resolved()
	if(persistence_startup_recovery_status == "pending")
		seen_pending = TRUE
		return FALSE
	return seen_pending || persistence_startup_recovery_status == "unresolved"

/datum/zone_real_probe/proc/profile_restart()
	world.Profile(PROFILE_RESTART)

/datum/zone_real_probe/proc/profile_dump(name)
	fdel("profile-[name].json")
	text2file(world.Profile(PROFILE_REFRESH, null, "json"), "profile-[name].json")

/datum/zone_real_probe/proc/timed(name, started)
	var/elapsed = world.timeofday - started
	if(elapsed < 0) elapsed += 864000
	result["[name]_s"] = elapsed / 10
	return elapsed / 10

/datum/zone_real_probe/proc/coordinates(list/source)
	var/list/rows = list()
	for(var/turf/T in source) rows += "[T.x],[T.y],[T.z]"
	return rows

// Zone identities with their membership, the roofs and the five spawn
// registries. Membership is a count and two position sums per zone and level,
// so two inventories agree only when every cell kept its zone.
/datum/zone_real_probe/proc/inventory(name)
	var/list/rows = list()
	var/unidentified = 0
	for(var/z = 1, z <= world.maxz, z++)
		for(var/y = 1, y <= world.maxy, y++)
			for(var/x = 1, x <= world.maxx, x++)
				var/turf/T = locate(x, y, z)
				var/area/A = T.loc
				var/list/row = rows[A]
				if(!row)
					row = list("id" = A.persistence_zone_id, "type" = "[A.type]", "name" = A.name, "cells" = 0, "levels" = list(), "sum_x" = 0, "sum_xy" = 0)
					rows[A] = row
					if(!A.persistence_zone_id) unidentified++
				row["cells"]++
				row["levels"]["[z]"]++
				row["sum_x"] = (row["sum_x"] + x) % ZONE_REAL_MOD
				row["sum_xy"] = (row["sum_xy"] + (x * y) % ZONE_REAL_MOD) % ZONE_REAL_MOD
				TICK_CHECK
	var/list/zones = list()
	for(var/area/A in rows) zones += list(rows[A])
	var/empty_registered = 0
	for(var/area/A in area_list)
		if(rows[A]) continue
		empty_registered++
		zones += list(list("id" = A.persistence_zone_id, "type" = "[A.type]", "name" = A.name, "cells" = 0, "levels" = list(), "sum_x" = 0, "sum_xy" = 0))
	var/list/roofs = list()
	for(var/obj/roof/R in world)
		if(!isturf(R.loc)) continue
		var/area/A = get_area(R)
		roofs += list(list("x" = R.x, "y" = R.y, "z" = R.z, "type" = "[R.type]", "switch" = R.switch_area, "base" = "[R.current_area_type]", "area" = "[A.type]", "zone" = A.persistence_zone_id))
	var/list/named = list()
	for(var/group in latejoin_turfs) named[group] = coordinates(latejoin_turfs[group])
	var/world_areas = 0
	for(var/area/A in world) world_areas++
	var/list/document = list("zones" = zones, "unidentified_zones" = unidentified, "empty_registered_zones" = empty_registered, "roofs" = roofs,
		"spawns" = list("latejoin" = named, "start" = coordinates(newplayer_start), "join" = coordinates(latejoin), "paradrop" = coordinates(paradrop_landmarks), "supply" = coordinates(supplydrop_turfs)),
		"census" = list("world_areas" = world_areas, "area_list" = area_list.len, "world_contents" = world.contents.len, "authoritative" = persistence_spawns_authoritative, "wall_s" = wall()))
	fdel("inventory-[name].json")
	text2file(json_encode(document), "inventory-[name].json")
	return document

/datum/zone_real_probe/proc/solid_ground(turf/T)
	if(!istype(T, /turf/floor) || T.density) return FALSE
	if(!(istype(T, /turf/floor/grass) || istype(T, /turf/floor/dirt) || istype(T, /turf/floor/beach/sand) || istype(T, /turf/floor/winter))) return FALSE
	if(locate(/obj/roof) in T) return FALSE
	for(var/atom/movable/M in T)
		if(M.density) return FALSE
	return TRUE

// One supported roof on solid ground in every climate zone of every level, the
// way a player's first hut changes the zone under it.
/datum/zone_real_probe/proc/build_roofs()
	var/list/climates = list("tundra", "taiga", "temperate", "sea", "semiarid", "desert", "savanna", "jungle")
	var/list/built = list()
	var/list/areas = area_list.Copy()
	for(var/area/caribbean/A in areas)
		if(istype(A, /area/caribbean/roofed) || !(A.climate in climates)) continue
		var/list/levels = list()
		var/seen = 0
		for(var/turf/floor/T in A)
			if(++seen > 400000 || levels.len >= world.maxz) break
			if(!(seen % 20000)) sleep(world.tick_lag)
			if(levels["[T.z]"] || !solid_ground(T)) continue
			// Away from the map edge, where borders and travel edges live.
			if(T.x < 12 || T.y < 12 || T.x > world.maxx - 12 || T.y > world.maxy - 12) continue
			levels["[T.z]"] = TRUE
			new /obj/structure/roof_support(T)
			new /obj/roof(T)
			built += list(list("x" = T.x, "y" = T.y, "z" = T.z, "base" = "[A.type]", "climate" = A.climate))
	return built

/datum/zone_real_probe/proc/start_round()
	wait_for("scheduler_ready", 18000, "Scheduler and ticker never became ready")
	config.webhook_can_fire = FALSE
	world.visibility = 0
	result["map"] = list("id" = map.ID, "type" = "[map.type]", "maxx" = world.maxx, "maxy" = world.maxy, "maxz" = world.maxz, "durable_metadata" = map.uses_durable_metadata(), "byond" = "[world.byond_version].[world.byond_build]")
	if(ticker.current_state < GAME_STATE_PLAYING)
		ticker.admin_started = TRUE
		if(ticker.pregame_timeleft > 1) ticker.pregame_timeleft = 1
	wait_for("game_playing", 18000, "Round did not reach PLAYING")

/datum/zone_real_probe/proc/save(name)
	mark(name)
	profile_restart()
	var/started = world.timeofday
	var/saved = ticker.savemap()
	timed(name, started)
	profile_dump(name)
	result["[name]_stream_plan"] = map_storage.last_stream_level_plan
	check(saved, "[name]: the world save completed ([map_storage.last_error])")
	return saved

/datum/zone_real_probe/proc/write()
	start_round()
	mark("settle")
	sleep(text2num(world.params["settle_ds"]) || 600)
	mark("build")
	var/turf/kept
	for(var/tries = 1, tries <= 200000 && !kept, tries++)
		var/turf/T = locate(rand(20, world.maxx - 20), rand(20, world.maxy - 20), 1)
		if(solid_ground(T)) kept = T
	check(kept, "write: found solid ground for the kept spawn group")
	latejoin_turfs[ZONE_REAL_GROUP_EMPTY] = list()
	latejoin_turfs[ZONE_REAL_GROUP_KEPT] = list(kept)
	var/list/built = build_roofs()
	result["roofs_built"] = built
	// Unsupported roofs fall five seconds after they are built.
	sleep(80)
	var/standing = 0
	for(var/obj/roof/R in world) standing++
	result["roofs_standing"] = standing
	check(built.len > 0 && standing >= built.len, "write: every built roof is still standing ([standing] of [built.len])")
	inventory("before-save")
	if(!save("save")) return
	mark("inventory")
	var/list/after = inventory("saved")
	check(!after["unidentified_zones"], "write: every zone with turfs has a saved identity")

/datum/zone_real_probe/proc/load_again(name)
	mark(name)
	profile_restart()
	var/started = world.timeofday
	var/loaded = ticker.loadmap()
	timed(name, started)
	profile_dump(name)
	check(loaded, "[name]: the load completed ([map_storage.last_error])")
	if(loaded) announce_restored_round_once()
	mark("[name]-inventory")
	inventory(name)
	return loaded

/datum/zone_real_probe/proc/spawn_groups()
	mark("spawn-groups")
	var/list/emptied = latejoin_turfs[ZONE_REAL_GROUP_EMPTY]
	var/list/kept = latejoin_turfs[ZONE_REAL_GROUP_KEPT]
	check(persistence_spawns_authoritative, "spawns: the saved registries are authoritative after the load")
	if(!check(islist(emptied) && !emptied.len && islist(kept) && kept.len == 1, "spawns: the emptied group is still empty and the kept group has its one turf")) return
	var/turf/home = kept[1]
	var/turf/apart = locate(home.x + 3, home.y, home.z)
	var/humans = human_mob_list.len
	var/mob/living/human/H = new(apart)
	H.job_spawn_location = ZONE_REAL_GROUP_EMPTY
	check(job_master.relocate(H) == FALSE && H.loc == apart, "spawns: a job whose saved group is empty is refused and not moved")
	check(!latejoin_turfs[ZONE_REAL_GROUP_EMPTY].len, "spawns: the refusal invented no destination")
	H.job_spawn_location = ZONE_REAL_GROUP_KEPT
	job_master.relocate(H)
	check(H.loc == home, "spawns: a job with a saved destination is placed on it")
	// The remedy the refusal names: an administrator places a spawn point.
	var/turf/placed = locate(home.x + 6, home.y, home.z)
	new /obj/effect/landmark{name = ZONE_REAL_GROUP_EMPTY}(placed)
	check(latejoin_turfs[ZONE_REAL_GROUP_EMPTY].len == 1, "spawns: an administrator's new spawn point joins the emptied group")
	H.job_spawn_location = ZONE_REAL_GROUP_EMPTY
	job_master.relocate(H)
	check(H.loc == placed, "spawns: the job joins at the administrator's spawn point")
	// A new body finishes its species and icon setup a moment after New.
	sleep(30)
	qdel(H)
	sleep(5)
	result["humans_before_after"] = list(humans, human_mob_list.len)

/datum/zone_real_probe/proc/read()
	mark("startup-load")
	wait_for("startup_resolved", 36000, "Startup recovery never resolved")
	timed("startup_load_resolved_at", started_tod)
	profile_dump("startup-load")
	result["startup_status"] = persistence_startup_recovery_status
	if(!check(isnull(persistence_startup_recovery_status) && persistence_spawns_authoritative, "read: startup restored the save with authoritative spawns ([map_storage.last_error])")) return
	start_round()
	mark("startup-load-inventory")
	inventory("load-1")
	var/loads = text2num(world.params["loads"]) || 3
	for(var/i = 2, i <= loads, i++)
		if(!load_again("load-[i]")) return
		// Let deferred deletions and the garbage queue run before sampling.
		mark("load-[i]-settle")
		sleep(300)
	spawn_groups()
	if(!save("resave")) return
	mark("resave-inventory")
	inventory("resaved")

// A save this build must not load: startup may not clear the map, and the
// runner then proves the files are byte-identical.
/datum/zone_real_probe/proc/reject()
	mark("reject")
	wait_for("startup_resolved", 36000, "Startup recovery never resolved")
	// Give a wrongly admitted import time to reach its map clear.
	sleep(100)
	result["startup_status"] = persistence_startup_recovery_status
	result["last_error"] = map_storage.last_error
	result["clearmap_calls"] = clearmap_calls
	check(persistence_startup_recovery_status == "unresolved", "reject: startup holds the save unresolved")
	check(!clearmap_calls, "reject: the map was never cleared")
	check(!persistence_spawns_authoritative, "reject: no saved spawn registry was published")
	check(findtext("[map_storage.last_error]", "[world.params["reason"]]"), "reject: refused for the named reason ([map_storage.last_error])")

/datum/zone_real_probe/proc/drive()
	var/failure
	try
		mode = world.params["real_mode"]
		switch(mode)
			if("write") write()
			if("read") read()
			if("reject") reject()
			else throw EXCEPTION("Unknown real-map mode")
	catch(var/exception/e)
		failure = "[e] at [e.file]:[e.line]"
		world.log << "ZONE3590 EXCEPTION: [failure]"
	var/failed_phase = phase
	mark("finished")
	result["mode"] = mode
	result["passed"] = !failure && !failures.len
	result["failure"] = failure
	result["failed_phase"] = failure ? failed_phase : null
	result["checks"] = checks
	result["failed_checks"] = failures
	result["clearmap_calls"] = clearmap_calls
	result["wall_s"] = wall()
	fdel("result.json")
	text2file(json_encode(result), "result.json")
	world.log << (result["passed"] ? "PASS: zone real-map [mode]" : "FAIL: zone real-map [mode]")
	sleep(5)
	del(world)

#undef ZONE_REAL_MOD
#undef ZONE_REAL_GROUP_EMPTY
#undef ZONE_REAL_GROUP_KEPT
