//This file was auto-corrected by findeclaration.exe on 25.5.2012 20:42:32

#define MAX_LINES 1000

/obj/structure/piano
	name = "Piano"
	icon = 'icons/obj/musician.dmi'
	icon_state = "piano"
	anchored = TRUE
	density = TRUE
	climbable = TRUE
	var/datum/song/song
	var/playing = FALSE
	var/help = FALSE
	var/edit = TRUE
	var/repeat = FALSE
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE
/obj/structure/piano/New()
	processing_objects += src

/obj/structure/piano/Del()
	processing_objects -= src
	..()

/obj/structure/piano/process()
	for (var/mob/living/human/H in range(1, src))
		var/turf/T = get_step(H, H.dir)
		if (T.contents.Find(src))
			return TRUE
	playing = FALSE
	return FALSE

// Note name to sample; notes without a sample play the nearest one, retuned.
/obj/structure/piano/var/static/list/samples = list(
	"Cn1" = 'sound/piano/Cn1.ogg',
	"C#1" = 'sound/piano/C#1.ogg',
	"Db1" = 'sound/piano/Db1.ogg',
	"Dn1" = 'sound/piano/Dn1.ogg',
	"D#1" = 'sound/piano/D#1.ogg',
	"Eb1" = 'sound/piano/Eb1.ogg',
	"En1" = 'sound/piano/En1.ogg',
	"Fb1" = 'sound/piano/Fb1.ogg',
	"E#1" = 'sound/piano/E#1.ogg',
	"Fn1" = 'sound/piano/Fn1.ogg',
	"F#1" = 'sound/piano/F#1.ogg',
	"Gb1" = 'sound/piano/Gb1.ogg',
	"Gn1" = 'sound/piano/Gn1.ogg',
	"Ab1" = 'sound/piano/Ab1.ogg',
	"G#1" = 'sound/piano/G#1.ogg',
	"An1" = 'sound/piano/An1.ogg',
	"A#1" = 'sound/piano/A#1.ogg',
	"Bb1" = 'sound/piano/Bb1.ogg',
	"Bn1" = 'sound/piano/Bn1.ogg',
	"B#1" = 'sound/piano/B#1.ogg',
	"Cb2" = 'sound/piano/Cb2.ogg',
	"Cn2" = 'sound/piano/Cn2.ogg',
	"C#2" = 'sound/piano/C#2.ogg',
	"Db2" = 'sound/piano/Db2.ogg',
	"Dn2" = 'sound/piano/Dn2.ogg',
	"D#2" = 'sound/piano/D#2.ogg',
	"Eb2" = 'sound/piano/Eb2.ogg',
	"En2" = 'sound/piano/En2.ogg',
	"Fb2" = 'sound/piano/Fb2.ogg',
	"E#2" = 'sound/piano/E#2.ogg',
	"Fn2" = 'sound/piano/Fn2.ogg',
	"F#2" = 'sound/piano/F#2.ogg',
	"Gb2" = 'sound/piano/Gb2.ogg',
	"Gn2" = 'sound/piano/Gn2.ogg',
	"Ab2" = 'sound/piano/Ab2.ogg',
	"G#2" = 'sound/piano/G#2.ogg',
	"An2" = 'sound/piano/An2.ogg',
	"A#2" = 'sound/piano/A#2.ogg',
	"Bb2" = 'sound/piano/Bb2.ogg',
	"Bn2" = 'sound/piano/Bn2.ogg',
	"B#2" = 'sound/piano/B#2.ogg',
	"Cb3" = 'sound/piano/Cb3.ogg',
	"Cn3" = 'sound/piano/Cn3.ogg',
	"C#3" = 'sound/piano/C#3.ogg',
	"Db3" = 'sound/piano/Db3.ogg',
	"Dn3" = 'sound/piano/Dn3.ogg',
	"D#3" = 'sound/piano/D#3.ogg',
	"Eb3" = 'sound/piano/Eb3.ogg',
	"En3" = 'sound/piano/En3.ogg',
	"Fb3" = 'sound/piano/Fb3.ogg',
	"E#3" = 'sound/piano/E#3.ogg',
	"Fn3" = 'sound/piano/Fn3.ogg',
	"F#3" = 'sound/piano/F#3.ogg',
	"Gb3" = 'sound/piano/Gb3.ogg',
	"Gn3" = 'sound/piano/Gn3.ogg',
	"Ab3" = 'sound/piano/Ab3.ogg',
	"G#3" = 'sound/piano/G#3.ogg',
	"An3" = 'sound/piano/An3.ogg',
	"A#3" = 'sound/piano/A#3.ogg',
	"Bb3" = 'sound/piano/Bb3.ogg',
	"Bn3" = 'sound/piano/Bn3.ogg',
	"B#3" = 'sound/piano/B#3.ogg',
	"Cb4" = 'sound/piano/Cb4.ogg',
	"Cn4" = 'sound/piano/Cn4.ogg',
	"C#4" = 'sound/piano/C#4.ogg',
	"Db4" = 'sound/piano/Db4.ogg',
	"Dn4" = 'sound/piano/Dn4.ogg',
	"D#4" = 'sound/piano/D#4.ogg',
	"Eb4" = 'sound/piano/Eb4.ogg',
	"En4" = 'sound/piano/En4.ogg',
	"Fb4" = 'sound/piano/Fb4.ogg',
	"E#4" = 'sound/piano/E#4.ogg',
	"Fn4" = 'sound/piano/Fn4.ogg',
	"F#4" = 'sound/piano/F#4.ogg',
	"Gb4" = 'sound/piano/Gb4.ogg',
	"Gn4" = 'sound/piano/Gn4.ogg',
	"Ab4" = 'sound/piano/Ab4.ogg',
	"G#4" = 'sound/piano/G#4.ogg',
	"An4" = 'sound/piano/An4.ogg',
	"A#4" = 'sound/piano/A#4.ogg',
	"Bb4" = 'sound/piano/Bb4.ogg',
	"Bn4" = 'sound/piano/Bn4.ogg',
	"B#4" = 'sound/piano/B#4.ogg',
	"Cb5" = 'sound/piano/Cb5.ogg',
	"Cn5" = 'sound/piano/Cn5.ogg',
	"C#5" = 'sound/piano/C#5.ogg',
	"Db5" = 'sound/piano/Db5.ogg',
	"Dn5" = 'sound/piano/Dn5.ogg',
	"D#5" = 'sound/piano/D#5.ogg',
	"Eb5" = 'sound/piano/Eb5.ogg',
	"En5" = 'sound/piano/En5.ogg',
	"Fb5" = 'sound/piano/Fb5.ogg',
	"E#5" = 'sound/piano/E#5.ogg',
	"Fn5" = 'sound/piano/Fn5.ogg',
	"F#5" = 'sound/piano/F#5.ogg',
	"Gb5" = 'sound/piano/Gb5.ogg',
	"Gn5" = 'sound/piano/Gn5.ogg',
	"Ab5" = 'sound/piano/Ab5.ogg',
	"G#5" = 'sound/piano/G#5.ogg',
	"An5" = 'sound/piano/An5.ogg',
	"A#5" = 'sound/piano/A#5.ogg',
	"Bb5" = 'sound/piano/Bb5.ogg',
	"Bn5" = 'sound/piano/Bn5.ogg',
	"B#5" = 'sound/piano/B#5.ogg',
	"Cb6" = 'sound/piano/Cb6.ogg',
	"Cn6" = 'sound/piano/Cn6.ogg',
	"C#6" = 'sound/piano/C#6.ogg',
	"Db6" = 'sound/piano/Db6.ogg',
	"Dn6" = 'sound/piano/Dn6.ogg',
	"D#6" = 'sound/piano/D#6.ogg',
	"Eb6" = 'sound/piano/Eb6.ogg',
	"En6" = 'sound/piano/En6.ogg',
	"Fb6" = 'sound/piano/Fb6.ogg',
	"E#6" = 'sound/piano/E#6.ogg',
	"Fn6" = 'sound/piano/Fn6.ogg',
	"F#6" = 'sound/piano/F#6.ogg',
	"Gb6" = 'sound/piano/Gb6.ogg',
	"Gn6" = 'sound/piano/Gn6.ogg',
	"Ab6" = 'sound/piano/Ab6.ogg',
	"G#6" = 'sound/piano/G#6.ogg',
	"An6" = 'sound/piano/An6.ogg',
	"A#6" = 'sound/piano/A#6.ogg',
	"Bb6" = 'sound/piano/Bb6.ogg',
	"Bn6" = 'sound/piano/Bn6.ogg',
	"B#6" = 'sound/piano/B#6.ogg',
	"Cb7" = 'sound/piano/Cb7.ogg',
	"Cn7" = 'sound/piano/Cn7.ogg',
	"C#7" = 'sound/piano/C#7.ogg',
	"Db7" = 'sound/piano/Db7.ogg',
	"Dn7" = 'sound/piano/Dn7.ogg',
	"D#7" = 'sound/piano/D#7.ogg',
	"Eb7" = 'sound/piano/Eb7.ogg',
	"En7" = 'sound/piano/En7.ogg',
	"Fb7" = 'sound/piano/Fb7.ogg',
	"E#7" = 'sound/piano/E#7.ogg',
	"Fn7" = 'sound/piano/Fn7.ogg',
	"F#7" = 'sound/piano/F#7.ogg',
	"Gb7" = 'sound/piano/Gb7.ogg',
	"Gn7" = 'sound/piano/Gn7.ogg',
	"Ab7" = 'sound/piano/Ab7.ogg',
	"G#7" = 'sound/piano/G#7.ogg',
	"An7" = 'sound/piano/An7.ogg',
	"A#7" = 'sound/piano/A#7.ogg',
	"Bb7" = 'sound/piano/Bb7.ogg',
	"Bn7" = 'sound/piano/Bn7.ogg',
	"B#7" = 'sound/piano/B#7.ogg',
	"Cb8" = 'sound/piano/Cb8.ogg',
	"Cn8" = 'sound/piano/Cn8.ogg',
	"C#8" = 'sound/piano/C#8.ogg',
	"Db8" = 'sound/piano/Db8.ogg',
	"Dn8" = 'sound/piano/Dn8.ogg',
	"D#8" = 'sound/piano/D#8.ogg',
	"Eb8" = 'sound/piano/Eb8.ogg',
	"En8" = 'sound/piano/En8.ogg',
	"Fb8" = 'sound/piano/Fb8.ogg',
	"E#8" = 'sound/piano/E#8.ogg',
	"Fn8" = 'sound/piano/Fn8.ogg',
	"F#8" = 'sound/piano/F#8.ogg',
	"Gb8" = 'sound/piano/Gb8.ogg',
	"Gn8" = 'sound/piano/Gn8.ogg',
	"Ab8" = 'sound/piano/Ab8.ogg',
	"G#8" = 'sound/piano/G#8.ogg',
	"An8" = 'sound/piano/An8.ogg',
	"A#8" = 'sound/piano/A#8.ogg',
	"Bb8" = 'sound/piano/Bb8.ogg',
	"Bn8" = 'sound/piano/Bn8.ogg',
	"B#8" = 'sound/piano/B#8.ogg',
	"Cb9" = 'sound/piano/Cb9.ogg',
	"Cn9" = 'sound/piano/Cn9.ogg')

