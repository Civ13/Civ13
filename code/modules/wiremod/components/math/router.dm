/obj/item/circuit_component/router
	name = "router component"
	display_name = "Router"
	category = "Math"
	desc = "Sends the input named by Input Selector to the output named by Output Selector: both count from 1 to 4. The other outputs keep whatever they last held."

	var/list/datum/port/input/inputs = list()
	var/datum/port/input/input_selector
	var/datum/port/input/output_selector
	var/list/datum/port/output/outputs = list()
	var/datum/port/output/triggered

/obj/item/circuit_component/router/populate_ports()
	for(var/index = 1, index <= 4, index++)
		inputs += add_input_port("Input [index]", PORT_TYPE_ANY, trigger = PROC_REF(route_input))
	input_selector = add_input_port("Input Selector", PORT_TYPE_NUMBER, trigger = PROC_REF(route_input), default = 1)
	output_selector = add_input_port("Output Selector", PORT_TYPE_NUMBER, trigger = PROC_REF(route_input), default = 1)
	for(var/index = 1, index <= 4, index++)
		outputs += add_output_port("Output [index]", PORT_TYPE_ANY)
	triggered = add_output_port("Triggered", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/router/proc/route_input(datum/port/input/input)
	var/input_index = valid_selector(input_selector.value)
	var/output_index = valid_selector(output_selector.value)
	if(input_index && output_index)
		outputs[output_index].set_output(inputs[input_index].value)
	triggered.set_output(COMPONENT_SIGNAL)

/obj/item/circuit_component/router/proc/valid_selector(value)
	if(!isnum(value) || value != round(value) || value < 1 || value > 4)
		return 0
	return value
