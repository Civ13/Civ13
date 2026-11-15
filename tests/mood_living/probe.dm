// Native probe: living conditions move where mood settles.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/mood_living/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 20
	maxy = 20
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/ml_probe/New()
	return
/mob/living/human/ml_probe/New()
	return
/mob/living/human/ml_probe/update_icons()
	return
/obj/structure/bed/ml_bed/New()
	return
/obj/structure/bed/bedroll/ml_roll/New()
	return
/obj/structure/bed/chair/ml_chair/New()
	return
/obj/item/weapon/bedsheet/ml_sheet/New()
	return

var/ml_failures = 0
var/ml_runtime_error = FALSE
/proc/ml_check(condition, label)
	if (!condition)
		ml_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	ml_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		map = new /obj/map_metadata/ml_probe
		map.nomads = TRUE
		map.civilizations = TRUE
		ml_checks()
	catch(var/exception/e)
		ml_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = ml_failures, "runtime_error" = ml_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

// A bare survivor: a bit dirty, cold, never slept in a bed, poorly fed.
/proc/ml_human(x, y)
	var/mob/living/human/ml_probe/H = new(locate(x, y, 1))
	H.stat = CONSCIOUS
	H.has_hunger_and_thirst = TRUE
	H.species = new /datum/species/human
	H.hygiene = 150
	H.bodytemperature = 290
	H.nutrition = H.max_nutrition
	H.water = H.max_water
	H.diet_reserves = list()
	for (var/group in diet_groups)
		H.diet_reserves[group] = 0
	return H

/proc/ml_rest(mob/living/human/H)
	H.refresh_mood_rest()
	return H.mood_rest

