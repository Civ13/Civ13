/obj/item/circuit_component/list_add
	name = "list add component"
	display_name = "List Add"
	category = "List"

	var/datum/port/input/list_input
	var/datum/port/input/value_input
	var/datum/port/output/result

/obj/item/circuit_component/list_add/populate_ports()
	list_input = add_input_port("List", PORT_TYPE_LIST, trigger = PROC_REF(add_value))
	value_input = add_input_port("Value", PORT_TYPE_ANY, trigger = PROC_REF(add_value))
	result = add_output_port("Result", PORT_TYPE_LIST)

/obj/item/circuit_component/list_add/proc/add_value(datum/port/input/input)
	var/list/source_list = list_input.value
	var/list/result_list = islist(source_list) ? source_list.Copy() : list()
	// A full list stays as it is; a list value is appended entry by entry.
	if(!isnull(value_input.value) && length(result_list) < CIRCUIT_MAX_LIST_LENGTH)
		result_list += value_input.value
	result.set_output(result_list)
