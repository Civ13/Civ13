// Civ13 transport adapter for the modern tgui frontend. The NanoUI manager,
// topic states and gameplay Topics remain authoritative. Legacy rendering stays
// available for older embedded browsers and failed asset loads.
/datum/nanoui/tgui
	var/legacy_renderer = FALSE
	var/frontend_ready = FALSE
	var/frontend_acknowledged = FALSE
	var/client/pending_transfer_client
	var/render_generation = 0
	var/list/latest_data

/datum/nanoui/tgui/set_initial_data(list/data)
	..()
	latest_data = data

/datum/nanoui/tgui/open()
	if (!user || !user.client || !src_object || !state)
		return
	render_generation++
	frontend_ready = FALSE
	frontend_acknowledged = FALSE
	pending_transfer_client = null
	if (!legacy_renderer)
		var/datum/asset/assets = get_asset_datum(/datum/asset/simple/civ13_tgui)
		assets.send(user)
	. = ..()
	if (!legacy_renderer && state && user && user.client)
		var/open_generation = render_generation
		var/mob/open_user = user
		var/client/open_client = user.client
		// Browser ready alone does not prove receipt of a server snapshot.
		// Recover even when client-to-server ready/fallback never arrives.
		spawn(200)
			if (legacy_renderer || frontend_acknowledged || render_generation != open_generation || user != open_user)
				return
			if (!user || user.client != open_client || !src_object || !state)
				return
			use_legacy_renderer()

/datum/nanoui/tgui/close()
	frontend_ready = FALSE
	frontend_acknowledged = FALSE
	pending_transfer_client = null
	render_generation++
	return ..()

// Ownership moves before mind.transfer_to links the client's new body.
/datum/nanoui/tgui/proc/prepare_user_transfer(var/client/expected_client)
	render_generation++
	frontend_ready = FALSE
	frontend_acknowledged = FALSE
	if (!expected_client)
		expected_client = pending_transfer_client
	pending_transfer_client = null
	if (legacy_renderer)
		return
	if (!expected_client)
		close()
		return
	pending_transfer_client = expected_client

// Called only after key assignment, with current ownership checked by manager.
/datum/nanoui/tgui/proc/complete_user_transfer(var/mob/linked_user)
	if (legacy_renderer || user != linked_user || !user || !state || !src_object || !pending_transfer_client)
		return
	if (user.client != pending_transfer_client || pending_transfer_client.mob != user)
		return
	pending_transfer_client = null
	open()

// Shared by a validated browser fallback and the server startup watchdog.
// Retain classic rendering for this UI datum once recovery is selected.
/datum/nanoui/tgui/proc/use_legacy_renderer()
	if (legacy_renderer || !user || !user.client || !src_object || !state)
		return
	update_status(FALSE)
	if (!state || status == STATUS_CLOSE)
		return
	legacy_renderer = TRUE
	set_initial_data(latest_data)
	open()

/datum/nanoui/tgui/get_config_data()
	var/list/config = ..()
	config["template"] = templates["main"]
	config["ref"] = "\ref[src]"
	config["window"] = window_id
	config["generation"] = render_generation
	return config

/datum/nanoui/tgui/get_html()
	if (legacy_renderer)
		return ..()
	return {"
<!DOCTYPE html>
<html><head><meta charset="utf-8"><meta http-equiv="X-UA-Compatible" content="IE=edge">
<title>Civ13 Interface</title></head>
<body data-ref="\ref[src]" data-window="[html_encode(window_id)]" data-generation="[render_generation]">
<div id="root"></div>
<p id="tgui-loading">Loading interface... <a id="tgui-legacy" href="byond://?src=\ref[src]&amp;window_id=[url_encode(window_id)]&amp;generation=[render_generation]&amp;type=fallback">Use classic interface</a></p>
<script src="civ13-tgui-bootstrap.js" onerror="window.location.href=document.getElementById('tgui-legacy').href"></script>
</body></html>
"}

/datum/nanoui/tgui/push_data(data, force_push = FALSE)
	if (!isnull(data))
		latest_data = data
	if (legacy_renderer)
		return ..()
	if (!user || !user.client || !src_object || !state)
		return
	update_status(FALSE)
	if (!state || !frontend_ready || (status == STATUS_DISABLED && !force_push))
		return
	var/list/send_data = get_send_data(data)
	user << output(list2params(list(strip_improper(json_encode(send_data)))), "[window_id].browser:receiveUpdateData")

// One primary action per request; optional fields are specific to that action.
// This is a transport boundary, not a replacement for each source Topic's checks.
/datum/nanoui/tgui/proc/allowed_actions()
	switch (templates["main"])
		if ("chem_disp.tmpl")
			return list("amount", "dispense", "ejectBeaker")
		if ("appearance_changer.tmpl")
			return list("race", "gender", "skin_tone", "skin_color", "hair", "hair_color", "facial_hair", "facial_hair_color", "eye_color")
		if ("vending_machine.tmpl")
			return list("vend", "cancelpurchase", "remove_coin", "togglevoice")
		if ("vending_machine2.tmpl", "vending_machine_gulag.tmpl", "vending_machine_taotd.tmpl")
			return list("vend", "cancelpurchase", "remove_money", "togglevoice")
		if ("research_bench.tmpl")
			return list("assign", "queue", "clear_queue", "write_book", "write_notes", "claim", "appoint_director", "dismiss_director", "set_director_title", "appoint_researcher", "dismiss_researcher")
		if ("faction_symbol.tmpl")
			return list("set_tool", "pick_color", "paint", "stroke", "stamp", "clear", "undo", "save")
		if ("faction_creation.tmpl")
			return list("set_name", "set_motto", "set_flavour", "set_tool", "pick_color", "paint", "stroke", "stamp", "clear", "undo", "found")
	return list()

/datum/nanoui/tgui/Topic(href, href_list)
	if (!user || usr != user || !user.client || !src_object || !state)
		return
	// Old templates still use the original NanoUI protocol after fallback.
	if (legacy_renderer)
		if (href_list["type"])
			return
		return ..()
	if (href_list["window_id"] != window_id || href_list["generation"] != "[render_generation]")
		return
	update_status(FALSE)
	if (!state || status == STATUS_CLOSE)
		return
	var/message_type = href_list["type"]
	if (message_type == "fallback")
		use_legacy_renderer()
		return
	if (message_type == "ready")
		frontend_ready = TRUE
		push_data(status == STATUS_DISABLED ? null : latest_data, TRUE)
		return
	if (message_type == "ack")
		if (frontend_ready)
			frontend_acknowledged = TRUE
		return
	if (status != STATUS_INTERACTIVE || !frontend_ready || !frontend_acknowledged || copytext(message_type, 1, 5) != "act/")
		return
	var/action = copytext(message_type, 5)
	if (!(action in allowed_actions()))
		return
	var/raw_payload = href_list["payload"]
	if (!istext(raw_payload) || length(raw_payload) > 8192)
		return
	var/list/params
	try
		params = json_decode(raw_payload)
	catch
		return
	if (!islist(params) || params.len > 8 || isnull(params[action]))
		return
	var/list/keys = list(action)
	switch (action)
		if ("paint")
			keys += list("x", "y")
		if ("stroke")
			keys += list("cells", "stroke_continue")
	for (var/key in params)
		if (!istext(key) || !(key in keys) || (!istext(params[key]) && !isnum(params[key])))
			return
		// Existing Topics consume href values as strings, including numbers.
		params[key] = "[params[key]]"
	// Parent rechecks CanUseTopic and ownership immediately before dispatch.
	return ..(list2params(params), params)
