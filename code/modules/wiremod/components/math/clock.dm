/obj/item/circuit_component/clock
	name = "clock component"
	display_name = "Clock"
	category = "Math"
	desc = "Sends a signal on Output every 0.9 seconds for as long as On is a number above zero. Setting On to zero or less, or removing the component, stops the clock."

	var/datum/port/input/on_input
	var/datum/port/output/output
	var/timer_id

/obj/item/circuit_component/clock/populate_ports()
	on_input = add_input_port("On", PORT_TYPE_NUMBER, trigger = PROC_REF(update_clock))
	output = add_output_port("Output", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/clock/proc/update_clock(datum/port/input/input)
	stop_clock()
	if(isnum(on_input.value) && on_input.value > 0)
		timer_id = addtimer(CALLBACK(src, PROC_REF(tick)), 9, TIMER_STOPPABLE)

/obj/item/circuit_component/clock/proc/tick()
	timer_id = null
	if(QDELETED(src) || !parent)
		return
	output.set_output(COMPONENT_SIGNAL)
	if(isnum(on_input.value) && on_input.value > 0)
		timer_id = addtimer(CALLBACK(src, PROC_REF(tick)), 9, TIMER_STOPPABLE)

/obj/item/circuit_component/clock/proc/stop_clock()
	if(timer_id)
		deltimer(timer_id)
		timer_id = null

/obj/item/circuit_component/clock/removed_from_circuit(obj/item/integrated_circuit/circuit)
	stop_clock()

/obj/item/circuit_component/clock/Destroy()
	stop_clock()
	return ..()
