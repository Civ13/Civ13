// Native probe: a stopped heart stays stopped without a pulse-adjusting
// drug (#6228), and severe blood loss gives a thready pulse (#6229).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/heart_pulse/probe.dm
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
/obj/map_metadata/hp_probe/New()
	return

var/hp_failures = 0
var/hp_runtime_error = FALSE
/proc/hp_check(condition, label)
	if (!condition)
		hp_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	hp_runtime_error = TRUE
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
		map = new /obj/map_metadata/hp_probe
		hp_pulse_checks()
	catch(var/exception/e)
		hp_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = hp_failures, "runtime_error" = hp_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/hp_pulse(mob/living/human/H, nopulse, chem_pulse)
	var/obj/item/organ/heart/heart = H.internal_organs_by_name["heart"]
	H.life_tick = 5
	H.chem_effects = list()
	if (nopulse)
		H.chem_effects[CE_NOPULSE] = 1
	if (chem_pulse)
		H.chem_effects[CE_PULSE] = chem_pulse
	heart.handle_pulse()
	return heart.pulse

/proc/hp_pulse_checks()
	var/mob/living/human/H = new(locate(5, 5, 1))
	hp_check(istype(H.internal_organs_by_name["heart"], /obj/item/organ/heart), "the patient has a heart")
	hp_check(H.get_blood_volume() >= 100, "the patient starts with full blood")
	hp_check(hp_pulse(H, FALSE, 0) == PULSE_NORM, "a healthy patient has a normal pulse")
	hp_check(hp_pulse(H, FALSE, 1) == PULSE_FAST, "a stimulant still raises a healthy pulse")
	hp_check(hp_pulse(H, TRUE, 0) == PULSE_NONE, "a heart-stopping drug alone leaves no pulse")
	hp_check(hp_pulse(H, TRUE, 2) == PULSE_NORM, "a pulse-adjusting drug can still restart a stopped heart")
	var/full = H.vessel.get_reagent_amount("blood")
	H.vessel.remove_reagent("blood", full / 2)
	hp_check(H.get_blood_volume() <= BLOOD_VOLUME_BAD, "half the blood is severe loss")
	hp_check(hp_pulse(H, FALSE, 0) == PULSE_THREADY, "severe blood loss gives a thready pulse")
	hp_check(hp_pulse(H, FALSE, -1) == PULSE_2FAST, "a pulse-adjusting drug still moves a thready pulse")
