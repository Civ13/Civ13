// Book-only bounded presentation. No authoring, save or knowledge mutations.
/datum/book_page_budget
	var/units_left = 65536
	var/nodes_left = 2048
	var/max_depth = 32

/proc/book_page_ink(value)
	if (!istext(value))
		return null
	value = lowertext(value)
	switch (value)
		if ("black")
			return "#000000"
		if ("blue")
			return "#0000ff"
		if ("red")
			return "#ff0000"
		if ("white")
			return "#ffffff"
	if (length(value) != 7 || copytext(value, 1, 2) != "#")
		return null
	for (var/index = 2, index <= 7, index++)
		var/code = text2ascii(value, index)
		if (!((code >= 48 && code <= 57) || (code >= 97 && code <= 102)))
			return null
	return value

/proc/book_page_face(value)
	if (!istext(value))
		return null
	value = lowertext(value)
	if (value == "verdana")
		return "verdana"
	if (value == "times new roman")
		return "times"
	return null

/proc/book_page_space(code)
	return code == 32 || code == 9 || code == 10 || code == 13

// A strict attribute lexer, not a browser HTML parser/repair operation.
/proc/book_page_font(tag)
	for (var/index = 1, index <= length(tag), index++)
		var/code = text2ascii(tag, index)
		if (code > 126 || (code < 32 && !book_page_space(code)))
			return null
	var/list/attributes = list()
	var/cursor = 5
	while (cursor <= length(tag))
		if (!book_page_space(text2ascii(tag, cursor)))
			return null
		while (cursor <= length(tag) && book_page_space(text2ascii(tag, cursor)))
			cursor++
		if (cursor > length(tag))
			break
		var/start = cursor
		while (cursor <= length(tag))
			var/code = text2ascii(tag, cursor)
			if (!((code >= 65 && code <= 90) || (code >= 97 && code <= 122)))
				break
			cursor++
		var/attribute = lowertext(copytext(tag, start, cursor))
		if (!(attribute in list("face", "color")) || (attribute in attributes))
			return null
		while (cursor <= length(tag) && book_page_space(text2ascii(tag, cursor)))
			cursor++
		if (cursor > length(tag) || text2ascii(tag, cursor) != 61)
			return null
		cursor++
		while (cursor <= length(tag) && book_page_space(text2ascii(tag, cursor)))
			cursor++
		if (cursor > length(tag))
			return null
		var/quote = text2ascii(tag, cursor)
		var/value
		if (quote == 34 || quote == 39)
			cursor++
			var/ending = findtext(tag, ascii2text(quote), cursor)
			if (!ending)
				return null
			value = copytext(tag, cursor, ending)
			cursor = ending + 1
		else
			start = cursor
			while (cursor <= length(tag) && !book_page_space(text2ascii(tag, cursor)))
				cursor++
			value = copytext(tag, start, cursor)
		var/parsed = attribute == "face" ? book_page_face(value) : book_page_ink(value)
		if (isnull(parsed))
			return null
		attributes[attribute] = parsed
	return attributes

// Decode-once entity contract, matching the existing pure text decoder.
/proc/book_page_entities(value)
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

