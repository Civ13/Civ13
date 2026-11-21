/obj/item/circuit_component/index_assoc
	name = "index associative list component"
	display_name = "Index Associative List"
	category = "List"
	desc = "Gives the value held under Index in an associative list. A key the list does not hold leaves Value empty."

	var/datum/port/input/list_input
	var/datum/port/input/index_input
	var/datum/port/output/result
	var/datum/port/output/triggered

/obj/item/circuit_component/index_assoc/populate_ports()
	list_input = add_input_port("Assoc List", PORT_TYPE_ASSOC_LIST, trigger = PROC_REF(get_value))
	index_input = add_input_port("Index", PORT_TYPE_STRING, trigger = PROC_REF(get_value))
	result = add_output_port("Value", PORT_TYPE_ANY)
	triggered = add_output_port("Triggered", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/index_assoc/proc/get_value(datum/port/input/input)
	result.set_output(wiremod_assoc_get(list_input.value, index_input.value))
	triggered.set_output(COMPONENT_SIGNAL)
