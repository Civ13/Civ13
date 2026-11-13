// A handover's standby world waits while the old world saves, for minutes on
// Gaia. It spends that wait on load work whose result the load would produce
// anyway, so the load itself is shorter:
//   1. it deletes the boot map's mobs and objects, as ClearMap does, and
//   2. it turns every turf into the type the last completed save recorded for
//      it (map_saves/validated.json, read at boot before the old world's save
//      removes it).
// The load still runs ClearMap and sets every turf to the new save's type.
// ChangeTurf to the type a turf already has does nothing, so only cells that
// changed since the last save cost time. Nothing here is trusted: a stale or
// missing record only means less work was done ahead.

/map_storage
	// "z" -> the last save's encoded turf grid (turf_grid_runs), read at boot.
	var/tmp/list/standby_prepare_hint
	var/tmp/standby_preparing = FALSE
	var/tmp/standby_prepare_stop = FALSE

// world/New, before the world can answer the host: the old world's save removes
// validated.json early, and the host starts that save once the standby answers.
/map_storage/proc/read_standby_prepare_hint()
	standby_prepare_hint = null
	try
		if(!map || !fexists("map_saves/validated.json") || !fexists("map_saves/map.txt")) return FALSE
		var/list/meta = splittext(file2text("map_saves/map.txt"), "\n")
		if(!meta.len || meta[1] != map.ID) return FALSE
		var/list/record = json_decode(file2text("map_saves/validated.json"))
		if(!islist(record) || record["maxx"] != world.maxx || record["maxy"] != world.maxy || !islist(record["turfs"])) return FALSE
		standby_prepare_hint = record["turfs"]
		return TRUE
	catch(var/exception/e)
		world.log << "Standby preparation: the last save's turf record was not read ([e])."
		standby_prepare_hint = null
	return FALSE

// Called by the load before it starts (standby_run). Returns once no
// preparation step is running.
/map_storage/proc/stop_standby_prepare()
	standby_prepare_stop = TRUE
	while(standby_preparing)
		sleep(1)
	standby_prepare_hint = null

/map_storage/proc/standby_prepare_allowed()
	return !standby_prepare_stop && persistence_restart && persistence_restart.standby && persistence_restart.startup_hold && !persistence_restart.busy && !persistence_active_operation

/map_storage/proc/prepare_standby_world()
	set waitfor = FALSE
	if(standby_preparing || !standby_prepare_allowed()) return
	standby_preparing = TRUE
	try
		var/started = world.timeofday
		var/cleared = clear_standby_boot_map()
		persistence_load_phase_log("standby preparation, clearing [cleared] boot map mobs and objects", started)
		if(islist(standby_prepare_hint) && standby_prepare_allowed())
			started = world.timeofday
			var/changed = prepare_standby_turfs()
			persistence_load_phase_log("standby preparation, [changed] turfs set from the last save", started)
	catch(var/exception/e)
		world.log << "Standby preparation stopped: [e] on [e.file]:[e.line]. The load does that work itself."
	standby_prepare_hint = null
	standby_preparing = FALSE

// ClearMap's deletions for everything on the map, yielding so the host's status
// and standby_load requests are answered. The load's own ClearMap deletes
// whatever is left, such as anything outside the map.
/map_storage/proc/clear_standby_boot_map()
	var/cleared = 0
	for(var/z = 1, z <= world.maxz, z++)
		for(var/turf/T in block(locate(1, 1, z), locate(world.maxx, world.maxy, z)))
			for(var/atom/movable/thing in T)
				if(ismob(thing))
					if(istype(thing, /mob/new_player) || thing == dview_mob) continue
				else if(!isobj(thing) || istype(thing, /obj/map_metadata) || istype(thing, /atom/movable/lighting_overlay) || istype(thing, /atom/movable/lighting_fullbright))
					continue
				qdel(thing)
				cleared++
			if(TICK_CHECK && !standby_prepare_allowed()) return cleared
	return cleared

// Lava runs callbacks and spreads, so it is left to the load.
/proc/standby_prepare_skips_turf(path)
	return ispath(path, /turf/floor/lava)

/map_storage/proc/prepare_standby_turfs()
	var/changed = 0
	var/list/kept = list()
	set_floor_icon_updates_deferred(TRUE)
	var/stopped = FALSE
	try
		for(var/z = 1, z <= world.maxz && !stopped, z++)
			var/list/grid = decode_turf_grid_runs(standby_prepare_hint["[z]"])
			if(!grid) continue
			var/cell = 0
			for(var/y = 1, y <= world.maxy, y++)
				if(!standby_prepare_allowed())
					stopped = TRUE
					break
				for(var/x = 1, x <= world.maxx, x++)
					var/type = grid[++cell]
					var/turf/T = locate(x, y, z)
					if(!T || T.type == type || standby_prepare_skips_turf(type) || standby_prepare_skips_turf(T.type)) continue
					T = T.ChangeTurf(type, FALSE, FALSE)
					changed++
					// The load clears the map again; keep what this turf made, as
					// the load's own turf pass would have made it after its clear.
					if(T)
						for(var/atom/movable/made in T)
							if(isobj(made) || ismob(made)) kept[made] = TRUE
				TICK_CHECK
	catch(var/exception/e)
		set_floor_icon_updates_deferred(FALSE)
		standby_kept_objects = kept
		throw e
	// The load refreshes every floor of each level it loads (refresh_deferred_floor_icons_level).
	set_floor_icon_updates_deferred(FALSE)
	standby_kept_objects = kept
	return changed
