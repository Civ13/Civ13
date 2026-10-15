/proc/rack_check(condition, message)
	if (!condition)
		text2file("FAIL: [message]", "food_result.txt")
		del(world)
		sleep(1)
// Fixture-only parent policy catches lost parent delegation and DM membership precedence.
/obj/structure/persistence_runtime_var(key)
	return key == "rack_fixture_parent_runtime" || ..()
// Inject only the external export outcome; execute the production rack hook.
/map_storage/rack_commit_failure/commit_save_transfer(datum/save_transfer/ticket)
	throw EXCEPTION("Fixture refuses paid transfer commit")
/proc/rack_wrapper_refusal(mode)
	var/turf/T = locate(5,2,1)
	var/obj/structure/dehydrator/rack = new(T)
	var/obj/item/weapon/reagent_containers/food/snacks/fishfillet/input = new(T)
	rack_check(rack.hang_on(input), "coverage fixture accepts paid input")
	rack.set_dry_timer(input, 150)
	var/original_name = input.name
	var/original_nutrition = input.nutriments_value()
	var/obj/item/weapon/storage/internal/foreign_owner
	if (mode == 2)
		foreign_owner = new(T)
		input.loc = foreign_owner // Leave a stale slot pointing to foreign custody.
	else
		for (var/row = 1, row <= 4, row++)
			for (var/column = 1, column <= 3, column++)
				rack.slots[row][column] = null // Legacy wrapper exists before queued refill.
	var/obj/item/weapon/reagent_containers/food/snacks/fishfillet/represented
	if (mode == 1)
		represented = new(T)
		rack_check(rack.hang_on(represented), "partial coverage fixture accepts represented input")
	var/atom/original_location = input.loc
	rack.current_process_id = "coverage fixture suspended"
	var/map_storage/exporter = new
	exporter.saving_z = 1
	var/savefile/F = new("rack_coverage_[mode].sav")
	var/refused_for_coverage = FALSE
	try
		exporter.BuildVarDirectory(F, T, 1)
	catch (var/exception/error)
		refused_for_coverage = !!findtext("[error]", mode == 2 ? "paid child left its storage" : "unrepresented storage child")
	rack_check(refused_for_coverage, "wrapper coverage refusal mode [mode] reaches ownership check")
	rack_check(input.loc == original_location && input.name == original_name && rack.get_dry_timer(input) == 150 && abs(input.nutriments_value() - original_nutrition) < 0.001, "wrapper coverage refusal mode [mode] preserves input custody and progress")
	rack_check(rack.current_process_id == "coverage fixture suspended" && (!represented || represented.loc == rack.storage), "wrapper coverage refusal mode [mode] precedes drop and callback mutation")
	exporter.clear_bookkeeping()
	if (mode == 2)
		// Teardown must not invoke Destroy's ordinary slot removal on foreign input.
		for (var/row = 1, row <= 4, row++)
			for (var/column = 1, column <= 3, column++)
				rack.slots[row][column] = null
	qdel(rack)
	qdel(input)
	if (represented)
		qdel(represented)
	if (foreign_owner)
		qdel(foreign_owner)
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
	rack_wrapper_refusal(0)
	rack_wrapper_refusal(1)
	rack_wrapper_refusal(2)
	var/turf/failure_turf = locate(4,2,1)
	var/obj/structure/dehydrator/failure_rack = new(failure_turf)
	var/obj/item/weapon/reagent_containers/food/snacks/octopus/failure_input = new(failure_turf)
	var/failure_nutrition = failure_input.nutriments_value()
	rack_check(failure_rack.hang_on(failure_input), "failure fixture accepts paid input")
	failure_rack.set_dry_timer(failure_input, 150)
	failure_rack.reinit() // Queue a real production wait before the failing save.
	var/map_storage/rack_commit_failure/failure_exporter = new
	failure_exporter.saving_z = 1
	var/savefile/failure_file = new("rack_commit_refused.sav")
	var/commit_refused = FALSE
	try
		failure_exporter.BuildVarDirectory(failure_file, failure_turf, 1)
	catch (var/exception/commit_error)
		commit_refused = !!findtext("[commit_error]", "Fixture refuses paid transfer commit")
	rack_check(commit_refused && failure_rack.current_process_id == "SAVE_REPAIR_REQUIRED", "failed commit leaves rack requiring repair")
	sleep(35) // New/reinit callbacks must not restart or reclaim the failed rack.
	rack_check(failure_rack.current_process_id == "SAVE_REPAIR_REQUIRED" && failure_input.loc == failure_turf, "pending reinit cannot reclaim failed save input")
	rack_check(failure_rack.get_dry_timer(failure_input) == 150 && abs(failure_input.nutriments_value() - failure_nutrition) < 0.001, "failed commit preserves paid nutrition and progress")
	failure_exporter.clear_bookkeeping()
	qdel(failure_rack)
	qdel(failure_input)
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
	// Schedule a real production wait, replace its owner, then let the unchanged
	// 150-tick wait wake. A stale callback must neither advance progress nor claim input.
	rack.set_dry_timer(input, TIME_TO_DRY - 150)
	rack.current_process_id = "fixture obsolete waiting callback"
	rack.dry_process("fixture obsolete waiting callback")
	rack.current_process_id = "fixture replacement holds paid input"
	sleep(155)
	var/stale_input_unchanged = input && input.loc == rack.storage && rack.get_dry_timer(input) == TIME_TO_DRY - 150
	rack_check(stale_input_unchanged, "stale drying wait does not advance or consume paid input")
	var/stale_products = 0
	for (var/obj/item/weapon/reagent_containers/food/snacks/octopus/dried/candidate in rack.storage.contents)
		stale_products++
	rack_check(stale_products == 0 && abs(input.nutriments_value() - paid_nutrition) < 0.001, "stale drying wait creates no product or nutrition change")
	rack.set_dry_timer(input, 150)
	rack.current_process_id = "fixture suspended before export"
	// Reference-first discovery has no active owning-turf frame. Refuse it
	// before the production hook can move input or clear the rack's slots.
	var/savefile/refused_file = new("rack_refused.sav")
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/reference_first_refused = FALSE
	try
		map_storage.BuildVarDirectory(refused_file, rack, 1)
	catch (var/exception/reference_error)
		reference_first_refused = !!findtext("[reference_error]", "owning turf")
	rack_check(reference_first_refused, "reference-first rack export refuses missing parent context")
	rack_check(input.loc == rack.storage && rack.get_dry_timer(input) == 150 && abs(input.nutriments_value() - paid_nutrition) < 0.001, "refused rack export preserves paid input and progress")
	rack_check(rack.current_process_id == "fixture suspended before export", "refused rack export preserves callback ownership before mutation")
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
	var/input_identity_pins = 0
	for (var/datum/saved in map_storage.saving_reference_pins)
		if (saved == input)
			input_identity_pins++
		rack_check(!istype(saved, /obj/item/weapon/storage/internal), "rack graph excludes empty runtime storage wrapper")
		if (saved.type == /obj/item/weapon/reagent_containers/food/snacks/octopus)
			saved_inputs++
	var/input_ref = map_storage.saving_references["\ref[input]"]
	var/turf_path = map_storage.entry_path(F, turf_ref)
	var/content_text = F["[turf_path]/content"]
	var/list/turf_content_refs = params2list(content_text)
	var/input_reachable = input_ref && ("[input_ref]" in turf_content_refs)
	var/input_content_occurrences = 0
	// params2list collapses repeated keys. Count the serialized numeric tokens
	// before decoding so duplicate parent edges cannot hide behind membership.
	var/list/content_tokens = splittext(content_text, "&")
	for (var/content_ref in content_tokens)
		if (input_ref && content_ref == "[input_ref]")
			input_content_occurrences++
	world.log << "RACK_GRAPH paid_input_pins=[saved_inputs] identity_pins=[input_identity_pins] input_ref=[input_ref] direct_turf_ref=[input_reachable] direct_occurrences=[input_content_occurrences] dropped_to_turf=[input.loc == T] turf_content_count=[turf_content_refs.len]"
	rack_check(saved_inputs == 1, "native turf graph saves exactly one paid input")
	rack_check(input_identity_pins == 1, "native graph pins paid input identity exactly once")
	rack_check(input_reachable, "owning turf graph references saved paid input")
	rack_check(input_content_occurrences == 1, "owning turf graph references paid input identity exactly once")
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
