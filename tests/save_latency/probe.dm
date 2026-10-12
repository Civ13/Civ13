world
	sleep_offline = FALSE
	maxx = 32
	maxy = 32
	maxz = 2
	fps = 20
	visibility = 0
var/heartbeat_running = FALSE
var/heartbeat_max = 0
var/heartbeat_count = 0
/proc/heartbeat()
	var/last = world.timeofday
	while(heartbeat_running)
		sleep(1)
		var/now = world.timeofday
		heartbeat_max = max(heartbeat_max, (now-last+864000)%864000)
		heartbeat_count++
		last = now
/obj/item/dense
	var/number = 0
	var/list/payload
/world/OpenPort(port)
	return ..("none")
/world/New()
	OpenPort("none")
	..()
	try
		if(world.params["large"])
			world.maxx = 500
			world.maxy = 500
		map = new /obj/map_metadata(locate(1,1,1))
		var/obj/item/dense/box = new(locate(1,1,1))
		box.number = -1
		var/count = world.params["large"] ? 10000 : 1000
		for(var/i = 1, i <= count, i++)
			var/obj/item/dense/item = new(box)
			item.number = i
			item.payload = list("key" = i, i, "literal")
		heartbeat_running = TRUE
		spawn(0) heartbeat()
		sleep(2)
		var/start = world.timeofday
		map_storage.Save_World()
		var/elapsed = (world.timeofday-start+864000)%864000
		sleep(2)
		world.log << "SAVE_METRICS first ticks=[elapsed] max_gap=[heartbeat_max] beats=[heartbeat_count]"
		heartbeat_max = 0
		heartbeat_count = 0
		start = world.timeofday
		map_storage.Save_World()
		elapsed = (world.timeofday-start+864000)%864000
		sleep(2)
		world.log << "SAVE_METRICS backup ticks=[elapsed] max_gap=[heartbeat_max] beats=[heartbeat_count]"
		heartbeat_running = FALSE
		if(!map_storage.validate_world_save()) throw EXCEPTION("save preflight failed")
		map_storage.ClearMap()
		if(!map_storage.Load_World()) throw EXCEPTION("load failed")
		box = locate(/obj/item/dense) in locate(1,1,1)
		if(!box || box.number != -1 || box.contents.len != count) throw EXCEPTION("dense contents lost")
		var/list/seen = list()
		for(var/obj/item/dense/item in box)
			if(seen["[item.number]"] || item.payload["key"] != item.number) throw EXCEPTION("duplicate or corrupt child")
			seen["[item.number]"] = TRUE
		text2file("PASS", "result.txt")
	catch(var/exception/E)
		world.log << "FAIL: [E]"
		text2file("FAIL: [E]", "result.txt")
	del(world)
