// Native probe: direct meat slicing conserves toxins and germs (issue 6938).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/meat_slicing/probe.dm
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
/obj/map_metadata/ms_probe/New()
	return

var/ms_failures = 0
var/ms_runtime_error = FALSE
/proc/ms_check(condition, label)
	if (!condition)
		ms_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	ms_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.name_set_event = new /decl/observ/name_set
		GLOB.stat_set_event = new /decl/observ/stat_set
		makeDatumRefLists()
		movementMachine = new
		map = new /obj/map_metadata/ms_probe
		ms_checks()
	catch(var/exception/e)
		ms_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = ms_failures, "runtime_error" = ms_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/ms_total(turf/T, id)
	. = 0
	for (var/obj/item/weapon/reagent_containers/food/snacks/rawcutlet/C in T)
		if (C.reagents)
			. += C.reagents.get_reagent_amount(id)

/proc/ms_count(turf/T)
	. = 0
	for (var/obj/item/weapon/reagent_containers/food/snacks/rawcutlet/C in T)
		.++

/proc/ms_checks()
	var/mob/living/human/cook = new(locate(2, 2, 1))
	var/obj/item/weapon/material/kitchen/utensil/knife/K = new(cook)
	var/turf/T1 = locate(4, 4, 1)
	var/obj/item/weapon/reagent_containers/food/snacks/meat/poisonfrog/F = new(T1)
	F.attackby(K, cook)
	ms_check(ms_count(T1) == 2, "frog meat cuts into two cutlets ([ms_count(T1)])")
	ms_check(abs(ms_total(T1, "cyanide") - 25) < 0.01, "the cutlets share all 25 units of the frog's cyanide ([ms_total(T1, "cyanide")])")
	ms_check(abs(ms_total(T1, "food_poisoning") - 15) < 0.01, "the cutlets share all 15 units of food poisoning ([ms_total(T1, "food_poisoning")])")
	var/turf/T2 = locate(8, 4, 1)
	var/obj/item/weapon/reagent_containers/food/snacks/bearmeat/B = new(T2)
	B.reagents.add_reagent("cholera", 6)
	B.attackby(K, cook)
	ms_check(ms_count(T2) == 3, "bear meat cuts into three cutlets ([ms_count(T2)])")
	ms_check(abs(ms_total(T2, "cholera") - 6) < 0.01, "three bear cutlets carry the slab's 6 units of cholera, not 9 ([ms_total(T2, "cholera")])")

	ms_check_dough_slices(K, cook)
	ms_check_salami_slices(K, cook)

/proc/ms_check_dough_slices(obj/item/weapon/material/kitchen/utensil/knife/K, mob/living/human/cook)
	var/turf/T = locate(5, 7, 1)
	var/obj/item/weapon/reagent_containers/food/snacks/sliceable/flatdough/input = new(T)
	input.reagents.add_reagent("water", 3)
	input.attackby(K, cook)
	var/list/portions = list()
	for (var/obj/item/weapon/reagent_containers/food/snacks/doughslice/piece in T)
		if (!QDELETED(piece))
			portions += piece
	ms_check(portions.len == 3, "flat dough produces three slices")
	for (var/obj/item/weapon/reagent_containers/food/snacks/doughslice/piece in portions)
		ms_check(abs(piece.reagents.total_volume - 2) < 0.01, "dough piece takes its share only")
		piece.attackby(K, cook)
	var/noodles = 0
	var/nutrition = 0
	var/protein = 0
	var/water = 0
	for (var/obj/item/weapon/reagent_containers/food/snacks/spaghetti/output in T)
		noodles++
		nutrition += output.reagents.get_reagent_amount("nutriment")
		protein += output.reagents.get_reagent_amount("protein")
		water += output.reagents.get_reagent_amount("water")
	ms_check(noodles == 3 && abs(nutrition - 2) < 0.01 && abs(protein - 1) < 0.01 && abs(water - 3) < 0.01, "dough and spaghetti conserve the mixed source across both cuts")

	var/turf/full_tile = locate(6, 7, 1)
	var/obj/item/weapon/reagent_containers/food/snacks/doughslice/full = new(full_tile)
	full.reagents.clear_reagents()
	full.reagents.add_reagent("protein", 50)
	full.attackby(K, cook)
	var/obj/item/weapon/reagent_containers/food/snacks/spaghetti/full_result = locate() in full_tile
	ms_check(full_result && full_result.reagents.get_reagent_amount("protein") == 50 && !full_result.reagents.get_reagent_amount("nutriment"), "a full one-portion slice does not lose room to default nutriment")

	var/turf/large_cut = locate(7, 7, 1)
	var/obj/item/weapon/reagent_containers/food/snacks/sliceable/flatdough/crude = new(large_cut)
	var/old_class = K.w_class
	K.w_class = 4
	crude.attackby(K, cook)
	K.w_class = old_class
	var/remaining = 0
	var/remaining_volume = 0
	for (var/obj/item/weapon/reagent_containers/food/snacks/doughslice/output in large_cut)
		remaining++
		remaining_volume += output.reagents.total_volume
	ms_check(remaining == 2 && abs(remaining_volume - 2) < 0.01, "a lost large-blade portion is not redistributed")

/proc/ms_check_salami_slices(obj/item/weapon/material/kitchen/utensil/knife/K, mob/living/human/cook)
	var/obj/item/weapon/reagent_containers/food/snacks/sausage/salted/salami/whole = new(cook)
	whole.reagents.remove_reagent("protein", 5)
	whole.reagents.add_reagent("water", 1)
	whole.attackby(K, cook)
	var/count = 0
	for (var/obj/item/weapon/reagent_containers/food/snacks/sausage/salted/salami/slice/piece in get_turf(cook))
		count++
		ms_check(abs(piece.reagents.get_reagent_amount("protein") - 0.75) < 0.01 && abs(piece.reagents.get_reagent_amount("water") - 0.25) < 0.01, "salami slice retains one quarter of remaining protein and water")
	ms_check(count == 4, "partly eaten salami still yields four slices")
