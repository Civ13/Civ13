// A pulse that sets a component off. Its value is only the time it was sent.
/datum/circuit_datatype/signal
	datatype = PORT_TYPE_SIGNAL
	color = "teal"

/datum/circuit_datatype/signal/convert(value)
	return wiremod_safe_number(value)
