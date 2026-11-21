/obj/item/circuit_component/voice_activator
	name = "voice activator component"
	display_name = "Voice Activator"
	category = "Sensor"
	desc = "Fires Triggered whenever someone speaks within earshot of the shell, with the words on Message and the speaker on Speaker. It also hears speech a radio at the shell receives, but then Speaker is empty because a radio does not carry the speaker. A loose circuit hears nothing."

	var/datum/port/output/message_output
	var/datum/port/output/speaker_output
	var/datum/port/output/triggered

/obj/item/circuit_component/voice_activator/populate_ports()
	message_output = add_output_port("Message", PORT_TYPE_STRING)
	speaker_output = add_output_port("Speaker", PORT_TYPE_ENTITY)
	triggered = add_output_port("Triggered", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/voice_activator/added_to_circuit(obj/item/integrated_circuit/circuit)
	if(!(src in wiremod_voice_activators))
		wiremod_voice_activators += src

/obj/item/circuit_component/voice_activator/removed_from_circuit(obj/item/integrated_circuit/circuit)
	wiremod_voice_activators -= src

/obj/item/circuit_component/voice_activator/Destroy()
	wiremod_voice_activators -= src
	return ..()

/obj/item/circuit_component/voice_activator/proc/hear_speech(mob/speaker, message, message_range)
	var/turf/here = wiremod_shell_turf(parent)
	var/turf/theirs = speaker ? get_turf(speaker) : null
	if(!here || !theirs || here.z != theirs.z)
		return
	if(get_dist(here, theirs) > message_range)
		return
	speak_up(message, speaker)

/obj/item/circuit_component/voice_activator/proc/hear_radio(frequency, message, datum/source)
	var/atom/anchor = wiremod_shell(parent)
	if(!anchor || !wiremod_nearby_radio(anchor, FALSE, frequency))
		return
	speak_up(message, null)

/obj/item/circuit_component/voice_activator/proc/speak_up(message, mob/speaker)
	if(!istext(message))
		return
	message_output.set_output(wiremod_safe_text(copytext(message, 1, 501)))
	speaker_output.set_output(speaker ? WEAKREF(speaker) : null)
	triggered.set_output(COMPONENT_SIGNAL)
