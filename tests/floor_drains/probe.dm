// Native probe for floor drains (code/modules/1713/floor_drains.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/floor_drains/probe.dm 300
/world
	hub = ""
	hub_password = ""
	maxx = 30
	maxy = 20
	maxz = 1
	turf = /turf/floor/dirt
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/floor_drain_probe/New()
	return
var/vr_failures = 0
var/vr_runtime_error = FALSE
/proc/vr_check(condition, label)
	if (!condition)
		vr_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	vr_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	sleep(1)
	try
		config = new
		config.webhook_can_fire = FALSE
		makeDatumRefLists()
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.stat_set_event = new
		GLOB.name_set_event = new
		movementMachine = new
		map = new /obj/map_metadata/floor_drain_probe
		Master.start_timer_loop()
		vr_checks()
	catch(var/exception/e)
		vr_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = vr_failures, "runtime_error" = vr_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/vr_checks()
	map.persistence = TRUE
	// A floor drain at (10,10) joined by stone drains to an outfall on a pond.
	var/obj/structure/sewer_piece/drain/floor/D = new /obj/structure/sewer_piece/drain/floor(locate(10, 10, 1))
	vr_check(!floor_drain_route(D), "a floor drain that runs nowhere takes nothing")
	var/obj/effect/flooding/dry = new /obj/effect/flooding(locate(11, 10, 1))
	vr_check(!floor_drain_take_puddle(dry), "a puddle beside a drain to nowhere stays")
	qdel(dry)
	new /obj/structure/sewer_piece/drain/stone(locate(10, 11, 1))
	var/obj/structure/sewer_piece/drain/stone/O = new /obj/structure/sewer_piece/drain/stone(locate(10, 12, 1))
	new /turf/floor/beach/water(locate(10, 13, 1))
	vr_check(O.outfall_dir() && floor_drain_route(D), "a floor drain joined to an outfall runs away")
	vr_check(D in sewer_drains, "a floor drain takes hollow water like any drain")

	// A puddle beside it runs away and washes the blood on its tile down.
	var/turf/side = locate(11, 10, 1)
	var/obj/effect/decal/cleanable/blood/B = new /obj/effect/decal/cleanable/blood(side)
	var/obj/effect/decal/cleanable/dirt/dirt = new /obj/effect/decal/cleanable/dirt(side)
	var/obj/effect/flooding/F = new /obj/effect/flooding(side)
	var/before = O.last_waste
	vr_check(floor_drain_take_puddle(F) && QDELETED(F), "a puddle beside the drain runs away")
	vr_check(QDELETED(B) && !QDELETED(dirt), "the puddle washes blood down, not dry dirt")
	vr_check(O.last_waste > before, "the blood fouls the outfall's water downstream")

	// A puddle two tiles away stays.
	var/obj/effect/flooding/far = new /obj/effect/flooding(locate(12, 10, 1))
	vr_check(!floor_drain_take_puddle(far) && !QDELETED(far), "a puddle two tiles off stays")

	// Vomit landing on the drain goes straight down.
	var/obj/effect/decal/cleanable/vomit/V = new /obj/effect/decal/cleanable/vomit(get_turf(D))
	sleep(5)
	vr_check(QDELETED(V), "vomit on the drain goes down it")
	var/obj/effect/decal/cleanable/blood/gibs/G = new /obj/effect/decal/cleanable/blood/gibs(get_turf(D))
	sleep(5)
	vr_check(!QDELETED(G), "gibs stay on the grate")

	// A clogged drain takes nothing until it is pulled clear.
	D.set_clogged(TRUE)
	vr_check(D.icon_state == "floor_drain_clogged" && !floor_drain_route(D), "a clogged drain shows it and takes nothing")
	D.set_clogged(FALSE)
	vr_check(D.icon_state == "floor_drain" && floor_drain_route(D), "cleared, it drains again")

	// A cesspit with room takes it too.
	var/obj/structure/sewer_piece/drain/floor/D2 = new /obj/structure/sewer_piece/drain/floor(locate(20, 10, 1))
	new /obj/structure/sewer_piece/cesspit(locate(21, 10, 1))
	vr_check(floor_drain_route(D2), "a floor drain beside a cesspit runs into it")

	// A running shower wets the floor unless drained or curtained.
	var/obj/structure/shower/S1 = new /obj/structure/shower(locate(5, 5, 1))
	S1.on = TRUE
	S1.bath_water_running()
	vr_check(locate(/obj/effect/flooding) in locate(5, 5, 1), "a running shower with no drain puddles its floor")
	var/obj/structure/shower/S2 = new /obj/structure/shower(locate(5, 8, 1))
	new /obj/structure/curtain(locate(5, 8, 1))
	S2.on = TRUE
	S2.bath_water_running()
	vr_check(!(locate(/obj/effect/flooding) in locate(5, 8, 1)), "a closed shower curtain keeps the water in")
	var/obj/structure/shower/S3 = new /obj/structure/shower(locate(10, 9, 1))
	S3.on = TRUE
	S3.bath_water_running()
	vr_check(!(locate(/obj/effect/flooding) in locate(10, 9, 1)), "a shower beside a floor drain stays dry")

	// A tub turned off empties beside it unless a drain takes it.
	var/obj/structure/shower/bathtub/T1 = new /obj/structure/shower/bathtub(locate(15, 5, 1))
	T1.bath_water_turned_off()
	var/found = FALSE
	for (var/turf/N in floor_drain_cardinals(get_turf(T1)))
		if (locate(/obj/effect/flooding) in N)
			found = TRUE
	vr_check(found, "a tub emptied with no drain slops onto the floor beside it")

	// Stepping out wet drips, unless onto a bath mat.
	var/mob/living/human/H = new /mob/living/human(locate(15, 8, 1))
	var/obj/structure/shower/bathtub/T2 = new /obj/structure/shower/bathtub(locate(15, 8, 1))
	T2.drips_until = world.time + 300
	H.Move(locate(16, 8, 1))
	sleep(3)
	vr_check(locate(/obj/effect/flooding) in locate(16, 8, 1), "stepping out of a bath drips on the floor")
	H.forceMove(locate(15, 8, 1))
	new /obj/item/bath_mat(locate(14, 8, 1))
	H.Move(locate(14, 8, 1))
	sleep(3)
	vr_check(H.loc == locate(14, 8, 1) && !(locate(/obj/effect/flooding) in locate(14, 8, 1)), "a bath mat catches the drips")

	// Off settlement maps plumbing carries everything away.
	map.persistence = FALSE
	var/obj/structure/sewer_piece/drain/floor/D3 = new /obj/structure/sewer_piece/drain/floor(locate(25, 15, 1))
	vr_check(floor_drain_route(D3), "off settlement maps a floor drain always drains")
