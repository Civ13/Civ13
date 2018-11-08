/obj/structure/sign/flag
	var/ripped = FALSE
	icon = 'icons/obj/decals.dmi'
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

/obj/structure/sign/flag/red
	name = "\improper red banner"
	desc = "A red linen banner."
	icon_state = "red_banner"
/obj/structure/sign/flag/red2
	name = "\improper red banner"
	desc = "A red linen banner, with golden trims."
	icon_state = "red_banner2"

/obj/structure/sign/flag/blue
	name = "\improper blue banner"
	desc = "A blue linen banner."
	icon_state = "blue_banner"
/obj/structure/sign/flag/blue2
	name = "\improper blue banner"
	desc = "A blue linen banner, with golden trims."
	icon_state = "blue_banner2"

/obj/structure/sign/flag/templar1
	name = "\improper templar banner"
	desc = "A white banner with the red cross of the templars in the middle."
	icon_state = "templar_banner1"

/obj/structure/sign/flag/templar2
	name = "\improper templar banner"
	desc = "A white banner with the red cross of the templars in the middle."
	icon_state = "templar_banner2"

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


/obj/structure/sign/flag/medical
	name = "Medical flag"
	desc = "A flag witht the universally recognized symbol for medicine."
	icon_state = "medical_flag"
