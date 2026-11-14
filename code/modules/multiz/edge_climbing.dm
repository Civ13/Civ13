// Ways down from an upper level, and ways between levels that players build.
//
// - Climb down an edge: grab intent with a free hand on the open air beside
//   you (or IC > Climb Down) lowers you, after a few seconds, onto the ground
//   below that open tile. It is the reverse of Climb Up (pit_climbing.dm).
// - Wooden ladder: use it on open air beside you on an upper level, or on the
//   ground under open air, to stand a ladder between the two levels.
// - Stairs: built stairs under open air lead to the level above. Walk onto
//   them the way they were built (or click them) to go up; walk onto the open
//   air above them to go down without falling.

#define EDGE_CLIMB_DOWN_TIME 30
#define EDGE_LADDER_PLACE_TIME 40
#define EDGE_LADDER_REMOVE_TIME 30
#define STAIRS_CLIMB_TIME 5
#define STAIRS_REPEAT_DELAY 10

/mob/living/human/var/tmp/stairs_moved_at = 0

/mob/living/human/persistence_runtime_var(key)
	return key == "stairs_moved_at" || ..()

// Open air you can climb down past: no floor, wall or roof on it.
/proc/edge_open_air(turf/T)
	if (!T || T.density || !building_open_turf(T))
		return FALSE
	for (var/atom/movable/A in T)
		if (A.density || istype(A, /obj/covers))
			return FALSE
	return TRUE

// The lower turf a climb down from H over the open air in direction lands on,
// or null. When it is null and why is a list, why[1] says what stopped it.
/proc/edge_descent_destination(mob/living/human/H, direction, list/why)
	. = null
	var/problem = ledge_climber_problem(H)
	if (!problem && !(direction in list(NORTH, SOUTH, EAST, WEST)))
		problem = "Face straight toward the edge you want to climb down."
	var/turf/here = problem ? null : get_turf(H)
	var/turf/edge = here ? get_step(here, direction) : null
	if (!problem && !edge_open_air(edge))
		problem = "There is no open edge there to climb down."
	if (!problem && edge_open_air(here))
		problem = "You need solid footing to climb down from."
	if (!problem)
		var/level = multiz_level_below(edge.z)
		var/turf/destination = level ? locate(edge.x, edge.y, level) : null
		if (!destination)
			problem = "There is nothing below to climb down to."
		else if (!ledge_landing_clear(destination))
			problem = building_open_turf(destination) ? "The drop is more than one storey. Build a floor or a ladder lower down first." : "The ground below is not clear, solid footing. Try another side."
		else if ((map && map.check_caribbean_block(H, destination)) || !persistence_movement_allowed(H, destination))
			problem = "You can't climb down there right now."
		else
			return destination
	if (islist(why))
		why.Cut()
		why += problem

// The facing first, then the other sides, so Climb Down finds any edge.
/proc/edge_descent_directions(facing)
	. = ledge_climb_directions(facing)
	for (var/d in list(NORTH, SOUTH, EAST, WEST))
		. |= d

/mob/living/human/proc/climb_down_edge(direction)
	var/turf/start = get_turf(src)
	var/list/why = list()
	var/turf/destination = edge_descent_destination(src, direction, why)
	if (!destination)
		to_chat(src, SPAN_WARNING(why.len && why[1] ? why[1] : "You can't climb down here."))
		return FALSE
	if (dir != direction)
		set_dir(direction)
	visible_message(SPAN_NOTICE("[src] starts climbing down over the edge."), SPAN_NOTICE("You start lowering yourself over the edge..."))
	if (!do_after(src, EDGE_CLIMB_DOWN_TIME, start))
		return FALSE
	// Re-resolve terrain and actor admission after the interruptible wait.
	if (get_turf(src) != start || edge_descent_destination(src, direction) != destination)
		return FALSE
	if (trench_climb_place(src, destination))
		visible_message(SPAN_NOTICE("[src] climbs down from above."), SPAN_NOTICE("You climb down safely."))
		return TRUE
	return FALSE

