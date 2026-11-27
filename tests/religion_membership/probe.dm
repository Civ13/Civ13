/world
	hub = ""
	hub_password = ""
	maxx = 2
	maxy = 2
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

/obj/map_metadata/four_kingdoms/religion_probe/New()
	return

/mob/living/human/religion_probe
	var/philosophy_coefficient = 3

/mob/living/human/religion_probe/New()
	return

/mob/living/human/religion_probe/getStatCoeff(statname)
	return philosophy_coefficient

/mob/living/human/religion_probe/fully_replace_character_name(oldname, newname)
	name = newname

var/religion_probe_failures = 0
var/religion_probe_runtime_error = FALSE

/proc/religion_probe_check(condition, label)
	if (!condition)
		religion_probe_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"

/world/Error(exception/e)
	religion_probe_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/world/New()
	OpenPort("none")
	try
		religion_probe_run()
	catch(var/exception/e)
		religion_probe_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = religion_probe_failures, "runtime_error" = religion_probe_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/religion_probe_run()
	map = new /obj/map_metadata/four_kingdoms/religion_probe
	// Mirror the Four Kingdoms starter faith without full map startup.
	var/list/starter = list(null, "Production", 14, "Cross", "#FFD700", "#FFFFFF", "Priests")
	map.custom_religions["Father in the Sky"] = starter
	map.custom_religion_nr += "Reserved"
	var/mob/living/human/religion_probe/H = new(locate(1, 1, 1))
	religion_probe_check(map.tribes && !map.nomads && !map.nationsrp && religion_membership_allowed(), "Four Kingdoms admits religion creation and membership")
	H.create_religion_pr("Father in the Sky")
	religion_probe_check(H.religion == "none" && map.custom_religions["Father in the Sky"] == starter && starter[3] == 14, "setup rejects a seeded name without changing the registry")
	religion_probe_check(religion_name_registered("Reserved") && !H.complete_religion_founding("Reserved", "Combat", "Shamans", "Star", "#000000", "#FFFFFF"), "legacy reserved names still block founding")
	religion_probe_check(H.complete_religion_founding("New Creed", "Combat", "Shamans", "Star", "#000000", "#FFFFFF") && H.religion == "New Creed" && H.religious_leader, "an available name can be registered")
	var/mob/living/human/religion_probe/J = new(locate(1, 1, 1))
	religion_probe_check(!J.complete_religion_founding("New Creed", "Production", "Priests", "Cross", "#000000", "#FFFFFF") && J.religion == "none", "name claimed during setup blocks the second founder")
	J.religion = "Father in the Sky"
	J.abandon_religion()
	religion_probe_check(J.religion == "none", "Four Kingdoms lay member can abandon a non-Clerical faith")
	J.religion = "Father in the Sky"
	J.philosophy_coefficient = 1
	J.complete_clergy_join("Father in the Sky")
	religion_probe_check(J.religious_clergy == FALSE, "clergy still enforces the normal skill requirement")
	J.philosophy_coefficient = 3
	J.complete_clergy_join("Father in the Sky")
	religion_probe_check(J.religious_clergy == "Priests", "Four Kingdoms eligible member can join its clergy")
	J.abandon_religion()
	religion_probe_check(J.religion == "Father in the Sky", "clergy cannot abandon")
	var/mob/living/human/religion_probe/K = new(locate(1, 1, 1))
	map.custom_religions["Temple"] = list(null, "Knowledge", 0, "Sun", "#000000", "#FFFFFF", "Clerics")
	K.religion = "Temple"
	K.abandon_religion()
	religion_probe_check(K.religion == "Temple" && K.religious_clergy == FALSE, "registered Clerical religion cannot be abandoned by a lay member")
	K.complete_clergy_join("Father in the Sky")
	religion_probe_check(K.religious_clergy == FALSE, "stale prompt cannot enroll a player in their new faith")
	K.religion = "Unregistered"
	K.complete_clergy_join("Unregistered")
	religion_probe_check(K.religious_clergy == FALSE, "missing religion safely refuses clergy enrollment")
	K.abandon_religion()
	religion_probe_check(K.religion == "none", "missing religion safely permits clearing stale membership")
	map.tribes = FALSE
	K.religion = "Father in the Sky"
	K.abandon_religion()
	religion_probe_check(K.religion == "Father in the Sky", "unsupported maps still block the membership verb")