/obj/structure/piano/proc/playnote(note)
	instrument_play_note(src, note, samples)

/obj/structure/piano/attack_hand(var/mob/user as mob)
	if (!anchored)
		return

	usr.using_object = src
	instrument_panel(src, user, "Piano", "piano", MAX_LINES)

/obj/structure/piano/Topic(href, href_list)
	instrument_topic(src, usr, href_list, "Piano", "piano", MAX_LINES)

/obj/structure/piano/attackby(obj/item/O as obj, mob/user as mob)
	if (is_tool(O, TOOL_WRENCH))
		if (anchored)
			playsound(loc, 'sound/items/Ratchet.ogg', 50, TRUE)
			to_chat(user, "<span class='notice'>You begin to loosen \the [src]'s casters...</span>")
			if (do_after(user, 40, src))
				user.visible_message( \
					"[user] loosens \the [src]'s casters.", \
					"<span class='notice'>You have loosened \the [src]. Now it can be pulled somewhere else.</span>", \
					"You hear ratchet.")
				anchored = FALSE
		else
			playsound(loc, 'sound/items/Ratchet.ogg', 50, TRUE)
			to_chat(user, "<span class='notice'>You begin to tighten \the [src] to the floor...</span>")
			if (do_after(user, 20, src))
				user.visible_message( \
					"[user] tightens \the [src]'s casters.", \
					"<span class='notice'>You have tightened \the [src]'s casters. Now it can be played again</span>.", \
					"You hear ratchet.")
				anchored = TRUE
	else
		..()