// Called by Climb Down when not up a tree: the facing edge first, then any.
/mob/living/human/proc/climb_down_any_edge()
	var/list/why = list()
	var/first_problem
	for (var/direction in edge_descent_directions(dir))
		if (edge_descent_destination(src, direction, why))
			return climb_down_edge(direction)
		var/turf/edge = get_step(src, direction)
		if (!first_problem && edge_open_air(edge) && why.len && why[1])
			first_problem = why[1]
	if (!first_problem)
		first_problem = ledge_climber_problem(src)
	to_chat(src, SPAN_WARNING(first_problem ? first_problem : "There is no open edge next to you to climb down. Stand beside open air."))
	return FALSE

// Grab intent with an empty hand on open air beside you climbs down over it.
// Returns TRUE only when it took over the click.
/mob/living/human/proc/grab_climb_down_edge(atom/A)
	if (a_intent != I_GRAB || get_active_hand() || !isturf(A))
		return FALSE
	var/turf/target = A
	var/turf/here = get_turf(src)
	if (!here || target.z != here.z || !edge_open_air(target) || edge_open_air(here))
		return FALSE
	var/direction = get_dir(here, target)
	if (!(direction in list(NORTH, SOUTH, EAST, WEST)) || get_step(here, direction) != target)
		return FALSE
	climb_down_edge(direction) // Explains a refusal.
	return TRUE

//////// Wooden ladders between building levels ////////

/obj/structure/multiz/ladder/placed
	name = "wooden ladder"
	desc = "A wooden ladder leading down to the level below. Use grab intent to take it down."
	icon_state = "ladderdown_wood"
	flammable = TRUE

/obj/structure/multiz/ladder/up/placed
	name = "wooden ladder"
	desc = "A wooden ladder leading up to the level above. Use grab intent to take it down."
	icon_state = "ladderup_wood"
	flammable = TRUE

/obj/structure/multiz/ladder/placed/New()
	..()
	ladder_list -= src // Never part of the mapped ladder numbering.

/obj/structure/multiz/ladder/up/placed/New()
	..()
	ladder_list -= src

/obj/structure/multiz/ladder/placed/find_target()
	var/turf/T = paired_turf()
	target = T ? locate(/obj/structure/multiz/ladder/up/placed) in T : null
	return target

/obj/structure/multiz/ladder/up/placed/find_target()
	var/turf/T = paired_turf()
	target = T ? locate(/obj/structure/multiz/ladder/placed) in T : null
	return target

/obj/structure/multiz/ladder/placed/attack_hand(mob/user)
	if (user && user.a_intent == I_GRAB)
		placed_ladder_take_down(src, user)
		return
	if (!target)
		find_target()
	return ..()

/obj/structure/multiz/ladder/up/placed/attack_hand(mob/user)
	if (user && user.a_intent == I_GRAB)
		placed_ladder_take_down(src, user)
		return
	if (!target)
		find_target()
	return ..()

// Either end comes down with the other.
/obj/structure/multiz/ladder/placed/Destroy()
	var/obj/structure/multiz/other = target ? target : find_target()
	target = null
	if (other && !QDELETED(other))
		other.target = null
		qdel(other)
	return ..()

/obj/structure/multiz/ladder/up/placed/Destroy()
	var/obj/structure/multiz/other = target ? target : find_target()
	target = null
	if (other && !QDELETED(other))
		other.target = null
		qdel(other)
	return ..()

/proc/placed_ladder_take_down(obj/structure/multiz/ladder/L, mob/user)
	if (!isliving(user) || !isturf(user.loc) || !L.Adjacent(user) || user.stat || user.restrained() || persistence_save_in_progress)
		return FALSE
	if (user.get_active_hand())
		to_chat(user, SPAN_WARNING("You need a free hand to take the ladder down."))
		return FALSE
	to_chat(user, SPAN_NOTICE("You start taking \the [L] down."))
	if (!do_after(user, EDGE_LADDER_REMOVE_TIME, L) || QDELETED(L) || !L.Adjacent(user) || user.stat || user.restrained() || persistence_save_in_progress)
		return FALSE
	qdel(L)
	var/obj/item/weapon/hole_ladder/item = new(get_turf(user))
	user.put_in_hands(item)
	to_chat(user, SPAN_NOTICE("You take the ladder down."))
	return TRUE

