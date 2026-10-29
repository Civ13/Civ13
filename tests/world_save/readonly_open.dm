// Windows read-only file compatibility only; not ACL or immutable-host custody.
world
	maxx = 1
	maxy = 1
	maxz = 1
	visibility = 0
	sleep_offline = 0

/world/OpenPort(port)
	return ..("none")

/world/New()
	OpenPort("none")
	..()
	var/role = world.params["role"] == "seed" ? "seed" : "consumer"
	var/result = "PASS"
	var/savefile/reader
	var/value
	try
		reader = new /savefile("selected.sav", 0.1)
		if(!reader.name)
			throw new /exception("READONLY_OPEN_UNAVAILABLE")
		if(role == "seed")
			reader["/value"] << "A"
			reader.Flush()
		else
			reader["/value"] >> value
			if(value != "A")
				throw new /exception("READ_VALUE_MATCH")
	catch(var/exception/open_error)
		result = "UNSUPPORTED: [open_error]"
	reader = null
	var/list/receipt = list("role" = role, "result" = result, "value" = value,
		"byond_version" = world.byond_version, "byond_build" = world.byond_build,
		"host_custody_verified" = 0)
	text2file(json_encode(receipt), "[role].json")
	text2file(result, "[role].result")
	shutdown()
