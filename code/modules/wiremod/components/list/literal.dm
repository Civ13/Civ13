/obj/item/circuit_component/list_literal
	name = "list literal component"
	display_name = "List Literal"
	category = "List"
	desc = "Builds a list out of its Value inputs, in order, whenever a signal reaches Trigger. The plus and minus buttons add and remove an entry. An input that is not set is left out."

	var/datum/port/input/trigger
	var/list/datum/port/input/value_inputs = list()
	var/datum/port/output/list_output
	var/datum/port/output/triggered

/obj/item/circuit_component/list_literal/populate_ports()
	trigger = add_input_port("Trigger", PORT_TYPE_SIGNAL, trigger = PROC_REF(build_list))
	value_inputs += add_input_port("Value 1", PORT_TYPE_ANY)
	value_inputs += add_input_port("Value 2", PORT_TYPE_ANY)
	list_output = add_output_port("List", PORT_TYPE_LIST)
	triggered = add_output_port("Triggered", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/list_literal/proc/build_list(datum/port/input/input)
	var/list/built = list()
	for(var/datum/port/input/value_port as anything in value_inputs)
		if(!isnull(value_port.value) && length(built) < CIRCUIT_MAX_LIST_LENGTH)
			built += value_port.value
	list_output.set_output(built)
	triggered.set_output(COMPONENT_SIGNAL)

/obj/item/circuit_component/list_literal/ui_buttons()
	var/list/buttons = list()
	if(length(value_inputs) < CIRCUIT_MAX_LITERAL_ENTRIES)
		buttons["plus"] = "add_entry"
	if(length(value_inputs) > 1)
		buttons["minus"] = "remove_entry"
	return buttons

/obj/item/circuit_component/list_literal/ui_perform_action(action_name, mob/user)
	switch(action_name)
		if("add_entry")
			if(length(value_inputs) >= CIRCUIT_MAX_LITERAL_ENTRIES)
				return FALSE
			value_inputs += append_input_port("Value [length(value_inputs) + 1]", PORT_TYPE_ANY)
			build_list(null)
			return TRUE
		if("remove_entry")
			if(length(value_inputs) <= 1)
				return FALSE
			var/datum/port/input/last_port = value_inputs[length(value_inputs)]
			value_inputs -= last_port
			remove_last_input_port()
			build_list(null)
			return TRUE
	return FALSE
