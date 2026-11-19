/obj/item/circuit_component/typecast
	name = "typecast component"
	display_name = "Typecast"
	category = "Math"
	desc = "Gives Value back when it is already of the chosen Type, and nothing when it is not. The types are Number, String, Boolean, List, Associative List and Entity."

	var/datum/port/input/value_input
	var/datum/port/input/type_input
	var/datum/port/output/result
	var/datum/port/output/triggered

/obj/item/circuit_component/typecast/populate_ports()
	value_input = add_input_port("Value", PORT_TYPE_ANY, trigger = PROC_REF(cast_value))
	type_input = add_input_port("Type", PORT_TYPE_OPTION, trigger = PROC_REF(cast_value), default = "Number", options = list("Number", "String", "Boolean", "List", "Associative List", "Entity"))
	result = add_output_port("Result", PORT_TYPE_ANY)
	triggered = add_output_port("Triggered", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/typecast/proc/cast_value(datum/port/input/input)
	result.set_output(wiremod_value_is_type(value_input.value, type_input.value) ? value_input.value : null)
	triggered.set_output(COMPONENT_SIGNAL)

// TRUE when a port value is of the named type. Shared with the Typecheck
// component so both read a value the same way.
/proc/wiremod_value_is_type(value, type_name)
	switch(type_name)
		if("Number")
			return isnum(value)
		if("String")
			return istext(value)
		if("Boolean")
			return isnum(value) && (value == 0 || value == 1)
		if("List")
			return islist(value) && !wiremod_is_assoc_list(value)
		if("Associative List")
			return wiremod_is_assoc_list(value)
		if("Entity")
			return istype(value, /datum/weakref)
	return FALSE

/obj/item/circuit_component/typecheck
	name = "typecheck component"
	display_name = "Typecheck"
	category = "Math"
	desc = "Names the kind of value Value holds: number, string, boolean, list, associative list, entity or none."

	var/datum/port/input/value_input
	var/datum/port/output/type_output
	var/datum/port/output/triggered

/obj/item/circuit_component/typecheck/populate_ports()
	value_input = add_input_port("Value", PORT_TYPE_ANY, trigger = PROC_REF(check_value))
	type_output = add_output_port("Type", PORT_TYPE_STRING)
	triggered = add_output_port("Triggered", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/typecheck/proc/check_value(datum/port/input/input)
	var/value = value_input.value
	if(isnull(value))
		type_output.set_output("none")
	else if(isnum(value))
		type_output.set_output((value == 0 || value == 1) ? "boolean" : "number")
	else if(istext(value))
		type_output.set_output("string")
	else if(islist(value))
		type_output.set_output(wiremod_is_assoc_list(value) ? "associative list" : "list")
	else if(istype(value, /datum/weakref))
		type_output.set_output("entity")
	else
		type_output.set_output("none")
	triggered.set_output(COMPONENT_SIGNAL)
