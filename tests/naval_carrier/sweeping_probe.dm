// Minesweeping (code/modules/naval/minesweeping.dm, docs/naval-mines.md): a
// magnetic sweep needs power and then sets off magnetic mines around it where
// they lie; an Oropesa sweep cuts contact mines to her sides up to the surface,
// never one under her, and a surfaced mine still goes off on a hull.
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

/proc/naval_checks()
	naval_fixture()
	for (var/x = 22, x <= 68, x++)
		for (var/y = 4, y <= 56, y++)
			var/turf/W = locate(x, y, 2)
			W.ChangeTurf(/turf/floor/beach/water)

	// ---- A wooden hull with both sweeps ----
	for (var/x = 30, x <= 34, x++)
		hull_lay(x, 10)
		hull_lay(x, 11)
	var/obj/structure/hull_tiller/tiller = new(locate(32, 10, 2))
	naval_check(isnull(tiller.commission("Sweeper", EAST)) && tiller.craft, "a wooden sweeper is commissioned")
	var/datum/craft/W = tiller.craft
	var/obj/structure/mine_sweep/oropesa/oro = new(locate(30, 11, 2))
	var/obj/structure/mine_sweep/magnetic/reel = new(locate(30, 10, 2))
	var/mob/living/human/naval_probe/hand = new(locate(31, 11, 2))
	oro.attack_hand(hand)
	naval_check(!oro.streamed, "a sweep that is not bolted down cannot be streamed")
	oro.anchored = TRUE
	reel.anchored = TRUE
	oro.attack_hand(hand)
	reel.attack_hand(hand)
	naval_check(oro.streamed && reel.streamed && oro.icon_state == "oropesa_on" && reel.icon_state == "sweep_reel_on", "bolted down, both are streamed")
	var/obj/structure/naval_mine/contact/side = new(locate(38, 13, 2))
	var/obj/structure/naval_mine/contact/far = new(locate(38, 16, 2))
	var/obj/structure/naval_mine/magnetic/quiet = new(locate(37, 14, 2))
	W.set_anchor(FALSE)
	W.set_speed(VESSEL_SPEED_SLOW)
	naval_check(hull_steps(W, 1) && !reel.streamed, "with no engine aboard the magnetic sweep goes dead and is wound in")
	naval_check(!QDELETED(quiet) && !mine_blasts.len, "and the magnetic mine is left alone")
	naval_check(hull_steps(W, 3) && side.surfaced && side.icon_state == "contact_surfaced" && findtext(side.name, "floating") && !QDELETED(side), "a contact mine two tiles off her side is cut up to the surface")
	naval_check(!far.surfaced && !QDELETED(far) && !mine_blasts.len, "one five tiles off is not reached, and nothing went off")
	W.set_speed(VESSEL_SPEED_STOP)
	qdel(far)
	qdel(quiet)
	// A cut mine under a hull still goes off.
	side.forceMove(locate(40, 11, 2))
	W.set_speed(VESSEL_SPEED_SLOW)
	naval_check(hull_steps(W, 4) && QDELETED(side) && mine_blasts.len == 1, "a surfaced mine still goes off when a hull runs onto it")
	W.set_speed(VESSEL_SPEED_STOP)
	oro.attack_hand(hand)
	naval_check(!oro.streamed && oro.icon_state == "oropesa", "the Oropesa sweep is wound in by hand")

	// ---- A submarine's magnetic sweep runs on her battery ----
	mine_blasts = list()
	var/obj/structure/vehicleparts/axis/ship/submarine/boat = build_submarine(locate(50, 40, 2), "Probe boat")
	var/datum/craft/B = craft_of_axis(boat)
	var/obj/structure/vehicleparts/frame/inside = boat.components[1]
	var/obj/structure/mine_sweep/magnetic/sub_reel = new(get_turf(inside))
	sub_reel.anchored = TRUE
	sub_reel.attack_hand(hand)
	naval_check(sub_reel.streamed && sub_reel.aboard() == B, "the reel streams from a submarine")
	var/obj/structure/naval_mine/magnetic/near = new(locate(sub_reel.x, sub_reel.y - 6, 2))
	var/obj/structure/naval_mine/magnetic/beyond = new(locate(sub_reel.x, sub_reel.y - 9, 2))
	var/obj/structure/naval_mine/contact/horned = new(locate(sub_reel.x + 6, sub_reel.y, 2))
	var/battery = boat.battery
	B.magnetic_moved(1)
	naval_check(QDELETED(near) && mine_blasts.len == 1 && mine_blasts[1] == locate(sub_reel.x, sub_reel.y - 6, 2), "its pulse sets off a magnetic mine six tiles off, where it lies")
	naval_check(!QDELETED(beyond) && !QDELETED(horned), "not one nine tiles off, nor a contact mine")
	naval_check(boat.battery == battery - 1, "a tile of sweeping costs a battery unit")
	boat.battery = 0
	B.magnetic_moved(1)
	naval_check(!sub_reel.streamed && !QDELETED(beyond), "a flat battery kills the sweep")

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
