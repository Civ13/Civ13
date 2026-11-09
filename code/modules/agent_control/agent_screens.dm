// NanoUI and tgui screens for agent characters (docs/agent-control.md#screens).
//
// A player opens a machine screen (research bench, chemical dispenser,
// vending machine, faction creation, recruitment station) in a browser window
// and presses its buttons. An agent character has no client, so open() drew
// nothing and the topic states closed the screen. Here a clientless agent body
// keeps the screen open without a window: character_observe lists it with its
// data and allowed actions, and the screen action presses one action through
// the same status checks and gameplay Topic a player's button reaches.

#define AGENT_SCREEN_DATA 4000

// A UI may stay open for this mob: a connected player, or an agent character's body.
/proc/nano_viewer_present(mob/M)
	if (!M)
		return FALSE
	if (M.client)
		return TRUE
	return (agent_characters.len && agent_character_for(M)) ? TRUE : FALSE

/proc/agent_screen_viewer(mob/M)
	return M && !M.client && agent_characters.len && agent_character_for(M)

/datum/nanoui/open()
	if (agent_screen_viewer(user))
		return agent_open()
	return ..()

/datum/nanoui/tgui/open()
	if (agent_screen_viewer(user))
		render_generation++
		return agent_open()
	return ..()

// open() without a browser: the status check and the manager's bookkeeping,
// so updates, distance closing and Topic routing work as for a player.
/datum/nanoui/proc/agent_open()
	if (!src_object)
		qdel(src)
		return
	update_status(0)
	if (status == STATUS_CLOSE)
		return
	GLOB.nanomanager.ui_opened(src)

// The data the screen shows now.
/datum/nanoui/proc/agent_screen_data()
	return initial_data

/datum/nanoui/tgui/agent_screen_data()
	return latest_data

// The buttons the screen accepts: tgui lists them; a classic NanoUI accepts any key.
/datum/nanoui/proc/agent_screen_actions()
	return null

/datum/nanoui/tgui/agent_screen_actions()
	return allowed_actions()

// The Topic a player's button reaches, after the same status and owner checks.
/datum/nanoui/proc/agent_topic(list/params)
	update_status(0)
	if (status != STATUS_INTERACTIVE || user != usr)
		return FALSE
	var/href = list2params(params)
	if (consume_topic(href, params))
		return TRUE
	if (src_object && src_object.Topic(href, params, state))
		GLOB.nanomanager.update_uis(src_object)
	return TRUE

/proc/agent_screen_status(status)
	switch (status)
		if (STATUS_INTERACTIVE)
			return "interactive"
		if (STATUS_UPDATE)
			return "view_only"
		if (STATUS_DISABLED)
			return "disabled"
	return "closed"

// Open screens of an agent body, newest last.
/proc/agent_open_screens(mob/M)
	. = list()
	for (var/datum/nanoui/ui in M.open_uis)
		if (ui.state && ui.src_object && ui.user == M)
			. += ui

/proc/agent_screen_rows(mob/M)
	. = list()
	var/n = 0
	for (var/datum/nanoui/ui in agent_open_screens(M))
		n++
		var/list/row = list("screen" = n, "title" = "[ui.title]", "template" = "[ui.templates["main"]]", "status" = agent_screen_status(ui.status))
		var/atom/A = ui.src_object
		if (istype(A))
			row["ref"] = agent_ref(A)
		var/list/actions = ui.agent_screen_actions()
		if (islist(actions))
			row["actions"] = actions
		var/list/data = ui.agent_screen_data()
		if (islist(data))
			var/text = json_encode(data)
			if (length(text) > AGENT_SCREEN_DATA)
				row["data_truncated"] = TRUE
				text = copytext(text, 1, AGENT_SCREEN_DATA + 1)
			row["data"] = text
		. += list(row)

/proc/agent_find_screen(mob/M, which)
	var/list/screens = agent_open_screens(M)
	var/n = text2num("[which]")
	if (isnum(n) && n >= 1 && n <= screens.len)
		return screens[n]
	for (var/datum/nanoui/ui in screens)
		if (lowertext("[ui.title]") == lowertext("[which]") || lowertext("[ui.templates["main"]]") == lowertext("[which]"))
			return ui
	return null

// Press one action of an open screen, as the matching button does; or close it.
/datum/agent_control/proc/agent_screen(datum/agent_character/C, list/req, from_queue)
	var/mob/living/M = C.body
	var/datum/nanoui/ui = agent_find_screen(M, req["screen"])
	if (!ui)
		agent_fail("not_found", "no open screen [req["screen"]]; see screens in character_observe")
	if (req["close"] == TRUE || req["close"] == 1)
		ui.close()
		return "closed [ui.title]"
	var/action = agent_text_arg(req, "act", 32)
	var/list/allowed = ui.agent_screen_actions()
	if (islist(allowed) && !(action in allowed))
		agent_fail("bad_args", "[ui.title] accepts [allowed.len ? jointext(allowed, ", ") : "no actions"]")
	var/list/params = list()
	params[action] = isnull(req["value"]) ? "1" : "[req["value"]]"
	// The extra fields the tgui transport lets a painting action carry.
	for (var/key in list("x", "y", "cells", "stroke_continue"))
		if (!isnull(req[key]))
			params[key] = "[req[key]]"
	// A gameplay Topic may prompt (an amount, a name), which sleeps.
	agent_queue_only("press a screen button", from_queue)
	if (!ui.agent_topic(params))
		agent_fail("cannot_act", "[ui.title] is [agent_screen_status(ui.status)] for this character right now")
	C.next_action = world.time + 2
	return "[ui.title]: [action] [params[action]]"

#undef AGENT_SCREEN_DATA
