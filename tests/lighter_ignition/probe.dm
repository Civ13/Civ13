// Native probe: only a lit lighter can set a fuel-soaked person alight (#6265).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/lighter_ignition/probe.dm
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
/obj/map_metadata/li_probe/New()
	return

var/li_failures = 0
var/li_runtime_error = FALSE
/proc/li_check(condition, label)
	if (!condition)
		li_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	li_runtime_error = TRUE
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
		map = new /obj/map_metadata/li_probe
		li_ignition_checks()
	catch(var/exception/e)
		li_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = li_failures, "runtime_error" = li_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/li_strike(mob/living/human/user, mob/living/human/target, obj/item/weapon/flame/lighter/L)
	target.ExtinguishMob()
	target.fire_stacks = 5
	user.targeted_organ = "chest"
	user.next_click = 0
	L.attack(target, user)
	return target.on_fire

/proc/li_ignition_checks()
	var/mob/living/human/user = new(locate(5, 5, 1))
	var/mob/living/human/target = new(locate(6, 5, 1))
	var/obj/item/weapon/flame/lighter/L = new(user)
	L.lit = FALSE
	li_check(!li_strike(user, target, L), "an unlit lighter with fuel does not ignite a fuel-soaked person")
	L.fuel = 0
	li_check(!li_strike(user, target, L), "an empty unlit lighter does not ignite a fuel-soaked person")
	L.fuel = 100
	L.lit = TRUE
	li_check(li_strike(user, target, L), "a lit lighter still ignites a fuel-soaked person")
	L.lit = FALSE
	processing_objects -= L
