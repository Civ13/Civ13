/obj/tank/var/last_fire = -1
/obj/tank/var/fire_delay = 100

#define MIN_RANGE 5
#define MAX_RANGE 6

/obj/tank/proc/density_check(var/turf/_loc)
	if (_loc.density)
		return TRUE
	for (var/atom/movable/am in _loc)
		if (am.density && am != src && am != front_seat() && am != back_seat())
			return TRUE
	return FALSE

#define MAX_DIST 4

/obj/tank/proc/get_x_steps_in_dir(steps)

	var/_loc = null
	switch (dir)
		if (NORTH, NORTHEAST, NORTHWEST)
			for (var/v in 1 to min(MAX_DIST,steps))
				_loc = locate(x+1, y+v+1, z)
				if (!_loc || density_check(_loc))
					return locate(x+1, y+v+1, z)
		if (SOUTH, SOUTHEAST, SOUTHWEST)
			for (var/v in 1 to min(MAX_DIST,steps))
				_loc = locate(x+1, y-v, z)
				if (!_loc || density_check(_loc))
					return locate(x+1, y-v, z)
		if (EAST)
			for (var/v in 1 to min(MAX_DIST,steps))
				_loc = locate(x+v+3, y+1, z)
				if (!_loc || density_check(_loc))
					return locate(x+v+3, y+1, z)
		if (WEST)
			for (var/v in 1 to min(MAX_DIST,steps))
				_loc = locate(x-v, y+1, z)
				if (!_loc || density_check(_loc))
					return locate(x-v, y+1, z)
	if (_loc)
		return _loc

	return get_step(src, dir)

/obj/tank/proc/tank_explosion(turf/epicenter, devastation_range, heavy_impact_range, light_impact_range, flash_range, adminlog = TRUE, z_transfer = UP|DOWN, is_rec = config.use_recursive_explosions)
	var/datum/explosiondata/data = explosion(epicenter, devastation_range, heavy_impact_range, light_impact_range, flash_range, adminlog, z_transfer, is_rec)
	data.objects_with_immunity += src

/obj/tank/proc/Fire()
	if (!truck)

		var/atom/target = get_x_steps_in_dir(rand(MIN_RANGE,MAX_RANGE))

		if (!target) return

		var/mob/user = back_seat() ? back_seat() : front_seat() // for debugging

		if (!user) return

		if (world.time - last_fire < fire_delay && last_fire != -1)
			user << "<span class = 'danger'>You can't fire again so quickly!</span>"
			return

		playsound(get_turf(src), 'sound/weapons/WW2/tank_fire.ogg', 100)

		last_fire = world.time

		var/abs_dist = abs_dist(src, target)

		spawn (round((1 * abs_dist)/2))
			if (target)
				tank_explosion(target, 1, 2, 3, 4)

#undef MIN_RANGE
#undef MAX_RANGE