// The pair a wooden ladder used on T would stand: list(lower turf, upper
// turf), or null with why[1] naming the reason. T is open air beside an upper
// floor, or ground (or a floor) with open air straight above it.
/proc/placed_ladder_spot(turf/T, mob/user, list/why)
	. = null
	var/problem
	var/turf/lower
	var/turf/upper
	if (!T)
		problem = "You can't stand a ladder there."
	else if (edge_open_air(T))
		var/level = multiz_level_below(T.z)
		lower = level ? locate(T.x, T.y, level) : null
		upper = T
		if (!lower)
			problem = "There is nothing below to stand the ladder on."
	else
		var/level = multiz_level_above(T.z)
		upper = level ? locate(T.x, T.y, level) : null
		lower = T
		if (!upper)
			problem = "There is no level above to lean the ladder against."
		else if (!edge_open_air(upper))
			problem = "There is a ceiling or something solid above. Stand the ladder under open air."
	if (!problem && ((locate(/obj/structure/multiz) in lower) || (locate(/obj/structure/multiz) in upper)))
		problem = "There already is a ladder or stairs there."
	if (!problem && !ledge_landing_clear(lower, TRUE))
		problem = building_open_turf(lower) ? "The ladder is too short for more than one storey. It needs solid ground below." : "The ladder needs clear, solid ground at its foot."
	if (!problem && (istype(get_area(upper), /area/caribbean/no_mans_land) || istype(get_area(lower), /area/caribbean/no_mans_land)))
		problem = "You can't stand a ladder here."
	if (!problem && persistence_save_in_progress)
		problem = "You can't build while the world is saving."
	if (problem)
		if (islist(why))
			why.Cut()
			why += problem
		return null
	return list(lower, upper)

/obj/item/weapon/hole_ladder/proc/try_stand_ladder(atom/A, mob/user)
	var/turf/T = get_turf(A)
	var/turf/here = get_turf(user)
	if (!T || !here || T.z != here.z || get_dist(here, T) > 1)
		return FALSE
	// Only open air beside you, or ground and floors, take a standing ladder.
	if (!isturf(A))
		var/obj/covers/C = A
		if (!istype(C) || C.wall)
			return FALSE
	var/list/why = list()
	var/list/spot = placed_ladder_spot(T, user, why)
	if (!spot)
		// Ground with no level above is an ordinary click, not a ladder attempt.
		if (!edge_open_air(T) && !multiz_level_above(T.z))
			return FALSE
		to_chat(user, SPAN_WARNING(why.len && why[1] ? why[1] : "You can't stand a ladder there."))
		return TRUE
	user.visible_message(SPAN_NOTICE("[user] starts standing up \the [src]."), SPAN_NOTICE("You start standing up \the [src]..."))
	if (!do_after(user, EDGE_LADDER_PLACE_TIME, T))
		return TRUE
	if (QDELETED(src) || user.get_active_hand() != src || get_dist(get_turf(user), T) > 1)
		return TRUE
	spot = placed_ladder_spot(T, user, why)
	if (!spot)
		to_chat(user, SPAN_WARNING(why.len && why[1] ? why[1] : "You can't stand a ladder there."))
		return TRUE
	var/turf/lower = spot[1]
	var/turf/upper = spot[2]
	qdel(src)
	var/obj/structure/multiz/ladder/up/placed/bottom = new(lower)
	var/obj/structure/multiz/ladder/placed/top = new(upper)
	bottom.target = top
	top.target = bottom
	playsound(T, 'sound/effects/ladder.ogg', 50, TRUE, -1)
	user.visible_message(SPAN_NOTICE("[user] stands up a ladder between the levels."), SPAN_NOTICE("You stand the ladder up. Click either end to climb it."))
	return TRUE

/obj/item/weapon/hole_ladder/resolve_attackby(atom/A, mob/user, icon_x, icon_y)
	if (try_stand_ladder(A, user))
		return TRUE
	return ..()

//////// Stairs ////////

/obj/covers/var/stairs = FALSE

/obj/covers/wood/stairs
	stairs = TRUE

/obj/covers/cobblestone/stairs
	stairs = TRUE

/obj/covers/sandstone/stairs
	stairs = TRUE

/proc/stairs_in(turf/T)
	if (!T)
		return null
	for (var/obj/covers/C in T)
		if (C.stairs && !C.gc_destroyed && !C.gcDestroyed)
			return C
	return null

