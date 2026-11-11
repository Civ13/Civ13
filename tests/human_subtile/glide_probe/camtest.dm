// Camera probe: the player's own mob walks with free-movement style pulses
// (16 x 2px per 13 ticks, due times rounded up to ticks) with the camera on it.
// SMOOTH 0 = raw pulses; 1 = Civ13 human_subtile_smooth_pulse (shipped);
// 2 = chained zero-time animate, 3 = relative animate, 4 = per-tick batching.
/world
	name = "glidetest"
	fps = 25
	icon_size = 32
	view = "15x5"
	maxx = 80
	maxy = 9
	maxz = 1
	mob = /mob/walker
#ifdef PIXELMODE
	movement_mode = PIXEL_MOVEMENT_MODE
#endif
	turf = /turf/floor

/turf/floor
	icon = 'glidetest.dmi'
	icon_state = "floor"

/client
	fps = 100

/mob/walker
	icon = 'glidetest.dmi'
	icon_state = "red"
#ifdef PIXELMODE
	glide_size = 32 / 13
#endif
	var/smooth_start
	var/pend_x = 0
	var/pend_y = 0
	var/pend_spacing = 0
	var/flush_queued = FALSE
	var/smooth_time = 0
	var/smooth_from_x = 0
	var/smooth_from_y = 0

/mob/walker/Login()
	..()
	loc = locate(10, 5, 1)
	spawn(30)
		walkloop()

// SMOOTH 4: pulses in one tick are collected and drawn with one animation.
/mob/walker/proc/queue_pulse(dx, dy, spacing)
	pend_x += dx
	pend_y += dy
	pend_spacing = spacing
	if (flush_queued)
		return
	flush_queued = TRUE
	spawn(0)
		flush_queued = FALSE
		var/fx = pend_x
		var/fy = pend_y
		pend_x = 0
		pend_y = 0
		smooth_pulse(fx, fy, pend_spacing)

// Copy of Civ13 human_subtile_smooth_pulse.
/mob/walker/proc/smooth_pulse(dx, dy, spacing)
	var/lag_x = 0
	var/lag_y = 0
	if (isnum(smooth_start) && smooth_time > 0)
		var/left = 1 - (world.time - smooth_start) / smooth_time
		if (left > 0)
			lag_x = smooth_from_x * left
			lag_y = smooth_from_y * left
	lag_x -= dx
	lag_y -= dy
	if (abs(lag_x) > 12 || abs(lag_y) > 12)
		lag_x = 0
		lag_y = 0
	var/time = max(world.tick_lag, spacing) + world.tick_lag
	smooth_start = world.time
	smooth_time = time
	smooth_from_x = lag_x
	smooth_from_y = lag_y
#if SMOOTH == 3
	var/time3 = max(world.tick_lag, spacing) + world.tick_lag
	pixel_w -= dx
	pixel_z -= dy
	animate(src, pixel_w = dx, pixel_z = dy, time = time3, flags = ANIMATION_RELATIVE | ANIMATION_PARALLEL)
	var/client/C = client
	if (C && C.eye == src)
		C.pixel_w -= dx
		C.pixel_z -= dy
		animate(C, pixel_w = dx, pixel_z = dy, time = time3, flags = ANIMATION_RELATIVE | ANIMATION_PARALLEL)
	return
#elif SMOOTH == 2
	var/lx = round(lag_x, 0.01)
	var/ly = round(lag_y, 0.01)
	animate(src, pixel_w = lx, pixel_z = ly, time = 0, flags = ANIMATION_PARALLEL)
	animate(pixel_w = 0, pixel_z = 0, time = time)
	var/client/C = client
	if (C && C.eye == src)
		animate(C, pixel_w = lx, pixel_z = ly, time = 0)
		animate(pixel_w = 0, pixel_z = 0, time = time)
#else
	pixel_w = round(lag_x, 0.01)
	pixel_z = round(lag_y, 0.01)
	animate(src, pixel_w = 0, pixel_z = 0, time = time, flags = ANIMATION_PARALLEL)
	var/client/C = client
	if (C && C.eye == src)
		C.pixel_w = pixel_w
		C.pixel_z = pixel_z
		animate(C, pixel_w = 0, pixel_z = 0, time = time, flags = ANIMATION_PARALLEL)
#endif

/mob/walker/proc/walkloop()
	var/duration = 13 * world.tick_lag
	while (src)
		var/start = world.time
		for (var/i = 1 to 16)
			var/due = start + i * duration / 16
			if (due > world.time)
				sleep(due - world.time)
			var/sx = step_x + 2
			var/tx = x
			if (sx >= 32)
				sx -= 32
				tx++
			var/wrapped = FALSE
			if (tx > 70)
				tx = 10
				sx = 0
				wrapped = TRUE
			Move(locate(tx, y, z), EAST, sx, 0)
			if (SMOOTH == 4 && !wrapped)
				queue_pulse(2, 0, duration / 16)
			else if (SMOOTH && !wrapped)
				smooth_pulse(2, 0, duration / 16)
