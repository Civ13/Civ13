/obj/item/circuit_component/format_list
	name = "format list component"
	display_name = "Format List"
	category = "String"
	desc = "Replaces each numbered placeholder in a list's Format text with that entry: %1 with the first, %2 with the second, and so on. A placeholder with no entry behind it is left as it is written."

	var/datum/port/input/list_input
	var/datum/port/input/format_input
	var/datum/port/output/result
	var/datum/port/output/triggered

/obj/item/circuit_component/format_list/populate_ports()
	list_input = add_input_port("List", PORT_TYPE_LIST, trigger = PROC_REF(format_entries))
	format_input = add_input_port("Format", PORT_TYPE_STRING, trigger = PROC_REF(format_entries))
	result = add_output_port("Result", PORT_TYPE_STRING)
	triggered = add_output_port("Triggered", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/format_list/proc/format_entries(datum/port/input/input)
	result.set_output(wiremod_format_text(format_input.value, list_input.value, FALSE))
	triggered.set_output(COMPONENT_SIGNAL)

/obj/item/circuit_component/format_assoc_list
	name = "format associative list component"
	display_name = "Format Associative List"
	category = "String"
	desc = "Replaces each named placeholder in an associative list's Format text with the value under that key: %Name with the entry kept under Name. A key the list does not hold is left as it is written."

	var/datum/port/input/list_input
	var/datum/port/input/format_input
	var/datum/port/output/result
	var/datum/port/output/triggered

/obj/item/circuit_component/format_assoc_list/populate_ports()
	list_input = add_input_port("Assoc List", PORT_TYPE_ASSOC_LIST, trigger = PROC_REF(format_entries))
	format_input = add_input_port("Format", PORT_TYPE_STRING, trigger = PROC_REF(format_entries))
	result = add_output_port("Result", PORT_TYPE_STRING)
	triggered = add_output_port("Triggered", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/format_assoc_list/proc/format_entries(datum/port/input/input)
	result.set_output(wiremod_format_text(format_input.value, list_input.value, TRUE))
	triggered.set_output(COMPONENT_SIGNAL)

// Replaces %<key> in format with the matching entry of values. A numbered key
// reads a flat list by position; a word key reads an associative list by name.
// A placeholder that names no entry is kept exactly as written.
/proc/wiremod_format_text(format, values, is_assoc)
	if(!istext(format))
		return null
	var/result = ""
	var/total = length(format)
	var/position = 1
	while(position <= total)
		var/marker = findtext(format, "%", position)
		if(!marker)
			result += copytext(format, position)
			break
		result += copytext(format, position, marker)
		var/next = marker + 1
		var/key = ""
		while(next <= total)
			var/character = copytext(format, next, next + 1)
			var/readable = is_assoc ? findtext("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_", character) : findtext("0123456789", character)
			if(!readable)
				break
			key += character
			next++
		if(!length(key))
			// A lone percent sign is not a placeholder.
			result += "%"
			position = marker + 1
			continue
		var/replacement = null
		if(is_assoc)
			replacement = wiremod_assoc_get(values, key)
		else if(islist(values))
			var/index = text2num(key)
			if(index >= 1 && index <= length(values))
				replacement = values[index]
		if(isnull(replacement))
			result += copytext(format, marker, next)
		else
			result += wiremod_text_of(replacement)
		position = next
	return wiremod_safe_text(result)
