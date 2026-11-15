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
	shard_group.peers -= list("northamerica", "europe", "southamerica")
	shard_group.region = old_region
	shard_group.enabled = old_enabled
