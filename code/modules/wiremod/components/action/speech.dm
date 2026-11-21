/obj/item/circuit_component/speech
	name = "speech component"
	display_name = "Speech"
	category = "Action"
	desc = "Makes the shell say its text out loud when a signal reaches Trigger. The text is escaped and cut at 500 characters, and the shell speaks at most once a second. A loose circuit says nothing."

	var/datum/port/input/string_input
	var/datum/port/input/trigger
	var/last_spoken = 0

/obj/item/circuit_component/speech/populate_ports()
	string_input = add_input_port("String", PORT_TYPE_STRING)
	trigger = add_input_port("Trigger", PORT_TYPE_SIGNAL, trigger = PROC_REF(speak))

/obj/item/circuit_component/speech/proc/speak(datum/port/input/input)
	if(world.time < last_spoken)
		return
	if(!istext(string_input.value))
		return
	var/message = copytext(string_input.value, 1, 501)
	if(wiremod_anchor_say(parent, message))
		last_spoken = world.time + CIRCUIT_SPEECH_COOLDOWN
