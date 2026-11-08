// Tape recorders and cassette tapes for the modern eras.
// Gameplay idea from CM-SS13's tape recorder (code/game/objects/items/devices/taperecorder.dm,
// AGPL-3.0); this is a fresh implementation that reuses Civ13's own sprites.
//
// A recorder with a tape in it records what is said within earshot of it, in or
// out of a pocket, and plays it back aloud. Each tape keeps the speaker's voice,
// the words and the language, so a listener who does not speak that language
// hears it scrambled, as they would in person. Write on a tape with a pen to
// label it.

#define TAPE_CAPACITY 6000 // deciseconds of tape: ten minutes
#define TAPE_MAX_LINES 120
#define TAPE_PLAYBACK_MIN_GAP 10
#define TAPE_PLAYBACK_MAX_GAP 40

var/global/list/recording_tape_recorders = list()

// Called by spoken speech with the atoms that could hear it. A recorder lying on
// the ground hears through hear_talk() like other objects (also whispers); this
// covers recorders that are carried or packed, which hear_talk() never reaches.
/proc/tape_recorders_hear(mob/living/speaker, text, verb, datum/language/speaking, list/heard)
	if (!recording_tape_recorders.len || !speaker || !text || !heard)
		return
	for (var/obj/item/tape_recorder/R in recording_tape_recorders)
		if (isturf(R.loc))
			continue
		var/turf/T = get_turf(R)
		if (T && (T in heard))
			R.record_speech(speaker, text, verb, speaking)

/obj/item/cassette
	name = "cassette tape"
	desc = "A blank cassette tape. Put it in a tape recorder to record on it. Write on it with a pen to label it."
	icon = 'icons/obj/computers.dmi'
	icon_state = "tape"
	w_class = ITEM_SIZE_TINY
	flammable = TRUE
	var/label = ""
	var/used = 0 // deciseconds of tape already recorded
	// One entry per recorded line, kept as parallel text lists so a save keeps them as plain values.
	var/list/stamps = list() // tape time of each line, in deciseconds
	var/list/voices = list()
	var/list/speech_verbs = list()
	var/list/lines = list()
	var/list/language_names = list()

/obj/item/cassette/black
	icon_state = "blacktape"

/obj/item/cassette/New()
	..()
	update_icon()

/obj/item/cassette/update_icon()
	overlays.Cut()
	if (label)
		overlays += image(icon, "tape_label")
		name = "cassette tape - '[label]'"
	else
		name = initial(name)

/obj/item/cassette/examine(mob/user)
	..()
	if (label)
		to_chat(user, "The label reads \"[label]\".")
	if (lines.len)
		to_chat(user, "It holds [tape_time_text(used)] of recording, [lines.len] line\s.")
	else
		to_chat(user, "It is blank.")
	if (used >= TAPE_CAPACITY)
		to_chat(user, "The tape is full.")

/obj/item/cassette/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/pen))
		var/new_label = input(user, "What do you want to write on the label? Leave it empty to rub the label off.", "Label tape", label) as text|null
		if (isnull(new_label) || !user.Adjacent(src) || user.incapacitated())
			return
		label = sanitize(new_label, 32)
		update_icon()
		to_chat(user, label ? "<span class='notice'>You label the tape \"[label]\".</span>" : "<span class='notice'>You rub the label off the tape.</span>")
		return
	return ..()

/obj/item/cassette/proc/is_full()
	return used >= TAPE_CAPACITY || lines.len >= TAPE_MAX_LINES

/obj/item/cassette/proc/add_line(stamp, voice, verb, text, language_name)
	if (lines.len >= TAPE_MAX_LINES)
		return FALSE
	stamps += stamp
	voices += voice
	speech_verbs += verb
	lines += text
	language_names += (language_name ? language_name : "")
	return TRUE

/obj/item/cassette/proc/wipe()
	used = 0
	stamps = list()
	voices = list()
	speech_verbs = list()
	lines = list()
	language_names = list()

/proc/tape_time_text(ds)
	var/seconds = round(ds / 10)
	return "[round(seconds / 60)]:[seconds % 60 < 10 ? "0" : ""][seconds % 60]"

/obj/item/tape_recorder
	name = "tape recorder"
	desc = "A portable cassette recorder. It records speech around it, even from a pocket, and plays it back aloud."
	icon = 'icons/obj/device.dmi'
	icon_state = "recorder"
	item_state = "walkietalkie"
	w_class = ITEM_SIZE_SMALL
	slot_flags = SLOT_BELT
	flammable = FALSE
	var/tmp/recording = FALSE
	var/tmp/playing = FALSE
	var/tmp/record_start = 0 // world.time the current stretch of recording started
	var/tmp/record_base = 0 // tape time when that stretch started

