// Native coffee probe, included by tests/ecology_spawning/run_linux.py, never
// by the game DME. It drives code/modules/1713/coffee.dm.
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
/obj/map_metadata/coffee_probe/New()
	map = src
/mob/living/human/coffee_probe/New()
	icon_update = FALSE // no species: skip body overlays when held items change
	return
var/coffee_failures = 0
var/coffee_runtime_error = FALSE
/proc/coffee_check(condition, label)
	if (!condition)
		coffee_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	coffee_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/coffee_probe
		initialize_chemical_reactions()
		season = "SUMMER"
		for (var/turf/T in block(locate(1, 1, 1), locate(30, 30, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		coffee_source_checks()
		coffee_roast_checks()
		coffee_grind_checks()
		coffee_brew_checks()
		coffee_drink_checks()
	catch(var/exception/e)
		coffee_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = coffee_failures, "runtime_error" = coffee_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)


/proc/coffee_source_checks()
	var/list/pool = wild_plant_pool()
	coffee_check(pool[/obj/structure/farming/plant/coffee] == 1, "wild coffee grows by flora regrowth")
	var/list/seeds = foraging_seed_table()
	var/list/climates = seeds[/obj/item/stack/farming/seeds/coffee]
	coffee_check(islist(climates) && ("jungle" in climates) && ("savanna" in climates), "coffee seeds are foraged in jungle and savanna")
	var/obj/structure/farming/plant/coffee/P = new(locate(2, 2, 1))
	coffee_check(!("desert" in P.biomes) && ("jungle" in P.biomes), "coffee is no desert crop")
	qdel(P)
	var/obj/item/weapon/reagent_containers/food/snacks/grown/coffee/G = new(locate(2, 2, 1))
	coffee_check(!G.reagents.get_reagent_amount("coffee") && G.icon_state == "green_coffee" && !G.color, "green coffee holds no coffee and uses its own sprite")
	qdel(G)

/proc/coffee_roast_checks()
	var/turf/T = locate(5, 5, 1)
	var/obj/structure/oven/fireplace/F = new(T)
	var/obj/item/weapon/reagent_containers/food/snacks/grown/coffee/G = new(F)
	F.process()
	var/obj/item/weapon/reagent_containers/food/snacks/roasted_coffee/R = locate() in T
	coffee_check(QDELETED(G) && istype(R) && R.roasted && R.decay == 0, "a fire roasts green coffee into beans that keep")
	coffee_check(R && R.reagents.get_reagent_amount("coffee") == 2, "roasted beans can be chewed for a little coffee")
	R.loc = F
	F.process()
	coffee_check(QDELETED(R) && (locate(/obj/item/weapon/reagent_containers/food/snacks/badrecipe) in T), "a second roast burns the beans")
	for (var/obj/item/I in T)
		qdel(I)
	qdel(F)

/proc/coffee_grind_checks()
	var/obj/item/weapon/reagent_containers/food/snacks/roasted_coffee/R = new(locate(7, 7, 1))
	var/list/result = mortar_grind_result(R)
	coffee_check(islist(result) && result["coffee_grounds"] == 3, "the mortar grinds roasted beans into 3 grounds")
	var/obj/item/weapon/reagent_containers/food/snacks/grown/coffee/G = new(locate(7, 7, 1))
	coffee_check(!mortar_grind_result(G), "green coffee is not ground")
	qdel(R)
	qdel(G)

/proc/coffee_brew_checks()
	var/obj/item/weapon/reagent_containers/glass/small_pot/P = new(locate(9, 9, 1))
	P.reagents.add_reagent("coffee_grounds", 3)
	P.reagents.add_reagent("water", 20)
	var/made = P.reagents.brew_coffee()
	coffee_check(made == 15 && P.reagents.get_reagent_amount("coffee") == 15 && P.reagents.get_reagent_amount("water") == 8 && !P.reagents.get_reagent_amount("coffee_grounds"), "3 grounds and 12 water brew 15 coffee, extra water stays")
	P.reagents.clear_reagents()
	P.reagents.add_reagent("coffee_grounds", 3)
	P.reagents.add_reagent("water", 4)
	P.reagents.brew_coffee()
	coffee_check(P.reagents.get_reagent_amount("coffee") == 5 && P.reagents.get_reagent_amount("coffee_grounds") == 2, "too little water leaves grounds")
	P.reagents.clear_reagents()
	P.reagents.add_reagent("coffee_grounds", 3)
	coffee_check(!P.reagents.brew_coffee(), "no water, no coffee")
	qdel(P)
	var/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/wood/M = new(locate(9, 9, 1))
	M.reagents.add_reagent("water", 4)
	M.reagents.add_reagent("coffee_grounds", 3)
	coffee_check(islist(M.stone_boil_mixture()), "a wooden mug of water and grounds can be stone-boiled")
	coffee_check(M.reagents.brew_coffee() == 5 && M.reagents.get_reagent_amount("coffee_grounds") == 2, "a partial wooden mug brew leaves grounds")
	coffee_check(!M.stone_boil_mixture(), "a partial brew still needs more water")
	M.reagents.add_reagent("water", 8)
	var/list/topped_up = M.stone_boil_mixture()
	coffee_check(topped_up && topped_up["coffee"] == 5 && topped_up["coffee_grounds"] == 2 && topped_up["water"] == 8, "a topped-up mug is eligible and snapshots the existing coffee")
	coffee_check(M.reagents.brew_coffee() == 10 && M.reagents.get_reagent_amount("coffee") == 15 && !M.reagents.get_reagent_amount("coffee_grounds") && !M.reagents.get_reagent_amount("water"), "a topped-up mug brews the remaining grounds")
	M.reagents.add_reagent("water", 1)
	M.reagents.add_reagent("milk", 1)
	coffee_check(!M.stone_boil_mixture(), "other reagents still block stone boiling")
	qdel(M)
	var/obj/item/weapon/reagent_containers/glass/beaker/B = new(locate(9, 9, 1))
	var/obj/item/weapon/reagent_containers/food/snacks/grown/coffee/G = new(locate(9, 9, 1))
	var/mob/living/human/coffee_probe/H = new(locate(9, 9, 1))
	B.attackby(G, H)
	coffee_check(!B.reagents.get_reagent_amount("coffee") && !QDELETED(G), "green coffee no longer makes instant coffee")
	qdel(B)
	qdel(G)
	qdel(H)

/proc/coffee_drink_checks()
	var/mob/living/human/coffee_probe/H = new(locate(12, 12, 1))
	H.stats["stamina"][1] = 10
	var/obj/item/weapon/reagent_containers/glass/beaker/B = new(locate(12, 12, 1))
	B.reagents.add_reagent("coffee", 10)
	var/datum/reagent/drink/coffee/C
	for (var/datum/reagent/R in B.reagents.reagent_list)
		if (R.id == "coffee")
			C = R
	C.affect_ingest(H, null, 1)
	coffee_check(!H.chem_effects.Find(CE_SPEEDBOOST), "coffee is no running stimulant")
	coffee_check(H.chem_effects.Find(CE_PULSE), "coffee still raises the pulse")
	coffee_check(H.stats["stamina"][1] == 15, "coffee restores a little energy")
	H.stats["stamina"][1] = H.diet_stamina_cap()
	C.affect_ingest(H, null, 1)
	coffee_check(H.stats["stamina"][1] == H.diet_stamina_cap(), "energy never goes over the cap")
	qdel(B)
	qdel(H)
