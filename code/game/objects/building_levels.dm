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

// Native expansion creates world.turf on every cell of the plane in one step
// that cannot yield. With open air as the default the plane is already right;
// a fixture whose default differs replaces those cells in batches.
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
		if (world.turf != /turf/sky/building)
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

// An empty cell of a plane under allocation needs no registry, render or
// lighting work: it is not in the turf registry that the daylight sweep walks,
// keeps its compiled defaults (so the level saves sparsely) and runs the full
// constructor only when something replaces it.
/turf/sky/building/New()
	if (building_allocating_z && z == building_allocating_z)
		return
	..()

/turf/sky/building/Entered(atom/movable/A)
	// Lighting renderers belong to their turf; they are not falling cargo.
	if (istype(A, /atom/movable/lighting_overlay) || istype(A, /atom/movable/lighting_fullbright))
		return
	if (!A || !A.loc || istype(A, /obj/covers) || istype(A, /obj/roof) || isobserver(A) || (locate(/obj/covers) in src) || (locate(/obj/structure/multiz/ladder) in src))
		return
	if (istype(A, /obj/effect) || istype(A, /obj/item/projectile))
		return
	// An airborne aircraft is the floor for what it carries.
	var/aircraft_holds = text2path("/proc/aircraft_holds")
	if (aircraft_holds && call(aircraft_holds)(src, A))
		return
	var/below_z = multiz_level_below(z)
	var/turf/below = below_z ? locate(x, y, below_z) : null
	// Open air over stairs is a stairwell: walk down instead of falling.
	if (below && stairs_soft_descent(A, below))
		return
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
	return key == "roof_overlay" || key == "sagging" || ..()

// Building levels stack over the surface; a dug cave level is never one.
/proc/building_upper_z(z)
	var/dug = dug_underground_z()
	return dug && z == dug ? 0 : multiz_level_above(z)

/obj/roof/proc/building_floor()
	if (!building_pair_id || building_floor_z != building_upper_z(z))
		return null
	for (var/obj/covers/C in locate(x, y, building_floor_z))
		if (C.building_pair_id == building_pair_id && C.building_roof_z == z && !C.gc_destroyed && !C.gcDestroyed)
			return C

/obj/covers/proc/building_roof()
	if (!building_pair_id || building_roof_z != multiz_level_below(z))
		return null
	for (var/obj/roof/R in locate(x, y, building_roof_z))
		if (R.building_pair_id == building_pair_id && R.building_floor_z == z && !R.gc_destroyed && !R.gcDestroyed)
			return R

// Soft ground carries this many storeys; taller buildings need a foundation.
#define BUILDING_UNFOUNDED_STOREYS 2
// Load that founded ground carries: more than any tier.
#define BUILDING_GROUND_STRENGTH 1000

// Rock, mapped masonry and built stone or metal floors are foundations.
/turf/proc/building_foundation()
	return FALSE

/turf/wall/building_foundation()
	return TRUE

/turf/floor/plating/building_foundation()
	return TRUE

/turf/floor/rocky/building_foundation()
	return TRUE

/turf/floor/dirt/underground/building_foundation()
	return TRUE

/obj/covers/proc/building_foundation()
	if (wall || incomplete || health <= 0 || gc_destroyed || gcDestroyed)
		return FALSE
	return (lowertext(material) in list("stone", "steel", "iron", "concrete"))

// A dirt road is packed soil, whatever its parent type is made of.
/obj/covers/roads/dirt/building_foundation()
	return FALSE

// A ground-floor support is founded on rock or over a stone, brick, concrete
// or metal floor. Derived from what stands there; nothing is saved for it.
/proc/building_founded(atom/A)
	var/turf/T = get_turf(A)
	if (!T)
		return FALSE
	if (T.building_foundation())
		return TRUE
	for (var/obj/covers/C in T)
		if (C.building_foundation())
			return TRUE
	return FALSE

// Storeys the ground under a ground-floor support carries.
/proc/building_ground_strength(atom/A)
	return building_founded(A) ? BUILDING_GROUND_STRENGTH : BUILDING_UNFOUNDED_STOREYS

