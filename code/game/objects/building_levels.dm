// Ceilings with an available upper plane have two faces of one slab. Coordinates
// and an ID, rather than cross-level references, survive per-level saves.
#define BUILDING_MAX_Z 32
#define BUILDING_EXTRA_LEVELS 8
#define BUILDING_MAX_LEVEL_CELLS 2000000

var/building_allocating_z = 0
var/building_compiled_maxz = 0

/proc/building_base_maxz()
	if (!building_compiled_maxz)
		building_compiled_maxz = world.maxz
	return building_compiled_maxz

/proc/building_open_turf(turf/T)
	return istype(T, /turf/sky) || istype(T, /turf/floor/broken_floor)

// Native expansion creates world.turf first. Dirt's constructor skips its
// recovery timers while this flag is set; replace those blank cells in batches.
/proc/building_allocate_level(target_z, bootstrap = FALSE, datum/new_z_reservation/reservation)
	if ((persistence_save_in_progress && !bootstrap) || building_allocating_z || target_z != world.maxz + 1 || target_z > BUILDING_MAX_Z || target_z > building_base_maxz() + BUILDING_EXTRA_LEVELS || world.maxx * world.maxy > BUILDING_MAX_LEVEL_CELLS)
		world_z_budget.last_error = "The level request is not sequential, or allocation/save ownership is busy."
		return FALSE
	var/own_reservation = !reservation
	if (own_reservation)
		reservation = world_z_budget.reserve(target_z, bootstrap ? "restore" : "roof")
	if (!reservation)
		return FALSE
	if (!world_z_budget.claim_level(reservation, target_z))
		if (own_reservation)
			world_z_budget.finish(reservation, FALSE)
		return FALSE
	building_allocating_z = target_z
	try
		world.maxz = target_z
		for (var/x = 1 to world.maxx)
			for (var/y = 1 to world.maxy)
				new /turf/sky/building(locate(x, y, target_z))
			TICK_CHECK
	catch (var/exception/allocation_error)
		world_z_budget.finish(reservation, FALSE)
		// Keep the busy flag: a partly initialized native grid requires restart.
		throw allocation_error
	building_allocating_z = 0
	if (own_reservation)
		return world_z_budget.finish(reservation, world.maxz == target_z)
	return world.maxz == target_z

// Unlike broken_floor, empty building sky has no global rendering registry or
// sleeping constructor per cell. Only entrants need to inspect the level below.
/turf/sky/building
	name = "open air"
	desc = "There is no floor here."

/turf/sky/building/Entered(atom/movable/A)
	// Lighting renderers belong to their turf; they are not falling cargo.
	if (istype(A, /atom/movable/lighting_overlay) || istype(A, /atom/movable/lighting_fullbright))
		return
	if (!A || !A.loc || istype(A, /obj/covers) || istype(A, /obj/roof) || isobserver(A) || (locate(/obj/covers) in src) || (locate(/obj/structure/multiz/ladder) in src))
		return
	if (istype(A, /obj/effect) || istype(A, /obj/item/projectile))
		return
	var/turf/below = locate(x, y, z - 1)
	if (below)
		A.forceMove(below)
		if (isliving(A))
			to_chat(A, SPAN_WARNING("The floor gives way beneath you!"))
		if (ishuman(A))
			var/mob/living/human/H = A
			H.Stun(6)
			for (var/part in list("head", "chest", "l_leg", "r_leg", "l_arm", "r_arm"))
				H.apply_damage(rand(0, 25), BRUTE, part)
			H.updatehealth()

/atom/proc/building_support_tier()
	return 0

/obj/structure/roof_support/building_support_tier()
	return health > 0 && !gc_destroyed && !gcDestroyed ? 2 : 0

/obj/structure/roof_support/admin/building_support_tier()
	return !gc_destroyed && !gcDestroyed ? 8 : 0

/obj/structure/mine_support/stone/building_support_tier()
	return health > 0 && !gc_destroyed && !gcDestroyed ? 4 : 0

