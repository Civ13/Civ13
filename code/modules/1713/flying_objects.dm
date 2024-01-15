// Missiles

/obj/structure/nuclear_missile
	name = "nuclear missile"
	desc = "A short range tactical nuclear missile."
	icon = 'icons/obj/decals_wider.dmi'
	icon_state = "rocket"
	density = TRUE
	opacity = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	flammable = FALSE
	anchored = TRUE
	var/active = FALSE
	var/flight_time = 4 SECONDS
	var/flight_distance = 15 // in tiles
	pixel_x = -32
	layer = 6.01

/obj/structure/nuclear_missile/update_icon()
	overlays.Cut()
	if (active)
		layer = 12.0
		overlays += image("icon" = 'icons/obj/decals_wider.dmi', "icon_state" = "rocket_o", "pixel_y" = -96)

/obj/structure/nuclear_missile/proc/activate()
	if (!active)
		active = TRUE
		update_icon()
		var/sound/uploaded_sound = sound('sound/effects/aircraft/effects/missile_big.ogg', repeat = FALSE, wait = TRUE, channel = 777)
		uploaded_sound.priority = 250
		for (var/mob/M in player_list)
			if (!new_player_mob_list.Find(M))
				//M << SPAN_DANGER("<font size=3>A nuclear missile has been launched!</font>")
				M.client << uploaded_sound
		animate(src, pixel_y = flight_distance*32, time = flight_time, alpha = 150, easing = SINE_EASING | EASE_IN)
		spawn(flight_time) // has to be equal to flight time else it'll look weird
			qdel(src)


// Planes DO NOT USE YET, NEEDS CODE ADJUSTEMENTS

/obj/structure/plane
	name = "plane"
	desc = "A plane."
	icon = 'icons/obj/vehicles/vehicles256x256.dmi'
	icon_state = "ar10"
	density = TRUE
	opacity = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	flammable = FALSE
	anchored = TRUE
	var/flight_time = 12 SECONDS
	var/flight_distance = 15 // in tiles
	var/start_point_x = 1
	var/start_point_y = 1
	var/end_point_x = 0
	var/end_point_y = 0
	layer = 14

/obj/structure/plane/proc/fly()
	switch(dir)
		if (NORTH)
			//flight_distance = world.maxy-src.y
			end_point_y = world.maxy
			end_point_x = src.x
			//animate(src, pixel_y = flight_distance*32, time = flight_time, easing = LINEAR_EASING)
			src.Move(locate(end_point_x,end_point_y,src.z))
		if (SOUTH)
			flight_distance = world.maxy-src.y
			animate(src, pixel_y = -(flight_distance*32), time = flight_time, easing = LINEAR_EASING)
		if (EAST)
			flight_distance = world.maxx-src.x
			animate(src, pixel_x = flight_distance*32, time = flight_time, easing = LINEAR_EASING)
		if (WEST)
			flight_distance = world.maxx-src.x
			animate(src, pixel_x = -(flight_distance*32), time = flight_time, easing = LINEAR_EASING)
	spawn(flight_time)
		qdel(src)

