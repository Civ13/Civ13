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
	var/list/obj/item/circuit_component/variable/getter/listeners = list()

/datum/circuit_variable/New(variable_name, variable_datatype, variable_is_list = FALSE)
	. = ..()
	name = variable_name
	datatype = variable_datatype
	is_list = variable_is_list
	port_datatype = is_list ? PORT_TYPE_LIST : datatype
	handler = circuit_datatype_for(port_datatype)
	color = handler.color
	if(is_list)
		value = list()

/datum/circuit_variable/proc/set_value(new_value)
	if(port_datatype == PORT_TYPE_LIST && !islist(new_value))
		return FALSE
	// The list handler returns a bounded copy, so the variable never shares a
	// list with the port that set it.
	value = handler.convert(new_value)
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
/obj/item/integrated_circuit/proc/add_variable(variable_name, variable_datatype, is_list)
	var/datum/circuit_variable/variable = new(variable_name, variable_datatype, is_list)
	circuit_variables[variable_name] = variable
	return variable

// Deletes a variable together with every node that reads or writes it.
/obj/item/integrated_circuit/proc/remove_variable(datum/circuit_variable/variable)
	for(var/obj/item/circuit_component/variable/node in attached_components.Copy())
		if(node.circuit_variable == variable)
			qdel(node)
	circuit_variables -= variable.name
	qdel(variable)

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
