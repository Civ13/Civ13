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

/obj/item/circuit_component/proc/disconnect()
	for(var/datum/port/input/input_port in input_ports)
		input_port.disconnect()
	for(var/datum/port/output/output_port in output_ports)
		output_port.disconnect_all()

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

