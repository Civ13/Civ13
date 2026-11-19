/obj/item/circuit_component/length
	name = "length component"
	display_name = "Length"
	category = "Math"
	desc = "Counts the characters in a text, or the entries in a list or associative list. A number, an entity or an empty input counts as 0."

	var/datum/port/input/value_input
	var/datum/port/output/result
	var/datum/port/output/triggered

/obj/item/circuit_component/length/populate_ports()
	value_input = add_input_port("Value", PORT_TYPE_ANY, trigger = PROC_REF(calculate))
	result = add_output_port("Length", PORT_TYPE_NUMBER)
	triggered = add_output_port("Triggered", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/length/proc/calculate(datum/port/input/input)
	if(istext(value_input.value) || islist(value_input.value))
		result.set_output(length(value_input.value))
	else
		result.set_output(0)
	triggered.set_output(COMPONENT_SIGNAL)
