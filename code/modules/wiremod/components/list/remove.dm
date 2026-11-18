/obj/item/circuit_component/list_remove
	name = "list remove component"
	display_name = "List Remove"
	category = "List"

	var/datum/port/input/list_input
	var/datum/port/input/value_input
	var/datum/port/output/result

/obj/item/circuit_component/list_remove/populate_ports()
	list_input = add_input_port("List", PORT_TYPE_LIST, trigger = PROC_REF(remove_value))
	value_input = add_input_port("Value", PORT_TYPE_ANY, trigger = PROC_REF(remove_value))
	result = add_output_port("Result", PORT_TYPE_LIST)

/obj/item/circuit_component/list_remove/proc/remove_value(datum/port/input/input)
	var/list/source_list = list_input.value
	var/list/result_list = islist(source_list) ? source_list.Copy() : list()
	if(!isnull(value_input.value))
		result_list -= value_input.value
	result.set_output(result_list)
