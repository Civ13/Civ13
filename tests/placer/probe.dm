// Native probe for pay dirt washing.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/placer/probe.dm 420
/world
	hub = ""
	hub_password = ""
	maxx = 20
	maxy = 20
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/placer_probe/New()
	return
/obj/structure/window/placer_probe/New()
	return
/mob/living/human/placer_probe/New()
	icon_update = FALSE
	return
var/eco_failures = 0
var/eco_runtime_error = FALSE
/proc/eco_check(condition, label)
	if (!condition)
		eco_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	eco_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.global_listen_count = list()
		GLOB.event_sources_count = list()
		GLOB.event_listen_count = list()
		movementMachine = new
		initialize_chemical_reagents()
		initialize_chemical_reactions()
		map = new /obj/map_metadata/placer_probe
		map.ordinal_age = 1
		placer_probe_checks()
	catch(var/exception/e)
		eco_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = eco_failures, "runtime_error" = eco_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/placer_probe_checks()
	var/n = 4000
	var/list/counts = list("rich" = 0, "tin" = 0, "rich_m" = 0, "rocker" = 0, "tin_tin" = 0, "barren_iron" = 0)
	for (var/i in 1 to n)
		if (pay_dirt_wash("rich", "sluice")[/obj/item/stack/ore/gold])
			counts["rich"]++
		if (pay_dirt_wash("rich", "sluice", TRUE)[/obj/item/stack/ore/gold])
			counts["rich_m"]++
		if (pay_dirt_wash("rich", "rocker")[/obj/item/stack/ore/gold])
			counts["rocker"]++
		var/list/t = pay_dirt_wash("tin", "sluice")
		if (t[/obj/item/stack/ore/gold])
			counts["tin"]++
		if (t[/obj/item/stack/ore/tin])
			counts["tin_tin"]++
		if (pay_dirt_wash("barren", "sluice")[/obj/item/stack/ore/iron_sand])
			counts["barren_iron"]++
	eco_check(abs(counts["rich"] / n - 0.27) < 0.03, "a sluice finds gold in about 27% of rich loads ([counts["rich"]])")
	eco_check(abs(counts["rich_m"] / n - 0.3375) < 0.03, "mercury in the riffles raises it a quarter ([counts["rich_m"]])")
	eco_check(abs(counts["rocker"] / n - 0.324) < 0.03, "a rocker finds more ([counts["rocker"]])")
	eco_check(abs(counts["tin"] / n - 0.09) < 0.02 && abs(counts["tin_tin"] / n - 0.6) < 0.04, "tin ground is mostly tin ([counts["tin"]], [counts["tin_tin"]])")
	eco_check(abs(counts["barren_iron"] / n - 0.5) < 0.04, "barren ground gives iron sand from the Classical age ([counts["barren_iron"]])")
	map.ordinal_age = 0
	var/iron0 = 0
	for (var/i in 1 to 500)
		if (pay_dirt_wash("barren", "sluice")[/obj/item/stack/ore/iron_sand])
			iron0++
	eco_check(iron0 == 0, "no iron sand in the Stone Age")
	var/turf/T = locate(5, 5, 1)
	eco_check(pay_dirt_grade(5, 5) == pay_dirt_grade(16, 16) && pay_dirt_type("rich") == /obj/item/stack/ore/pay_dirt/rich, "a district has one grade")
	var/datum/resource_stock/S = T.pay_dirt_stock()
	eco_check(S.take(1) && S.take(1) && S.take(1) && !S.take(1) && T.pay_dirt_stock() == S, "a bank tile gives three loads, then rests")
	var/obj/structure/placer_washer/sluice/SL = new(locate(8, 8, 1))
	SL.reagents.add_reagent("mercury", 2)
	eco_check(SL.mercury_charged(), "mercury charges the riffles")
	SL.spend_mercury()
	eco_check(abs(SL.reagents.get_reagent_amount("mercury") - 1.95) < 0.001, "each load washes a little away")
	var/obj/structure/placer_washer/rocker/R = new(locate(9, 9, 1))
	eco_check(!R.anchored && R.water_capacity == 40 && !R.mercury_charged(), "the rocker is movable with its own tank")
	var/turf/bank = locate(13, 14, 1)
	bank = bank.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	var/turf/water = locate(14, 14, 1)
	water = water.ChangeTurf(/turf/floor/beach/water, FALSE, FALSE)
	var/datum/resource_stock/stock = bank.pay_dirt_stock()
	eco_check(bank.pay_dirt_bank() && bank.panning_water() == water, "ordinary shallow freshwater enables panning and digging")
	var/obj/covers/roads/dirt/worked/road = new(bank)
	eco_check(!bank.pay_dirt_bank() && bank.panning_water() == water && stock.available() == PAY_DIRT_LOADS, "a road cover on the same turf removes bank eligibility without touching stock")
	qdel(road)
	water = water.ChangeTurf(/turf/floor/beach/water/ice, FALSE, FALSE)
	eco_check(!bank.panning_water() && !bank.pay_dirt_bank() && stock.available() == PAY_DIRT_LOADS, "ice is not panning water or a valid placer source")
	water = water.ChangeTurf(/turf/floor/beach/water/shallowsaltwater, FALSE, FALSE)
	eco_check(!bank.panning_water(), "liquid salt water still does not permit panning")
	water = water.ChangeTurf(/turf/floor/beach/water/deep, FALSE, FALSE)
	eco_check(!bank.panning_water(), "liquid deep fresh water still does not permit panning")

	// Exercise the actual paid actions with the actor and tool stationary while the terrain changes.
	var/turf/work_bank = locate(16, 16, 1)
	work_bank = work_bank.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	var/turf/work_water = locate(17, 16, 1)
	work_water = work_water.ChangeTurf(/turf/floor/beach/water, FALSE, FALSE)
	var/mob/living/human/placer_probe/H = new(work_bank)
	H.hand = FALSE
	H.r_hand = new /obj/item/weapon/material/shovel(H)
	var/datum/resource_stock/work_stock = work_bank.pay_dirt_stock()
	spawn(1)
		new /obj/covers/roads/dirt/worked(work_bank)
	H.dig_pay_dirt()
	var/obj/covers/roads/dirt/worked/cover = locate() in work_bank
	eco_check(cover && work_stock.available() == PAY_DIRT_LOADS && !(locate(/obj/item/stack/ore/pay_dirt) in work_bank), "a road built mid-dig does not consume stock or spawn gravel")
	qdel(cover)

	var/obj/item/kitchen/wood_bowl/bowl = new(H)
	var/obj/item/stack/ore/pay_dirt/load = new(H)
	load.amount = 2
	H.r_hand = load
	H.l_hand = bowl
	spawn(1)
		work_water.ChangeTurf(/turf/floor/beach/water/ice, FALSE, FALSE)
	bowl.attackby(load, H)
	work_water = locate(17, 16, 1)
	eco_check(istype(work_water, /turf/floor/beach/water/ice) && load.amount == 2, "pay dirt is not consumed when the selected water freezes mid-pan")
	work_water.ChangeTurf(/turf/floor/beach/water, FALSE, FALSE)
	bowl.attackby(load, H)
	eco_check(load.amount == 1, "the same pan consumes exactly one load when the water stays liquid")
	placer_bowl_custody_checks()

