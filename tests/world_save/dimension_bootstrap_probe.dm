// Two fresh processes share only copied, temporary save files. The allocator is
// the production shared allocator; roof construction and round-v2 metadata are separate.
world
	name = "Civ13 offline dimension bootstrap"
	sleep_offline = FALSE
	maxx = 8
	maxy = 6
	maxz = 2
	turf = /turf/dimension_test
	visibility = 0
/turf/dimension_test
	map_storage_saved_vars = "name;dir"
/turf/floor/broken_floor
/obj/item/dimension_test
	var/pair_id = ""
	var/number = 0
	var/turf/destination
	var/area/current_area
var/allocation_calls = 0
var/checks = 0
/proc/check(condition, message)
	checks++
	if(!condition) throw EXCEPTION(message)
/map_storage/dimension_fixture/allocate_saved_level(target_z)
	allocation_calls++
	var/result = ..()
	if(world.params["case"] == "allocation-failure") return FALSE
	if(world.params["case"] == "exact-post")
		var/savefile/F = new("map_saves/3.sav")
		F["/maxz"] << 4
	return result
/world/OpenPort(port)
	return ..("none")
/proc/dimension_write()
	if(world.params["mode"] == "write3") world.maxz = 3
	var/turf/upper = locate(8, 6, world.maxz)
	upper.name = "saved upper corner"
	var/obj/item/dimension_test/A = new(locate(1, 1, 1))
	A.pair_id = "paid-pair-1"
	A.number = 17
	A.destination = upper
	A.current_area = upper.loc
	var/obj/item/dimension_test/B = new(A)
	B.number = 99
	check(map_storage.Save_World(), "writer save failed")
	check(map_storage.validate_world_save(), "writer generation failed validation")
/proc/dimension_mutate(case_name)
	var/list/R = json_decode(file2text("map_saves/round.json"))
	switch(case_name)
		if("fractional") R["maxz"] = 2.5
		if("negative") R["maxz"] = -1
		if("text") R["maxz"] = "3"
		if("total-cap") R["maxz"] = 33
		if("growth-cap") R["maxz"] = 11
		if("shrink") R["maxz"] = 1
		if("horizontal") R["maxx"] = 9
		if("missing") fdel("map_saves/3.sav")
		if("marker") fdel("map_saves/save_complete.txt")
		if("metadata") R["metadata"] = "invalid digest"
		if("generation", "grid", "reference", "area")
			var/savefile/F = new("map_saves/1.sav")
			if(case_name == "generation") F["/generation"] << "round-v1:other"
			if(case_name == "grid") F["/map/1/1/1"] << null
			if(case_name == "reference" || case_name == "area")
				var/ref = F["/map/1/1/1"]
				var/list/content = map_storage.saved_content_refs(F["[map_storage.entry_path(F, ref)]/content"], F["/format_version"])
				check(content.len == 1, "writer item missing from mutation fixture")
				var/path = map_storage.entry_path(F, text2num(content[1]))
				if(case_name == "reference") F["[path]/destination"] << list("kind" = "turf", "x" = 1, "y" = 1, "z" = 4)
				if(case_name == "area") F["[path]/current_area"] << list("kind" = "area", "type" = /area, "x" = 9, "y" = 1, "z" = 3)
	if(case_name == "json")
		fdel("map_saves/round.json")
		text2file("{", "map_saves/round.json")
	else
		fdel("map_saves/round.json")
		text2file(json_encode(R), "map_saves/round.json")
