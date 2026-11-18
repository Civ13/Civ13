// Port datatypes and ports. A port only ever holds null, a finite number, text
// of at most PORT_MAX_STRING_LENGTH bytes or a list of at most
// CIRCUIT_MAX_LIST_LENGTH such values: the handlers below enforce that on every
// write, so a circuit can neither keep a reference to a game object nor grow a
// value without bound.

/proc/wiremod_safe_number(value)
	if(!isnum(value) || isnan(value) || isinf(value))
		return null
	return value

/proc/wiremod_safe_text(value)
	if(!istext(value))
		return null
	if(length(value) > PORT_MAX_STRING_LENGTH)
		return copytext(value, 1, PORT_MAX_STRING_LENGTH + 1)
	return value

// A bounded list of plain values. Nested lists and objects are dropped.
/proc/wiremod_safe_list(value)
	if(!islist(value))
		return null
	var/list/source = value
	var/list/result = list()
	for(var/index = 1, index <= length(source) && length(result) < CIRCUIT_MAX_LIST_LENGTH, index++)
		var/entry = source[index]
		if(isnum(entry))
			entry = wiremod_safe_number(entry)
		else
			entry = wiremod_safe_text(entry)
		if(!isnull(entry))
			result += entry
	return result

/proc/wiremod_safe_value(value)
	if(isnum(value))
		return wiremod_safe_number(value)
	if(istext(value))
		return wiremod_safe_text(value)
	if(islist(value))
		return wiremod_safe_list(value)
	return null

/datum/circuit_datatype
	should_save = FALSE
	var/datatype
	var/list/can_receive_from = list()

/datum/circuit_datatype/proc/can_receive_from_datatype(other_type)
	return datatype == other_type || (other_type in can_receive_from)

/datum/circuit_datatype/proc/convert(value)
	return wiremod_safe_value(value)

/datum/circuit_datatype/any
	datatype = PORT_TYPE_ANY

/datum/circuit_datatype/any/can_receive_from_datatype(other_type)
	return TRUE

/datum/circuit_datatype/number
	datatype = PORT_TYPE_NUMBER
	can_receive_from = list(PORT_TYPE_BOOLEAN)

/datum/circuit_datatype/number/convert(value)
	if(istext(value))
		value = text2num(value)
	return wiremod_safe_number(value)

/datum/circuit_datatype/boolean
	datatype = PORT_TYPE_BOOLEAN
	can_receive_from = list(PORT_TYPE_NUMBER)

/datum/circuit_datatype/boolean/convert(value)
	if(istext(value))
		return lowertext(value) in list("true", "yes", "on", "1")
	if(isnum(value))
		return !!wiremod_safe_number(value)
	return FALSE

/datum/circuit_datatype/string
	datatype = PORT_TYPE_STRING

/datum/circuit_datatype/string/can_receive_from_datatype(other_type)
	return other_type != PORT_TYPE_LIST && other_type != PORT_TYPE_SIGNAL

/datum/circuit_datatype/string/convert(value)
	if(isnum(value))
		value = wiremod_safe_number(value)
		return isnull(value) ? null : "[value]"
	return wiremod_safe_text(value)

/datum/circuit_datatype/signal
	datatype = PORT_TYPE_SIGNAL

/datum/circuit_datatype/signal/convert(value)
	return wiremod_safe_number(value)

/datum/circuit_datatype/list
	datatype = PORT_TYPE_LIST

/datum/circuit_datatype/list/can_receive_from_datatype(other_type)
	return other_type == PORT_TYPE_LIST || other_type == PORT_TYPE_ANY

/datum/circuit_datatype/list/convert(value)
	return wiremod_safe_list(value)

