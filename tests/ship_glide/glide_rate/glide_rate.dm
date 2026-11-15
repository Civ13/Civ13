// How Dream Seeker draws a one-tile move made by setting loc (as a craft's
// forceMove does) at a slow-ahead ship's glide (32 px over 150 ds), 25 fps
// like Civ13. Recorded by run_glide_rate.py. Every row steps east a tile
// every 15 s; each differs from the control in one way a ship's plank does:
//  y3 red    control: FORWARD_STEPS, glide set long before
//  y4 green  SLIDE_STEPS (every Civ13 /obj and /mob)
//  y5 blue   glide given in the same tick, just before the move
//  y6 red    the tile it arrives on changes area just before the move
//  y7 green  the tile it arrives on changes appearance just before the move
//  y8 blue   all of the above at once, as a ship's plank
// The camera is a fixed turf throughout.
#define MOVER_SLIDE 1
#define MOVER_LATE_GLIDE 2
#define MOVER_AREA 4
#define MOVER_TURF_LOOK 8
#define MOVER_GLIDE 0.0853333

/world
	name = "gliderate"
	fps = 25
	icon_size = 32
	view = "17x7"
	maxx = 80
	maxy = 11
	maxz = 1
	mob = /mob/watcher
	turf = /turf/floor

/turf/floor
	icon = 'glidetest.dmi'
	icon_state = "floor"

/mob/watcher
	icon = 'glidetest.dmi'
	icon_state = "red"

/client
	fps = 100

var/global/started = 0

/area/one
/area/two

/mob/watcher/Login()
	..()
	loc = locate(20, 1, 1)
	client.eye = locate(20, 6, 1)
	client.perspective = EYE_PERSPECTIVE
	new /obj/mover(locate(13, 3, 1), "red", 0)
	new /obj/mover(locate(13, 4, 1), "green", MOVER_SLIDE)
	new /obj/mover(locate(13, 5, 1), "blue", MOVER_LATE_GLIDE)
	new /obj/mover(locate(13, 6, 1), "red", MOVER_AREA)
	new /obj/mover(locate(13, 7, 1), "green", MOVER_TURF_LOOK)
	new /obj/mover(locate(13, 8, 1), "blue", MOVER_SLIDE | MOVER_LATE_GLIDE | MOVER_AREA | MOVER_TURF_LOOK)
	started = world.time

/obj/mover
	icon = 'glidetest.dmi'
	density = 0
	animate_movement = FORWARD_STEPS
	var/how = 0

/obj/mover/New(loc, state, how)
	..()
	icon_state = state
	src.how = how
	if (how & MOVER_SLIDE)
		animate_movement = SLIDE_STEPS
	glide_size = (how & MOVER_LATE_GLIDE) ? 0 : MOVER_GLIDE
	spawn(30)
		drive()

/obj/mover/proc/drive()
	var/flip = FALSE
	while (src)
		var/turf/T = locate(x + 1 > 60 ? 13 : x + 1, y, z)
		if (how & MOVER_AREA)
			flip = !flip
			var/area/A = locate(flip ? /area/one : /area/two)
			if (!A)
				A = new (flip ? /area/one : /area/two)
			A.contents += T
		if (how & MOVER_TURF_LOOK)
			T.color = T.color ? null : "#c0c0ff"
		if (how & MOVER_LATE_GLIDE)
			glide_size = MOVER_GLIDE
		loc = T
		sleep(150)
