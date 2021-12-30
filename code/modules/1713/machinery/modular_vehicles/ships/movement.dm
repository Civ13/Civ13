////////////////////////WHEELS AND TRACKS///////////////////

/obj/structure/vehicleparts/movement/sails
	name = "wood mast"
	icon = 'icons/obj/vehicles/vehicleparts64x64.dmi'
	icon_state = "sail0"
	base_icon = "sail1"
	movement_icon = "sail2"
	layer = 2.99
	broken = FALSE
	var/obj/item/sail/sails = null
	ntype = "mast"
	var/sails_on = FALSE

/obj/structure/vehicleparts/movement/sails/premade/New()
	..()
	sails = new/obj/item/sail(src)
	update_icon()

/obj/structure/vehicleparts/movement/sails/update_icon()
	if (sails)
		if (sails_on)
			icon_state = movement_icon
		else
			icon_state = base_icon
	else
		icon_state = "sail0"

/obj/structure/vehicleparts/movement/sails/MouseDrop(var/obj/structure/vehicleparts/frame/ship/VP)
	if (istype(VP, /obj/structure/vehicleparts/frame/ship) && VP.axis)
		dir = VP.axis.dir
		VP.axis.masts += src
		axis = VP.axis
		connected = VP
		VP.mwheel = src
		forceMove(VP)
		playsound(loc, 'sound/effects/lever.ogg',80, TRUE)

/obj/structure/vehicleparts/movement/sails/attackby(var/obj/item/I, var/mob/living/human/H)
	if (istype(I, /obj/item/weapon/weldingtool))
		return
	else
		if (istype(I, /obj/item/sail) && !sails)
			sails = I
			H.drop_from_inventory(I)
			I.forceMove(src)
			H << "You add the sail to the mast."
			update_icon()
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
	sails = null
	visible_message("<span class='danger'>\The [name] gets destroyed!</span>")
	..()