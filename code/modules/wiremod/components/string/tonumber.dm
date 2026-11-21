/obj/item/circuit_component/string_to_number
	name = "string to number component"
	display_name = "String to Number"
	category = "String"
	desc = "Reads String as a number when the whole text is a number, such as 12, -3.5 or 1e7. Text with anything else in it leaves Number empty."

	var/datum/port/input/value_input
	var/datum/port/output/result
	var/datum/port/output/triggered
	var/static/regex/numeric = regex(@"^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?$")

/obj/item/circuit_component/string_to_number/populate_ports()
	value_input = add_input_port("String", PORT_TYPE_STRING, trigger = PROC_REF(convert_number))
	result = add_output_port("Number", PORT_TYPE_NUMBER)
	triggered = add_output_port("Triggered", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/string_to_number/proc/convert_number(datum/port/input/input)
	var/text = value_input.value
	if(istext(text) && numeric.Find(text))
		result.set_output(text2num(text))
	else
		result.set_output(null)
	triggered.set_output(COMPONENT_SIGNAL)
