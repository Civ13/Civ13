// Turf-built vessels, phase 3: players lay the carrier down. The shipyard
// office is gated on Naval Aviation, checks that a carrier fits on the sea
// north-east of it, lays it down for steel, glass and cable; the bunkers take
// fuel oil and a dry ship stops; the helm's chart reads position, fuel and
// what lies ahead; the helm saves the ship's state and rebuilds it after a
// load over decks that are already on the map.
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
var/naval_research_done = FALSE
/obj/map_metadata/naval_probe/New()
	return
/obj/map_metadata/naval_probe/is_node_done(faction, node_id)
	return naval_research_done
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

/proc/naval_checks()
	naval_fixture()
	build_research_tree()

	// Research: Naval Aviation follows Powered Flight and Submarines and gates the office.
	var/datum/research_node/N = get_research_node("naval_aviation")
	naval_check(N && ("powered_flight" in N.prereqs) && ("submarines" in N.prereqs) && N.category == "Industrial", "Naval Aviation needs Powered Flight and Submarines")
	naval_check(get_recipe_node_req("/obj/structure/car_workshop/shipyard") == "naval_aviation", "the shipyard office recipe is gated on Naval Aviation")

	// The office stands on a shore tile at (4, 25); the ship's corner is (5, 26).
	var/turf/shore = locate(4, 25, 2)
	shore.ChangeTurf(/turf/floor/beach/sand)
	var/mob/living/human/naval_probe/wright = new(locate(4, 24, 2))
	var/obj/structure/car_workshop/shipyard/office = new(shore)
	var/refusal = office.build_refusal(wright, shore)
	naval_check(refusal && findtext(refusal, "Naval Aviation") && findtext(refusal, "power cable") && !findtext(refusal, "deep sea"), "without research the office reports the research and the cable, and the sea fits ([refusal])")
	naval_research_done = TRUE
	refusal = office.build_refusal(wright, shore)
	naval_check(refusal && !findtext(refusal, "research") && findtext(refusal, "power cable"), "with research only the cable is missing ([refusal])")
	naval_check(office.clear_footprint("Aircraft carrier, bow east") && office.clear_footprint("Aircraft carrier, bow west"), "a carrier fits bow east or west on the sea north-east of the office")
	var/list/why = list()
	naval_check(!office.vessel_fits("Aircraft carrier, bow north", why) && why.len && findtext(why[1], "edge of the world"), "bow north it would run off the map ([why.len ? why[1] : "no reason"])")
	naval_check(!naval_vessels.len, "fit checks lay nothing down")

	// Laying down costs the materials and puts the ship on the sea.
	naval_check(!office.has_inputs("Aircraft carrier, bow east") && !office.complete_assembly("Aircraft carrier, bow east") && !naval_vessels.len, "an empty office lays nothing down")
	office.stock["steel"] = 450
	office.stock["glass"] = 25
	office.stock["cable"] = 40
	var/datum/vessel/carrier/C = office.complete_assembly("Aircraft carrier, bow east")
	naval_check(istype(C) && C.placed && C.ox == 5 && C.oy == 26 && C.dir == EAST && C.base_z == 2, "the office lays the carrier down bow east at (5, 26)")
	if (!istype(C))
		return
	naval_check(office.stock["steel"] == 50 && office.stock["glass"] == 5 && office.stock["cable"] == 0, "400 steel, 20 glass and 40 cable are spent")
	naval_check(C.fuel == 0 && C.anchored && C.speed == VESSEL_SPEED_STOP, "the new ship is anchored with empty bunkers")
	var/turf/second_shore = locate(30, 25, 2)
	second_shore.ChangeTurf(/turf/floor/beach/sand)
	var/obj/structure/car_workshop/shipyard/second = new(second_shore)
	second.stock["steel"] = 450
	second.stock["glass"] = 25
	second.stock["cable"] = 40
	naval_check(!second.clear_footprint("Aircraft carrier, bow east") && !second.complete_assembly("Aircraft carrier, bow east") && second.stock["steel"] == 450 && naval_vessels.len == 1, "a second office whose sea is under the first ship lays nothing down")

	// Bunkers: a dry ship will not sail; pouring takes only fuel oil.
	var/obj/structure/vessel_bunker/valve = locate(/obj/structure/vessel_bunker) in locate(12, 32, 1)
	var/obj/structure/vessel_helm/helm = locate(/obj/structure/vessel_helm) in locate(25, 27, 3)
	naval_check(valve && istype(valve.loc, /turf/floor/sub_deck/carrier/bunker) && valve.ship() == C && helm && helm.vessel == C, "the bunker filling point stands in the fuel bunker and the helm on the island")
	C.set_anchor(FALSE)
	C.set_speed(VESSEL_SPEED_FULL)
	C.stop_sailing()
	naval_check(!C.sail_tick() && C.ox == 5 && C.speed == VESSEL_SPEED_STOP && findtext(C.last_refusal, "dry"), "with dry bunkers a hop stops the ship ([C.last_refusal])")
	var/mob/living/human/naval_probe/stoker = new(locate(13, 32, 1))
	var/obj/item/weapon/reagent_containers/glass/barrel/barrel = new(locate(13, 32, 1))
	barrel.reagents.add_reagent("diesel", 150, safety = TRUE)
	barrel.reagents.add_reagent("water", 50, safety = TRUE)
	valve.attackby(barrel, stoker)
	naval_check(C.fuel == 150 && barrel.reagents.get_reagent_amount("diesel") == 0 && barrel.reagents.get_reagent_amount("water") == 50, "pouring a barrel takes its diesel and leaves the water")
	barrel.reagents.add_reagent("petroleum", 100, safety = TRUE)
	valve.attackby(barrel, stoker)
	naval_check(C.fuel == 250, "petroleum is fuel oil too")
	naval_check(C.bunker(5000) == C.fuel_capacity - 250 && C.fuel == C.fuel_capacity, "the bunkers hold [C.fuel_capacity] units")
	C.fuel = 20
	C.set_speed(VESSEL_SPEED_FULL)
	C.stop_sailing()
	naval_check(C.sail_tick() && C.ox == 11 && C.fuel == 20 - 3 * VESSEL_FUEL_PER_STEP, "a hop at full ahead burns [3 * VESSEL_FUEL_PER_STEP] units ([C.fuel] left)")
	naval_check(C.sail_tick() && C.ox == 17 && C.fuel == 20 - 6 * VESSEL_FUEL_PER_STEP, "and the next one the same")
	naval_check(C.hops_of_fuel() == 1, "the chart counts one hop of fuel left")
	naval_check(C.sail_tick() && C.ox == 23 && !C.sail_tick() && C.ox == 23 && C.speed == VESSEL_SPEED_STOP, "the last hop empties the bunkers and the ship stops")

	// The chart.
	var/chart = C.chart_text()
	naval_check(findtext(chart, "bow to the east") && findtext(chart, "all stop") && findtext(chart, "Bunkers: 2 of") && findtext(chart, "Ahead: the edge of the world, 9 tiles ahead"), "the chart reads heading, telegraph, fuel and the map edge nine tiles off the bow ([chart])")
	var/turf/rock = locate(66, 30, 2)
	rock.ChangeTurf(/turf/wall/rockwall)
	chart = C.chart_text()
	naval_check(findtext(chart, "Ahead: cave wall, 4 tiles ahead"), "the chart warns of rock four tiles off the bow ([chart])")

	// Saving: the helm keeps the ship's state; a load rebuilds the vessel
	// over the decks that came back as turfs.
	C.fuel = 300
	C.anchored = FALSE
	helm.before_save()
	naval_check(length(helm.vessel_state) > 100 && findtext(helm.vessel_state, "\"fuel\":300"), "before a save the helm records the ship's state")
	var/turf/deck = locate(30, 30, 2)
	var/turf/floor/sub_deck/hangar = locate(35, 30, 1)
	var/datum/flooding_controller/old_controller = C.flooding
	qdel(C)
	naval_check(!vessel_at(deck) && !naval_vessels.len && istype(deck, /turf/floor/plating/carrier_deck) && hangar.flooding_owner == old_controller, "with the vessel gone the decks are still on the map and orphaned")
	helm.after_load()
	var/datum/vessel/carrier/R = helm.vessel
	naval_check(istype(R) && R != C && R.placed && R.ox == 23 && R.oy == 26 && R.dir == EAST && R.base_z == 2 && R.fuel == 300 && !R.anchored, "after a load the helm rebuilds the carrier where it was, with its fuel")
	if (!istype(R))
		return
	naval_check(vessel_at(deck) == R && vessel_at(hangar) == R && hangar.flooding_owner == R.flooding && R.flooding.tracked_turfs.len == 222 && !(hangar in old_controller.tracked_turfs), "the decks are the rebuilt ship's again and its controller tracks every deck tile ([R.flooding.tracked_turfs.len])")
	var/datum/habitat_ledger/hangar_air = R.flooding.get_air(CARRIER_COMP_HANGAR)
	naval_check(hangar_air && hangar_air.volume == 113 && hangar_air.oxygen_kpa() > 20, "the hangar breathes sea-level air again (113 tiles)")
	naval_check(!R.hop_timer, "a stopped ship does not sail by itself after a load")
	helm.after_load()
	naval_check(helm.vessel == R && naval_vessels.len == 1, "a second load does not build a second ship")
	R.set_speed(VESSEL_SPEED_SLOW)
	R.stop_sailing()
	naval_check(R.sail_tick() && R.ox == 25 && istype(locate(23, 30, 2), /turf/floor/beach/water/deep) && istype(locate(24, 30, 1), /turf/wall/rockwall) && istype(locate(64, 30, 2), /turf/floor/plating/carrier_deck), "the rebuilt ship hops and puts the sea and rock back where it was")
	R.remove()
	naval_check(naval_count(2, /turf/floor/plating/carrier_deck) == 0 && naval_count(1, /turf/floor/sub_deck/carrier) == 0, "removing the rebuilt ship restores every tile")

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
