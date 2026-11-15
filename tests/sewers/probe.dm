// Native probe for sewers phase S1 (code/modules/1713/sewers.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/sewers/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 12
	maxy = 6
	maxz = 1
	turf = /turf/floor/dirt
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/sewer_probe/New()
	return
var/sewer_failures = 0
var/sewer_runtime_error = FALSE
/proc/sewer_check(condition, label)
	if (!condition)
		sewer_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	sewer_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		map = new /obj/map_metadata/sewer_probe
		sewer_checks()
	catch(var/exception/e)
		sewer_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = sewer_failures, "runtime_error" = sewer_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/sewer_poo(turf/T)
	return new /obj/item/weapon/reagent_containers/food/snacks/poo(T)

/proc/sewer_count_poo(turf/T)
	. = 0
	for (var/obj/item/weapon/reagent_containers/food/snacks/poo/P in T)
		if (!QDELETED(P) && !istype(P, /obj/item/weapon/reagent_containers/food/snacks/poo/fertilizer))
			.++

/proc/sewer_checks()
	var/obj/structure/toilet/T = new /obj/structure/toilet(locate(2, 3, 1))

	// Off a persistence map plumbing still carries waste away by itself.
	map.persistence = FALSE
	sewer_check(T.drains_away(), "plumbing drains away where there are no sewers")
	sewer_check(T.flush_waste(sewer_poo(T.loc)) && !sewer_count_poo(T.loc), "flushed waste vanishes without sewers")

	map.persistence = TRUE
	sewer_check(!T.drains_away(), "a toilet with no drain does not drain away")
	sewer_check(!T.flush_waste(sewer_poo(T.loc)) && sewer_count_poo(T.loc) == 1, "a toilet with no drain backs up onto the floor")
	var/obj/structure/sink/well/W = new /obj/structure/sink/well(locate(2, 5, 1))
	sewer_check(W.has_nearby_fecal_waste(), "backed-up waste on a toilet's tile fouls a well")
	for (var/obj/item/weapon/reagent_containers/food/snacks/poo/P in T.loc)
		qdel(P)
	sewer_check(!W.has_nearby_fecal_waste(), "the well is clean once the floor is")

	// A covered stone drain from x 3 to x 9; nothing at its end yet.
	var/list/drains = list()
	for (var/x in 3 to 9)
		drains += new /obj/structure/sewer_piece/drain/stone(locate(x, 3, 1))
	// Clogs are random; this probe checks them in s2_probe.dm.
	for (var/obj/structure/sewer_piece/drain/D in drains)
		D.clog_chance = 0
	var/obj/structure/sewer_piece/drain/first = drains[1]
	var/obj/structure/sewer_piece/drain/middle = drains[3]
	sewer_check(first.icon_state == "stone_drain4" && middle.icon_state == "stone_drain12", "a straight run joins east and west, and its open end only east ([first.icon_state], [middle.icon_state])")
	sewer_check(T.drains_away(), "a toilet beside a drain drains away")
	sewer_check(!T.flush_waste(sewer_poo(T.loc)) && sewer_count_poo(T.loc) == 1, "a drain that runs nowhere still backs up")
	for (var/obj/item/weapon/reagent_containers/food/snacks/poo/P in T.loc)
		qdel(P)

	// A cesspit at the end takes the waste until it is full.
	var/obj/structure/sewer_piece/cesspit/C = new /obj/structure/sewer_piece/cesspit(locate(10, 3, 1))
	var/obj/structure/sewer_piece/drain/last = drains[drains.len]
	sewer_check(last.icon_state == "stone_drain12", "the drain joins the cesspit ([last.icon_state])")
	sewer_check(T.flush_waste(sewer_poo(T.loc)) && !sewer_count_poo(T.loc) && C.waste == 1, "waste runs down the drain into the cesspit")
	sewer_check(C.icon_state == "cesspit1", "a cesspit shows its fill ([C.icon_state])")
	sewer_check(!W.has_nearby_fecal_waste(), "a covered drain and a far cesspit leave the well clean")
	C.waste = 39
	sewer_check(T.flush_waste(sewer_poo(T.loc)) && C.is_full() && C.icon_state == "cesspit3", "the last flush fills the cesspit")
	sewer_check(!T.flush_waste(sewer_poo(T.loc)) && sewer_count_poo(T.loc) == 1, "a full cesspit backs the toilet up")
	for (var/obj/item/weapon/reagent_containers/food/snacks/poo/P in T.loc)
		qdel(P)
	var/obj/structure/sink/well/W2 = new /obj/structure/sink/well(locate(10, 5, 1))
	sewer_check(W2.has_nearby_fecal_waste(), "a well beside a cesspit with waste in it is fouled")
	C.waste = 0
	C.sewer_update_icon()
	sewer_check(!W2.has_nearby_fecal_waste() && C.icon_state == "cesspit0", "an emptied cesspit fouls nothing")
	qdel(W2)

	// Swap the cesspit for open water: the last drain becomes an outfall.
	qdel(C)
	sewer_check(last.icon_state == "stone_drain8", "removing the cesspit updates the drain ([last.icon_state])")
	var/turf/water = locate(10, 3, 1)
	water.ChangeTurf(/turf/floor/beach/water/deep)
	last.sewer_update_icon()
	sewer_check(last.outfall_dir() == EAST && last.overlays.len == 1, "a drain beside open water is an outfall")
	sewer_check(T.flush_waste(sewer_poo(T.loc)) && !sewer_count_poo(T.loc), "waste runs out of the outfall")
	sewer_check(last.recently_fouled() && !middle.recently_fouled(), "the outfall carries waste; covered drains do not count")
	var/obj/structure/sink/well/W3 = new /obj/structure/sink/well(locate(9, 6, 1))
	sewer_check(W3.has_nearby_fecal_waste(), "a well near a working outfall is fouled")
	sewer_check(!W.has_nearby_fecal_waste(), "a well far from the outfall stays clean")
	qdel(W3)

	// An open ditch carrying waste fouls a well beside it.
	qdel(drains[2])
	var/obj/structure/sewer_piece/drain/ditch/D = new /obj/structure/sewer_piece/drain/ditch(locate(4, 3, 1))
	D.clog_chance = 0
	sewer_check(D.icon_state == "ditch12", "a ditch joins the stone drains ([D.icon_state])")
	sewer_check(!D.recently_fouled(), "a new ditch has carried nothing")
	sewer_check(T.flush_waste(sewer_poo(T.loc)), "waste runs through a mixed ditch and drain")
	var/obj/structure/sink/well/W4 = new /obj/structure/sink/well(locate(4, 5, 1))
	sewer_check(D.recently_fouled() && W4.has_nearby_fecal_waste(), "an open ditch carrying waste fouls a well two tiles away")

	// A cut in the line stops the flow.
	qdel(drains[5])
	sewer_check(!T.flush_waste(sewer_poo(T.loc)), "a gap in the drain backs the toilet up")
