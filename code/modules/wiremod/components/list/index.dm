/obj/item/circuit_component/list_index
	name = "list index component"
	display_name = "List Index"
	category = "List"
	desc = "Gives the entry of List at position Index. Positions count from 1. An Index outside the list leaves Value empty."

	var/datum/port/input/list_input
	var/datum/port/input/index_input
	var/datum/port/output/result

/obj/item/circuit_component/list_index/populate_ports()
	list_input = add_input_port("List", PORT_TYPE_LIST, trigger = PROC_REF(get_value))
	index_input = add_input_port("Index", PORT_TYPE_NUMBER, trigger = PROC_REF(get_value), default = 1)
	result = add_output_port("Value", PORT_TYPE_ANY)

/obj/item/circuit_component/list_index/proc/get_value(datum/port/input/input)
	var/list/source = list_input.value
	var/index = isnum(index_input.value) ? round(index_input.value) : 0
	if(!islist(source) || index < 1 || index > length(source))
		result.set_output(null)
		return
	result.set_output(source[index])
