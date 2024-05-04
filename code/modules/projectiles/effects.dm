/obj/effect/projectile
	icon = 'icons/effects/projectiles.dmi'
	icon_state = "bolt"
	layer = 20

/obj/effect/projectile/New(var/turf/location)
	if (istype(location))
		loc = location

/obj/effect/projectile/proc/set_transform(var/matrix/M)
	if (istype(M))
		transform = M

/obj/effect/projectile/proc/activate(var/kill_delay = 1)
	spawn(kill_delay)
		qdel(src)	//see effect_system.dm - sets loc to null and lets GC handle removing these effects

	return

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
	layer = 20

//----------------------------
// Impact
//----------------------------

/obj/effect/projectile/impact
	icon_state = "impact_generic"
	var/speed_modifier = 1
	var/angle = 0
	var/call_time = 0

/obj/effect/projectile/impact/activate(var/direction)
	if(cos(direction) != 0)
		pixel_x = cos(direction) * 32
	if(sin(direction) != 0)
		pixel_y = sin(direction) * 32
	call_time = world.time
	var/dispersion = rand(-25, 25)
	angle = direction + dispersion - 180
	speed_modifier = sqrt(abs(dispersion))
	update()

/obj/effect/projectile/impact/proc/update()
	var/dt = world.time - call_time
	if(dt > 5)
		loc = null
		qdel(src)
		return
	alpha *= 0.75
	var/ds = 16
	if(speed_modifier != 0)
		ds /= speed_modifier
	if(dt != 0)
		ds /= dt 
	pixel_x += cos(angle) * sqrt(ds)
	pixel_y += sin(angle) * sqrt(ds)
	spawn(0.3)
		update()