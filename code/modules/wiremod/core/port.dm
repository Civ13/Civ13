// Ports. What a port may hold, and how each datatype reads a value, is in
// ../datatypes: a port holds null, a finite number, bounded text, a bounded list
// of those or a weak reference to a thing in the world, never the thing itself.
//
// A list on a port is never changed in place: a component that wants a different
// list builds a new one (set_output() stores a copy of whatever it is handed).
// That is what lets a wire pass the same list on without copying it again.

/datum/port
	should_save = FALSE
	var/name = "Port"
	var/datatype = PORT_TYPE_ANY
	var/value
	var/datum/circuit_datatype/datatype_handler
	var/obj/item/circuit_component/connected_component

/datum/port/New(obj/item/circuit_component/component, port_name, port_type = PORT_TYPE_ANY)
	connected_component = component
	name = port_name
	set_datatype(port_type)

/datum/port/proc/set_datatype(new_type)
	var/datum/circuit_datatype/new_handler = circuit_datatype_for(new_type)
	if(!new_handler)
		CRASH("Unknown Wiremod port datatype '[new_type]'")
	hold(null)
	datatype = new_type
	datatype_handler = new_handler

/datum/port/proc/set_value(new_value)
	hold(datatype_handler.convert(new_value))

// The one place a port's value changes; the caller has checked the value. A
// port that holds an entity listens for the deletion of the thing it stands
// for, and stops listening when it holds something else. The listening is what
// has to be undone here: the weak reference itself keeps nothing alive.
/datum/port/proc/hold(new_value)
	if(new_value == value)
		return
	var/atom/movable/watched = wiremod_entity(value)
	if(watched)
		GLOB.destroyed_event?.unregister(watched, src, PROC_REF(entity_deleted))
	value = new_value
	watched = wiremod_entity(new_value)
	if(watched)
		GLOB.destroyed_event?.register(watched, src, PROC_REF(entity_deleted))

// Called as a thing this port listens to is deleted: the port empties and an
// open editor is told. Nothing is run: a deletion must never set a player's
// circuit going from inside another object's cleanup.
/datum/port/proc/entity_deleted(datum/source)
	if(istype(value, /datum/weakref) && !wiremod_entity(value))
		hold(null)
		connected_component?.parent?.refresh_editor()

// The component and the handler are released so a deleted port never keeps its
// component alive (the component still holds the port in its typed fields).
/datum/port/Destroy()
	hold(null)
	connected_component = null
	datatype_handler = null
	return ..()

/datum/port/input
	var/datum/port/output/connected_output
	var/trigger
	// The only texts a PORT_TYPE_OPTION port accepts, the first being its default.
	var/list/options

/datum/port/input/New(obj/item/circuit_component/component, port_name, port_type = PORT_TYPE_ANY, input_trigger = null, default_value = null, list/port_options = null)
	trigger = input_trigger
	options = port_options
	..(component, port_name, port_type)
	if(!isnull(default_value))
		set_input(default_value, FALSE)

// A value outside a restricted port's choices leaves the current choice alone.
/datum/port/input/set_value(new_value)
	if(options)
		new_value = datatype_handler.convert(new_value)
		if(!(new_value in options))
			return
	..()

// Replaces the choices a restricted port offers. The current choice is kept
// when it is still one of them, and otherwise falls back to the first choice, so
// a port never keeps a choice the editor can no longer show.
/datum/port/input/proc/set_input_options(list/new_options)
	options = islist(new_options) ? new_options.Copy() : null
	if(options && !(value in options))
		hold(length(options) ? datatype_handler.convert(options[1]) : null)

// Both ports must sit on components of the same circuit.
/datum/port/input/proc/connect(datum/port/output/output)
	if(!istype(output) || output == connected_output || !datatype_handler || !datatype_handler.can_receive_from_datatype(output.datatype))
		return FALSE
	var/obj/item/integrated_circuit/circuit = connected_component?.parent
	if(!circuit || output.connected_component?.parent != circuit)
		return FALSE
	disconnect()
	connected_output = output
	if(!output.connected_inputs)
		output.connected_inputs = list()
	output.connected_inputs |= src
	if(datatype != PORT_TYPE_SIGNAL)
		receive_from(output)
	return TRUE

/datum/port/input/proc/disconnect()
	if(connected_output)
		if(connected_output.connected_inputs)
			connected_output.connected_inputs -= src
		connected_output = null

/datum/port/input/proc/set_input(new_value, should_trigger = TRUE)
	set_value(new_value)
	if(should_trigger)
		queue_trigger()

// Takes the value an output port holds. It takes a port and not a value so the
// shortcut cannot be reached with anything a handler has not checked: a list an
// output holds is already a bounded list of plain values, and for an input
// whose handler would only copy it the same list is kept. Every other value is
// converted as usual.
/datum/port/input/proc/receive_from(datum/port/output/output)
	// An associative list reaching a plain list input is converted, so it arrives
	// flat whichever path delivered it.
	if(islist(output.value) && !options && datatype_handler.keeps_port_lists && !(datatype == PORT_TYPE_LIST && wiremod_is_assoc_list(output.value)))
		hold(output.value)
	else
		set_value(output.value)
	queue_trigger()

/datum/port/input/proc/queue_trigger()
	if(trigger && connected_component?.parent)
		connected_component.parent.queue_input(src)

/datum/port/input/Destroy()
	disconnect()
	options = null
	return ..()

/datum/port/output
	var/list/datum/port/input/connected_inputs

/datum/port/output/proc/set_output(new_value)
	set_value(new_value)
	if(!connected_inputs)
		return
	for(var/datum/port/input/input in connected_inputs.Copy())
		input.receive_from(src)

/datum/port/output/proc/disconnect_all()
	if(connected_inputs)
		for(var/datum/port/input/input in connected_inputs.Copy())
			input.disconnect()
	hold(null)

/datum/port/output/Destroy()
	disconnect_all()
	connected_inputs = null
	return ..()
