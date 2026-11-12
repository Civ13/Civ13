// Torpedoes (code/modules/naval/torpedoes.dm, docs/naval-mines.md): a tube is
// trained by hand, bolted down and fired along its line; a contact torpedo goes
// off only on a hull it strikes; a magnetic torpedo also goes off under a steel
// hull it passes close to, not under a wooden or wiped one, and never under the
// ship that fired it; a spent torpedo sinks.
/world
	hub = ""
	hub_password = ""
	maxx = 70
	maxy = 60
	maxz = 3
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
var/naval_research_done = FALSE
/obj/map_metadata/naval_probe/New()
	return
/obj/map_metadata/naval_probe/is_node_done(faction, node_id)
	return naval_research_done
/mob/living/human/naval_probe/New()
	return
var/naval_failures = 0
var/naval_runtime_error = FALSE
/proc/naval_check(condition, label)
	if (!condition)
		naval_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	naval_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

// Rock under everything, sand ashore (x 1-20) and deep sea beyond, sky above.
/proc/naval_fixture()
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			var/turf/R = locate(x, y, 1)
			R.ChangeTurf(/turf/wall/rockwall)
			var/turf/W = locate(x, y, 2)
			W.ChangeTurf(x <= 20 ? /turf/floor/beach/sand : /turf/floor/beach/water/deep/saltwater)
			var/turf/S = locate(x, y, 3)
			S.ChangeTurf(/turf/sky/building)

/obj/structure/probe_gun
	name = "probe gun"
	anchored = TRUE
/obj/structure/probe_rock
	name = "probe rock"
	anchored = TRUE
	density = TRUE

// A plank laid the way a player lays one, with its first update already run.
/proc/hull_lay(x, y)
	var/turf/T = locate(x, y, 2)
	var/obj/covers/repairedfloor/ship/C = new(T)
	C.updateturf()
	return C

/proc/hull_planks(turf/T)
	. = 0
	for (var/obj/covers/C in T)
		.++

// The steps a half minute covers at her speed: a gliding hull makes one tile
// a step. TRUE when every step moved her.
/proc/hull_leg(datum/craft/C)
	var/steps = 0
	while (steps < C.speed * VESSEL_TILES_PER_STEP)
		if (!C.sail_tick())
			return FALSE
		steps++
	return steps > 0


// A steel plate laid the way a player lays one.
/proc/hull_plate(x, y)
	var/turf/T = locate(x, y, 2)
	var/obj/covers/steelplating/C = new(T)
	C.updateturf()
	return C

// The blasts are recorded, not set off: the fixture has no explosion config.
var/list/mine_blasts = list()
/obj/structure/naval_mine/blast_at(turf/hit)
	mine_blasts += hit

/proc/hull_steps(datum/craft/C, n)
	for (var/i = 1, i <= n, i++)
		if (!C.sail_tick())
			return FALSE
	return TRUE

/obj/structure/naval_mine/torpedo
	run_by_timer = FALSE

// Runs a torpedo until it is spent. Returns the tiles it ran.
/proc/torpedo_run(obj/structure/naval_mine/torpedo/R)
	. = 0
	if (!R || QDELETED(R))
		return
	while (R.run_step())
		.++
		if (. > 100)
			return

// Sets the tube on the shore at row y, loads it and fires it east.
/proc/shore_shot(obj/structure/torpedo_tube/tube, y, run_type)
	tube.forceMove(locate(20, y, 2))
	tube.loaded = run_type
	return tube.fire(null)

