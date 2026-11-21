// Native probe: an armed impact grenade blows once in a severe blast, and an empty
// dynamite casing does not (#6298, #6337).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/explosive_activation/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 12
	maxy = 12
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/ea_probe/New()
	return

var/ea_failures = 0
var/ea_runtime_error = FALSE
/proc/ea_check(condition, label)
	if (!condition)
		ea_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	ea_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.name_set_event = new /decl/observ/name_set
		GLOB.stat_set_event = new /decl/observ/stat_set
		makeDatumRefLists()
		movementMachine = new
		map = new /obj/map_metadata/ea_probe
		ea_checks()
	catch(var/exception/e)
		ea_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = ea_failures, "runtime_error" = ea_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/obj/item/weapon/grenade/modern/impact/ea_probe
	var/primes = 0
/obj/item/weapon/grenade/modern/impact/ea_probe/prime()
	primes++

/obj/item/weapon/grenade/dynamite/ea_probe
	var/primes = 0
/obj/item/weapon/grenade/dynamite/ea_probe/prime()
	primes++

/proc/ea_checks()
	var/turf/T = locate(5, 5, 1)
	var/obj/item/weapon/grenade/modern/impact/ea_probe/G = new(T)
	G.active = TRUE
	G.ex_act(1.0)
	ea_check(G.primes == 1, "an armed impact grenade detonates in a severe blast")
	G.ex_act(1.0)
	G.throw_impact(T)
	ea_check(G.primes == 1, "repeated blasts and a throw impact do not detonate it twice")

	var/obj/item/weapon/grenade/modern/impact/ea_probe/H = new(T)
	H.ex_act(2.0)
	H.active = TRUE
	H.ex_act(2.0)
	ea_check(H.primes == 0, "a light blast does not set off an armed impact grenade")

	var/obj/item/weapon/grenade/modern/impact/ea_probe/U = new(T)
	U.ex_act(1.0)
	U.ex_act(1.0)
	sleep(20)
	ea_check(U.primes == 1, "an unarmed impact grenade in a severe blast goes off once")

	var/obj/item/weapon/grenade/dynamite/ea_probe/empty = new(T)
	empty.ex_act(1.0)
	var/obj/item/weapon/grenade/dynamite/ea_probe/filled = new(T)
	filled.state = 1
	filled.ex_act(1.0)
	var/obj/item/weapon/grenade/dynamite/ea_probe/wicked = new(T)
	wicked.state = 2
	wicked.ex_act(1.0)
	sleep(20)
	ea_check(!empty.active && empty.primes == 0, "an empty dynamite casing is not set off by a blast")
	ea_check(filled.primes == 1, "a filled dynamite stick still chains in a blast")
	ea_check(wicked.primes == 1, "an assembled dynamite stick still chains in a blast")
