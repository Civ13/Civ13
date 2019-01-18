/atom/movable
	layer = 3
	plane = GAME_PLANE
	var/last_move = null
	var/anchored = FALSE
	// var/elevation = 2    - not used anywhere
	var/move_speed = 10
	var/l_move_time = TRUE
	var/m_flag = TRUE
	var/throwing = FALSE
	var/thrower = null
	var/speed = 0
	var/range = 0
	var/turf/throw_source = null
	var/turf/last_throw_source = null // when we need a longterm reference
	var/atom/original_target = null
	var/throw_speed = 2
	var/throw_range = 7
	var/moved_recently = FALSE
	var/mob/pulledby = null
	var/item_state = null // Used to specify the item state for the on-mob overlays.

	var/auto_init = TRUE
	var/nothrow = FALSE
	var/throwmode = 0

	// temp vars
	var/dist_x = 0
	var/dist_y = 0
	var/dx = null
	var/dy = null
	var/dist_travelled = 0
	var/error = 0
	var/area/a = null

/atom/movable/New()
	..()
	if (auto_init && ticker && ticker.current_state == GAME_STATE_PLAYING)
		initialize()

/atom/movable/Del()
	if (!gcDestroyed && loc)
		testing("GC: -- [type] was deleted via del() rather than qdel() --")
		crash_with("GC: -- [type] was deleted via del() rather than qdel() --") // stick a stack trace in the runtime logs
//	else if (!gcDestroyed))
//		testing("GC: [type] was deleted via GC without qdel()") //Not really a huge issue but from now on, please qdel()
//	else
//		testing("GC: [type] was deleted via GC with qdel()")
	..()

/atom/movable/Destroy()
	. = ..()
	for (var/atom/movable/AM in contents)
		qdel(AM)
	forceMove(null)
	if (pulledby)
		if (pulledby.pulling == src)
			pulledby.pulling = null
		pulledby = null


// called by mobs when e.g. having the atom as their machine, pulledby, loc (AKA mob being inside the atom) or buckled var set.
// see code/modules/mob/mob_movement.dm for more.
/atom/movable/proc/relaymove(var/mob/mob, direction)

	if (direction)
		// prevents going over the invisible wall
		var/list/dirs = list()

		switch (direction)
			if (NORTHEAST)
				dirs += NORTH
				dirs += EAST
			if (NORTHWEST)
				dirs += NORTH
				dirs += WEST
			if (SOUTHEAST)
				dirs += SOUTH
				dirs += EAST
			if (SOUTHWEST)
				dirs += SOUTH
				dirs += WEST
			else
				dirs += direction

		for (var/refdir in dirs)
			var/turf/ref = get_step(mob, refdir)

			if (ref && map.check_caribbean_block(mob, ref))
				mob.dir = direction
				return FALSE

	// bug abusers btfo
	if (map.check_caribbean_block(mob, get_turf(mob)))
		return FALSE

	return TRUE

//Convenience function for atoms to update turfs they occupy
/atom/movable/proc/update_nearby_tiles(need_rebuild)
/*	if (!air_master)
		return FALSE

	for (var/turf/turf in locs)
		air_master.mark_for_update(turf)*/

	return TRUE

/atom/movable/proc/initialize()
	if (gcDestroyed)
		crash_with("GC: -- [type] had initialize() called after qdel() --")

/atom/movable/Bump(var/atom/A, yes)

	if (throwing)
		throw_impact(A)
		throwing = FALSE

	spawn(0)
		if (A && yes)
			A.last_bumped = world.time
			A.Bumped(src)
		return

	..()
	return

/atom/movable/proc/forceMove(atom/destination, var/special_event)
	if (loc == destination)
		return FALSE

	var/is_origin_turf = isturf(loc)
	var/is_destination_turf = isturf(destination)
	// It is a new area if:
	//  Both the origin and destination are turfs with different areas.
	//  When either origin or destination is a turf and the other is not.
	var/is_new_area = (is_origin_turf ^ is_destination_turf) || (is_origin_turf && is_destination_turf && loc.loc != destination.loc)

	var/atom/origin = loc
	loc = destination

	if (origin)
		origin.Exited(src, destination)
		if (is_origin_turf)
			for (var/atom/movable/AM in origin)
				AM.Uncrossed(src)
			if (is_new_area && is_origin_turf)
				origin.loc.Exited(src, destination)

	if (destination)
		destination.Entered(src, origin, special_event)
		if (is_destination_turf) // If we're entering a turf, cross all movable atoms
			for (var/atom/movable/AM in loc)
				if (AM != src)
					AM.Crossed(src)
			if (is_new_area && is_destination_turf)
				destination.loc.Entered(src, origin)
	return TRUE

/atom/movable/proc/forceMove_nondenseturf(atom/destination, var/special_event)
	if (isturf(destination))
		var/turf/T = destination
		if (T.density)
			return FALSE
	return forceMove(destination, special_event)


