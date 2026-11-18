// Native probe for opening dug-out rock to the sky (code/modules/1713/open_cave_roof.dm).
// Full production sources with ordinary startup disabled; run with
// python3 tests/ecology_spawning/run_linux.py . tests/open_cave_roof/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 10
	maxy = 10
	maxz = 1
	turf = /turf/floor/dirt/underground
	area = /area/caribbean/void/caves
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/open_cave_roof_probe/New()
	return
/mob/living/human/open_cave_roof_probe/New()
	return
/mob/living/human/open_cave_roof_probe/update_icons()
	return

var/open_roof_failures = 0
var/open_roof_runtime_error = FALSE
/proc/open_roof_check(condition, label)
	if (!condition)
		open_roof_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	open_roof_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/open_cave_roof_probe
		open_roof_probe_run()
	catch(var/exception/e)
		open_roof_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = open_roof_failures, "runtime_error" = open_roof_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/open_roof_mine(x, y)
	var/turf/T = locate(x, y, 1)
	T.ChangeTurf(/turf/floor/dirt)
	return locate(x, y, 1)

/proc/open_roof_probe_run()
	var/area/cave = get_area(locate(5, 5, 1))
	open_roof_check(istype(cave, /area/caribbean/void/caves) && cave.location == AREA_INSIDE, "fixture is cave rock")
	// Column x = 1 is open ground outside the mountain.
	var/area/caribbean/sky = new
	sky.location = AREA_OUTSIDE
	for (var/y = 1 to 10)
		var/turf/G = open_roof_mine(1, y)
		ChangeArea(G, sky)
	var/mob/living/human/open_cave_roof_probe/H = new(locate(1, 1, 1))

	var/turf/rock = locate(2, 5, 1)
	open_roof_check(findtext(rock.open_cave_roof_refusal(H), "Mine the rock"), "solid rock must be mined first")
	var/turf/edge = open_roof_mine(2, 5)
	var/turf/inner = open_roof_mine(3, 5)
	open_roof_check(isnull(edge.open_cave_roof_refusal(H)), "a mined tile touching open sky can be opened")
	open_roof_check(findtext(inner.open_cave_roof_refusal(H), "edge already open"), "a mined tile away from the sky cannot be opened yet")

	var/obj/structure/blocker = new /obj/structure(edge)
	open_roof_check(findtext(edge.open_cave_roof_refusal(H), "Clear"), "a structure on the tile blocks opening")
	qdel(blocker)
	var/obj/structure/mine_support/support = new(edge)
	open_roof_check(isnull(edge.open_cave_roof_refusal(H)), "a mine support does not block opening")
	qdel(support)
	var/mob/living/human/open_cave_roof_probe/other = new(edge)
	open_roof_check(findtext(edge.open_cave_roof_refusal(H), "Someone"), "someone standing there blocks opening")
	other.forceMove(locate(1, 10, 1))

	open_roof_check(edge.open_cave_roof(edge.open_cave_roof_sky_area()), "opening moves the tile into the outdoor area")
	open_roof_check(get_area(edge) == sky && sky.location == AREA_OUTSIDE, "the opened tile is outdoors")
	open_roof_check(isnull(inner.open_cave_roof_refusal(H)), "the next tile in can be opened from the newly opened one")
	open_roof_check(findtext(edge.open_cave_roof_refusal(H), "no rock overhead"), "an opened tile cannot be opened again")
	var/turf/floor/F = inner
	open_roof_check(F.mine_supported(), "a roofed tile next to the opening counts as supported")

	var/turf/ore = locate(2, 7, 1)
	ore.ChangeTurf(/turf/floor/mining)
	ore = locate(2, 7, 1)
	open_roof_check(!isnull(ore.open_cave_roof_refusal(H)), "an ore floor is refused")
