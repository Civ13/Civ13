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
	var/datum/nanoui/tgui/snapshot/character_flavor/ui = open_reader_ui(viewer, src, ui_key, /datum/nanoui/tgui/snapshot/character_flavor, /datum/topic_state/reader/character_flavor)
	if (!ui)
		var/datum/topic_state/reader/character_flavor/reader_state = new(src, viewer)
		ui = new /datum/nanoui/tgui/snapshot/character_flavor(viewer, src, ui_key, "character_flavor.tmpl", "[name]", 500, 200, _state = reader_state)
		ui.use_on_close_logic(FALSE)
	ui.legacy_snapshot = legacy_snapshot
	if (!modern)
		ui.plain_page = TRUE
		ui.set_initial_data(list())
	else
		ui.set_initial_data(list("name" = encoded_name, "text" = flavor_text))
	ui.open()
	return TRUE

// The classic renderer is the complete existing browser snapshot. The content
// is a snapshot: walking away does not recollect or erase it. Only an explicit
// More... rechecks view and refreshes content.
/datum/nanoui/tgui/snapshot/character_flavor
	fixed_classic_page = TRUE

/datum/topic_state/reader/character_flavor
