/obj/item/circuit_component/set_variable_trigger
	name = "set variable trigger component"
	display_name = "Set Variable Trigger"
	category = "Utility"
	desc = "Stores Value in the chosen circuit variable when a signal reaches Trigger, then sends a signal on Output. It does the same as a variable setter node, with a trigger of its own and a picker for the variable."

	var/datum/port/input/variable_input
	var/datum/port/input/value_input
	var/datum/port/input/trigger
	var/datum/port/output/output

/obj/item/circuit_component/set_variable_trigger/populate_ports()
	variable_input = add_input_port("Variable", PORT_TYPE_OPTION, options = list())
	value_input = add_input_port("Value", PORT_TYPE_ANY)
	trigger = add_input_port("Trigger", PORT_TYPE_SIGNAL, trigger = PROC_REF(set_variable))
	output = add_output_port("Output", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/set_variable_trigger/added_to_circuit(obj/item/integrated_circuit/circuit)
	refresh_variable_options()

/obj/item/circuit_component/set_variable_trigger/refresh_variable_options()
	if(variable_input)
		variable_input.set_input_options(wiremod_circuit_variable_names(parent))

/obj/item/circuit_component/set_variable_trigger/proc/set_variable(datum/port/input/input)
	var/datum/circuit_variable/variable = wiremod_circuit_variable(parent, variable_input.value)
	if(!variable || !variable.set_value(value_input.value))
		return
	output.set_output(COMPONENT_SIGNAL)
