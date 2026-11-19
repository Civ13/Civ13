/obj/item/circuit_component/tostring
	name = "to string component"
	display_name = "To String"
	category = "String"
	desc = "Writes any value as text: a number as its digits, a thing in the world as its name, and a list as the word list. An unset value becomes empty text."

	var/datum/port/input/value_input
	var/datum/port/output/result
	var/datum/port/output/triggered

/obj/item/circuit_component/tostring/populate_ports()
	value_input = add_input_port("Value", PORT_TYPE_ANY, trigger = PROC_REF(convert_value))
	result = add_output_port("String", PORT_TYPE_STRING)
	triggered = add_output_port("Triggered", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/tostring/proc/convert_value(datum/port/input/input)
	result.set_output(wiremod_safe_text(wiremod_text_of(value_input.value)))
	triggered.set_output(COMPONENT_SIGNAL)
