// Glide probe: how Dream Seeker draws pixel-offset movement under each
// world.movement_mode. Compile with -DMODE=... via the two .dme files.
// Red:   2px pulses every tick through Move() with step offsets (free movement).
// Green: the same pulses, plus a pixel_w counter-offset animated back to 0.
// Blue:  ordinary tile steps every 4 ticks with glide_size 8 (NPC style).
// The camera is a fixed turf so only the movers move.
/world
	name = "glidetest"
	fps = 25
	icon_size = 32
	view = "15x5"
	maxx = 40
	maxy = 9
	maxz = 1
	movement_mode = MODE
	mob = /mob/observer
	turf = /turf/floor

/turf/floor
	icon = 'glidetest.dmi'
	icon_state = "floor"

/mob/observer
	invisibility = 101
	density = 0

/client
	fps = 100

/mob/observer/Login()
	..()
	loc = locate(20, 5, 1)
	client.eye = loc
	client.perspective = EYE_PERSPECTIVE
	new /obj/mover/red(locate(13, 7, 1))
	new /obj/mover/green(locate(13, 5, 1))
	new /obj/mover/blue(locate(13, 3, 1))

/obj/mover
	icon = 'glidetest.dmi'
	density = 0

/obj/mover/New()
	..()
	spawn(20)
		drive()

/obj/mover/proc/drive()

/obj/mover/red
	icon_state = "red"

/obj/mover/red/drive()
	while (src)
		var/sx = step_x + 2
		var/tx = x
		if (sx >= 32)
			sx -= 32
			tx++
		if (tx > 26)
			tx = 13
			sx = 0
		Move(locate(tx, y, z), EAST, sx, 0)
		sleep(world.tick_lag)

/obj/mover/green
	icon_state = "green"

/obj/mover/green/drive()
	while (src)
		var/sx = step_x + 2
		var/tx = x
		var/wrap = FALSE
		if (sx >= 32)
			sx -= 32
			tx++
		if (tx > 26)
			tx = 13
			sx = 0
			wrap = TRUE
		Move(locate(tx, y, z), EAST, sx, 0)
		if (!wrap)
			pixel_w = -2
			animate(src, pixel_w = 0, time = world.tick_lag)
		sleep(world.tick_lag)

/obj/mover/blue
	icon_state = "blue"
	glide_size = 8

/obj/mover/blue/drive()
	while (src)
		var/tx = x + 1
		if (tx > 26)
			loc = locate(13, y, z)
		else
			Move(locate(tx, y, z), EAST)
		sleep(4 * world.tick_lag)
