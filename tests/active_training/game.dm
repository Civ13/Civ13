var/training_fixture_time = 0
var/training_failures = 0
var/training_wait_mode = "success"
var/training_wait_count = 0
/world
	hub = ""
	hub_password = ""
	maxx = 8
	maxy = 8
	maxz = 2
	turf = /turf
	visibility = 0
/world/OpenPort(port)
	return port == "none" ? ..() : FALSE
/obj/map_metadata/training_fixture/New()
	return
/mob/living/human/training_fixture/New()
	species = new /datum/species/human
	body_build = new /datum/body_build
	bloodstr = new /datum/reagents/metabolism(1000, src, CHEM_BLOOD)
	ingested = new /datum/reagents/metabolism(1000, src, CHEM_INGEST)
	touching = new /datum/reagents/metabolism(1000, src, CHEM_TOUCH)
	reagents = bloodstr
	vessel = new /datum/reagents(1000, src)
/obj/structure/exercise/training_fixture/exercise_wait(mob/living/human/H, duration)
	return training_wait(src,H,duration)
/obj/structure/exercise/course/training_fixture/exercise_wait(mob/living/human/H, duration)
	return training_wait(src,H,duration)
/obj/structure/exercise/modern/training_fixture/exercise_wait(mob/living/human/H, duration)
	return training_wait(src,H,duration)
/proc/training_wait(obj/structure/exercise/E,mob/living/human/H,duration)
	training_wait_count++
	training_check(!E.complete_repetition(H), "busy lock rejects recursive repetition")
	if (training_wait_mode == "cancel")
		H.cancel_exercise()
	if (training_wait_mode == "move")
		H.forceMove(locate(7,7,1))
	if (training_wait_mode == "death")
		H.stat = DEAD
	if (training_wait_mode == "success")
		training_fixture_time += duration
	return training_wait_mode != "interrupt"
/proc/training_check(condition,label)
	if (!condition)
		training_failures++
	world.log << "[condition ? "PASS" : "FAIL:"] [label]"
