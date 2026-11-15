// Pushing a hull off by hand (code/modules/naval/hull_push.dm): a long hull
// run up against a shore with no room to turn is pushed a tile at a time by
// people standing ashore or in the shallows, their strength added together.
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

/proc/push_person(x, y, strength = 100)
	var/mob/living/human/naval_probe/M = new(locate(x, y, 2))
	M.stats = list("strength" = list(strength, strength), "stamina" = list(100, 100))
	return M

/proc/naval_checks()
	naval_fixture()
	// A shallow bay east of the sand (x 1-20), deep sea beyond x 60.
	for (var/x = 21, x <= 60, x++)
		for (var/y = 4, y <= 50, y++)
			var/turf/W = locate(x, y, 2)
			W.ChangeTurf(/turf/floor/beach/water)
	// A long hull, 12 x 3, bow west, run up against the sand at x 20.
	for (var/x = 21, x <= 32, x++)
		for (var/y = 30, y <= 32, y++)
			hull_lay(x, y)
	var/obj/structure/hull_tiller/tiller = new(locate(30, 31, 2))
	naval_check(isnull(tiller.commission("Longship", WEST)) && tiller.craft, "the longship is commissioned bow west")
	var/datum/craft/C = tiller.craft
	var/datum/craft_body/built/B = C.body
	C.set_anchor(FALSE)
	C.set_speed(VESSEL_SPEED_SLOW)
	naval_check(!C.sail_tick(), "with the sand ahead she cannot sail ([C.last_refusal])")
	C.set_speed(VESSEL_SPEED_STOP)
	naval_check(abs(C.push_strength_needed() - 1.8) < 0.01, "36 tiles of hull need about two people ([C.push_strength_needed()])")

	var/obj/covers/bow = locate(/obj/covers) in locate(21, 31, 2)
	var/mob/living/human/naval_probe/sailor = push_person(22, 31)
	naval_check(findtext(hull_push_refusal(sailor, bow), "own deck"), "nobody pushes her from her own deck ([hull_push_refusal(sailor, bow)])")
	var/mob/living/human/naval_probe/far = push_person(19, 31)
	naval_check(findtext(hull_push_refusal(far, bow), "right beside"), "nor from two tiles off")
	var/mob/living/human/naval_probe/one = push_person(20, 31)
	naval_check(isnull(hull_push_refusal(one, bow)), "a person on the sand beside her bow may push ([hull_push_refusal(one, bow)])")
	naval_check(!hull_push_add(C, one, EAST) && B.px == 30, "alone, an average person cannot shift her")
	var/obj/covers/bow2 = locate(/obj/covers) in locate(21, 30, 2)
	var/mob/living/human/naval_probe/two = push_person(20, 30)
	naval_check(isnull(hull_push_refusal(two, bow2)), "a second person beside her may push too")
	var/turf/sailor_at = get_turf(sailor)
	naval_check(hull_push_add(C, two, EAST) && B.px == 31 && B.py == 31 && B.dir == WEST, "two heaving together within five seconds push her a tile off, bow still west")
	naval_check(sailor.x == sailor_at.x + 1 && tiller.x == 31 && hull_planks(locate(21, 31, 2)) == 0 && hull_planks(locate(33, 31, 2)) == 1, "her deck, tiller and crew go with her and the shore tile is clear")
	naval_check(!length(C.push_heaves), "the heaves are spent")
	// Wading after her: from the shallows the same two push her on.
	one.forceMove(locate(21, 31, 2))
	two.forceMove(locate(21, 30, 2))
	var/obj/covers/bow3 = locate(/obj/covers) in locate(22, 31, 2)
	naval_check(isnull(hull_push_refusal(one, bow3)), "wading in the shallows beside her, she can be pushed")
	hull_push_add(C, one, EAST)
	naval_check(hull_push_add(C, two, EAST) && B.px == 32, "and goes another tile")
	// A heave too old does not count.
	var/mob/living/human/naval_probe/strong = push_person(22, 31, 100)
	hull_push_add(C, one, EAST)
	var/list/old = C.push_heaves[one]
	old[3] = world.time - 60
	naval_check(!hull_push_add(C, strong, EAST) && B.px == 32, "a heave from more than five seconds ago does not add up")
	// A very strong person may manage alone.
	var/mob/living/human/naval_probe/giant = push_person(22, 30, 200)
	C.push_heaves = list()
	naval_check(hull_push_add(C, giant, EAST) && B.px == 33, "someone twice as strong as most pushes her alone")
	// Under way or on a voyage, no pushing.
	C.set_anchor(FALSE)
	C.set_speed(VESSEL_SPEED_SLOW)
	giant.forceMove(locate(23, 30, 2))
	var/obj/covers/side = locate(/obj/covers) in locate(24, 30, 2)
	naval_check(findtext(hull_push_refusal(giant, side), "under way"), "under way she cannot be pushed")
	C.set_speed(VESSEL_SPEED_STOP)
	C.set_anchor(TRUE)
	tiller.voyage = list("id" = "probe")
	naval_check(findtext(hull_push_refusal(giant, side), "voyage"), "nor on a voyage")
	tiller.voyage = null
	naval_check(isnull(hull_push_refusal(giant, side)), "at anchor and home again she can")
	qdel(tiller)

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
