/obj/item/circuit_component/radio
	name = "radio component"
	display_name = "Radio"
	category = "Action"
	desc = "Sends its Message over the chosen frequency through a radio at the shell, and fires Received when another radio or radio component transmits on that frequency. The frequency runs from 150 to 300. A loose circuit has no radio to speak through."

	var/datum/port/input/frequency_input
	var/datum/port/input/message_input
	var/datum/port/input/send
	var/datum/port/output/received
	var/datum/port/output/message_output
	var/datum/port/output/speaker_output
	var/last_sent = 0

/obj/item/circuit_component/radio/populate_ports()
	frequency_input = add_input_port("Frequency", PORT_TYPE_NUMBER, default = 150)
	message_input = add_input_port("Message", PORT_TYPE_STRING)
	send = add_input_port("Send", PORT_TYPE_SIGNAL, trigger = PROC_REF(send_message))
	received = add_output_port("Received", PORT_TYPE_SIGNAL)
	message_output = add_output_port("Message", PORT_TYPE_STRING)
	speaker_output = add_output_port("Speaker", PORT_TYPE_ENTITY)

/obj/item/circuit_component/radio/added_to_circuit(obj/item/integrated_circuit/circuit)
	if(!(src in wiremod_radios))
		wiremod_radios += src

/obj/item/circuit_component/radio/removed_from_circuit(obj/item/integrated_circuit/circuit)
	wiremod_radios -= src

/obj/item/circuit_component/radio/Destroy()
	wiremod_radios -= src
	return ..()

/obj/item/circuit_component/radio/proc/current_frequency()
	return isnum(frequency_input.value) ? clamp(round(frequency_input.value), 150, 300) : 150

/obj/item/circuit_component/radio/proc/send_message(datum/port/input/input)
	if(world.time < last_sent)
		return
	var/message = wiremod_safe_text(message_input.value)
	if(!length(message))
		return
	var/atom/anchor = wiremod_shell(parent)
	if(!anchor)
		return
	last_sent = world.time + CIRCUIT_SPEECH_COOLDOWN
	var/frequency = current_frequency()
	var/mob/speaker = wiremod_circuit_speaker(parent)
	var/obj/transmitter = wiremod_nearby_radio(anchor, TRUE)
	if(transmitter && speaker)
		// The radio is tuned for the one transmission and left as it was found.
		var/old_frequency = transmitter:freq
		transmitter:freq = frequency
		radio_broadcast(transmitter, message, speaker, "says", src)
		transmitter:freq = old_frequency
		return
	// With no radio at the shell, other components still hear the transmission.
	wiremod_radio_heard(frequency, message, speaker, src)

/obj/item/circuit_component/radio/proc/receive_transmission(frequency, message, mob/speaker)
	if(frequency != current_frequency())
		return
	message_output.set_output(wiremod_safe_text(message))
	speaker_output.set_output(speaker ? WEAKREF(speaker) : null)
	received.set_output(COMPONENT_SIGNAL)