// How far a support holds a slab: pillars reach further than walls.
/proc/building_support_reach(atom/A)
	if (istype(A, /obj/structure/roof_support))
		return 3
	if (istype(A, /obj/structure/mine_support/stone) || isturf(A))
		return 2
	if (istype(A, /obj/covers))
		return 1
	return 0

// What support A stands on: list(storey, strength). Ground is storey 0 and
// carries anything when founded; an upper floor passes on what holds it.
/proc/building_support_base(atom/A, list/memo, depth = 0)
	var/turf/U = get_turf(A)
	if (!U)
		return null
	if (!building_open_turf(U))
		return list(0, building_ground_strength(A))
	for (var/obj/covers/C in U)
		if (C.gc_destroyed || C.gcDestroyed)
			continue
		var/obj/roof/R = C.building_roof()
		if (R)
			var/list/info = building_slab_info(get_turf(R), memo, depth + 1)
			if (info)
				return info
	return null

// The storey a roof on T is and the storeys its strongest support chain
// carries: list(storey, strength), or null when nothing holds it. Every
// elevated support must lead through a paired slab to real ground, and a chain
// is as strong as its weakest support. memo keeps each roof tile's answer for
// one check, so supports shared between tiles are resolved once and the work
// grows with the size of the building, not exponentially with its height.
/proc/building_slab_info(turf/T, list/memo, depth = 0)
	if (!T || depth > BUILDING_EXTRA_LEVELS)
		return null
	var/known = memo[T]
	if (known)
		return islist(known) ? known : null
	memo[T] = -1
	var/list/best
	for (var/atom/A in range(3, T))
		var/tier = A.building_support_tier()
		if (!tier || get_dist(A, T) > building_support_reach(A))
			continue
		var/list/under = building_support_base(A, memo, depth)
		if (!under)
			continue
		var/h = under[1] + 1
		// A chain is as strong as its weakest support.
		var/cap = min(tier, under[2])
		if (h > cap)
			continue
		if (!best || cap > best[2])
			best = list(h, cap)
	if (best)
		memo[T] = best
	return best

// -1 is unsupported air. Natural/mapped solid ground is a foundation.
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

// The storey of a roof on T, or 0 when nothing holds it (or nothing that
// carries required_height storeys).
/proc/building_supported_height(turf/T, depth = 0, required_height = 0)
	var/list/info = building_slab_info(T, list(), depth)
	if (!info || info[2] < required_height)
		return 0
	return info[1]

// A support on an upper floor carries storey h only over supports that carry
// it too: walk down, one storey at a time, looking within a tile of the column
// for a wall or pillar of that strength, founded where it meets the ground.
/proc/building_column_carries(atom/A, h)
	var/turf/U = get_turf(A)
	var/storeys = 0
	while (U && building_open_turf(U))
		if (++storeys > BUILDING_EXTRA_LEVELS)
			return FALSE
		var/turf/below
		for (var/obj/covers/C in U)
			if (C.gc_destroyed || C.gcDestroyed)
				continue
			var/obj/roof/R = C.building_roof()
			if (R)
				below = get_turf(R)
				break
		if (!below)
			return FALSE
		var/atom/carrier
		for (var/atom/S in range(1, below))
			if (S.building_support_tier() < h)
				continue
			if (!building_open_turf(get_turf(S)) && building_ground_strength(S) < h)
				continue
			carrier = S
			break
		if (!carrier)
			return FALSE
		U = get_turf(carrier)
	return TRUE

