/obj/item/circuit_shell
	name = "circuit shell"
	desc = "A shell for an integrated circuit. Use an integrated circuit on it to install one, and a screwdriver to take it out."
	// The circuit inside is live graph state and is not written to saves.
	should_save = FALSE
	var/obj/item/integrated_circuit/circuit

/obj/item/circuit_shell/AltClick(mob/user)
	if(circuit?.can_be_edited_by(user))
		circuit.ui_interact(user)
		return
	return ..()

/obj/item/circuit_shell/examine(mob/user)
	. = ..()
	if(circuit)
		to_chat(user, "It holds [circuit]. Use a screwdriver to remove it.")
	else
		to_chat(user, "It is empty. Use an integrated circuit on it to install one.")

// A shell holds one integrated circuit. An integrated circuit goes in by hand;
// a screwdriver takes it out again and the shell's own parts stay behind.
/obj/item/circuit_shell/attackby(obj/item/item, mob/user)
	if(istype(item, /obj/item/integrated_circuit))
		insert_circuit(item, user)
		return TRUE
	if(circuit && user && user.a_intent != I_HARM && is_tool(item, TOOL_SCREWDRIVER))
		remove_circuit(user)
		return TRUE
	return ..()

/obj/item/circuit_shell/proc/insert_circuit(obj/item/integrated_circuit/new_circuit, mob/user)
	if(!istype(new_circuit) || QDELETED(new_circuit))
		return FALSE
	if(circuit)
		to_chat(user, "<span class='warning'>[src] already holds an integrated circuit. Use a screwdriver to remove it first.</span>")
		return FALSE
	if(!user)
		return FALSE
	// drop_from_inventory() would stage the circuit at the shell's loc instead
	// of inside it (MOVED_DROP), so transfer it straight from the hand.
	var/moved = FALSE
	if(istype(user, /mob/living))
		var/mob/living/living_user = user
		moved = living_user.transfer_held_item_to(new_circuit, src)
	if(!moved)
		if(!user.drop_from_inventory(new_circuit))
			return FALSE
		if(new_circuit.loc != src && !new_circuit.forceMove(src))
			return FALSE
	if(new_circuit.loc != src)
		return FALSE
	circuit = new_circuit
	if(!circuit_installed(circuit, user))
		circuit = null
		if(user)
			user.put_in_hands(new_circuit)
		else
			new_circuit.forceMove(get_turf(src))
		return FALSE
	circuit.refresh_editor()
	to_chat(user, "<span class='notice'>You insert [new_circuit] into [src].</span>")
	return TRUE

/obj/item/circuit_shell/proc/remove_circuit(mob/user)
	if(!circuit)
		return FALSE
	var/obj/item/integrated_circuit/removed = circuit
	circuit_uninstalled(removed, user)
	circuit = null
	if(user)
		user.put_in_hands(removed)
	else
		removed.forceMove(get_turf(src))
	removed.refresh_editor()
	to_chat(user, "<span class='notice'>You unscrew and remove [removed] from [src].</span>")
	return TRUE

// Hooks for shells that bring parts of their own into the circuit. Returning
// FALSE from circuit_installed cancels the insertion and hands the circuit back.
/obj/item/circuit_shell/proc/circuit_installed(obj/item/integrated_circuit/installed, mob/user)
	return TRUE

/obj/item/circuit_shell/proc/circuit_uninstalled(obj/item/integrated_circuit/removed, mob/user)
	return

/obj/item/circuit_shell/Destroy()
	QDEL_NULL(circuit)
	return ..()
