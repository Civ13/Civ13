// Native probe for code/modules/persistence/standby_prepare.dm; run by run.py with the
// real standby_prepare.dm, ClearMap (functions.dm) and decode_turf_grid_runs/turf_grid_runs
// (loading.dm) beside these stubs.
#define TICK_CHECK stoplag()
// del() clears every reference, so a deleted atom reads as null.
#define QDEL_GONE(D) (!(D))

/world
	maxx = 6
	maxy = 5
	maxz = 2
	turf = /turf/plain

/turf/plain
/turf/grass
/turf/floor/lava
/turf/spawner/New()
	..()
	new /obj/made(src)

/turf/proc/ChangeTurf(path, tell_universe = 1, force_lighting_update = FALSE)
	if(!path) return
	if(path == type) return src
	return new path(src)

/obj/thing
/obj/made
/obj/map_metadata
	var/ID = "probe"
/atom/movable/lighting_overlay
/atom/movable/lighting_fullbright
/mob/animal
/mob/new_player

/datum/restart_stub
	var/standby = FALSE
	var/startup_hold = FALSE
	var/busy = FALSE

var/global/datum/restart_stub/persistence_restart = new
var/global/persistence_active_operation
var/global/obj/map_metadata/map
var/global/mob/dview_mob
var/global/map_storage/map_storage = new
var/global/list/phase_lines = list()
var/global/list/deferred_calls = list()

/map_storage

/proc/stoplag()
	sleep(1)
	return 1

/proc/qdel(datum/D)
	del(D)

/proc/persistence_load_phase_log(phase, started)
	phase_lines += phase
	return world.timeofday

/proc/set_floor_icon_updates_deferred(deferred)
	deferred_calls += deferred

var/global/list/failures = list()
/proc/check(ok, message)
	if(!ok) failures += message

/proc/write_hint(maxx = world.maxx, id = "probe", list/grid)
	fdel("map_saves/validated.json")
	fdel("map_saves/map.txt")
	text2file("[id]\n1\n", "map_saves/map.txt")
	var/list/turfs = list("1" = turf_grid_runs(grid))
	text2file(json_encode(list("version" = 2, "kind" = "candidate", "maxx" = maxx, "maxy" = world.maxy, "maxz" = 2, "turfs" = turfs)), "map_saves/validated.json")

/proc/wanted_grid()
	var/list/grid = list()
	for(var/y = 1 to world.maxy)
		for(var/x = 1 to world.maxx)
			var/type = /turf/grass
			if(x == 2 && y == 2) type = /turf/spawner
			if(x == 3 && y == 3) type = /turf/floor/lava
			if(x == 1 && y == 1) type = /turf/plain
			grid += type
	return grid

/proc/run_probe()
	map = new /obj/map_metadata(locate(1, 1, 1))
	dview_mob = new /mob/animal(null)
	var/obj/thing/thing = new(locate(4, 4, 1))
	var/obj/thing/high = new(locate(4, 4, 2))
	var/mob/animal/animal = new(locate(5, 5, 1))
	var/mob/new_player/lobby = new(null)
	var/atom/movable/lighting_overlay/overlay = new(locate(2, 2, 1))
	var/list/grid = wanted_grid()

	// Not a standby: nothing is read or done.
	write_hint(grid = grid)
	map_storage.prepare_standby_world()
	sleep(5)
	var/turf/first = locate(2, 2, 1)
	check(!QDEL_GONE(thing) && first.type == /turf/plain, "a world that is not a standby must not prepare")

	// A record for other dimensions or another map is not used.
	write_hint(maxx = 7, grid = grid)
	check(!map_storage.read_standby_prepare_hint(), "a record for other dimensions must not be used")
	write_hint(id = "elsewhere", grid = grid)
	check(!map_storage.read_standby_prepare_hint(), "a record for another map must not be used")

	persistence_restart.standby = TRUE
	persistence_restart.startup_hold = TRUE
	write_hint(grid = grid)
	check(map_storage.read_standby_prepare_hint(), "the last save's record must be read")
	// The old world's save removes the record; the standby already holds it.
	fdel("map_saves/validated.json")
	map_storage.prepare_standby_world()
	while(map_storage.standby_preparing) sleep(1)

	check(QDEL_GONE(thing) && QDEL_GONE(high) && QDEL_GONE(animal), "boot map objects and mobs must be cleared")
	check(!QDEL_GONE(lobby) && !QDEL_GONE(map) && !QDEL_GONE(overlay) && !QDEL_GONE(dview_mob), "lobby mobs, map metadata, lighting and the view mob must stay")
	var/cell = 0
	for(var/y = 1 to world.maxy)
		for(var/x = 1 to world.maxx)
			var/want = grid[++cell]
			var/turf/T = locate(x, y, 1)
			if(want == /turf/floor/lava) check(T.type == /turf/plain, "lava must be left to the load")
			else check(T.type == want, "turf [x],[y] must be [want], is [T.type]")
	var/turf/upper = locate(2, 2, 2)
	check(upper.type == /turf/plain, "a level the record does not hold must be left alone")
	var/obj/made/made = locate() in locate(2, 2, 1)
	check(made && map_storage.standby_kept_objects && map_storage.standby_kept_objects[made], "what a prepared turf made must be kept for the load")
	check(deferred_calls.len >= 2 && deferred_calls[deferred_calls.len] == FALSE, "floor icon updates must be deferred, then released")
	check(("standby preparation, 28 turfs set from the last save" in phase_lines), "the turf step must log its count: [json_encode(phase_lines)]")
	check(!map_storage.standby_prepare_hint, "the record must be dropped once used")

	// The load's ClearMap keeps what the turf pass made and deletes anything newer.
	var/obj/thing/later = new(locate(5, 1, 1))
	map_storage.ClearMap()
	check(!QDEL_GONE(made), "the load's clear must keep what a prepared turf made")
	check(QDEL_GONE(later), "the load's clear must delete objects made after preparation")
	check(!map_storage.standby_kept_objects, "the kept list is used once")

	// standby_load stops a running preparation and waits for it.
	for(var/i = 1 to 6) new /obj/thing(locate(i, 1, 1))
	for(var/x = 1 to world.maxx)
		var/turf/T = locate(x, 4, 1)
		T.ChangeTurf(/turf/plain)
	write_hint(grid = grid)
	map_storage.standby_prepare_stop = FALSE
	map_storage.read_standby_prepare_hint()
	map_storage.prepare_standby_world()
	check(map_storage.standby_preparing, "preparation runs in the background")
	map_storage.stop_standby_prepare()
	check(!map_storage.standby_preparing, "stop must wait for the preparation to end")
	check(locate(/obj/thing) in world, "a stopped clear leaves the rest to the load")
	var/turf/row = locate(1, 4, 1)
	check(row.type == /turf/plain, "a stopped preparation must not change turfs")
	map_storage.prepare_standby_world()
	sleep(3)
	check(!map_storage.standby_preparing && row.type == /turf/plain, "a stopped standby must not prepare again")

/world/New()
	..()
	spawn(1)
		try
			run_probe()
		catch(var/exception/e)
			failures += "probe error: [e] on [e.file]:[e.line]"
		text2file(json_encode(list("failures" = failures.len, "messages" = failures)), "result.json")
		shutdown()
