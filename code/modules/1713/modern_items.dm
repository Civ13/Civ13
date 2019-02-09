/obj/structure/lamp
	name = "small lamp post"
	desc = "A small lamp post, good for outdoor illumination."
	icon = 'icons/obj/lighting.dmi'
	icon_state = "lamppost_small"
	var/base_icon = "lamppost_small"
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	var/on = FALSE
	not_movable = TRUE
	not_disassemblable = FALSE
	powerneeded = 2
	var/light_amt = 6 //light range
	layer = 3.95

/obj/structure/lamp/New()
	..()
	do_light()

/obj/structure/lamp/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/stack/cable_coil))
		if (powersource)
			user << "There's already a cable connected here! Split it further from the engine."
			return
		var/obj/item/stack/cable_coil/CC = W
		powersource = CC.place_turf(get_turf(src), user, turn(get_dir(user,src),180))
		powersource.connections += src
		user << "You connect the cable to the [src]."
	else
		..()


/obj/structure/lamp/proc/do_light()
	if (check_power())
		set_light(light_amt)
		icon_state = "[base_icon]_on"
		powered = TRUE
		on = TRUE
	else
		set_light(0)
		icon_state = base_icon
		powered = FALSE
		on = FALSE

	spawn(10)
		do_light()

/obj/structure/lamp/proc/check_power()
	if (!powersource || powerneeded == 0)
		return FALSE
	else
		if (powersource.powered && ((powersource.powerflow-powersource.currentflow) >= powerneeded))
			if (!on)
				powersource.update_power(powerneeded)
				on = TRUE
			return TRUE
		else
			if (on)
				powersource.update_power(powerneeded)
				on = FALSE
			return FALSE

/obj/structure/lamp/lamppost_small
	name = "small lamp post"
	desc = "A small lamp post, good for outdoor illumination."
	icon_state = "lamppost_small"
	powerneeded = 2
	light_amt = 6

/obj/structure/lamp/lamp_small
	name = "small lightbulb"
	desc = "A small lightbulb."
	icon_state = "bulb"
	base_icon = "bulb"
	powerneeded = 1
	light_amt = 3
	not_movable = FALSE
	not_disassemblable = FALSE

/obj/structure/lamp/lamp_big
	name = "light tube"
	desc = "A light tube."
	icon_state = "tube"
	base_icon = "tube"
	powerneeded = 1.3
	light_amt = 4
	not_movable = FALSE
	not_disassemblable = FALSE