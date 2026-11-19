// Native probe for heavy earthwork (code/modules/1713/earthworking_heavy.dm
// and the steam shovel's cut job in earthworks.dm). Full production sources
// with ordinary startup disabled; run with
// python3 tests/ecology_spawning/run_linux.py . tests/earthworking/probe.dm
// Heights come from tests/terrain_height/fixture.txt: rows y 7-12 rise one
// level per tile eastward (height = x - 1), rows y 1-6 are flat 0.
/world
	hub = ""
	hub_password = ""
	maxx = 12
	maxy = 12
	maxz = 1
	turf = /turf/floor/rocky
	area = /area/caribbean/void/caves
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/earthworking_probe
	terrain_height_file = "tests/terrain_height/fixture.txt"
/obj/map_metadata/earthworking_probe/New()
	map = src

var/earthworking_failures = 0
var/earthworking_runtime_error = FALSE
/proc/earthworking_check(condition, label)
	if (!condition)
		earthworking_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	earthworking_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/earthworking_probe
		earthworking_probe_run()
	catch(var/exception/e)
		earthworking_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = earthworking_failures, "runtime_error" = earthworking_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/earthworking_dirt(x1, y1, x2, y2)
	for (var/turf/T in block(locate(x1, y1, 1), locate(x2, y2, 1)))
		T.ChangeTurf(/turf/floor/dirt)

/proc/earthworking_probe_run()
	earthworking_dirt(5, 8, 9, 12)

	// Slip scraper: only a draft animal draws it through the ground.
	var/obj/structure/closet/crate/cart/slip_scraper/S = new(locate(7, 10, 1))
	S.set_dir(EAST)
	S.blade_down = TRUE
	earthworking_check(S.scrape(EAST) == 0, "without a horse or an ox the blade cuts nothing")
	var/mob/living/simple_animal/horse/H = new(locate(8, 10, 1))
	S.hitched_to = H
	var/turf/mid = locate(7, 10, 1)
	var/before = terrain_height_at(mid)
	earthworking_check(S.scrape(EAST) == 3 && S.loads == 3, "one step cuts a three-tile swath across the direction of travel")
	earthworking_check(terrain_height_at(locate(7, 10, 1)) == before - 1 && terrain_height_at(locate(7, 11, 1)) == before - 1 && terrain_height_at(locate(7, 9, 1)) == before - 1, "each swath tile drops one level")
	earthworking_check(terrain_height_at(locate(8, 10, 1)) == 7, "tiles ahead are untouched")
	S.forceMove(locate(6, 10, 1))
	for (var/turf/T in S.swath(EAST))
		world.log << "DEBUG [T.x],[T.y] [T.type] problem=[S.grade_problem(T, -1)] h=[terrain_height_at(T)]"
	earthworking_check(S.scrape(EAST) == 3 && S.loads == 6, "the next step cuts the next swath")
	S.forceMove(locate(5, 10, 1))
	earthworking_check(S.scrape(EAST) == 3 && S.loads == 9, "three steps grade a 3x3 patch")
	S.forceMove(locate(8, 10, 1))
	earthworking_check(S.scrape(EAST) == 0 && S.loads == 9, "a full scoop cuts nothing more")
	S.forceMove(locate(7, 10, 1))
	S.loads = 1
	S.forceMove(locate(7, 10, 1))
	earthworking_check(S.scrape(EAST) == 3 && S.loads == 4, "a second pass cuts the same tiles again")
	earthworking_check(S.scrape(EAST) == 0, "never more than two levels below the map by hand or team")

	// Tipping builds the swath back up.
	S.blade_down = FALSE
	var/low = terrain_height_at(locate(7, 10, 1))
	earthworking_check(S.tip_load() == 3 && S.loads == 1, "tipping builds up the three swath tiles, one load each")
	earthworking_check(terrain_height_at(locate(7, 10, 1)) == low + 1 && istype(locate(7, 10, 1), /turf/floor/tamped_earth), "built-up ground is tamped earth one level higher")
	S.forceMove(locate(2, 2, 1)) // rocky ground that can't be graded
	var/turf/rocky = locate(2, 2, 1)
	earthworking_check(S.tip_load() == 0 && S.loads == 0 && (locate(/obj/item/weapon/barrier) in rocky), "earth with nowhere to go is tipped out in piles")

	// Steam shovel: cut the ground within reach down a level.
	earthworking_dirt(5, 8, 9, 12)
	for (var/turf/T in block(locate(5, 8, 1), locate(9, 12, 1)))
		T.terrain_grade = 0
		T.terrain_grade_apply()
	var/turf/shovel_spot = locate(7, 10, 1)
	var/obj/structure/workshop_machine/steam_site/steam_shovel/shovel = new(shovel_spot)
	var/list/cuts = shovel.cuttings()
	for (var/turf/T in range(2, shovel_spot))
		world.log << "DEBUG2 [T.x],[T.y] [T.type] problem=[terrain_grade_problem(T, -1)]"
	earthworking_check(length(cuts) == 12 && !(shovel_spot in cuts), "a steam shovel cuts up to twelve tiles within reach, never its own")
	var/turf/far = cuts[1]
	var/far_before = terrain_height_at(far)
	earthworking_check(shovel.cut_down(null) == 12, "the cut job cuts every tile it found")
	var/piles = 0
	for (var/obj/item/weapon/barrier/B in shovel_spot)
		piles++
	earthworking_check(piles == 12 && terrain_height_at(far) == far_before - 1, "spoil heaps at the shovel's foot and the ground drops a level")

	// Blasting charge: breaks the rock around it.
	var/turf/rock1 = locate(2, 5, 1)
	var/turf/rock2 = locate(3, 5, 1)
	var/turf/rock3 = locate(5, 5, 1)
	rock1.ChangeTurf(/turf/floor/dirt/underground)
	rock2.ChangeTurf(/turf/floor/dirt/underground)
	rock3.ChangeTurf(/turf/floor/dirt/underground)
	rock1 = locate(2, 5, 1)
	rock2 = locate(3, 5, 1)
	rock3 = locate(5, 5, 1)
	earthworking_check(rock1.density, "fixture rock is solid")
	earthworking_check(blasting_charge_break_rock(locate(2, 4, 1)) == 2, "a charge breaks the rock beside it")
	rock1 = locate(2, 5, 1)
	rock2 = locate(3, 5, 1)
	rock3 = locate(5, 5, 1)
	earthworking_check(!rock1.density && !rock2.density && rock3.density, "rock out of reach stays")
	var/obj/item/weapon/grenade/blasting_charge/C = new(locate(1, 1, 1))
	earthworking_check(C.state == 0 && !C.active, "a new charge is empty")
	var/obj/item/weapon/grenade/blasting_charge/ready/R = new(locate(1, 1, 1))
	earthworking_check(R.state == 2 && R.name == "blasting charge", "a ready charge has powder and a fuse")
