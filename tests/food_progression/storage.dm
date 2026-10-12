/obj/map_metadata/food_fixture/New()
	return
/mob/living/human/food_fixture/New()
	return
/mob/living/human/food_fixture/adaptStat(stat, amount)
	return
/proc/food_check(condition, message)
	if (!condition)
		text2file("FAIL: [message]", "food_result.txt")
		del(world)
		sleep(1) // Stop this caller while world shutdown completes.
/world
	hub = ""
	hub_password = ""
	maxx = 6
	maxy = 3
	maxz = 1
	fps = 20
	turf = /turf
/world/Topic(T, addr, master, key)
	return "Food fixture has no remote operations."
/world/Error(exception/e, datum/e_src)
	world.log << "Runtime error: [e]"
	text2file("FAIL: runtime [e]", "food_result.txt")
	del(world)
	sleep(1)
/world/New()
	OpenPort("none")
	food_check(!world.port, "isolated storage fixture closes its port")
	if (config)
		config.webhook_can_fire = FALSE
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	initialize_chemical_reagents()
	var/turf/T = locate(2,2,1)
	var/obj/item/weapon/can/sealed = new(T)
	sealed.open = FALSE
	var/obj/item/weapon/can/opened = new(T)
	opened.open = TRUE
	var/obj/item/weapon/reagent_containers/food/snacks/grown/tomato/closed_food = new(sealed)
	var/obj/item/weapon/reagent_containers/food/snacks/grown/tomato/open_food = new(opened)
	var/obj/item/weapon/reagent_containers/food/snacks/grown/tomato/floor_food = new(T)
	sleep(7)
	food_check(closed_food.decaytimer == 0, "sealed can pauses food age")
	food_check(open_food.decaytimer >= 300, "opened can accumulates food age")
	food_check(floor_food.decaytimer > open_food.decaytimer, "floor food ages faster than opened-can storage")
	var/age_before = open_food.decaytimer
	var/savefile/F = new("food_storage.sav")
	F["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/ref = map_storage.BuildVarDirectory(F, open_food)
	map_storage.clear_bookkeeping()
	var/obj/item/weapon/reagent_containers/food/snacks/grown/tomato/restored = map_storage.Load_Entry(F, ref, starting_loc = opened)
	food_check(restored && restored.decaytimer == age_before, "native food entry retains accumulated age")
	sleep(5)
	food_check(restored.decaytimer > age_before, "restored opened-can food continues aging")
	text2file("PASS: sealed/opened can aging and native food age restoration", "food_result.txt")
	del(world)

