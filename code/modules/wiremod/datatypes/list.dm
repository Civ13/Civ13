// A bounded list of numbers, texts and things in the world. A thing in the world
// is kept as its weak reference, never the thing itself: a stale reference
// simply stops resolving. Nested lists and real objects are dropped.
/proc/wiremod_safe_list(value)
	if(!islist(value))
		return null
	var/list/source = value
	var/list/result = list()
	for(var/index = 1, index <= length(source) && length(result) < CIRCUIT_MAX_LIST_LENGTH, index++)
		var/entry = source[index]
		if(isnum(entry))
			entry = wiremod_safe_number(entry)
		else if(istext(entry))
			entry = wiremod_safe_text(entry)
		else
			entry = wiremod_safe_entity(entry)
		if(!isnull(entry))
			result += entry
	return result

/datum/circuit_datatype/list
	datatype = PORT_TYPE_LIST
	can_receive_from = list(PORT_TYPE_ANY)
	color = "white"
	keeps_port_lists = TRUE

/datum/circuit_datatype/list/convert(value)
	return wiremod_safe_list(value)