/proc/circuit_datatype_for(type_key)
	var/static/list/handlers
	if(!handlers)
		handlers = list()
		handlers[PORT_TYPE_ANY] = new /datum/circuit_datatype/any
		handlers[PORT_TYPE_NUMBER] = new /datum/circuit_datatype/number
		handlers[PORT_TYPE_BOOLEAN] = new /datum/circuit_datatype/boolean
		handlers[PORT_TYPE_STRING] = new /datum/circuit_datatype/string
		handlers[PORT_TYPE_SIGNAL] = new /datum/circuit_datatype/signal
		handlers[PORT_TYPE_LIST] = new /datum/circuit_datatype/list
	return istext(type_key) ? handlers[type_key] : null

/datum/port
	should_save = FALSE
	var/name = "Port"
	var/datatype = PORT_TYPE_ANY
	var/value
	var/datum/circuit_datatype/datatype_handler
	var/obj/item/circuit_component/connected_component

/datum/port/New(obj/item/circuit_component/component, port_name, port_type = PORT_TYPE_ANY)
	connected_component = component
	name = port_name
	set_datatype(port_type)

/datum/port/proc/set_datatype(new_type)
	var/datum/circuit_datatype/new_handler = circuit_datatype_for(new_type)
	if(!new_handler)
		CRASH("Unknown Wiremod port datatype '[new_type]'")
	datatype = new_type
	datatype_handler = new_handler
	value = null

/datum/port/proc/set_value(new_value)
	value = datatype_handler.convert(new_value)

// The component and the handler are released so a deleted port never keeps its
// component alive (the component still holds the port in its typed fields).
/datum/port/Destroy()
	connected_component = null
	datatype_handler = null
	value = null
	return ..()

/datum/port/input
	var/datum/port/output/connected_output
	var/trigger
	// When set, the only texts this port accepts; the editor shows a dropdown.
	var/list/options

/datum/port/input/New(obj/item/circuit_component/component, port_name, port_type = PORT_TYPE_ANY, input_trigger = null, default_value = null, list/port_options = null)
	connected_component = component
	name = port_name
	trigger = input_trigger
	options = port_options
	set_datatype(port_type)
	if(!isnull(default_value))
		set_input(default_value, FALSE)

// A value outside a restricted port's choices leaves the current choice alone.
/datum/port/input/set_value(new_value)
	if(options)
		new_value = datatype_handler.convert(new_value)
		if(!(new_value in options))
			return
	..()

// Both ports must sit on components of the same circuit.
/datum/port/input/proc/connect(datum/port/output/output)
	if(!istype(output) || output == connected_output || !datatype_handler || !datatype_handler.can_receive_from_datatype(output.datatype))
		return FALSE
	var/obj/item/integrated_circuit/circuit = connected_component?.parent
	if(!circuit || output.connected_component?.parent != circuit)
		return FALSE
	disconnect()
	connected_output = output
	if(!output.connected_inputs)
		output.connected_inputs = list()
	output.connected_inputs |= src
	if(datatype != PORT_TYPE_SIGNAL)
		set_input(output.value)
	return TRUE

/datum/port/input/proc/disconnect()
	if(connected_output)
		if(connected_output.connected_inputs)
			connected_output.connected_inputs -= src
		connected_output = null

/datum/port/input/proc/set_input(new_value, should_trigger = TRUE)
	set_value(new_value)
	if(should_trigger && trigger && connected_component?.parent)
		connected_component.parent.queue_input(src)

/datum/port/input/Destroy()
	disconnect()
	options = null
	return ..()

/datum/port/output
	var/list/datum/port/input/connected_inputs

/datum/port/output/proc/set_output(new_value)
	set_value(new_value)
	if(!connected_inputs)
		return
	for(var/datum/port/input/input in connected_inputs.Copy())
		input.set_input(value)

/datum/port/output/proc/disconnect_all()
	if(connected_inputs)
		for(var/datum/port/input/input in connected_inputs.Copy())
			input.disconnect()
	value = null

/datum/port/output/Destroy()
	disconnect_all()
	connected_inputs = null
	return ..()
