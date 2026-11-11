// Player tutorial fixture: the real player_tutorial.dm step checks on a small
// world. No client joins; chat links, the screen line and prefs saving are not
// driven. Each step is pending and then done from the state its action leaves.
/world
	hub = ""
	hub_password = ""
	maxx = 20
	maxy = 20
	maxz = 1
	turf = /turf/floor/wood
	area = /area/caribbean
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/world/Topic(T, addr, master, key)
	return "Closed player tutorial fixture"

var/global/list/tutorial_probe_checks = list()
var/global/list/tutorial_probe_failed = list()
var/global/tutorial_probe_runtime_error = FALSE

/world/Error(exception/E)
	tutorial_probe_runtime_error = TRUE
	world.log << "Unexpected fixture runtime: [E] at [E.file]:[E.line]"
	return ..()

/proc/tutorial_probe_check(label, passed)
	tutorial_probe_checks += list(list("label" = label, "passed" = !!passed))
	if (!passed)
		tutorial_probe_failed += label

/proc/tutorial_probe_run()
	makeDatumRefLists()
	if (!movementMachine)
		movementMachine = new
	var/list/steps = tutorial_active_steps()
	tutorial_probe_check("steps/research_only_with_books", !("research" in steps) && steps.len == tutorial_step_ids().len - 1)
	var/all_text = TRUE
	for (var/id in tutorial_step_ids())
		if (!length(tutorial_step_short(id)) || !length(tutorial_step_text(id, null)))
			all_text = FALSE
	tutorial_probe_check("steps/all_have_text", all_text)

	var/turf/start = locate(5, 5, 1)
	var/mob/living/human/H = new(start)
	var/datum/player_tutorial/T = new(null)
	T.body = H

	T.begin_step("move")
	tutorial_probe_check("move/pending", !T.step_done("move"))
	H.forceMove(locate(9, 5, 1))
	tutorial_probe_check("move/done", T.step_done("move"))

	var/obj/item/knife = new /obj/item/weapon/material/kitchen/utensil/knife(H.loc)
	T.begin_step("pick_up")
	tutorial_probe_check("pick_up/pending", !T.step_done("pick_up"))
	H.put_in_active_hand(knife)
	tutorial_probe_check("pick_up/done", T.step_done("pick_up"))

	T.begin_step("swap")
	tutorial_probe_check("swap/pending", !T.step_done("swap"))
	H.swap_hand()
	tutorial_probe_check("swap/done", T.step_done("swap"))

	var/obj/item/hat = new /obj/item/clothing/head/strawhat(H.loc)
	H.put_in_active_hand(hat)
	T.begin_step("stow")
	tutorial_probe_check("stow/pending_while_held", !T.step_done("stow"))
	H.equip_to_slot_if_possible(hat, slot_head)
	tutorial_probe_check("stow/done", H.head == hat && T.step_done("stow"))

	H.a_intent = I_HELP
	T.begin_step("intent")
	tutorial_probe_check("intent/pending", !T.step_done("intent"))
	H.a_intent = I_HARM
	tutorial_probe_check("intent/done", T.step_done("intent"))

	T.begin_step("atlas")
	tutorial_probe_check("atlas/pending", !T.step_done("atlas"))
	T.note_event("chat")
	tutorial_probe_check("atlas/other_event_ignored", !T.step_done("atlas"))
	T.note_event("atlas")
	tutorial_probe_check("atlas/done", T.step_done("atlas"))

	H.nutrition = 100
	T.begin_step("eat")
	H.nutrition = 90
	tutorial_probe_check("eat/hunger_falling_pending", !T.step_done("eat"))
	H.nutrition = 120
	tutorial_probe_check("eat/done", T.step_done("eat"))

	T.begin_step("chat")
	tutorial_probe_check("chat/reading_pending", !T.step_done("chat"))
	T.step_started = world.time - TUTORIAL_READ_TIME
	tutorial_probe_check("chat/read_done", T.step_done("chat"))

	qdel(T)
	tutorial_probe_check("end/clean", QDELETED(T) && !T.body)

/world/New()
	OpenPort("none")
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	tutorial_probe_run()
	text2file(json_encode(list("commit" = world.params["tested_commit"], "check_count" = tutorial_probe_checks.len, "failed_labels" = tutorial_probe_failed, "runtime_error" = tutorial_probe_runtime_error, "checks" = tutorial_probe_checks)), "result.json")
	world.log << "COMPLETE player tutorial fixture"
	del(world)
