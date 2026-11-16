// Native probe for station water tanks and running water feeds (station_water.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/station_water/station_water_probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 6
	maxy = 3
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/station_water_probe/New()
	return
var/sw_failures = 0
var/sw_runtime_error = FALSE
/proc/sw_check(condition, label)
	if (!condition)
		sw_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	sw_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		map = new /obj/map_metadata/station_water_probe
		sw_checks()
	catch(var/exception/e)
		sw_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = sw_failures, "runtime_error" = sw_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)


/obj/structure/station_water_probe
	name = "probe station"
	anchored = TRUE
	water_capacity = 50
	water_per_use = 20

/proc/sw_checks()
	// No river flow data here, so any fresh water beside a station feeds it.
	new /turf/floor/beach/water(locate(1, 2, 1))
	var/obj/structure/station_water_probe/near = new(locate(2, 2, 1))
	var/obj/structure/station_water_probe/far = new(locate(5, 2, 1))
	sw_check(near.station_water_feed() == "fresh water", "fresh water feeds a station beside it on an uncharted map")
	sw_check(near.station_take_water(null) && near.water_store == 0, "a fed station takes nothing from its tank")
	sw_check(!far.station_water_feed() && !far.station_take_water(null), "a dry unfed station refuses")

	var/obj/item/weapon/reagent_containers/glass/bucket/B = new(locate(5, 1, 1))
	B.reagents.add_reagent("water", 100)
	sw_check(far.station_water_pour(B, null) && far.water_store == 50 && B.reagents.get_reagent_amount("water") == 50, "pouring fills the tank up to its capacity")
	sw_check(far.station_take_water(null) && far.water_store == 30, "each use takes its share")
	sw_check(far.station_take_water(null) && !far.station_take_water(null) && far.water_store == 10, "the tank runs dry")

	// Pumped pipes fill it like any pipe sink.
	sw_check(far.fluid_demand_tier() == FLUID_TIER_SINK && far.fluid_demand("water") == 40 && !far.fluid_demand("fuel"), "a tank asks pipes for water only")
	sw_check(far.fluid_receive("water", 100, null) == 40 && far.water_store == 50, "pipes fill it to the brim")

	// Ice does not feed; a sink or a wet aqueduct does.
	new /turf/floor/beach/water/ice(locate(1, 2, 1))
	sw_check(!near.station_water_feed(), "frozen water feeds nothing")
	var/obj/structure/aqueduct/A = new(locate(3, 3, 1))
	sw_check(!near.station_water_feed(), "a dry aqueduct feeds nothing")
	A.wet = TRUE
	sw_check(near.station_water_feed() == "the aqueduct", "a wet aqueduct channel feeds it")
	var/obj/structure/station_water_probe/plain = new(locate(5, 3, 1))
	plain.water_capacity = 0
	sw_check(plain.station_take_water(null) && !plain.station_water_pour(B, null), "a station without a tank ignores water")
