// Native probe for Stone and Classical flood defences (flood_defences.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/river_flow/defences_probe.dm
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
/obj/map_metadata/flood_defences_probe/New()
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
		map = new /obj/map_metadata/flood_defences_probe
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


	// Platforms lift what stands on them out of the water.
	F.restore_hollows(list(1, 6))
	var/turf/A = locate(4, 4, 1)
	var/turf/B = locate(4, 3, 1)
	sewer_check(abs(flood_depth_at(A) - 1) < 0.001, "the hollow stands a level deep ([flood_depth_at(A)])")
	var/obj/structure/flood_platform/stilts/S = new /obj/structure/flood_platform/stilts(A)
	var/obj/structure/flood_platform/plinth/P = new /obj/structure/flood_platform/plinth(B)
	sewer_check(A.flood_raise == 2 && B.flood_raise == 1, "platforms raise their tiles ([A.flood_raise], [B.flood_raise])")
	sewer_check(!flood_depth_at(A) && !flood_depth_at(B), "stilts and a plinth stand dry in a level of water")
	F.restore_hollows(list(1, 12))
	sewer_check(!flood_depth_at(A) && abs(flood_depth_at(B) - 1) < 0.001 && abs(flood_depth_at(locate(5, 4, 1)) - 2) < 0.001, "two levels: stilts dry, the plinth a level under, bare ground two")
	qdel(S)
	sewer_check(!A.flood_raise && abs(flood_depth_at(A) - 2) < 0.001, "taking the stilts away floods the tile")
	qdel(P)

	// A sluice gate holds water back like a bank only while shut.
	var/turf/G = locate(8, 2, 1)
	var/ground = flood_tile_ground(G)
	F.dirty_windows = list()
	var/obj/structure/sluice_gate/SG = new /obj/structure/sluice_gate(G)
	sewer_check(abs(flood_tile_ground(G) - ground - 1.5) < 0.001 && SG.density && F.dirty_windows.len == 1, "a shut sluice gate holds a level and a half and marks the ground changed")
	F.dirty_windows = list()
	SG.set_open(TRUE)
	sewer_check(abs(flood_tile_ground(G) - ground) < 0.001 && !SG.density && SG.icon_state == "sluice_gate_open" && F.dirty_windows.len == 1, "an open sluice gate lets the water through")
	SG.set_open(FALSE)
	sewer_check(SG.icon_state == "sluice_gate" && abs(flood_tile_ground(G) - ground - 1.5) < 0.001, "shut again, it holds")

	// Water lifts empty a hollow from its edge.
	F.restore_hollows(list(1, 6))
	var/obj/structure/water_lift/shaduf/SH = new /obj/structure/water_lift/shaduf(locate(3, 4, 1))
	sewer_check(SH.lift_hollow() == 1, "a shaduf on the hollow's edge can reach it")
	sewer_check(abs(SH.lift_once() - 0.5) < 0.001 && abs(F.hollow_volume[1] - 5.5) < 0.001, "a shaduf lifts half a level of water a bucket ([F.hollow_volume[1]])")
	var/obj/structure/water_lift/archimedes_screw/AS = new /obj/structure/water_lift/archimedes_screw(locate(5, 3, 1))
	sewer_check(abs(AS.lift_once() - 1.5) < 0.001 && abs(F.hollow_volume[1] - 4) < 0.001, "an Archimedes screw lifts three times as much")
	F.restore_hollows(list(1, 1))
	sewer_check(abs(AS.lift_once() - 1) < 0.001 && !F.hollow_volume[1] && !SH.lift_once(), "it lifts the last of the water, then nothing")
	var/obj/structure/water_lift/shaduf/OUT = new /obj/structure/water_lift/shaduf(locate(7, 4, 1))
	sewer_check(!OUT.lift_hollow(), "a shaduf away from a hollow lifts nothing")

	// A river gauge reads the river against its banks.
	var/obj/structure/river_gauge/RG = new /obj/structure/river_gauge(locate(9, 2, 1))
	F.stage[1] = 0
	var/list/low = RG.reading()
	sewer_check(islist(low) && findtext(low[1], "below the top of its banks"), "at low water the gauge shows the river under its banks ([low ? low[1] : "none"])")
	F.stage[1] = 2
	F.peak[1] = 2.5
	var/list/high = RG.reading()
	sewer_check(islist(high) && findtext(high[1], "over its banks") && findtext(high[2], "highest mark"), "in flood the gauge shows the river over its banks and the high mark ([high ? jointext(high, " ") : "none"])")
	var/obj/structure/river_gauge/DRY = new /obj/structure/river_gauge(locate(2, 2, 1))
	sewer_check(isnull(DRY.reading()), "a gauge far from any river reads nothing")

	// A cistern fills from the sky over it and the roofs around it.
	cistern_checks()

/obj/roof/cistern_tester/New()
	return

/proc/cistern_checks()
	var/turf/site = locate(2, 5, 1)
	var/area/A = get_area(site)
	A.location = AREA_OUTSIDE
	A.weather = WEATHER_NONE
	A.icon_state = ""
	season = "SPRING"
	time_of_day = "Midday"
	var/obj/structure/reagent_dispensers/cistern/C = new /obj/structure/reagent_dispensers/cistern(site)
	sewer_check(C.reagents.total_volume == 0 && C.icon_state == "cistern0" && (C in processing_objects), "a new cistern is empty and collecting")
	sewer_check(!C.collection_rate(), "no rain, no water")
	A.weather = WEATHER_WET
	A.icon_state = "rain2"
	sewer_check(C.collection_rate() == 10, "rain from the open sky ([C.collection_rate()])")
	new /obj/roof/cistern_tester(locate(1, 5, 1))
	new /obj/roof/cistern_tester(locate(3, 6, 1))
	new /obj/roof/cistern_tester(locate(5, 5, 1))
	sewer_check(C.collection_rate() == 10, "roofs are counted only now and then")
	C.roofs_counted = -100000
	sewer_check(C.roof_count() == 2 && C.collection_rate() == 16, "gutters on two roofs within reach add to it ([C.collection_rate()])")
	for (var/i in 1 to 30)
		C.last_collection_tick = world.time - 20
		C.process_interval(2)
	sewer_check(C.reagents.get_reagent_amount("water") == 16 && C.icon_state == "cistern1", "a minute of rain fills it ([C.reagents.total_volume], [C.icon_state])")
	C.reagents.add_reagent("water", 1990)
	sewer_check(C.icon_state == "cistern3", "a full cistern shows full")
	C.collect_minute()
	sewer_check(C.reagents.total_volume == 2000, "it never overflows")
	new /obj/roof/cistern_tester(site)
	C.roofs_counted = -100000
	sewer_check(C.collection_rate() == 9, "under a roof it takes in only from the gutters ([C.collection_rate()])")
