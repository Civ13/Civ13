// An entity: a person or an object in the world. A port never holds the thing
// itself. It holds the thing's weak reference (code/datums/weakref.dm), which
// does not keep it alive and stops resolving the moment it is deleted; the port
// holding it is also told of the deletion and empties itself (core/port.dm).
// An entity is never written to a save and never put in a list.

// The weak reference a port may hold for this value, or null. Only a weak
// reference is accepted here: a caller with the thing itself says so by passing
// WEAKREF(thing), so nothing reaches a port as an object by accident.
/proc/wiremod_safe_entity(value)
	return wiremod_entity(value) ? value : null

// The thing an entity value stands for, or null once it is gone.
/proc/wiremod_entity(value)
	if(!istype(value, /datum/weakref))
		return null
	var/datum/weakref/handle = value
	var/atom/movable/target = handle.resolve()
	return istype(target) ? target : null

// The name of the thing an entity value stands for, as plain text, or null.
// It is a name as written on the thing: escape it before it reaches chat.
/proc/wiremod_entity_name(value)
	var/atom/movable/target = wiremod_entity(value)
	return target ? wiremod_safe_text("[target.name]") : null

/datum/circuit_datatype/entity
	datatype = PORT_TYPE_ENTITY
	can_receive_from = list(PORT_TYPE_ANY)
	color = "purple"
	takes_marked_entity = TRUE

/datum/circuit_datatype/entity/convert(value)
	return wiremod_safe_entity(value)

// An entity cannot be typed; it is marked (act_set_component_input).
/datum/circuit_datatype/entity/parse_manual(value)
	return null
