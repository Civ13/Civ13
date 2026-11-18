/obj/item/circuit_component/length
	name = "length component"
	display_name = "Length"
	category = "Math"

	var/datum/port/input/value_input
	var/datum/port/output/result

/obj/item/circuit_component/length/populate_ports()
	value_input = add_input_port("Value", PORT_TYPE_ANY, trigger = PROC_REF(calculate))
	result = add_output_port("Length", PORT_TYPE_NUMBER)

/obj/item/circuit_component/length/proc/calculate(datum/port/input/input)
	if(istext(value_input.value) || islist(value_input.value))
		result.set_output(length(value_input.value))
	else
		result.set_output(null)
