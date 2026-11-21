/obj/item/circuit_component/list_remove
	name = "list remove component"
	display_name = "List Remove"
	category = "List"
	desc = "Removes the first entry equal to Value from the chosen list variable when a signal reaches Trigger. A Value the list does not hold leaves it unchanged."

	var/datum/port/input/variable_input
	var/datum/port/input/value_input
	var/datum/port/input/trigger
	var/datum/port/output/triggered

/obj/item/circuit_component/list_remove/populate_ports()
	variable_input = add_input_port("Variable", PORT_TYPE_OPTION, options = list())
	value_input = add_input_port("Value", PORT_TYPE_ANY)
	trigger = add_input_port("Trigger", PORT_TYPE_SIGNAL, trigger = PROC_REF(remove_value))
	triggered = add_output_port("Triggered", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/list_remove/added_to_circuit(obj/item/integrated_circuit/circuit)
	refresh_variable_options()

/obj/item/circuit_component/list_remove/refresh_variable_options()
	if(variable_input)
		variable_input.set_input_options(wiremod_list_variable_names(parent))

/obj/item/circuit_component/list_remove/proc/remove_value(datum/port/input/input)
	var/datum/circuit_variable/variable = wiremod_list_variable(parent, variable_input.value)
	if(variable)
		var/list/stored = variable.value
		var/list/entries = islist(stored) ? stored.Copy() : list()
		var/value = wiremod_safe_value(value_input.value)
		// A list Value would remove each of its entries, so it removes nothing.
		if(!isnull(value) && !islist(value))
			entries -= value
			variable.set_value(entries)
	triggered.set_output(COMPONENT_SIGNAL)
