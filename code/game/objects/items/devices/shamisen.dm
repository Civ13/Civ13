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

// Note name to sample; notes without a sample play the nearest one, retuned.
/obj/item/shamisen/var/static/list/samples = list(
	"Cb2" = 'sound/shamisen/shamisen Cb2.ogg',
	"C#2" = 'sound/shamisen/shamisen C#2.ogg',
	"Db2" = 'sound/shamisen/shamisen Db2.ogg',
	"Eb2" = 'sound/shamisen/shamisen Eb2.ogg',
	"Fb2" = 'sound/shamisen/shamisen Fb2.ogg',
	"F#2" = 'sound/shamisen/shamisen F#2.ogg',
	"Ab2" = 'sound/shamisen/shamisen Ab2.ogg',
	"A#2" = 'sound/shamisen/shamisen A#2.ogg',
	"B#2" = 'sound/shamisen/shamisen B#2.ogg',
	"D#3" = 'sound/shamisen/shamisen D#3.ogg',
	"A#3" = 'sound/shamisen/shamisen A#3.ogg',
	"Cb4" = 'sound/shamisen/shamisen Cb4.ogg',
	"C#4" = 'sound/shamisen/shamisen C#4.ogg',
	"Db4" = 'sound/shamisen/shamisen Db4.ogg',
	"Fb4" = 'sound/shamisen/shamisen Fb4.ogg',
	"F#4" = 'sound/shamisen/shamisen F#4.ogg',
	"A#4" = 'sound/shamisen/shamisen A#4.ogg',
	"Cb5" = 'sound/shamisen/shamisen Cb5.ogg',
	"C#5" = 'sound/shamisen/shamisen C#5.ogg',
	"D#5" = 'sound/shamisen/shamisen D#5.ogg',
	"En5" = 'sound/shamisen/shamisen En5.ogg',
	"En6" = 'sound/shamisen/shamisen En6.ogg',
	"F#6" = 'sound/shamisen/shamisen F#6.ogg',
	"A#6" = 'sound/shamisen/shamisen A#6.ogg',
	"En7" = 'sound/shamisen/shamisen En7.ogg',
	"D#8" = 'sound/shamisen/shamisen D#8.ogg',
	"A#8" = 'sound/shamisen/shamisen A#8.ogg')

/obj/item/shamisen/proc/playnote(note)
	instrument_play_note(src, note, samples)

/obj/item/shamisen/attack_self(mob/user as mob)
	instrument_open_held_panel(src, user, "Shamisen", "shamisen", MAX_CHARS_PER_LINE)

/obj/item/shamisen/Topic(href, href_list)
	instrument_topic(src, usr, href_list, "Shamisen", "shamisen", MAX_CHARS_PER_LINE)