/obj/structure/mine_support/stone/concrete/building_support_tier()
	return health > 0 && !gc_destroyed && !gcDestroyed ? 6 : 0

/obj/covers/building_support_tier()
	if (!wall || incomplete || health <= 0 || gc_destroyed || gcDestroyed)
		return 0
	switch (lowertext(material))
		if ("steel", "iron")
			return 8
		if ("concrete")
			return 6
		if ("stone", "clay")
			return 4
	return 2

/obj/covers/vault/building_support_tier()
	return health > 0 && !gc_destroyed && !gcDestroyed ? 6 : 0

/turf/wall/building_support_tier()
	return 4

/obj/structure/simple_door/building_support_tier()
	return !gc_destroyed && !gcDestroyed ? 2 : 0

/obj/covers
	var/building_pair_id
	var/building_roof_z = 0

/obj/roof
	var/building_pair_id
	var/building_floor_z = 0

/obj/roof/get_saved_vars()
	. = ..()
	. |= list("building_pair_id", "building_floor_z", "health", "current_area_type", "switch_area", "seasonal_construction_due")

/obj/roof/persistence_runtime_var(key)
	return key == "roof_overlay" || ..()

/obj/roof/proc/building_floor()
	if (!building_pair_id || building_floor_z != z + 1)
		return null
	for (var/obj/covers/C in locate(x, y, building_floor_z))
		if (C.building_pair_id == building_pair_id && C.building_roof_z == z && !C.gc_destroyed && !C.gcDestroyed)
			return C

/obj/covers/proc/building_roof()
	if (!building_pair_id || building_roof_z != z - 1)
		return null
	for (var/obj/roof/R in locate(x, y, building_roof_z))
		if (R.building_pair_id == building_pair_id && R.building_floor_z == z && !R.gc_destroyed && !R.gcDestroyed)
			return R

// -1 is unsupported air. Natural/mapped solid ground is a foundation. Every
// elevated support must lead through a paired slab to a real foundation.
/proc/building_floor_height(turf/T, depth = 0, required_height = 0)
	if (!T || depth > BUILDING_EXTRA_LEVELS)
		return -1
	if (!building_open_turf(T))
		return 0
	for (var/obj/covers/C in T)
		if (C.gc_destroyed || C.gcDestroyed)
			continue
		var/obj/roof/R = C.building_roof()
		if (R)
			var/h = building_supported_height(get_turf(R), depth + 1, required_height)
			if (h > 0)
				return h
	return -1

/proc/building_supported_height(turf/T, depth = 0, required_height = 0)
	if (!T || depth > BUILDING_EXTRA_LEVELS)
		return 0
	for (var/atom/A in range(3, T))
		var/tier = A.building_support_tier()
		if (!tier)
			continue
		var/reach = 0
		if (istype(A, /obj/structure/roof_support))
			reach = 3
		else if (istype(A, /obj/structure/mine_support/stone) || isturf(A))
			reach = 2
		else if (istype(A, /obj/covers))
			reach = 1
		if (get_dist(A, T) > reach)
			continue
		var/h = building_floor_height(get_turf(A), depth)
		if (h >= 0 && max(h + 1, required_height) <= tier)
			if (building_floor_height(get_turf(A), depth, max(h + 1, required_height)) >= 0)
				return h + 1
	return 0

/proc/building_roof_error(turf/T)
	if (!T || building_allocating_z || persistence_save_in_progress)
		return "The upper building level is not ready. Try again shortly."
	if (istype(get_area(T), /area/caribbean/no_mans_land))
		return "You cannot build a roof here."
	if (locate(/obj/roof) in T)
		return "That area is already roofed!"
	if (!building_supported_height(T))
		return "This roof needs grounded walls or pillars of a sufficient tier. Wood supports two storeys, stone four, concrete six and metal eight."
	// A roof does not require a new plane. Admission for optional upper-floor
	// growth stays in building_allocate_level; existing upper turfs must be clear.
	if (T.z < world.maxz)
		var/turf/above = locate(T.x, T.y, T.z + 1)
		if (!building_open_turf(above) || (locate(/obj/covers) in above) || istype(get_area(above), /area/caribbean/no_mans_land))
			return "There is already terrain or construction above this roof."
	return null

