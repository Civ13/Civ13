// Unwatched-world freeze against walkers that are already running (#4197):
// a native walk_rand, a subtile wild walk caught mid-pulse, and resuming once
// someone connects. Run with run_linux.py like probe.dm.
/world
	hub = ""
	hub_password = ""
	maxx = 40
	maxy = 40
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
	fps = 20
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/eco_probe/New()
	return
/mob/living/simple_animal/deer/eco_probe/New()
	return
var/eco_failures = 0
var/eco_runtime_error = FALSE
/proc/eco_check(condition, label)
	if (!condition)
		eco_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	eco_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	spawn(1)
		try
			GLOB.all_observable_events = list()
			GLOB.moved_event = new
			GLOB.dir_set_event = new
			GLOB.destroyed_event = new
			movementMachine = new
			map = new /obj/map_metadata/eco_probe
			for (var/turf/T in block(locate(1, 1, 1), locate(40, 40, 1)))
				T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
			eco_freeze_checks()
		catch(var/exception/e)
			eco_check(FALSE, "exception [e] [e.file]:[e.line]")
		text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = eco_failures, "runtime_error" = eco_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
		del(world)

// What the mob process does each second for a frozen animal.
/proc/eco_freeze_fire(mob/living/simple_animal/A)
	if (ecology_animal_frozen(A))
		A.ecology_hold_still()

/proc/eco_moves_within(mob/living/simple_animal/A, ticks)
	var/list/start = list(A.x, A.y, A.step_x, A.step_y)
	for (var/i = 1, i <= ticks, i++)
		sleep(world.tick_lag)
		if (A.x != start[1] || A.y != start[2] || A.step_x != start[3] || A.step_y != start[4])
			return TRUE
	return FALSE

/proc/eco_freeze_checks()
	ecology_world_unwatched = FALSE
	// Native walker started before the last player left.
	var/mob/living/simple_animal/deer/eco_probe/N = new(locate(20, 20, 1))
	N.npc_subtile_species_walk("random", null, 1)
	eco_check(eco_moves_within(N, 20), "a native walker moves while someone is connected")
	ecology_world_unwatched = TRUE
	eco_freeze_fire(N)
	eco_check(!eco_moves_within(N, 30), "the native walker stops once nobody is connected")
	eco_check(N.npc_subtile_species_walk("random", null, 1) == FALSE && !eco_moves_within(N, 20), "no new native walk starts while nobody is connected")
	ecology_world_unwatched = FALSE
	N.npc_subtile_species_walk("random", null, 1)
	eco_check(eco_moves_within(N, 20), "the native walker starts again after a reconnect")
	walk(N, 0)

	// Subtile wild walker, frozen in the middle of a pulse.
	var/mob/living/simple_animal/deer/eco_probe/S = new(locate(10, 10, 1))
	S.npc_subtile_species_enabled = TRUE
	eco_check(S.set_npc_subtile(TRUE), "the probe deer takes subtile movement")
	S.npc_subtile_species_walk("random", null, 4)
	var/caught = FALSE
	for (var/i = 1, i <= 80 && !caught, i++)
		sleep(world.tick_lag)
		caught = !!S.npc_subtile_transaction
	eco_check(S.npc_subtile_wild_walk && caught, "a subtile wild walk is mid-pulse")
	ecology_world_unwatched = TRUE
	eco_freeze_fire(S)
	eco_check(!S.npc_subtile_wild_walk && !S.npc_subtile_pending_intent, "freezing cancels the wild walk and its pending intent")
	// The pulse ends through its own transaction; the deer may rest between
	// tiles as any stopped walker does, and the next walk aligns it first.
	for (var/i = 1, i <= 40 && (S.npc_subtile_transaction || S.npc_subtile_pulse || world.time < S.npc_subtile_until), i++)
		sleep(world.tick_lag)
	eco_check(!S.npc_subtile_transaction && !S.npc_subtile_pulse && world.time >= S.npc_subtile_until, "the in-flight pulse finishes through its own transaction")
	eco_freeze_fire(S)
	eco_check(!eco_moves_within(S, 40), "the subtile walker stays still while nobody is connected")
	var/turf/next = get_step(S, NORTH)
	eco_check(!S.ai_step(next, 4), "ai_step refuses while nobody is connected")
	ecology_world_unwatched = FALSE
	S.npc_subtile_species_walk("random", null, 4)
	eco_check(eco_moves_within(S, 60), "the subtile walker moves again after a reconnect")
	S.npc_subtile_stop_continuous_walk()