/proc/book_page_parse(value, datum/book_page_budget/budget)
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
	var/list/stack = list()
	var/ink = "#000000"
	var/face = "times"
	var/bold = FALSE
	var/italic = FALSE
	var/cursor = 1
	while (cursor <= length(value))
		var/opening = findtext(value, "<", cursor)
		if (!opening)
			opening = length(value) + 1
		if (opening > cursor)
			var/chunk = copytext(value, cursor, opening)
			if (!book_page_entities(chunk) || budget.nodes_left <= 0)
				return null
			budget.nodes_left--
			runs += list(list("text" = chunk, "ink" = ink, "face" = face, "bold" = bold, "italic" = italic))
		if (opening > length(value))
			break
		var/ending = findtext(value, ">", opening + 1)
		if (!ending)
			return null
		var/first = text2ascii(value, opening + 1)
		if (!(first in list(66, 73, 70, 72, 98, 105, 102, 104, 47)))
			return null
		var/tag = trim(copytext(value, opening + 1, ending))
		var/lower_tag = lowertext(tag)
		if (lower_tag == "br" || lower_tag == "br/" || (copytext(lower_tag, 1, 3) == "br" && trim(copytext(lower_tag, 3)) == "/"))
			if (budget.nodes_left <= 0)
				return null
			budget.nodes_left--
			runs += list(list("br" = TRUE, "ink" = ink, "face" = face, "bold" = bold, "italic" = italic))
		else if (lower_tag == "hr")
			// The writer joins complete pages with a bare, top-level divider.
			if (stack.len || budget.nodes_left <= 0)
				return null
			budget.nodes_left--
			runs += list(list("divider" = TRUE))
		else if (lower_tag == "b" || lower_tag == "i" || lower_tag == "font" || (copytext(lower_tag, 1, 5) == "font" && book_page_space(text2ascii(tag, 5))))
			if (stack.len >= budget.max_depth || budget.nodes_left <= 0)
				return null
			budget.nodes_left--
			var/kind = copytext(lower_tag, 1, 5) == "font" ? "font" : lower_tag
			stack += list(list("tag" = kind, "ink" = ink, "face" = face, "bold" = bold, "italic" = italic))
			if (kind == "b")
				bold = TRUE
			else if (kind == "i")
				italic = TRUE
			else
				var/list/attributes = book_page_font(tag)
				if (isnull(attributes))
					return null
				if (attributes["color"])
					ink = attributes["color"]
				if (attributes["face"])
					face = attributes["face"]
		else if (lower_tag == "/b" || lower_tag == "/i" || lower_tag == "/font")
			if (!stack.len)
				return null
			var/list/prior = stack[stack.len]
			if (prior["tag"] != copytext(lower_tag, 2))
				return null
			ink = prior["ink"]
			face = prior["face"]
			bold = prior["bold"]
			italic = prior["italic"]
			stack.Cut(stack.len, stack.len + 1)
		else
			return null
		cursor = ending + 1
	if (stack.len)
		return null
	return runs

/proc/book_page_metadata(value)
	if (!istext(value) || length(value) > 256 || strip_improper(value) != value || findtext(value, "<") || findtext(value, "&"))
		return FALSE
	for (var/control = 1, control <= 31, control++)
		if (findtext(value, ascii2text(control)))
			return FALSE
	var/nul = ascii2text(0)
	return !(length(nul) && findtext(value, nul)) && !findtext(value, ascii2text(127))

/obj/item/weapon/book/proc/present_book_reader(mob/reader, legacy_snapshot, visible_snapshot, title_snapshot, name_snapshot)
	if (!reader || !reader.client)
		return FALSE
	var/datum/book_page_budget/budget = new()
	var/list/runs
	if (book_page_metadata(title_snapshot) && book_page_metadata(name_snapshot))
		budget.units_left -= length(title_snapshot) + length(name_snapshot)
		runs = book_page_parse(visible_snapshot, budget)
	var/ui_key = "book_reader"
	var/datum/nanoui/tgui/snapshot/book_reader/ui = open_reader_ui(reader, src, ui_key, /datum/nanoui/tgui/snapshot/book_reader, /datum/topic_state/reader/book_reader)
	if (!ui)
		var/datum/topic_state/reader/book_reader/reader_state = new(src, reader)
		ui = new /datum/nanoui/tgui/snapshot/book_reader(reader, src, ui_key, "book_reader.tmpl", "Book", 625, 650, _state = reader_state)
		ui.use_on_close_logic(FALSE)
	ui.legacy_snapshot = legacy_snapshot
	if (isnull(runs))
		ui.plain_page = TRUE
		ui.title = "Book"
		ui.set_initial_data(list())
	else
		ui.title = html_encode(title_snapshot ? title_snapshot : "Book")
		ui.set_initial_data(list("runs" = runs))
	ui.open()
	return TRUE

// The classic renderer is the complete existing book page.
/datum/nanoui/tgui/snapshot/book_reader
	fixed_classic_page = TRUE

// A book page stays with the connection that opened it, not only the body.
/datum/topic_state/reader/book_reader
	var/client/reader_client

/datum/topic_state/reader/book_reader/New(datum/new_subject, mob/new_reader)
	..()
	reader_client = new_reader.client

/datum/topic_state/reader/book_reader/reader_allowed(mob/user)
	return user.client == reader_client

/datum/topic_state/reader/book_reader/bound_to(datum/expected_subject, mob/expected_reader)
	return ..() && expected_reader && reader_client == expected_reader.client