// The upper turf stairs S take H to, or null with why[1] naming the reason.
// The open air above the stairs is the stairwell; the top step lands on the
// floor beyond it, the way the stairs were built first.
/proc/stairs_destination(mob/living/human/H, obj/covers/S, list/why)
	. = null
	var/problem
	var/turf/T = get_turf(S)
	if (!istype(H) || !isturf(H.loc) || H.stat || H.lying || H.restrained() || H.buckled)
		problem = "You can't climb the stairs right now."
	else if (persistence_save_in_progress)
		problem = "You can't climb while the world is saving."
	var/level = (!problem && T) ? multiz_level_above(T.z) : 0
	var/turf/well = level ? locate(T.x, T.y, level) : null
	if (!problem && !well)
		problem = "These stairs don't lead anywhere: there is no level above."
	else if (!problem && !edge_open_air(well))
		problem = "There is a ceiling over these stairs. Leave the space above them open."
	if (!problem)
		var/list/directions = list()
		if (S.dir in list(NORTH, SOUTH, EAST, WEST))
			directions += S.dir
		directions |= ledge_climb_directions(H.dir)
		directions |= list(NORTH, SOUTH, EAST, WEST)
		for (var/d in directions)
			var/turf/landing = get_step(well, d)
			if (!ledge_landing_clear(landing))
				continue
			if ((map && map.check_caribbean_block(H, landing)) || !persistence_movement_allowed(H, landing))
				continue
			return landing
		problem = "There is no floor at the top of these stairs to step onto."
	if (islist(why))
		why.Cut()
		why += problem

/mob/living/human/proc/climb_stairs(obj/covers/S, wait = TRUE)
	var/list/why = list()
	var/turf/destination = stairs_destination(src, S, why)
	if (!destination)
		if (wait)
			to_chat(src, SPAN_WARNING(why.len && why[1] ? why[1] : "You can't climb these stairs."))
		return FALSE
	var/turf/start = get_turf(src)
	if (wait && !do_after(src, STAIRS_CLIMB_TIME, S))
		return FALSE
	if (QDELETED(S) || get_turf(src) != start || stairs_destination(src, S) != destination)
		return FALSE
	if (pulling)
		stop_pulling()
	if (pulledby)
		pulledby.stop_pulling()
	stairs_moved_at = world.time
	if (trench_climb_place(src, destination))
		to_chat(src, SPAN_NOTICE("You climb up the stairs."))
		return TRUE
	return FALSE

// Clicking stairs you stand on or beside climbs them.
/obj/covers/attack_hand(mob/user)
	if (stairs && ishuman(user) && Adjacent(user) && user.a_intent != I_HARM)
		var/mob/living/human/H = user
		H.climb_stairs(src)
		return
	return ..()

// Walking onto stairs the way they climb takes you up.
/proc/stairs_step_on(mob/living/human/H, turf/T, atom/OL)
	if (!H.client || H.stat || H.lying || H.buckled || !isturf(OL) || OL.z != T.z || world.time < H.stairs_moved_at + STAIRS_REPEAT_DELAY)
		return
	var/obj/covers/S = stairs_in(T)
	if (!S || !(get_dir(OL, T) & S.dir))
		return
	stairs_step_up_later(H, T, S)

// After the move that triggered it has finished.
/proc/stairs_step_up_later(mob/living/human/H, turf/T, obj/covers/S)
	set waitfor = FALSE
	sleep(0)
	if (H && H.loc == T && !QDELETED(S))
		H.climb_stairs(S, FALSE)

// Walking off an upper floor onto the open air over stairs steps down onto
// them instead of falling. Returns TRUE when it handled the move.
/proc/stairs_soft_descent(atom/movable/A, turf/below)
	if (!ishuman(A) || !below || !stairs_in(below) || !ledge_landing_clear(below, TRUE))
		return FALSE
	var/mob/living/human/H = A
	if (!persistence_movement_allowed(H, below))
		return FALSE
	if (H.pulling)
		H.stop_pulling()
	if (H.pulledby)
		H.pulledby.stop_pulling()
	H.stairs_moved_at = world.time
	if (!trench_climb_place(H, below))
		return FALSE
	to_chat(H, SPAN_NOTICE("You walk down the stairs."))
	return TRUE

#undef EDGE_CLIMB_DOWN_TIME
#undef EDGE_LADDER_PLACE_TIME
#undef EDGE_LADDER_REMOVE_TIME
#undef STAIRS_CLIMB_TIME
#undef STAIRS_REPEAT_DELAY