/proc/placer_bowl_custody_checks()
	map.ordinal_age = 1 // ordinary sand washing is gated on the Classical age
	var/turf/bank = locate(10, 14, 1)
	bank = bank.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	var/turf/water = locate(11, 14, 1)
	water.ChangeTurf(/turf/floor/beach/water, FALSE, FALSE)
	var/turf/adjacent_bank = locate(9, 14, 1)
	adjacent_bank = adjacent_bank.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	var/mob/living/human/placer_probe/H = new(bank)
	var/mob/living/human/placer_probe/other = new(bank)
	var/obj/item/weapon/storage/backpack/bag = new(bank)
	var/obj/item/kitchen/wood_bowl/bowl = new(H)
	var/obj/structure/window/placer_probe/edge = new(bank)
	H.hand = FALSE
	for (var/feed in list(/obj/item/stack/ore/pay_dirt, /obj/item/stack/ore/crushed_ore/gold, /obj/item/stack/ore/glass))
		var/obj/item/stack/load = new feed(H)
		load.amount = 10
		H.r_hand = load
		bowl.loc = H
		H.l_hand = bowl
		spawn(1)
			bowl.loc = other
			other.l_hand = bowl
		bowl.attackby(load, H)
		eco_check(bowl.loc == other && load.amount == 10 && !(locate(/obj/item/stack) in bank), "[feed] refusal: recipient on the same tile is not the original holder (moved [bowl.loc == other], amount [load.amount])")
		other.l_hand = null

		bowl.loc = H
		spawn(1)
			bowl.loc = bag
		bowl.attackby(load, H)
		eco_check(bowl.loc == bag && load.amount == 10 && !(locate(/obj/item/stack) in bank), "[feed] refusal: a bag on the same tile is not the original location")

		bowl.loc = adjacent_bank
		H.l_hand = null
		edge.dir = NORTH
		spawn(1)
			edge.dir = WEST
		bowl.attackby(load, H)
		eco_check(edge.dir == WEST && load.amount == 10 && !(locate(/obj/item/stack) in bank), "[feed] refusal: a newly blocked edge prevents panning even with the same ground location")
		edge.dir = NORTH
		bowl.attackby(load, H)
		eco_check(QDELETED(load) || load.amount == 9, "[feed] control: a reachable ground bowl still pans (amount [load.amount])")
		H.r_hand = null
		qdel(load)
		for (var/obj/item/stack/output in bank)
			qdel(output)

	var/obj/structure/kanna_channel/channel = new(bank)
	var/obj/item/stack/ore/glass/sand = new(H)
	sand.amount = 5
	H.r_hand = sand
	channel.attackby(sand, H)
	eco_check(QDELETED(sand) && !channel.washing && locate(/obj/item/stack/ore/iron_sand) in bank, "the default washing channel still consumes sand, returns iron sand and releases its lock")
