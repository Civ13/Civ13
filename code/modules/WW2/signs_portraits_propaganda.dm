/obj/structure/sign/portrait

/* // this has never worked, not sure why, but its disabled now
/obj/structure/sign/portrait/verb/tear()
	set category = null
	set src in oview(1, usr)
	if (!locate(src) in get_step(usr, usr.dir))
		return FALSE
	visible_message("<span class = 'danger'>[usr] starts to tear down [src]...</span>")
	if (do_after(usr, 30, get_turf(src)))
		visible_message("<span class = 'danger'>[usr] tears down [src]!</span>")
		qdel(src)*/

/obj/structure/sign/portrait/hitler
	name = "Portrait of Hitler"
	desc = "Our glorious Führer!"
	icon_state = "hitler"

/obj/structure/sign/portrait/stalin
	name = "Portrait of Stalin"
	icon_state = "stalin"

/obj/structure/sign/portrait/hirohito
	name = "Portrait of Hirohito"
	icon_state = "hirohito"

/obj/structure/sign/portrait/propaganda

/obj/structure/sign/portrait/propaganda/sov1
	name = "Soviet Propaganda Poster"
	icon_state = "soviet_prop_1"
/obj/structure/sign/portrait/propaganda/sov2
	name = "Soviet Propaganda Poster"
	icon_state = "soviet_prop_2"
/obj/structure/sign/portrait/propaganda/sov3
	name = "Soviet Propaganda Poster"
	icon_state = "soviet_prop_3"

/obj/structure/sign/portrait/propaganda/ger1
	name = "German Propaganda Poster"
	icon_state = "ger_prop_1"
/obj/structure/sign/portrait/propaganda/ger2
	name = "German Propaganda Poster"
	icon_state = "ger_prop_2"