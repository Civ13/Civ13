// Generated source binding. Controller integration must preserve the ready/go protocol.
var/list/discovery_assertions = list()
var/exception/discovery_assertion_exception
var/discovery_phase

/proc/discovery_record(condition, message)
	var/list/entry = list("name" = message, "ok" = condition ? 1 : 0)
	discovery_assertions += list(entry)
	world.log << "DISCOVERY1688_ASSERT [json_encode(entry)]"
	if (!condition)
		discovery_assertion_exception = EXCEPTION(message)
		throw discovery_assertion_exception

/proc/discovery_binding()
	return list("schema" = 1, "adapter" = "@ADAPTER@", "candidate_manifest_sha256" = "@BINDING@", "version" = "516.1688", "head" = "@HEAD@", "tree" = "@TREE@", "variant" = "@VARIANT@", "phase" = discovery_phase, "port" = world.port)

/proc/discovery_finish(status, failure)
	var/list/result = discovery_binding()
	result["status"] = status
	result["failure"] = failure
	result["assertions"] = discovery_assertions
	text2file(json_encode(result), "discovery-native-result.json")
	world.log << "DISCOVERY1688_RESULT @VARIANT@:[discovery_phase]"

/world/Topic(T, addr, master, key)
	return null

/world/New()
	discovery_phase = world.params["discovery_phase"]
	try
		if (world.byond_version != 516 || world.byond_build != 1688)
			throw EXCEPTION("Wrong runtime version")
		if (!(discovery_phase in list("roundtrip", "writer", "reader")))
			throw EXCEPTION("Unknown discovery phase")
		if ("@VARIANT@" != "baseline" && discovery_phase != "roundtrip")
			throw EXCEPTION("Mutation phase denied")
		world.OpenPort("none")
		if (world.port)
			throw EXCEPTION("Fixture port did not close")
		text2file(json_encode(discovery_binding()), "discovery-native-ready.json")
		var/ack_waits = 0
		while (!fexists("discovery-native-go.txt") && ack_waits < 100)
			sleep(1)
			ack_waits++
		if (trim(file2text("discovery-native-go.txt")) != "@BINDING@:@VARIANT@:[discovery_phase]")
			throw EXCEPTION("Missing owned-listener acknowledgement")
		discovery_setup()
		switch (discovery_phase)
			if ("roundtrip")
				discovery_fixture()
				discovery_mind_roundtrip()
			if ("writer")
				discovery_mind_writer()
			if ("reader")
				discovery_mind_reader()
		discovery_finish("passed", null)
	catch(var/exception/discovery_error)
		if (discovery_error == discovery_assertion_exception)
			discovery_finish("assertion-rejected", "[discovery_error]")
		else
			discovery_finish("fatal", "[discovery_error]")
	del(world)
	return

/world/Error(exception/e, datum/e_src)
	discovery_finish("fatal", "[e]")
	del(world)
	return
