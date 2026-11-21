/obj/item/circuit_component/assoc_literal
	name = "associative list literal component"
	display_name = "Associative List Literal"
	category = "List"
	desc = "Builds an associative list from its Key and Value pairs when a signal reaches Trigger. The plus and minus buttons add and remove a pair. A pair with no key or no value is left out, and the last key of a repeated name wins."

	var/datum/port/input/trigger
	var/list/datum/port/input/key_inputs = list()
	var/list/datum/port/input/value_inputs = list()
	var/datum/port/output/list_output
	var/datum/port/output/triggered

/obj/item/circuit_component/assoc_literal/populate_ports()
	trigger = add_input_port("Trigger", PORT_TYPE_SIGNAL, trigger = PROC_REF(build_list))
	key_inputs += add_input_port("Key 1", PORT_TYPE_STRING)
	value_inputs += add_input_port("Value 1", PORT_TYPE_ANY)
	list_output = add_output_port("Assoc List", PORT_TYPE_ASSOC_LIST)
	triggered = add_output_port("Triggered", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/assoc_literal/proc/build_list(datum/port/input/input)
	var/list/built = list()
	for(var/index = 1, index <= length(key_inputs) && length(built) < CIRCUIT_MAX_ASSOC_ENTRIES; index++)
		var/key = wiremod_safe_text(key_inputs[index].value)
		var/value = wiremod_safe_value(value_inputs[index].value)
		if(!length(key) || isnull(value))
			continue
		built[key] = value
	list_output.set_output(built)
	triggered.set_output(COMPONENT_SIGNAL)

/obj/item/circuit_component/assoc_literal/ui_buttons()
	var/list/buttons = list()
	if(length(key_inputs) < CIRCUIT_MAX_LITERAL_ENTRIES)
		buttons["plus"] = "add_pair"
	if(length(key_inputs) > 1)
		buttons["minus"] = "remove_pair"
	return buttons

/obj/item/circuit_component/assoc_literal/ui_perform_action(action_name, mob/user)
	switch(action_name)
		if("add_pair")
			if(length(key_inputs) >= CIRCUIT_MAX_LITERAL_ENTRIES)
				return FALSE
			var/position = length(key_inputs) + 1
			key_inputs += append_input_port("Key [position]", PORT_TYPE_STRING)
			value_inputs += append_input_port("Value [position]", PORT_TYPE_ANY)
			return TRUE
		if("remove_pair")
			if(length(key_inputs) <= 1)
				return FALSE
			var/datum/port/input/last_value = value_inputs[length(value_inputs)]
			value_inputs -= last_value
			remove_last_input_port()
			var/datum/port/input/last_key = key_inputs[length(key_inputs)]
			key_inputs -= last_key
			remove_last_input_port()
			return TRUE
	return FALSE
