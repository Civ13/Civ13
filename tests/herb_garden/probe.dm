// Native herb garden probe, included by tests/ecology_spawning/run_linux.py, never
// by the game DME. It drives code/modules/1713/herb_garden.dm.
/world
	hub = ""
	hub_password = ""
	maxx = 30
	maxy = 30
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/garden_probe/New()
	map = src
/mob/living/human/garden_probe/New()
	icon_update = FALSE // no species: skip body overlays when held items change
	return
var/garden_failures = 0
var/garden_runtime_error = FALSE
/proc/garden_check(condition, label)
	if (!condition)
		garden_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	garden_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/garden_probe
		season = "SUMMER"
		var/area/A = get_area(locate(1, 1, 1))
		A.location = AREA_OUTSIDE
		A.climate = "temperate"
		A.weather = WEATHER_NONE
		for (var/turf/T in block(locate(1, 1, 1), locate(30, 30, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		garden_crop_checks()
		garden_harvest_checks()
		garden_steeping_checks()
		garden_tea_checks()
		garden_wild_checks()
	catch(var/exception/e)
		garden_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = garden_failures, "runtime_error" = garden_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/garden_count(atom/loc, path)
	. = 0
	for (var/obj/item/I in loc)
		if (istype(I, path))
			.++

/proc/garden_clear(turf/T)
	for (var/obj/O in T)
		qdel(O)

// Every seed sows its own plant, and every plant names a produce or overrides it.
/proc/garden_crop_checks()
	for (var/name in list("chamomile", "dandelion", "mint", "sunflower", "rose"))
		var/seedpath = text2path("/obj/item/stack/farming/seeds/[name]")
		var/plantpath = text2path("/obj/structure/farming/plant/[name]")
		garden_check(seedpath && plantpath, "[name] has seeds and a plant")
		var/obj/structure/farming/plant/P = new plantpath(locate(2, 2, 1))
		garden_check(P.plant == name && P.icon_state == "[name]-grow1", "[name] plant sprite family")
		qdel(P)

/proc/garden_harvest_checks()
	var/turf/T = locate(5, 5, 1)
	var/obj/structure/farming/plant/dandelion/D = new(T)
	D.plant_nutrition = 0
	D.spawn_produce(0)
	garden_check(garden_count(T, /obj/item/weapon/reagent_containers/food/snacks/grown/dandelion) == 1 && garden_count(T, /obj/item/weapon/reagent_containers/food/snacks/grown/dandelion_root) == 1, "a dandelion harvest gives greens and a root")
	garden_clear(T)
	var/obj/structure/farming/plant/rose/R = new(T)
	R.plant_nutrition = 0
	R.spawn_produce(0)
	garden_check(garden_count(T, /obj/item/weapon/reagent_containers/food/snacks/grown/rosehips) == 1 && garden_count(T, /obj/item/weapon/reagent_containers/food/snacks/grown/rose_petals) == 1, "a rose harvest gives hips and petals")
	garden_clear(T)
	var/obj/structure/farming/plant/sunflower/S = new(T)
	S.plant_nutrition = 0
	S.spawn_produce(0)
	var/obj/item/weapon/reagent_containers/food/snacks/grown/sunflower/head = locate() in T
	garden_check(head, "a sunflower harvest gives a head")
	var/mob/living/human/garden_probe/H = new(T)
	head.attack_self(H)
	garden_check(QDELETED(head) && garden_count(T, /obj/item/weapon/reagent_containers/food/snacks/grown/sunflower_seeds) == 3, "a head shells into three handfuls of seeds")
	garden_clear(T)
	qdel(H)
	// Drying targets.
	var/obj/item/weapon/reagent_containers/food/snacks/grown/chamomile/C = new(T)
	var/obj/item/weapon/reagent_containers/food/snacks/grown/dandelion_root/DR = new(T)
	var/obj/item/weapon/reagent_containers/food/snacks/grown/mint/M = new(T)
	var/obj/item/weapon/reagent_containers/food/snacks/grown/rose_petals/RP = new(T)
	garden_check(C.dried_type && DR.dried_type && M.dried_type && RP.dried_type, "chamomile, root, mint and petals dry on a dehydrator")
	garden_clear(T)

/proc/garden_steeping_checks()
	var/turf/stand = locate(10, 10, 1)
	var/mob/living/human/garden_probe/H = new(stand)
	var/obj/item/weapon/reagent_containers/glass/beaker/B = new(locate(11, 10, 1))
	B.reagents.add_reagent("water", 30)
	var/obj/item/weapon/reagent_containers/food/snacks/grown/chamomile/C = new(stand)
	garden_check(C.steep_herb(B, H) && QDELETED(C) && B.reagents.get_reagent_amount("chamomile_tea") == 5 && B.reagents.get_reagent_amount("water") == 25, "fresh chamomile steeps five tea")
	var/obj/item/weapon/reagent_containers/food/snacks/grown/dried_chamomile/DC = new(stand)
	garden_check(DC.steep_herb(B, H) && B.reagents.get_reagent_amount("chamomile_tea") == 15 && B.reagents.get_reagent_amount("water") == 15, "dried chamomile steeps ten tea")
	var/obj/item/weapon/reagent_containers/food/snacks/grown/roasted_dandelion_root/root = new(stand)
	garden_check(root.steep_herb(B, H) && B.reagents.get_reagent_amount("dandelion_coffee") == 10, "roasted root steeps dandelion coffee")
	var/obj/item/weapon/reagent_containers/food/snacks/grown/rosehips/hips = new(stand)
	garden_check(!hips.steep_herb(B, H) && !QDELETED(hips), "five water is not enough for rose hips")
	var/obj/item/weapon/reagent_containers/food/snacks/grown/dandelion/greens = new(stand)
	garden_check(!greens.steep_reagent, "greens are food, not tea")
	garden_clear(stand)
	qdel(B)
	qdel(H)

/proc/garden_tea_checks()
	var/mob/living/human/garden_probe/H = new(locate(15, 15, 1))
	var/datum/reagents/R = new(100)
	R.my_atom = H
	R.add_reagent("food_poisoning", 5)
	R.add_reagent("mint_tea", 5)
	var/datum/reagent/drink/mint_tea/tea = locate() in R.reagent_list
	tea.affect_ingest(H, null, 1)
	garden_check(R.get_reagent_amount("food_poisoning") == 3, "mint tea clears food poisoning")
	for (var/id in list("chamomile_tea", "mint_tea", "dandelion_coffee", "rosehip_tea", "rose_tea"))
		garden_check(chemical_reagents_list && chemical_reagents_list[id], "[id] is a registered reagent")
	qdel(H)

/proc/garden_wild_checks()
	var/list/pool = wild_plant_pool()
	var/list/table = foraging_seed_table()
	for (var/name in list("chamomile", "dandelion", "mint", "sunflower", "rose"))
		garden_check(pool[text2path("/obj/structure/farming/plant/[name]")], "[name] grows wild")
		garden_check(table[text2path("/obj/item/stack/farming/seeds/[name]")], "[name] seeds can be foraged")
