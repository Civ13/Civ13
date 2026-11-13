/obj/item/trombone
	name = "trumpet"
	desc = "To announce the arrival of the king!"
	icon_state = "trombone"
	item_state = "trombone"
	icon = 'icons/obj/musician.dmi'
	force = WEAPON_FORCE_WEAK
	var/datum/song/song
	var/playing = FALSE
	var/help = FALSE
	var/edit = TRUE
	var/repeat = FALSE
	flammable = TRUE
	value = 0
	flags = CONDUCT

/obj/item/trombone/proc/playnote(var/note as text)
	//to_chat(world, "Note: [note]")
	var/soundfile
	/*BYOND loads resource files at compile time if they are ''. This means you can't really manipulate them dynamically.
	Tried doing it dynamically at first but its more trouble than its worth. Would have saved many lines tho.*/
	switch(note)
		if ("Ab2", "G#2")	soundfile = 'sound/trombone/Ab2.mid'
		if ("Ab3", "G#3")	soundfile = 'sound/trombone/Ab3.mid'
		if ("Ab4", "G#4")	soundfile = 'sound/trombone/Ab4.mid'
		if ("Ab5", "G#5")	soundfile = 'sound/trombone/Ab5.mid'
		if ("Ab6", "G#6")	soundfile = 'sound/trombone/Ab6.mid'
		if ("An2")	soundfile = 'sound/trombone/An2.mid'
		if ("An3")	soundfile = 'sound/trombone/An3.mid'
		if ("An4")	soundfile = 'sound/trombone/An4.mid'
		if ("An5")	soundfile = 'sound/trombone/An5.mid'
		if ("An6")	soundfile = 'sound/trombone/An6.mid'
		if ("Bb2", "A#2")	soundfile = 'sound/trombone/Bb2.mid'
		if ("Bb3", "A#3")	soundfile = 'sound/trombone/Bb3.mid'
		if ("Bb4", "A#4")	soundfile = 'sound/trombone/Bb4.mid'
		if ("Bb5", "A#5")	soundfile = 'sound/trombone/Bb5.mid'
		if ("Bb6", "A#6")	soundfile = 'sound/trombone/Bb6.mid'
		if ("Bn2")	soundfile = 'sound/trombone/Bn2.mid'
		if ("Bn3")	soundfile = 'sound/trombone/Bn3.mid'
		if ("Bn4")	soundfile = 'sound/trombone/Bn4.mid'
		if ("Bn5")	soundfile = 'sound/trombone/Bn5.mid'
		if ("Bn6")	soundfile = 'sound/trombone/Bn6.mid'
		if ("Cn2")	soundfile = 'sound/trombone/Cn2.mid'
		if ("Cn3", "B#2")	soundfile = 'sound/trombone/Cn3.mid'
		if ("Cn4", "B#3")	soundfile = 'sound/trombone/Cn4.mid'
		if ("Cn5", "B#4")	soundfile = 'sound/trombone/Cn5.mid'
		if ("Cn6", "B#5")	soundfile = 'sound/trombone/Cn6.mid'
		if ("Db2", "C#2")	soundfile = 'sound/trombone/Db2.mid'
		if ("Db3", "C#3")	soundfile = 'sound/trombone/Db3.mid'
		if ("Db4", "C#4")	soundfile = 'sound/trombone/Db4.mid'
		if ("Db5", "C#5")	soundfile = 'sound/trombone/Db5.mid'
		if ("Db6", "C#6")	soundfile = 'sound/trombone/Db6.mid'
		if ("Dn2")	soundfile = 'sound/trombone/Dn2.mid'
		if ("Dn3")	soundfile = 'sound/trombone/Dn3.mid'
		if ("Dn4")	soundfile = 'sound/trombone/Dn4.mid'
		if ("Dn5")	soundfile = 'sound/trombone/Dn5.mid'
		if ("Dn6")	soundfile = 'sound/trombone/Dn6.mid'
		if ("Eb2", "D#2")	soundfile = 'sound/trombone/Eb2.mid'
		if ("Eb3", "D#3")	soundfile = 'sound/trombone/Eb3.mid'
		if ("Eb4", "D#4")	soundfile = 'sound/trombone/Eb4.mid'
		if ("Eb5", "D#5")	soundfile = 'sound/trombone/Eb5.mid'
		if ("Eb6", "D#6")	soundfile = 'sound/trombone/Eb6.mid'
		if ("En2")	soundfile = 'sound/trombone/En2.mid'
		if ("En3")	soundfile = 'sound/trombone/En3.mid'
		if ("En4")	soundfile = 'sound/trombone/En4.mid'
		if ("En5")	soundfile = 'sound/trombone/En5.mid'
		if ("En6")	soundfile = 'sound/trombone/En6.mid'
		if ("Fn2", "E#2")	soundfile = 'sound/trombone/Fn2.mid'
		if ("Fn3", "E#3")	soundfile = 'sound/trombone/Fn3.mid'
		if ("Fn4", "E#4")	soundfile = 'sound/trombone/Fn4.mid'
		if ("Fn5", "E#5")	soundfile = 'sound/trombone/Fn5.mid'
		if ("Fn6", "E#6")	soundfile = 'sound/trombone/Fn6.mid'
		if ("Gb2", "F#2")	soundfile = 'sound/trombone/Gb2.mid'
		if ("Gb3", "F#3")	soundfile = 'sound/trombone/Gb3.mid'
		if ("Gb4", "F#4")	soundfile = 'sound/trombone/Gb4.mid'
		if ("Gb5", "F#5")	soundfile = 'sound/trombone/Gb5.mid'
		if ("Gb6", "F#6")	soundfile = 'sound/trombone/Gb6.mid'
		if ("Gn2")	soundfile = 'sound/trombone/Gn2.mid'
		if ("Gn3")	soundfile = 'sound/trombone/Gn3.mid'
		if ("Gn4")	soundfile = 'sound/trombone/Gn4.mid'
		if ("Gn5")	soundfile = 'sound/trombone/Gn5.mid'
		if ("Gn6")	soundfile = 'sound/trombone/Gn6.mid'
		else		return

	hearers(15, get_turf(src)) << sound(soundfile)

/obj/item/trombone/attack_self(mob/user as mob)
	if (!isliving(user) || user.stat || user.restrained() || user.lying)	return
	user.set_using_object(src)
	instrument_panel(src, user, "trombone", "trombone", MAX_CHARS_PER_LINE)

/obj/item/trombone/Topic(href, href_list)
	instrument_topic(src, usr, href_list, "trombone", "trombone", MAX_CHARS_PER_LINE)
