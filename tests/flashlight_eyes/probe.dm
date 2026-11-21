// Native probe: a flashlight eye exam reports pupil findings for another
// patient, not for yourself, and stops when the patient has no eyes (#6253).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/flashlight_eyes/probe.dm
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
/obj/map_metadata/fe_probe/New()
	return

var/fe_failures = 0
var/fe_runtime_error = FALSE
/proc/fe_check(condition, label)
	if (!condition)
		fe_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	fe_runtime_error = TRUE
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
		map = new /obj/map_metadata/fe_probe
		fe_eye_checks()
	catch(var/exception/e)
		fe_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = fe_failures, "runtime_error" = fe_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

// Messages are read through the agent-character capture hook that
// to_chat_wrapper already calls; the exam itself is production code.
/proc/fe_saw(mob/M, text)
	var/datum/agent_character/AC = agent_characters[M]
	for (var/list/row in AC.messages)
		if (findtext(row["text"], text))
			return TRUE
	return FALSE

/proc/fe_exam(mob/living/human/user, mob/living/human/patient, obj/item/flashlight/F)
	var/datum/agent_character/AC = agent_characters[user]
	AC.messages.Cut()
	user.targeted_organ = "eyes"
	user.next_click = 0
	F.attack(patient, user)

/proc/fe_eye_checks()
	var/mob/living/human/user = new(locate(5, 5, 1))
	var/mob/living/human/patient = new(locate(6, 5, 1))
	var/datum/agent_character/AC = new
	AC.body = user
	agent_characters[user] = AC
	var/obj/item/flashlight/F = new(user)
	F.on = TRUE
	fe_exam(user, patient, F)
	fe_check(fe_saw(user, "pupils"), "examining another patient reports their pupils")
	fe_exam(user, user, F)
	fe_check(!fe_saw(user, "pupils"), "you cannot read your own pupils")
	var/obj/item/organ/eyes = patient.internal_organs_by_name[patient.species.vision_organ]
	patient.internal_organs_by_name -= patient.species.vision_organ
	fe_exam(user, patient, F)
	fe_check(fe_saw(user, "You can't find any") && !fe_saw(user, "pupils"), "a patient without eyes stops the exam safely")
	patient.internal_organs_by_name[patient.species.vision_organ] = eyes
