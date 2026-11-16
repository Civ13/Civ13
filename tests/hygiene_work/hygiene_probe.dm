// Native probe for dirt from work and dirty hands (hygiene_work.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/hygiene_work/hygiene_probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 6
	maxy = 3
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/hygiene_probe/New()
	return
var/hw_failures = 0
var/hw_runtime_error = FALSE
/proc/hw_check(condition, label)
	if (!condition)
		hw_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	hw_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		map = new /obj/map_metadata/hygiene_probe
		hw_checks()
	catch(var/exception/e)
		hw_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = hw_failures, "runtime_error" = hw_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)


/mob/living/human/hw_tester/New()
	return

/mob/living/human/hw_tester/adaptStat(statname, multiplier = 1, variety_key = null)
	if (statname == "farming")
		soil(1)

/proc/hw_checks()
	var/mob/living/human/hw_tester/H = new(locate(2, 2, 1))
	H.hygiene = 200
	H.soil(3, DIRTY_HANDS_GRIME)
	hw_check(H.hygiene == 197 && H.dirty_hands == DIRTY_HANDS_GRIME, "butchering dirties body and hands ([H.hygiene], [H.dirty_hands])")
	H.soil(5, DIRTY_HANDS_WASTE)
	hw_check(H.dirty_hands == DIRTY_HANDS_WASTE, "waste makes the hands worse")
	H.soil(1, DIRTY_HANDS_GRIME)
	hw_check(H.dirty_hands == DIRTY_HANDS_WASTE, "grime never lessens waste on the hands")
	H.wash_hands()
	hw_check(!H.dirty_hands, "washing clears the hands")
	H.adaptStat("farming", 1)
	hw_check(H.hygiene == 190 && !H.dirty_hands, "farm work dirties the body, not the hands ([H.hygiene])")
	H.gloves = new /obj/item/clothing/gloves(H)
	H.soil(0, DIRTY_HANDS_WASTE)
	hw_check(!H.dirty_hands, "gloves keep the hands clean")
	H.gloves = null
	hw_check(HYGIENE_FACTOR == 0.015, "idle dirt is slower (0.015 a second)")

	// Freshly bathed: once on reaching 200 from below, not again soon.
	H.hygiene = 150
	var/mood_before = H.mood
	H.raise_hygiene(200)
	hw_check(H.hygiene == 200 && H.mood == mood_before + 3, "a wash to 200 gives freshly bathed ([H.mood - mood_before])")
	H.hygiene = 150
	mood_before = H.mood
	H.raise_hygiene(200)
	hw_check(H.mood == mood_before, "freshly bathed waits twenty minutes")

	// Tubs hold their own water on Persistence maps.
	map.persistence = TRUE
	var/obj/structure/shower/bathtub/wooden/tub = new(locate(6, 3, 1))
	tub.attack_hand(H)
	hw_check(!tub.on, "a dry tub will not run")
	var/obj/item/weapon/reagent_containers/glass/bucket/B = new(locate(6, 2, 1))
	B.reagents.add_reagent("water", 150)
	hw_check(tub.attackby(B, H) && tub.water_store == 100, "a bucket fills the tub to its tank")
	tub.attack_hand(H)
	hw_check(tub.on && tub.water_store == 0, "running the tub takes a tubful")
	var/obj/structure/shower/bathtub/steel/steel_tub = new(locate(1, 3, 1))
	hw_check(steel_tub.water_per_use == 80, "a steel tub takes less water")
	map.persistence = FALSE
	var/obj/structure/shower/bathtub/wooden/round_tub = new(locate(1, 1, 1))
	round_tub.attack_hand(H)
	hw_check(round_tub.on, "tubs run free on round maps")
