/obj/item/circuit_component/string_to_number
	name = "string to number component"
	display_name = "String to Number"
	category = "String"
	desc = "Reads the number at the start of String, such as 12 or -3.5. Text that does not start with a number leaves Number empty."

	var/datum/port/input/value_input
	var/datum/port/output/result

/obj/item/circuit_component/string_to_number/populate_ports()
	value_input = add_input_port("String", PORT_TYPE_STRING, trigger = PROC_REF(convert_number))
	result = add_output_port("Number", PORT_TYPE_NUMBER)

/obj/item/circuit_component/string_to_number/proc/convert_number(datum/port/input/input)
	if(isnull(value_input.value))
		result.set_output(null)
	else
		result.set_output(text2num(value_input.value))
