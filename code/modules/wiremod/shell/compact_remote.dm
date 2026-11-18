/obj/item/circuit_shell/compact_remote
	name = "compact remote"
	desc = "A handheld remote that sends a signal to the circuit inside it when pressed. Insert an integrated circuit to use it, Alt-click to edit the circuit, or use a screwdriver to remove it."
	icon = 'icons/obj/science/circuits.dmi'
	icon_state = "setup_small_simple"
	w_class = ITEM_SIZE_TINY
	// The circuit it holds is live graph state and is not written to saves.
	should_save = FALSE
	var/obj/item/circuit_component/compact_remote/remote_input

// The remote brings its own signal source. It stays with the shell while no
// circuit is fitted and is attached to whichever circuit is inserted.
/obj/item/circuit_shell/compact_remote/New()
	. = ..()
	remote_input = new /obj/item/circuit_component/compact_remote(src)

/obj/item/circuit_shell/compact_remote/Destroy()
	QDEL_NULL(remote_input)
	return ..()

/obj/item/circuit_shell/compact_remote/circuit_installed(obj/item/integrated_circuit/installed, mob/user)
	if(remote_input?.parent == installed)
		return TRUE
	if(remote_input?.parent)
		remote_input.parent.remove_component(remote_input, src)
	for(var/obj/item/circuit_component/compact_remote/existing in installed.attached_components)
		if(existing != remote_input)
			to_chat(user, "<span class='warning'>[installed] already has a compact remote button.</span>")
			return FALSE
	return installed.add_component(remote_input, user)

/obj/item/circuit_shell/compact_remote/circuit_uninstalled(obj/item/integrated_circuit/removed, mob/user)
	if(remote_input?.parent == removed)
		removed.remove_component(remote_input, src)

/obj/item/circuit_shell/compact_remote/attack_self(mob/user)
	if(!user)
		return FALSE
	if(!circuit)
		to_chat(user, "<span class='warning'>There is no integrated circuit in [src].</span>")
		return TRUE
	if(!remote_input || remote_input.parent != circuit)
		to_chat(user, "<span class='warning'>[src]'s button is not attached to its circuit.</span>")
		return TRUE
	remote_input.send_trigger(user)
	return TRUE

/obj/item/circuit_component/compact_remote
	display_name = "Compact Remote"
	desc = "The remote's button. Each press sends a signal on Signal, and User becomes the person who pressed it. Wire User into a text input to get their name."
	removable = FALSE

	var/datum/port/output/user_output
	var/datum/port/output/signal_output

/obj/item/circuit_component/compact_remote/populate_ports()
	user_output = add_output_port("User", PORT_TYPE_ENTITY)
	signal_output = add_output_port("Signal", PORT_TYPE_SIGNAL)

// The user port carries a weak reference to the presser, never the mob itself:
// a port must not keep a game object alive.
/obj/item/circuit_component/compact_remote/proc/send_trigger(mob/user)
	user_output.set_output(WEAKREF(user))
	signal_output.set_output(COMPONENT_SIGNAL)
