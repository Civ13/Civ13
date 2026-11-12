// Native probe: a belt placed on a linked line follows the line's switch.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/conveyor_sync/probe.dm
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
/mob/living/human/conveyor_probe/New()
	return
/mob/living/human/conveyor_probe/update_icons()
	return
/mob/living/human/conveyor_probe/incapacitated()
	return FALSE
var/conv_failures = 0
var/conv_runtime_error = FALSE
/proc/conv_check(condition, label)
	if (!condition)
		conv_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	conv_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		conv_check(!world.port, "fixture has no listening port")
		conv_sync_checks()
	catch(var/exception/e)
		conv_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = conv_failures, "runtime_error" = conv_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

// Places a linked belt assembly on (x, y) from a user standing south of it.
/proc/conv_place(x, y, id)
	var/turf/T = locate(x, y, 1)
	var/mob/living/human/conveyor_probe/H = new(locate(x, y - 1, 1))
	var/obj/item/conveyor_construct/A = new(H)
	A.id = id
	A.afterattack(T, H, TRUE)
	qdel(H)
	for (var/obj/machinery/conveyor/C in T)
		return C

/proc/conv_sync_checks()
	var/obj/machinery/conveyor_switch/S = new(locate(1, 1, 1), "line1")
	S.position = 1
	var/obj/machinery/conveyor/C1 = conv_place(3, 3, "line1")
	conv_check(C1 && C1.operating == 1 && C1.movedir == C1.forwards && C1.icon_state == "conveyor1", "a belt placed on a running line runs forward")
	S.position = -1
	var/obj/machinery/conveyor/C2 = conv_place(5, 3, "line1")
	conv_check(C2 && C2.operating == -1 && C2.movedir == C2.backwards, "a belt placed on a reversed line runs backwards")
	S.position = 0
	var/obj/machinery/conveyor/C3 = conv_place(7, 3, "line1")
	conv_check(C3 && C3.operating == 0 && !C3.movedir, "a belt placed on a stopped line stays off")
	var/obj/machinery/conveyor/C4 = conv_place(9, 3, "unlinked")
	conv_check(C4 && C4.operating == 0, "a belt with no switch stays off")
	S.position = 1
	var/obj/machinery/conveyor/old = new(locate(3, 7, 1), WEST)
	old.id = "line1"
	var/turf/T = locate(3, 7, 1)
	var/mob/living/human/conveyor_probe/H = new(locate(3, 6, 1))
	var/obj/item/conveyor_construct/A = new(H)
	A.id = "line1"
	A.afterattack(T, H, TRUE)
	var/obj/machinery/conveyor/corner = null
	for (var/obj/machinery/conveyor/C in T)
		corner = C
	conv_check(corner && corner != old && (corner.dir & (corner.dir - 1)) && corner.operating == 1 && corner.movedir == corner.forwards, "a replacement corner on a running line runs forward")
