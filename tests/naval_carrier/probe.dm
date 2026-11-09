// Turf-built vessels, phase 1: the aircraft carrier is laid down as three
// decks on three stacked levels, hops along its heading with everything
// aboard, refuses land, obstacles and the map edge, comes about, and is taken
// off the map again. Its hangar deck reports to its own flooding controller.
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

// Rock under the sea, deep water at the surface, open air above: Gaia's
// three levels around the ocean.
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

/proc/naval_near(a, b, tolerance = 0.01)
	return abs(a - b) <= tolerance

/proc/naval_checks()
	naval_fixture()
	var/water_tiles = naval_count(2, /turf/floor/beach/water/deep)
	var/rock_tiles = naval_count(1, /turf/wall/rockwall)
	var/sky_tiles = naval_count(3, /turf/sky/building)
	naval_check(water_tiles == world.maxx * world.maxy && rock_tiles == water_tiles && sky_tiles == water_tiles, "fixture: rock under deep water under open air")

	// The Submarine Commander boat keeps its global controller.
	var/datum/flooding_controller/subcom = new
	naval_check(global.subcom_flooding == subcom && (subcom in flooding_controllers) && !subcom.vessel, "a bare flooding controller is still SUBCOM13's global one")
	var/turf/plain = locate(60, 55, 2)
	plain = plain.ChangeTurf(/turf/floor/sub_deck/galley)
	var/turf/floor/sub_deck/plain_deck = plain
	naval_check(plain_deck.flooding_owner == subcom && plain_deck.compartment_air() == subcom.get_air(SUB_COMP_GALLEY), "a deck tile outside any vessel reports to the SUBCOM13 controller")
	subcom.unregister_turf(plain_deck)
	plain.ChangeTurf(/turf/floor/beach/water/deep/saltwater)

	// Lay the carrier down: south-west corner (5, 26), bow east.
	var/datum/vessel/carrier/C = carrier_lay_down(locate(5, 26, 2), EAST)
	naval_check(istype(C) && C.placed && C.ox == 5 && C.oy == 26 && C.dir == EAST, "the carrier is laid down bow east ([istype(C) ? "placed" : "refused: [C ? C["refused"] : "null"]"])")
	if (!istype(C))
		return
	naval_check(C.flooding && C.flooding != subcom && C.flooding.vessel == C && (C.flooding in flooding_controllers) && !C.flooding.breaches_vent(), "the carrier owns a flooding controller that keeps its air when breached")
	var/list/cells = C.cells()
	var/hangar_cells = 0
	var/deck_cells = 0
	var/island_cells = 0
	for (var/turf/T in cells)
		if (T.z == 1) hangar_cells++
		if (T.z == 2) deck_cells++
		if (T.z == 3) island_cells++
	naval_check(hangar_cells == 342 && deck_cells == 360 && island_cells == 15, "three decks: hangar [hangar_cells]/342, flight deck [deck_cells]/360, island [island_cells]/15")
	naval_check(istype(locate(5, 26, 2), /turf/floor/plating/carrier_deck) && istype(locate(44, 34, 2), /turf/floor/plating/carrier_deck) && istype(locate(5, 26, 1), /turf/wall/rockwall) && istype(locate(6, 26, 1), /turf/wall/sub_hull/carrier), "the flight deck overhangs the hull by one tile at each end")
	var/turf/floor/sub_deck/engine = locate(7, 30, 1)
	var/turf/floor/sub_deck/hangar = locate(25, 31, 1)
	naval_check(istype(engine, /turf/floor/sub_deck/carrier/engine_room) && istype(hangar, /turf/floor/sub_deck/carrier/hangar), "compartments lie stern to bow (engine room aft, hangar amidships)")
	naval_check(istype(locate(11, 30, 1), /turf/floor/sub_deck/carrier/bunker) && (locate(/obj/structure/simple_door/blast) in locate(11, 30, 1)) && istype(locate(11, 29, 1), /turf/wall/sub_bulkhead/carrier), "each bulkhead has one blast door on the centreline")
	var/datum/habitat_ledger/engine_air = C.flooding.get_air(CARRIER_COMP_ENGINE_ROOM)
	var/datum/habitat_ledger/hangar_air = C.flooding.get_air(CARRIER_COMP_HANGAR)
	naval_check(engine.flooding_owner == C.flooding && engine.compartment_air() == engine_air && engine_air.volume == 28 && hangar_air.volume == 113 && naval_near(engine_air.oxygen_kpa(), 21, 0.5), "hangar deck tiles report to the carrier's controller: engine room 28 tiles, hangar 113, sea-level air")
	naval_check(C.flooding.tracked_turfs.len == 222, "the controller tracks every deck tile ([C.flooding.tracked_turfs.len]/222)")
	naval_check(subcom.tracked_turfs.len == 0, "the SUBCOM13 controller did not pick up carrier tiles")
	var/obj/structure/vessel_helm/helm = locate(/obj/structure/vessel_helm) in locate(25, 27, 3)
	naval_check(helm && helm.vessel == C, "the helm stands on the island and knows its ship")
	var/obj/structure/multiz/ladder/down = locate(/obj/structure/multiz/ladder) in locate(25, 30, 2)
	var/obj/structure/multiz/ladder/up/hatch = locate(/obj/structure/multiz/ladder/up) in locate(25, 30, 1)
	var/obj/structure/multiz/ladder/up/island_foot = locate(/obj/structure/multiz/ladder/up) in locate(23, 28, 2)
	var/obj/structure/multiz/ladder/island_top = locate(/obj/structure/multiz/ladder) in locate(23, 28, 3)
	naval_check(down && hatch && down.target == hatch && hatch.target == down, "the flight deck hatch ladder pairs with the hangar ladder")
	naval_check(island_foot && island_top && island_foot.target == island_top && island_top.target == island_foot, "the island ladder pairs with its foot on the flight deck")
	naval_check(vessel_at(locate(10, 30, 2)) == C && !vessel_at(locate(4, 30, 2)) && !vessel_at(locate(10, 30, 3)) && vessel_at(locate(25, 27, 3)) == C, "vessel_at finds the ship on each level and nothing beside it")

	// Cargo, crew and damage aboard.
	var/obj/structure/closet/crate/crate = new(locate(10, 30, 2))
	var/mob/living/human/naval_probe/sailor = new(locate(12, 30, 2))
	var/obj/item/weapon/reagent_containers/glass/bucket/bucket = new(locate(8, 29, 1))
	var/turf/wall/sub_hull/wall = locate(6, 30, 1)
	wall.apply_breach_damage(1000)
	var/turf/floor/sub_deck/wet = locate(7, 30, 1)
	naval_check(wall.breached && wet.water_inflow_rate == SUB_BREACH_INFLOW_BASE && wet.water_depth == SUB_BREACH_INFLOW_BASE, "a torpedo-sized hit breaches the hull and floods the engine room")
	engine_air.oxygen *= 0.5
	var/o2_before = engine_air.oxygen_kpa()

	// One hop at full ahead: six tiles east with everything aboard. The
	// bunkers are filled first; the shipyard probe covers dry ones.
	C.bunker(C.fuel_capacity)
	C.set_anchor(FALSE)
	C.set_speed(VESSEL_SPEED_FULL)
	naval_check(C.hop_timer, "weighing anchor at full ahead starts the hop timer")
	C.stop_sailing()
	naval_check(C.sail_tick() && C.ox == 11 && C.oy == 26, "a hop at full ahead moves the ship six tiles ([C.ox],[C.oy])")
	world.log << "hop took [C.last_hop_ms] ms"
	naval_check(C.last_hop_ms < 3000, "a hop finishes in under three seconds ([C.last_hop_ms] ms)")
	naval_check(crate.loc == locate(16, 30, 2) && sailor.loc == locate(18, 30, 2) && bucket.loc == locate(14, 29, 1), "crate, sailor and bucket ride along")
	naval_check(helm.loc == locate(31, 27, 3) && helm.vessel == C, "the helm rides along on the island")
	naval_check(istype(locate(5, 26, 2), /turf/floor/beach/water/deep) && istype(locate(10, 34, 2), /turf/floor/beach/water/deep) && istype(locate(6, 30, 1), /turf/wall/rockwall) && istype(locate(23, 28, 3), /turf/sky/building), "the sea, rock and sky come back where the ship was")
	naval_check(istype(locate(50, 30, 2), /turf/floor/plating/carrier_deck) && istype(locate(49, 30, 1), /turf/wall/sub_hull/carrier), "the bow now reaches tile 50")
	var/turf/wall/sub_hull/moved_wall = locate(12, 30, 1)
	var/turf/floor/sub_deck/moved_wet = locate(13, 30, 1)
	naval_check(moved_wall.breached && moved_wall.breach_inflow_rate == SUB_BREACH_INFLOW_BASE && moved_wet.water_inflow_rate == SUB_BREACH_INFLOW_BASE && moved_wet.water_depth == SUB_BREACH_INFLOW_BASE, "the breach and the water aboard move with the hull")
	var/datum/habitat_ledger/engine_after = C.flooding.get_air(CARRIER_COMP_ENGINE_ROOM)
	naval_check(engine_after && engine_after.volume == 28 && naval_near(engine_after.oxygen_kpa(), o2_before, 0.05), "the engine room keeps its thinned air across the hop ([engine_after ? engine_after.oxygen_kpa() : "none"] vs [o2_before] kPa)")
	naval_check(C.flooding.tracked_turfs.len == 222 && moved_wet.flooding_owner == C.flooding && !istype(wet, /turf/floor/sub_deck), "the controller tracks the new deck tiles and none of the old")
	down = locate(/obj/structure/multiz/ladder) in locate(31, 30, 2)
	hatch = locate(/obj/structure/multiz/ladder/up) in locate(31, 30, 1)
	naval_check(down && hatch && down.target == hatch && hatch.target == down, "the ladders still pair after the hop")
	C.flooding.process_tick()
	naval_check(moved_wet.water_depth > SUB_BREACH_INFLOW_BASE, "the flooding tick keeps the breached compartment filling")

	// Land ahead stops the ship where it is.
	var/turf/land = locate(51, 30, 2)
	land.ChangeTurf(/turf/floor/dirt)
	naval_check(!C.sail_tick() && C.ox == 11 && C.speed == VESSEL_SPEED_STOP && findtext(C.last_refusal, "ahead"), "land off the bow stops the ship ([C.last_refusal])")
	land.ChangeTurf(/turf/floor/beach/water/deep/saltwater)
	// A rock three tiles off the bow: the ship closes up to it with a shorter hop.
	var/obj/structure/closet/crate/rock = new(locate(53, 30, 2))
	C.set_speed(VESSEL_SPEED_FULL)
	naval_check(C.sail_tick() && C.ox == 13 && findtext(C.last_refusal, "in the way"), "an obstacle three tiles ahead leaves a two-tile hop ([C.ox])")
	naval_check(!C.sail_tick() && C.ox == 13 && C.speed == VESSEL_SPEED_STOP, "hard against the obstacle the ship stops")
	qdel(rock)
	// A level that is being saved is never rewritten.
	C.set_speed(VESSEL_SPEED_FULL)
	persistence_save_in_progress = TRUE
	naval_check(!C.sail_tick() && C.ox == 13 && C.speed == VESSEL_SPEED_FULL, "no hop while a world save runs")
	persistence_save_in_progress = FALSE
	// The map edge.
	var/datum/vessel/carrier/edge = new
	naval_check(!edge.place(40, 50, 2, EAST) && edge.last_refusal == "the edge of the world" && !edge.placed, "a ship that would cross the map edge is refused")
	naval_check(!edge.place(20, 30, 2, EAST) && findtext(edge.last_refusal, "ahead") && !edge.placed, "a second ship cannot be laid over the first ([edge.last_refusal])")
	qdel(edge)

	// Coming about: north, around the centre of the ship.
	naval_check(C.turn_to(NORTH) && C.dir == NORTH, "the ship comes about to the north ([C.ox],[C.oy], [C.last_refusal])")
	naval_check(istype(locate(C.ox, C.oy, 2), /turf/floor/plating/carrier_deck) && istype(locate(C.ox + 8, C.oy + 39, 2), /turf/floor/plating/carrier_deck) && !istype(locate(C.ox + 9, C.oy, 2), /turf/floor/plating/carrier_deck), "the footprint is now 9 wide and 40 long")
	// Ship cell (u 20, v 7) heading north lies at dx = 7, dy = 20.
	naval_check(helm.loc == locate(C.ox + 7, C.oy + 20, 3), "the helm is where the island now stands")
	naval_check(sailor.loc && sailor.loc.z == 2 && istype(sailor.loc, /turf/floor/plating/carrier_deck), "the sailor is still on the flight deck")
	naval_check(naval_count(2, /turf/floor/plating/carrier_deck) == 360 && naval_count(1, /turf/wall/sub_hull/carrier) == 90 && C.flooding.tracked_turfs.len == 222, "no deck or hull was left behind by the turn")
	hatch = locate(/obj/structure/multiz/ladder/up) in locate(C.ox + 4, C.oy + 20, 1)
	down = locate(/obj/structure/multiz/ladder) in locate(C.ox + 4, C.oy + 20, 2)
	naval_check(down && hatch && down.target == hatch, "the hatch ladder pairs after the turn")

	// Off the map.
	C.remove()
	naval_check(!C.placed && naval_count(2, /turf/floor/beach/water/deep) == world.maxx * world.maxy && naval_count(1, /turf/wall/rockwall) == world.maxx * world.maxy && naval_count(3, /turf/sky/building) == world.maxx * world.maxy, "removing the ship puts back every tile of sea, rock and sky")
	naval_check(C.flooding.tracked_turfs.len == 0 && !C.flooding.compartment_air.len, "the controller forgets the decks")
	naval_check(istype(crate.loc, /turf/floor/beach/water/deep) && !vessel_at(crate.loc), "what stood on deck is left in the water")
	qdel(C)
	naval_check(!(C in naval_vessels) && !(C.flooding in flooding_controllers), "a deleted vessel leaves the registries")

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
