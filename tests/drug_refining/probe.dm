// Native drug refining probe, included by tests/ecology_spawning/run_linux.py, never
// by the game DME. It drives code/modules/reagents/drug_refining.dm.
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
/obj/map_metadata/drugrefine_probe/New()
	map = src
var/list/drugrefine_known = list()
/obj/map_metadata/drugrefine_probe/book_research_enabled()
	return FALSE
/obj/map_metadata/drugrefine_probe/is_node_done(faction, node_id)
	return node_id in drugrefine_known
/mob/living/human/drugrefine_probe/New()
	icon_update = FALSE
	bloodstr = new/datum/reagents/metabolism(1000, src, CHEM_BLOOD)
	ingested = new/datum/reagents/metabolism(1000, src, CHEM_INGEST)
	touching = new/datum/reagents/metabolism(1000, src, CHEM_TOUCH)
	reagents = bloodstr
	species = new /datum/species/human
	stats = list("medical" = list(165, 165))
	return
var/drugrefine_failures = 0
var/drugrefine_runtime_error = FALSE
/proc/drugrefine_check(condition, label)
	if (!condition)
		drugrefine_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	drugrefine_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/drugrefine_probe
		initialize_chemical_reactions()
		season = "SUMMER"
		for (var/turf/T in block(locate(1, 1, 1), locate(30, 30, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		drugrefine_laudanum()
		drugrefine_distiller()
		drugrefine_twist()
		drugrefine_cigarettes()
	catch(var/exception/e)
		drugrefine_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = drugrefine_failures, "runtime_error" = drugrefine_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/drugrefine_amount(datum/reagents/holder, id)
	return holder ? holder.get_reagent_amount(id) : 0

/proc/drugrefine_laudanum()
	var/obj/item/weapon/reagent_containers/glass/beaker/B = new(locate(2, 2, 1))
	B.reagents.add_reagent("opium", 3)
	B.reagents.add_reagent("ethanol", 6)
	B.reagents.process_reactions() // the chemistry process does this in game
	drugrefine_check(drugrefine_amount(B.reagents, "laudanum") >= 9, "opium dissolves in spirits into laudanum")
	var/obj/item/weapon/reagent_containers/glass/beaker/C = new(locate(3, 2, 1))
	C.reagents.add_reagent("opium", 3)
	C.reagents.add_reagent("ethanol", 3)
	C.reagents.add_reagent("acetone", 3)
	C.reagents.process_reactions()
	drugrefine_check(!drugrefine_amount(C.reagents, "laudanum") && drugrefine_amount(C.reagents, "tramadol") > 0, "acetone still makes tramadol, not laudanum")

/proc/drugrefine_run(input_id, amount, mob/living/human/H)
	var/obj/structure/lab_distillery/D = new(locate(6, 6, 1))
	D.collector = new(D)
	D.reagents.add_reagent(input_id, amount)
	var/handled = D.drug_refine(input_id, H)
	return list(handled, D)

/proc/drugrefine_distiller()
	var/mob/living/human/drugrefine_probe/H = new(locate(6, 6, 1))
	drugrefine_known = list()
	var/list/run = drugrefine_run("opium", 10, H)
	var/obj/structure/lab_distillery/D = run[2]
	drugrefine_check(run[1] && drugrefine_amount(D.reagents, "opium") == 10 && !drugrefine_amount(D.collector.reagents, "morphine"), "without Pharmacology the opium is kept, not refined")
	drugrefine_known = list("pharmacology")
	run = drugrefine_run("opium", 10, H)
	D = run[2]
	drugrefine_check(abs(drugrefine_amount(D.collector.reagents, "morphine") - 5) < 0.01 && !drugrefine_amount(D.reagents, "opium"), "a skilled doctor refines opium into pure morphine")
	run = drugrefine_run("coca_leaf", 30, H)
	D = run[2]
	drugrefine_check(abs(drugrefine_amount(D.collector.reagents, "cocaine") - 15) < 0.01, "ground coca refines into cocaine")
	run = drugrefine_run("morphine", 6, H)
	D = run[2]
	drugrefine_check(!drugrefine_amount(D.collector.reagents, "heroin"), "heroin needs Modern Medicine")
	drugrefine_known = list("pharmacology", "modern_medicine")
	run = drugrefine_run("morphine", 6, H)
	D = run[2]
	drugrefine_check(abs(drugrefine_amount(D.collector.reagents, "heroin") - 4) < 0.01, "Modern Medicine refines morphine into heroin")
	H.stats = list("medical" = list(115, 115))
	run = drugrefine_run("opium", 10, H)
	D = run[2]
	var/morphine = drugrefine_amount(D.collector.reagents, "morphine")
	drugrefine_check(morphine < 5 && morphine >= 2.5 && drugrefine_amount(D.collector.reagents, "drug_residue") > 0, "an unskilled hand leaves residue in the batch")
	run = drugrefine_run("water", 10, H)
	drugrefine_check(!run[1], "ordinary distilling is left alone")
	qdel(H)

/proc/drugrefine_twist()
	var/turf/T = locate(10, 10, 1)
	var/mob/living/human/drugrefine_probe/H = new(T)
	var/obj/item/weapon/reagent_containers/glass/beaker/B = new(T)
	B.reagents.add_reagent("cocaine", 4)
	B.reagents.add_reagent("sugar", 16)
	var/obj/item/weapon/paper/P = new(T)
	drugrefine_check(paper_twist_fold(B, P, H), "a blank paper folds around a pinch")
	var/obj/item/weapon/reagent_containers/pill/paper_twist/X = locate() in (T.contents + H.contents)
	drugrefine_check(X && abs(X.reagents.total_volume - 10) < 0.01 && QDELETED(P), "a paper twist holds ten units")
	drugrefine_check(X && findtext(drug_strength_text(X.reagents), "weak"), "tasting a cut twist shows it is weak")
	var/obj/item/weapon/reagent_containers/glass/beaker/C = new(T)
	C.reagents.add_reagent("cocaine", 10)
	drugrefine_check(findtext(drug_strength_text(C.reagents), "strong and clean"), "tasting pure cocaine shows it is strong")
	var/obj/item/weapon/paper/W = new(T)
	W.info = "a letter"
	drugrefine_check(!paper_twist_fold(C, W, H), "a written page is not folded into a twist")
	qdel(H)

/proc/drugrefine_cigarettes()
	var/turf/T = locate(14, 14, 1)
	var/mob/living/human/drugrefine_probe/H = new(T)
	var/obj/item/stack/material/tobacco/L = new(T, 1)
	var/obj/item/weapon/paper/P = new(T)
	L.attackby(P, H)
	drugrefine_check(!QDELETED(P) && !(locate(/obj/item/clothing/mask/smokable/cigarette) in T), "one leaf is not enough for cigarettes")
	var/list/recipes = file2text("config/crafting/material_recipes_global.txt")
	drugrefine_check(!findtext(recipes, "RECIPE: /material/tobacco/,cigarette,") && !findtext(recipes, "RECIPE: /material/coca/,cocaine,"), "cigarettes and cocaine are no longer hand crafts")
	qdel(H)
