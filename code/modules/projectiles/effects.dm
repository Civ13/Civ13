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