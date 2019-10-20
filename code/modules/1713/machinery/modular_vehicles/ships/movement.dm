////////////////////////WHEELS AND TRACKS///////////////////

/obj/structure/vehicleparts/movement/sails
	name = "wood mast"
	icon = 'icons/obj/vehicleparts64x64.dmi'
	icon_state = "sail0"
	base_icon = "sail0"
	movement_icon = "sail1"
	layer = 2.99
	broken = FALSE
	var/obj/item/sail/sails = null
	ntype = "mast"
	var/sails_on = FALSE

/obj/structure/vehicleparts/movement/sails/update_icon()
	if (sails && sails_on)
		icon_state = movement_icon
	else
		icon_state = base_icon

/obj/structure/vehicleparts/movement/sails/MouseDrop(var/obj/structure/vehicleparts/frame/ship/VP)
	if (istype(VP, /obj/structure/vehicleparts/frame/ship) && VP.axis)
		if (!isemptylist(VP.axis.corners))
			if (VP == VP.axis.corners[1])
				reversed = FALSE
			else if (VP == VP.axis.corners[2])
				if (ntype == "wheel")
					reversed = TRUE
				else
					reversed = FALSE
			else if (VP == VP.axis.corners[3])
				if (ntype == "wheel")
					reversed = FALSE
				else
					reversed = TRUE
			else if (VP == VP.axis.corners[4])
				if (ntype == "wheel")
					reversed = TRUE
				else
					reversed = TRUE
			else
				return

			dir = VP.axis.dir
			VP.axis.masts += src
			axis = VP.axis
			connected = VP
			VP.mwheel = src
			forceMove(VP)
			playsound(loc, 'sound/effects/lever.ogg',80, TRUE)

/obj/structure/vehicleparts/movement/sails/attackby(var/obj/item/I, var/mob/living/carbon/human/H)
	if (istype(I, /obj/item/weapon/weldingtool))
		return
	else
		if (istype(I, /obj/item/sail))
			sails = I
			H.drop_from_inventory(I)
			I.forceMove(src)
			H << "You add the sail to the mast."
		else
			..()


/obj/structure/vehicleparts/movement/sails/ex_act(severity)
	switch(severity)
		if (1.0)
			if (prob(40))
				Destroy()
				return
		if (2.0)
			if (prob(10))
				Destroy()
				return
		if (3.0)
			if (!broken && prob(80))
				broken = TRUE
				visible_message("<span class='danger'>\The [name] breaks down!</span>")
			return

/obj/structure/vehicleparts/movement/sails/Destroy()
	if (axis)
		axis.wheels -= src
	visible_message("<span class='danger'>\The [name] gets destroyed!</span>")
	qdel(src)