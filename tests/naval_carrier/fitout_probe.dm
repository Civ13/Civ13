// Turf-built vessels, phase 5: the fit-out. A bow catapult throws a parked
// plane into the air without a deck roll and refuses a plane off the track,
// pointed the wrong way or with its engine cold; gun tubs at the corners
// keep planes off; deck edge lights switch from the wheel and are saved with
// the ship; the island radar lists ships, other vessels and aircraft in
// range and carries two searchlights; shoring kits are a Submarines recipe.
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
/obj/map_metadata/naval_probe/New()
	return
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

/proc/naval_fixture()
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			var/turf/R = locate(x, y, 1)
			R.ChangeTurf(/turf/wall/rockwall)
			var/turf/W = locate(x, y, 2)
			W.ChangeTurf(/turf/floor/beach/water/deep/saltwater)
			var/turf/S = locate(x, y, 3)
			S.ChangeTurf(/turf/sky/building)

/proc/naval_count(z, path)
	. = 0
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			if (istype(locate(x, y, z), path))
				.++

/proc/naval_count_objects(z, path)
	. = 0
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			var/turf/T = locate(x, y, z)
			for (var/atom/A in T)
				if (istype(A, path) && !QDELETED(A))
					.++

// Fills every tile of a compartment to the flooded mark.

// Fills every tile of a compartment to the flooded mark.
/proc/naval_flood(datum/vessel/V, cid)
	for (var/turf/floor/sub_deck/T in V.flooding.compartment_turfs[cid])
		T.add_water(200)

/proc/naval_fuel(obj/structure/vehicleparts/axis/aircraft/A)
	var/obj/structure/engine/internal/E = A.engine
	E.fueltank.reagents.add_reagent(E.fuels[1], 100, safety = TRUE)
	E.on = TRUE

/proc/naval_frames_in(obj/structure/vehicleparts/axis/aircraft/A, z, x1, x2, y1, y2)
	var/list/F = A.frames()
	if (F.len != 12)
		return FALSE
	for (var/obj/structure/vehicleparts/frame/FR in F)
		if (FR.z != z || FR.x < x1 || FR.x > x2 || FR.y < y1 || FR.y > y2)
			return FALSE
	return TRUE

/proc/naval_scrap(obj/structure/vehicleparts/axis/aircraft/A)
	var/list/F = A.frames()
	qdel(A)
	for (var/obj/structure/vehicleparts/frame/FR in F)
		qdel(FR)

/proc/naval_lit_lights(z)
	. = 0
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			for (var/obj/structure/lamp/lamp_small/alwayson/deck/L in locate(x, y, z))
				if (L.lit && L.light_range > 0)
					.++

/proc/naval_has_line(list/lines, prefix)
	for (var/line in lines)
		if (findtext(line, prefix) == 1)
			return line
	return null

