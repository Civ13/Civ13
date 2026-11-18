/datum/circuit_datatype/number
	datatype = PORT_TYPE_NUMBER
	can_receive_from = list(PORT_TYPE_BOOLEAN)
	color = "green"
	manual_error = "Enter a valid number."

/datum/circuit_datatype/number/convert(value)
	if(istext(value))
		value = text2num(value)
	return wiremod_safe_number(value)
