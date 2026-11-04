// Production roof, support and persistence code on a synthetic 12x8x2 world.
// Roofs must still find their supports after Save_World, ClearMap and Load_World.
/obj/map_metadata/roof_support_fixture/New()
	return
/proc/roof_load_check(condition, message)
	if(!condition)
		text2file("FAIL: [message]", "roof_result.txt")
		del(world)
		sleep(1)
/world
	hub = ""
	hub_password = ""
	maxx = 12
	maxy = 8
	maxz = 2
	fps = 20
	turf = /turf
/world/Topic(T, addr, master, key)
	return "Roof fixture has no remote operations."
/world/Error(exception/e, datum/e_src)
	world.log << "Runtime error: [e] on [e.file]:[e.line]"
	text2file("FAIL: runtime [e] on [e.file]:[e.line]", "roof_result.txt")
	del(world)
	sleep(1)
/proc/roof_load_roofs()
	var/list/result = list()
	for(var/obj/roof/R in world)
		if(!isturf(R.loc) || R.gcDestroyed)
			continue
		result["[R.x],[R.y],[R.z]"] = R
	return result
/world/New()
	generate_gameid()
	if(config)
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	map = new /obj/map_metadata/roof_support_fixture
	map.ID = MAP_NOMADS_CONTINENTAL
	season = "SUMMER"
	var/area/caribbean/nomads/semiarid/base = locate(/area/caribbean/nomads/semiarid)
	if(!base) base = new /area/caribbean/nomads/semiarid
	for(var/turf/T in world)
		ChangeArea(T, base)
		T.ChangeTurf(T.z == 1 ? /turf/floor/dirt : /turf/sky/building, FALSE, FALSE)
	// Each supported roof sits at the edge of its support's reach.
	new /obj/structure/roof_support(locate(2,2,1))
	var/obj/roof/plain = new /obj/roof/wood(locate(2,5,1))
	new /obj/structure/mine_support/stone(locate(6,2,1))
	new /obj/roof/wood(locate(6,4,1))
	new /obj/covers/wood_wall(locate(10,2,1))
	new /obj/roof/wood(locate(10,3,1))
	// Constructed roofs are paired with an upper floor on the open level above.
	new /obj/structure/roof_support(locate(2,7,1))
	var/obj/roof/paired = building_construct_roof(locate(5,7,1), /obj/roof/wood, null, null)
	roof_load_check(paired && paired.building_pair_id && paired.building_floor(), "constructed roof pairs with an upper floor")
	roof_load_check(plain && !plain.building_pair_id, "plain roof is unpaired")
	// Roof read before its support in turf order, and a second storey on a paired floor.
	new /obj/roof/wood(locate(8,5,1))
	new /obj/structure/roof_support(locate(8,8,1))
	new /obj/structure/roof_support(locate(11,8,1))
	var/obj/roof/lower = building_construct_roof(locate(11,7,1), /obj/roof/wood, null, null)
	roof_load_check(lower && lower.building_floor(), "lower storey pairs")
	new /obj/structure/roof_support(locate(11,7,2))
	new /obj/roof/wood(locate(11,5,2))
	roof_load_check(building_supported_height(locate(11,5,2)) == 2, "second storey is supported through the paired floor ([building_supported_height(locate(11,5,2))])")
	var/list/before = roof_load_roofs()
	sleep(60)
	var/list/settled = roof_load_roofs()
	roof_load_check(settled.len == before.len, "supported roofs stand before saving ([settled.len]/[before.len])")
	// Saved without any support: its constructor check is still pending.
	new /obj/roof/wood(locate(12,1,1))
	roof_load_check(map_storage.Save_World(), "production whole-world export succeeds")
	roof_load_check(map_storage.validate_world_save(), "production preflight accepts roof save: [map_storage.last_error]")
	map_storage.ClearMap()
	roof_load_check(map_storage.Load_World(), "production whole-world import succeeds: [map_storage.last_error]")
	var/list/loaded = roof_load_roofs()
	roof_load_check(loaded.len == before.len + 1, "every roof is restored ([loaded.len]/[before.len + 1])")
	sleep(80)
	var/list/after = roof_load_roofs()
	roof_load_check(!after["12,1,1"], "unsupported restored roof collapses")
	for(var/key in before)
		roof_load_check(after[key], "restored roof at [key] recognizes its support")
	var/obj/roof/restored = after["5,7,1"]
	roof_load_check(restored.building_pair_id && restored.building_floor(), "restored constructed roof keeps its upper floor")
	roof_load_check(!building_roof_error(locate(2,4,1)), "a new roof next to a restored support is buildable: [building_roof_error(locate(2,4,1))]")
	roof_view_check()
	text2file("PASS: restored roofs keep their supports and reconnecting players see them", "roof_result.txt")
	del(world)

// A restored body carries roofs_removed = FALSE from the client it had at save
// time. A reconnecting client's image list is empty and must get the roofs.
/proc/roof_view_check()
	makeDatumRefLists()
	var/mob/living/human/H = new(locate(1,8,1))
	var/datum/old_viewer = new
	var/list/old_images = list()
	H.sync_static_roofs(old_viewer, old_images, FALSE)
	roof_load_check(old_images.len == roofs_list.len && roofs_list.len >= 7, "outdoor viewer sees every roof ([old_images.len]/[roofs_list.len])")
	H.roofs_removed = FALSE // as restored from a save made while outdoors
	var/datum/new_viewer = new
	var/list/new_images = list()
	H.sync_static_roofs(new_viewer, new_images, FALSE)
	roof_load_check(new_images.len == roofs_list.len, "reconnected viewer outdoors sees restored roofs ([new_images.len]/[roofs_list.len])")
	H.sync_static_roofs(new_viewer, new_images, TRUE)
	roof_load_check(!new_images.len, "indoor viewer hides every roof")
	H.sync_static_roofs(new_viewer, new_images, TRUE)
	roof_load_check(!new_images.len, "staying indoors never re-adds roofs")
	var/list/indoor_images = list()
	H.roofs_removed = FALSE
	H.sync_static_roofs(new /datum, indoor_images, TRUE)
	roof_load_check(!indoor_images.len, "reconnected viewer indoors gets no roofs")
	roof_load_check(H.persistence_runtime_var("roofs_removed") && H.persistence_runtime_var("roofs_client"), "roof view state is not saved")
