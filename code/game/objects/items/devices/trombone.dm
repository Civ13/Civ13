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

// Note name to sample; notes without a sample play the nearest one, retuned.
/obj/item/trombone/var/static/list/samples = list(
	"Cn2" = 'sound/trombone/Cn2.ogg',
	"Db2" = 'sound/trombone/Db2.ogg',
	"Dn2" = 'sound/trombone/Dn2.ogg',
	"Eb2" = 'sound/trombone/Eb2.ogg',
	"En2" = 'sound/trombone/En2.ogg',
	"Fn2" = 'sound/trombone/Fn2.ogg',
	"Gb2" = 'sound/trombone/Gb2.ogg',
	"Gn2" = 'sound/trombone/Gn2.ogg',
	"Ab2" = 'sound/trombone/Ab2.ogg',
	"An2" = 'sound/trombone/An2.ogg',
	"Bb2" = 'sound/trombone/Bb2.ogg',
	"Bn2" = 'sound/trombone/Bn2.ogg',
	"Cn3" = 'sound/trombone/Cn3.ogg',
	"Db3" = 'sound/trombone/Db3.ogg',
	"Dn3" = 'sound/trombone/Dn3.ogg',
	"Eb3" = 'sound/trombone/Eb3.ogg',
	"En3" = 'sound/trombone/En3.ogg',
	"Fn3" = 'sound/trombone/Fn3.ogg',
	"Gb3" = 'sound/trombone/Gb3.ogg',
	"Gn3" = 'sound/trombone/Gn3.ogg',
	"Ab3" = 'sound/trombone/Ab3.ogg',
	"An3" = 'sound/trombone/An3.ogg',
	"Bb3" = 'sound/trombone/Bb3.ogg',
	"Bn3" = 'sound/trombone/Bn3.ogg',
	"Cn4" = 'sound/trombone/Cn4.ogg',
	"Db4" = 'sound/trombone/Db4.ogg',
	"Dn4" = 'sound/trombone/Dn4.ogg',
	"Eb4" = 'sound/trombone/Eb4.ogg',
	"En4" = 'sound/trombone/En4.ogg',
	"Fn4" = 'sound/trombone/Fn4.ogg',
	"Gb4" = 'sound/trombone/Gb4.ogg',
	"Gn4" = 'sound/trombone/Gn4.ogg',
	"Ab4" = 'sound/trombone/Ab4.ogg',
	"An4" = 'sound/trombone/An4.ogg',
	"Bb4" = 'sound/trombone/Bb4.ogg',
	"Bn4" = 'sound/trombone/Bn4.ogg',
	"Cn5" = 'sound/trombone/Cn5.ogg',
	"Db5" = 'sound/trombone/Db5.ogg',
	"Dn5" = 'sound/trombone/Dn5.ogg',
	"Eb5" = 'sound/trombone/Eb5.ogg',
	"En5" = 'sound/trombone/En5.ogg',
	"Fn5" = 'sound/trombone/Fn5.ogg',
	"Gb5" = 'sound/trombone/Gb5.ogg',
	"Gn5" = 'sound/trombone/Gn5.ogg',
	"Ab5" = 'sound/trombone/Ab5.ogg',
	"An5" = 'sound/trombone/An5.ogg',
	"Bb5" = 'sound/trombone/Bb5.ogg',
	"Bn5" = 'sound/trombone/Bn5.ogg',
	"Cn6" = 'sound/trombone/Cn6.ogg',
	"Db6" = 'sound/trombone/Db6.ogg',
	"Dn6" = 'sound/trombone/Dn6.ogg',
	"Eb6" = 'sound/trombone/Eb6.ogg',
	"En6" = 'sound/trombone/En6.ogg',
	"Fn6" = 'sound/trombone/Fn6.ogg',
	"Gb6" = 'sound/trombone/Gb6.ogg',
	"Gn6" = 'sound/trombone/Gn6.ogg',
	"Ab6" = 'sound/trombone/Ab6.ogg',
	"An6" = 'sound/trombone/An6.ogg',
	"Bb6" = 'sound/trombone/Bb6.ogg',
	"Bn6" = 'sound/trombone/Bn6.ogg')

/obj/item/trombone/proc/playnote(note)
	instrument_play_note(src, note, samples)

/obj/item/trombone/attack_self(mob/user as mob)
	instrument_open_held_panel(src, user, "trombone", "trombone", MAX_CHARS_PER_LINE)

/obj/item/trombone/Topic(href, href_list)
	instrument_topic(src, usr, href_list, "trombone", "trombone", MAX_CHARS_PER_LINE)
