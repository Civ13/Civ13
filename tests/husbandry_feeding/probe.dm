// Native husbandry feeding probe, included by tests/ecology_spawning/run_linux.py,
// never by the game DME. It drives code/modules/1713/husbandry_feeding.dm.
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
/obj/map_metadata/husbandry_probe/New()
	map = src
/mob/living/simple_animal/cattle/cow/feed_tester/crush()
	return
var/hf_failures = 0
var/hf_runtime_error = FALSE
/proc/hf_check(condition, label)
	if (!condition)
		hf_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	hf_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/husbandry_probe
		husbandry_checks()
	catch(var/exception/e)
		hf_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = hf_failures, "runtime_error" = hf_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/hf_refill(mob/living/simple_animal/cattle/cow/C, hunger)
	C.simplehunger = hunger
	C.udder.clear_reagents()
	var/total = 0
	for (var/i in 1 to 20)
		C.udder.clear_reagents()
		C.udder.add_reagent("milk", 10)
		total += C.udder.get_reagent_amount("milk")
	return total

/proc/husbandry_checks()
	var/mob/living/simple_animal/cattle/cow/feed_tester/C = new(locate(5, 5, 1))
	hf_check(istype(C.udder, /datum/reagents/udder), "cow udders use the fed-scaled holder")
	hf_check(hf_refill(C, 1000) == 200, "a well-fed cow fills at the full rate")
	hf_check(hf_refill(C, 300) == 100, "a hungry cow fills at half the rate")
	hf_check(hf_refill(C, 100) == 0, "a starving cow gives no milk")
	C.simplehunger = 1000
	C.udder.clear_reagents()
	C.udder.add_reagent("water", 10)
	C.simplehunger = 0
	C.udder.add_reagent("water", 10)
	hf_check(C.udder.get_reagent_amount("water") == 20, "only milk is scaled")
	var/mob/living/simple_animal/goat/female/G = new(locate(7, 5, 1))
	hf_check(istype(G.udder, /datum/reagents/udder), "goat udders use the fed-scaled holder")
	var/mob/living/simple_animal/bison/B = new(locate(9, 5, 1))
	hf_check(istype(B.udder, /datum/reagents/udder), "bison udders use the fed-scaled holder")
	// Eggs: the same thresholds on each 120-tick laying cycle.
	var/mob/living/simple_animal/chicken/H = new(locate(11, 5, 1))
	var/list/rates = list()
	for (var/hunger in list(1000, 300, 100))
		H.simplehunger = hunger
		var/laid = 0
		for (var/i in 1 to 400)
			laid += animal_product_roll(H)
		rates += laid
	hf_check(rates[1] == 400, "a well-fed hen lays every cycle")
	hf_check(rates[2] > 140 && rates[2] < 260, "a hungry hen lays about half the cycles ([rates[2]]/400)")
	hf_check(rates[3] == 0, "a starving hen stops laying")
	hf_check(animal_product_factor(null) == 1, "non-animal holders are not scaled")
