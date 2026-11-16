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

	// Stations that use water.
	var/obj/structure/workshop_machine/potters_wheel/wheel = new(locate(5, 1, 1))
	var/obj/structure/workshop_machine/brick_bench/bench = new(locate(6, 1, 1))
	var/obj/structure/converter/retting_trough/trough = new(locate(6, 3, 1))
	sw_check(wheel.water_per_use == 10 && bench.water_per_use == 20 && trough.water_per_use == 30, "the wheel, bench and trough take 10, 20 and 30 water")
	sw_check(!wheel.station_has_water() && !bench.station_has_water() && !trough.station_has_water(), "away from water they start dry")
	B.reagents.add_reagent("water", 100)
	sw_check(wheel.station_water_pour(B, null) && wheel.station_has_water(), "a bucket wets the wheel")
	B.reagents.add_reagent("water", 50)
	sw_check(trough.attackby(B, null) == null && trough.water_store > 0, "a bucket fills the retting trough")

	// The quench tub hardens iron and steel forged beside it.
	var/obj/structure/anvil/anvil = new(locate(6, 2, 1))
	var/obj/structure/quench_tub/tub = new(locate(5, 2, 1))
	sw_check(!anvil.quench_tub(), "a dry quench tub does not count")
	B.reagents.add_reagent("water", 100)
	tub.station_water_pour(B, null)
	sw_check(anvil.quench_tub() == tub && tub.water_store == 60, "a bucket fills the quench tub to 60")
	var/obj/item/weapon/material/knife = new /obj/item/weapon/material/kitchen/utensil/knife(locate(6, 2, 1), "iron")
	sw_check(tub.quench(knife, null) && knife.crafting_quality == 1.2 && tub.water_store == 50, "quenching hardens a piece one step for 10 water")
	sw_check(!tub.quench(knife, null) && tub.water_store == 50, "a piece is only quenched once")
	sw_check(quench_hardens("steel") && quench_hardens("iron") && !quench_hardens("bronze") && !quench_hardens("copper"), "only iron and steel harden")
	tub.water_store = 5
	sw_check(!anvil.quench_tub(), "a near-empty tub is passed over")