//called when src is thrown into hit_atom
/atom/movable/proc/throw_impact(atom/hit_atom, var/speed)
	if (istype(hit_atom,/mob/living))
		var/mob/living/M = hit_atom
		M.hitby(src,speed)

	else if (isobj(hit_atom))
		var/obj/O = hit_atom
		if (!O.anchored)
			step(O, last_move)
		O.hitby(src,speed)

	else if (isturf(hit_atom))
		throwing = FALSE
		var/turf/T = hit_atom
		if (T.density)
			spawn(2)
				step(src, turn(last_move, 180))
			if (istype(src,/mob/living))
				var/mob/living/M = src
				M.turf_collision(T, speed)

	spawn (1)
		if (istype(src, /obj/item))
			var/obj/item/I = src
			playsound(get_turf(src), I.dropsound, 100, TRUE)

		if (istype(src, /obj/item/weapon/snowball))
			var/obj/item/weapon/snowball/SB = src
			SB.icon_state = "snowball_hit"
			SB.update_icon()
			spawn(6)
				qdel(SB)
			return
//decided whether a movable atom being thrown can pass through the turf it is in.
/atom/movable/proc/hit_check(var/speed)
	if (throwing)
		for (var/atom/movable/A in get_turf(src))
			if (A == src) continue
			if (istype(A,/mob/living))
				if (A:lying) continue
				if (A == thrower)
					if (locate(/obj/structure/window/sandbag) in get_turf(src))
						continue
				throw_impact(A,speed)
			else if (isobj(A))
				var/obj/structure/window/sandbag/S = A
				if (istype(S) && S.CanPass(src, get_turf(src)))
					continue
				else if (A.density && !A.throwpass)	// **TODO: Better behaviour for windows which are dense, but shouldn't always stop movement
					throw_impact(A,speed)

/atom/movable/proc/throw_at(atom/target, _range, _speed, _thrower)
	. = TRUE
	if (!target || !src)	return FALSE

	original_target = target

	//use a modified version of Bresenham's algorithm to get from the atom's current position to that of the target

	throwing = TRUE
	if (target.allow_spin && allow_spin)
		SpinAnimation(5,1)
	thrower = _thrower
	speed = _speed
	range = _range
	throw_source = get_turf(src)	//store the origin turf
	last_throw_source = throw_source

	dist_x = abs(target.x - x)
	dist_y = abs(target.y - y)

	if (target.x > x)
		dx = EAST
	else
		dx = WEST

	if (target.y > y)
		dy = NORTH
	else
		dy = SOUTH

	dist_travelled = 0
//	var/dist_since_sleep = 0
	a = get_area(loc)
	if (dist_x > dist_y)
		error = dist_x/2 - dist_y
		throwmode = 0
	else
		error = dist_y/2 - dist_x
		throwmode = 1
	thrown_list += src

/atom/movable/proc/finished_throwing()
	thrown_list -= src
	var/turf/new_loc = get_turf(src)
	if (isobj(src)) throw_impact(new_loc,speed)
	if (src && new_loc)
		new_loc.Entered(src)
		throwing = FALSE
		thrower = null
		throw_source = null

		// if we're a bottle we shatter even if we didn't hit anything
		var/obj/item/weapon/reagent_containers/food/drinks/bottle/B = src
		if (istype(B))
			B.throw_impact(new_loc, speed)


//Overlays
/atom/movable/overlay
	var/atom/master = null
	anchored = TRUE

/atom/movable/overlay/New()
	for (var/x in verbs)
		verbs -= x
	..()

/atom/movable/overlay/attackby(a, b)
	if (master)
		return master.attackby(a, b)
	return

/atom/movable/overlay/attack_hand(a, b, c)
	if (master)
		return master.attack_hand(a, b, c)
	return

/atom/movable/proc/touch_map_edge()

	var/move_to_z = get_transit_zlevel()
	if (move_to_z)
		z = move_to_z

		if (x <= TRANSITIONEDGE)
			x = world.maxx - TRANSITIONEDGE - 2
			y = rand(TRANSITIONEDGE + 2, world.maxy - TRANSITIONEDGE - 2)

		else if (x >= (world.maxx - TRANSITIONEDGE + 1))
			x = TRANSITIONEDGE + 1
			y = rand(TRANSITIONEDGE + 2, world.maxy - TRANSITIONEDGE - 2)

		else if (y <= TRANSITIONEDGE)
			y = world.maxy - TRANSITIONEDGE -2
			x = rand(TRANSITIONEDGE + 2, world.maxx - TRANSITIONEDGE - 2)

		else if (y >= (world.maxy - TRANSITIONEDGE + 1))
			y = TRANSITIONEDGE + 1
			x = rand(TRANSITIONEDGE + 2, world.maxx - TRANSITIONEDGE - 2)

		spawn(0)
			if (loc) loc.Entered(src)

//This list contains the z-level numbers which can be accessed via space travel and the percentile chances to get there.
var/list/accessible_z_levels = list("1" = 5, "3" = 10, "4" = 15, "6" = 60)

//by default, transition randomly to another zlevel
/atom/movable/proc/get_transit_zlevel()
	var/list/candidates = accessible_z_levels.Copy()
	candidates.Remove("[z]")

	if (!candidates.len)
		return null
	return text2num(pickweight(candidates))

