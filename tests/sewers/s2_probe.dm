// Native probe for sewers phase S2: inlets, storms, backflow, flap gates, clogs.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/sewers/s2_probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 10
	maxy = 6
	maxz = 1
	turf = /turf/floor/dirt
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/sewer_s2_probe/New()
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
		map = new /obj/map_metadata/sewer_s2_probe
		sewer_checks()
	catch(var/exception/e)
		sewer_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = sewer_failures, "runtime_error" = sewer_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

// A river down the east column; a basin (x 3-5, y 3-4) at level 1 inside a rim
// at level 3; ground at 1 elsewhere. A stone drain runs from the basin east
// through the rim to the river.
/proc/s2_flood_text()
	var/list/lines = list("civ13-river-flood 2", "size 10 6", "z 1", "reaches 1", "r 1 0 10 3 60 60 6")
	for (var/r in 1 to 6)
		lines += "01010101010101010101"
	lines += list("111111111.", "133333111.", "133333111.", "133333111.", "133333111.", "111111111.")
	lines += list("hollows 1", "h 1 3 1 4 4 6 30 6,0,0,0", "hollow_rows 2")
	lines += list("3 00000101010000000000", "4 00000101010000000000")
	return jointext(lines, "\n")

/proc/s2_poo(turf/T)
	return new /obj/item/weapon/reagent_containers/food/snacks/poo(T)

