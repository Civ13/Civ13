/obj/item/circuit_component/not
	name = "not component"
	display_name = "Not"
	category = "Math"
	desc = "Outputs 1 when its input is exactly zero or not set, and 0 for anything else."

	var/datum/port/input/value_input
	var/datum/port/output/result
	var/datum/port/output/triggered

/obj/item/circuit_component/not/populate_ports()
	value_input = add_input_port("Input", PORT_TYPE_ANY, trigger = PROC_REF(invert))
	result = add_output_port("Result", PORT_TYPE_BOOLEAN)
	triggered = add_output_port("Triggered", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/not/proc/invert(datum/port/input/input)
	result.set_output(isnull(value_input.value) || (isnum(value_input.value) && value_input.value == 0))
	triggered.set_output(COMPONENT_SIGNAL)
