world
	sleep_offline = FALSE
	maxx = 32
	maxy = 32
	maxz = 2
	fps = 20
	visibility = 0
var/obj/item/dense/moving_item
var/obj/item/dense/deleted_item
var/mutation_done = FALSE
var/mutation_cancel = FALSE
var/interruption_armed = FALSE
/proc/interruption_signal()
	while(!interruption_armed || fexists("map_saves/save_complete.txt") || map_storage.saving_reference_pins.len < 20)
		sleep(1)
	text2file("READY", "interruption_ready.txt")
var/save_finished = FALSE
var/save_ok = FALSE
/proc/mutate_during_save()
	var/identity = "\ref[moving_item]"
	while(!mutation_cancel && !map_storage.saving_references[identity])
		sleep(1)
	if(mutation_cancel) return
	if(world.params["scenario"] == "parent-deletion")
		var/atom/parent = moving_item.loc
		del(parent)
	else
		new /turf(locate(1,1,1))
		moving_item.loc = locate(world.maxx,world.maxy,2)
		del(deleted_item)
	mutation_done = TRUE
/proc/concurrent_export(datum/controller/gameticker/ticker)
	save_ok = ticker.savemap()
	save_finished = TRUE
var/heartbeat_running = FALSE
var/heartbeat_max = 0
var/heartbeat_count = 0
var/dense_progress_beats = 0
var/first_identity
var/last_identity
/proc/heartbeat()
	var/last = world.timeofday
	while(heartbeat_running)
		sleep(1)
		var/now = world.timeofday
		heartbeat_max = max(heartbeat_max, (now-last+864000)%864000)
		heartbeat_count++
		if(map_storage.saving_references[first_identity] && !map_storage.saving_references[last_identity])
			dense_progress_beats++
		last = now
/obj/item/dense
	var/number = 0
	var/list/payload
/proc/fixture_payload_valid(obj/item/dense/item)
	return islist(item.payload) && item.payload.len == 3 && item.payload["key"] == item.number && item.payload[2] == item.number && item.payload[3] == "literal"
/world/OpenPort(port)
	return ..("none")
