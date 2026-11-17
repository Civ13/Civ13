// Native probe of code/modules/client/survival_hints.dm,
// included by tests/ecology_spawning/run_linux.py, never by the game DME.
/world
	hub = ""
	hub_password = ""
	maxx = 5
	maxy = 5
	maxz = 1
	turf = /turf/floor/plating
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/client/New()
	del(src)
	return
/obj/map_metadata/hint_probe/New()
	map = src
/mob/living/human/hint_tester/New()
	return
var/hint_failures = 0
var/hint_runtime_error = FALSE
/proc/hint_check(condition, label)
	if (!condition)
		hint_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	hint_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/datum/species/hint_probe
	cold_level_1 = 260
/world/New()
	OpenPort("none")
	try
		new /obj/map_metadata/hint_probe
		var/mob/living/human/hint_tester/H = new(locate(2, 2, 1))
		H.species = new /datum/species/hint_probe
		H.stat = CONSCIOUS
		H.bodytemperature = 310
		H.nutrition = 300
		H.water = 300
		H.cold_wetness = 0
		H.weakened = 0
		var/list/seen = list()
		hint_check(isnull(H.survival_hint_due(seen)), "a comfortable character gets no hint")
		H.bodytemperature = 250
		hint_check(H.survival_hint_due(seen) == "cold", "a freezing character is told about warmth")
		seen += "cold"
		hint_check(isnull(H.survival_hint_due(seen)), "a hint already seen is not due again")
		H.cold_wetness = 1
		hint_check(H.survival_hint_due(seen) == "soaked", "a soaked character is told to dry off")
		seen += "soaked"
		H.nutrition = 151
		hint_check(isnull(H.survival_hint_due(seen)), "food above a quarter gives no hint")
		H.nutrition = 150
		hint_check(H.survival_hint_due(seen) == "starving", "food down to a quarter gives the food hint")
		seen += "starving"
		H.water = 125
		hint_check(H.survival_hint_due(seen) == "parched", "water down to a quarter gives the water hint")
		seen += "parched"
		H.weakened = 3
		hint_check(H.survival_hint_due(seen) == "knocked_down", "a knocked down character is told they will get up")
		seen += "knocked_down"
		H.stat = UNCONSCIOUS
		seen -= "cold"
		hint_check(isnull(H.survival_hint_due(seen)), "an unconscious character gets no hint")
		var/all_plain = TRUE
		for (var/id in survival_hint_texts)
			if (findtext(id, "&") || findtext(id, "|") || findtext(id, "=") || findtext(id, "{") || findtext(id, "}") || !length(survival_hint_texts[id]))
				all_plain = FALSE
		hint_check(all_plain && survival_hint_texts.len == 7, "every hint has a line and an id safe to save")
	catch(var/exception/e)
		hint_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = hint_failures, "runtime_error" = hint_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
