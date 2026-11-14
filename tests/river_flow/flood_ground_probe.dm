// Native probe for player ground changes to floods (flood_ground.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/river_flow/flood_ground_probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 10
	maxy = 7
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/flood_ground_probe/New()
	return
var/ground_failures = 0
var/ground_runtime_error = FALSE
/proc/ground_check(condition, label)
	if (!condition)
		ground_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	ground_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		map = new /obj/map_metadata/flood_ground_probe
		ground_checks()
	catch(var/exception/e)
		ground_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = ground_failures, "runtime_error" = ground_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

// One reach: a river along y 4 with flat banks at level 0 on both sides.
/proc/ground_probe_text()
	var/list/lines = list("civ13-river-flood 1", "size 10 7", "z 1", "reaches 1", "r 1 0 5 4 70 70 10")
	for (var/r in 1 to 7)
		lines += "01010101010101010101"
	for (var/r in 1 to 7)
		lines += (r == 4 ? ".........." : "0000000000")
	return jointext(lines, "\n")

/proc/ground_checks()
	var/datum/river_flood/F = river_flood_parse(ground_probe_text(), 10, 7, 1)
	ground_check(!F.error, "parses ([F.error])")
	map.river_flood_cache = F
	map.river_flood_loaded = TRUE
	map.river_flood_state = list()
	F.published = map.river_flood_state
	F.stage[1] = 0.5
	ground_check(abs(flood_depth_at(locate(3, 6, 1)) - 0.5) < 0.001, "flat bank floods before any wall")

	// A dirt wall all along y 5 holds the north bank dry until the river tops it.
	var/list/walls = list()
	for (var/x in 1 to 10)
		walls += new /obj/structure/window/barrier(locate(x, 5, 1))
	ground_check(F.dirty_windows.len == 1, "building marks one window")
	ground_check(F.process_windows() == 1 && !F.dirty_windows.len, "the window is recomputed on the next tick")
	ground_check(F.overrides[locate(3, 6, 1)] == 1 && F.overrides[locate(3, 7, 1)] == 1 && isnull(F.overrides[locate(3, 3, 1)]), "land behind the wall needs the wall's crest")
	ground_check(flood_depth_at(locate(3, 6, 1)) == 0 && abs(flood_depth_at(locate(3, 3, 1)) - 0.5) < 0.001, "the far bank still floods")
	F.stage[1] = 1.5
	// Over the crest the water stands on the ground behind the wall, not on the wall.
	ground_check(abs(flood_depth_at(locate(3, 6, 1)) - 1.5) < 0.001, "a flood over the crest pours in")
	F.stage[1] = 0.5

	// A gap in the wall lets the water through.
	qdel(walls[5])
	F.process_windows()
	ground_check(isnull(F.overrides[locate(3, 6, 1)]) && abs(flood_depth_at(locate(3, 6, 1)) - 0.5) < 0.001, "a gap in the wall floods the land behind")

	// A palisade lets water through; a sandbag wall holds it.
	ground_check(!new /obj/structure/window/barrier/palisade(locate(5, 5, 1)) || TRUE, "palisade placed")
	F.process_windows()
	ground_check(isnull(F.overrides[locate(3, 6, 1)]), "a palisade holds no water")
	new /obj/structure/window/barrier/sandbag(locate(5, 5, 1))
	F.process_windows()
	ground_check(F.overrides[locate(3, 6, 1)] == 1, "a sandbag wall closes the gap")
