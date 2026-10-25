// Generated source binding. Controller integration must preserve the ready/go protocol.
var/list/winter_assertions = list()
var/exception/winter_assertion_exception
var/winter_phase

/proc/winter_record(condition, message)
	var/list/entry = list("name" = message, "ok" = condition ? 1 : 0)
	winter_assertions += list(entry)
	world.log << "WINTER1688_ASSERT [json_encode(entry)]"
	if (!condition)
		winter_assertion_exception = EXCEPTION(message)
		throw winter_assertion_exception

/proc/winter_binding()
	return list("schema" = 1, "adapter" = "@ADAPTER@", "candidate_manifest_sha256" = "@BINDING@", "version" = "516.1688", "head" = "@HEAD@", "tree" = "@TREE@", "variant" = "@VARIANT@", "phase" = winter_phase, "port" = world.port)

/proc/winter_finish(status, failure)
	var/list/result = winter_binding()
	result["status"] = status
	result["failure"] = failure
	result["assertions"] = winter_assertions
	text2file(json_encode(result), "winter-native-result.json")
	world.log << "WINTER1688_RESULT @VARIANT@:[winter_phase]"

/world/Topic(T, addr, master, key)
	return null

/world/New()
	winter_phase = world.params["winter_phase"]
	try
		if (world.byond_version != 516 || world.byond_build != 1688)
			throw EXCEPTION("Wrong runtime version")
		if (!(winter_phase in list("roundtrip", "writer", "reader")))
			throw EXCEPTION("Unknown winter phase")
		if ("@VARIANT@" != "baseline" && winter_phase != "roundtrip")
			throw EXCEPTION("Mutation phase denied")
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
		switch (winter_phase)
			if ("roundtrip")
				winter_fixture()
				winter_food_roundtrip()
			if ("writer")
				winter_food_writer()
			if ("reader")
				winter_food_reader()
		winter_finish("passed", null)
	catch(var/exception/winter_error)
		if (winter_error == winter_assertion_exception)
			winter_finish("assertion-rejected", "[winter_error]")
		else
			winter_finish("fatal", "[winter_error]")
	del(world)
	return

/world/Error(exception/e, datum/e_src)
	winter_finish("fatal", "[e]")
	del(world)
	return
