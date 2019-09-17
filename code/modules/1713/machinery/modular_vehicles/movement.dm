////////////////////////WHEELS AND TRACKS///////////////////

/obj/structure/vehicleparts/movement
	name = "wheel"
	icon_state = "wheel"
	var/base_icon = "wheel"
	var/movement_icon = "wheel_m"
	layer = 4
	var/reversed = FALSE
	var/obj/structure/vehicleparts/axis/axis = null
	var/broken = FALSE
	var/ntype = "wheel"

/obj/structure/vehicleparts/movement/tracks
	name = "armored tracks"
	icon_state = "tracks_end"
	base_icon = "tracks_end"
	movement_icon = "tracks_end_m"
	ntype = "track"
/obj/structure/vehicleparts/movement/tracks/reversed
	reversed = TRUE
/obj/structure/vehicleparts/movement/tracks/MouseDrop(var/obj/structure/vehicleparts/frame/VP)
	if (istype(VP, /obj/structure/vehicleparts/frame) && VP.axis)
		VP.axis.wheels += src
		axis = VP.axis
		playsound(loc, 'sound/effects/lever.ogg',80, TRUE)

/obj/structure/vehicleparts/movement/attackby(var/obj/item/I, var/mob/living/carbon/human/H)
	if (broken && istype(I, /obj/item/weapon/wrench))
		visible_message("[H] starts repairing \the [ntype]...")
		if (do_after(H, 200, src))
			visible_message("[H] sucessfully repairs \the [ntype].")
			broken = FALSE
			return
	else
		..()

/obj/structure/vehicleparts/movement/ex_act(severity)
	switch(severity)
		if (1.0)
			Destroy()
			return
		if (2.0)
			if (prob(30))
				Destroy()
				return
		if (3.0)
			if (!broken)
				broken = TRUE
				visible_message("<span class='danger'>\The [name] breaks down!</span>")
			return


/obj/structure/vehicleparts/movement/tracks/ex_act(severity)
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

/obj/structure/vehicleparts/movement/Destroy()
	if (axis)
		axis.wheels -= src
	visible_message("<span class='danger'>\The [name] gets destroyed!</span>")
	qdel(src)