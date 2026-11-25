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
		conv_switch_assembly_checks()
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


// A normal resolved link must not fall through to the click's placement handler.
/proc/conv_switch_assembly_checks()
	var/mob/living/human/conveyor_probe/H = new(locate(6, 9, 1))
	var/turf/belt_turf = locate(6, 10, 1)
	var/turf/mount_turf = locate(7, 9, 1)
	var/obj/item/conveyor_switch_construct/control = new(H)
	conv_check(control.convdir == 0, "a fresh assembly makes a reversible switch")
	var/obj/item/conveyor_construct/first = new(belt_turf)
	conv_check(control.resolve_attackby(first, H, 0, 0) && first.id == control.id, "a switch assembly links the first belt")
	first.afterattack(belt_turf, H, TRUE)
	var/obj/item/conveyor_construct/second = new(belt_turf)
	var/resolved = control.resolve_attackby(second, H, 0, 0)
	if (!resolved)
		control.afterattack(second, H, TRUE)
	conv_check(resolved && !QDELETED(control) && control.loc == H && second.id == control.id && !(locate(/obj/machinery/conveyor_switch) in belt_turf), "linking a second belt keeps the held switch assembly")
	if (QDELETED(control))
		return
	control.afterattack(mount_turf, H, TRUE)
	var/obj/machinery/conveyor_switch/mounted = locate() in mount_turf
	conv_check(mounted && QDELETED(control), "deliberate placement mounts and consumes the assembly")
	if (!mounted)
		return
	var/obj/machinery/conveyor/B = locate() in belt_turf
	if (!B)
		conv_check(FALSE, "mounted switch has its original linked belt")
		return
	conv_toggle_check(mounted, B, H, 1, -1)
	conv_round_trip(mounted, B, H, 0, 1, -1)
	var/obj/machinery/conveyor_switch/oneway/O = new(locate(8, 9, 1), "forward_test")
	var/obj/machinery/conveyor/F = conv_place(8, 10, O.id)
	conv_round_trip(O, F, H, 1, 1, 1)
	O = new(locate(5, 9, 1), "reverse_test")
	O.convdir = -1
	var/obj/machinery/conveyor/R = conv_place(5, 10, O.id)
	conv_round_trip(O, R, H, -1, -1, -1)

/proc/conv_round_trip(obj/machinery/conveyor_switch/S, obj/machinery/conveyor/B, mob/living/human/H, direction, first, second)
	var/turf/T = get_turf(S)
	var/id = S.id
	var/obj/item/weapon/crowbar/tool = new(H)
	conv_check(tool.resolve_attackby(S, H, 0, 0), "detaching the switch is handled")
	var/obj/item/conveyor_switch_construct/assembly = locate() in T
	conv_check(assembly && assembly.id == id && assembly.convdir == direction, "the detached assembly keeps its line and direction ([direction])")
	if (!assembly || !B)
		return
	assembly.forceMove(H)
	assembly.afterattack(T, H, TRUE)
	var/obj/machinery/conveyor_switch/installed = locate() in T
	conv_check(installed && installed.id == id && istype(installed, /obj/machinery/conveyor_switch/oneway) == !!direction && installed.convdir == direction, "reinstalling the assembly restores its matching type ([direction])")
	if (installed)
		conv_toggle_check(installed, B, H, first, second)
	qdel(tool)

/proc/conv_toggle_check(obj/machinery/conveyor_switch/S, obj/machinery/conveyor/B, mob/living/human/H, first, second)
	S.attack_hand(H)
	S.process()
	conv_check(S.position == first && B.operating == first, "first start uses the configured direction ([first])")
	S.attack_hand(H)
	S.process()
	conv_check(!S.position && !B.operating, "switch stops the line")
	S.attack_hand(H)
	S.process()
	conv_check(S.position == second && B.operating == second, "second start uses the expected direction ([second])")
	S.attack_hand(H)
	S.process()
