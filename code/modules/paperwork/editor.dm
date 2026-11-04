// Pen attacks reach this through paper_editor_try_entrypoint. The existing
// transport still owns generation, ready/snapshot/ack and fallback.
/proc/paper_editor_request(payload)
	if (!istext(payload) || length(payload) > 8192)
		return null
	var/list/request = null
	try
		request = json_decode(payload)
	catch
		return null
	if (!islist(request) || !istext(request["operation"]) || !istext(request["lease"]) || length(request["lease"]) != 32)
		return null
	var/operation = request["operation"]
	if (operation == "refresh" || operation == "cancel")
		return paper_document_keys(request, list("operation", "lease")) ? request : null
	if (operation != "append" || !paper_document_keys(request, list("operation", "lease", "document_id", "revision", "language_id", "kind", "value")))
		return null
	if ((!isnull(request["document_id"]) && (!istext(request["document_id"]) || length(request["document_id"]) != 32)) || !isnum(request["revision"]) || request["revision"] < 0 || request["revision"] > 1048575 || request["revision"] != round(request["revision"]))
		return null
	if (!istext(request["language_id"]) || length(request["language_id"]) > 64 || !(request["kind"] in list("body", "title", "signature")) || !istext(request["value"]) || length(request["value"]) > MAX_PAPER_MESSAGE_LEN)
		return null
	return request

// Pen and crayon sections render through the guarded Book page. Existing legacy
// HTML is shown there as inert styled text parsed on the client; it is never
// rewritten, and the classic read-only preview remains the failure fallback.
/proc/paper_editor_modern_supported(list/data)
	if (!data || !(data["draft_tool"] in list("pen", "crayon")))
		return FALSE
	var/list/view = data["view"]
	if (!islist(view) || !istext(view["legacy_body_html"]) || length(view["legacy_body_html"]) > 65536)
		return FALSE
	var/list/sections = view["sections"]
	if (!islist(sections))
		return FALSE
	for (var/list/section in sections)
		if (!(section["tool"] in list("pen", "crayon")))
			return FALSE
	return TRUE

/datum/topic_state/paper_editor
	should_save = FALSE
	var/datum/paper_document_authoring/session

/datum/topic_state/paper_editor/New(datum/paper_document_authoring/new_session)
	..()
	session = new_session

/datum/topic_state/paper_editor/can_use_topic(src_object, mob/user)
	if (!session || src_object != session.paper || user != session.controller || !session.lifecycle_physical_current())
		return STATUS_CLOSE
	return STATUS_INTERACTIVE

/datum/nanoui/tgui/paper_editor
	should_save = FALSE
	on_close_logic = FALSE
	var/datum/paper_document_authoring/editor_session
	var/editor_closed = FALSE
	var/response_serial = 0
	var/last_result = "ready"

/datum/nanoui/tgui/paper_editor/persistence_runtime_var(key)
	return (key in list("editor_session", "editor_closed", "response_serial", "last_result")) || ..()

/datum/nanoui/tgui/paper_editor/allowed_actions()
	return list("paper_edit")

// A classic fallback is a complete projected read-only view, never the old
// field/EOF editor. It cannot downgrade a classified write to legacy HTML.
/datum/nanoui/tgui/paper_editor/Topic(href, href_list)
	if (editor_closed || legacy_renderer)
		return
	return ..()

/datum/nanoui/tgui/paper_editor/proc/editor_current()
	var/datum/topic_state/paper_editor/editor_state = state
	return !editor_closed && editor_session && editor_session.authoring_ui == src && user == editor_session.controller && src_object == editor_session.paper && istype(editor_state) && editor_state.session == editor_session && editor_state.can_use_topic(src_object, user) == STATUS_INTERACTIVE

/datum/nanoui/tgui/paper_editor/proc/editor_data()
	if (!editor_current())
		return null
	var/list/data = editor_session.snapshot(user)
	if (!data)
		return null
	var/obj/item/weapon/paper/P = editor_session.paper
	var/list/view = data["view"]
	if (isnull(editor_session.expected_record))
		// The old editor cache contains write hrefs. This owned editor uses only
		// the same authorized authored bytes, never that mutable href cache.
		view["legacy_body_html"] = "[P.info][P.stamps]"
	if (!paper_document_ink(editor_session.writing_pen.colour))
		return null
	data["draft_ink"] = editor_session.writing_pen.colour
	data["draft_tool"] = istype(editor_session.writing_pen, /obj/item/weapon/pen/crayon) ? "crayon" : "pen"
	data["response_serial"] = response_serial
	data["result"] = last_result
	return data

/datum/nanoui/tgui/paper_editor/open()
	var/list/data = editor_data()
	if (!data)
		close()
		return
	if (!paper_editor_modern_supported(data))
		legacy_renderer = TRUE
	set_initial_data(data)
	return ..()

// Ignore cached/injected data: ready, refresh and ordinary updates re-project
// current language knowledge and authority before anything is sent again.
/datum/nanoui/tgui/paper_editor/push_data(data, force_push = FALSE)
	var/list/current = editor_data()
	if (!current)
		close()
		return
	if (!legacy_renderer && !paper_editor_modern_supported(current))
		use_legacy_renderer()
		return
	return ..(current, force_push)

