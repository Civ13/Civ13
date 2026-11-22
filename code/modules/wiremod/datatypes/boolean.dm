// The one reading of a truth value: TRUE, FALSE, or null for anything that is
// not one. Every caller decides for itself what an unreadable value means.
/proc/wiremod_parse_boolean(value)
	if(isnum(value))
		value = wiremod_safe_number(value)
		return isnull(value) ? null : !!value
	if(istext(value))
		var/static/list/words = list("true" = TRUE, "yes" = TRUE, "on" = TRUE, "1" = TRUE, "false" = FALSE, "no" = FALSE, "off" = FALSE, "0" = FALSE)
		return words[lowertext(value)]
	return null

/datum/circuit_datatype/boolean
	datatype = PORT_TYPE_BOOLEAN
	can_receive_from = list(PORT_TYPE_NUMBER)
	color = "bad"
	manual_error = "Enter true or false."

// On a wire, anything that is not a truth value counts as false.
/datum/circuit_datatype/boolean/convert(value)
	return wiremod_parse_boolean(value) ? TRUE : FALSE

/datum/circuit_datatype/boolean/parse_manual(value)
	return wiremod_parse_boolean(value)
