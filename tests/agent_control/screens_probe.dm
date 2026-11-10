// Native probe for agent machine screens (code/modules/agent_control/agent_screens.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/agent_control/screens_probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 10
	maxy = 10
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/mob/living/human/screens_probe/New()
	return
/mob/living/human/screens_probe/update_icons()
	return
/mob/living/human/screens_probe/movement_delay()
	return 1
var/screens_failures = 0
var/screens_runtime_error = FALSE
/proc/screens_check(condition, label)
	if (!condition)
		screens_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	screens_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		if (!GLOB.nanomanager)
			GLOB.nanomanager = new
		screens_checks()
	catch(var/exception/e)
		screens_check(FALSE, "exception [e] [e.file]:[e.line] [e.desc]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = screens_failures, "runtime_error" = screens_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/obj/structure/screens_probe
	name = "probe dispenser"
	var/last_amount
	var/amount = 5

/obj/structure/screens_probe/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = TRUE, var/datum/nanoui/master_ui = null, var/datum/topic_state/state = default_state)
	var/list/data = list("amount" = amount)
	ui = GLOB.nanomanager.try_update_ui(user, src, ui_key, ui, data, force_open)
	if (!ui)
		ui = new /datum/nanoui/tgui(user, src, ui_key, "chem_disp.tmpl", "Probe Dispenser", 390, 655)
		ui.set_initial_data(data)
		ui.open()

/obj/structure/screens_probe/Topic(href, href_list, state)
	if (href_list["amount"])
		last_amount = href_list["amount"]
		amount = text2num(href_list["amount"])
		return TRUE
	return FALSE

/proc/screen_try(datum/agent_character/C, list/req, from_queue = TRUE)
	try
		return agent_control.agent_screen(C, req, from_queue)
	catch(var/exception/e)
		return e.desc

/proc/screens_checks()
	var/mob/living/human/screens_probe/H = new(locate(5, 5, 1))
	H.species = new /datum/species/human
	H.stat = CONSCIOUS
	H.canmove = TRUE
	var/datum/agent_character/C = new
	C.body = H
	agent_characters[H] = C
	usr = H
	var/obj/structure/screens_probe/O = new(locate(6, 5, 1))
	screens_check(nano_viewer_present(H), "an agent body counts as a UI viewer")
	O.ui_interact(H)
	var/list/rows = agent_screen_rows(H)
	screens_check(rows.len == 1 && rows[1]["status"] == "interactive", "the opened screen is listed and interactive")
	screens_check(rows.len && ("amount" in rows[1]["actions"]) && findtext(rows[1]["data"], "\"amount\":5"), "the screen shows its actions and data")
	screens_check(findtext(screen_try(C, list("screen" = 1, "act" = "amount", "value" = 20), FALSE), "use_queue") == 1, "pressing a button runs from the queue")
	screens_check(findtext(screen_try(C, list("screen" = 1, "act" = "hack")), "bad_args") == 1, "an action the screen does not offer is refused")
	var/detail = screen_try(C, list("screen" = "Probe Dispenser", "act" = "amount", "value" = 20))
	screens_check(O.last_amount == "20" && O.amount == 20, "the button reaches the machine's Topic ([detail])")
	rows = agent_screen_rows(H)
	screens_check(rows.len && findtext(rows[1]["data"], "\"amount\":20"), "the screen data refreshes after the press")
	H.forceMove(locate(1, 1, 1))
	O.forceMove(locate(10, 10, 1))
	var/datum/nanoui/ui = agent_find_screen(H, 1)
	ui.update_status(0)
	screens_check(!agent_open_screens(H).len, "walking away closes the screen")
	H.forceMove(locate(9, 10, 1))
	O.ui_interact(H)
	screens_check(agent_open_screens(H).len == 1, "the screen opens again next to the machine")
	screen_try(C, list("screen" = 1, "close" = TRUE))
	screens_check(!agent_open_screens(H).len, "close closes the screen")
	var/mob/living/human/screens_probe/P = new(locate(9, 9, 1))
	P.species = new /datum/species/human
	P.stat = CONSCIOUS
	screens_check(!nano_viewer_present(P), "a clientless body that is not an agent is no viewer")
	O.ui_interact(P)
	screens_check(!agent_open_screens(P).len, "no screen opens for it")
