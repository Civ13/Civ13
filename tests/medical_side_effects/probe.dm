// Native probe: triggered medical side effects are registered on the patient.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/medical_side_effects/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 5
	maxy = 5
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/mob/living/human/side_effect_probe/New()
	side_effects = list()
	return
/mob/living/human/side_effect_probe/update_icons()
	return
var/se_failures = 0
var/se_runtime_error = FALSE
/proc/se_check(condition, label)
	if (!condition)
		se_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	se_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		se_check(!world.port, "fixture has no listening port")
		var/mob/living/human/side_effect_probe/H = new(locate(2, 2, 1))
		H.life_tick = 30
		H.add_side_effect("Headache", 5)
		var/datum/medical_effect/first = length(H.side_effects) ? H.side_effects[1] : null
		se_check(length(H.side_effects) == 1 && istype(first, /datum/medical_effect/headache) && first.strength == 5 && first.start == 30, "a triggered headache is registered with its strength and start")
		H.life_tick = 45
		H.add_side_effect("Headache")
		se_check(length(H.side_effects) == 1 && first.strength == 10 && first.start == 45, "a repeat trigger refreshes the existing headache")
		H.add_side_effect("Cramps")
		se_check(length(H.side_effects) == 2 && istype(H.side_effects[2], /datum/medical_effect/cramps), "a different effect is registered separately")
		H.add_side_effect("Nonexistent")
		se_check(length(H.side_effects) == 2, "an unknown effect name is ignored")
	catch(var/exception/e)
		se_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = se_failures, "runtime_error" = se_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
