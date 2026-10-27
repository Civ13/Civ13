// Compile-only target: never launch. Startup isolation is generated, not shared.
/world
	hub = ""
	hub_password = ""
	maxx = 1
	maxy = 1
	maxz = 1
	turf = /turf
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/world/New()
	OpenPort("none")
	text2file("Compile target was launched unexpectedly; no tests ran.", "UNEXPECTED_LAUNCH.txt")
	del(world)
