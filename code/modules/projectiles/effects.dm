/obj/effect/projectile
	icon = 'icons/effects/projectiles.dmi'
	icon_state = "bolt"
	layer = 5
	var/angle = 0
	var/call_time = 0

/obj/effect/projectile/New(var/turf/location)
	if (istype(location))
		loc = location

/obj/effect/projectile/proc/activate(var/direction)
	pixel_x = cos(direction) * 25
	pixel_y = sin(direction) * 25
	transform = turn(transform, -direction) 
	call_time = world.time
	spawn(0.3)
		update()

/obj/effect/projectile/proc/update()
	var/dt = world.time - call_time
	if(dt > 2)
		loc = null
		qdel(src)
		return
	alpha *= 0.9
	spawn(0.3)
		update()

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

//----------------------------
// Impact
//----------------------------

/obj/effect/projectile/impact
	icon_state = "dust_cloud_generic"
	var/speed_modifier = 1

/obj/effect/projectile/impact/activate(var/direction)
	pixel_x = cos(direction) * 32
	pixel_y = sin(direction) * 32
	call_time = world.time
	var/dispersion = rand(-30, 30)
	angle = direction + dispersion - 180
	speed_modifier = sqrt(abs(dispersion))
	update()

/obj/effect/projectile/impact/update()
	var/dt = world.time - call_time
	if(dt > 5)
		loc = null
		qdel(src)
		return
	alpha *= 0.85
	var/ds = 20
	if(speed_modifier != 0)
		ds /= speed_modifier
	if(dt != 0)
		ds /= dt 
	pixel_x += cos(angle) * sqrt(ds)
	pixel_y += sin(angle) * sqrt(ds)
	spawn(0.4)
		update()

//----------------------------
// Tracer
//----------------------------

/obj/effect/projectile/tracer
	icon_state = "tracer_white"

/obj/effect/projectile/tracer/activate(var/direction, var/pixel_dist, var/turf/starting)
	angle = direction
	pixel_x = (cos(angle) * pixel_dist) - ((x - starting.x) * world.icon_size)
	pixel_y = (sin(angle) * pixel_dist) - ((y - starting.y) * world.icon_size)
	transform = turn(transform, -angle)
	call_time = world.time
	spawn(0.5)
		update()

/obj/effect/projectile/tracer/update()
	var/dt = world.time - call_time
	if(dt > 2)
		loc = null
		qdel(src)
		return
	alpha *= 0.8
	spawn(0.6)
		update()

/obj/effect/projectile/tracer/minor
	alpha = 64

/obj/effect/projectile/tracer/red
	icon_state = "tracer_red"

/obj/effect/projectile/tracer/green
	icon_state = "tracer_green"

/obj/effect/projectile/tracer/shell
	icon_state = "shell_tracer_white"