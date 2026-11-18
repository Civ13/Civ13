// Civ13 transport adapter for the modern tgui frontend. The NanoUI manager,
// topic states and gameplay Topics remain authoritative. There is no second
// renderer: a window is the modern screen, or - only for the few windows that
// keep one - a complete plain page for content the screen cannot show.
#define TGUI_INLINE_SNAPSHOT_LIMIT 262144

/datum/nanoui/tgui
	// TRUE while this window shows its plain page instead of the modern screen.
	var/plain_page = FALSE
	var/frontend_ready = FALSE
	var/frontend_acknowledged = FALSE
	var/client/pending_transfer_client
	var/render_generation = 0
	var/list/latest_data
	// Digest of the last snapshot this page was sent.
	var/last_sent
	// TRUE from an accepted button press until the next snapshot is sent.
	var/reply_owed = FALSE

// The modern screen ships as its own three files, sent in open(). The classic
// NanoUI scripts, styles and images are never used by it.
/datum/nanoui/tgui/send_base_assets(template_filename)
	return

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
	last_sent = null
	reply_owed = FALSE
	if (!plain_page)
		var/datum/asset/assets = get_asset_datum(/datum/asset/simple/civ13_tgui)
		assets.send(user)
	// A browser already known to run the modern screen opens without BYOND's
	// title bar, so the window's own bar shows from the start. Otherwise the
	// screen hides BYOND's bar itself once it has drawn.
	var/saved_options = window_options
	if (opens_with_own_title_bar())
		window_options = replacetext(replacetext(window_options, "titlebar=1", "titlebar=0"), "can_resize=1", "can_resize=0")
	. = ..()
	window_options = saved_options

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
	if (plain_page)
		return
	if (!expected_client)
		close()
		return
	pending_transfer_client = expected_client

// Called only after key assignment, with current ownership checked by manager.
/datum/nanoui/tgui/proc/complete_user_transfer(var/mob/linked_user)
	if (plain_page || user != linked_user || !user || !state || !src_object || !pending_transfer_client)
		return
	if (user.client != pending_transfer_client || pending_transfer_client.mob != user)
		return
	pending_transfer_client = null
	open()

// Whether this window keeps a complete plain page of its own (a book page with
// old markup, a read-only document). Most windows do not.
/datum/nanoui/tgui/proc/has_plain_page()
	return FALSE

// The browser asked to give up on the modern screen, or the window found
// content the screen cannot show. Only a window with a plain page switches;
// it then keeps that page until it is closed.
/datum/nanoui/tgui/proc/show_plain_page()
	if (plain_page || !has_plain_page() || !user || !user.client || !src_object || !state)
		return
	update_status(FALSE)
	if (!state || status == STATUS_CLOSE)
		return
	restore_title_bar()
	plain_page = TRUE
	set_initial_data(latest_data)
	open()

// The window draws its own title bar (title, close button, dragging and
// resizing) instead of BYOND's, unless the player turned that off in
// Character Setup > Settings. A plain page always keeps BYOND's bar.
/datum/nanoui/tgui/proc/own_title_bar()
	return !plain_page && user && user.client && user.client.is_preference_enabled(/datum/client_preference/tgui_title_bar)

/datum/nanoui/tgui/proc/opens_with_own_title_bar()
	return own_title_bar() && user.client.modern_ui_acknowledged && !user.client.modern_ui_failed

// Gives the window BYOND's title bar back, so a page that cannot draw its own
// can still be moved and closed.
/datum/nanoui/tgui/proc/restore_title_bar()
	if (user && user.client)
		winset(user, window_id, "titlebar=true;can-resize=true")

/datum/nanoui/tgui/get_config_data()
	var/list/config = ..()
	config["template"] = templates["main"]
	config["ref"] = "\ref[src]"
	config["window"] = window_id
	config["generation"] = render_generation
	config["title_bar"] = own_title_bar() ? 1 : 0
	return config

// The first snapshot as JSON that is safe inside a script element, so the
// window can draw before its ready message has made the round trip. Empty when
// it is too large to carry in the page; the ready push then delivers it.
/datum/nanoui/tgui/proc/initial_snapshot()
	var/json = strip_improper(json_encode(get_send_data(status == STATUS_DISABLED ? null : latest_data)))
	if (length(json) > TGUI_INLINE_SNAPSHOT_LIMIT)
		return ""
	return replacetext(json, "<", "\\u003c")

