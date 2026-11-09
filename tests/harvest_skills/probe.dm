// Native probe: trained hunting and farming skills raise harvest yields.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/harvest_skills/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 12
	maxy = 12
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/hs_probe/New()
	return
/mob/living/human/hs_probe/New()
	return
/mob/living/human/hs_probe/update_icons()
	return
/mob/living/simple_animal/cattle/cow/hs_probe/New()
	return
/mob/living/simple_animal/sheep/hs_probe/New()
	return
/obj/structure/farming/plant/potato/hs_probe/New()
	return
/obj/structure/farming/plant/hemp/hs_probe/New()
	return

var/hs_failures = 0
var/hs_runtime_error = FALSE
/proc/hs_check(condition, label)
	if (!condition)
		hs_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	hs_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/hs_probe
		hs_amount_checks()
		hs_skill_checks()
		hs_butcher_checks()
		hs_farming_checks()
	catch(var/exception/e)
		hs_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = hs_failures, "runtime_error" = hs_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/hs_amount_checks()
	hs_check(harvest_skill_amount(4, 0) == 4, "no bonus keeps the base yield")
	hs_check(harvest_skill_amount(4, 1) == 8, "full bonus doubles the yield")
	hs_check(harvest_skill_amount(4, 0.5) == 6, "half bonus adds half")
	hs_check(harvest_skill_amount(0, 1) == 0, "an empty yield stays empty")
	var/total = 0
	for (var/i = 1, i <= 2000, i++)
		total += harvest_skill_amount(1, 0.5)
	hs_check(total > 2800 && total < 3200, "fractional bonus averages out ([total]/2000)")

/proc/hs_skill_checks()
	var/mob/living/human/hs_probe/H = new(locate(1, 1, 1))
	hs_check(islist(H.stats["hunting"]), "new characters have a hunting skill")
	hs_check(H.harvest_skill_bonus("hunting") == 0, "default hunting gives no bonus")
	H.stats["hunting"] = list(150, 150)
	hs_check(abs(H.harvest_skill_bonus("hunting") - 0.5) < 0.001, "hunting 150 gives +50%")
	H.stats["farming"] = list(250, 250)
	hs_check(H.harvest_skill_bonus("farming") == 1, "bonus caps at +100%")
	H.stats["farming"] = list(60, 60)
	hs_check(H.harvest_skill_bonus("farming") == 0, "low skill never cuts the yield")
	// A body restored from an older save has no hunting entry.
	H.stats -= "hunting"
	hs_check(H.harvest_skill_bonus("hunting") == 0, "missing hunting reads as default")
	hs_check(islist(H.stats["hunting"]) && H.stats["hunting"][2] == 100, "missing hunting is restored at 100")
	H.stats -= "hunting"
	H.adaptStat("hunting", 10)
	hs_check(islist(H.stats["hunting"]) && H.stats["hunting"][2] > 100, "training restores and raises hunting")
	hs_check(harvest_skill_user_bonus(null, "hunting") == 0, "non-human harvesters get no bonus")
	qdel(H)

/proc/hs_count(turf/T, path, exact = TRUE)
	var/n = 0
	for (var/atom/movable/A in T)
		if (exact ? A.type == path : istype(A, path))
			n++
	return n

/proc/hs_clear(turf/T)
	for (var/atom/movable/A in T)
		qdel(A)

/proc/hs_butcher(path, turf/T, bonus)
	var/mob/living/simple_animal/S = new path(T)
	S.harvest_bonus = bonus
	S.harvest_products(T, FALSE)
	S.harvest_bonus = 0
	S.loc = null
	return S

/proc/hs_butcher_checks()
	var/turf/T = locate(3, 3, 1)
	var/meat = /obj/item/weapon/reagent_containers/food/snacks/meat
	hs_butcher(/mob/living/simple_animal/cattle/cow/hs_probe, T, 0)
	var/base_meat = hs_count(T, meat)
	var/base_fat = hs_count(T, /obj/item/weapon/reagent_containers/food/snacks/animalfat)
	hs_clear(T)
	hs_butcher(/mob/living/simple_animal/cattle/cow/hs_probe, T, 1)
	var/skilled_meat = hs_count(T, meat)
	var/skilled_fat = hs_count(T, /obj/item/weapon/reagent_containers/food/snacks/animalfat)
	hs_clear(T)
	hs_check(base_meat > 0 && skilled_meat == base_meat * 2, "master hunter doubles cow meat ([base_meat] -> [skilled_meat])")
	hs_check(skilled_fat == base_fat * 2, "master hunter doubles cow fat ([base_fat] -> [skilled_fat])")
	hs_butcher(/mob/living/simple_animal/sheep/hs_probe, T, 0.5)
	var/half_meat = hs_count(T, meat)
	hs_clear(T)
	hs_butcher(/mob/living/simple_animal/sheep/hs_probe, T, 0)
	var/sheep_meat = hs_count(T, meat)
	hs_clear(T)
	hs_check(half_meat >= sheep_meat && half_meat <= sheep_meat + round(sheep_meat / 2) + 1, "half bonus adds about half the sheep meat ([sheep_meat] -> [half_meat])")

/proc/hs_seed_total(turf/T)
	var/n = 0
	for (var/obj/item/stack/farming/seeds/S in T)
		n += S.amount
	return n

/proc/hs_stack_total(turf/T, path)
	var/n = 0
	for (var/obj/item/stack/S in T)
		if (istype(S, path))
			n += S.amount
	return n

/proc/hs_farming_checks()
	var/turf/T = locate(6, 6, 1)
	var/obj/structure/farming/plant/potato/hs_probe/P = new(T)
	P.plant_nutrition = 0
	P.spawn_seeds(0)
	hs_check(hs_seed_total(T) == 2, "unskilled harvest keeps two seeds")
	hs_clear(T)
	P = new(T)
	P.plant_nutrition = 0
	P.spawn_seeds(1)
	hs_check(hs_seed_total(T) == 4, "master farmer saves four seeds")
	hs_clear(T)
	P = new(T)
	P.plant_nutrition = 0
	P.spawn_produce(0)
	var/potato = /obj/item/weapon/reagent_containers/food/snacks/grown/potato
	hs_check(hs_count(T, potato) == 1, "unskilled potato harvest gives one")
	hs_clear(T)
	P = new(T)
	P.plant_nutrition = 0
	P.spawn_produce(1)
	hs_check(hs_count(T, potato) == 2, "master farmer gathers two potatoes")
	hs_clear(T)
	var/obj/structure/farming/plant/hemp/hs_probe/HP = new(T)
	HP.plant_nutrition = 0
	HP.spawn_produce(0)
	var/hemp = /obj/item/stack/material/hemp
	var/base_hemp = hs_stack_total(T, hemp)
	hs_clear(T)
	HP = new(T)
	HP.plant_nutrition = 0
	HP.spawn_produce(1)
	var/skilled_hemp = hs_stack_total(T, hemp)
	hs_clear(T)
	hs_check(base_hemp > 0 && skilled_hemp == base_hemp * 2, "master farmer doubles a stacked crop ([base_hemp] -> [skilled_hemp])")
