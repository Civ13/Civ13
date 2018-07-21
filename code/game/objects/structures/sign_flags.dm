/obj/structure/sign/flag
	var/ripped = FALSE

/obj/structure/sign/flag/attack_hand(mob/user as mob)
	if (!ripped)
		playsound(loc, 'sound/items/poster_ripped.ogg', 100, TRUE)
		for (var/i = FALSE to 3)
			if (do_after(user, 10))
				playsound(loc, 'sound/items/poster_ripped.ogg', 100, TRUE)
			else
				return
		visible_message("<span class='warning'>[user] rips [src]!</span>" )
		icon_state += "_ripped"
		ripped = TRUE

/obj/structure/sign/flag/russian
	name = "\improper Russian flag"
	desc = "Just like new and very dense. Holds a point blank pistol shot "
	icon_state = "ru_flag"

/obj/structure/sign/flag/usa
	name = "\improper USA flag"
	desc = "Democracy! Freedom! U! S! A!"
	icon_state = "usa_flag"

/obj/structure/sign/flag/local
	name = "\improper Local flag"
	desc = "I don't even remember to which country Slatino belongs."
	icon_state = "local_flag"

/obj/structure/sign/clock
	name = "\improper Broken clock"
	desc = "Stopped at 5 o'clock."
	icon_state = "clock"

/obj/structure/sign/wide
	icon = 'icons/obj/decals_wide.dmi'
	bound_x = 32

/obj/structure/sign/wide/carpet
	name = "\improper Carpet"
	desc = "A low quality carpet dangling on the wall."
	icon = 'icons/obj/decals_wide.dmi'
	icon_state = "carpet"
	layer = OBJ_LAYER - 0.1

/obj/structure/sign/wide/loc_name_sign
	name = "Slatino sign"
	desc = "Heeey! That's not Prishtina! That's Slatino!"
	icon_state = "slatino"
	density = TRUE

/obj/structure/sign/wide/barrier
	name = "Security Gate"
	icon = 'icons/obj/gate.dmi'
	desc = "A base security gate. Pull it to the side to let vehicles pass."
	icon_state = "gate"
	density = TRUE

/obj/structure/sign/flag/germany
	name = "Third Reich flag"
	desc = "Ein Volk, ein Reich, ein Fuhrer!"
	icon_state = "ger_flag"

/obj/structure/sign/flag/pirates
	name = "Soviet Union flag"
	desc = "Soyuz nerushimy respublik svobodnyh!"
	icon_state = "sov_flag"

/obj/structure/sign/flag/germany2
	name = "Third Reich flag"
	desc = "Ein Volk, ein Reich, ein Fuhrer!"
	icon_state = "ger_flag"

/obj/structure/sign/flag/pirates2
	name = "Soviet Union flag"
	desc = "Soyuz nerushimy respublik svobodnyh!"
	icon_state = "sov_flag"

/obj/structure/sign/flag/japanese
	name = "Japanese Empire flag"
	desc = "BANZAI! BANZAI! BANZAI!"
	icon_state = "japan_flag"


/obj/structure/sign/flag/medical
	name = "Medical flag"
	desc = "A flag witht the universally recognized symbol for medicine."
	icon_state = "medical_flag"

/obj/structure/sign/flag/germanybanner
	name = "Third Reich banner"
	desc = "Ein Volk, ein Reich, ein Fuhrer!"
	icon_state = "ger_banner"

/obj/structure/sign/flag/piratesbanner
	name = "Soviet Union banner"
	desc = "Soyuz nerushimy respublik svobodnyh!"
	icon_state = "sov_banner"


/obj/structure/sign/flag/germanycerflag
	name = "Third Reich flag"
	desc = "Ein Volk, ein Reich, ein Fuhrer!"
	icon_state = "ger_cerflag"

/obj/structure/sign/flag/piratescerflag
	name = "Soviet Union flag"
	desc = "Soyuz nerushimy respublik svobodnyh!"
	icon_state = "sov_cerflag"

/obj/structure/sign/wide96
	icon = 'icons/obj/decals_32x96.dmi'

/obj/structure/sign/wide96/ger_bigbanner
	name = "Big Third Reich banner"
	desc = "A big Swastika banner."
	icon_state = "ger_extbanner"