/proc/dimension_read()
	var/case_name = world.params["case"]
	if(case_name != "positive" && case_name != "matching") dimension_mutate(case_name)
	var/marker = file2text("map_saves/save_complete.txt")
	var/round_hash = md5(file2text("map_saves/round.json"))
	var/turf/original = locate(8, 6, 2)
	original.name = "live sentinel"
	var/obj/item/dimension_test/sentinel = new(original)
	sentinel.number = 77
	var/datum/persistence_world_operation/operation = begin_persistence_operation(map_storage, "load")
	check(operation && operation.current(map_storage, "load"), "dimension import admission failed")
	var/list/intent
	if(case_name == "intent") intent = list("generation" = "round-v1:other", "metadata" = "wrong", "round" = "wrong")
	var/accepted = map_storage.prepare_saved_dimensions(intent)
	check(!map_storage.validation_maxz && !map_storage.dimension_bootstrap_busy, "validation context leaked")
	check(file2text("map_saves/save_complete.txt") == marker && md5(file2text("map_saves/round.json")) == round_hash, "bootstrap changed generation files")
	if(case_name == "allocation-failure" || case_name == "exact-post")
		check(!accepted && world.maxz == 3 && allocation_calls == 1 && map_storage.dimension_recovery_required, "allocation failure did not impose restart latch")
		check(!map_storage.prepare_saved_dimensions() && allocation_calls == 1, "failed allocation retried in process")
		check(operation.finish(FALSE) && !persistence_active_operation && persistence_save_in_progress, "failed allocation lost recovery admission latch")
		check(!map_storage.Save_World() && map_storage.dimension_recovery_required && file2text("map_saves/save_complete.txt") == marker, "failed allocation allowed save overwrite")
		check(locate(8, 6, 2) == original && sentinel.loc == original && sentinel.number == 77, "allocation failure changed mapped world")
		return
	if(case_name != "positive" && case_name != "matching")
		check(!accepted, "malformed save accepted")
		check(world.maxz == 2 && allocation_calls == 0, "rejected save allocated levels")
		check(locate(8, 6, 2) == original && original.name == "live sentinel" && sentinel.loc == original && sentinel.number == 77, "rejected save mutated live world")
		operation.finish(FALSE)
		return
	check(accepted, "bootstrap rejected valid save: [map_storage.last_error]")
	check(world.maxz == (case_name == "matching" ? 2 : 3), "saved dimensions not allocated")
	check(allocation_calls == (case_name == "matching" ? 0 : 1), "allocation count differs")
	if(case_name == "positive") check(istype(locate(8, 6, 3), /turf/sky/building), "shared allocator did not create building sky")
	check(locate(8, 6, 2) == original && sentinel.loc == original, "bootstrap replaced existing map")
	check(map_storage.validate_world_save(), "normal exact validation rejected allocated save")
	check(!map_storage.Load_World() && operation.current(map_storage, "load"), "nested import bypassed dimension operation")
	map_storage.ClearMap()
	check(map_storage.run_world_operation("load", operation), "allocated world import failed")
	var/obj/item/dimension_test/A = locate(/obj/item/dimension_test) in locate(1, 1, 1)
	check(A && A.number == 17 && A.pair_id == "paid-pair-1", "paid parent identity lost")
	var/obj/item/dimension_test/B = locate(/obj/item/dimension_test) in A
	check(B && B.number == 99 && A.contents.len == 1, "paid nested contents lost or duplicated")
	var/turf/upper = locate(8, 6, world.maxz)
	check(upper.name == "saved upper corner" && A.destination == upper && A.current_area == upper.loc, "upper typed references lost")
	check(operation.finish(TRUE) && !persistence_active_operation && !persistence_save_in_progress, "dimension import admission not released")
/world/New()
	OpenPort("none")
	..()
	map_storage = new /map_storage/dimension_fixture("SS13")
	map_storage.record_compiled_dimensions()
	map = new /obj/map_metadata(locate(1, 1, 1))
	ticker = new
	try
		if(world.params["mode"] == "write3" || world.params["mode"] == "write2")
			dimension_write()
		else
			dimension_read()
		text2file("PASS", "result.txt")
	catch(var/exception/e)
		text2file("FAIL: [e]", "result.txt")
	text2file(json_encode(list("checks" = checks, "maxz" = world.maxz, "allocations" = allocation_calls)), "receipt.json")
	shutdown()
