// Native probe for height-aware line of sight. Compiled with
// code/modules/visibility/los_terrain.dm and the height parser from
// code/modules/1713/terrain_height.dm, plus the small stubs below.
// Writes each field's ground-hidden cells for run.py to compare against its
// Python reference, and times the sweep.
/datum/var/should_save = TRUE
/obj/map_metadata
	var/terrain_height_file = null
	var/tmp/datum/terrain_heights/terrain_heights_cache = null
/obj/map_metadata/proc/terrain_heights()
	if (!terrain_heights_cache)
		terrain_heights_cache = terrain_heights_parse(file2text(terrain_height_file), world.maxx, world.maxy, world.maxz)
	return terrain_heights_cache.error ? null : terrain_heights_cache
var/global/obj/map_metadata/map
var/global/invalidated = 0
/proc/root_tree_family(atom/A)
	return FALSE
/proc/los_invalidate(atom/A, possible = FALSE)
	invalidated++
/datum/los_snapshot
	var/datum/los_terrain_field/terrain
	var/terrain_tile_x = 0
	var/terrain_tile_y = 0
/mob
	var/resting = FALSE
	var/lying = FALSE
	var/prone = FALSE
/proc/ishuman(A)
	return istype(A, /mob)

/world
	maxx = 500
	maxy = 350
	maxz = 2

/world/New()
	..()
	spawn(1)
		los_terrain_probe()

/proc/los_terrain_probe()
	map = new
	map.terrain_height_file = "heights.txt"
	var/datum/terrain_heights/H = map.terrain_heights()
	if (!H)
		world.log << "LOS_TERRAIN FAIL heights did not load"
		shutdown()
		return
	var/list/eyes = json_decode(file2text("eyes.json"))
	var/list/out = list()
	var/mob/M = new
	for (var/list/e in eyes)
		M.loc = locate(e[1], e[2], 2)
		M.step_x = e[3]
		M.step_y = e[4]
		M.lying = e[5]
		var/list/r = los_terrain_for(M, e[6])
		var/list/hidden = list()
		if (r)
			var/datum/los_terrain_field/F = r[1]
			for (var/i = -F.radius, i <= F.radius, i++)
				for (var/j = -F.radius, j <= F.radius, j++)
					if (!F.visible(i, j, LOS_GROUND_TOP))
						hidden += "[i],[j]"
			out += list(list("tile" = list(r[2], r[3]), "hidden" = hidden))
		else
			out += list(null)
	// Timing: fresh sweeps (cache cleared) and cached lookups.
	var/start = world.timeofday
	var/builds = 0
	for (var/n = 1 to 4)
		for (var/list/e in eyes)
			los_terrain_cache = list()
			M.loc = locate(e[1], e[2], 2)
			M.step_x = e[3]
			M.step_y = e[4]
			M.lying = e[5]
			los_terrain_for(M, 9)
			builds++
	var/build_ds = world.timeofday - start
	start = world.timeofday
	for (var/n = 1 to 20000)
		los_terrain_for(M, 9)
	var/cached_ds = world.timeofday - start
	// Grading (terrain_heights/set_level) clears the cache and refreshes viewers.
	los_terrain_heights_changed(locate(M.x, M.y, 2))
	var/cleared = !los_terrain_cache.len && invalidated == 1
	text2file(json_encode(list("fields" = out, "builds" = builds, "build_ds" = build_ds, "cached_ds" = cached_ds, "cleared" = cleared)), "result.json")
	world.log << "LOS_TERRAIN DONE"
	shutdown()
