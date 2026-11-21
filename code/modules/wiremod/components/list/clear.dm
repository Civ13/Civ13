/obj/item/circuit_component/list_clear
	name = "list clear component"
	display_name = "List Clear"
	category = "List"
	desc = "Empties the chosen list variable when a signal reaches Trigger, leaving every other variable alone."

	var/datum/port/input/variable_input
	var/datum/port/input/trigger
	var/datum/port/output/triggered

/obj/item/circuit_component/list_clear/populate_ports()
	variable_input = add_input_port("Variable", PORT_TYPE_OPTION, options = list())
	trigger = add_input_port("Trigger", PORT_TYPE_SIGNAL, trigger = PROC_REF(clear_list))
	triggered = add_output_port("Triggered", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/list_clear/added_to_circuit(obj/item/integrated_circuit/circuit)
	refresh_variable_options()

/obj/item/circuit_component/list_clear/refresh_variable_options()
	if(variable_input)
		variable_input.set_input_options(wiremod_list_variable_names(parent))

/obj/item/circuit_component/list_clear/proc/clear_list(datum/port/input/input)
	var/datum/circuit_variable/variable = wiremod_list_variable(parent, variable_input.value)
	if(variable)
		variable.set_value(list())
	triggered.set_output(COMPONENT_SIGNAL)
