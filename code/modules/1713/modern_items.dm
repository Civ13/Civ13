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

/obj/structure/heatsource/New()
	..()
	do_light()

/obj/structure/lamppost_small/attackby(obj/item/weapon/W as obj, mob/user as mob)
	//TODO: Cable stuff
	..()
/obj/structure/lamppost_small/proc/do_light()
	if (powered && powersource)
		if (powersource.on)
			set_light(6)
			icon_state = "lamppost_small_on"
		else
			set_light(0)
			icon_state = "lamppost_small"
			powered = FALSE
	else
		set_light(0)
		icon_state = "lamppost_small"
		powered = FALSE
	spawn(10)
		do_light()