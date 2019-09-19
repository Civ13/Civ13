////////////////////////WHEELS AND TRACKS///////////////////

/obj/structure/vehicleparts/movement
	name = "wheel"
	icon_state = "wheel"
	var/base_icon = "wheel"
	var/movement_icon = "wheel_m"
	layer = 2.97
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
	var/left = FALSE

/obj/structure/vehicleparts/movement/tracks/left
	left = TRUE

/obj/structure/vehicleparts/movement/tracks/middle
	icon_state = "tracks_cover"
	base_icon = "tracks_cover"
	movement_icon = "tracks_m_cover"

/obj/structure/vehicleparts/movement/tracks/reversed
	reversed = TRUE

/obj/structure/vehicleparts/movement/tracks/reversed/left
	left = TRUE

/obj/structure/vehicleparts/movement/tracks/MouseDrop(var/obj/structure/vehicleparts/frame/VP)
	if (istype(VP, /obj/structure/vehicleparts/frame) && VP.axis)
		VP.axis.wheels += src
		axis = VP.axis
		playsound(loc, 'sound/effects/lever.ogg',80, TRUE)

/obj/structure/vehicleparts/movement/tracks/update_icon()
	..()
	if (!left)
		switch(dir)
			if(NORTH)
				pixel_x =-21
			if(SOUTH)
				pixel_x =21
			if(WEST)
				pixel_y =21
			if(EAST)
				pixel_y =-21
	else
		switch(dir)
			if(NORTH)
				pixel_x =21
			if(SOUTH)
				pixel_x =-21
			if(WEST)
				pixel_y =-21
			if(EAST)
				pixel_y =21
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


var/global/list/rotation_matrixes = list(
/*
	"left" = list(
		"1,1" = list("1,5"),
		"1,2" = list("2,5"),
		"1,3" = list("3,5"),
		"1,4" = list("4,5"),
		"1,5" = list("5,5"),

		"2,1" = list("1,4"),
		"2,2" = list("2,4"),
		"2,3" = list("3,4"),
		"2,4" = list("4,4"),
		"2,5" = list("5,4"),

		"3,1" = list("1,3"),
		"3,2" = list("2,3"),
		"3,3" = list("3,3"),
		"3,4" = list("4,3"),
		"3,5" = list("5,3"),

		"4,1" = list("1,2"),
		"4,2" = list("2,2"),
		"4,3" = list("3,2"),
		"4,4" = list("4,2"),
		"4,5" = list("5,2"),

		"5,1" = list("1,1"),
		"5,2" = list("2,1"),
		"5,3" = list("3,1"),
		"5,4" = list("4,1"),
		"5,5" = list("5,1"),),
*/
	"left" = list(
		"1,1" = list("5,1"),
		"1,2" = list("4,1"),
		"1,3" = list("3,1"),
		"1,4" = list("2,1"),
		"1,5" = list("1,1"),

		"2,1" = list("5,2"),
		"2,2" = list("4,2"),
		"2,3" = list("3,2"),
		"2,4" = list("2,2"),
		"2,5" = list("1,2"),

		"3,1" = list("5,3"),
		"3,2" = list("4,3"),
		"3,3" = list("3,3"),
		"3,4" = list("2,3"),
		"3,5" = list("1,3"),

		"4,1" = list("5,4"),
		"4,2" = list("4,4"),
		"4,3" = list("3,4"),
		"4,4" = list("2,4"),
		"4,5" = list("1,4"),

		"5,1" = list("5,5"),
		"5,2" = list("4,5"),
		"5,3" = list("3,5"),
		"5,4" = list("2,5"),
		"5,5" = list("1,5"),),
	"right" = list(
		"1,1" = list("5,1"),
		"1,2" = list("4,1"),
		"1,3" = list("3,1"),
		"1,4" = list("2,1"),
		"1,5" = list("1,1"),

		"2,1" = list("5,2"),
		"2,2" = list("4,2"),
		"2,3" = list("3,2"),
		"2,4" = list("2,2"),
		"2,5" = list("1,2"),

		"3,1" = list("5,3"),
		"3,2" = list("4,3"),
		"3,3" = list("3,3"),
		"3,4" = list("2,3"),
		"3,5" = list("1,3"),

		"4,1" = list("5,4"),
		"4,2" = list("4,4"),
		"4,3" = list("3,4"),
		"4,4" = list("2,4"),
		"4,5" = list("1,4"),

		"5,1" = list("5,5"),
		"5,2" = list("4,5"),
		"5,3" = list("3,5"),
		"5,4" = list("2,5"),
		"5,5" = list("1,5"),),
)
/*
	SOUTH = list(
		"1,1" = list(5,5),
		"1,2" = list(5,4),
		"1,3" = list(5,3),
		"1,4" = list(5,2),
		"1,5" = list(5,1),

		"2,1" = list(4,5),
		"2,2" = list(4,4),
		"2,3" = list(4,3),
		"2,4" = list(4,2),
		"2,5" = list(4,1),

		"3,1" = list(3,5),
		"3,2" = list(3,4),
		"3,3" = list(3,3),
		"3,4" = list(3,2),
		"3,5" = list(3,1),

		"4,1" = list(2,5),
		"4,2" = list(2,4),
		"4,3" = list(2,3),
		"4,4" = list(2,2),
		"4,5" = list(2,1),

		"5,1" = list(1,5),
		"5,2" = list(1,4),
		"5,3" = list(1,3),
		"5,4" = list(1,2),
		"5,5" = list(1,1),),
	EAST = list(
		"1,1" = list(5,1),
		"1,2" = list(4,1),
		"1,3" = list(3,1),
		"1,4" = list(2,1),
		"1,5" = list(1,1),

		"2,1" = list(5,2),
		"2,2" = list(4,2),
		"2,3" = list(3,2),
		"2,4" = list(2,2),
		"2,5" = list(1,2),

		"3,1" = list(5,2),
		"3,2" = list(4,3),
		"3,3" = list(3,3),
		"3,4" = list(2,3),
		"3,5" = list(1,3),

		"4,1" = list(5,4),
		"4,2" = list(4,4),
		"4,3" = list(3,4),
		"4,4" = list(2,4),
		"4,5" = list(1,4),

		"5,1" = list(5,5),
		"5,2" = list(4,5),
		"5,3" = list(3,5),
		"5,4" = list(2,5),
		"5,5" = list(1,5),),
	NORTH = list(
		"1,1" = list(1,1),
		"1,2" = list(1,2),
		"1,3" = list(1,3),
		"1,4" = list(1,4),
		"1,5" = list(1,5),

		"2,1" = list(2,1),
		"2,2" = list(2,2),
		"2,3" = list(2,3),
		"2,4" = list(2,4),
		"2,5" = list(2,5),

		"3,1" = list(3,1),
		"3,2" = list(3,2),
		"3,3" = list(3,3),
		"3,4" = list(3,4),
		"3,5" = list(3,5),

		"4,1" = list(4,1),
		"4,2" = list(4,2),
		"4,3" = list(4,3),
		"4,4" = list(4,4),
		"4,5" = list(4,5),

		"5,1" = list(5,1),
		"5,2" = list(5,2),
		"5,3" = list(5,3),
		"5,4" = list(5,4),
		"5,5" = list(5,5),),)
*/