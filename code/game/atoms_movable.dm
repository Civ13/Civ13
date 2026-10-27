// Save admission owns this restriction, including preparation and cleanup.
// Imports must be free to reconstruct locations. Same-z save hooks (for
// example paid rack transfers) remain valid; never wait inside the serializer.
/proc/persistence_live_contents(atom/movable/container)
	for (var/atom/movable/child in container)
		if (!child.gcDestroyed && !child.gc_destroyed)
			return TRUE
		if (persistence_live_contents(child))
			return TRUE
	return FALSE

/proc/persistence_movement_allowed(atom/movable/mover, atom/destination)
	if (!persistence_save_active())
		return TRUE
	if (!mover)
		return FALSE
	var/turf/origin = get_turf(mover)
	var/turf/target = get_turf(destination)
	// Retirement is a deletion exception, never permission to re-enter a level.
	if (target && (mover.gcDestroyed || mover.gc_destroyed))
		return FALSE
	if (!origin)
		// Permit empty new atoms, not a nullspace carrier of existing live atoms.
		return !persistence_live_contents(mover)
	if (!target)
		// Retirement must still detach deleted atoms. Ordinary nullspace hops
		// cannot be used to evade the cross-z restriction in a second move.
		return !destination && (mover.gcDestroyed || mover.gc_destroyed) && !persistence_live_contents(mover)
	return origin.z == target.z

/atom/movable
	layer = 3
	plane = GAME_PLANE
	var/last_move = null
	var/anchored = FALSE
	var/l_move_time = TRUE
	var/throwing = FALSE
	var/thrower = null
	var/speed = 0
	var/range = 0
	var/turf/throw_source = null
	var/turf/last_throw_source = null // when we need a longterm reference
	// Only the initial, uninterrupted overlap of a human's released item.
	// The custom saver enumerates tmp fields; see persistence_runtime_var.
	var/tmp/mob/living/human/throw_launch_source = null
	var/tmp/throw_launch_dx = null
	var/tmp/throw_launch_dy = null
	var/tmp/throw_launch_x = null
	var/tmp/throw_launch_y = null
	// Identity of one accepted flight, never a reusable permission flag.
	var/tmp/list/throw_flight_token = null
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

	var/load_datums = 1
	
/atom/movable/New()
	..()
	if (auto_init && ticker && ticker.current_state == GAME_STATE_PLAYING)
		initialize()

/atom/movable/Del()
	if (!gcDestroyed && loc)
//		testing("GC: -- [type] was deleted via del() rather than qdel() --")
		crash_with("GC: -- [type] was deleted via del() rather than qdel() --") // stick a stack trace in the runtime logs
//	else if (!gcDestroyed))
//		testing("GC: [type] was deleted via GC without qdel()") //Not really a huge issue but from now on, please qdel()
//	else
//		testing("GC: [type] was deleted via GC with qdel()")
	..()

/atom/movable/Destroy()
	clear_throw_launch()
	throw_flight_token = null
	. = ..()
	for (var/atom/movable/AM in contents)
		qdel(AM)
	if (pulledby)
		if (pulledby.pulling == src)
			pulledby.pulling = null
		pulledby = null
	forceMove(null)

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

/atom/movable/proc/initialize()
	if (gcDestroyed)
		crash_with("GC: -- [type] had initialize() called after qdel() --")

/atom/movable/Bump(var/atom/A, yes)

	if (throwing)
		clear_throw_launch()
		throw_flight_token = null
		throw_impact(A)
		if (isnull(throw_flight_token))
			throwing = FALSE

	spawn(0)
		if (A && yes)
			A.last_bumped = world.time
			A.Bumped(src)
		return

	..()
	return

/atom/movable/proc/forceMove(atom/destination, var/special_event, list/throw_hop_token = null)
	if (!isnull(throw_hop_token) && throw_hop_token != throw_flight_token)
		return FALSE
	if (!persistence_movement_allowed(src, destination))
		return FALSE
	if (loc == destination)
		return FALSE
	// Only this flight's processor-owned hop may preserve initial overlap.
	// Nested callbacks use their own default null; a newer throw has a new token.
	if (throw_launch_source && isnull(throw_hop_token))
		clear_throw_launch()

	var/is_origin_turf = isturf(loc)
	var/is_destination_turf = isturf(destination)
	if (!is_destination_turf || (is_origin_turf && z != destination.z))
		clear_throw_launch()
		throw_flight_token = null
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

// Preserve raw loc-assignment semantics at legacy teleport sites: adding
// forceMove callbacks there changes collision/Entered behavior and can recurse.
/atom/movable/proc/persistence_set_loc(atom/destination)
	if (!persistence_movement_allowed(src, destination))
		return FALSE
	loc = destination
	return TRUE

/atom/movable/proc/persistence_set_z(target_z)
	var/turf/T = get_turf(src)
	if (!T)
		return FALSE
	var/turf/destination = locate(T.x, T.y, target_z)
	if (!destination)
		return FALSE
	return persistence_set_loc(destination)

/atom/movable/proc/forceMove_nondenseturf(atom/destination, var/special_event, list/throw_hop_token = null)
	if (isturf(destination))
		var/turf/T = destination
		if (T.density)
			return FALSE
	return forceMove(destination, special_event, throw_hop_token)


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

