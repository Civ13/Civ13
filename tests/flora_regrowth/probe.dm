/world
	hub = ""
	hub_password = ""
	maxx = 40
	maxy = 40
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/flora_probe
	flora_regrowth = TRUE
/obj/map_metadata/flora_probe/New()
	return
/mob/living/human/flora_probe/New()
	return
var/flora_failures = 0
var/flora_runtime_error = FALSE
/proc/flora_check(condition, label)
	if (!condition)
		flora_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	flora_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/flora_probe
		season = "SUMMER"
		var/area/A = get_area(locate(1, 1, 1))
		A.location = AREA_OUTSIDE
		A.climate = "temperate"
		for (var/turf/T in block(locate(1, 1, 1), locate(40, 40, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		flora_site_checks()
		flora_plant_checks()
		flora_palm_checks()
		flora_stump_checks()
		flora_persistence_checks()
	catch(var/exception/e)
		flora_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = flora_failures, "runtime_error" = flora_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/flora_new_worker()
	var/datum/flora_regrowth/F = new
	F.enabled = TRUE
	F.started_at = world.time - 10 MINUTES
	return F

/proc/flora_site_checks()
	var/datum/flora_regrowth/F = flora_new_worker()
	var/turf/T = locate(20, 20, 1)
	flora_check(isnull(F.plant_site_error(T)), "open outdoor grass is a wild plant site")
	var/obj/structure/S = new /obj/structure(locate(22, 20, 1))
	flora_check(F.plant_site_error(T) == "settled", "a built structure within three tiles keeps plants away")
	qdel(S)
	var/turf/P = locate(18, 21, 1)
	P = P.ChangeTurf(/turf/floor/dirt/ploughed, FALSE, FALSE)
	flora_check(F.plant_site_error(T) == "settled", "a nearby field keeps plants away")
	P.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
	var/obj/structure/wild/smallbush/B = new(locate(21, 21, 1))
	flora_check(isnull(F.plant_site_error(T)), "wild bushes nearby do not count as a settlement")
	qdel(B)
	var/obj/roof/R = new(locate(19, 19, 1))
	flora_check(F.plant_site_error(T) == "settled", "a roof nearby keeps plants away")
	qdel(R)
	var/obj/item/I = new /obj/item(T)
	flora_check(F.plant_site_error(T) == "occupied", "a tile with an item is refused")
	qdel(I)
	var/area/A = get_area(T)
	A.location = AREA_INSIDE
	flora_check(F.plant_site_error(T) == "habitat", "indoor areas are refused")
	A.location = AREA_OUTSIDE
	var/turf/W = locate(2, 2, 1)
	W = W.ChangeTurf(/turf/floor/beach/water, FALSE, FALSE)
	flora_check(F.plant_site_error(W) == "ground", "water is refused")
	W.ChangeTurf(/turf/floor/grass, FALSE, FALSE)

/proc/flora_plant_checks()
	var/datum/flora_regrowth/F = flora_new_worker()
	wild_plant_list = list()
	F.started_at = world.time
	flora_check(F.cycle() == 0 && !wild_plant_list.len, "nothing grows during warm-up")
	F.started_at = world.time - 10 MINUTES
	F.cycle()
	flora_check(F.plant_target == 4, "target is 2.5 plants per 1000 tiles of habitat (1600 tiles -> 4), got [F.plant_target]")
	flora_check(wild_plant_list.len == 4, "a cycle grows plants up to the target, got [wild_plant_list.len]")
	F.cycle()
	flora_check(wild_plant_list.len == 4, "no plants grow above the target")
	var/all_fit = TRUE
	for (var/obj/structure/farming/plant/P in wild_plant_list)
		if (!P.wild || !P.readyHarvest() || !("temperate" in P.biomes) || !(season in P.seasons) || !istype(get_turf(P), /turf/floor/grass) || !findtext(P.name, "wild "))
			all_fit = FALSE
	flora_check(all_fit, "wild plants are ripe, named wild, on grass and suit the biome and season")
	var/obj/structure/farming/plant/P = wild_plant_list[1]
	var/stage_before = P.stage
	var/water_before = P.water
	P.growth()
	flora_check(P.stage == stage_before && P.water == water_before, "a wild plant does not grow or dry out")
	// Harvest returns produce and seeds like a farmed crop.
	var/turf/PT = get_turf(P)
	var/obj/structure/farming/plant/wheat/H = new(locate(5, 5, 1))
	H.make_wild()
	var/items_before = 0
	for (var/obj/item/I in H.loc)
		items_before++
	H.spawn_seeds()
	H.spawn_produce()
	var/items_after = 0
	for (var/obj/item/I in H.loc)
		items_after++
	flora_check(items_after > items_before, "harvesting a wild plant gives produce and seeds")
	qdel(H)
	flora_check(!(H in wild_plant_list), "a destroyed wild plant leaves the registry")
	for (var/obj/item/I in locate(5, 5, 1))
		qdel(I)
	// Winter withers plants that are out of season.
	season = "WINTER"
	F.wither_plants()
	var/out_of_season = 0
	for (var/obj/structure/farming/plant/W in wild_plant_list)
		if (!(season in W.seasons))
			out_of_season++
	flora_check(out_of_season == 0, "out-of-season wild plants wither")
	season = "SUMMER"
	flora_check(PT != null, "plant tile existed")
	for (var/obj/structure/farming/plant/W in wild_plant_list.Copy())
		qdel(W)
	// More than one scan budget of in-season plants must not hide later plants.
	for (var/i = 1, i <= 32, i++)
		var/obj/structure/farming/plant/wheat/retained = new(locate(6, 6, 1))
		retained.make_wild()
		retained.seasons = list("SUMMER")
	var/obj/structure/farming/plant/wheat/expired = new(locate(6, 6, 1))
	expired.make_wild()
	expired.seasons = list("WINTER")
	F.wither_plants()
	flora_check(!QDELETED(expired), "bounded first scan leaves the later plant")
	F.wither_plants()
	flora_check(QDELETED(expired), "later out-of-season plant is visited on the next scan")
	flora_check(wild_plant_list.len == 32, "in-season plants remain registered")
	for (var/obj/structure/farming/plant/W in wild_plant_list.Copy())
		qdel(W)

/proc/flora_palm_checks()
	var/turf/T = locate(15, 15, 1)
	var/mob/living/human/flora_probe/H = new(T)
	var/obj/structure/wild/palm/P = new(locate(16, 15, 1))
	var/obj/item/knife = new(H)
	var/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/tribalpot/pot = new(H)
	var/obj/item/replacement = new(H)
	H.r_hand = knife
	H.l_hand = replacement
	var/datum/epoch = persistence_admission_identity
	flora_check(!P.finish_sap_extraction(H, knife, pot, TRUE, epoch) && !QDELETED(replacement) && !P.cooldown_sap, "replaced pot cannot be consumed or yield sap")
	H.l_hand = pot
	var/datum/old_epoch = new
	flora_check(!P.finish_sap_extraction(H, knife, pot, TRUE, old_epoch) && !QDELETED(pot), "changed persistence identity cancels extraction")
	flora_check(P.finish_sap_extraction(H, knife, pot, TRUE, epoch) && QDELETED(pot) && P.cooldown_sap, "valid extraction consumes the retained pot and claims cooldown")
	var/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/tribalpot/second = new(H)
	H.l_hand = second
	flora_check(!P.finish_sap_extraction(H, knife, second, TRUE, epoch) && !QDELETED(second), "a competing extraction cannot consume a second pot")
	qdel(P)
	qdel(H)

/proc/flora_stump_checks()
	var/datum/flora_regrowth/F = flora_new_worker()
	regrowing_stump_list = list()
	var/turf/T = locate(10, 30, 1)
	var/obj/structure/wild/tree/live_tree/pine/tree = new(T)
	tree.health = 0
	tree.try_destroy()
	var/obj/structure/wild/tree_stump/regrowing/S = locate() in T
	flora_check(S && S.regrow_type == /obj/structure/wild/tree/live_tree/pine, "a chopped pine leaves a stump that remembers it")
	flora_check(S && (S in regrowing_stump_list), "the stump registers for regrowth")
	var/turf/T2 = locate(12, 30, 1)
	var/obj/structure/wild/tree/live_tree/burnt = new(T2)
	qdel(burnt)
	flora_check(!(locate(/obj/structure/wild/tree_stump) in T2), "a tree destroyed at full health (fire, shell, load) leaves no stump")
	var/obj/structure/wild/smallbush/bush = new(T2)
	bush.health = 0
	bush.try_destroy()
	flora_check(!(locate(/obj/structure/wild/tree_stump) in T2), "bushes leave no stump")
	map.stump_regrowth_minutes = 1 // every visit regrows
	season = "WINTER"
	F.regrow_stumps()
	flora_check(!QDELETED(S) && (locate(/obj/structure/wild/tree_stump/regrowing) in T), "stumps do not regrow in winter")
	season = "SUMMER"
	var/obj/structure/blocker = new /obj/structure(T)
	blocker.density = FALSE
	F.regrow_stumps()
	flora_check(!QDELETED(S), "a stump under a non-dense structure does not regrow")
	qdel(blocker)
	var/list/items = list()
	for (var/i = 1, i <= 33, i++)
		var/obj/item/created = new(T)
		items += created
	F.regrow_stumps()
	var/obj/structure/wild/tree/live_tree/pine/back = locate() in T
	flora_check(QDELETED(S) && back && !(locate(/obj/structure/wild/tree_stump) in T), "the stump ignores itself and regrows despite harmless items")
	for (var/obj/item/I in items)
		qdel(I)
	flora_check(!(S in regrowing_stump_list), "the regrown stump leaves the registry")
	flora_check(F.trees_regrown == 1, "regrown trees are counted")
	var/obj/structure/wild/palm/palm = new(T2)
	palm.health = 0
	palm.try_destroy()
	var/obj/structure/wild/tree_stump/regrowing/S2 = locate() in T2
	flora_check(S2 && S2.regrow_type == /obj/structure/wild/palm, "a chopped palm leaves a palm stump")
	S2.health = 0
	S2.try_destroy()
	flora_check(!(locate(/obj/structure/wild/tree_stump) in T2), "chopping a stump clears it without another stump")
	map.stump_regrowth_minutes = 240
	qdel(back)

/proc/flora_persistence_checks()
	var/obj/structure/wild/tree_stump/regrowing/S = new(locate(30, 30, 1))
	S.regrow_type = /obj/structure/wild/jungle/medpine
	var/list/saved = S.get_saved_vars()
	flora_check(("regrow_type" in saved), "the stump saves the tree it regrows as")
	regrowing_stump_list -= S
	S.after_load()
	flora_check((S in regrowing_stump_list), "a loaded stump registers again")
	S.regrow_type = null
	S.after_load()
	flora_check(S.regrow_type == /obj/structure/wild/tree/live_tree, "a missing regrow type falls back to a broadleaf tree")
	qdel(S)
	var/obj/structure/farming/plant/oat/P = new(locate(31, 31, 1))
	P.make_wild()
	var/list/plant_saved = P.get_saved_vars()
	flora_check(("wild" in plant_saved) && ("stage" in plant_saved), "a wild plant saves its wild flag and stage")
	wild_plant_list -= P
	P.after_load()
	flora_check((P in wild_plant_list), "a loaded wild plant registers again")
	qdel(P)
	var/datum/flora_regrowth/F = new
	flora_check(F.persistence_runtime_var("plant_fit") && F.persistence_runtime_var("enabled") && !F.should_save, "worker state is runtime only")
	flora_check(map.persistence_runtime_var("flora_regrowth") && map.persistence_runtime_var("stump_regrowth_minutes"), "map flora policy is not saved")
	var/obj/map_metadata/nomads/N = /obj/map_metadata/nomads
	var/obj/map_metadata/M = /obj/map_metadata
	flora_check(initial(N.flora_regrowth) && !initial(M.flora_regrowth), "nomads maps opt in; other maps do not")
