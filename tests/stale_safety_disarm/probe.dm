// Native probe: a single-shot rifle's safety blocks firing, and a stale mine disarm
// attempt cannot reach a mine that was moved and re-armed (#6697, #6705).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/stale_safety_disarm/probe.dm 300
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
/obj/map_metadata/sd_probe/New()
	return

var/sd_failures = 0
var/sd_runtime_error = FALSE
/proc/sd_check(condition, label)
	if (!condition)
		sd_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	sd_runtime_error = TRUE
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
		map = new /obj/map_metadata/sd_probe
		sd_checks()
	catch(var/exception/e)
		sd_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = sd_failures, "runtime_error" = sd_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/obj/item/mine/sd_probe
	var/triggers = 0
/obj/item/mine/sd_probe/trigger(atom/movable/AM)
	triggers++

/proc/sd_checks()
	var/mob/living/human/user = new(locate(5, 5, 1))
	var/obj/item/weapon/gun/projectile/boltaction/singleshot/barrett/B = new(user)
	user.put_in_active_hand(B)
	B.bolt_open = FALSE
	B.safetyon = TRUE
	sd_check(!B.special_check(user), "the Barrett will not fire with its safety on")
	B.safetyon = FALSE
	sd_check(B.special_check(user), "the Barrett fires with its safety off and breech closed")
	B.bolt_open = TRUE
	sd_check(!B.special_check(user), "the open-breech guard still holds")
	qdel(B)

	var/obj/item/mine/sd_probe/M = new(locate(6, 5, 1))
	M.anchored = TRUE
	M.arm_generation = 1
	var/obj/item/weapon/wirecutters/W = new(user)
	user.put_in_active_hand(W)
	spawn(0)
		M.attackby(W, user)
	sleep(10)
	// meanwhile someone else disarms it, carries it off and re-arms it elsewhere
	M.anchored = FALSE
	M.forceMove(locate(9, 9, 1))
	M.arm_generation++
	M.anchored = TRUE
	sleep(70)
	sd_check(M.anchored && M.triggers == 0, "a stale disarm attempt leaves the moved, re-armed mine alone (anchored=[M.anchored] triggers=[M.triggers])")
	sd_check(!M.disarm_attempt_valid(1, locate(6, 5, 1)), "an attempt from the earlier arming is no longer valid")
	sd_check(M.disarm_attempt_valid(M.arm_generation, M.loc), "an attempt on the current arming is valid")
