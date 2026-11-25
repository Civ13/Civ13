// Read-only Notes presentation. No saved fields, learning or data repairs.
/datum/character_notes_budget
	var/units_left = 65536 // Native length() units; never truncate a fragment.
	var/nodes_left = 2048 // Includes section/entry structure, not only text runs.
	var/max_depth = 32

// common.text decodes once. Reject ambiguous/unsupported entities so the modern
// path cannot silently reinterpret the original browser's text. Unknown forms
// keep the complete original classic snapshot, including all private content.
/proc/character_notes_entities_safe(value)
	var/cursor = 1
	while (cursor <= length(value))
		var/amp = findtext(value, "&", cursor)
		if (!amp)
			break
		cursor = amp + 1
		if (cursor > length(value))
			break
		var/first = text2ascii(value, cursor)
		if (first != 35 && !(first >= 65 && first <= 90) && !(first >= 97 && first <= 122))
			continue
		var/ending = findtext(value, ";", cursor)
		if (!ending || ending - cursor > 16)
			return FALSE
		var/entity = copytext(value, cursor, ending)
		if (!(entity in list("amp", "lt", "gt", "quot", "apos", "AMP", "LT", "GT", "QUOT")))
			if (copytext(entity, 1, 2) != "#")
				return FALSE
			var/digits = copytext(entity, 2)
			if (!length(digits) || length(digits) > 7)
				return FALSE
			for (var/index = 1, index <= length(digits), index++)
				var/code = text2ascii(digits, index)
				if (code < 48 || code > 57)
					return FALSE
			var/point = text2num(digits)
			if (point <= 0 || point > 1114111 || (point >= 55296 && point <= 57343) || (point >= 127 && point <= 159))
				return FALSE
			if (point < 32 && point != 9 && point != 10 && point != 13)
				return FALSE
		cursor = ending + 1
	return TRUE

// Attribute-free, balanced b/i/br only. Text remains encoded until React's
// existing pure text decoder runs once. No raw HTML is inserted by the frontend.
/proc/character_notes_parse(value, datum/character_notes_budget/budget)
	if (!istext(value) || !budget || length(value) > budget.units_left || strip_improper(value) != value)
		return null
	budget.units_left -= length(value)
	var/nul = ascii2text(0)
	if (length(nul) && findtext(value, nul))
		return null
	for (var/control = 1, control <= 31, control++)
		if (control != 9 && control != 10 && control != 13 && findtext(value, ascii2text(control)))
			return null
	if (findtext(value, ascii2text(127)))
		return null
	var/list/runs = list()
	var/list/tags = list()
	var/bold = 0
	var/italic = 0
	var/cursor = 1
	while (cursor <= length(value))
		var/opening = findtext(value, "<", cursor)
		if (!opening)
			opening = length(value) + 1
		if (opening > cursor)
			var/chunk = copytext(value, cursor, opening)
			if (!character_notes_entities_safe(chunk) || budget.nodes_left <= 0)
				return null
			budget.nodes_left--
			runs += list(list("text" = chunk, "bold" = (bold > 0), "italic" = (italic > 0)))
		if (opening > length(value))
			break
		var/ending = findtext(value, ">", opening + 1)
		if (!ending)
			return null
		var/first = text2ascii(value, opening + 1)
		if (!(first in list(66, 73, 98, 105, 47)))
			return null
		var/tag = lowertext(trim(copytext(value, opening + 1, ending)))
		if (tag == "br" || tag == "br/" || (copytext(tag, 1, 3) == "br" && trim(copytext(tag, 3)) == "/"))
			if (budget.nodes_left <= 0)
				return null
			budget.nodes_left--
			runs += list(list("br" = TRUE))
		else if (tag == "b" || tag == "i")
			if (tags.len >= budget.max_depth)
				return null
			tags += tag
			if (tag == "b")
				bold++
			else
				italic++
		else if (tag == "/b" || tag == "/i")
			var/expected = copytext(tag, 2)
			if (!tags.len || tags[tags.len] != expected)
				return null
			tags.Cut(tags.len, tags.len + 1)
			if (expected == "b")
				bold--
			else
				italic--
		else
			return null
		cursor = ending + 1
	if (tags.len)
		return null
	return runs

/datum/mind/proc/character_notes_ui_data(discovery_snapshot, character_heading)
	var/datum/character_notes_budget/budget = new()
	var/list/character_runs = character_notes_parse(character_heading, budget)
	if (isnull(character_runs))
		return null
	var/list/sections = list()
	for (var/title in notes)
		if (budget.nodes_left <= 0)
			return null
		budget.nodes_left--
		var/list/title_runs = character_notes_parse("[title]", budget)
		if (isnull(title_runs))
			return null
		var/list/entries = list()
		var/list/notelist = notes[title]
		if (!islist(notelist))
			return null
		for (var/index = 1, index <= notelist.len, index++)
			if (budget.nodes_left <= 0)
				return null
			budget.nodes_left--
			var/list/entry_runs = character_notes_parse("[notelist[index]]", budget)
			if (isnull(entry_runs))
				return null
			entries += list(list("runs" = entry_runs))
		sections += list(list("title" = title_runs, "entries" = entries))
	var/list/memory_runs = character_notes_parse(memory ? "[memory]" : "No memories stored.", budget)
	var/list/discovery_runs = character_notes_parse(discovery_snapshot, budget)
	if (isnull(memory_runs) || isnull(discovery_runs))
		return null
	return list("character" = character_runs, "sections" = sections, "memory" = memory_runs, "discoveries" = discovery_runs)

// Fixed internal presentation hook. No client-selected proc or action forwarding.
/datum/mind/proc/present_character_notes_ui(mob/user, legacy_snapshot, discovery_snapshot, character_heading)
	if (!user || !user.client || user.mind != src)
		return FALSE
	var/list/data = character_notes_ui_data(discovery_snapshot, character_heading)
	var/ui_key = "character_notes"
	if (islist(user.open_uis))
		for (var/datum/nanoui/tgui/snapshot/character_notes/old_ui in user.open_uis.Copy())
			if (istype(old_ui) && old_ui.user == user && old_ui.src_object != src)
				old_ui.close()
	var/datum/nanoui/tgui/snapshot/character_notes/ui = open_reader_ui(user, src, ui_key, /datum/nanoui/tgui/snapshot/character_notes, /datum/topic_state/reader/character_notes)
	if (!ui)
		var/datum/topic_state/reader/character_notes/reader_state = new(src, user)
		ui = new /datum/nanoui/tgui/snapshot/character_notes(user, src, ui_key, "character_notes.tmpl", "Notes", 625, 650, _state = reader_state)
		ui.use_on_close_logic(FALSE)
	ui.legacy_snapshot = legacy_snapshot
	if (isnull(data))
		ui.plain_page = TRUE
		ui.set_initial_data(list())
	else
		ui.set_initial_data(data)
	ui.open()
	return TRUE

// The classic renderer is the complete cached Notes page.
/datum/nanoui/tgui/snapshot/character_notes
	fixed_classic_page = TRUE

// Notes belong to one mind: a body that no longer holds it loses the window.
/datum/topic_state/reader/character_notes/reader_allowed(mob/user)
	return user.mind == subject