/atom/movable/proc/clear_throw_launch()
	throw_launch_source = null
	throw_launch_dx = null
	throw_launch_dy = null
	throw_launch_x = null
	throw_launch_y = null

/atom/movable/proc/begin_throw_launch()
	clear_throw_launch()
	if (!isitem(src) || !ishuman(thrower) || !isturf(loc))
		return
	var/mob/living/human/source = thrower
	if (!isturf(source.loc) || source.loc != loc || source.z != z || bounds_dist(src, source) >= 0)
		return
	throw_launch_source = source
	throw_launch_dx = dx
	throw_launch_dy = dy
	throw_launch_x = x
	throw_launch_y = y

// Sample AFTER each attempted hop, including an empty destination. Movement of
// the human across an anchor before the first hop must not reopen the launch race.
/atom/movable/proc/update_throw_launch(advanced)
	if (!throw_launch_source)
		return
	if (!advanced || !throwing || thrower != throw_launch_source || isDeleted(throw_launch_source) || !isturf(loc) || !isturf(throw_launch_source.loc) || z != throw_launch_source.z || dx != throw_launch_dx || dy != throw_launch_dy)
		clear_throw_launch()
		return
	var/hop_x = x - throw_launch_x
	var/hop_y = y - throw_launch_y
	// Forced relocations, reverse hops and changed flight directions end the
	// initial outbound segment even if the item never cleared its source.
	if (abs(hop_x) + abs(hop_y) != 1 || (hop_x && ((hop_x > 0 ? EAST : WEST) != throw_launch_dx)) || (hop_y && ((hop_y > 0 ? NORTH : SOUTH) != throw_launch_dy)) || bounds_dist(src, throw_launch_source) >= 0)
		clear_throw_launch()
		return
	throw_launch_x = x
	throw_launch_y = y

// Decide whether a movable atom being thrown can pass through its current turf.
/atom/movable/proc/hit_check(var/speed, advanced = FALSE)
	update_throw_launch(advanced)
	var/list/flight_token = throw_flight_token
	if (throwing)
		for (var/atom/movable/A in get_turf(src))
			if (A == src) continue
			if (istype(A,/mob/living))
				if (A:lying) continue
				if (A == throw_launch_source) continue
				if (A == thrower)
					if (locate(/obj/structure/window/barrier) in get_turf(src))
						continue
				throw_impact(A,speed)
				if (throw_flight_token != flight_token)
					return
			else if (isobj(A))
				var/obj/structure/window/barrier/S = A
				if (istype(S) && S.CanPass(src, get_turf(src)))
					continue
				else if (A.density && !A.throwpass)	// **TODO: Better behaviour for windows which are dense, but shouldn't always stop movement
					throw_impact(A,speed)
					if (throw_flight_token != flight_token)
						return

/atom/movable/proc/throw_at(atom/target, _range, _speed, _thrower)
	. = TRUE
	if (!target || !src)	return FALSE

	throw_flight_token = list()
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
	a = get_area(loc)
	if (dist_x > dist_y)
		error = dist_x/2 - dist_y
		throwmode = 0
	else
		error = dist_y/2 - dist_x
		throwmode = 1
	begin_throw_launch()
	thrown_list += src

/atom/movable/proc/throw_at_random(var/include_own_turf, var/maxrange, var/speed)
	var/list/turfs = trange(maxrange, src)
	if(!maxrange)
		maxrange = 1

	if(!include_own_turf)
		turfs -= get_turf(src)
	if (length(turfs))
		throw_at(pick(turfs), maxrange, speed)

/atom/movable/proc/finished_throwing()
	clear_throw_launch()
	throw_flight_token = null
	thrown_list -= src
	var/turf/new_loc = get_turf(src)
	// Clear the completed target before impact/Entered can start a newer throw.
	original_target = null
	if (isobj(src)) throw_impact(new_loc,speed)
	if (!isnull(throw_flight_token))
		return // A callback started a newer flight; old cleanup must not cancel it.
	if (src && new_loc)
		new_loc.Entered(src)
		if (!isnull(throw_flight_token))
			return
		throwing = FALSE
		thrower = null
		throw_source = null

		// if we're a bottle we shatter even if we didn't hit anything
		var/obj/item/weapon/reagent_containers/food/drinks/bottle/B = src
		if (istype(B))
			B.throw_impact(new_loc, speed)

/atom/movable/proc/dropInto(atom/destination)
	while(istype(destination))
		var/atom/drop_destination = destination.onDropInto(src)
		if(!istype(drop_destination) || drop_destination == destination)
			return forceMove(destination)
		destination = drop_destination
	return forceMove(null)

/atom/proc/onDropInto(atom/movable/AM)
	return // If onDropInto returns null, then dropInto will forceMove AM into us.

/atom/movable/onDropInto(atom/movable/AM)
	return loc // If onDropInto returns something, then dropInto will attempt to drop AM there.

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

//This list contains the z-level numbers which can be accessed via space travel and the percentile chances to get there.
var/list/accessible_z_levels = list("1" = 5, "3" = 10, "4" = 15, "6" = 60)

//by default, transition randomly to another zlevel
/atom/movable/proc/get_transit_zlevel()
	var/list/candidates = accessible_z_levels.Copy()
	candidates.Remove("[z]")

	if (!candidates.len)
		return null
	return text2num(pickweight(candidates))