/datum/nanoui/tgui/paper_editor/update(force_open = FALSE)
	if (legacy_renderer)
		open()
	else
		push_data(null, TRUE)

/datum/nanoui/tgui/paper_editor/get_html()
	if (!legacy_renderer)
		return ..()
	var/list/data = editor_data()
	if (!data)
		return ""
	var/list/view = data["view"]
	var/body = paper_document_view_body(view, editor_session.paper)
	var/title = paper_document_view_title(view["legacy_name"])
	return "<HTML><HEAD><TITLE>" + title + "</TITLE></HEAD><BODY style=\"background:#FFFFFF;color:#000000\"><p>This document is shown in a read-only view.</p>" + body + "</BODY></HTML>"

/datum/nanoui/tgui/paper_editor/consume_topic(href, list/href_list)
	if (!editor_current() || legacy_renderer || !frontend_ready || !frontend_acknowledged || status != STATUS_INTERACTIVE || usr != user)
		return TRUE
	if (!paper_document_keys(href_list, list("paper_edit")))
		return TRUE
	var/list/request = paper_editor_request(href_list["paper_edit"])
	if (!request || !editor_session.can_mutate(user, editor_session.writing_pen))
		return TRUE
	var/operation = request["operation"]
	if (operation == "cancel")
		editor_session.cancel(user, request["lease"])
		return TRUE
	if (response_serial >= 1048575)
		close()
		return TRUE
	response_serial++
	last_result = "refreshed"
	if (operation == "append")
		if (!paper_editor_modern_supported(editor_data()))
			use_legacy_renderer()
			return TRUE
		last_result = editor_session.append(user, editor_session.writing_pen, request["document_id"], request["revision"], request["language_id"], request["kind"], request["value"], request["lease"]) ? "saved" : "rejected"
	// Refresh is read-only and may recover an old lease after a lost reply.
	// Its real actor/session/pen/custody guard above remains authoritative.
	if (!editor_closed)
		push_data(null, TRUE)
	// Consumed locally: never broadcast through update_uis(paper).
	return TRUE

/datum/nanoui/tgui/paper_editor/close()
	if (editor_closed)
		return
	editor_closed = TRUE
	var/datum/paper_document_authoring/old_session = editor_session
	editor_session = null
	if (old_session && !old_session.session_closed)
		try
			old_session.retire()
		catch (var/exception/e)
			error(e.desc)
	return ..()

// Pen use opens the language-aware editor. A paper it cannot take (a subtype,
// or a writer with no written language) keeps the guarded legacy editor only
// while it has no canonical record; a classified paper never downgrades.
#define PAPER_EDITOR_ENTRYPOINT_ENABLED TRUE
/proc/paper_editor_try_entrypoint(obj/item/weapon/paper/P, mob/actor, obj/item/weapon/pen/pen)
	if (!PAPER_EDITOR_ENTRYPOINT_ENABLED)
		return FALSE
	if (paper_editor_open(P, actor, pen))
		return TRUE
	if (P && !P.gc_destroyed && isnull(P.document_record))
		return FALSE
	to_chat(actor, SPAN_WARNING("You cannot write on this paper right now."))
	return TRUE
#undef PAPER_EDITOR_ENTRYPOINT_ENABLED

// The pen route uses this factory; construction itself grants no access.
/proc/paper_editor_open(obj/item/weapon/paper/P, mob/actor, obj/item/weapon/pen/pen)
	if (!P || !actor || !actor.client)
		return null
	if (islist(actor.open_uis))
		for (var/datum/nanoui/tgui/paper_editor/existing in actor.open_uis.Copy())
			if (istype(existing) && existing.src_object == P && existing.user == actor && existing.editor_data())
				existing.open()
				if (existing.editor_closed || !existing.editor_data())
					existing.close()
					return null
				return existing
	var/datum/paper_document_authoring/session = new(P, actor, pen)
	var/datum/nanoui/tgui/paper_editor/ui = null
	try
		if (!session.begin(actor))
			session.retire()
			return null
		var/datum/topic_state/paper_editor/editor_state = new(session)
		// A server-minted key prevents failed preparation from closing another
		// window opened reentrantly by an asset/constructor callback.
		ui = new(actor, P, "paper_editor_[session.session_lease]", "paper_editor.tmpl", "Paper", 750, 720, _state = editor_state)
		ui.editor_session = session
		if (ui.editor_closed || !ui.state || !session.bind_ui(actor, session.session_lease, ui))
			session.retire()
			ui.close()
			return null
		ui.set_auto_update(FALSE)
		ui.open()
		if (ui.editor_closed || !ui.state || !ui.editor_data())
			session.retire()
			ui.close()
			return null
		return ui
	catch (var/exception/e)
		try
			session.retire()
		catch (var/exception/cleanup_error)
			error(cleanup_error.desc)
		if (ui)
			ui.close()
		error(e.desc)
		return null
