// Flying between continents (aircraft_crossing.dm): routes from the shared
// layout, packing a flying plane into a record, and building her again in
// open sky in from the edge she flies in over.
/proc/aircraft_crossing_checks()
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			var/turf/T = locate(x, y, 2)
			if (!istype(T, /turf/sky/building))
				new /turf/sky/building(T)
	map.terrain_heights_cache = aircraft_probe_heights(list(), "0")
	// ---- Routes ----
	aircraft_check(continent_flight("gaia") && continent_flight("northamerica") && !continent_flight("far1"), "planes fly to continents with a flight level only")
	var/old_region = shard_group.region
	var/old_enabled = shard_group.enabled
	shard_group.enabled = TRUE
	shard_group.region = "gaia"
	shard_group.peers["northamerica"] = list("name" = "North America", "kind" = "SURFACE", "state" = "UP")
	shard_group.peers["europe"] = list("name" = "Europe", "kind" = "SURFACE", "state" = "UP")
	shard_group.peers["southamerica"] = list("name" = "South America", "kind" = "SURFACE", "state" = "STOPPED")
	var/list/routes = air_crossing_destinations()
	aircraft_check(routes.len == 2 && findtext(routes[1], "North America, to the west: 6 tiles of flying") && findtext(routes[2], "Europe, to the east: 5 tiles of flying"), "up continents with a flight level are offered, a stopped one is not ([jointext(routes, "; ")])")
	shard_group.region = "far1"
	aircraft_check(!length(air_crossing_destinations()), "a land off the layout offers no flights")
	shard_group.region = "gaia"

	// ---- Leaving ----
	var/obj/structure/vehicleparts/axis/aircraft/A = build_light_plane(locate(8, 40, 2))
	var/obj/structure/engine/internal/E = A.engine
	E.fueltank.reagents.add_reagent(E.fuels[1], 100, safety = TRUE)
	aircraft_check(findtext(A.air_crossing_refusal(null), "Take off first"), "a plane on the ground cannot fly to another land")
	A.set_flight_state(AIRCRAFT_CRUISE)
	aircraft_check(findtext(A.air_crossing_refusal(null), "Only the pilot"), "only the pilot sets the course")
	aircraft_check(!A.near_map_edge(), "in the middle of the map she is not near the edge")
	var/obj/structure/vehicleparts/axis/aircraft/N = build_light_plane(locate(8, 54, 2))
	N.set_flight_state(AIRCRAFT_CRUISE)
	aircraft_check(N.near_map_edge(), "within 8 tiles of the edge she is")
	var/per_second = A.cruise_fuel_per_second(null)
	aircraft_check(per_second > 0 && A.fuel_holding(per_second * 20 * 6) && !A.fuel_holding(1000), "a flight's fuel is reckoned from cruise burn ([per_second] a second)")
	var/old_turf = get_turf(A)
	var/list/packed = A.air_crossing_pack()
	aircraft_check(islist(packed) && islist(packed["record"]), "a flying, empty, stopped plane packs into a record ([istext(packed) ? packed : "ok"])")
	var/list/record = islist(packed) ? packed["record"] : null
	var/size = record ? length(json_encode(record)) : 0
	aircraft_check(record && size < 40000, "the record fits a travel payload ([size] bytes)")
	aircraft_check(get_turf(A) == old_turf && A.airborne() && !QDELETED(A), "packing moves and deletes nothing")
	var/list/plane = list("v" = 1, "record" = record, "name" = A.name, "dir" = NORTH, "gear" = 3, "state" = AIRCRAFT_CRUISE, "from" = list(8, 40, 2))
	aircraft_check(air_crossing_plane_ok(plane), "the plane record is well formed")
	aircraft_check(air_crossing_payload_ok(list("flight" = "gaia-1-2", "pilot" = 1, "plane" = plane)) && air_crossing_payload_ok(list("flight" = "gaia-1-2")) && air_crossing_payload_ok(list()), "payloads with and without her are accepted")
	var/list/bad = plane.Copy()
	bad["state"] = AIRCRAFT_GROUND
	aircraft_check(!air_crossing_payload_ok(list("flight" = "gaia-1-2", "plane" = bad)) && !air_crossing_payload_ok(list("plane" = plane)) && !air_crossing_payload_ok(list("flight" = "x", "pilot" = 2)), "malformed ones are refused")
	// Take her out of the sky as a crossing does.
	var/datum/extraction_vehicle_transfer/transfer = packed["transfer"]
	for (var/obj/O in transfer.parts)
		if (O != A)
			qdel(O)
	qdel(A)
	qdel(N)

	// ---- Arriving ----
	aircraft_check(air_crossing_flight_z() == 2, "planes arrive on the open-air level")
	var/turf/pivot = air_crossing_anchorage(plane)
	aircraft_check(pivot && pivot.z == 2 && pivot.y == 9, "flying north, she comes in over the south edge ([pivot ? "[pivot.x],[pivot.y]" : "none"])")
	var/list/along_plane = plane.Copy()
	along_plane["along"] = 1
	var/turf/along_pivot = air_crossing_anchorage(along_plane)
	aircraft_check(along_pivot && along_pivot.y == 9 && along_pivot.x == 12, "flown off an edge, she comes in at the place along it her line reaches, kept off the corner ([along_pivot ? "[along_pivot.x],[along_pivot.y]" : "none"])")
	var/obj/structure/vehicleparts/axis/aircraft/B = air_crossing_build(plane, pivot, "gaia-1-2")
	aircraft_check(istype(B) && B.airborne() && B.flight_state == AIRCRAFT_CRUISE && aircraft_frames_z(B, 2), "she is built flying on the open-air level")
	aircraft_check(B && air_crossing_find("gaia-1-2") == B && B.air_crossing_hold > world.time, "and holds steady for her crew")
	var/obj/structure/engine/internal/BE = B ? B.engine : null
	aircraft_check(BE && BE.fueltank && BE.fueltank.reagents.total_volume >= 99, "her fuel came with her ([BE && BE.fueltank ? BE.fueltank.reagents.total_volume : 0])")
	aircraft_check(B && !air_crossing_clear(record, pivot), "the sky she fills is no longer clear")
	B.air_crossing_hold = 0
	B.air_crossing_resume(3, null)
	aircraft_check(B.moving && B.currentspeed >= B.stall_gear && BE.on, "she flies on with her engine running")
	qdel(B)

	// ---- Over linked edges (aircraft_edge.dm) ----
	var/list/R = air_edge_route("europe", "east", 0.5)
	aircraft_check(islist(R) && R[1] == "asia" && R[2] == "west" && R[3] == 0.5 && R[4] == 1, "off Europe's east edge she flies straight into Asia, one leg ([islist(R) ? jointext(R, ",") : R])")
	R = air_edge_route("northamerica", "east", 0.64)
	aircraft_check(islist(R) && R[1] == "gaia" && R[2] == "west" && R[4] == 3, "off North America's east edge in line with Gaia she is carried over the Atlantic to Gaia's west edge ([islist(R) ? jointext(R, ",") : R])")
	R = air_edge_route("northamerica", "east", 0.1)
	aircraft_check(islist(R) && R[1] == "africa" && R[2] == "west" && R[4] == 6 && abs(R[3] - 0.1 / 0.42) < 0.01, "further south she crosses the whole Atlantic to Africa ([islist(R) ? jointext(R, ",") : R])")
	R = air_edge_route("gaia", "east", 0.5)
	aircraft_check(islist(R) && R[1] == "europe" && R[2] == "west" && R[4] == 4, "off Gaia's east edge she flies on to Europe ([islist(R) ? jointext(R, ",") : R])")
	R = air_edge_route("europe", "north", 0.5)
	aircraft_check(istext(R) && findtext(R, "sea"), "north over the Arctic there is nothing to land on ([R])")
	R = air_edge_route("far1", "north", 0.5)
	aircraft_check(istext(R), "a land off the table has nothing beyond its edges ([R])")
	var/list/edge_plane = plane.Copy()
	edge_plane["along"] = 0.25
	aircraft_check(air_crossing_plane_ok(edge_plane), "an edge flight's place along the arrival edge travels with her")
	edge_plane["along"] = 2
	aircraft_check(!air_crossing_plane_ok(edge_plane), "a place along that is off the edge is refused")
	shard_group.edge_travel_oceans = TRUE
	shard_group.region = "far1"
	var/obj/structure/vehicleparts/axis/aircraft/EP = build_light_plane(locate(6, 1, 2))
	var/obj/structure/engine/internal/EPE = EP.engine
	EPE.fueltank.reagents.add_reagent(EPE.fuels[1], 100, safety = TRUE)
	EPE.on = TRUE
	EP.set_flight_state(AIRCRAFT_CRUISE)
	EP.moving = TRUE
	EP.currentspeed = EP.speeds
	aircraft_check(!EP.do_vehicle_check() && EP.edge_blocked && !EP.air_crossing_asking, "with edge travel on, an edge with nothing beyond still stops her")
	qdel(EP)
	shard_group.edge_travel_oceans = FALSE
	shard_group.region = "gaia"
	shard_group.peers -= list("northamerica", "europe", "southamerica")
	shard_group.region = old_region
	shard_group.enabled = old_enabled
