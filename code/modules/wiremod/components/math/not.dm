/obj/item/circuit_component/not
	name = "not component"
	display_name = "Not"
	category = "Math"
	desc = "Gives the opposite of its input: true becomes false and false becomes true. An input that is not set counts as false."

	var/datum/port/input/value_input
	var/datum/port/output/result

/obj/item/circuit_component/not/populate_ports()
	value_input = add_input_port("Input", PORT_TYPE_BOOLEAN, trigger = PROC_REF(invert))
	result = add_output_port("Result", PORT_TYPE_BOOLEAN)

/obj/item/circuit_component/not/proc/invert(datum/port/input/input)
	result.set_output(!value_input.value)