/proc/sewer_checks()
	map.persistence = TRUE
	var/datum/terrain_heights/H = new
	H.maxx = 10
	H.maxy = 6
	H.rows_by_z["1"] = list("1111111110", "1333331110", "1311131110", "1311131110", "1333331110", "1111111110")
	map.terrain_height_file = "probe"
	map.terrain_heights_cache = H
	var/datum/river_flood/F = river_flood_parse(s2_flood_text(), 10, 6, 1)
	sewer_check(!F.error && F.hollow_count == 1, "the probe flood file parses ([F.error])")
	map.river_flood_cache = F
	map.river_flood_loaded = TRUE
	map.river_flood_state = list()
	F.published = map.river_flood_state
	F.stage[1] = 0
	for (var/y in 1 to 6)
		var/turf/W = locate(10, y, 1)
		W.ChangeTurf(/turf/floor/beach/water/deep)

	var/list/line = list()
	for (var/x in 4 to 9)
		var/obj/structure/sewer_piece/drain/D = new /obj/structure/sewer_piece/drain/stone(locate(x, 4, 1))
		D.clog_chance = 0
		line += D
	var/obj/structure/sewer_piece/drain/outfall = line[line.len]
	outfall.sewer_update_icon()
	sewer_check(outfall.outfall_dir() == EAST && outfall.outfall_open(), "the drain spills into the river")
	var/obj/structure/sewer_piece/drain/inlet = line[1]
	sewer_check(inlet.find_outfall() == outfall, "an inlet finds its outfall")

	// Inlets drain a hollow, up to what the outfall can take.
	F.restore_hollows(list(1, 6))
	sewer_check(abs(F.hollow_depth_at(locate(4, 4, 1)) - 1) < 0.001, "the hollow holds a level of rain")
	F.drain_hollows()
	sewer_check(abs(F.hollow_volume[1] - 2) < 0.001 && world.time >= outfall.full_until, "two inlets drain the hollow at full rate ([F.hollow_volume[1]])")
	var/obj/structure/sewer_piece/drain/third = new /obj/structure/sewer_piece/drain/stone(locate(4, 3, 1))
	third.clog_chance = 0
	F.restore_hollows(list(1, 6))
	F.drain_hollows()
	sewer_check(abs(F.hollow_volume[1] - 2) < 0.001 && world.time < outfall.full_until, "a third inlet runs the outfall full ([F.hollow_volume[1]])")
	var/obj/structure/toilet/T = new /obj/structure/toilet(locate(7, 5, 1))
	sewer_check(!T.flush_waste(s2_poo(T.loc)) && !sewer_last_backflow, "a sewer running full in a storm backs the toilet up")
	for (var/obj/item/weapon/reagent_containers/food/snacks/poo/P in T.loc)
		qdel(P)
	outfall.full_until = 0
	sewer_check(T.flush_waste(s2_poo(T.loc)), "once it runs clear the toilet flushes")
	F.restore_hollows(list(1, 0))
	F.drain_hollows()
	sewer_check(F.hollow_volume[1] == 0, "a dry hollow gives nothing")

	// Clogs stop the flow until dug out.
	var/obj/structure/sewer_piece/drain/middle = line[4]
	middle.set_clogged(TRUE)
	sewer_check(middle.overlays.len == 1 && !inlet.find_outfall(), "a clogged drain cuts the network")
	F.restore_hollows(list(1, 6))
	F.drain_hollows()
	sewer_check(F.hollow_volume[1] == 6, "a clogged sewer drains nothing")
	sewer_check(!T.flush_waste(s2_poo(T.loc)), "a toilet above a clog backs up")
	for (var/obj/item/weapon/reagent_containers/food/snacks/poo/P in T.loc)
		qdel(P)
	middle.set_clogged(FALSE)
	sewer_check(inlet.find_outfall() == outfall && !middle.overlays.len, "a cleared drain runs again")
	middle.clog_chance = 100
	for (var/obj/structure/sewer_piece/drain/D in line)
		D.clog_chance = 100
	T.flush_waste(s2_poo(T.loc))
	var/clogs = 0
	for (var/obj/structure/sewer_piece/drain/D in line)
		if (D.clogged)
			clogs++
			D.set_clogged(FALSE)
		D.clog_chance = 0
	sewer_check(clogs == 1, "waste silts up one drain at a time ([clogs])")

	// A river in flood over the outfall pushes back up the drains.
	F.restore_hollows(list(1, 0))
	F.stage[1] = 2
	sewer_check(abs(outfall.outfall_flood_level() - 2) < 0.001 && outfall.backflowing() && !outfall.outfall_open(), "the river stands over the outfall")
	sewer_check(!F.hollow_depth_at(locate(4, 4, 1)) && !flood_depth_at(locate(4, 4, 1)), "the rim keeps the river itself out of the hollow")
	F.drain_hollows()
	sewer_check(abs(F.hollow_volume[1] - 6) < 0.001, "backflow fills the hollow through the inlets ([F.hollow_volume[1]])")
	sewer_check(!T.flush_waste(s2_poo(T.loc)) && sewer_last_backflow, "and surges up the toilet")
	for (var/obj/item/weapon/reagent_containers/food/snacks/poo/P in T.loc)
		qdel(P)
	F.restore_hollows(list(1, 12))
	F.drain_hollows()
	sewer_check(abs(F.hollow_volume[1] - 12) < 0.001, "backflow stops at the hollow's spill")

	// A flap gate holds the river out and the waste in.
	F.restore_hollows(list(1, 0))
	var/obj/structure/sewer_flap_gate/G = new /obj/structure/sewer_flap_gate(outfall.loc)
	sewer_check(G.dir == EAST && !outfall.backflowing(), "the gate hangs toward the water")
	F.drain_hollows()
	sewer_check(F.hollow_volume[1] == 0, "a gated outfall lets no river in")
	var/fouled = outfall.last_waste
	sewer_check(T.flush_waste(s2_poo(T.loc)) && outfall.last_waste == fouled, "the sewer holds waste behind a shut gate")
	F.restore_hollows(list(1, 6))
	F.drain_hollows()
	sewer_check(F.hollow_volume[1] == 6, "nothing drains out against the river")
	F.stage[1] = 0
	F.drain_hollows()
	sewer_check(F.hollow_volume[1] < 6, "when the river falls the gate opens and the hollow drains")

	// Brick sewers carry the most.
	var/obj/structure/sewer_piece/drain/brick/B = new /obj/structure/sewer_piece/drain/brick(locate(5, 3, 1))
	var/obj/structure/sewer_piece/drain/stone/ST = /obj/structure/sewer_piece/drain/stone
	sewer_check(findtext(B.icon_state, "brick_drain") == 1 && B.inlet_rate > initial(ST.inlet_rate) && B.clog_chance < initial(ST.clog_chance), "a brick sewer carries more and clogs less")
