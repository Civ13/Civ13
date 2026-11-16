// One-off migration of a map's compiled underground to unformed rock
// (docs/underground-level.md). Gaia, Desert, Jungle, Barren and the Moon used
// to ship a filled cave level at z 1; their saves still hold it. The host
// boots a copy of the region with -params migrate_underground=1
// (shard_group.py migrate-underground): the world restores the save, lifts
// people, loose objects and crates on the old level to the nearest clear
// surface tile above, turns every cell of the level into unformed rock, saves,
// writes underground_migration.json and ends. The host then validates the new
// save before it replaces the region's.

/proc/underground_migration_requested()
	return islist(world.params) && world.params["migrate_underground"] == "1"

/hook/startup/proc/underground_migration()
	if (underground_migration_requested())
		underground_migration_run()
	return TRUE

// Lifted, not deleted: people (players and their bodies), loose objects and
// crates. Everything else on the old level goes with it.
/proc/underground_migration_lifted(atom/movable/AM)
	return ishuman(AM) || istype(AM, /obj/item) || istype(AM, /obj/structure/closet)

/proc/underground_migration_clear(turf/T)
	if (!istype(T, /turf/floor) || T.density || istype(T, /turf/floor/beach/water/deep) || istype(T, /turf/floor/lava))
		return FALSE
	for (var/atom/movable/AM in T)
		if (AM.density && !ismob(AM))
			return FALSE
	return TRUE

// The nearest clear surface tile to (x, y), out to 15 tiles; the tile itself
// when nothing nearer is clear.
/proc/underground_migration_spot(x, y, surface_z)
	var/turf/center = locate(x, y, surface_z)
	for (var/r = 0 to 15)
		for (var/turf/T in range(r, center))
			if (get_dist(T, center) == r && underground_migration_clear(T))
				return T
	return center

/proc/underground_migration_run()
	set waitfor = FALSE
	var/list/report = list("version" = 1, "ok" = FALSE)
	try
		// The startup import restores the save; a world without one has nothing to move.
		while (!ticker || !map || persistence_startup_recovery_status == "pending" || (persistence_restart && persistence_restart.startup_hold))
			sleep(10)
		config.webhook_can_fire = FALSE
		world.visibility = 0
		report["map"] = map.ID
		if (persistence_startup_recovery_status)
			throw EXCEPTION("The save did not restore: [persistence_startup_recovery_status] ([map_storage.last_error])")
		report["restored"] = !!map_storage.round_restored
		var/z = map.underground_compiled_z
		if (!z)
			throw EXCEPTION("This map has no compiled underground level")
		var/surface_z = z + 1
		var/list/lifted = list("players" = list(), "bodies" = 0, "items" = 0, "crates" = 0)
		var/deleted = 0
		var/ladders = 0
		var/reset = 0
		var/area/caves = dug_underground_area()
		var/list/strays = list()
		for (var/turf/T in block(locate(1, 1, z), locate(world.maxx, world.maxy, z)))
			// The map's control room (admin area) stays as compiled.
			if (istype(T.loc, /area/caribbean/admin))
				continue
			var/turf/up
			for (var/atom/movable/AM in T)
				if (istype(AM, /atom/movable/lighting_overlay) || istype(AM, /atom/movable/lighting_fullbright) || isobserver(AM) || istype(AM, /mob/new_player) || istype(AM, /obj/map_metadata))
					continue
				if (underground_migration_lifted(AM))
					if (!up)
						up = underground_migration_spot(T.x, T.y, surface_z)
					if (istype(AM, /obj/structure/closet))
						lifted["crates"]++ // Its contents come up inside it.
					else if (ishuman(AM))
						var/mob/living/human/H = AM
						if (H.ckey)
							lifted["players"] += H.ckey
						else
							lifted["bodies"]++
						to_chat(H, SPAN_NOTICE("The ground shifts and you find yourself above ground."))
					else
						lifted["items"]++
					AM.forceMove(up)
				else
					// A ladder or shaft that led down leads nowhere now.
					if (istype(AM, /obj/structure/multiz))
						var/turf/above = locate(T.x, T.y, surface_z)
						for (var/obj/structure/multiz/M in above)
							qdel(M)
							ladders++
					qdel(AM)
					deleted++
			if (T.type != /turf/sky/building/unformed)
				T.lighting_clear_overlay()
				new /turf/sky/building/unformed(T)
				reset++
			var/turf/now = locate(T.x, T.y, z)
			if (now.loc != caves)
				strays += now
			TICK_CHECK
		if (strays.len)
			caves.contents.Add(strays)
		report["lifted"] = lifted
		report["deleted"] = deleted
		report["surface_ladders_removed"] = ladders
		report["cells_reset"] = reset
		report["cells_moved_to_cave_area"] = strays.len
		var/started = world.timeofday
		if (!ticker.savemap())
			throw EXCEPTION("The migrated world did not save: [map_storage.last_error]")
		report["save_seconds"] = round((world.timeofday - started) / 10, 0.1)
		report["generation"] = fexists("map_saves/save_complete.txt") ? trim(file2text("map_saves/save_complete.txt")) : null
		report["ok"] = TRUE
	catch (var/exception/e)
		report["error"] = "[e] at [e.file]:[e.line]"
	world.log << "Underground migration: [json_encode(report)]"
	if (fexists("underground_migration.json"))
		fdel("underground_migration.json")
	text2file(json_encode(report), "underground_migration.json")
	sleep(5)
	del(world)
