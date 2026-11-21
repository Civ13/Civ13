// The list variable components add, clear and remove entries of a list the
// circuit keeps, chosen by name in the editor, and act only when a signal
// reaches Trigger. A circuit variable is the only list they can be pointed at,
// so they can never write through a wire into some other component's list.

/obj/item/circuit_component/list_add
	name = "list add component"
	display_name = "List Add"
	category = "List"
	desc = "Adds Value to the end of the chosen list variable when a signal reaches Trigger. A full list (500 entries) stays as it is. Pick the list in the editor."

	var/datum/port/input/variable_input
	var/datum/port/input/value_input
	var/datum/port/input/trigger
	var/datum/port/output/triggered

/obj/item/circuit_component/list_add/populate_ports()
	variable_input = add_input_port("Variable", PORT_TYPE_OPTION, options = list())
	value_input = add_input_port("Value", PORT_TYPE_ANY)
	trigger = add_input_port("Trigger", PORT_TYPE_SIGNAL, trigger = PROC_REF(add_value))
	triggered = add_output_port("Triggered", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/list_add/added_to_circuit(obj/item/integrated_circuit/circuit)
	refresh_variable_options()

/obj/item/circuit_component/list_add/refresh_variable_options()
	if(variable_input)
		variable_input.set_input_options(wiremod_list_variable_names(parent))

/obj/item/circuit_component/list_add/proc/add_value(datum/port/input/input)
	var/datum/circuit_variable/variable = wiremod_list_variable(parent, variable_input.value)
	if(variable)
		var/list/stored = variable.value
		var/list/entries = islist(stored) ? stored.Copy() : list()
		var/value = wiremod_safe_value(value_input.value)
		if(!isnull(value) && length(entries) < CIRCUIT_MAX_LIST_LENGTH)
			entries += value
			variable.set_value(entries)
	triggered.set_output(COMPONENT_SIGNAL)

// The names of the circuit's list variables, in the order the editor lists
// them. Shared by the three list components.
/proc/wiremod_list_variable_names(obj/item/integrated_circuit/circuit)
	var/list/names = list()
	if(!istype(circuit))
		return names
	for(var/variable_name in circuit.circuit_variables)
		var/datum/circuit_variable/variable = circuit.circuit_variables[variable_name]
		if(variable.port_datatype == PORT_TYPE_LIST)
			names += variable_name
	return names

// The list variable a name picks out, or null when it is not a list variable.
/proc/wiremod_list_variable(obj/item/integrated_circuit/circuit, variable_name)
	if(!istype(circuit) || !istext(variable_name) || !(variable_name in circuit.circuit_variables))
		return null
	var/datum/circuit_variable/variable = circuit.circuit_variables[variable_name]
	return variable.port_datatype == PORT_TYPE_LIST ? variable : null
