// Production vending machines across a whole-world save/load on a synthetic
// 6x4x1 world. Saved product records are constructed without arguments.
/obj/map_metadata/vending_fixture/New()
	return
/obj/structure/vending/vending_fixture
	products = list(/obj/item/stack/material/wood = 2)
/proc/vending_check(condition, message)
	if(!condition)
		text2file("FAIL: [message]", "vending_result.txt")
		del(world)
		sleep(1)
/world
	hub = ""
	hub_password = ""
	maxx = 6
	maxy = 4
	maxz = 1
	fps = 20
	turf = /turf
/world/Topic(T, addr, master, key)
	return "Vending fixture has no remote operations."
/world/Error(exception/e, datum/e_src)
	world.log << "Runtime error: [e] on [e.file]:[e.line]"
	text2file("FAIL: runtime [e] on [e.file]:[e.line]", "vending_result.txt")
	del(world)
	sleep(1)
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
	map = new /obj/map_metadata/vending_fixture
	map.ID = MAP_NOMADS_CONTINENTAL
	map.persistence = TRUE
	season = "SUMMER"
	var/area/caribbean/nomads/semiarid/base = locate(/area/caribbean/nomads/semiarid)
	if(!base) base = new /area/caribbean/nomads/semiarid
	for(var/turf/T in world)
		ChangeArea(T, base)
		T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	// A player-stocked rack holds the real item; a vendor builds its own list.
	var/obj/structure/vending/craftable/rack = new(locate(2,2,1))
	var/obj/item/stack/material/wood/stocked = new(locate(2,2,1))
	var/datum/data/vending_product/record = new(rack, stocked.type, "fixture planks", 1, 7, null, null, null, stocked)
	rack.product_records += record
	var/obj/structure/vending/vending_fixture/vendor = new(locate(4,2,1))
	sleep(10)
	vending_check(rack.product_records.len == 1 && vendor.product_records.len == 1, "fixture inventories are built ([rack.product_records.len], [vendor.product_records.len])")
	vending_check(map_storage.Save_World(), "production whole-world export succeeds")
	vending_check(map_storage.validate_world_save(), "production preflight accepts the save: [map_storage.last_error]")
	map_storage.ClearMap()
	vending_check(map_storage.Load_World(), "production whole-world import succeeds: [map_storage.last_error]")
	sleep(10)
	rack = locate(/obj/structure/vending/craftable) in locate(2,2,1)
	vendor = locate(/obj/structure/vending/vending_fixture) in locate(4,2,1)
	vending_check(rack && vendor, "vending machines are restored")
	vending_check(rack.product_records.len == 1, "rack keeps one product record ([rack.product_records.len])")
	record = rack.product_records[1]
	vending_check(record.product_name == "fixture planks" && record.price == 7 && record.product_path == /obj/item/stack/material/wood && record.vending_machine == rack, "rack record fields are restored")
	vending_check(record.product_image, "rack record has a listing image after load")
	vending_check(vendor.product_records.len == 1, "vendor inventory is not built a second time on load ([vendor.product_records.len])")
	text2file("PASS: vending product records survive save/load without duplicates", "vending_result.txt")
	del(world)
