// Circuit variables: a named value a circuit keeps, written by setter nodes and
// read by getter nodes.

/datum/circuit_variable
	should_save = FALSE
	var/name
	var/datatype
	var/port_datatype
	var/datum/circuit_datatype/handler
	var/color
	var/value
	var/is_list = FALSE
	var/is_assoc = FALSE
	var/list/obj/item/circuit_component/variable/getter/listeners = list()

/datum/circuit_variable/New(variable_name, variable_datatype, variable_is_list = FALSE, variable_is_assoc = FALSE)
	. = ..()
	name = variable_name
	datatype = variable_datatype
	is_list = variable_is_list
	is_assoc = variable_is_assoc
	if(is_assoc)
		port_datatype = PORT_TYPE_ASSOC_LIST
	else if(is_list)
		port_datatype = PORT_TYPE_LIST
	else
		port_datatype = datatype
	handler = circuit_datatype_for(port_datatype)
	color = handler.color
	if(is_list || is_assoc)
		value = list()

/datum/circuit_variable/proc/set_value(new_value)
	if((port_datatype == PORT_TYPE_LIST || port_datatype == PORT_TYPE_ASSOC_LIST) && !islist(new_value))
		return FALSE
	// The list handler returns a bounded copy, so the variable never shares a
	// list with the port that set it.
	var/converted = handler.convert(new_value)
	// The associative list handler gives null for a list it rejects.
	if(port_datatype == PORT_TYPE_ASSOC_LIST && isnull(converted))
		return FALSE
	value = converted
	for(var/obj/item/circuit_component/variable/getter/listener as anything in listeners.Copy())
		if(listener.parent)
			listener.value_output.set_output(value)
	return TRUE

/datum/circuit_variable/Destroy()
	listeners.Cut()
	handler = null
	value = null
	return ..()

// The caller has checked the name, the datatype and the variable limit.
/obj/item/integrated_circuit/proc/add_variable(variable_name, variable_datatype, is_list, is_assoc = FALSE)
	var/datum/circuit_variable/variable = new(variable_name, variable_datatype, is_list, is_assoc)
	circuit_variables[variable_name] = variable
	refresh_variable_options()
	return variable

// Deletes a variable together with every node that reads or writes it.
/obj/item/integrated_circuit/proc/remove_variable(datum/circuit_variable/variable)
	for(var/obj/item/circuit_component/variable/node in attached_components.Copy())
		if(node.circuit_variable == variable)
			qdel(node)
	circuit_variables -= variable.name
	qdel(variable)
	refresh_variable_options()

// A node only exists tied to a variable, so it is always deleted on removal and
// never handed out as an item.
/obj/item/circuit_component/variable
	display_name = "Variable"
	desc = "Reads or writes a circuit variable: a named value the circuit keeps."
	category = "Utility"
	printed = TRUE

	var/datum/circuit_variable/circuit_variable

// Ties the node to its variable: its port takes the variable's datatype. The
// node is already in its circuit.
/obj/item/circuit_component/variable/proc/bind(datum/circuit_variable/variable)
	circuit_variable = variable

/obj/item/circuit_component/variable/proc/unbind()
	if(circuit_variable)
		circuit_variable.listeners -= src
		circuit_variable = null

/obj/item/circuit_component/variable/removed_from_circuit(obj/item/integrated_circuit/circuit)
	unbind()

/obj/item/circuit_component/variable/Destroy()
	unbind()
	return ..()

/obj/item/circuit_component/variable/getter
	display_name = "Variable Getter"
	desc = "Gives the current value of its variable, and gives it again whenever the variable changes."

	var/datum/port/output/value_output

/obj/item/circuit_component/variable/getter/populate_ports()
	value_output = add_output_port("Value", PORT_TYPE_ANY)

/obj/item/circuit_component/variable/getter/bind(datum/circuit_variable/variable)
	..()
	display_name = "Getter: [variable.name]"
	value_output.set_datatype(variable.port_datatype)
	variable.listeners += src
	value_output.set_output(variable.value)

/obj/item/circuit_component/variable/setter
	display_name = "Variable Setter"
	desc = "Stores its Input in its variable whenever Input changes. Every getter of that variable then gives the new value."

	var/datum/port/input/value_input

/obj/item/circuit_component/variable/setter/populate_ports()
	value_input = add_input_port("Input", PORT_TYPE_ANY, trigger = PROC_REF(set_variable))

/obj/item/circuit_component/variable/setter/bind(datum/circuit_variable/variable)
	..()
	display_name = "Setter: [variable.name]"
	value_input.set_datatype(variable.port_datatype)

/obj/item/circuit_component/variable/setter/proc/set_variable(datum/port/input/input_port)
	if(circuit_variable)
		circuit_variable.set_value(input_port.value)

// A setter that waits for a signal, so it can be told when to write instead of
// writing on every change of its input. It passes the signal on when it is done.
/obj/item/circuit_component/variable/triggered_setter
	display_name = "Triggered Setter"
	desc = "Stores Value in its variable when a signal reaches Trigger, then sends a signal on Output."

	var/datum/port/input/value_input
	var/datum/port/input/trigger
	var/datum/port/output/output

/obj/item/circuit_component/variable/triggered_setter/populate_ports()
	value_input = add_input_port("Value", PORT_TYPE_ANY)
	trigger = add_input_port("Trigger", PORT_TYPE_SIGNAL, trigger = PROC_REF(set_variable))
	output = add_output_port("Output", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/variable/triggered_setter/bind(datum/circuit_variable/variable)
	..()
	display_name = "Triggered Setter: [variable.name]"
	value_input.set_datatype(variable.port_datatype)

/obj/item/circuit_component/variable/triggered_setter/proc/set_variable(datum/port/input/input_port)
	if(circuit_variable)
		circuit_variable.set_value(value_input.value)
	output.set_output(COMPONENT_SIGNAL)

// The names of the circuit's variables, in the order the editor lists them.
/proc/wiremod_circuit_variable_names(obj/item/integrated_circuit/circuit)
	var/list/names = list()
	if(!istype(circuit))
		return names
	for(var/variable_name in circuit.circuit_variables)
		names += variable_name
	return names

// The variable a name picks out, or null when there is none.
/proc/wiremod_circuit_variable(obj/item/integrated_circuit/circuit, variable_name)
	if(!istype(circuit) || !istext(variable_name) || !(variable_name in circuit.circuit_variables))
		return null
	return circuit.circuit_variables[variable_name]