// Always the modern shell; a window with a plain page overrides this.
/datum/nanoui/tgui/get_html()
	var/version = civ13_tgui_version()
	return {"
<!DOCTYPE html>
<html><head><meta charset="utf-8"><meta http-equiv="X-UA-Compatible" content="IE=edge">
<title>Civ13 Interface</title></head>
<body style="background:#211c16;color:#eee5d3;font-family:sans-serif" data-ref="\ref[src]" data-window="[html_encode(window_id)]" data-generation="[render_generation]" data-assets="[version]">
<div id="root"></div>
<p id="tgui-loading">Loading interface...</p>
<script type="application/json" id="tgui-initial">[initial_snapshot()]</script>
<script src="[civ13_tgui_versioned_name("civ13-tgui-bootstrap.js", version)]" onerror="document.getElementById('tgui-loading').textContent='This window could not load. Close it and open it again.'"></script>
</body></html>
"}

/datum/nanoui/tgui/push_data(data, force_push = FALSE)
	if (!isnull(data))
		latest_data = data
	if (plain_page || !user || !user.client || !src_object || !state)
		return
	update_status(FALSE)
	if (!state || !frontend_ready || (status == STATUS_DISABLED && !force_push))
		return
	var/json = strip_improper(json_encode(get_send_data(data)))
	// An automatic refresh that changes nothing is not sent again. A button
	// press always gets its answer, changed or not.
	var/digest = md5(json)
	if (digest == last_sent && !force_push && !reply_owed)
		return
	last_sent = digest
	reply_owed = FALSE
	user << output(list2params(list(json)), "[window_id].browser:receiveUpdateData")

/datum/client_preference/tgui_title_bar
	description = "Interface window title bars"
	key = "TGUI_TITLE_BAR"
	enabled_description = "Built-in"
	disabled_description = "Windows"

// Open windows redraw with the new bar on their next refresh.
/datum/client_preference/tgui_title_bar/toggled(mob/preference_mob, enabled)
	if (preference_mob)
		GLOB.nanomanager.update_user_uis(preference_mob)

// Opens this owner's window for a user, or refreshes the one already open.
// state may be a topic state or the type of one to create for a new window;
// keep_interaction leaves the user's current machine alone when it closes.
/datum/proc/open_tgui(mob/user, ui_key, template, title, width, height, list/data, datum/nanoui/ui, force_open = TRUE, state, keep_interaction = FALSE, auto_update = FALSE)
	ui = GLOB.nanomanager.try_update_ui(user, src, ui_key, ui, data, force_open)
	if (ui)
		return ui
	if (ispath(state))
		state = new state()
	ui = new /datum/nanoui/tgui(user, src, ui_key, template, title, width, height, _state = state ? state : default_state)
	if (keep_interaction)
		ui.use_on_close_logic(FALSE)
	ui.set_initial_data(data)
	ui.open()
	if (auto_update)
		ui.set_auto_update(TRUE)
	return ui

// Each window's owner declares what its buttons may send. A request is one
// action with an optional "value" plus the extra fields ui_action_fields() names.
// This is a transport boundary, not a replacement for each owner's own checks.
/datum/proc/ui_actions(ui_key)
	return list()

/datum/proc/ui_action_fields(ui_key, action)
	return null

// Typed handler for one declared action. params holds "value" and any declared
// fields as the text or numbers the window sent. Return TRUE when the action
// was handled here; the open windows of this owner are then refreshed. An
// owner without one keeps receiving the action through its Topic().
/datum/proc/ui_act(action, list/params, mob/user, datum/nanoui/ui)
	return FALSE

/datum/nanoui/tgui/proc/allowed_actions()
	return src_object ? src_object.ui_actions(ui_key) : list()

/datum/nanoui/tgui/proc/allowed_fields(action)
	return src_object ? src_object.ui_action_fields(ui_key, action) : null

/datum/nanoui/tgui/Topic(href, href_list)
	if (!user || usr != user || !user.client || !src_object || !state)
		return
	// A plain page is ordinary HTML: its links keep the original protocol.
	if (plain_page)
		if (href_list["type"])
			return
		return ..()
	if (href_list["window_id"] != window_id || href_list["generation"] != "[render_generation]")
		return
	update_status(FALSE)
	if (!state || status == STATUS_CLOSE)
		return
	var/message_type = href_list["type"]
	// The close button on the window's own title bar.
	if (message_type == "close")
		close()
		return
	if (message_type == "fallback")
		restore_title_bar()
		show_plain_page()
		return
	if (message_type == "ready")
		frontend_ready = TRUE
		push_data(status == STATUS_DISABLED ? null : latest_data, TRUE)
		return
	if (message_type == "ack")
		if (frontend_ready)
			frontend_acknowledged = TRUE
			// This browser runs the modern frontend, so WWinput may use modern prompts.
			user.client.modern_ui_acknowledged = TRUE
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
	if (!islist(params) || params.len > 8)
		return
	var/list/keys = list("value")
	var/list/fields = allowed_fields(action)
	if (islist(fields))
		keys += fields
	for (var/key in params)
		if (!istext(key) || !(key in keys) || (!istext(params[key]) && !isnum(params[key])))
			return
	reply_owed = TRUE
	if (act_typed(action, params))
		return
	var/list/legacy = href_form(action, params)
	// Parent rechecks CanUseTopic and ownership immediately before dispatch.
	return ..(list2params(legacy), legacy)

// Offers one validated action to the owner's ui_act(). The caller has just
// rechecked status and owner.
/datum/nanoui/tgui/proc/act_typed(action, list/params)
	if (isnull(params["value"]))
		params["value"] = 1
	if (!src_object.ui_act(action, params, user, src))
		return FALSE
	// A handler may wait on the player; the owner can be gone by then.
	if (src_object)
		GLOB.nanomanager.update_uis(src_object)
	return TRUE

// Owners without ui_act() read href-style text: the action names its value.
/datum/nanoui/tgui/proc/href_form(action, list/params)
	. = list()
	.[action] = "[params["value"]]"
	for (var/key in params)
		if (key != "value" && key != action)
			.[key] = "[params[key]]"
