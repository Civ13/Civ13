/obj/item/circuit_component/sound_emitter
	name = "sound emitter component"
	display_name = "Sound Emitter"
	category = "Action"
	desc = "Plays one of its listed sounds from the shell when a signal reaches Trigger. Volume runs from 1 to 100 and Frequency from 0.5 to 2, higher being shriller. It plays at most once a second. A loose circuit makes no sound."

	var/datum/port/input/sound_input
	var/datum/port/input/frequency_input
	var/datum/port/input/volume_input
	var/datum/port/input/trigger
	var/last_played = 0

/obj/item/circuit_component/sound_emitter/populate_ports()
	var/list/choices = list("Ping", "Buzz", "Click", "Button", "Horn", "Siren")
	sound_input = add_input_port("Sound", PORT_TYPE_OPTION, default = choices[1], options = choices)
	frequency_input = add_input_port("Frequency", PORT_TYPE_NUMBER, default = 1)
	volume_input = add_input_port("Volume", PORT_TYPE_NUMBER, default = 50)
	trigger = add_input_port("Trigger", PORT_TYPE_SIGNAL, trigger = PROC_REF(play_sound))

/obj/item/circuit_component/sound_emitter/proc/play_sound(datum/port/input/input)
	if(world.time < last_played)
		return
	var/list/files = list(
		"Ping" = 'sound/machines/ping.ogg',
		"Buzz" = 'sound/machines/buzz-sigh.ogg',
		"Click" = 'sound/machines/click.ogg',
		"Button" = 'sound/machines/button.ogg',
		"Horn" = 'sound/items/bikehorn.ogg',
		"Siren" = 'sound/machines/ambulance_siren.ogg',
	)
	var/sound_file = files[sound_input.value]
	if(!sound_file)
		return
	var/volume = isnum(volume_input.value) ? clamp(volume_input.value, 1, 100) : 50
	var/frequency = isnum(frequency_input.value) ? clamp(frequency_input.value, 0.5, 2) : 1
	if(emit_sound(sound_file, volume, frequency))
		last_played = world.time + CIRCUIT_SOUND_COOLDOWN

// Kept apart from choosing the sound so a fixture can record what was played.
/obj/item/circuit_component/sound_emitter/proc/emit_sound(sound_file, volume, frequency)
	return wiremod_anchor_sound(parent, sound_file, volume, frequency)
