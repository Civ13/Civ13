// Source-bound, inactive two-process observation wrapper; oracle owns verdicts.
var/winter_phase
/proc/winter_binding()
	return list("schema" = 1, "adapter" = "@ADAPTER@", "candidate_manifest_sha256" = "@BINDING@", "version" = "516.1688", "head" = "@HEAD@", "tree" = "@TREE@", "variant" = "@VARIANT@", "phase" = winter_phase, "port" = world.port)

/proc/winter_finish(status, failure)
	var/list/result = winter_binding()
	result["status"] = status
	result["failure"] = failure
	result["tick_lag"] = world.tick_lag
	result["fps"] = world.fps
	result["map_type"] = map ? "[map.type]" : null
	result["map_id"] = map ? map.ID : null
	result["round_version"] = "round-v1"
	result["observations"] = winter_observations
	result["poll_max_gap"] = winter_poll_max_gap
	result["origin_tick"] = winter_origin_tick
	result["setup_started_tick"] = winter_setup_started_tick
	result["save_started_tick"] = winter_save_started_tick
	result["save_finished_tick"] = winter_save_finished_tick
	result["load_started_tick"] = winter_load_started_tick
	result["load_finished_tick"] = winter_load_finished_tick
	result["writer_saved_snapshot"] = winter_saved_snapshot
	text2file(json_encode(result), "winter-native-result.json")
	world.log << "GROWTH1688_RESULT @VARIANT@:[winter_phase]"

/world/Topic(T, addr, master, key)
	return null
/world/New()
	winter_phase = world.params["winter_phase"]
	try
		if (world.byond_version != 516 || world.byond_build != 1688)
			throw EXCEPTION("Wrong runtime version")
		if (!(winter_phase in list("writer", "reader")) || "@VARIANT@" != "baseline")
			throw EXCEPTION("Unknown growth phase or variant")
		world.OpenPort("none")
		if (world.port)
			throw EXCEPTION("Fixture port did not close")
		text2file(json_encode(winter_binding()), "winter-native-ready.json")
		var/ack_waits = 0
		while (!fexists("winter-native-go.txt") && ack_waits < 100)
			sleep(1)
			ack_waits++
		if (trim(file2text("winter-native-go.txt")) != "@BINDING@:@VARIANT@:[winter_phase]")
			throw EXCEPTION("Missing owned-listener acknowledgement")
		winter_setup()
		if (winter_phase == "writer")
			winter_food_writer()
		else
			winter_food_reader()
		winter_finish("observed", null)
	catch(var/exception/E)
		world.log << "GROWTH1688_FATAL [E]"
		winter_finish("fatal", "[E]")
	del(world)
	return
/world/Error(exception/E, datum/e_src)
	world.log << "GROWTH1688_FATAL [E]"
	winter_finish("fatal", "[E]")
	del(world)
	return
