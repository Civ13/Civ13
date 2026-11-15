// Native probe for sewers phase S3: pumping stations, settling tanks, septic tanks.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/sewers/s3_probe.dm
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
/obj/map_metadata/sewer_s3_probe/New()
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
		map = new /obj/map_metadata/sewer_s3_probe
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


	// A steam pump on the outfall: idle, it shuts the drain against the river.
	var/obj/structure/sewer_pump/steam/P = new /obj/structure/sewer_pump/steam(outfall.loc)
	sewer_check(P.icon_state == "pump_steam" && !P.working() && P.why_not_running(), "a cold pump does not run")
	F.restore_hollows(list(1, 0))
	F.stage[1] = 2
	sewer_check(!outfall.backflowing() && outfall.gated(), "an idle pump's valve keeps the river out")
	F.drain_hollows()
	sewer_check(F.hollow_volume[1] == 0, "no river comes up through an idle pump")
	F.restore_hollows(list(1, 6))
	F.drain_hollows()
	sewer_check(abs(F.hollow_volume[1] - 6) < 0.001, "an idle pump lifts nothing over a flood")

	// Stoked and started, it lifts the hollow out over the flood.
	var/obj/item/stack/ore/coal/C = new /obj/item/stack/ore/coal(P.loc)
	C.amount = 2
	P.attackby(C, null)
	sewer_check(P.fuel == 60 && QDELETED(C), "two coal give an hour of pumping ([P.fuel])")
	P.on = TRUE
	P.update_icon()
	sewer_check(P.working() && outfall.pump() == P && P.icon_state == "pump_steam_on", "a stoked pump runs")
	F.drain_hollows()
	sewer_check(abs(F.hollow_volume[1] - 2) < 0.001 && P.fuel == 59, "the pump lifts the inlets' water over the flood and burns a minute of fuel ([F.hollow_volume[1]], [P.fuel])")
	var/obj/structure/sewer_piece/drain/third = new /obj/structure/sewer_piece/drain/stone(locate(4, 3, 1))
	third.clog_chance = 0
	F.restore_hollows(list(1, 12))
	F.drain_hollows()
	sewer_check(abs(F.hollow_volume[1] - 6) < 0.001 && world.time >= outfall.full_until, "a steam pump lifts three stone inlets' worth over a flood ([F.hollow_volume[1]])")
	var/obj/structure/sewer_piece/drain/fourth = new /obj/structure/sewer_piece/drain/stone(locate(5, 3, 1))
	fourth.clog_chance = 0
	F.restore_hollows(list(1, 12))
	F.drain_hollows()
	sewer_check(abs(F.hollow_volume[1] - 6) < 0.001 && world.time < outfall.full_until, "four inlets outrun it, and the sewer runs full ([F.hollow_volume[1]])")
	qdel(fourth)
	outfall.full_until = 0
	var/obj/structure/toilet/T = new /obj/structure/toilet(locate(7, 5, 1))
	var/fouled = outfall.last_waste
	sewer_check(T.flush_waste(s2_poo(T.loc)) && outfall.last_waste != fouled, "a toilet flushes over the flood, and the waste fouls the water")

	// A settling tank catches the waste until it fills.
	var/obj/structure/sewer_settling_tank/S = new /obj/structure/sewer_settling_tank(outfall.loc)
	outfall.last_waste = -100000
	sewer_check(T.flush_waste(s2_poo(T.loc)) && S.sludge == 1 && !outfall.recently_fouled() && S.icon_state == "settling1", "a settling tank keeps the outfall clean ([S.icon_state])")
	S.sludge = 60
	sewer_check(!S.take_sludge() && T.flush_waste(s2_poo(T.loc)) && outfall.recently_fouled(), "a full settling tank lets the waste through")
	S.sludge = 0
	S.sewer_update_icon()
	outfall.last_waste = -100000

	// Out of fuel it stops, and the drain stays shut.
	P.fuel = 1
	F.restore_hollows(list(1, 6))
	F.drain_hollows()
	sewer_check(abs(F.hollow_volume[1]) < 0.001 && !P.on && !P.working() && P.icon_state == "pump_steam", "a pump runs its last minute of fuel, then stops ([F.hollow_volume[1]])")
	F.restore_hollows(list(1, 6))
	F.drain_hollows()
	sewer_check(abs(F.hollow_volume[1] - 6) < 0.001, "a stopped pump holds the water in")

	// On dry ground a running pump adds to what the outfall takes.
	F.stage[1] = 0
	P.fuel = 10
	P.on = TRUE
	F.restore_hollows(list(1, 12))
	F.drain_hollows()
	sewer_check(abs(F.hollow_volume[1] - 6) < 0.001 && world.time >= outfall.full_until, "with the river low the pump and the outfall drain three inlets together ([F.hollow_volume[1]])")
	qdel(P)
	sewer_check(!outfall.gated() && !outfall.pump(), "taking the pump away opens the outfall")

	// An electric pump needs power.
	var/obj/structure/sewer_pump/electric/E = new /obj/structure/sewer_pump/electric(outfall.loc)
	E.on = TRUE
	var/obj/structure/sewer_pump/steam/SP = /obj/structure/sewer_pump/steam
	sewer_check(!E.working() && E.why_not_running() && E.pump_rate > initial(SP.pump_rate) && E.powerneeded > 0, "an electric pump without power does not run but would lift more")
	qdel(E)

	// A septic tank fouls nothing and digests what it holds.
	var/obj/structure/sewer_piece/cesspit/septic/ST = new /obj/structure/sewer_piece/cesspit/septic(locate(2, 1, 1))
	var/obj/structure/toilet/T2 = new /obj/structure/toilet(locate(1, 1, 1))
	sewer_check(T2.flush_waste(s2_poo(T2.loc)) && ST.waste == 1 && ST.icon_state == "septic1", "a toilet empties into a septic tank ([ST.icon_state])")
	var/obj/structure/sink/well/W = new /obj/structure/sink/well(locate(3, 2, 1))
	sewer_check(!W.has_nearby_fecal_waste() && !sewer_fouls_near(W), "a septic tank leaves a well beside it clean")
	ST.waste = 10
	ST.digested_at = world.realtime - 18000 * 3.5
	sewer_check(!ST.is_full() && ST.waste == 7 && world.realtime - ST.digested_at < 18000 * 0.6, "a septic tank digests a load each half hour ([ST.waste])")
	ST.waste = 120
	ST.digested_at = world.realtime
	sewer_check(!T2.flush_waste(s2_poo(T2.loc)), "a full septic tank backs up")
	var/obj/structure/sewer_piece/cesspit/CP = /obj/structure/sewer_piece/cesspit
	sewer_check(ST.capacity > initial(CP.capacity), "a septic tank holds more than a cesspit")
