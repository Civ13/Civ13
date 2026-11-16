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
	var/typed_value
	var/typed_user
	var/amount = 5

/obj/structure/screens_probe/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = TRUE, var/datum/nanoui/master_ui = null, var/datum/topic_state/state = default_state)
	var/list/data = list("amount" = amount)
	ui = GLOB.nanomanager.try_update_ui(user, src, ui_key, ui, data, force_open)
	if (!ui)
		ui = new /datum/nanoui/tgui(user, src, ui_key, "chem_disp.tmpl", "Probe Dispenser", 390, 655)
		ui.set_initial_data(data)
		ui.open()

/obj/structure/screens_probe/ui_actions(ui_key)
	return list("amount", "typed")

/obj/structure/screens_probe/ui_act(action, list/params, mob/user, datum/nanoui/ui)
	if (action != "typed")
		return FALSE
	typed_value = params["value"]
	typed_user = user
	amount = 30
	return TRUE

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
	screen_try(C, list("screen" = 1, "act" = "typed", "value" = 7))
	screens_check(O.typed_value == 7 && O.typed_user == H && O.last_amount == "20", "a typed handler gets the number and the presser, and its Topic is not called")
	rows = agent_screen_rows(H)
	screens_check(rows.len && findtext(rows[1]["data"], "\"amount\":30"), "the screen data refreshes after a typed action")
	screen_try(C, list("screen" = 1, "act" = "typed", "value" = "iron"))
	screens_check(O.typed_value == "iron", "a typed handler gets text as text")
	H.forceMove(locate(1, 1, 1))
	O.forceMove(locate(10, 10, 1))
	var/datum/nanoui/ui = agent_find_screen(H, 1)
	ui.update_status(0)
	screens_check(!agent_open_screens(H).len, "walking away closes the screen")
	H.forceMove(locate(9, 10, 1))
	O.ui_interact(H)
	screens_check(agent_open_screens(H).len == 1, "the screen opens again next to the machine")
	// The page carries its first snapshot, safe inside a script element.
	var/datum/nanoui/tgui/T = agent_find_screen(H, 1)
	T.latest_data = list("amount" = 5, "note" = "</script><b>")
	var/marker = "id=\"tgui-initial\">"
	var/page = T.get_html()
	var/start = findtext(page, marker)
	var/json = copytext(page, start + length(marker), findtext(page, "</script>", start))
	var/list/carried = json_decode(json)
	screens_check(start && !findtext(json, "<") && carried["data"]["note"] == "</script><b>" && carried["config"]["template"] == "chem_disp.tmpl", "the page carries the first snapshot with markup escaped")
	var/pad = "0123456789abcdef"
	while (length(pad) < 300000)
		pad += pad
	T.latest_data = list("pad" = pad)
	page = T.get_html()
	screens_check(findtext(page, "[marker]</script>") && length(page) < 2000, "a snapshot too large for the page is left to the ready push")
	screen_try(C, list("screen" = 1, "close" = TRUE))
	screens_check(!agent_open_screens(H).len, "close closes the screen")
	// A panel window: the safe describes itself and its buttons reach its Topic.
	var/obj/structure/safe/S = new(locate(9, 9, 1))
	var/obj/item/weapon/paper/note = new(S)
	note.name = "deed"
	S.tumbler_1_open = S.tumbler_1_pos
	S.tumbler_2_open = S.tumbler_2_pos
	S.attack_hand(H)
	rows = agent_screen_rows(H)
	screens_check(rows.len == 1 && findtext(rows[1]["data"], "\"Dial\"") && !findtext(rows[1]["data"], "deed") && ("retrieve" in rows[1]["actions"]), "a shut safe shows its dial and not its contents")
	var/dial = S.dial
	screen_try(C, list("screen" = 1, "act" = "increment"))
	rows = agent_screen_rows(H)
	screens_check(S.dial == dial + 1 && findtext(rows[1]["data"], "\"value\":[S.dial * 5]"), "the dial button turns the dial and the panel refreshes")
	screen_try(C, list("screen" = 1, "act" = "open"))
	rows = agent_screen_rows(H)
	screens_check(S.open && findtext(rows[1]["data"], "deed") && findtext(rows[1]["data"], "\ref[note]"), "an opened safe lists its contents with a button each")
	screen_try(C, list("screen" = 1, "act" = "retrieve", "value" = "\ref[note]"))
	rows = agent_screen_rows(H)
	screens_check(note.loc != S && !findtext(rows[1]["data"], "deed"), "taking an item removes it from the safe and the list")
	screen_try(C, list("screen" = 1, "close" = TRUE))
	// A radio set describes its frequency and switches, and a switch reaches the shared radio Topic.
	var/obj/item/weapon/radio/R = new(locate(9, 9, 1))
	R.do_html(H)
	rows = agent_screen_rows(H)
	var/was_on = R.receiver_on
	screens_check(rows.len == 1 && findtext(rows[1]["data"], "\"Frequency\"") && ("receiver" in rows[1]["actions"]), "a radio shows its frequency and switches")
	screen_try(C, list("screen" = 1, "act" = "receiver"))
	rows = agent_screen_rows(H)
	screens_check(R.receiver_on != was_on && findtext(rows[1]["data"], R.receiver_on ? "Turn off" : "Turn on"), "the receiver switch toggles and the panel refreshes")
	screen_try(C, list("screen" = 1, "close" = TRUE))
	// A window chosen by key: the fuel pump asks before a sale is finished.
	var/obj/structure/fuelpump/pump = new(locate(9, 9, 1))
	pump.fueltype = "diesel"
	pump.unlocked = 1
	pump.unlockedvol = 5
	pump.attack_hand(H)
	rows = agent_screen_rows(H)
	screens_check(rows.len == 1 && findtext(rows[1]["data"], "finish_yes") && findtext(rows[1]["data"], "5 units of diesel"), "the fuel pump asks before finishing a sale")
	GLOB.nanomanager.close_user_uis(H, pump)
	var/obj/item/weapon/gun/projectile/dartgun/dart = new(locate(9, 9, 1))
	dart.attack_self(H)
	rows = agent_screen_rows(H)
	screens_check(rows.len == 1 && findtext(rows[1]["data"], "There is no container inserted!"), "an empty dart gun says it has no container")
	GLOB.nanomanager.close_user_uis(H, dart)
	// A gun's laying window stays up for a conscious gunner and closes when they stop using it.
	var/obj/structure/cannon/gun = new(locate(9, 9, 1))
	gun.do_html(H)
	rows = agent_screen_rows(H)
	screens_check(rows.len == 1 && findtext(rows[1]["data"], "FIRE!") && ("distance_10plus" in rows[1]["actions"]), "a cannon shows its laying window")
	H.using_cannon = gun
	H.stop_using_cannon()
	screens_check(!agent_open_screens(H).len, "stopping use of the cannon closes its window")
	var/obj/structure/catapult/sling = new(locate(9, 9, 1))
	sling.do_html(H)
	rows = agent_screen_rows(H)
	screens_check(rows.len == 1 && findtext(rows[1]["data"], "No projectile loaded"), "a catapult shows its window")
	GLOB.nanomanager.close_user_uis(H, sling)
	// A held folder lists its papers; Remove hands one back and the list refreshes.
	var/obj/item/weapon/folder/binder = new(H)
	var/obj/item/weapon/paper/memo = new(binder)
	memo.name = "memo"
	binder.attack_self(H)
	rows = agent_screen_rows(H)
	screens_check(rows.len == 1 && findtext(rows[1]["data"], "memo") && ("rename" in rows[1]["actions"]), "a folder lists its papers with a button each")
	screen_try(C, list("screen" = 1, "act" = "remove", "value" = "\ref[memo]"))
	rows = agent_screen_rows(H)
	screens_check(memo.loc != binder && findtext(rows[1]["data"], "The folder is empty."), "removing a paper takes it out of the folder and the list")
	GLOB.nanomanager.close_user_uis(H, binder)
	var/obj/structure/noticeboard/board = new(locate(9, 9, 1))
	memo.loc = board
	board.notices = 1
	board.examine(H)
	rows = agent_screen_rows(H)
	screens_check(rows.len == 1 && findtext(rows[1]["data"], "memo") && ("write" in rows[1]["actions"]), "a notice board lists its pinned papers")
	screen_try(C, list("screen" = 1, "act" = "remove", "value" = "\ref[memo]"))
	rows = agent_screen_rows(H)
	screens_check(memo.loc != board && findtext(rows[1]["data"], "Nothing is pinned here."), "removing a notice unpins it and the list refreshes")
	GLOB.nanomanager.close_user_uis(H, board)
	var/mob/living/human/screens_probe/P = new(locate(9, 9, 1))
	P.species = new /datum/species/human
	P.stat = CONSCIOUS
	screens_check(!nano_viewer_present(P), "a clientless body that is not an agent is no viewer")
	O.ui_interact(P)
	screens_check(!agent_open_screens(P).len, "no screen opens for it")
