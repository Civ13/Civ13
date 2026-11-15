// Native fixture for spilled-water puddles (/obj/effect/flooding). The
// production puddle body is extracted by run.py; the turf, qdel and layer
// definitions below are minimal stand-ins.

#define MOB_LAYER 4
var/list/cardinal = list(NORTH, SOUTH, EAST, WEST)
var/list/failed_labels = list()
var/checks = 0

/world
	maxx = 5
	maxy = 5
	maxz = 1
	turf = /turf/fixture_dirt

/turf/fixture_dirt
	icon = 'icons/turf/beach.dmi'
	icon_state = "dirt"

/turf/fixture_grass
	icon = 'icons/turf/beach.dmi'
	icon_state = "grass"

/atom/movable/var/anchored = 0
/atom/proc/update_icon()
/proc/get_turf(atom/A)
	for (A = A, A && !isturf(A), A = A.loc);
	return A

/datum/var/gc_destroyed = 0
/datum/proc/Destroy()
	return 0
/atom/movable/Destroy()
	loc = null
	return ..()

/proc/qdel(datum/D)
	if (!D || D.gc_destroyed)
		return
	D.gc_destroyed = world.time + 1
	D.Destroy()

/proc/check(label, ok)
	checks++
	if (!ok)
		failed_labels += label

// TRUE when T carries only its own edge overlay, no stranded water.
/proc/only_own_overlay(turf/T)
	if (T.overlays.len != 1)
		return FALSE
	for (var/O in T.overlays)
		return O:icon_state == "edge"

/proc/puddle_on(turf/T)
	return locate(/obj/effect/flooding) in T

/world/New()
	..()
	spawn(1)
		run_probe()

/proc/run_probe()
	var/turf/C = locate(3, 3, 1)
	var/turf/E = locate(4, 3, 1)
	var/turf/W = locate(2, 3, 1)
	// The turf's own edge/snow overlay, which the puddle must leave alone.
	var/image/own = image('icons/turf/beach.dmi', "edge")
	C.overlays += own
	E.overlays += own
	new /turf/fixture_grass(W)

	new /obj/effect/flooding(C)
	sleep(40)
	var/obj/effect/flooding/P = puddle_on(C)
	check("puddle exists", P)
	check("turf overlays untouched by a puddle", only_own_overlay(C))
	check("lone puddle draws water and four edges on itself", P && P.overlays.len == 5)

	new /obj/effect/flooding(E)
	sleep(40)
	var/obj/effect/flooding/Q = puddle_on(E)
	check("second puddle exists", Q)
	check("neighbour drops its shared edge", P.overlays.len == 4)
	check("new puddle drops its shared edge", Q && Q.overlays.len == 4)
	check("east turf overlays untouched", only_own_overlay(E))

	// Two spills on one tile merge into one deeper puddle.
	new /obj/effect/flooding(C)
	sleep(40)
	var/count = 0
	for (var/obj/effect/flooding/F in C)
		count++
	check("spills on one tile merge", count == 1)
	P = puddle_on(C)
	check("merged puddle is deeper", P && P.flood_level == 2)
	check("merged puddle still draws its own water", P && P.overlays.len == 4)

	// Scooped up or dried: the neighbour regains its edge, the turf is clean.
	qdel(Q)
	check("drying puddle leaves the tile", !puddle_on(E))
	check("neighbour regains its edge", P.overlays.len == 5)
	check("dried tile keeps only its own overlay", only_own_overlay(E))
	qdel(P)
	check("last puddle gone", !puddle_on(C))
	check("dry dirt shows no water", only_own_overlay(C))
	check("grass beside it never changed", W.overlays.len == 0)

	var/list/result = list("checks" = checks, "failed_labels" = failed_labels)
	text2file(json_encode(result), "result.json")
	world.log << json_encode(result)
	del(world)
