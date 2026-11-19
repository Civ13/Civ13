/obj/item/circuit_component/multiplexer
	name = "multiplexer component"
	display_name = "Multiplexer"
	category = "Math"
	desc = "Gives the value of the input named by Selector: 1 to 4. A Selector outside that range, or one that is not whole, gives nothing."

	var/list/datum/port/input/inputs = list()
	var/datum/port/input/selector
	var/datum/port/output/output
	var/datum/port/output/triggered

/obj/item/circuit_component/multiplexer/populate_ports()
	for(var/index = 1, index <= 4, index++)
		inputs += add_input_port("Input [index]", PORT_TYPE_ANY, trigger = PROC_REF(select_input))
	selector = add_input_port("Selector", PORT_TYPE_NUMBER, trigger = PROC_REF(select_input), default = 1)
	output = add_output_port("Output", PORT_TYPE_ANY)
	triggered = add_output_port("Triggered", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/multiplexer/proc/select_input(datum/port/input/input)
	var/index = 0
	if(isnum(selector.value) && selector.value == round(selector.value) && selector.value >= 1 && selector.value <= 4)
		index = selector.value
	output.set_output(index ? inputs[index].value : null)
	triggered.set_output(COMPONENT_SIGNAL)
