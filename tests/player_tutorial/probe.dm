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

/obj/map_metadata/tutorial_probe_land
	civilizations = TRUE
/obj/map_metadata/tutorial_probe_land/New()
	map = src

/proc/tutorial_probe_run()
	makeDatumRefLists()
	if (!movementMachine)
		movementMachine = new
	var/list/steps = tutorial_active_steps()
	// No map here: the book step and the five survival steps are left out.
	tutorial_probe_check("steps/research_only_with_books", !("research" in steps) && !("fire" in steps) && steps.len == tutorial_step_ids().len - 6)
	var/obj/map_metadata/tutorial_probe_land/land = new
	steps = tutorial_active_steps()
	tutorial_probe_check("steps/survival_where_people_settle", steps.len == tutorial_step_ids().len - 1 && steps.Find("branch") == steps.Find("eat") + 1 && steps.Find("water") == steps.Find("chat") - 1)
	map = null
	qdel(land)
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

	T.begin_step("branch")
	tutorial_probe_check("branch/pending", !T.step_done("branch"))
	T.note_event("branch")
	tutorial_probe_check("branch/done", T.step_done("branch"))

	T.begin_step("twine")
	tutorial_probe_check("twine/pending", !T.step_done("twine"))
	var/obj/item/stack/crude_twine/cord = new(H.loc, 1, FALSE)
	H.put_in_active_hand(cord)
	tutorial_probe_check("twine/done_when_carried", cord.loc == H && T.step_done("twine"))

	var/obj/structure/oven/fireplace/fire = new(locate(H.x + 3, H.y, 1))
	T.begin_step("fire")
	tutorial_probe_check("fire/unlit_and_far_pending", !T.step_done("fire"))
	fire.on = TRUE
	tutorial_probe_check("fire/lit_but_far_pending", !T.step_done("fire"))
	fire.forceMove(locate(H.x + 1, H.y, 1))
	tutorial_probe_check("fire/done_beside_a_lit_fire", T.step_done("fire"))
	fire.on = FALSE
	tutorial_probe_check("fire/unlit_beside_pending", !T.step_done("fire"))

	H.water = 100
	H.nutrition = 100
	T.begin_step("water")
	H.nutrition = 200
	tutorial_probe_check("water/food_alone_pending", !T.step_done("water"))
	H.water = 130
	tutorial_probe_check("water/done", T.step_done("water"))

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
