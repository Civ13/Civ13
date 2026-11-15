// Native wild herb probe, included by tests/ecology_spawning/run_linux.py, never
// by the game DME. It drives code/modules/ecology/wild_herbs.dm.
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
/obj/map_metadata/herb_probe/New()
	map = src
/mob/living/human/herb_probe/New()
	icon_update = FALSE // no species: skip body overlays when held items change
	return
var/herb_failures = 0
var/herb_runtime_error = FALSE
/proc/herb_check(condition, label)
	if (!condition)
		herb_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	herb_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/herb_probe
		season = "SUMMER"
		var/area/A = get_area(locate(1, 1, 1))
		A.location = AREA_OUTSIDE
		A.climate = "temperate"
		A.weather = WEATHER_NONE
		for (var/turf/T in block(locate(1, 1, 1), locate(30, 30, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		herb_picking_checks()
		herb_dressing_checks()
		herb_steeping_checks()
		herb_tea_checks()
		herb_seed_checks()
	catch(var/exception/e)
		herb_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = herb_failures, "runtime_error" = herb_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/herb_count(atom/loc, path)
	. = 0
	for (var/obj/item/stack/S in loc)
		if (istype(S, path))
			. += S.amount

/proc/herb_picking_checks()
	var/turf/stand = locate(5, 5, 1)
	var/mob/living/human/herb_probe/H = new(stand)
	var/obj/structure/wild/flowers/wild_herb/yarrow/Y = new(locate(6, 5, 1))
	herb_check(Y.icon == 'icons/farming/humanity_wild_herbs.dmi' && Y.icon_state == "yarrow", "yarrow keeps its own sprite")
	herb_check(Y.sprigs == 3, "a fresh patch has three sprigs")
	for (var/i = 1, i <= 3, i++)
		Y.finish_pick(H)
	var/picked = herb_count(H, /obj/item/stack/medical/wild_herb/yarrow) + herb_count(stand, /obj/item/stack/medical/wild_herb/yarrow)
	herb_check(picked == 3 && Y.sprigs == 0, "three yarrow sprigs picked")
	herb_check(!Y.finish_pick(H), "a bare patch gives nothing")
	Y.regrow_sprig()
	herb_check(Y.sprigs == 1, "a sprig grows back")
	season = "WINTER"
	herb_check(!Y.finish_pick(H) && Y.sprigs == 1, "nothing to pick in winter")
	season = "SUMMER"
	herb_check(("sprigs" in Y.get_saved_vars()) && Y.persistence_runtime_var("sprig_regrow_pending") && Y.persistence_runtime_var("sprig_busy"), "sprig stock is saved, timers are not")
	for (var/obj/item/I in H)
		qdel(I)
	for (var/obj/item/I in stand)
		qdel(I)
	qdel(Y)
	qdel(H)

/proc/herb_dressing_checks()
	var/obj/item/stack/medical/wild_herb/yarrow/Y = new(null, 1)
	herb_check((Y.treat_flags & MED_BANDAGE) && Y.heals_wounds, "yarrow binds bleeding wounds")
	var/obj/item/stack/medical/wild_herb/comfrey/C = new(null, 1)
	herb_check((C.treat_flags & MED_SALVE) && C.heal_brute > 0 && !C.steep_reagent, "comfrey is a bruise salve, never a tea")
	var/obj/item/stack/medical/wild_herb/elderflower/E = new(null, 1)
	herb_check(!E.treat_flags && E.steep_reagent == "elderflower_tea", "elderflower is a tea herb")
	var/obj/item/stack/medical/wild_herb/milk_thistle/M = new(null, 1)
	herb_check(!M.treat_flags && M.steep_reagent == "milk_thistle_tea", "milk thistle is a tea herb")
	qdel(Y)
	qdel(C)
	qdel(E)
	qdel(M)

/proc/herb_steeping_checks()
	var/turf/stand = locate(10, 10, 1)
	var/mob/living/human/herb_probe/H = new(stand)
	var/obj/item/weapon/reagent_containers/glass/beaker/B = new(locate(11, 10, 1))
	herb_check(B.is_open_container(), "the beaker is open")
	var/obj/item/stack/medical/wild_herb/elderflower/E = new(null, 2)
	E.loc = H
	herb_check(!E.steep(B, H) && E.amount == 2, "an empty beaker is refused")
	B.reagents.add_reagent("water", 5)
	herb_check(!E.steep(B, H) && E.amount == 2, "too little water is refused")
	B.reagents.add_reagent("water", 15)
	herb_check(E.steep(B, H) && E.amount == 1, "one elderflower sprig is steeped")
	herb_check(B.reagents.get_reagent_amount("elderflower_tea") == 10 && B.reagents.get_reagent_amount("water") == 10, "ten water turned into ten elderflower tea")
	var/turf/far = locate(20, 20, 1)
	B.loc = far
	herb_check(!E.steep(B, H) && E.amount == 1, "a distant container is refused")
	var/obj/item/stack/medical/wild_herb/comfrey/C = new(null, 1)
	herb_check(!C.steep(B, H) && C.amount == 1, "comfrey cannot be steeped")
	qdel(C)
	qdel(E)
	qdel(B)
	qdel(H)

/proc/herb_tea_checks()
	var/mob/living/human/herb_probe/H = new(locate(15, 15, 1))
	var/datum/reagent/drink/elderflower_tea/E = new
	H.disease = 1
	H.disease_type = "flu"
	H.disease_treatment = FALSE
	H.bodytemperature = 315
	E.affect_ingest(H, null, 0.1)
	herb_check(H.disease_treatment && H.bodytemperature < 315, "elderflower tea treats flu and cools a fever")
	var/datum/reagent/drink/milk_thistle_tea/M = new
	herb_check(M.id == "milk_thistle_tea" && M.metabolism < E.metabolism, "milk thistle tea is slow and lasting")
	qdel(E)
	qdel(M)
	qdel(H)

/proc/herb_seed_checks()
	map.ecology_wildlife = TRUE
	herb_check(!wild_herb_list.len, "picked-over test patches left the registry")
	var/n = wild_herb_seed_patches(TRUE)
	herb_check(n == 4 && wild_herb_list.len == 4, "a small grass world gets the minimum four patches [wild_herb_seed_report]")
	herb_check(wild_herb_seed_patches(TRUE) == 0, "a second pass finds the target met [wild_herb_seed_report]")
	var/obj/structure/wild/flowers/wild_herb/first = wild_herb_list[1]
	var/turf/T = first.loc
	qdel(first)
	herb_check(wild_herb_seed_patches(TRUE) == 1, "a lost patch is topped up [wild_herb_seed_report]")
	var/obj/structure/wild/flowers/wild_herb/occupied = wild_herb_list[1]
	herb_check(T && !wild_herb_site_ok(occupied.loc), "an occupied tile is not a site")
	herb_check(wild_herb_types_for("temperate").len == 4 && wild_herb_types_for("semiarid").len == 2 && !wild_herb_types_for("desert").len, "herbs follow their climates")
