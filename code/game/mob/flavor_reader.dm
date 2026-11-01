// Static More... reader. Stored flavor/editor/preview semantics are unchanged.
/mob/proc/present_character_flavor_ui(mob/viewer, legacy_snapshot)
	if (!viewer || !viewer.client || !(src in view(viewer)))
		return FALSE
	var/encoded_name = html_encode("[name]")
	// Editor output is already encoded. Imported markup or noncanonical text
	// keeps the complete existing browser snapshot, never a repaired subset.
	var/modern = istext(flavor_text) && length(flavor_text) + length(encoded_name) <= 65536
	if (modern)
		modern = strip_improper(flavor_text) == flavor_text && html_encode(html_decode(flavor_text)) == flavor_text
	if (modern)
		var/list/lines = splittext(flavor_text, "\n")
		if (lines.len > 2048)
			modern = FALSE
	if (findtext("[name]", "<") || findtext("[name]", "&") || strip_improper("[name]") != "[name]")
		modern = FALSE
	var/ui_key = "character_flavor"
	var/datum/nanoui/tgui/character_flavor/ui = GLOB.nanomanager.get_open_ui(viewer, src, ui_key)
	if (ui)
		var/datum/topic_state/character_flavor/old_state = ui.state
		if (!istype(ui) || !istype(old_state) || old_state.subject != src || old_state.reader != viewer)
			ui.close()
			ui = null
	if (!ui)
		var/datum/topic_state/character_flavor/reader_state = new(src, viewer)
		ui = new /datum/nanoui/tgui/character_flavor(viewer, src, ui_key, "character_flavor.tmpl", "[name]", 500, 200, _state = reader_state)
		ui.use_on_close_logic(FALSE)
	ui.legacy_snapshot = legacy_snapshot
	if (!modern)
		ui.legacy_renderer = TRUE
		ui.set_initial_data(list())
	else
		ui.set_initial_data(list("name" = encoded_name, "text" = flavor_text))
	ui.open()
	return TRUE

/datum/nanoui/tgui/character_flavor
	var/legacy_snapshot
	var/reader_closed = FALSE

/datum/nanoui/tgui/character_flavor/get_html()
	var/datum/topic_state/character_flavor/reader_state = state
	if (!istype(reader_state) || reader_state.can_use_topic(src_object, user) == STATUS_CLOSE)
		return ""
	if (legacy_renderer)
		return legacy_snapshot
	return ..()

/datum/nanoui/tgui/character_flavor/update(var/force_open = FALSE)
	if (!user || !src_object || !state)
		close()
		return
	if (legacy_renderer)
		update_status(FALSE)
	else
		push_data(null, TRUE)

/datum/nanoui/tgui/character_flavor/close()
	if (reader_closed)
		return
	reader_closed = TRUE
	legacy_snapshot = null
	return ..()

/datum/topic_state/character_flavor
	var/mob/subject
	var/mob/reader

/datum/topic_state/character_flavor/New(mob/new_subject, mob/new_reader)
	..()
	subject = new_subject
	reader = new_reader

/datum/topic_state/character_flavor/can_use_topic(var/src_object, var/mob/user)
	if (!user || !user.client || !subject || src_object != subject || user != reader)
		return STATUS_CLOSE
	// Existing browser content is a snapshot: walking away does not recollect
	// or erase it. Only explicit More... rechecks view and refreshes content.
	return STATUS_UPDATE