// Why a new roof on T may not be built, or null. Standing roofs keep the plain
// support rule (building_supported_height); new work must also be designed:
// supports above supports and, from the second storey up, no slab hung from
// one distant pillar.
/proc/building_design_error(turf/T)
	var/list/memo = list()
	var/list/info = building_slab_info(T, memo)
	if (!info)
		return "This roof needs grounded walls or pillars of a sufficient tier. Wood supports two storeys, stone four, concrete six and metal eight. Above two storeys the ground-floor supports must stand on rock or on a stone, brick or concrete floor."
	var/h = info[1]
	var/near = FALSE
	var/uncarried = FALSE
	var/list/sides = list()
	for (var/atom/A in range(3, T))
		var/tier = A.building_support_tier()
		if (tier < h || get_dist(A, T) > building_support_reach(A))
			continue
		var/list/under = building_support_base(A, memo)
		if (!under || under[1] + 1 != h || under[2] < h)
			continue
		if (!building_column_carries(A, h))
			uncarried = TRUE
			continue
		if (get_dist(A, T) <= 1)
			near = TRUE
			break
		sides |= get_dir(T, A)
	// A ground-floor roof keeps its old rule: any one support within reach.
	if (near || sides.len >= 2 || (h < 2 && sides.len))
		return null
	if (uncarried)
		return "The walls or pillars here have nothing strong enough beneath them on the floor below. Build supports above supports of the same strength."
	return "One distant pillar cannot hold this. Build a wall or pillar next to this tile, or a second support on another side."

/proc/building_roof_error(turf/T)
	if (!T || building_allocating_z || persistence_save_in_progress)
		return "The upper building level is not ready. Try again shortly."
	if (istype(get_area(T), /area/caribbean/no_mans_land))
		return "You cannot build a roof here."
	if (locate(/obj/roof) in T)
		return "That area is already roofed!"
	var/design_error = building_design_error(T)
	if (design_error)
		return design_error
	// A roof does not require a new plane. Admission for optional upper-floor
	// growth stays in building_allocate_level; existing upper turfs must be clear.
	var/upper_z = building_upper_z(T.z)
	if (upper_z)
		var/turf/above = locate(T.x, T.y, upper_z)
		if (!building_open_turf(above) || (locate(/obj/covers) in above) || istype(get_area(above), /area/caribbean/no_mans_land))
			return "There is already terrain or construction above this roof."
	else if (practice_room_z && T.z + 1 == practice_room_z && building_stack_room(T.z))
		return "The level above is in use for a moment. Try again in a few minutes."
	return null

// TRUE when the map lets its building levels grow above z.
/proc/building_stack_room(z)
	return map && map.building_levels && z >= building_base_maxz() && z < building_base_maxz() + map.building_levels

// A roof adds the next level when it is on the top ground level, as before, or
// on the highest building level of a map that permits more of them.
/proc/building_grows_from(z)
	if (building_upper_z(z))
		return FALSE
	return z == multiz_top_z() || (z == world.maxz && z > building_base_maxz() && building_stack_room(z))

/proc/building_floor_error(turf/T)
	if (!T)
		return "The target floor no longer exists."
	if (!building_open_turf(T))
		return null // Ground-level finishes do not create ceilings underground.
	var/below_z = multiz_level_below(T.z)
	if (building_allocating_z || !below_z || (locate(/obj/covers) in T))
		return "You cannot build another floor here."
	var/turf/below = locate(T.x, T.y, below_z)
	var/error = building_roof_error(below)
	// The target open turf is checked above by the common roof preflight.
	return error

/proc/building_link(obj/roof/R, obj/covers/C)
	if (!R || !C || R.x != C.x || R.y != C.y || !C.z || building_upper_z(R.z) != C.z)
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
	if (building_grows_from(T.z))
		building_allocate_level(world.maxz + 1)
	// Allocation can yield: recheck both support and occupancy before placing.
	error = building_roof_error(T)
	if (error)
		to_chat(user, SPAN_WARNING(error))
		return null
	if (source && (!building_item_usable(source, user) || user.z != T.z || get_dist(user, T) > 1))
		return null
	var/obj/roof/R = new roof_type(T)
	var/upper_z = building_upper_z(T.z)
	var/turf/above = upper_z ? locate(T.x, T.y, upper_z) : null
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
	var/below_z = multiz_level_below(z)
	var/turf/below = below_z ? locate(x, y, below_z) : null
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
