/obj/item/compact_remote
	name = "compact remote"
	desc = "A handheld remote that sends a signal to its built-in circuit when pressed. Alt-click it to edit the circuit."
	icon = 'icons/obj/science/circuits.dmi'
	icon_state = "setup_small_simple"
	w_class = ITEM_SIZE_TINY
	// The circuit inside is live graph state and is not written to saves.
	should_save = FALSE

	var/obj/item/integrated_circuit/circuit
	var/obj/item/circuit_component/compact_remote/remote_input

/obj/item/compact_remote/New()
	. = ..()
	circuit = new /obj/item/integrated_circuit(src)
	remote_input = new /obj/item/circuit_component/compact_remote
	if(!circuit.add_component(remote_input))
		qdel(remote_input)
		remote_input = null
		stack_trace("Failed to initialize the compact remote circuit.")

/obj/item/compact_remote/Destroy()
	remote_input = null
	QDEL_NULL(circuit)
	return ..()

/obj/item/compact_remote/attack_self(mob/user)
	if(!user || !remote_input || !circuit)
		return FALSE
	remote_input.send_trigger(user)
	return TRUE

/obj/item/compact_remote/AltClick(mob/user)
	if(circuit && wiremod_circuit_state.can_use_topic(circuit, user) == STATUS_INTERACTIVE)
		circuit.ui_interact(user)
		return
	return ..()

/obj/item/circuit_component/compact_remote
	display_name = "Compact Remote"
	desc = "Sends a signal to the circuit whenever the compact remote is pressed."
	removable = FALSE

	var/datum/port/output/user_output
	var/datum/port/output/signal_output

/obj/item/circuit_component/compact_remote/populate_ports()
	user_output = add_output_port("User", PORT_TYPE_STRING)
	signal_output = add_output_port("Signal", PORT_TYPE_SIGNAL)

// The user port carries the presser's visible name, never the mob itself: a
// port must not keep a game object alive.
/obj/item/circuit_component/compact_remote/proc/send_trigger(mob/user)
	user_output.set_output(user ? "[user.name]" : null)
	signal_output.set_output(COMPONENT_SIGNAL)
