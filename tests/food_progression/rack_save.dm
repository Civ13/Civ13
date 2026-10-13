/proc/rack_check(condition, message)
	if (!condition)
		text2file("FAIL: [message]", "food_result.txt")
		del(world)
		sleep(1)
// Fixture-only parent policy catches lost parent delegation and DM membership precedence.
/obj/structure/persistence_runtime_var(key)
	return key == "rack_fixture_parent_runtime" || ..()
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
	return "Rack save fixture has no remote operations."
/world/Error(exception/e, datum/e_src)
	world.log << "Runtime error: [e]"
	text2file("FAIL: runtime [e]", "food_result.txt")
	del(world)
	sleep(1)
/world/New()
	OpenPort("none")
	rack_check(!world.port, "rack fixture closes listener")
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
	rack_check(rack.persistence_runtime_var("rack_fixture_parent_runtime"), "rack preserves parent runtime exclusions")
	rack.name = "rack save paid-input fixture"
	sleep(35)
	var/obj/item/weapon/reagent_containers/food/snacks/octopus/input = new(T)
	input.reagents.remove_reagent("nutriment", 3)
	input.reagents.remove_reagent("protein", 0.5)
	input.decaytimer = 1200
	var/paid_nutrition = input.nutriments_value()
	rack_check(rack.hang_on(input), "rack accepts paid partial input")
	rack.set_dry_timer(input, 150)
	rack.current_process_id = "fixture suspended before export"
	var/savefile/F = new("rack_turf.sav")
	F["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	// Export the owning turf, not a manually selected dropped-food entry.
	var/turf_ref = map_storage.BuildVarDirectory(F, T, 1)
	var/rack_ref = map_storage.saving_references["\ref[rack]"]
	rack_check(turf_ref && rack_ref, "native graph exports owning turf and rack")
	rack_check(input.loc == T && !rack.storage.contents.len, "graph export invokes production before_save drop")
	var/rack_path = map_storage.entry_path(F, rack_ref)
	F.cd = rack_path
	var/list/rack_keys = F.dir.Copy()
	for (var/key in list("slots", "storage", "current_process_id"))
		world.log << "RACK_EXPORT runtime_field=[key] saved=[key in rack_keys]"
		rack_check(!(key in rack_keys), "rack export excludes runtime fields")
	var/saved_inputs = 0
	for (var/datum/saved in map_storage.saving_reference_pins)
		rack_check(!istype(saved, /obj/item/weapon/storage/internal), "rack graph excludes empty runtime storage wrapper")
		if (saved.type == /obj/item/weapon/reagent_containers/food/snacks/octopus)
			saved_inputs++
	rack_check(saved_inputs == 1, "native turf graph saves exactly one paid input")
	// Insert an obsolete field after the clean-export assertion to check import exclusion too.
	F["[rack_path]/current_process_id"] << list("kind" = "value", "value" = "obsolete imported process")
	map_storage.clear_bookkeeping()
	qdel(rack)
	qdel(input)
	var/turf/restored_turf = map_storage.Load_Entry(F, turf_ref, old_turf = T)
	var/obj/structure/dehydrator/restored_rack
	var/obj/item/weapon/reagent_containers/food/snacks/octopus/restored_input
	var/rack_count = 0
	var/input_count = 0
	for (var/obj/structure/dehydrator/candidate in restored_turf)
		if (candidate.name == "rack save paid-input fixture")
			restored_rack = candidate
			rack_count++
	for (var/obj/item/weapon/reagent_containers/food/snacks/octopus/candidate in restored_turf)
		if (candidate.type == /obj/item/weapon/reagent_containers/food/snacks/octopus)
			restored_input = candidate
			input_count++
	rack_check(rack_count == 1 && restored_rack != rack, "native graph restores one replacement rack")
	rack_check(input_count == 1 && restored_input != input, "native graph restores one replacement paid input")
	rack_check(restored_rack.current_process_id != "obsolete imported process", "rack import excludes stale runtime process")
	rack_check(restored_input.decaytimer == 1200 && abs(restored_input.nutriments_value() - paid_nutrition) < 0.001, "native graph restores paid nutrition and accumulated age")
	rack_check(restored_rack.get_dry_timer(restored_input) == 150, "native graph restores encoded drying progress")
	// Match Load_World's after_load pass without starting normal game systems.
	for (var/datum/loaded in map_storage.all_loaded.Copy())
		loaded.after_load()
		if (istype(loaded, /obj))
			var/obj/loaded_object = loaded
			if (loaded_object.load_datums && loaded_object.reagents)
				loaded_object.reagents.my_atom = loaded_object
	rack_check(restored_rack.storage && restored_rack.storage.loc == restored_rack, "restored rack rebuilds runtime storage before refill")
	var/obj/item/weapon/storage/internal/rebuilt_storage = restored_rack.storage
	rack_check(restored_rack.ensure_runtime_storage() == rebuilt_storage, "rack storage rebuild is idempotent")
	// Legacy saves may restore the empty wrapper in contents even though its pointer is excluded.
	qdel(rebuilt_storage)
	var/obj/item/weapon/storage/internal/legacy_storage = new(restored_rack)
	rack_check(restored_rack.ensure_runtime_storage() == legacy_storage, "rack adopts legacy restored storage contents")
	rack_check(legacy_storage.master_item == restored_rack && !legacy_storage.should_save, "legacy rack storage is rebound and excluded from future saves")
	var/storage_count = 0
	for (var/obj/item/weapon/storage/internal/candidate in restored_rack.contents)
		storage_count++
	rack_check(storage_count == 1, "rack owns exactly one live runtime storage wrapper")
	map_storage.clear_bookkeeping()
	sleep(170) // Allow native constructor and production after_load/reinit waits, unchanged.
	rack_check(restored_rack.storage && restored_rack.storage.loc == restored_rack, "restored rack owns live runtime storage")
	rack_check(restored_input.loc == restored_rack.storage, "production after_load refill recovers paid input")
#ifdef RACK_CONTROL_DUPLICATE
	var/obj/item/weapon/reagent_containers/food/snacks/octopus/duplicate = new(restored_rack.storage)
	duplicate.name = restored_input.name
#endif
	input_count = 0
	for (var/obj/item/weapon/reagent_containers/food/snacks/octopus/candidate in restored_rack.storage.contents)
		if (candidate.type == /obj/item/weapon/reagent_containers/food/snacks/octopus)
			input_count++
	rack_check(input_count == 1, "restored rack contains exactly one paid input")
	rack_check(restored_rack.get_dry_timer(restored_input) >= 150 && restored_rack.get_dry_timer(restored_input) < TIME_TO_DRY, "production refill retains unfinished progress")
	restored_rack.set_dry_timer(restored_input, TIME_TO_DRY - 150)
	restored_rack.current_process_id = "rack fixture completion"
	restored_rack.dry_process("rack fixture completion")
	sleep(155) // Production 150-tick drying wait is unchanged in this fixture.
	var/product_count = 0
	var/obj/item/weapon/reagent_containers/food/snacks/octopus/dried/product
	for (var/obj/item/weapon/reagent_containers/food/snacks/octopus/dried/candidate in restored_rack.storage.contents)
		product = candidate
		product_count++
	rack_check(product_count == 1 && !(restored_input in restored_rack.storage.contents), "restored rack converts one paid input once")
	rack_check(abs(product.nutriments_value() - paid_nutrition) < 0.001, "restored conversion retains paid nutrition")
	var/decay_offset = findtext(product.name, "DECAY_") + 6
	var/limit = text2num(copytext(product.name, decay_offset, decay_offset + 8))
	rack_check(limit > 0 && abs(product.decaytimer / limit - 1200 / 9000) < 0.0001, "restored conversion retains relative age")
	sleep(5)
	product_count = 0
	for (var/obj/item/weapon/reagent_containers/food/snacks/octopus/dried/candidate in restored_rack.storage.contents)
		product_count++
	rack_check(product_count == 1, "pending rack callbacks do not duplicate conversion")
	text2file("PASS: native turf rack graph, runtime exclusions and single paid conversion", "food_result.txt")
	del(world)
