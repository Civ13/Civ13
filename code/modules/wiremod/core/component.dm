/obj/item/circuit_component
	name = COMPONENT_DEFAULT_NAME
	desc = "A programmable integrated circuit component."
	icon = 'icons/obj/devices/circuitry_n_data.dmi'
	icon_state = "component"
	w_class = ITEM_SIZE_TINY
	// Ports and links are live graph state; circuits are not written to saves.
	should_save = FALSE

	var/display_name = "Component"
	var/category = COMPONENT_DEFAULT_CATEGORY
	var/obj/item/integrated_circuit/parent
	// The number the editor names this component by while it is in a circuit.
	// The circuit hands out a new one on every insertion and never reuses one,
	// so a request for a removed component can never reach another.
	var/circuit_id = 0
	var/list/datum/port/input/input_ports = list()
	var/list/datum/port/output/output_ports = list()
	var/rel_x = 0
	var/rel_y = 0
	var/removable = TRUE
	// TRUE for a component created in the editor: it is deleted when removed
	// instead of becoming an item, so the editor cannot be used to mint objects.
	var/printed = FALSE

/obj/item/circuit_component/New()
	. = ..()
	populate_ports()

/obj/item/circuit_component/proc/populate_ports()
	return

/obj/item/circuit_component/proc/add_input_port(port_name, port_type = PORT_TYPE_ANY, trigger = PROC_REF(input_received), default = null, list/options = null)
	var/datum/port/input/new_port = new(src, port_name, port_type, trigger, default, options)
	input_ports += new_port
	return new_port

/obj/item/circuit_component/proc/add_output_port(port_name, port_type = PORT_TYPE_ANY)
	var/datum/port/output/new_port = new(src, port_name, port_type)
	output_ports += new_port
	return new_port

// Grows the component by one input at the end. Only the last port is ever grown
// or shrunk, so a port's position, and with it the name the editor knows it by,
// never moves.
/obj/item/circuit_component/proc/append_input_port(port_name, port_type = PORT_TYPE_ANY, trigger = PROC_REF(input_received), default = null, list/options = null)
	var/datum/port/input/new_port = add_input_port(port_name, port_type, trigger, default, options)
	parent?.refresh_editor()
	return new_port

// Drops the last input, if it is not the only one. Its wires are cut with it.
/obj/item/circuit_component/proc/remove_last_input_port()
	if(length(input_ports) <= 1)
		return FALSE
	var/datum/port/input/last_port = input_ports[length(input_ports)]
	input_ports -= last_port
	last_port.disconnect()
	qdel(last_port)
	parent?.refresh_editor()
	return TRUE

// The buttons the editor shows on this component's titlebar, as a map of icon
// name to action name. The action name is checked again before it is run.
/obj/item/circuit_component/proc/ui_buttons()
	return null

// The notices the editor shows beside those buttons, as a map of icon name to
// the text shown when it is hovered over.
/obj/item/circuit_component/proc/ui_alerts()
	return null

// Does what one of the titlebar buttons asks. The circuit has already checked
// that the named action is one this component offers and that the user may
// edit the circuit.
/obj/item/circuit_component/proc/ui_perform_action(action_name, mob/user)
	return FALSE

/obj/item/circuit_component/proc/disconnect()
	for(var/datum/port/input/input_port in input_ports)
		input_port.disconnect()
	for(var/datum/port/output/output_port in output_ports)
		output_port.disconnect_all()

// Called after the circuit has taken this component in, so a component that
// reads from its circuit (a variable picker, the shell it sits in) can fill in.
/obj/item/circuit_component/proc/added_to_circuit(obj/item/integrated_circuit/circuit)
	return

// Called when the circuit's place in the world may have changed, such as when
// it is put into or taken out of a shell.
/obj/item/circuit_component/proc/anchor_changed()
	return

// Called when the circuit's variables are added or removed, so a variable
// picker can offer the new set.
/obj/item/circuit_component/proc/refresh_variable_options()
	return

// Called by the circuit as it lets go of this component, before the links are cut.
/obj/item/circuit_component/proc/removed_from_circuit(obj/item/integrated_circuit/circuit)
	return

/obj/item/circuit_component/proc/trigger_component(datum/port/input/input_port)
	if(input_port?.trigger && hascall(src, input_port.trigger))
		return call(src, input_port.trigger)(input_port)
	return input_received(input_port)

/obj/item/circuit_component/proc/input_received(datum/port/input/input_port)
	return

/obj/item/circuit_component/Destroy()
	if(parent)
		parent.remove_component(src)
	disconnect()
	for(var/datum/port/input/input_port in input_ports.Copy())
		qdel(input_port)
	for(var/datum/port/output/output_port in output_ports.Copy())
		qdel(output_port)
	input_ports.Cut()
	output_ports.Cut()
	return ..()

