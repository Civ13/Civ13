// Port datatypes. Each file in this folder defines one datatype as a subtype of
// /datum/circuit_datatype: what a wire may deliver to a port of that type
// (convert), how a typed value is read (parse_manual), which outputs it accepts,
// its colour in the editor and what the editor is shown of its values. Defining
// a subtype with a `datatype` name registers it; nothing else lists datatypes.
//
// A port only ever holds null, a finite number, text of at most
// PORT_MAX_STRING_LENGTH bytes, a list of at most CIRCUIT_MAX_LIST_LENGTH numbers
// and texts, or a weak reference to a thing in the world (entity.dm). The
// handlers enforce that on every write, so a circuit can neither keep a game
// object alive nor grow a value without bound.

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

// Any value a port may hold, or null for anything else.
/proc/wiremod_safe_value(value)
	if(isnum(value))
		return wiremod_safe_number(value)
	if(istext(value))
		return wiremod_safe_text(value)
	if(islist(value))
		if(wiremod_is_assoc_list(value))
			return wiremod_safe_assoc_list(value)
		return wiremod_safe_list(value)
	return wiremod_safe_entity(value)

// What a port value reads as in text: an entity as its name, a list as the word
// list, and nothing as empty. The caller escapes it before it reaches a person.
/proc/wiremod_text_of(value)
	if(isnull(value))
		return ""
	if(istext(value))
		return value
	if(isnum(value))
		return "[value]"
	if(islist(value))
		return "/list"
	var/entity_name = wiremod_entity_name(value)
	return entity_name ? entity_name : ""


/datum/circuit_datatype
	should_save = FALSE
	// The name ports and the editor know this datatype by. A subtype without
	// one is a shared base and is not registered.
	var/datatype
	var/list/can_receive_from = list()
	// TRUE when convert() changes nothing about a list a port already holds, so
	// an input of this type may take such a list as it is.
	var/keeps_port_lists = FALSE
	// The colour the editor draws ports and variables of this type in. These
	// are tgstation's colours, so its players recognise the types.
	var/color = "blue"
	// TRUE when an input of this type may be set by marking a thing in the world
	// (mark_input() in core/circuit_ui.dm).
	var/takes_marked_entity = FALSE
	// Told to a player whose typed value parse_manual() could not read.
	var/manual_error = "That value cannot be entered here."

/datum/circuit_datatype/proc/can_receive_from_datatype(other_type)
	return datatype == other_type || (other_type in can_receive_from)

/datum/circuit_datatype/proc/convert(value)
	return wiremod_safe_value(value)

// A value a player typed into the editor (text or a number) as a value of this
// type, or null when it cannot be read as one. Stricter than convert(), which
// has to make something of whatever a wire delivers.
/datum/circuit_datatype/proc/parse_manual(value)
	return convert(value)

// What the editor is shown of a value a port of this type holds: a number, a
// text or nothing. An entity is shown as its name; the editor escapes it.
/datum/circuit_datatype/proc/ui_value(value)
	if(isnum(value) || istext(value))
		return value
	return wiremod_entity_name(value)

// Anything more the editor needs to draw an input of this type, or null.
/datum/circuit_datatype/proc/ui_data(datum/port/input/port)
	return null

// Every datatype by name, built once from the subtypes above.
/proc/wiremod_datatypes()
	var/static/list/handlers
	if(!handlers)
		handlers = list()
		for(var/handler_type in typesof(/datum/circuit_datatype) - /datum/circuit_datatype)
			var/datum/circuit_datatype/handler = new handler_type
			if(istext(handler.datatype) && !handlers[handler.datatype])
				handlers[handler.datatype] = handler
	return handlers

// The one handler of a datatype, or null for a name that is not one.
/proc/circuit_datatype_for(type_key)
	return istext(type_key) ? wiremod_datatypes()[type_key] : null
