/obj/item/circuit_component/delay
	name = "delay component"
	display_name = "Delay"
	category = "Utility"
	desc = "Passes a signal on after a wait. A signal on Trigger starts a wait of Delay seconds, from 0.1 to 600 (0.1 if not set), and Output fires when it ends. Another signal on Trigger before then starts the wait again."

	var/datum/port/input/delay_amount
	var/datum/port/input/trigger
	var/datum/port/output/output
	var/timer_id

/obj/item/circuit_component/delay/populate_ports()
	delay_amount = add_input_port("Delay", PORT_TYPE_NUMBER)
	trigger = add_input_port("Trigger", PORT_TYPE_SIGNAL, trigger = PROC_REF(run_delay))
	output = add_output_port("Output", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/delay/proc/run_delay(datum/port/input/input)
	if(timer_id)
		deltimer(timer_id)
	var/delay = isnum(delay_amount.value) ? delay_amount.value : CIRCUIT_DELAY_MIN
	delay = max(CIRCUIT_DELAY_MIN, min(delay, CIRCUIT_DELAY_MAX))
	timer_id = addtimer(CALLBACK(src, PROC_REF(fire_delayed_output)), delay * 10, TIMER_STOPPABLE)

/obj/item/circuit_component/delay/proc/fire_delayed_output()
	timer_id = null
	if(parent && output && !QDELETED(src))
		output.set_output(COMPONENT_SIGNAL)

/obj/item/circuit_component/delay/Destroy()
	if(timer_id)
		deltimer(timer_id)
		timer_id = null
	return ..()