/world/Error(exception/e)
	training_failures++
	world.log << "runtime error: [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	// Global startup is bypassed; initialize its real round identity before saving.
	generate_gameid()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	movementMachine = new
	map = new /obj/map_metadata/training_fixture
	map.ID = MAP_NOMADS_CONTINENTAL
	map.ordinal_age = 0
	try
		var/mob/living/human/training_fixture/H = new(locate(2,2,1))
		var/mob/living/human/training_fixture/other = new(locate(2,2,1))
		var/obj/structure/exercise/training_fixture/E = new(locate(2,2,1))
		H.stats["strength"] = list(80,80)
		E.attack_hand(H)
		training_check(E.actor == H && E.repetition == 1 && H.getMaxStat("strength") == 80 && training_wait_count == 1, "one manual repetition gives no partial XP or autonomous continuation")
		E.attack_hand(other)
		training_check(E.actor == H && !other.exercise_equipment, "equipment claim blocks concurrent actor")
		var/obj/structure/exercise/training_fixture/second = new(locate(2,2,1))
		second.attack_hand(H)
		training_check(!second.actor && H.exercise_equipment == E, "second equipment cannot bypass actor session")
		E.attack_hand(H)
		E.attack_hand(H)
		training_check(abs(H.getMaxStat("strength") - 80.4) < 0.001 && H.exercise_fatigue == 2 && !E.actor && !H.exercise_equipment && training_fixture_time == 450, "three manual repetitions complete finite 45-second paid-equipment set (strength [H.getMaxStat("strength")])")
		var/gain = H.getMaxStat("strength")
		for (var/mode in list("interrupt","move","death","cancel"))
			training_wait_mode = mode
			H.forceMove(locate(2,2,1))
			H.stat = CONSCIOUS
			E.attack_hand(H)
			training_check(!H.exercise_equipment && !E.actor && H.getMaxStat("strength") == gain, "[mode] rejects XP and releases claim")
		training_wait_mode = "success"
		H.stat = CONSCIOUS
		H.forceMove(locate(2,2,1))
		H.exercise_fatigue = 6
		training_check(!E.eligible(H), "shared fatigue blocks additional training")
		training_fixture_time += 600
		H.recover_exercise()
		training_check(H.exercise_fatigue == 5, "one running-server minute recovers one fatigue point")
		H.exercise_fatigue = 4
		H.exercise_rest_epoch = training_fixture_time
		H.stats["strength"] = list(100,100)
		E.attack_hand(H)
		E.attack_hand(H)
		E.attack_hand(H)
		training_check(abs(H.getMaxStat("strength") - 100.1) < 0.001 && H.exercise_fatigue == 6, "fatigue and intermediate training diminish native reward")
		H.exercise_fatigue = 0
		H.stats["strength"] = list(124.9,124.9)
		E.attack_hand(H)
		E.attack_hand(H)
		E.attack_hand(H)
		training_check(H.getMaxStat("strength") == 125 && !E.eligible(H), "early equipment cap preserves advanced useful practice")
		var/obj/structure/exercise/modern/training_fixture/M = new(locate(2,2,1))
		training_check(!M.eligible(H), "Modern gym equipment rejects early era")
		map.ordinal_age = 8
		H.exercise_fatigue = 0
		training_check(M.eligible(H), "Modern equipment permits intermediate training")
		H.stats["strength"] = list(149.9,149.9)
		M.attack_hand(H)
		M.attack_hand(H)
		M.attack_hand(H)
		training_check(H.getMaxStat("strength") == 150 && !M.eligible(H), "Modern gym cap retains advanced native progression")
		H.stats["strength"] = list(125,125)
		H.exercise_fatigue = 0
		var/obj/structure/exercise/course/training_fixture/C = new(locate(2,2,1))
		H.stats["dexterity"] = list(80,80)
		H.stats["stamina"] = list(80,80)
		C.attack_hand(H)
		training_check(!C.complete_repetition(H) && !C.actor && H.getMaxStat("dexterity") == 80, "course rejects skipped physical movement")
		C.attack_hand(H)
		for (var/leg = 1, leg <= 4, leg++)
			H.forceMove(C.goal())
			training_check(C.complete_repetition(H), "actual corner position and manual leg [leg]")
		training_check(abs(H.getMaxStat("dexterity") - 80.24) < 0.001 && abs(H.getMaxStat("stamina") - 80.24) < 0.001 && !C.actor, "completed physical course awards bounded native dexterity and stamina")
		H.forceMove(locate(2,2,1))
		M.attack_hand(H)
		qdel(M)
		training_check(!H.exercise_equipment, "equipment deletion clears actor session")
		E.attack_hand(other)
		qdel(other)
		training_check(!E.actor, "human deletion releases equipment actor")
		H.exercise_fatigue = 5
		E.actor = H
		H.exercise_equipment = E
		E.origin = H.loc
		E.repetition = 1
		training_check(map_storage.Save_World() && map_storage.validate_world_save(), "native equipment, fatigue and stat save")
		map_storage.ClearMap()
		training_check(map_storage.Load_World(), "native exercise world reload")
		H = locate(/mob/living/human/training_fixture) in locate(2,2,1)
		E = locate(/obj/structure/exercise/training_fixture) in locate(2,2,1)
		training_check(H && E && H.exercise_fatigue == 5 && H.getMaxStat("strength") == 125 && !H.exercise_equipment && !E.actor && !E.repetition && H.exercise_rest_epoch == -1, "durable gains/fatigue survive; runtime claims and clock do not")
	catch (var/exception/e)
		training_check(FALSE,"exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit"=world.params["tested_commit"],"failures"=training_failures,"byond_build"=world.byond_build)),"result.json")
	del(world)
