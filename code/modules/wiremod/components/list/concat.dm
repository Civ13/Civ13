/obj/item/circuit_component/list_concat
	name = "list concatenate component"
	display_name = "List Concat"
	category = "List"

	var/datum/port/input/list_a
	var/datum/port/input/list_b
	var/datum/port/output/result

/obj/item/circuit_component/list_concat/populate_ports()
	list_a = add_input_port("A", PORT_TYPE_LIST, trigger = PROC_REF(concatenate))
	list_b = add_input_port("B", PORT_TYPE_LIST, trigger = PROC_REF(concatenate))
	result = add_output_port("Result", PORT_TYPE_LIST)

/obj/item/circuit_component/list_concat/proc/concatenate(datum/port/input/input)
	var/list/result_list = list()
	if(islist(list_a.value))
		result_list += list_a.value
	if(islist(list_b.value))
		result_list += list_b.value
	result.set_output(result_list)
