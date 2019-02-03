/obj/structure/lamppost_small
	name = "small lamp post"
	desc = "A small lamp post, good for outdoor illumination."
	icon = 'icons/obj/lighting.dmi'
	icon_state = "lamppost_small"
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	var/on = FALSE
	not_movable = TRUE
	not_disassemblable = FALSE
	powerneeded = 2

/obj/structure/lamppost_small/New()
	..()
	do_light()

/obj/structure/lamppost_small/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/stack/cable_coil))
		var/obj/item/stack/cable_coil/CC = W
		powersource = CC.place_turf(get_turf(src), user, turn(get_dir(user,src),180))
		powersource.connections += src
		user << "You connect the cable to the [src]."
	else
		..()
/obj/structure/lamppost_small/proc/do_light()
	if (check_power())
		set_light(6)
		icon_state = "lamppost_small_on"
		powered = TRUE
	else
		set_light(0)
		icon_state = "lamppost_small"
		powered = FALSE
	spawn(10)
		do_light()

/obj/structure/lamppost_small/proc/check_power()
	if (!powersource || powerneeded == 0)
		return FALSE
	else
		if (powersource.powered && powersource.powerflow >= powerneeded)
			powersource.powerflow-=powerneeded
			return TRUE
		else
			return FALSE