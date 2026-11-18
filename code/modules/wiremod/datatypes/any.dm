// Untyped: holds whatever a port may hold, and accepts every output.
/datum/circuit_datatype/any
	datatype = PORT_TYPE_ANY
	keeps_port_lists = TRUE
	takes_marked_entity = TRUE
	color = "blue"

// Text that is exactly a number is taken as that number.
/datum/circuit_datatype/any/parse_manual(value)
	if(istext(value))
		var/numeric_value = wiremod_safe_number(text2num(value))
		if(!isnull(numeric_value) && "[numeric_value]" == value)
			return numeric_value
	return convert(value)

/datum/circuit_datatype/any/can_receive_from_datatype(other_type)
	return TRUE
