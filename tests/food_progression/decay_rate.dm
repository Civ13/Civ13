// Bounded diagnostic: production handlers and serializer with accelerated waits.
// The runner replaces food's 590..610 ds wait with 20 and the rack's
// 601..650 ds restart with 21; it does not alter the age charged per callback.
/proc/food_check(condition, message)
	if (!condition)
		text2file("FAIL: [message]", "food_result.txt")
		del(world)
		sleep(1)
/world
	hub = ""
	hub_password = ""
	maxx = 6
	maxy = 3
	maxz = 1
	fps = 20
	turf = /turf
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/world/Topic(T, addr, master, key)
	return "Food fixture has no remote operations."
/world/Error(exception/e, datum/e_src)
	world.log << "Runtime error: [e]"
	text2file("FAIL: runtime [e]", "food_result.txt")
	del(world)
	sleep(1)
/world/New()
	OpenPort("none")
	food_check(!world.port, "decay-rate fixture closes listener")
	if (config)
		config.webhook_can_fire = FALSE
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	initialize_chemical_reagents()
	var/turf/T = locate(2,2,1)
	var/obj/structure/dehydrator/rack = new(T)
	sleep(35) // Let its constructor's reinit finish before owning the probe.
	rack.current_process_id = "decay-rate-fixture"
	var/obj/item/weapon/reagent_containers/food/snacks/driedmeat/original = new(T)
	original.mark_salted_meat()
	original.decaytimer = 80000
	food_check(rack.hang_on(original), "rack accepts paid dried input")
	rack.before_save()
	var/savefile/F = new("decay-rate.sav")
	F["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/ref = map_storage.BuildVarDirectory(F, original, 1)
	map_storage.clear_bookkeeping()
	qdel(original)
	var/start = world.time
	var/obj/item/weapon/reagent_containers/food/snacks/driedmeat/restored = map_storage.Load_Entry(F, ref, starting_loc = T)
	food_check(restored && restored.decay == 0 && restored.salted_meat && restored.decaytimer == 80000, "restored rack input retains paid paused state")
	var/offset = findtext(restored.name, "POS_") + 4
	var/list/position = rack.split_size(text2num(copytext(restored.name, offset, offset + 1), 16))
	rack.refill()
	food_check(restored.loc == rack.storage && rack.slots[position[1]][position[2]] == restored, "restored input reoccupies rack slot")
	var/obj/item/weapon/reagent_containers/food/snacks/driedmeat/released = rack.take_product_by_x_y(9 + (position[2] - 1) * 5, 4 + (4 - position[1]) * 6, T)
	food_check(released == restored && released.loc == T && released.decay == 600000, "normal removal restores salted limit")
	var/obj/item/weapon/reagent_containers/food/snacks/driedmeat/reference = new(T)
	reference.mark_salted_meat()
	reference.decaytimer = 80000
	food_check(world.time == start, "restore and reference fit within one scheduler tick")
	sleep(25)
	var/first_restored = released.decaytimer - 80000
	var/first_reference = reference.decaytimer - 80000
	world.log << "DECAY_RATE first restored=[first_restored] reference=[first_reference]"
	food_check(first_restored == 600 && first_reference == 600, "first sample observes one age charge in each item")
	sleep(20)
	var/second_restored = released.decaytimer - 80000
	var/second_reference = reference.decaytimer - 80000
	world.log << "DECAY_RATE second restored=[second_restored] reference=[second_reference]"
	food_check(second_reference == 1200, "reference observes two ordinary age charges")
	food_check(second_restored == second_reference, "restored rack food ages at the single ordinary rate")
	text2file("PASS: restored rack food and reference have one decay chain", "food_result.txt")
	del(world)