/proc/building_floor_error(turf/T)
	if (!T)
		return "The target floor no longer exists."
	if (!building_open_turf(T))
		return null // Ground-level finishes do not create ceilings underground.
	if (building_allocating_z || T.z <= 1 || (locate(/obj/covers) in T))
		return "You cannot build another floor here."
	var/turf/below = locate(T.x, T.y, T.z - 1)
	var/error = building_roof_error(below)
	// The target open turf is checked above by the common roof preflight.
	return error

/proc/building_link(obj/roof/R, obj/covers/C)
	if (!R || !C || R.x != C.x || R.y != C.y || R.z + 1 != C.z)
		return FALSE
	var/id = md5("\ref[R]|\ref[C]|[world.realtime]|[world.time]")
	R.building_pair_id = id
	R.building_floor_z = C.z
	C.building_pair_id = id
	C.building_roof_z = R.z
	return TRUE

/proc/building_item_usable(obj/item/I, mob/user)
	return I && user && I.loc == user && !I.gcDestroyed && !I.gc_destroyed

/proc/building_construct_roof(turf/T, roof_type, mob/user, obj/item/source)
	var/error = building_roof_error(T)
	if (error)
		to_chat(user, SPAN_WARNING(error))
		return null
	if (T.z == world.maxz)
		building_allocate_level(T.z + 1)
	// Allocation can yield: recheck both support and occupancy before placing.
	error = building_roof_error(T)
	if (error)
		to_chat(user, SPAN_WARNING(error))
		return null
	if (source && (!building_item_usable(source, user) || user.z != T.z || get_dist(user, T) > 1))
		return null
	var/obj/roof/R = new roof_type(T)
	var/turf/above = locate(T.x, T.y, T.z + 1)
	if (!above)
		return R // Allocation was refused: the paid roof still provides shelter.
	var/obj/covers/repairedfloor/C = new(above)
	C.name = "upper floor"
	C.desc = "The walkable upper face of the ceiling below. Removing either face removes both."
	C.flammable = R.flammable
	C.wood = R.flammable
	if (!R.flammable)
		C.material = "Stone"
		C.amount = 0
	building_link(R, C)
	return R

/obj/covers/proc/building_finish_floor()
	var/turf/T = get_turf(src)
	if (!T)
		return FALSE
	if (!building_open_turf(T))
		return TRUE
	var/turf/below = locate(x, y, z - 1)
	if (!below || !building_supported_height(below) || (locate(/obj/roof) in below))
		return FALSE
	var/obj/roof/R = new /obj/roof/wood(below)
	return building_link(R, src)

/obj/roof/proc/building_remove_floor()
	var/obj/covers/C = building_floor()
	building_pair_id = null
	building_floor_z = 0
	if (C)
		qdel(C)

/obj/covers/proc/building_remove_roof()
	if (!building_pair_id)
		return
	var/obj/roof/R = building_roof()
	var/turf/T = get_turf(src)
	building_pair_id = null
	building_roof_z = 0
	if (R)
		R.building_pair_id = null
		R.building_floor_z = 0
		qdel(R)
	if (T && building_open_turf(T))
		// Exclude the retiring floor before native fall callbacks inspect covers.
		loc = null
		for (var/atom/movable/A in T)
			T.Entered(A)
		for (var/obj/roof/above in range(3, T))
			above.collapse_check()

// Both source files define covers lifecycle procedures. This common call is
// placed in the final definition so paired cleanup cannot be shadowed.
/obj/covers/Del()
	unregister_seasonal_construction()
	building_remove_roof()
	return ..()

/obj/roof/Del()
	unregister_seasonal_construction()
	building_remove_floor()
	return ..()
