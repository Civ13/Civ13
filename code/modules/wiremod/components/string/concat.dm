/obj/item/circuit_component/operator/string_concat
	name = "string concat component"
	display_name = "Concatenation"
	category = "String"
	desc = "Joins 2 to 10 text inputs end to end. An input that is not set counts as empty text, and a number is joined as its digits. The plus and minus buttons add and remove an input. The result is cut at 5,000 characters."

	var/list/datum/port/input/string_inputs = list()

/obj/item/circuit_component/operator/string_concat/populate_ports()
	string_inputs += add_input_port("String 1", PORT_TYPE_STRING, trigger = PROC_REF(concatenate))
	string_inputs += add_input_port("String 2", PORT_TYPE_STRING, trigger = PROC_REF(concatenate))
	result = add_output_port("Result", PORT_TYPE_STRING)
	triggered = add_output_port("Triggered", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/operator/string_concat/proc/concatenate(datum/port/input/input)
	var/joined = ""
	for(var/datum/port/input/string_port as anything in string_inputs)
		if(!isnull(string_port.value))
			joined = "[joined][string_port.value]"
	result.set_output(joined)
	triggered.set_output(COMPONENT_SIGNAL)

/obj/item/circuit_component/operator/string_concat/ui_buttons()
	var/list/buttons = list()
	if(length(string_inputs) < CIRCUIT_MAX_CONCAT_INPUTS)
		buttons["plus"] = "add_input"
	if(length(string_inputs) > 2)
		buttons["minus"] = "remove_input"
	return buttons

/obj/item/circuit_component/operator/string_concat/ui_perform_action(action_name, mob/user)
	switch(action_name)
		if("add_input")
			if(length(string_inputs) >= CIRCUIT_MAX_CONCAT_INPUTS)
				return FALSE
			string_inputs += append_input_port("String [length(string_inputs) + 1]", PORT_TYPE_STRING, PROC_REF(concatenate))
			concatenate(null)
			return TRUE
		if("remove_input")
			if(length(string_inputs) <= 2)
				return FALSE
			var/datum/port/input/last_port = string_inputs[length(string_inputs)]
			string_inputs -= last_port
			remove_last_input_port()
			concatenate(null)
			return TRUE
	return FALSE