/obj/item/tape_recorder/loaded/New()
	..()
	new /obj/item/cassette(src)

/obj/item/tape_recorder/Destroy()
	recording = FALSE
	playing = FALSE
	recording_tape_recorders -= src
	return ..()

/obj/item/tape_recorder/proc/get_tape()
	return locate(/obj/item/cassette) in contents

/obj/item/tape_recorder/update_icon()
	icon_state = (recording || playing) ? "recorder_on" : "recorder"

/obj/item/tape_recorder/examine(mob/user)
	..()
	var/obj/item/cassette/T = get_tape()
	if (!T)
		to_chat(user, "There is no tape in it.")
	else
		to_chat(user, "It holds \a [T]: [tape_time_text(T.used)] of [tape_time_text(TAPE_CAPACITY)] used.")
	if (recording)
		to_chat(user, "<span class='warning'>It is recording.</span>")
	else if (playing)
		to_chat(user, "It is playing.")

/obj/item/tape_recorder/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/cassette))
		if (get_tape())
			to_chat(user, "<span class='warning'>There is already a tape in [src].</span>")
			return
		if (W.loc == user && !user.unEquip(W))
			return
		W.forceMove(src)
		to_chat(user, "<span class='notice'>You put [W] into [src].</span>")
		playsound(src, 'sound/machines/click.ogg', 30)
		return
	return ..()

/obj/item/tape_recorder/attack_self(mob/user)
	var/obj/item/cassette/T = get_tape()
	var/list/options = list("Cancel")
	if (recording || playing)
		options += "Stop"
	else if (T)
		options += list("Record", "Play", "Erase tape", "Eject tape")
	if (options.len == 1)
		to_chat(user, "<span class='warning'>[src] has no tape in it.</span>")
		return
	var/choice = WWinput(user, "What do you want to do with the tape recorder?", "Tape Recorder", "Cancel", options)
	if (!choice || choice == "Cancel" || !user.Adjacent(src) || user.incapacitated())
		return
	switch (choice)
		if ("Stop")
			stop(user)
		if ("Record")
			start_recording(user)
		if ("Play")
			start_playback(user)
		if ("Erase tape")
			erase(user)
		if ("Eject tape")
			eject(user)

/obj/item/tape_recorder/verb/tape_record()
	set name = "Start Recording"
	set category = null
	set src in usr
	start_recording(usr)

/obj/item/tape_recorder/verb/tape_stop()
	set name = "Stop Tape"
	set category = null
	set src in usr
	stop(usr)

/obj/item/tape_recorder/verb/tape_play()
	set name = "Play Tape"
	set category = null
	set src in usr
	start_playback(usr)

/obj/item/tape_recorder/verb/tape_eject()
	set name = "Eject Tape"
	set category = null
	set src in usr
	eject(usr)

/obj/item/tape_recorder/proc/start_recording(mob/user)
	if (recording || playing || (user && user.incapacitated()))
		return FALSE
	var/obj/item/cassette/T = get_tape()
	if (!T)
		if (user)
			to_chat(user, "<span class='warning'>[src] has no tape in it.</span>")
		return FALSE
	if (T.is_full())
		if (user)
			to_chat(user, "<span class='warning'>The tape is full.</span>")
		return FALSE
	recording = TRUE
	record_start = world.time
	record_base = T.used
	recording_tape_recorders |= src
	update_icon()
	if (user)
		to_chat(user, "<span class='notice'>You press record on [src].</span>")
	playsound(src, 'sound/machines/click.ogg', 30)
	watch_recording()
	return TRUE

// Advances the tape while it records and stops at its end.
/obj/item/tape_recorder/proc/watch_recording()
	set waitfor = FALSE
	while (recording && !QDELETED(src))
		sleep(10)
		if (!recording)
			return
		var/obj/item/cassette/T = get_tape()
		if (!T)
			stop()
			return
		T.used = tape_position()
		if (T.is_full())
			stop()
			visible_message("<span class='notice'>[src] clicks: the tape has run out.</span>")
			return

// Where the tape is now while recording, in deciseconds.
/obj/item/tape_recorder/proc/tape_position()
	return min(TAPE_CAPACITY, record_base + (world.time - record_start))

/obj/item/tape_recorder/hear_talk(mob/M, text, verb, datum/language/speaking)
	if (recording && isturf(loc) && isliving(M))
		record_speech(M, text, verb, speaking)

