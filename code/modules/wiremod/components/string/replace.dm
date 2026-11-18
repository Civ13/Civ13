/obj/item/circuit_component/string_replace
	name = "string replace component"
	display_name = "String Replace"
	category = "String"

	var/datum/port/input/value_input
	var/datum/port/input/search
	var/datum/port/input/replacement
	var/datum/port/output/result

/obj/item/circuit_component/string_replace/populate_ports()
	value_input = add_input_port("String", PORT_TYPE_STRING, trigger = PROC_REF(replace_text))
	search = add_input_port("Search", PORT_TYPE_STRING, trigger = PROC_REF(replace_text))
	replacement = add_input_port("Replacement", PORT_TYPE_STRING, trigger = PROC_REF(replace_text))
	result = add_output_port("Result", PORT_TYPE_STRING)

/obj/item/circuit_component/string_replace/proc/replace_text(datum/port/input/input)
	if(isnull(value_input.value) || !length(search.value))
		result.set_output(value_input.value)
		return
	var/replacement_text = isnull(replacement.value) ? "" : replacement.value
	if(length(replacement_text) <= length(search.value))
		result.set_output(replacetext(value_input.value, search.value, replacement_text))
		return
	// A longer replacement can multiply the text, so it is built piece by piece
	// and stops at the port's limit instead of allocating the whole product.
	var/list/pieces = list()
	var/built = 0
	var/position = 1
	var/found = findtext(value_input.value, search.value, position)
	while(found && built < PORT_MAX_STRING_LENGTH)
		pieces += copytext(value_input.value, position, found)
		pieces += replacement_text
		built += (found - position) + length(replacement_text)
		position = found + length(search.value)
		found = findtext(value_input.value, search.value, position)
	pieces += copytext(value_input.value, position)
	result.set_output(jointext(pieces, ""))
