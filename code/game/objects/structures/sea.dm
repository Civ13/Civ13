/obj/structure/buoy
	name = "buoy"
	desc = "A colorful buoy, marking something."
	icon = 'icons/mob/fish.dmi'
	icon_state = "buoy_rw0"
	var/base_icon_state = "buoy_rw"
	anchored = FALSE
	density = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	var/message = ""
/obj/structure/buoy/update_icon()
	if (istype(loc, /turf/floor/beach/water))
		icon_state = "[base_icon_state]1"
		anchored = TRUE
	else
		icon_state = "[base_icon_state]0"

/obj/structure/buoy/red_white
	name = "red and white buoy"

/obj/structure/buoy/yellow
	name = "yellow buoy"
	icon_state = "buoy_y0"
	base_icon_state = "buoy_y"

/obj/structure/buoy/orange
	name = "orange buoy"
	icon_state = "buoy_o0"
	base_icon_state = "buoy_o"

/obj/structure/buoy/examine(mob/user)
	..()
	if (message != "")
		user << "It has a sign that says: <b>[message]</b>"

/obj/structure/buoy/attackby(obj/item/I as obj, mob/user as mob)
	if (istype(I, /obj/item/weapon/pen))
		message = input(usr, "What do you want the buoy to say?") as text
	else
		..()