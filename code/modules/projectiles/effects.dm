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
	if (istype(location))
		loc = location

/obj/effect/projectile/proc/activate(var/direction)
	pixel_x = cos(direction) * 25
	pixel_y = sin(direction) * 25
	transform = turn(transform, -direction) 
	call_time = world.time
	update()

/obj/effect/projectile/proc/update()
	var/dt = world.time - call_time
	if(dt > life_time)
		loc = null
		qdel(src)
		return
	alpha *= alpha_modifier
	spawn(update_time)
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
	var/dt = world.time - call_time
	if(dt > life_time)
		loc = null
		qdel(src)
		return
	alpha *= alpha_modifier
	var/ds = 30
	if(speed_modifier != 0)
		ds /= speed_modifier
	if(dt != 0)
		ds /= dt 
	pixel_x += cos(angle) * sqrt(ds)
	pixel_y += sin(angle) * sqrt(ds)
	spawn(update_time)
		update()

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
	var/dt = world.time - call_time
	if(dt > life_time)
		loc = null
		qdel(src)
		return
	alpha *= alpha_modifier
	var/ds = 20
	if(speed_modifier != 0)
		ds /= speed_modifier
	if(dt != 0)
		ds /= dt 
	pixel_x += cos(angle) * sqrt(ds)
	pixel_y += sin(angle) * sqrt(ds)
	spawn(update_time)
		update()

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
	spawn()
		update()

/obj/effect/projectile/tracer/update()
	var/dt = world.time - call_time
	if(dt > life_time)
		loc = null
		qdel(src)
		return
	alpha *= alpha_modifier
	spawn(update_time)
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
	var/dt = world.time - call_time
	if(dt > life_time)
		loc = null
		qdel(src)
		return
	alpha *= alpha_modifier
	var/ds = 20
	if(dt != 0)
		ds /= dt * speed_modifier
	pixel_x += cos(angle) * sqrt(ds)
	pixel_y += sin(angle) * sqrt(ds)
	spawn(update_time)
		update()