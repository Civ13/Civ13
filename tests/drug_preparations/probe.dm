// Native drug preparation probe, included by tests/ecology_spawning/run_linux.py, never
// by the game DME. It drives code/modules/1713/drug_preparations.dm.
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
/obj/map_metadata/drugprep_probe/New()
	map = src
/mob/living/human/drugprep_probe/New()
	icon_update = FALSE
	bloodstr = new/datum/reagents/metabolism(1000, src, CHEM_BLOOD)
	ingested = new/datum/reagents/metabolism(1000, src, CHEM_INGEST)
	touching = new/datum/reagents/metabolism(1000, src, CHEM_TOUCH)
	reagents = bloodstr
	species = new /datum/species/human
	return
var/drugprep_failures = 0
var/drugprep_runtime_error = FALSE
/proc/drugprep_check(condition, label)
	if (!condition)
		drugprep_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	drugprep_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/drugprep_probe
		initialize_chemical_reactions()
		season = "SUMMER"
		for (var/turf/T in block(locate(1, 1, 1), locate(30, 30, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		drugprep_teas()
		drugprep_chewing()
		drugprep_khat()
		drugprep_cannabis()
		drugprep_lancing()
	catch(var/exception/e)
		drugprep_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = drugprep_failures, "runtime_error" = drugprep_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/drugprep_amount(datum/reagents/holder, id)
	return holder ? holder.get_reagent_amount(id) : 0

/proc/drugprep_teas()
	var/obj/item/weapon/reagent_containers/glass/beaker/B = new(locate(2, 2, 1))
	B.reagents.add_reagent("water", 10)
	B.reagents.add_reagent("poppy_straw", 3)
	B.reagents.process_reactions() // the chemistry process does this in game
	drugprep_check(drugprep_amount(B.reagents, "poppy_tea") >= 9, "poppy straw steeps in water into poppy tea")
	var/obj/item/weapon/reagent_containers/glass/beaker/C = new(locate(3, 2, 1))
	C.reagents.add_reagent("water", 10)
	C.reagents.add_reagent("coca_leaf", 3)
	C.reagents.process_reactions()
	drugprep_check(drugprep_amount(C.reagents, "coca_tea") >= 9, "ground coca steeps in water into coca tea")
	var/list/rows = processing_recipes_for("mortar")
	var/found = 0
	for (var/datum/processing_recipe/R in rows)
		if (R.input in list(/obj/item/stack/material/poppy, /obj/item/stack/material/coca, /obj/item/stack/material/cannabis))
			found++
	drugprep_check(found == 3, "the mortar grinds poppy, coca and cannabis")

/proc/drugprep_chewing()
	var/mob/living/human/drugprep_probe/H = new(locate(5, 5, 1))
	var/obj/item/stack/material/coca/L = new(locate(5, 5, 1), 3)
	drugprep_check(L.chew_wad(H, "coca_leaf", 3, "coca leaves"), "coca leaves can be chewed")
	drugprep_check(drugprep_amount(H.ingested, "coca_leaf") == 3 && L.amount == 2, "chewing uses one leaf and puts coca in the stomach")
	var/obj/item/stack/material/tobacco/T = new(locate(5, 5, 1), 2)
	T.chew_wad(H, "nicotine", 4, "chewing tobacco")
	drugprep_check(drugprep_amount(H.ingested, "nicotine") == 4, "dried tobacco can be chewed")
	qdel(H)

/proc/drugprep_khat()
	var/turf/T = locate(8, 8, 1)
	var/obj/structure/farming/plant/khat/P = new(T)
	drugprep_check(("semiarid" in P.biomes) && ("savanna" in P.biomes) && !("jungle" in P.biomes), "khat grows in dry savanna and semiarid land")
	P.make_wild()
	P.spawn_produce(0)
	P.spawn_seeds(0)
	var/obj/item/weapon/reagent_containers/food/snacks/grown/khat/K = locate() in T
	drugprep_check(K && drugprep_amount(K.reagents, "khat") >= 6, "khat harvests fresh shoots with khat in them")
	drugprep_check(K && K.decay > 0 && K.decay <= 60*600, "fresh khat wilts within the hour")
	drugprep_check(locate(/obj/item/stack/farming/seeds/khat) in T, "khat drops its own seeds")
	var/list/pool = wild_plant_pool()
	drugprep_check(pool[/obj/structure/farming/plant/khat], "khat grows wild")

/proc/drugprep_cannabis()
	var/obj/item/weapon/reagent_containers/pill/hashish/X = new(locate(10, 10, 1))
	drugprep_check(drugprep_amount(X.reagents, "thc") == 10 && X.is_contraband, "hashish carries THC")
	var/obj/item/clothing/mask/smokable/pipe/P = new(locate(10, 10, 1))
	var/mob/living/human/drugprep_probe/H = new(locate(10, 10, 1))
	P.attackby(X, H)
	drugprep_check(drugprep_amount(P.reagents, "thc") == 20 && QDELETED(X), "hashish packs a pipe")
	var/obj/item/clothing/mask/smokable/pipe/Q = new(locate(11, 10, 1))
	var/obj/item/stack/material/cannabis/D = new(locate(11, 10, 1), 2)
	Q.attackby(D, H)
	drugprep_check(drugprep_amount(Q.reagents, "thc") == 15 && D.amount == 1, "dried cannabis packs a pipe")
	qdel(H)

/proc/drugprep_lancing()
	var/turf/T = locate(14, 14, 1)
	var/obj/structure/farming/plant/poppy/P = new(T)
	P.make_wild()
	var/mob/living/human/drugprep_probe/H = new(T)
	P.latex_due = world.time + 100
	P.attack_hand(H)
	drugprep_check(!(locate(/obj/item/weapon/reagent_containers/pill/opium) in T), "wet latex cannot be picked")
	P.latex_due = world.time - 1
	P.attack_hand(H)
	var/obj/item/weapon/reagent_containers/pill/opium/O = locate() in T
	drugprep_check(O && drugprep_amount(O.reagents, "opium") == 5, "dried latex picks off as an opium ball")
	drugprep_check(P.latex_due == 0 && !QDELETED(P), "the poppy stays standing after its latex is picked")
	qdel(H)