/proc/ml_checks()
	var/mob/living/human/H = ml_human(5, 5)
	ml_check(ml_rest(H) == 50 && !H.mood_rest_parts.len, "a bare survivor rests at neutral ([H.mood_rest] [json_encode(H.mood_rest_parts)])")

	// Each condition on its own.
	H.hygiene = 200
	ml_check(ml_rest(H) == 54 && H.mood_rest_parts["being clean"] == 4, "being clean lifts the resting level")
	H.hygiene = 74
	ml_check(ml_rest(H) == 42 && H.mood_rest_parts["being filthy"] == -8, "being filthy lowers it")
	H.hygiene = 150
	H.has_fleas = TRUE
	ml_check(ml_rest(H) == 45 && H.mood_rest_parts["fleas"] == -5, "fleas lower it")
	H.has_fleas = FALSE
	for (var/i = 1, i <= 2, i++)
		H.diet_reserves[diet_groups[i]] = 100
	ml_check(ml_rest(H) == 50, "two food groups are not a varied diet")
	H.diet_reserves[diet_groups[3]] = 40
	ml_check(ml_rest(H) == 55 && H.mood_rest_parts["a varied diet"] == 5, "three adequate food groups are")
	for (var/group in diet_groups)
		H.diet_reserves[group] = 0
	H.bodytemperature = H.species.body_temperature
	ml_check(ml_rest(H) == 53 && H.mood_rest_parts["being warm and dry"] == 3, "warm and dry lifts it")
	H.cold_wetness = 0.5
	ml_check(ml_rest(H) == 50, "wet clothes are not comfortable")
	H.cold_wetness = 0
	H.bodytemperature = H.species.heat_level_1
	ml_check(ml_rest(H) == 50, "overheating is not comfortable")
	H.bodytemperature = 290
	H.nutrition = H.max_nutrition * 0.25
	ml_check(ml_rest(H) == 42 && H.mood_rest_parts["going hungry"] == -8, "hunger lowers it")
	H.water = H.max_water * 0.2
	ml_check(ml_rest(H) == 34 && H.mood_rest_parts["going thirsty"] == -8, "thirst adds to hunger")
	H.nutrition = H.max_nutrition
	H.water = H.max_water
	H.traumatic_shock = 50
	ml_check(ml_rest(H) == 45 && H.mood_rest_parts["being in pain"] == -5, "lasting pain lowers it")
	H.traumatic_shock = 49
	ml_check(ml_rest(H) == 50, "a passing ache does not")
	H.disease = TRUE
	H.disease_type = "flu"
	ml_check(ml_rest(H) == 42 && H.mood_rest_parts["being sick"] == -8, "illness lowers it")
	H.disease_type = "cholera"
	H.disease_progression = 179
	ml_check(ml_rest(H) == 42, "an early serious illness counts as being sick")
	H.disease_progression = 180
	ml_check(ml_rest(H) == 38 && H.mood_rest_parts["being seriously ill"] == -12 && !("being sick" in H.mood_rest_parts), "a serious illness weighs more")
	H.disease = FALSE
	H.disease_type = "none"
	H.disease_progression = 0

	// Sleep: the bed is noted while asleep and counts after waking.
	var/turf/T = get_turf(H)
	ml_check(ml_rest(H) == 50, "recovered, the survivor rests at neutral again")
	H.inducedSSD = TRUE
	H.sleeping = 66
	var/obj/structure/bed/chair/ml_chair/chair = new(T)
	ml_rest(H)
	ml_check(H.sleep_comfort == 0, "a chair is no bed")
	chair.loc = null
	var/obj/structure/bed/bedroll/ml_roll/roll = new(T)
	ml_rest(H)
	ml_check(H.sleep_comfort == 2, "a bedroll is a simple place to sleep ([H.sleep_comfort])")
	var/obj/item/weapon/bedsheet/ml_sheet/sheet = new(T)
	ml_rest(H)
	ml_check(H.sleep_comfort == 4, "a blanket makes the bedroll comfortable")
	roll.loc = null
	ml_rest(H)
	ml_check(H.sleep_comfort == 0, "a sheet on the bare ground is no bed")
	new /obj/structure/bed/ml_bed(T)
	sheet.loc = null
	ml_rest(H)
	ml_check(H.sleep_comfort == 4, "a proper bed is comfortable")
	sheet.loc = T
	ml_check(ml_rest(H) == 50 && H.sleep_comfort == 6, "a sleeper's resting level waits until they wake")
	H.inducedSSD = FALSE
	H.sleeping = 0
	ml_check(ml_rest(H) == 56 && H.mood_rest_parts["a fine bed with sheets to sleep in"] == 6, "a fine bed counts after waking ([H.mood_rest])")
	H.loc = locate(10, 10, 1)
	ml_check(ml_rest(H) == 56, "and keeps counting away from the bed")

	// Everything good at once stays under the cap; everything bad stays above the floor.
	H.hygiene = 250
	H.bodytemperature = H.species.body_temperature
	for (var/group in diet_groups)
		H.diet_reserves[group] = 100
	ml_check(ml_rest(H) == 68, "bed, diet, washing and warmth together rest at 68 ([H.mood_rest])")
	ml_check(mood_tier(H.mood_rest) == MOOD_TIER_GOOD, "which is a good mood")
	H.mood = 68
	H.mood_drift()
	ml_check(H.mood == 68, "a comfortable character stays there")
	H.sleep_comfort = 0
	H.hygiene = 0
	H.has_fleas = TRUE
	H.nutrition = 0
	H.water = 0
	H.traumatic_shock = 100
	H.disease = TRUE
	H.disease_type = "plague"
	H.disease_progression = 500
	for (var/group in diet_groups)
		H.diet_reserves[group] = 0
	ml_check(ml_rest(H) == 30, "misery is limited to 30 ([H.mood_rest])")

	// Maps without survival needs keep the neutral resting level.
	H.disease = FALSE
	H.has_fleas = FALSE
	H.traumatic_shock = 0
	H.hygiene = 250
	H.sleep_comfort = 6
	map.nomads = FALSE
	map.civilizations = FALSE
	ml_check(ml_rest(H) == 50, "a battle map ignores living conditions ([H.mood_rest] [json_encode(H.mood_rest_parts)])")
