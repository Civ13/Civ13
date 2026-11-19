// World output components act from the circuit's shell. A circuit that is not
// installed in one has nowhere to act, and so does nothing.
/obj/item/circuit_component/light
	name = "light component"
	display_name = "Light"
	category = "Action"
	desc = "Lights the shell while On is a number above zero and turns the light off at zero. Removing the component or taking the circuit out of its shell also turns the light off. A loose circuit has nothing to light."

	var/datum/port/input/on_input
	var/light_on = FALSE
	// The shell this component lit, so it can be put out after the circuit has
	// already left it.
	var/obj/item/circuit_shell/lit_shell

/obj/item/circuit_component/light/populate_ports()
	on_input = add_input_port("On", PORT_TYPE_NUMBER, trigger = PROC_REF(apply_light))

/obj/item/circuit_component/light/proc/apply_light(datum/port/input/input)
	var/want_on = isnum(on_input.value) && on_input.value > 0
	if(want_on == light_on)
		return
	if(!want_on)
		turn_off()
		return
	if(!wiremod_anchor_light(parent, TRUE))
		return
	light_on = TRUE
	lit_shell = wiremod_shell(parent)

/obj/item/circuit_component/light/removed_from_circuit(obj/item/integrated_circuit/circuit)
	turn_off()

/obj/item/circuit_component/light/anchor_changed()
	turn_off()

/obj/item/circuit_component/light/Destroy()
	turn_off()
	return ..()

/obj/item/circuit_component/light/proc/turn_off()
	if(!light_on)
		return
	light_on = FALSE
	if(lit_shell && !QDELETED(lit_shell))
		lit_shell.set_light(0, 0)
	lit_shell = null
