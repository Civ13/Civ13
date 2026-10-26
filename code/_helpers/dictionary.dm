// Dictionary rows stay ordered: later replacements consume earlier output.
/proc/parse_dictionary_lines(var/list/lines)
	var/list/entries = list()
	var/line_number = 0
	for (var/line in lines)
		line_number++
		if (!findtext(line, ","))
			continue
		var/list/entry = splittext(line, ",")
		if (entry.len != 2 && entry.len != 3)
			world.log << "Error! config/dictionary.txt line [line_number] has [entry.len] fields (expected 2 or 3); skipped."
			continue
		if (entry.len == 3)
			// Validate text before conversion: empty text must never become era 0.
			var/selector = trim(entry[3])
			if (!(selector in list("0", "1", "2", "3", "4", "5", "6", "7", "8")))
				world.log << "Error! config/dictionary.txt line [line_number] has invalid era selector '[selector]' (expected 0-8); skipped."
				continue
			entry[3] = text2num(selector)
		entries += list(entry)
	return entries

/proc/apply_dictionary_replacements(var/message)
	for (var/list/entry in dictionary_list)
		// Read the live research era; display age can lag prototype discoveries.
		// Test field presence rather than truthiness because era 0 is restricted.
		if (entry.len == 3 && (!map || entry[3] != map.ordinal_age))
			continue
		message = replacetext(message, entry[1], entry[2])
	return message
