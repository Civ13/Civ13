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
	board.examine(H)
	rows = agent_screen_rows(H)
	screens_check(rows.len == 1 && findtext(rows[1]["data"], "memo") && ("read" in rows[1]["actions"]) && !("write" in rows[1]["actions"]), "a notice board lists read-only pinned papers")
	board.board_glass = TRUE
	board.board_glass_closed = TRUE
	board.noticeboard_refresh()
	rows = agent_screen_rows(H)
	screens_check(rows.len == 1 && findtext(rows[1]["data"], "Glass closed") && ("read" in rows[1]["actions"]), "closed glass leaves posted papers readable")
	screen_try(C, list("screen" = 1, "act" = "remove", "value" = "\ref[memo]"))
	screens_check(memo.loc == board, "closed glass refuses stale removal")
	board.board_glass_closed = FALSE
	board.noticeboard_refresh()
	screen_try(C, list("screen" = 1, "act" = "remove", "value" = "\ref[memo]"))
	rows = agent_screen_rows(H)
	screens_check(memo.loc != board && findtext(rows[1]["data"], "Nothing is pinned here."), "removing a notice unpins it and the list refreshes")
	GLOB.nanomanager.close_user_uis(H, board)
	// The pill maker: amount buttons carry the reagent id, and analysis looks the reagent up on the server.
	var/obj/structure/chem_master/mixer = new(locate(9, 9, 1))
	mixer.anchored = TRUE
	var/obj/item/weapon/reagent_containers/glass/beaker/jar = new(mixer)
	jar.reagents.add_reagent("water", 30)
	mixer.beaker = jar
	mixer.attack_hand(H)
	rows = agent_screen_rows(H)
	screens_check(rows.len == 1 && findtext(rows[1]["data"], "Add to buffer") && ("add_5" in rows[1]["actions"]), "the pill maker lists the beaker's reagents with amount buttons")
	screen_try(C, list("screen" = 1, "act" = "add_5", "value" = "water"))
	screens_check(mixer.reagents.get_reagent_amount("water") == 5 && jar.reagents.get_reagent_amount("water") == 25, "an amount button moves that much into the buffer")
	screen_try(C, list("screen" = 1, "act" = "analyze", "value" = "water"))
	rows = agent_screen_rows(H)
	screens_check(findtext(rows[1]["data"], "\"Description\"") && !findtext(rows[1]["data"], "Add to buffer"), "analysis shows the reagent's own description")
	screen_try(C, list("screen" = 1, "act" = "main"))
	screen_try(C, list("screen" = 1, "act" = "pill_sprite", "value" = 99))
	screens_check(mixer.pillsprite == "1", "a pill style outside the list is refused")
	screen_try(C, list("screen" = 1, "act" = "pill_sprite", "value" = 7))
	rows = agent_screen_rows(H)
	screens_check(mixer.pillsprite == "7" && findtext(rows[1]["data"], "pill7.png"), "a listed pill style is taken and shown")
	GLOB.nanomanager.close_user_uis(H, mixer)
	// The stock market: a form sends its fields, and the members window is keyed by company.
	var/obj/structure/stockmarket/exchange = new(locate(9, 9, 1))
	var/made_map = !map
	if (made_map)
		map = new /obj/map_metadata(locate(1, 1, 1))
	map.custom_company_nr += "Probe & Sons"
	map.custom_company["Probe & Sons"] = list(list(H, 100, 0))
	map.custom_company_value["Probe & Sons"] = 0
	var/company_index = map.custom_company_nr.Find("Probe & Sons")
	exchange.attack_hand(H)
	rows = agent_screen_rows(H)
	screens_check(rows.len == 1 && findtext(rows[1]["data"], "you own 100%") && ("sell" in rows[1]["actions"]), "the stock market offers a sell form for an owned company")
	var/listed = map.sales_registry.len
	screen_try(C, list("screen" = 1, "act" = "sell", "value" = company_index, "amt" = 40, "price" = 20, "cur" = "standard"))
	rows = agent_screen_rows(H)
	screens_check(map.sales_registry.len == listed + 1 && findtext(rows[1]["data"], "40% of Probe"), "the sell form lists the stake and the window refreshes")
	screen_try(C, list("screen" = 1, "act" = "sell", "value" = company_index, "amt" = 40, "price" = 20, "cur" = "no_such_currency"))
	screens_check(map.sales_registry.len == listed + 1, "an unknown currency is refused")
	screen_try(C, list("screen" = 1, "act" = "viewmembers", "value" = company_index))
	screens_check(GLOB.nanomanager.get_open_ui(H, exchange, "members_[company_index]") != null, "the members window opens for that company")
	GLOB.nanomanager.close_user_uis(H, exchange)
	// A supply stall: its forms set the order, and only a real currency is accepted.
	var/obj/structure/supplier/stall = new(locate(9, 9, 1))
	stall.owner = "Probe & Sons"
	stall.invisibility = 0 // a new stall stays hidden until its colours are painted
	stall.attack_hand(H)
	rows = agent_screen_rows(H)
	screens_check(rows.len == 1 && findtext(rows[1]["data"], "No active buy order") && ("changeprice" in rows[1]["actions"]), "a company member opens the supply stall")
	screen_try(C, list("screen" = 1, "act" = "changeprice", "value" = 12))
	screen_try(C, list("screen" = 1, "act" = "changeamount", "value" = 30))
	screen_try(C, list("screen" = 1, "act" = "rename", "value" = "<b>Probe</b> stall"))
	screen_try(C, list("screen" = 1, "act" = "changecurrency", "value" = "no_such_currency"))
	screens_check(stall.orderprice == 12 && stall.orderamount == 30 && stall.accepted_currency == "standard", "the stall's forms set the order and refuse an unknown currency")
	screens_check(!findtext(stall.name, "<") && findtext(stall.name, "Probe"), "a new stall name is stored without markup")
	GLOB.nanomanager.close_user_uis(H, stall)
	qdel(stall)
	// A company vendor's management window has its own actions beside the purchase window's.
	var/obj/structure/vending/sales/shop = new(locate(9, 9, 1))
	shop.owner = "Probe & Sons"
	shop.show_management_ui(H)
	rows = agent_screen_rows(H)
	screens_check(rows.len == 1 && findtext(rows[1]["data"], "No products in this vendor") && ("changecurrency" in rows[1]["actions"]) && !("vend" in rows[1]["actions"]), "a company member opens the vendor's management window")
	screen_try(C, list("screen" = 1, "act" = "rename", "value" = "<i>Probe</i> shop"))
	screen_try(C, list("screen" = 1, "act" = "changecurrency", "value" = "no_such_currency"))
	screen_try(C, list("screen" = 1, "act" = "removeproduct", "value" = 3))
	screens_check(!findtext(shop.name, "<") && findtext(shop.name, "Probe") && shop.accepted_currency == "standard", "the vendor is renamed without markup and refuses an unknown currency")
	GLOB.nanomanager.close_user_uis(H, shop)
	qdel(shop)
	map.sales_registry.Cut(listed + 1)
	map.custom_company_nr -= "Probe & Sons"
	map.custom_company -= "Probe & Sons"
	map.custom_company_value -= "Probe & Sons"
	// A trader: the shop lists its goods, a purchase takes the held money, and a busy trader closes the shop.
	var/mob/living/simple_animal/npc_vendor/walter/trader = new(locate(9, 9, 1))
	trader.walter_cooldown = -1 // the probe runs at world.time 0
	var/obj/item/stack/money/dollar/cash = new(H.loc)
	cash.amount = 500
	H.drop_item()
	H.put_in_active_hand(cash)
	// The gunsmithing bench: only the step the design is on, and only a part it offers, is accepted.
	var/obj/structure/gunbench/bench = new(locate(9, 9, 1))
	bench.attack_hand(H)
	rows = agent_screen_rows(H)
	screens_check(rows.len == 1 && findtext(rows[1]["data"], "Start New Gun") && ("step1" in rows[1]["actions"]), "the gunsmithing bench opens with money in hand")
	screen_try(C, list("screen" = 1, "act" = "start"))
	screens_check(bench.current_gun && findtext(agent_screen_rows(H)[1]["data"], "Step 1: Choose Stock"), "starting a gun shows the first step")
	screen_try(C, list("screen" = 1, "act" = "step2", "value" = "Bolt-Action"))
	screen_try(C, list("screen" = 1, "act" = "step1", "value" = "Golden Stock"))
	screen_try(C, list("screen" = 1, "act" = "name", "value" = "free gun"))
	screens_check(bench.current_gun && bench.current_gun.receiver_type == "none" && bench.current_gun.stock_type == "none" && cash.amount == 500, "a step out of order, an unknown part and an early finish are refused")
	screen_try(C, list("screen" = 1, "act" = "cancel"))
	screens_check(!bench.current_gun && !agent_screen_rows(H).len, "cancelling drops the design and closes the bench")
	qdel(bench)
	trader.attack_hand(H)
	rows = agent_screen_rows(H)
	screens_check(rows.len == 1 && findtext(rows[1]["data"], "Supplies") && findtext(rows[1]["data"], "$100") && ("buy" in rows[1]["actions"]), "a trader's shop lists goods with prices")
	screen_try(C, list("screen" = 1, "act" = "buy", "value" = 99))
	screens_check(cash.amount == 500 && agent_screen_rows(H).len == 1, "a product the trader does not sell is refused")
	screen_try(C, list("screen" = 1, "act" = "buy", "value" = 1))
	screens_check(cash.amount == 480 && trader.walter_cooldown > world.time, "buying takes the money held in hand")
	screens_check(!agent_screen_rows(H).len, "a trader who is busy closes the shop")
	H.drop_from_inventory(cash)
	qdel(cash)
	qdel(trader)
	if (made_map)
		qdel(map)
		map = null
	// Read-only report windows: a table section and a chart section reach the panel.
	var/obj/structure/factory_monitor/monitor = new(locate(9, 9, 1))
	monitor.attack_hand(H)
	rows = agent_screen_rows(H)
	screens_check(rows.len == 1 && findtext(rows[1]["data"], "No factory machines") && findtext(rows[1]["data"], "Pipe networks"), "a factory monitor shows its report window")
	GLOB.nanomanager.close_user_uis(H, monitor)
	var/obj/structure/power_meter/gauge = new(locate(9, 9, 1))
	gauge.attack_hand(H)
	rows = agent_screen_rows(H)
	screens_check(rows.len == 1 && findtext(rows[1]["data"], "Not connected") && (H in gauge.readers), "a loose power meter says it is not connected")
	GLOB.nanomanager.close_user_uis(H, gauge)
	gauge.supply_log += 1
	gauge.sample()
	screens_check(!(H in gauge.readers) && !agent_open_screens(H).len, "a reader who closed the meter window is dropped and it is not reopened")
	var/mob/living/human/screens_probe/P = new(locate(9, 9, 1))
	P.species = new /datum/species/human
	P.stat = CONSCIOUS
	screens_check(!nano_viewer_present(P), "a clientless body that is not an agent is no viewer")
	O.ui_interact(P)
	screens_check(!agent_open_screens(P).len, "no screen opens for it")
