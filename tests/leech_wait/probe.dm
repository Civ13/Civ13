// Native probe: leech treatment needs the patient to stay (#6818).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/leech_wait/probe.dm
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
/obj/map_metadata/lw_probe/New()
	return

var/lw_failures = 0
var/lw_runtime_error = FALSE
/proc/lw_check(condition, label)
	if (!condition)
		lw_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	lw_runtime_error = TRUE
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
		map = new /obj/map_metadata/lw_probe
		lw_checks()
	catch(var/exception/e)
		lw_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = lw_failures, "runtime_error" = lw_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)


/proc/lw_checks()
	var/mob/living/human/healer = new(locate(2, 2, 1))
	// Control: a patient who stays put is treated.
	var/mob/living/human/still = new(locate(3, 2, 1))
	var/obj/item/weapon/leech/L = new(healer)
	healer.put_in_active_hand(L)
	lw_check(L.loc == healer, "the healer holds the leech")
	var/blood = still.vessel.get_reagent_amount("blood")
	L.attack(still, healer)
	lw_check(L.fill && still.vessel.get_reagent_amount("blood") < blood, "a still patient is leeched")

	// A patient who walks away interrupts the treatment.
	var/mob/living/human/leaver = new(locate(2, 3, 1))
	var/obj/item/weapon/leech/K = new(healer)
	var/leaver_blood = leaver.vessel.get_reagent_amount("blood")
	spawn(20)
		leaver.forceMove(locate(10, 10, 1))
	K.attack(leaver, healer)
	lw_check(!K.fill, "the leech is not filled when the patient walks away")
	lw_check(leaver.vessel.get_reagent_amount("blood") == leaver_blood, "a patient who walked away keeps their blood")
