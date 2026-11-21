// Speech that reaches a circuit. A Voice Activator listens to what is said
// nearby and to what a radio at its shell receives; a Radio component sends and
// receives transmissions. The registries hold the components themselves, which
// their circuits already own, and a component leaves its registry as soon as it
// leaves its circuit.
var/global/list/obj/item/circuit_component/voice_activator/wiremod_voice_activators = list()
var/global/list/obj/item/circuit_component/radio/wiremod_radios = list()

// Called by a person's say, after the message is known and its range settled.
/proc/wiremod_speech_heard(mob/speaker, message, message_range)
	if(!speaker || !istext(message))
		return
	for(var/obj/item/circuit_component/voice_activator/listener as anything in wiremod_voice_activators)
		listener.hear_speech(speaker, message, message_range)

// Called by radio_broadcast, after a radio has decided to transmit. The source is
// the circuit that asked for the transmission, so it does not hear itself.
/proc/wiremod_radio_heard(frequency, message, speaker, datum/source)
	if(!istext(message))
		return
	for(var/obj/item/circuit_component/radio/receiver as anything in wiremod_radios)
		if(receiver != source)
			receiver.receive_transmission(frequency, message, speaker)
	for(var/obj/item/circuit_component/voice_activator/listener as anything in wiremod_voice_activators)
		listener.hear_radio(frequency, message, source)

// A radio item or structure within reach of the anchor, or null. A transmitting
// radio must be able to transmit and a receiving one must be switched on.
/proc/wiremod_nearby_radio(atom/anchor, is_transmitter, frequency)
	if(!anchor)
		return null
	var/turf/here = get_turf(anchor)
	if(!here)
		return null
	for(var/obj/candidate in range(1, here))
		if(!istype(candidate, /obj/item/weapon/radio) && !istype(candidate, /obj/structure/radio))
			continue
		if(is_transmitter)
			if(!candidate:transmitter || !candidate:transmitter_on)
				continue
		else if(!candidate:receiver_on)
			continue
		if(!isnull(frequency) && !wiremod_radio_tuned(candidate, frequency))
			continue
		return candidate
	return null

// TRUE when the radio's tuning covers a frequency.
/proc/wiremod_radio_tuned(obj/radio, frequency)
	if(!isnum(frequency) || !isnum(radio:freq))
		return FALSE
	if(radio:multifreq)
		return frequency in radio:multifreqlist
	return radio:freq == frequency

// The person a circuit speaks as: whoever holds or wears its shell, or the
// nearest person to a shell that lies in the world. Only a human can speak on
// Civ13's radio network, so anything else finds no speaker.
/proc/wiremod_circuit_speaker(obj/item/integrated_circuit/circuit)
	var/atom/shell = wiremod_shell(circuit)
	if(!shell)
		return null
	var/atom/place = shell
	while(place && !ismob(place) && place.loc && place.loc != place)
		place = place.loc
	if(istype(place, /mob/living/human))
		return place
	var/turf/here = get_turf(shell)
	if(!here)
		return null
	for(var/mob/living/human/person in range(1, here))
		return person
	return null