/obj/item/tape_recorder/proc/record_speech(mob/living/speaker, text, verb, datum/language/speaking)
	if (!recording)
		return FALSE
	var/obj/item/cassette/T = get_tape()
	if (!T || T.is_full())
		return FALSE
	text = strip_html_properly(text)
	if (!text || dd_hasprefix(text, "*"))
		return FALSE
	var/voice = speaker.name
	if (ishuman(speaker))
		var/mob/living/human/H = speaker
		voice = H.GetVoice()
	var/stamp = tape_position()
	T.used = stamp
	return T.add_line(stamp, voice, verb ? verb : "says", copytext(text, 1, MAX_MESSAGE_LEN), speaking ? speaking.name : null)

/obj/item/tape_recorder/proc/start_playback(mob/user)
	if (recording || playing || (user && user.incapacitated()))
		return FALSE
	var/obj/item/cassette/T = get_tape()
	if (!T)
		if (user)
			to_chat(user, "<span class='warning'>[src] has no tape in it.</span>")
		return FALSE
	if (!T.lines.len)
		if (user)
			to_chat(user, "<span class='warning'>The tape is blank.</span>")
		return FALSE
	playing = TRUE
	update_icon()
	if (user)
		to_chat(user, "<span class='notice'>You press play on [src].</span>")
	playsound(src, 'sound/machines/click.ogg', 30)
	play_tape(T)
	return TRUE

/obj/item/tape_recorder/proc/play_tape(obj/item/cassette/T)
	set waitfor = FALSE
	var/last = 0
	for (var/i = 1, i <= T.lines.len, i++)
		var/gap = T.stamps[i] - last
		last = T.stamps[i]
		sleep(clamp(gap, TAPE_PLAYBACK_MIN_GAP, TAPE_PLAYBACK_MAX_GAP))
		if (!playing || QDELETED(src) || get_tape() != T)
			return
		play_line(T.voices[i], T.speech_verbs[i], T.lines[i], T.language_names[i])
	sleep(TAPE_PLAYBACK_MIN_GAP)
	if (playing && !QDELETED(src))
		playing = FALSE
		update_icon()
		visible_message("<span class='notice'>[src] clicks: the tape has finished playing.</span>")

/obj/item/tape_recorder/proc/play_line(voice, verb, text, language_name)
	var/turf/source = get_turf(src)
	if (!source)
		return
	for (var/mob/M in hearers(7, source))
		if ((!M.client && !agent_character_for(M)) || M.stat == UNCONSCIOUS || M.sleeping)
			continue
		to_chat(M, "<span class='game say'><b>[src]</b> plays: <i>[voice] [verb], \"[tape_heard_text(M, text, language_name)]\"</i></span>")

// What a listener makes of a recorded line: scrambled unless they speak its language.
/proc/tape_heard_text(mob/M, text, language_name)
	var/datum/language/L = language_name ? all_languages[language_name] : null
	if (L && !(L.flags & INNATE) && !M.say_understands(null, L))
		return L.scramble(text, M)
	return text

/obj/item/tape_recorder/proc/stop(mob/user)
	if (!recording && !playing)
		return FALSE
	if (recording)
		var/obj/item/cassette/T = get_tape()
		if (T)
			T.used = tape_position()
	recording = FALSE
	playing = FALSE
	recording_tape_recorders -= src
	update_icon()
	if (user)
		to_chat(user, "<span class='notice'>You press stop on [src].</span>")
	playsound(src, 'sound/machines/click.ogg', 30)
	return TRUE

/obj/item/tape_recorder/proc/erase(mob/user)
	var/obj/item/cassette/T = get_tape()
	if (!T || recording || playing)
		return FALSE
	if (WWinput(user, "Erase everything on [T]?", "Tape Recorder", "No", list("No", "Yes")) != "Yes")
		return FALSE
	if (get_tape() != T || recording || playing)
		return FALSE
	T.wipe()
	to_chat(user, "<span class='notice'>You wind the tape back and erase it.</span>")
	return TRUE

/obj/item/tape_recorder/proc/eject(mob/user)
	var/obj/item/cassette/T = get_tape()
	if (!T)
		if (user)
			to_chat(user, "<span class='warning'>[src] has no tape in it.</span>")
		return FALSE
	if (recording || playing)
		stop()
	T.forceMove(get_turf(src))
	if (user)
		user.put_in_hands(T)
		to_chat(user, "<span class='notice'>You eject [T] from [src].</span>")
	playsound(src, 'sound/machines/click.ogg', 30)
	return TRUE

#undef TAPE_PLAYBACK_MIN_GAP
#undef TAPE_PLAYBACK_MAX_GAP
