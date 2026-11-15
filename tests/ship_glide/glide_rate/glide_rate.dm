// How Dream Seeker draws a one-tile move made by setting loc (as a craft's
// forceMove does) at slow glide sizes. 25 fps like Civ13. Recorded by
// run_glide_rate.py; see README.md.
// Rows (bottom to top), each stepping east one tile when its last glide is due to end:
//  y3 red    glide 0.085 (a slow-ahead ship step: 32 px over 150 ds)
//  y4 green  glide 0.25
//  y5 blue   glide 0.5
//  y6 red    glide 1
//  y7 green  glide 0.5, moved with Move() instead of loc
//  y8 blue   glide 4
// For the first 20 s the camera is a fixed turf; then it follows a mob that
// steps north... east with glide 0.5 by loc, as a sailor carried by a ship.
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

/mob/watcher/Login()
	..()
	loc = locate(20, 1, 1)
	client.eye = locate(20, 6, 1)
	client.perspective = EYE_PERSPECTIVE
	new /obj/mover(locate(13, 3, 1), "red", 0.085, FALSE)
	new /obj/mover(locate(13, 4, 1), "green", 0.25, FALSE)
	new /obj/mover(locate(13, 5, 1), "blue", 0.5, FALSE)
	new /obj/mover(locate(13, 6, 1), "red", 1, FALSE)
	new /obj/mover(locate(13, 7, 1), "green", 0.5, TRUE)
	new /obj/mover(locate(13, 8, 1), "blue", 4, FALSE)
	started = world.time
	spawn(500)
		// Phase two: the camera rides a carried body.
		loc = locate(13, 10, 1)
		glide_size = 0.5
		client.eye = src
		client.perspective = MOB_PERSPECTIVE
		while (src)
			sleep(64 * world.tick_lag)
			loc = locate(x + 1, y, z)

/obj/mover
	icon = 'glidetest.dmi'
	density = 0
	var/use_move = FALSE

/obj/mover/New(loc, state, glide, mover)
	..()
	icon_state = state
	glide_size = glide
	use_move = mover
	spawn(30)
		drive()

/obj/mover/proc/drive()
	var/interval = max(25, round(32 / glide_size)) * world.tick_lag
	while (src)
		var/turf/T = locate(x + 1 > 60 ? 13 : x + 1, y, z)
		if (use_move)
			Move(T, EAST)
		else
			loc = T
		sleep(interval)
