/obj/item/circuit_component/concatenate_list
	name = "concatenate list component"
	display_name = "Concatenate List"
	category = "String"
	desc = "Turns a list into text, putting Separator between its entries. A separator left unset is a comma, and an entity entry is written as its name. The result is cut at 5,000 characters."

	var/datum/port/input/list_input
	var/datum/port/input/separator
	var/datum/port/output/result
	var/datum/port/output/triggered

/obj/item/circuit_component/concatenate_list/populate_ports()
	list_input = add_input_port("List", PORT_TYPE_LIST, trigger = PROC_REF(join_list))
	separator = add_input_port("Separator", PORT_TYPE_STRING, trigger = PROC_REF(join_list), default = ",")
	result = add_output_port("Result", PORT_TYPE_STRING)
	triggered = add_output_port("Triggered", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/concatenate_list/proc/join_list(datum/port/input/input)
	var/list/entries = list_input.value
	if(!islist(entries))
		result.set_output(null)
		triggered.set_output(COMPONENT_SIGNAL)
		return
	var/text = ""
	var/glue = isnull(separator.value) ? "," : separator.value
	for(var/index = 1, index <= length(entries); index++)
		if(length(text) >= PORT_MAX_STRING_LENGTH)
			break
		if(index > 1)
			text += glue
		text += wiremod_text_of(entries[index])
	result.set_output(wiremod_safe_text(text))
	triggered.set_output(COMPONENT_SIGNAL)
