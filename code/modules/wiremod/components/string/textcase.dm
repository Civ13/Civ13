/obj/item/circuit_component/string_case
	name = "string case component"
	display_name = "String Case"
	category = "String"
	desc = "Turns String into all small letters (Lower) or all capital letters (Upper), as chosen in Case."

	var/datum/port/input/value_input
	var/datum/port/input/operation
	var/datum/port/output/result

/obj/item/circuit_component/string_case/populate_ports()
	value_input = add_input_port("String", PORT_TYPE_STRING, trigger = PROC_REF(convert_case))
	operation = add_input_port("Case", PORT_TYPE_OPTION, trigger = PROC_REF(convert_case), default = "Lower", options = list("Lower", "Upper"))
	result = add_output_port("Result", PORT_TYPE_STRING)

/obj/item/circuit_component/string_case/proc/convert_case(datum/port/input/input)
	if(isnull(value_input.value))
		result.set_output(null)
	else if(operation.value == "Upper")
		result.set_output(uppertext(value_input.value))
	else
		result.set_output(lowertext(value_input.value))
