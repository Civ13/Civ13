// The mechanism port: a circuit shell that joins an integrated circuit to the
// cord mechanisms (code/modules/1713/mechanisms.dm). Lying on the floor it is a
// trigger: rope on it ties cords to doors, gates, bells and the rest, and a
// signal on its Pull input pulls them. It is also an actuator: a lever's or
// plate's cord tied to it sends a signal out of its Pulled output.

#define MECHANISM_PORT_PULL_GAP 20

/obj/item/circuit_shell/mechanism_port
	name = "mechanism port"
	desc = "A small iron box with a cord pulley and a sensing pawl, for an integrated circuit. Set it on the floor and use rope on it to tie cords to doors, gates, bells and the like within seven tiles: a signal from the circuit pulls them. A lever's or plate's cord tied to the port sends a signal into the circuit. Insert an integrated circuit to use it, Alt-click to edit the circuit, or use a screwdriver to remove it."
	icon = 'icons/obj/science/circuits.dmi'
	icon_state = "setup_stationary"
	w_class = ITEM_SIZE_SMALL
	var/links = "" // "dx,dy;...": tiles its cords are tied to (mechanisms.dm)
	var/next_pull = 0
	var/obj/item/circuit_component/mechanism_port/port_component

/obj/item/circuit_shell/mechanism_port/New()
	. = ..()
	port_component = new /obj/item/circuit_component/mechanism_port(src)
	port_component.shell = src

/obj/item/circuit_shell/mechanism_port/Destroy()
	QDEL_NULL(port_component)
	return ..()

/obj/item/circuit_shell/mechanism_port/examine(mob/user)
	. = ..()
	if (isturf(loc))
		mechanism_links_examine(src, user)
	else
		to_chat(user, "Set it on the floor to tie cords to it.")

/obj/item/circuit_shell/mechanism_port/attackby(obj/item/item, mob/user)
	if (istype(item, /obj/item/stack/material/rope) && ishuman(user))
		if (!isturf(loc))
			to_chat(user, "<span class='warning'>Set [src] on the floor first.</span>")
			return TRUE
		mechanism_rope_on_trigger(src, item, user)
		return TRUE
	return ..()

// Picking the port up leaves its cords behind: they were tied to the floor spot.
/obj/item/circuit_shell/mechanism_port/pickup(mob/user)
	links = ""
	return ..()

/obj/item/circuit_shell/mechanism_port/circuit_installed(obj/item/integrated_circuit/installed, mob/user)
	if (port_component?.parent == installed)
		return TRUE
	if (port_component?.parent)
		port_component.parent.remove_component(port_component, src)
	for (var/obj/item/circuit_component/mechanism_port/existing in installed.attached_components)
		if (existing != port_component)
			to_chat(user, "<span class='warning'>[installed] already has a mechanism port.</span>")
			return FALSE
	return installed.add_component(port_component, user)

/obj/item/circuit_shell/mechanism_port/circuit_uninstalled(obj/item/integrated_circuit/removed, mob/user)
	if (port_component?.parent == removed)
		removed.remove_component(port_component, src)

// A signal from the circuit: pull the cords, at most once every two seconds.
/obj/item/circuit_shell/mechanism_port/proc/circuit_pull(state)
	if (!isturf(loc) || world.time < next_pull)
		return FALSE
	next_pull = world.time + MECHANISM_PORT_PULL_GAP
	mechanism_pull_links(src, links, state)
	return TRUE

// A cord tied to the port was pulled.
/obj/item/circuit_shell/mechanism_port/proc/cord_pulled(state)
	if (!isturf(loc) || !circuit || !port_component || port_component.parent != circuit)
		return FALSE
	port_component.send_pulled(state)
	return TRUE

/obj/item/circuit_component/mechanism_port
	display_name = "Mechanism Port"
	desc = "The port's cords. A signal on Pull pulls every cord tied to the port, at most once every two seconds: Mode \"throw\" works them like a lever thrown over, \"throw back\" like a lever thrown back, and \"toggle\" like a pull cord. When a lever's or plate's cord tied to the port is pulled, Pulled sends a signal and Thrown is true, or false for a lever thrown back."
	removable = FALSE

	var/datum/port/input/pull_input
	var/datum/port/input/mode_input
	var/datum/port/output/pulled_output
	var/datum/port/output/thrown_output
	var/obj/item/circuit_shell/mechanism_port/shell

/obj/item/circuit_component/mechanism_port/populate_ports()
	mode_input = add_input_port("Mode", PORT_TYPE_OPTION, trigger = null, options = list("toggle", "throw", "throw back"))
	pull_input = add_input_port("Pull", PORT_TYPE_SIGNAL, trigger = PROC_REF(pull_cords))
	pulled_output = add_output_port("Pulled", PORT_TYPE_SIGNAL)
	thrown_output = add_output_port("Thrown", PORT_TYPE_BOOLEAN)

/obj/item/circuit_component/mechanism_port/Destroy()
	shell = null
	return ..()

/obj/item/circuit_component/mechanism_port/proc/pull_cords(datum/port/input/input)
	if (!shell || QDELETED(shell))
		return
	var/state = null
	switch (mode_input.value)
		if ("throw")
			state = TRUE
		if ("throw back")
			state = FALSE
	shell.circuit_pull(state)

/obj/item/circuit_component/mechanism_port/proc/send_pulled(state)
	thrown_output.set_output(state != FALSE)
	pulled_output.set_output(COMPONENT_SIGNAL)

#undef MECHANISM_PORT_PULL_GAP
