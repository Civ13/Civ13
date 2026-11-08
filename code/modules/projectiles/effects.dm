/obj/effect/projectile
	icon = 'icons/effects/projectiles.dmi'
	icon_state = "bolt"
	layer = 5
	mouse_opacity = FALSE
	var/angle = 0
	var/call_time = 0
	var/life_time = 0.6
	var/alpha_modifier = 1
	var/update_time = 0.6

/obj/effect/projectile/New(var/turf/location)
	effect_lifetime = list()
	if (istype(location))
		loc = location

/obj/effect/projectile/proc/activate(var/direction)
	pixel_x = cos(direction) * 25
	pixel_y = sin(direction) * 25
	transform = turn(transform, -direction) 
	call_time = world.time
	update()

// The whole fade and drift is one client-side animation, then one retirement.
// The old per-tick updates sent a new appearance to every viewer up to twenty
// times per puff; with about thirty puffs, tracers and impacts per shot that
// was the main client frame cost during firefights.
/obj/effect/projectile/proc/update()
	fade_out(pixel_x, pixel_y)

// Alpha left after the old loop's per-step fade over life_time.
/obj/effect/projectile/proc/faded_alpha()
	var/steps = 0
	var/step = projectile_effect_step(update_time)
	for (var/dt = 0, dt <= life_time, dt += step)
		++steps
	return round(alpha * (alpha_modifier ** steps))

/obj/effect/projectile/proc/fade_out(end_x, end_y)
	var/end_alpha = faded_alpha()
	if (end_alpha != alpha || end_x != pixel_x || end_y != pixel_y)
		animate(src, alpha = end_alpha, pixel_x = end_x, pixel_y = end_y, time = life_time, easing = SINE_EASING | EASE_OUT)
	var/list/lifetime = effect_lifetime
	var/my_call_time = call_time
	spawn(life_time)
		if (!QDELETED(src) && effect_lifetime == lifetime && call_time == my_call_time)
			qdel(src)

// The old loop's real step: a sleep shorter than a tick still waits a tick.
/proc/projectile_effect_step(update_time)
	return max(world.tick_lag, -round(-update_time / world.tick_lag) * world.tick_lag)

// Total pixel drift of the old per-step loop: each step moved sqrt(base / d),
// where d is first_divisor at dt 0 and divisor * dt afterwards (a zero
// divisor counted as 1, as the old loops skipped dividing by it).
/proc/projectile_effect_drift(base, divisor, first_divisor, life_time, update_time)
	var/total = 0
	var/step = projectile_effect_step(update_time)
	if (!divisor)
		divisor = 1
	if (!first_divisor)
		first_divisor = 1
	for (var/dt = 0, dt <= life_time, dt += step)
		total += sqrt(base / (dt ? divisor * dt : first_divisor))
	return total


//----------------------------
// Bullet
//----------------------------
/obj/effect/projectile/bullet/muzzle
	icon_state = "muzzle_bullet"
///LASERS
/obj/effect/projectile/laser/muzzle
	icon_state = "muzzle_laser"
/obj/effect/projectile/laser/muzzle/b
	icon_state = "muzzle_laserb"
/obj/effect/projectile/laser/muzzle/g
	icon_state = "muzzle_laserg"

/obj/effect/projectile
	icon = 'icons/effects/projectiles.dmi'
	icon_state = "bolt"
	layer = 5

/obj/effect/projectile/bullet/muzzle/gunsmoke
	icon_state = "dust_cloud_generic"
	life_time = 8
	alpha_modifier = 0.8
	update_time = 0.4
	var/speed_modifier = 1

/obj/effect/projectile/bullet/muzzle/gunsmoke/activate(var/direction)
	pixel_x = cos(direction) * 16
	pixel_y = sin(direction) * 16
	call_time = world.time
	var/dispersion = rand(-20, 20)
	angle = direction + dispersion
	speed_modifier *= sqrt(abs(dispersion)) * 2
	update()

/obj/effect/projectile/bullet/muzzle/gunsmoke/update()
	var/drift = projectile_effect_drift(30, speed_modifier, speed_modifier, life_time, update_time)
	fade_out(pixel_x + cos(angle) * drift, pixel_y + sin(angle) * drift)


//----------------------------
// Impact
//----------------------------

/obj/effect/projectile/impact
	icon_state = "dust_cloud_generic"
	life_time = 6
	alpha_modifier = 0.8
	update_time = 0.5
	var/speed_modifier = 1

/obj/effect/projectile/impact/activate(var/direction)
	pixel_x = cos(direction) * 32
	pixel_y = sin(direction) * 32
	call_time = world.time
	var/dispersion = rand(-60, 60)
	angle = direction + dispersion - 180
	speed_modifier *= sqrt(abs(dispersion)) * 0.5
	update()

/obj/effect/projectile/impact/update()
	var/drift = projectile_effect_drift(20, speed_modifier, speed_modifier, life_time, update_time)
	fade_out(pixel_x + cos(angle) * drift, pixel_y + sin(angle) * drift)


/obj/effect/projectile/impact/heavy
	icon_state = "dust_heavy_cloud_generic"
	life_time = 10
	alpha_modifier = 0.9
	update_time = 0.6
	speed_modifier = 1.5

//----------------------------
// Tracer
//----------------------------

/obj/effect/projectile/tracer
	icon_state = "tracer_white"
	life_time = 6
	alpha_modifier = 0.9
	update_time = 0.7

/obj/effect/projectile/tracer/activate(var/direction, var/pixel_dist, var/turf/starting)
	angle = direction
	pixel_x = (cos(angle) * pixel_dist) - ((x - starting.x) * world.icon_size)
	pixel_y = (sin(angle) * pixel_dist) - ((y - starting.y) * world.icon_size)
	transform = turn(transform, -angle)
	call_time = world.time
	update()

/obj/effect/projectile/tracer/minor
	alpha = 64
	life_time = 3
	alpha_modifier = 0.7

/obj/effect/projectile/tracer/red
	icon_state = "tracer_red"

/obj/effect/projectile/tracer/green
	icon_state = "tracer_green"

/obj/effect/projectile/tracer/shell
	icon_state = "shell_tracer_white"
	life_time = 10

/obj/effect/projectile/tracer/missile
	icon_state = "dust_cloud_generic"
	life_time = 8
	alpha_modifier = 0.8
	update_time = 0.2
	var/speed_modifier

/obj/effect/projectile/tracer/missile/activate(var/direction, var/x_offset, var/y_offset)
	pixel_x = x_offset - (cos(direction) * 32)
	pixel_y = y_offset - (sin(direction) * 32)
	call_time = world.time
	var/dispersion = rand(-20, 20)
	angle = direction + dispersion - 180
	speed_modifier = rand(1, 2)
	update()

/obj/effect/projectile/tracer/missile/update()
	var/drift = projectile_effect_drift(20, speed_modifier, 1, life_time, update_time)
	fade_out(pixel_x + cos(angle) * drift, pixel_y + sin(angle) * drift)