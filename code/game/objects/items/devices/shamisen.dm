/obj/item/shamisen
	name = "Shamisen"
	desc = "A japanese shamisen."
	icon = 'icons/obj/musician.dmi'
	icon_state = "shamisen"
	item_state = "shamisen"
	force = WEAPON_FORCE_PAINFUL
	var/datum/song/song
	var/playing = FALSE
	var/help = FALSE
	var/edit = TRUE
	var/repeat = FALSE
	flammable = TRUE
	value = 0

/obj/item/shamisen/proc/playnote(var/note as text)
	//to_chat(world, "Note: [note]")
	var/soundfile
	/*BYOND loads resource files at compile time if they are ''. This means you can't really manipulate them dynamically.
	Tried doing it dynamically at first but its more trouble than its worth. Would have saved many lines tho.*/
	switch(note)
		if ("A#2")	soundfile = 'sound/shamisen/shamisen A#2.ogg'
		if ("A#3")	soundfile = 'sound/shamisen/shamisen A#3.ogg'
		if ("A#4")	soundfile = 'sound/shamisen/shamisen A#4.ogg'
		if ("A#6")	soundfile = 'sound/shamisen/shamisen A#6.ogg'
		if ("A#8")	soundfile = 'sound/shamisen/shamisen A#8.ogg'
		if ("Ab2")	soundfile = 'sound/shamisen/shamisen Ab2.ogg'
		if ("B#2")	soundfile = 'sound/shamisen/shamisen B#2.ogg'
		if ("C#2")	soundfile = 'sound/shamisen/shamisen C#2.ogg'
		if ("C#4")	soundfile = 'sound/shamisen/shamisen C#4.ogg'
		if ("C#5")	soundfile = 'sound/shamisen/shamisen C#5.ogg'
		if ("Cb2")	soundfile = 'sound/shamisen/shamisen Cb2.ogg'
		if ("Cb4")	soundfile = 'sound/shamisen/shamisen Cb4.ogg'
		if ("Cb5")	soundfile = 'sound/shamisen/shamisen Cb5.ogg'
		if ("D#3")	soundfile = 'sound/shamisen/shamisen D#3.ogg'
		if ("D#5")	soundfile = 'sound/shamisen/shamisen D#5.ogg'
		if ("D#8")	soundfile = 'sound/shamisen/shamisen D#8.ogg'
		if ("Db2")	soundfile = 'sound/shamisen/shamisen Db2.ogg'
		if ("Db4")	soundfile = 'sound/shamisen/shamisen Db4.ogg'
		if ("Eb2")	soundfile = 'sound/shamisen/shamisen Eb2.ogg'
		if ("En5")	soundfile = 'sound/shamisen/shamisen En5.ogg'
		if ("En6")	soundfile = 'sound/shamisen/shamisen En6.ogg'
		if ("En7")	soundfile = 'sound/shamisen/shamisen En7.ogg'
		if ("F#2")	soundfile = 'sound/shamisen/shamisen F#2.ogg'
		if ("F#4")	soundfile = 'sound/shamisen/shamisen F#4.ogg'
		if ("F#6")	soundfile = 'sound/shamisen/shamisen F#6.ogg'
		if ("Fb2")	soundfile = 'sound/shamisen/shamisen Fb2.ogg'
		if ("Fb4")	soundfile = 'sound/shamisen/shamisen Fb4.ogg'
		else		return

	hearers(15, get_turf(src)) << sound(soundfile)

/obj/item/shamisen/attack_self(mob/user as mob)
	if (!isliving(user) || user.stat || user.restrained() || user.lying)	return
	user.set_using_object(src)
	instrument_panel(src, user, "Shamisen", "shamisen", MAX_CHARS_PER_LINE)

/obj/item/shamisen/Topic(href, href_list)
	instrument_topic(src, usr, href_list, "Shamisen", "shamisen", MAX_CHARS_PER_LINE)
