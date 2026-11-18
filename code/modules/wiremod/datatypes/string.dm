/datum/circuit_datatype/string
	datatype = PORT_TYPE_STRING
	color = "orange"

/datum/circuit_datatype/string/can_receive_from_datatype(other_type)
	return other_type != PORT_TYPE_LIST && other_type != PORT_TYPE_SIGNAL

// A number becomes its digits and an entity its name.
/datum/circuit_datatype/string/convert(value)
	if(isnum(value))
		value = wiremod_safe_number(value)
		return isnull(value) ? null : "[value]"
	if(istext(value))
		return wiremod_safe_text(value)
	return wiremod_entity_name(value)
