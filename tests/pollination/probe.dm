// Native probe for bee pollination (code/modules/1713/pollination.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/pollination/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 24
	maxy = 12
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/wild_bee_probe/New()
	return
/mob/living/human/wild_bee_probe/New()
	return
/mob/living/human/wild_bee_probe/adaptStat(statname, multiplier = 1, source = null)
	return
// A bare probe body has no icons to update: hands are just slots here.
/mob/living/human/wild_bee_probe/put_in_hands(obj/item/W)
	W.loc = src
	l_hand = W
	return TRUE
/mob/living/human/wild_bee_probe/drop_from_inventory(obj/item/W, atom/target = null)
	if (l_hand == W)
		l_hand = null
	if (r_hand == W)
		r_hand = null
	W.loc = target ? target : loc
	return TRUE

var/wb_failures = 0
var/wb_runtime_error = FALSE
/proc/wb_check(condition, label)
	if (!condition)
		wb_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	wb_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/wild_bee_probe
		populate_material_list()
		pollination_checks()
	catch(var/exception/e)
		wb_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = wb_failures, "runtime_error" = wb_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
/proc/wb_count(turf/T, item_type)
	var/count = 0
	for (var/obj/item/I in T)
		if (istype(I, item_type))
			count++
	return count

/proc/wb_clear(turf/T)
	for (var/obj/item/I in T)
		qdel(I)

/proc/pollination_checks()
	var/area/A = get_area(locate(1, 1, 1))
	A.location = AREA_OUTSIDE
	A.climate = "temperate"
	season = SEASON_SUMMER

	var/turf/field = locate(10, 6, 1)
	var/obj/structure/farming/plant/apple/apple = new(field)
	var/obj/structure/farming/plant/wheat/wheat = new(locate(11, 6, 1))
	var/obj/structure/farming/plant/cotton/cotton = new(locate(12, 6, 1))
	wb_check(apple.insect_pollinated && cotton.insect_pollinated && !wheat.insect_pollinated, "fruit and cotton need insects, wheat does not")

	// With no colony in reach nothing extra ever comes.
	wb_check(bee_colony_strength_near(field) == 0 && pollination_chance(0) == 0, "no colony means no pollination chance")
	var/extra = 0
	for (var/i in 1 to 50)
		if (apple.pollination_harvest(null))
			extra++
	wb_check(extra == 0 && wb_count(field, /obj/item/weapon/reagent_containers/food/snacks/grown/apple) == 0, "no bees, no extra apples")
	wb_check(findtext(apple.pollination_diagnostic(), "needs bees"), "a farmer is told the crop wants bees")

	// An empty hive does nothing; a settled one in reach does.
	var/obj/structure/kept_hive/hive = new(locate(14, 6, 1))
	wb_check(bee_colony_strength_near(field) == 0, "an empty hive pollinates nothing")
	hive.settle(100)
	wb_check(bee_colony_strength_near(field) == 100, "a full colony four tiles away reaches the field")
	wb_check(pollination_chance(100) == 80 && pollination_chance(10) == 26, "chance grows with colony strength and is capped")
	wb_check(findtext(apple.pollination_diagnostic(), "Bees are working"), "a farmer sees bees working the flowers")
	extra = 0
	for (var/i in 1 to 100)
		if (apple.pollination_harvest(null))
			extra++
	var/apples = wb_count(field, /obj/item/weapon/reagent_containers/food/snacks/grown/apple)
	wb_check(extra >= 55 && extra <= 98 && apples == extra, "a strong colony gives an extra apple most harvests ([extra] of 100)")
	wb_check(!wheat.pollination_harvest(null) && wb_count(wheat.loc, /obj/item) == 0, "wheat gets nothing from bees")

	// The real knife harvest rolls once per ripe crop. Poor soil gives one
	// apple, so any second apple came from the bees.
	var/mob/living/human/wild_bee_probe/farmer = new(locate(9, 4, 1))
	var/obj/item/weapon/material/kitchen/utensil/knife/knife = new(farmer)
	var/turf/orchard = locate(12, 4, 1)
	var/harvested = 0
	for (var/i in 1 to 40)
		var/obj/structure/farming/plant/apple/tree = new(orchard)
		tree.stage = tree.readyStageMin
		tree.plant_nutrition = 0
		tree.attackby(knife, farmer)
		if (QDELETED(tree))
			harvested++
	var/picked = wb_count(orchard, /obj/item/weapon/reagent_containers/food/snacks/grown/apple)
	wb_check(harvested == 40 && picked >= 60 && picked <= 80, "knife harvests near a full hive give extra apples ([picked] from 40)")
	wb_clear(orchard)
	var/obj/structure/farming/plant/apple/young = new(orchard)
	young.stage = 2
	young.attackby(knife, farmer)
	wb_check(QDELETED(young) && wb_count(orchard, /obj/item) == 0, "uprooting a young tree gives nothing from the bees")

	// Stacked crops get one more stack portion.
	var/turf/cotton_turf = get_turf(cotton)
	var/obj/item/stack/I = cotton.spawn_pollinated_extra()
	wb_check(istype(I, /obj/item/stack/material/cotton) && I.amount == cotton.stack_amount && I.loc == cotton_turf, "cotton gains a stack portion")

	// A wild nest counts as a middling colony, and only while occupied.
	qdel(hive)
	var/obj/structure/wild_bee_nest/N = new(locate(10, 10, 1))
	wb_check(bee_colony_strength_near(field) == 50, "an occupied wild nest pollinates nearby crops")
	N.occupied = FALSE
	wb_check(bee_colony_strength_near(field) == 0, "an empty wild nest does not")

	// Out of reach is out of reach.
	var/obj/structure/kept_hive/far = new(locate(20, 6, 1))
	far.settle(100)
	wb_check(bee_colony_strength_near(field) == 0, "a hive ten tiles off does not reach the field")
