// Turf-built vessels, phase 4: damage control. Blasts crater the flight deck
// (no runway until welded), breach the hull and buckle bulkheads without
// tearing the steel out as turfs, and set the hangar deck alight; craters
// ride hops; flooded compartments list the ship and take telegraph steps off
// her; at three flooded compartments she sinks, leaving her people in the
// water and wreckage where she was.
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
				if (istype(A, path))
					.++

// Fills every tile of a compartment to the flooded mark.
/proc/naval_flood(datum/vessel/V, cid)
	for (var/turf/floor/sub_deck/T in V.flooding.compartment_turfs[cid])
		T.add_water(200)

/proc/naval_checks()
	naval_fixture()
	// Bow east with the south-west corner at (5, 26): the same ship as the
	// vessel probe. Hull at (6, 30, 1), a bulkhead at (11, 29, 1), hangar
	// deck at (25, 31, 1), flight deck at (20, 30, 2), helm at (25, 27, 3).
	var/datum/vessel/carrier/C = carrier_lay_down(locate(5, 26, 2), EAST)
	naval_check(istype(C) && C.placed, "the carrier is laid down")
	if (!istype(C))
		return
	C.bunker(C.fuel_capacity)
	var/mob/living/human/naval_probe/sailor = new(locate(25, 31, 1))
	var/mob/living/human/naval_probe/deckhand = new(locate(30, 33, 2))
	var/obj/structure/closet/crate/crate = new(locate(20, 33, 2))
	var/obj/structure/vehicleparts/axis/aircraft/P = build_light_plane(locate(35, 28, 2))
	var/obj/structure/vessel_helm/helm = locate(/obj/structure/vessel_helm) in locate(25, 27, 3)
	naval_check(istype(P) && P.on_runway() && helm, "a plane is parked on the deck and the wheel is on the island")

	// Craters.
	var/turf/floor/plating/carrier_deck/deck = locate(20, 30, 2)
	deck.ex_act(1)
	naval_check(istype(locate(20, 30, 2), /turf/floor/plating/carrier_deck) && deck.cratered && !aircraft_runway_at(deck) && findtext(deck.name, "cratered"), "a blast craters the flight deck instead of tearing it out, and the crater is no runway")
	deck.repair_crater()
	naval_check(!deck.cratered && aircraft_runway_at(deck) && deck.name == initial(deck.name), "welding the crater shut makes it runway again")
	deck.ex_act(1)
	var/turf/floor/plating/carrier_deck/island = locate(25, 28, 3)
	island.ex_act(1)
	naval_check(istype(locate(25, 28, 3), /turf/floor/plating/carrier_deck/island) && island.cratered, "the island deck craters the same way")
	C.set_anchor(FALSE)
	C.set_speed(VESSEL_SPEED_SLOW)
	C.stop_sailing()
	naval_check(C.sail_tick() && C.ox == 7, "the ship hops two tiles")
	var/turf/floor/plating/carrier_deck/moved = locate(22, 30, 2)
	var/turf/floor/plating/carrier_deck/left = locate(20, 30, 2)
	naval_check(moved.cratered && !aircraft_runway_at(moved) && istype(left) && !left.cratered, "the crater rides the hop and the tile it left is whole")
	C.set_speed(VESSEL_SPEED_STOP)
	C.set_anchor(TRUE)
	naval_check(C.relocate(5, 26, EAST) && deck.cratered, "moving the ship back brings the crater back")

	// Hull and bulkheads take damage but stay steel.
	var/turf/wall/sub_hull/hull = locate(6, 30, 1)
	hull.ex_act(3)
	naval_check(istype(locate(6, 30, 1), /turf/wall/sub_hull/carrier) && hull.hull_integrity == 900 && !hull.breached, "a light blast scars the hull (900/1000)")
	hull.ex_act(2)
	naval_check(hull.hull_integrity == 600 && !hull.breached, "a medium blast cracks it (600/1000)")
	hull.ex_act(1)
	var/turf/floor/sub_deck/wet = locate(7, 30, 1)
	naval_check(istype(locate(6, 30, 1), /turf/wall/sub_hull/carrier) && hull.breached && wet.water_inflow_rate == SUB_BREACH_INFLOW_BASE, "a heavy blast breaches the hull and the engine room takes water, with the hull still a hull")
	var/turf/wall/sub_bulkhead/bulkhead = locate(11, 29, 1)
	bulkhead.ex_act(3)
	naval_check(istype(locate(11, 29, 1), /turf/wall/sub_bulkhead/carrier) && bulkhead.health == 175 && bulkhead.watertight, "a light blast dents a bulkhead and it holds water")
	bulkhead.ex_act(1)
	naval_check(istype(locate(11, 29, 1), /turf/wall/sub_bulkhead/carrier) && bulkhead.health == 25 && !bulkhead.watertight, "a heavy blast buckles its seals, and it is still a bulkhead")

	// Fire on the hangar deck.
	var/turf/floor/sub_deck/hangar = locate(25, 31, 1)
	hangar.ex_act(1)
	naval_check(istype(locate(25, 31, 1), /turf/floor/sub_deck/carrier/hangar) && hangar.fire_active && (locate(/obj/effect/fire) in hangar), "a blast on the hangar deck starts a fire and leaves the deck")
	hangar.extinguish_fire()
	naval_check(!hangar.fire_active && !(locate(/obj/effect/fire) in hangar), "the fire is put out")

	// Flooding lists the ship.
	var/water_before = wet.water_depth
	for (var/i = 1, i <= 10, i++)
		C.flooding.process_tick()
	naval_check(wet.water_depth > water_before && C.flooded_compartments() == 0 && C.max_speed == VESSEL_SPEED_FULL, "ten seconds of a breach fill the engine room a little, short of flooded ([wet.water_depth] cm)")
	naval_flood(C, CARRIER_COMP_ENGINE_ROOM)
	C.flooding.process_tick()
	naval_check(C.flooded_compartments() == 1 && C.max_speed == VESSEL_SPEED_HALF, "a flooded engine room lists the ship: half ahead at most")
	C.set_anchor(FALSE)
	C.set_speed(VESSEL_SPEED_FULL)
	naval_check(C.speed == VESSEL_SPEED_HALF, "ringing full ahead gives half ahead")
	var/chart = C.chart_text()
	naval_check(findtext(chart, "1 of 6 compartments flooded") && findtext(chart, "half ahead is all she will make"), "the chart reports the flooding and the list ([chart])")
	naval_flood(C, CARRIER_COMP_BUNKER)
	C.flooding.process_tick()
	naval_check(C.flooded_compartments() == 2 && C.max_speed == VESSEL_SPEED_SLOW && C.speed == VESSEL_SPEED_SLOW, "a second flooded compartment leaves slow ahead and slows the ship")
	C.flooding.emergency_drain(CARRIER_COMP_BUNKER, 500)
	C.flooding.process_tick()
	naval_check(C.flooded_compartments() == 1 && C.max_speed == VESSEL_SPEED_HALF, "pumping a compartment out eases the list")

	// Three flooded compartments sink her.
	var/datum/flooding_controller/controller = C.flooding
	naval_flood(C, CARRIER_COMP_BUNKER)
	naval_flood(C, CARRIER_COMP_QUARTERS)
	C.flooding.process_tick()
	naval_check(QDELETED(C) && !naval_vessels.len && !(controller in flooding_controllers), "with three compartments flooded the ship sinks and leaves the registries")
	naval_check(naval_count(2, /turf/floor/plating/carrier_deck) == 0 && naval_count(1, /turf/floor/sub_deck) == 0 && naval_count(1, /turf/wall/sub_hull) == 0 && naval_count(3, /turf/floor/plating/carrier_deck/island) == 0, "the decks are gone and the sea, rock and sky are back")
	naval_check(sailor.loc == locate(25, 31, 2) && istype(sailor.loc, /turf/floor/beach/water/deep), "the sailor from the hangar deck comes up into the water")
	naval_check(deckhand.loc == locate(30, 33, 2) && crate.loc == locate(20, 33, 2) && istype(crate.loc, /turf/floor/beach/water/deep), "the deckhand and the crate are in the water where the deck was")
	naval_check(QDELETED(P) && naval_count_objects(2, /obj/structure/vehicleparts/frame) == 0 && QDELETED(helm), "the plane and the wheel go down with the ship")
	naval_check(naval_count_objects(2, /obj/structure/barricade/debris) == 5 && naval_count_objects(1, /obj/structure/barricade/debris) == 0, "five pieces of wreckage float where she sank")

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
