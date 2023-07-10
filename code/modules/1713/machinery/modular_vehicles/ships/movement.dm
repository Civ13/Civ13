////////////////////////WHEELS AND TRACKS///////////////////

/obj/structure/vehicleparts/movement/sail
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

/obj/structure/vehicleparts/movement/sail/premade/New()
	..()
	sails = new/obj/item/sail(src)
	update_icon()

/obj/structure/vehicleparts/movement/sail/update_icon()
	if (sails)
		if (sails_on)
			icon_state = movement_icon
		else
			icon_state = base_icon
	else
		icon_state = "sail0"

/obj/structure/vehicleparts/movement/sail/MouseDrop(var/obj/structure/vehicleparts/frame/ship/VP)
	if (istype(VP, /obj/structure/vehicleparts/frame/ship) && VP.axis)
		dir = VP.axis.dir
		VP.axis.masts += src
		axis = VP.axis
		connected = VP
		VP.mwheel = src
		forceMove(VP)
		playsound(loc, 'sound/effects/lever.ogg',80, TRUE)

/obj/structure/vehicleparts/movement/sail/attackby(var/obj/item/I, var/mob/living/human/H)
	if (istype(I, /obj/item/weapon/weldingtool))
		return
	if (istype(I, /obj/item/sail) && !sails)
		H << SPAN_NOTICE("You begin adding \the [I] to \the [src].")
		if (do_after(H,25,src))
			sails = I
			H.drop_from_inventory(I)
			I.forceMove(src)
			H <<  SPAN_NOTICE("You add \the [I] to \the [src].")
			update_icon()
	if (istype(I,/obj/item/weapon/hammer) && sails)
		playsound(loc, 'sound/items/Screwdriver.ogg', 75, TRUE)
		H << SPAN_NOTICE("You begin taking down \the [sails].")
		if (do_after(H,25,src))
			sails = null
			sails.forceMove(H)
			H << SPAN_NOTICE("You take \the [sails] off of \the [src].")
			update_icon()
	else
		..()


/obj/structure/vehicleparts/movement/sail/ex_act(severity)
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

/obj/structure/vehicleparts/movement/sail/Destroy()
	if (axis)
		axis.wheels -= src
	sails = null
	visible_message("<span class='danger'>\The [name] gets destroyed!</span>")
	..()