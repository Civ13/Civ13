// Dictionary rows stay ordered: later replacements consume earlier output.
/proc/parse_dictionary_lines(var/list/lines)
	var/list/entries = list()
	var/line_number = 0
	for (var/line in lines)
		line_number++
		if (!findtext(line, ","))
			continue
		var/list/entry = splittext(line, ",")
		if (entry.len != 2 && entry.len != 3 && entry.len != 4)
			world.log << "Error! config/dictionary.txt line [line_number] has [entry.len] fields (expected 2, 3 or 4); skipped."
			continue
		if (entry.len >= 3)
			// Validate text before conversion: empty text must never become era 0.
			var/selector = trim(entry[3])
			if (!(selector in list("0", "1", "2", "3", "4", "5", "6", "7", "8")))
				world.log << "Error! config/dictionary.txt line [line_number] has invalid era selector '[selector]' (expected 0-8); skipped."
				continue
			entry[3] = text2num(selector)
		if (entry.len == 4)
			var/mode = trim(entry[4])
			if (mode != "phrase")
				world.log << "Error! config/dictionary.txt line [line_number] has invalid mode '[mode]' (expected phrase); skipped."
				continue
			var/valid_phrase = length(entry[1]) && entry[1] == trim(entry[1])
			for (var/position = 1, position <= length(entry[1]), position++)
				if (text2ascii(entry[1], position) > 127)
					valid_phrase = FALSE
			if (!valid_phrase)
				world.log << "Error! config/dictionary.txt line [line_number] has invalid phrase source (expected nonempty ASCII without outer whitespace); skipped."
				continue
			entry[4] = mode
		entries += list(entry)
	return entries

// Only known ASCII separators are boundaries. Apostrophes, hyphens, word
// characters and unknown Unicode neighbors remain continuations.
/proc/dictionary_phrase_boundary(var/message, var/position)
	if (position < 1 || position > length(message))
		return TRUE
	switch (text2ascii(message, position))
		if (9, 10, 11, 12, 13, 32, 33, 34, 40, 41, 44, 46, 58, 59, 63, 91, 93, 123, 125)
			return TRUE
	return FALSE

/proc/replace_dictionary_phrase(var/message, var/source, var/replacement)
	var/source_length = length(source)
	if (!source_length)
		return message
	var/result = ""
	var/copied_through = 1
	var/search_from = 1
	var/match_at = findtext(message, source, search_from)
	while (match_at)
		if (dictionary_phrase_boundary(message, match_at - 1) && dictionary_phrase_boundary(message, match_at + source_length))
			result += copytext(message, copied_through, match_at) + replacement
			copied_through = match_at + source_length
			search_from = copied_through
		else
			search_from = match_at + 1
		match_at = findtext(message, source, search_from)
	return result + copytext(message, copied_through)

/proc/apply_dictionary_replacements(var/message)
	for (var/list/entry in dictionary_list)
		// Read the live research era; display age can lag prototype discoveries.
		// Test field presence rather than truthiness because era 0 is restricted.
		if (entry.len >= 3 && (!map || entry[3] != map.ordinal_age))
			continue
		if (entry.len == 4)
			if (entry[4] != "phrase")
				continue
			message = replace_dictionary_phrase(message, entry[1], entry[2])
		else
			message = replacetext(message, entry[1], entry[2])
	return message