/proc/naval_checks()
	naval_fixture()
	// Bow south with the south-west corner at (10, 10): ship cell (u, v) is
	// world tile (18 - v, 49 - u). The bow is at y 10, the catapult track
	// (u 35-38, v 1-3) at x 15-17, y 11-14 with its lever at (16, 15), the
	// gun tubs at the four corners of the box, the deck lights along x 10
	// and x 18, and the island at x 10-12, y 27-31 on the level above with
	// the radar at (11, 27, 3) and searchlights at (10, 27, 3) and (10, 31, 3).
	// The light plane is built facing south, so it faces the bow.
	var/datum/vessel/carrier/C = carrier_lay_down(locate(10, 10, 2), SOUTH)
	naval_check(istype(C) && C.placed, "the carrier is laid down bow south")
	if (!istype(C))
		return
	C.bunker(C.fuel_capacity)

	// Layout.
	naval_check(naval_count(2, /turf/floor/plating/carrier_deck/catapult) == 12 && istype(locate(15, 11, 2), /turf/floor/plating/carrier_deck/catapult) && istype(locate(17, 14, 2), /turf/floor/plating/carrier_deck/catapult), "twelve catapult track tiles lie at the bow")
	var/turf/track = locate(16, 12, 2)
	naval_check(track.aircraft_runway() && track.aircraft_deck(), "the track counts as runway")
	var/tubs = 0
	for (var/turf/T in list(locate(10, 10, 2), locate(18, 10, 2), locate(10, 49, 2), locate(18, 49, 2)))
		if (istype(T, /turf/floor/plating/carrier_deck/gun_tub) && !T.aircraft_runway() && !T.aircraft_deck())
			tubs++
	naval_check(tubs == 4 && naval_count(2, /turf/floor/plating/carrier_deck/gun_tub) == 4, "a gun tub stands at each corner of the deck; it is no runway and the crash barrier keeps planes off it")
	var/obj/structure/vessel_lever/catapult/lever = locate(/obj/structure/vessel_lever/catapult) in locate(16, 15, 2)
	naval_check(lever && lever.ship() == C && lever.track().len == 12, "the catapult lever beside the track serves all twelve tiles")
	naval_check(naval_count_objects(2, /obj/structure/vessel_lever/elevator) == 2 && naval_count_objects(1, /obj/structure/vessel_lever/elevator) == 2, "the elevator levers are still on both decks")

	// Island fittings.
	var/obj/structure/vessel_radar/radar = locate(/obj/structure/vessel_radar) in locate(11, 27, 3)
	naval_check(radar && radar.ship() == C, "the radar set stands on the island")
	naval_check(naval_count_objects(3, /obj/structure/searchlight) == 2 && (locate(/obj/structure/searchlight) in locate(10, 27, 3)) && (locate(/obj/structure/searchlight) in locate(10, 31, 3)), "two searchlights stand at the island's corners")
	naval_check(locate(/obj/structure/vessel_helm) in locate(11, 29, 3), "the wheel is between them")

	// Deck lights.
	naval_check(naval_count_objects(2, /obj/structure/lamp/lamp_small/alwayson/deck) == 16 && naval_lit_lights(2) == 16, "sixteen deck lights line the deck edges and are lit")
	C.set_deck_lights(FALSE)
	naval_check(!C.deck_lights_on && naval_lit_lights(2) == 0, "the wheel switches the deck lights off")
	naval_check(findtext(C.save_state(), "\"deck_lights\":0"), "the saved state records the lights")
	C.set_deck_lights(TRUE)
	naval_check(naval_lit_lights(2) == 16, "and on again")

	// Catapult refusals.
	naval_check(lever.launch(null) == "There is no aircraft on the catapult.", "an empty catapult refuses")
	var/obj/structure/vehicleparts/axis/aircraft/W = build_light_plane(locate(13, 11, 2))
	naval_check(istype(W) && naval_frames_in(W, 2, 14, 16, 11, 14), "a plane built with a wheel off the track")
	var/refusal = lever.launch(null)
	naval_check(findtext(refusal, "not fully on the catapult track"), "is refused: [refusal]")
	naval_scrap(W)
	var/obj/structure/vehicleparts/axis/aircraft/A = build_light_plane(locate(14, 11, 2))
	naval_check(istype(A) && naval_frames_in(A, 2, 15, 17, 11, 14) && A.on_runway() && A.dir == SOUTH, "a plane built on the track faces the bow")
	refusal = lever.launch(null)
	naval_check(findtext(refusal, "engine is not running"), "a cold engine is refused: [refusal]")
	naval_fuel(A)
	A.dir = EAST
	refusal = lever.launch(null)
	naval_check(findtext(refusal, "nose to the bow (south)"), "a plane pointed across the deck is refused: [refusal]")
	A.dir = SOUTH
	naval_check(!A.airborne() && naval_frames_in(A, 2, 15, 17, 11, 14), "the refused plane has not moved")

	// The launch.
	refusal = lever.launch(null)
	naval_check(isnull(refusal) && A.airborne() && A.flight_state == AIRCRAFT_LOW && naval_frames_in(A, 3, 15, 17, 10, 14), "the catapult throws the plane into the air above the bow without a deck roll")
	naval_check(A.currentspeed == A.speeds && A.moving && !lever.busy, "it flies off at full speed and the catapult is ready again")
	naval_check(track.aircraft_runway() && !(locate(/obj/structure/vehicleparts/frame) in track), "the track is clear for the next plane")
	A.moving = FALSE

	// Radar contacts.
	var/list/lines = radar.contacts()
	naval_check(naval_has_line(lines, "Aircraft: "), "the radar sees the plane in the air: [naval_has_line(lines, "Aircraft: ")]")
	naval_check(!naval_has_line(lines, "Vessel: ") && !naval_has_line(lines, "Ship: "), "and nothing else yet")
	var/datum/vessel/carrier/O = carrier_lay_down(locate(30, 20, 2), EAST)
	var/obj/structure/vehicleparts/axis/ship/S = new(locate(20, 45, 2))
	lines = radar.contacts()
	var/vessel_line = naval_has_line(lines, "Vessel: ")
	var/ship_line = naval_has_line(lines, "Ship: ")
	naval_check(istype(O) && vessel_line && findtext(vessel_line, "bow to the east") && findtext(vessel_line, "stopped"), "a second carrier shows as a stopped vessel with its heading: [vessel_line]")
	naval_check(ship_line && findtext(ship_line, "tiles") && findtext(ship_line, "stopped"), "a ship's rudder axis shows as a ship: [ship_line]")
	naval_check(lines.len == 3, "three contacts in all")
	var/obj/structure/vessel_radar/other = locate(/obj/structure/vessel_radar) in locate(52, 21, 3)
	var/list/other_lines = other ? other.contacts() : list()
	var/our_line = naval_has_line(other_lines, "Vessel: ")
	var/other_vessels = 0
	for (var/line in other_lines)
		if (findtext(line, "Vessel: ") == 1)
			other_vessels++
	naval_check(other && our_line && findtext(our_line, "bow to the south") && other_vessels == 1, "the other ship's radar sees this one and leaves herself out: [our_line]")
	qdel(S)
	lines = radar.contacts()
	naval_check(!naval_has_line(lines, "Ship: "), "a scrapped ship drops off the screen")

	// Recipes.
	build_research_tree()
	naval_check(get_recipe_node_req("/obj/item/weapon/shoring_kit") == "submarines" && get_recipe_node_req("/obj/structure/car_workshop/shipyard") == "naval_aviation", "shoring kits need Submarines and the shipyard Naval Aviation")

	// Fittings go down with the ship.
	O.sink()
	naval_check(QDELETED(O) && naval_count_objects(2, /obj/structure/vessel_lever) == 3 && naval_count_objects(3, /obj/structure/vessel_radar) == 1, "scuttling the other carrier takes her fittings and leaves this ship's")
	naval_flood(C, CARRIER_COMP_ENGINE_ROOM)
	naval_flood(C, CARRIER_COMP_BUNKER)
	naval_flood(C, CARRIER_COMP_QUARTERS)
	C.flooding.process_tick()
	naval_check(QDELETED(C) && naval_count(2, /turf/floor/plating/carrier_deck) == 0, "three flooded compartments sink her")
	naval_check(naval_count_objects(2, /obj/structure/lamp/lamp_small/alwayson/deck) == 0 && naval_count_objects(3, /obj/structure/vessel_radar) == 0 && naval_count_objects(3, /obj/structure/searchlight) == 0 && naval_count_objects(2, /obj/structure/vessel_lever) == 0 && naval_count_objects(1, /obj/structure/vessel_lever) == 0, "the lights, radar, searchlights and levers go down with her")
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
