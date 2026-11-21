// An associative list: text keys to plain values. A port holds a bounded copy,
// never the list it was handed, so a wire can neither smuggle in a game object
// nor grow a value without bound. Values are a finite number, bounded text or
// a thing's weak reference, like the entries of a plain list.
//
// A list is read as associative when it has at least one key that is not a
// position (1, 2, 3 ...). A plain list built by appending from 1 never is.

/proc/wiremod_is_assoc_list(value)
	if(!islist(value) || !length(value))
		return FALSE
	return !isnum(value[1])

// A bounded copy of an associative list, or null for anything else. An empty
// list is accepted so a literal with no entries still gives an associative list.
/proc/wiremod_safe_assoc_list(value)
	if(!islist(value))
		return null
	var/list/source = value
	if(length(source) && !wiremod_is_assoc_list(source))
		return null
	var/list/result = list()
	for(var/key in source)
		if(length(result) >= CIRCUIT_MAX_ASSOC_ENTRIES)
			break
		if(!istext(key))
			continue
		var/entry = source[key]
		if(isnum(entry))
			entry = wiremod_safe_number(entry)
		else if(istext(entry))
			entry = wiremod_safe_text(entry)
		else
			entry = wiremod_safe_entity(entry)
		if(isnull(entry))
			continue
		result[wiremod_safe_text(key)] = entry
	return result

// The value under a text key, or null.
/proc/wiremod_assoc_get(value, key)
	if(!wiremod_is_assoc_list(value) || !istext(key))
		return null
	return wiremod_safe_value(value[key])

// TRUE when the associative list holds this text key.
/proc/wiremod_assoc_has(value, key)
	return wiremod_is_assoc_list(value) && istext(key) && (key in value)

// The text keys of an associative list, in the order the list holds them.
/proc/wiremod_assoc_keys(value)
	var/list/keys = list()
	if(!wiremod_is_assoc_list(value))
		return keys
	for(var/key in value)
		if(istext(key))
			keys += key
	return keys

/datum/circuit_datatype/assoc_list
	datatype = PORT_TYPE_ASSOC_LIST
	can_receive_from = list(PORT_TYPE_ANY)
	color = "label"
	keeps_port_lists = TRUE
	manual_error = "An associative list is made with the Associative List Literal component."

/datum/circuit_datatype/assoc_list/convert(value)
	return wiremod_safe_assoc_list(value)

// Only a component makes an associative list; it cannot be typed.
/datum/circuit_datatype/assoc_list/parse_manual(value)
	return null

/datum/circuit_datatype/assoc_list/ui_value(value)
	if(!islist(value))
		return null
	return "Assoc list ([length(value)] entries)"
