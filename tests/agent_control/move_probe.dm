// Native probe for agent walking (code/modules/agent_control/agent_movement.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/agent_control/move_probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 10
	maxy = 10
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/mob/living/human/move_probe/New()
	return
/mob/living/human/move_probe/update_icons()
	return
/mob/living/human/move_probe/movement_delay()
	return 1
var/move_failures = 0
var/move_runtime_error = FALSE
/proc/move_check(condition, label)
	if (!condition)
		move_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	move_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		move_checks()
	catch(var/exception/e)
		move_check(FALSE, "exception [e] [e.file]:[e.line] [e.desc]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = move_failures, "runtime_error" = move_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/move_try(datum/agent_identity/A, datum/agent_character/C, d, from_queue = TRUE)
	try
		var/list/result = agent_control.agent_walk_step(A, C, d, from_queue)
		return result["moved"] ? "moved" : "blocked"
	catch(var/exception/e)
		return e.desc

/proc/move_checks()
	var/datum/agent_identity/A = new
	A.name = "probe"
	var/mob/living/human/move_probe/H = new(locate(5, 5, 1))
	H.species = new /datum/species/human
	H.stats = list("stamina" = list(100, 100))
	H.canmove = TRUE
	H.stat = CONSCIOUS
	var/datum/agent_character/C = new
	C.body = H
	agent_characters[H] = C
	H.m_intent = "walk"
	H.nutrition = 500
	H.water = 500
	move_check(move_try(A, C, EAST) == "moved" && H.x == 6, "a walking step moves one tile")
	var/walk_cost = C.next_action - world.time
	move_check(abs(walk_cost - (1 + H.get_walk_delay())) < 0.01, "walking costs movement delay plus the walk delay")
	move_check(H.nutrition < 500 && H.water < 500, "walking costs food and water")
	H.m_intent = "run"
	H.velocity = 0
	move_check(move_try(A, C, EAST) == "moved", "a running step moves")
	var/run_cost = C.next_action - world.time
	move_check(run_cost < walk_cost, "running is faster than walking")
	move_check(H.stats["stamina"][1] < 100, "running costs stamina")
	H.stats["stamina"][1] = 0
	move_try(A, C, EAST)
	move_check(H.m_intent == "walk", "an exhausted runner drops to walking")
	H.m_intent = "stealth"
	move_try(A, C, WEST)
	move_check(C.next_action - world.time > walk_cost, "sneaking is slower than walking")
	H.m_intent = "walk"
	H.crouching = TRUE
	move_check(findtext(move_try(A, C, WEST), "crouching"), "a crouching character cannot step")
	H.crouching = FALSE
	var/obj/structure/noose/N = new(get_turf(H))
	N.hanging = H
	move_check(findtext(move_try(A, C, WEST), "noose"), "a hanged character cannot step")
	N.hanging = null
	qdel(N)
	H.pinned = list("a spear")
	move_check(findtext(move_try(A, C, WEST), "pinned"), "a pinned character cannot step")
	H.pinned = list()
	H.prone = TRUE
	move_check(findtext(move_try(A, C, WEST, FALSE), "use_queue") == 1, "crawling runs only from the queue")
	H.prone = FALSE
	var/turf/start = get_turf(H)
	H.drowsyness = 5
	move_try(A, C, NORTH)
	move_check(C.next_action - world.time >= walk_cost + 3, "drowsiness slows a step")
	H.drowsyness = 0
	move_check(get_turf(H) != start, "the drowsy step still moved")