/proc/naval_checks()
	naval_fixture()
	for (var/x = 22, x <= 68, x++)
		for (var/y = 4, y <= 56, y++)
			var/turf/W = locate(x, y, 2)
			W.ChangeTurf(/turf/floor/beach/water)

	// ---- The tube ----
	var/obj/structure/torpedo_tube/tube = new(locate(20, 31, 2))
	var/mob/living/human/naval_probe/gunner = new(locate(19, 31, 2))
	var/obj/item/naval_torpedo/magnetic/fish = new(locate(19, 31, 2))
	naval_check(fish.run_type == /obj/structure/naval_mine/torpedo/magnetic && initial(fish.w_class) == ITEM_SIZE_HUGE, "a magnetic torpedo is a heavy item that runs as a magnetic torpedo")
	qdel(fish)
	tube.attack_hand(gunner)
	naval_check(tube.dir == SOUTH, "unbolted, a hand trains it round a quarter turn")
	tube.attack_hand(gunner)
	tube.attack_hand(gunner)
	tube.attack_hand(gunner)
	naval_check(tube.dir == EAST, "four turns bring it back to east")
	tube.loaded = /obj/structure/naval_mine/torpedo
	naval_check(findtext(tube.fire_problem(), "Bolt"), "it will not fire unbolted")
	var/obj/item/weapon/wrench/spanner = new(locate(19, 31, 2))
	tube.attackby(spanner, gunner)
	naval_check(tube.anchored && isnull(tube.fire_problem()), "bolted and loaded, it is ready to fire")
	tube.set_dir(WEST)
	naval_check(findtext(tube.fire_problem(), "open water"), "pointed inland it will not fire")
	tube.set_dir(EAST)
	tube.loaded = null

	// ---- A steel hull of twenty plates ----
	for (var/x = 30, x <= 34, x++)
		for (var/y = 30, y <= 33, y++)
			hull_plate(x, y)
	var/obj/structure/hull_tiller/tiller = new(locate(32, 31, 2))
	naval_check(isnull(tiller.commission("Iron Duke", EAST)) && tiller.craft, "a steel hull is commissioned")
	var/datum/craft/S = tiller.craft
	naval_check(S.magnetic_signature() == 20, "she shows 20")

	var/obj/structure/naval_mine/torpedo/R = shore_shot(tube, 31, /obj/structure/naval_mine/torpedo)
	naval_check(R && isnull(tube.loaded) && R.dir == EAST, "fired, the torpedo runs east and the tube is empty")
	var/ran = torpedo_run(R)
	naval_check(QDELETED(R) && mine_blasts.len == 1 && mine_blasts[1] == locate(30, 31, 2), "a contact torpedo strikes her side and goes off under it ([ran] tiles)")
	mine_blasts = list()
	R = shore_shot(tube, 34, /obj/structure/naval_mine/torpedo)
	ran = torpedo_run(R)
	naval_check(QDELETED(R) && !mine_blasts.len && ran == TORPEDO_STEPS_PER_RUN, "one tile off her side a contact torpedo runs past and sinks at the end of its run ([ran])")

	R = shore_shot(tube, 35, /obj/structure/naval_mine/torpedo/magnetic)
	ran = torpedo_run(R)
	naval_check(QDELETED(R) && !mine_blasts.len, "two tiles off a magnetic torpedo does not feel her")
	R = shore_shot(tube, 34, /obj/structure/naval_mine/torpedo/magnetic)
	ran = torpedo_run(R)
	var/turf/hit = mine_blasts.len ? mine_blasts[1] : null
	naval_check(QDELETED(R) && mine_blasts.len == 1 && hit && hit.y == 33 && S.body.contains(hit), "one tile off a magnetic torpedo goes off under her nearest plate")
	mine_blasts = list()
	S.magnetic_wipe = 70
	R = shore_shot(tube, 34, /obj/structure/naval_mine/torpedo/magnetic)
	ran = torpedo_run(R)
	naval_check(QDELETED(R) && !mine_blasts.len, "wiped, she lets the same magnetic torpedo run past")
	S.magnetic_wipe = 0

	// ---- A wooden hull ----
	for (var/x = 30, x <= 34, x++)
		hull_lay(x, 10)
		hull_lay(x, 11)
	var/obj/structure/hull_tiller/wood_tiller = new(locate(32, 10, 2))
	naval_check(isnull(wood_tiller.commission("Wren", EAST)) && wood_tiller.craft, "a wooden hull is commissioned")
	R = shore_shot(tube, 12, /obj/structure/naval_mine/torpedo/magnetic)
	ran = torpedo_run(R)
	naval_check(QDELETED(R) && !mine_blasts.len, "a magnetic torpedo passes close by a wooden hull")
	R = shore_shot(tube, 11, /obj/structure/naval_mine/torpedo/magnetic)
	ran = torpedo_run(R)
	naval_check(QDELETED(R) && mine_blasts.len == 1 && mine_blasts[1] == locate(30, 11, 2), "but its pistol still fires on striking her")
	mine_blasts = list()

	// ---- Fired from her own deck ----
	tube.forceMove(locate(34, 32, 2))
	naval_check(tube.aboard() == S && tube.muzzle(S) == locate(35, 32, 2), "on her deck the tube fires from past her bow")
	tube.loaded = /obj/structure/naval_mine/torpedo/magnetic
	R = tube.fire(null)
	naval_check(R && !QDELETED(R) && R.launcher == S, "her own magnetic torpedo does not go off under her")
	naval_check(S.check_naval_mines() == 0 && !QDELETED(R), "nor when she looks for mines beside it")
	var/obj/structure/naval_mine/contact/ahead = new(locate(50, 32, 2))
	ran = torpedo_run(R)
	naval_check(QDELETED(R) && !mine_blasts.len && !QDELETED(ahead), "it runs on past a moored mine without setting it off")
	qdel(ahead)

	// ---- A hull that runs onto a torpedo ----
	R = new /obj/structure/naval_mine/torpedo(locate(36, 31, 2))
	R.dir = WEST
	S.set_anchor(FALSE)
	S.set_speed(VESSEL_SPEED_SLOW)
	naval_check(hull_steps(S, 2) && QDELETED(R) && mine_blasts.len == 1, "a hull that runs onto a torpedo sets it off")
	S.set_speed(VESSEL_SPEED_STOP)
/proc/naval_run()
	try
		naval_checks()
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = naval_failures, "runtime_error" = naval_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/naval_probe
		naval_check(!world.port, "fixture has no listening port")
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		naval_run()