/world/New()
	OpenPort("none")
	..()
	try
		if(world.params["large"])
			var/dimension = world.params["dimension"] ? text2num(world.params["dimension"]) : 500
			if(dimension < 2 || dimension > 500 || round(dimension) != dimension) throw EXCEPTION("invalid fixture dimension")
			world.maxx = dimension
			world.maxy = dimension
		map = new /obj/map_metadata(locate(1,1,1))
		if(world.params["recovery"])
			if(world.params["recovery"] == "active")
				if(map_storage.validate_world_save()) throw EXCEPTION("interrupted active save accepted")
			else
				if(!map_storage.validate_world_save() || !map_storage.Load_World()) throw EXCEPTION("completed backup recovery failed")
				var/obj/item/dense/recovered = locate(/obj/item/dense) in locate(1,1,1)
				var/expected = world.params["dense"] ? 20000 : (world.params["large"] ? 10000 : 1000)
				if(!recovered || recovered.number != -1 || recovered.contents.len != expected) throw EXCEPTION("backup graph lost")
				var/list/recovery_seen = list()
				for(var/obj/item/dense/item in recovered)
					TICK_CHECK
					if(recovery_seen["[item.number]"] || item.number < 1 || item.number > expected || (!world.params["dense"] && !fixture_payload_valid(item))) throw EXCEPTION("backup child duplicate or corrupt")
					recovery_seen["[item.number]"] = TRUE
				if(recovery_seen.len != expected) throw EXCEPTION("backup child type or count lost")
				world.log << "BACKUP_RESTORED children=[expected]"
			text2file("PASS", "result.txt")
			del(world)
			return
		if(world.params["interrupt"])
			spawn(0) interruption_signal()
		var/obj/item/dense/box = new(locate(1,1,1))
		box.number = -1
		var/count = world.params["dense"] ? 20000 : (world.params["large"] ? 10000 : 1000)
		for(var/i = 1, i <= count, i++)
			var/obj/item/dense/item = new(box)
			item.number = i
			item.payload = world.params["dense"] ? null : list("key" = i, i, "literal")
			if(i == 1)
				moving_item = item
				first_identity = "\ref[item]"
			if(i == count) last_identity = "\ref[item]"
			if(i == 2) deleted_item = item
		if((world.params["scenario"] == "movement" || world.params["scenario"] == "parent-deletion"))
			spawn(0) mutate_during_save()
		if(world.params["scenario"] == "concurrent")
			var/datum/controller/gameticker/ticker = new
			spawn(0) concurrent_export(ticker)
			sleep(1)
			if(!persistence_save_in_progress || ticker.savemap() || ticker.loadmap()) throw EXCEPTION("concurrent request guard failed")
			while(!save_finished) sleep(1)
			if(!save_ok || persistence_save_in_progress) throw EXCEPTION("save lock not released")
		heartbeat_running = TRUE
		spawn(0) heartbeat()
		sleep(2)
		var/start = world.timeofday
		map_storage.Save_World()
		var/elapsed = (world.timeofday-start+864000)%864000
		if(world.params["bounded"] && world.params["dense"] && dense_progress_beats < 2)
			throw EXCEPTION("dense graph prevented heartbeat progress")
		sleep(2)
		world.log << "SAVE_METRICS first ticks=[elapsed] max_gap=[heartbeat_max] beats=[heartbeat_count]"
		if((world.params["scenario"] == "movement" || world.params["scenario"] == "parent-deletion"))
			mutation_cancel = TRUE
			if(!mutation_done) throw EXCEPTION("movement callback never ran during save")
			if(!map_storage.validate_world_save()) throw EXCEPTION("moving graph invalid")
			map_storage.ClearMap()
			map_storage.Load_World()
			box = locate(/obj/item/dense) in locate(1,1,1)
			var/moving_count = 0
			for(var/obj/item/dense/item in world)
				if(item.number == 1)
					moving_count++
					if(item.loc != box) throw EXCEPTION("captured child changed owner")
			if(moving_count != 1) throw EXCEPTION("moving child duplicated or lost")
			text2file("PASS", "result.txt")
			del(world)
			return
		heartbeat_max = 0
		heartbeat_count = 0
		start = world.timeofday
		if(world.params["verify_backup"]) box.number = -2
		interruption_armed = TRUE
		map_storage.Save_World()
		elapsed = (world.timeofday-start+864000)%864000
		sleep(2)
		world.log << "SAVE_METRICS backup ticks=[elapsed] max_gap=[heartbeat_max] beats=[heartbeat_count]"
		heartbeat_running = FALSE
		if(world.params["benchmark"])
			text2file("PASS", "result.txt")
			del(world)
			return
		if(!map_storage.validate_world_save()) throw EXCEPTION("save preflight failed")
		map_storage.ClearMap()
		if(!map_storage.Load_World()) throw EXCEPTION("load failed")
		box = locate(/obj/item/dense) in locate(1,1,1)
		world.log << "DENSE_RESTORED number=[box ? box.number : null] children=[box ? box.contents.len : null] expected=[count]"
		if(!box || box.number != (world.params["verify_backup"] ? -2 : -1) || box.contents.len != count) throw EXCEPTION("dense contents lost")
		var/list/seen = list()
		for(var/obj/item/dense/item in box)
			if(seen["[item.number]"] || item.number < 1 || item.number > count || (!world.params["dense"] && !fixture_payload_valid(item))) throw EXCEPTION("duplicate or corrupt child")
			seen["[item.number]"] = TRUE
		if(seen.len != count) throw EXCEPTION("active child type or count lost")
		text2file("PASS", "result.txt")
	catch(var/exception/E)
		world.log << "FAIL: [E]"
		text2file("FAIL: [E]", "result.txt")
	del(world)
