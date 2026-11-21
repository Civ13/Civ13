// ============================================================
// Slipway ships as player-built hulls (docs/slipway.md)
// ------------------------------------------------------------
// A slipway ship comes off the ways as a hull of objects, the same as one
// players lay plank by plank (craft/built_body.dm), commissioned under her
// name with a tiller where her wheel stood. She then sails like any built
// hull: by pixels while someone is near, with her bilge, seams, anchor and
// drives (naval/hull_*.dm).
//
// - The schooner: ship floors over the water and her two rigged masts.
// - The freighter: a steel deck with the wheelhouse walls, and her hold below
//   the waterline (naval/hull_hold.dm) with a diesel engine and its fuel
//   barrel where the bunker filling point stood. The bulkhead between the
//   engine room and the hold is the rock left between them, with its door.
//
// A slipway ship still afloat from before, which was a turf-built vessel, is
// turned into one the same way shortly after the world loads. Everyone and
// everything aboard stays where it stands; her crew register goes with her,
// and the fuel in her bunkers goes into the engine's barrel.
// ============================================================

// The freighter's engine: big enough for full ahead with a hold full of cargo.
#define SLIPWAY_ENGINE_CC 5000

// TRUE for a vessel this file can turn into a built hull: a deck at the sea's
// surface and at most a hold on the level below, afloat on open water.
/datum/vessel/proc/hull_convertible()
	if (!placed)
		return FALSE
	var/surface = FALSE
	for (var/datum/vessel_level/L in levels)
		if (L.dz == 0)
			surface = TRUE
		else if (L.dz != -1 || L.z != multiz_level_below(base_z))
			return FALSE
	if (!surface)
		return FALSE
	// Built hulls float on the sea, lakes and rivers, not in flooded trenches,
	// and a hold is hollowed out of rock or deep water.
	for (var/turf/T in cells())
		var/datum/vessel_level/L = level_for_z(T.z)
		var/original = L.originals["[T.x],[T.y]"]
		if (L.dz == 0 ? !ispath(original, /turf/floor/beach/water) : !(ispath(original, /turf/wall/rockwall) || ispath(original, /turf/floor/beach/water/deep)))
			return FALSE
	return TRUE

// Slipway ships are launched and kept as built hulls.
/datum/vessel/proc/sails_as_built_hull()
	return FALSE

/datum/vessel/schooner/sails_as_built_hull()
	return TRUE

/datum/vessel/freighter/sails_as_built_hull()
	return TRUE

// What her deck is laid with as a built hull.
/datum/vessel/proc/built_floor_type()
	return /obj/covers/repairedfloor/ship

/datum/vessel/freighter/built_floor_type()
	return /obj/covers/steelplating

// Turns a placed vessel into a commissioned built hull. Returns her tiller,
// or null (and leaves her as she was) when she cannot be.
/proc/vessel_to_built_hull(datum/vessel/V)
	if (!V || QDELETED(V) || !V.hull_convertible())
		return null
	var/list/deck = list()
	var/list/walls = list()
	var/list/hold = list()
	var/turf/helm_at = null
	var/turf/bunker_at = null
	var/list/mast_at = list()
	for (var/turf/T in V.cells())
		var/datum/vessel_level/L = V.level_for_z(T.z)
		if (L.dz)
			// Her hull and bulkheads below are the rock left around the hold.
			if (!istype(T, /turf/wall))
				hold += T
			for (var/obj/structure/vessel_bunker/B in T)
				bunker_at = T
			continue
		deck += T
		if (istype(T, /turf/wall))
			walls[T] = TRUE
		for (var/obj/structure/vessel_helm/H in T)
			if (!helm_at)
				helm_at = T
		for (var/obj/structure/vessel_mast/M in T)
			mast_at += T
	if (!helm_at || !deck.len || deck.len > BUILT_HULL_MAX_TILES || deck.len + hold.len > BUILT_HULL_MAX_DECK_TILES)
		return null
	var/hull_name = V.name
	var/heading = V.dir
	var/fuel = V.fuel
	var/floor_type = V.built_floor_type()
	var/datum/craft/old = craft_of_vessel(V, FALSE)
	var/datum/craft_register/register = old ? old.register : null
	if (old)
		if (old.name)
			hull_name = old.name
		old.register = null
	for (var/turf/T in deck + hold)
		for (var/obj/structure/vessel_helm/H in T)
			qdel(H)
		for (var/obj/structure/vessel_mast/M in T)
			qdel(M)
		for (var/obj/structure/vessel_bunker/B in T)
			qdel(B)
	// Her turfs go back to what they were; what stood on them stays.
	V.remove()
	qdel(V)
	for (var/turf/T in deck)
		var/obj/covers/F = walls[T] ? new /obj/covers/metal(T) : new floor_type(T)
		F.updateturf()
	for (var/turf/T in hold)
		hull_hold_lay(T)
	for (var/turf/T in mast_at)
		var/obj/structure/vehicleparts/movement/sail/premade/S = new(T)
		S.anchored = TRUE
	if (bunker_at)
		var/obj/structure/engine/internal/diesel/E = new(bunker_at)
		E.enginesize = SLIPWAY_ENGINE_CC
		E.maxpower = initial(E.maxpower) * SLIPWAY_ENGINE_CC / 1000
		E.fuelefficiency = initial(E.fuelefficiency) * SLIPWAY_ENGINE_CC / 1000
		E.weight = 20 * SLIPWAY_ENGINE_CC / 1000
		E.name = "[SLIPWAY_ENGINE_CC]cc [initial(E.name)]"
		var/obj/item/weapon/reagent_containers/glass/barrel/tank = new(bunker_at)
		tank.anchored = TRUE
		E.fueltank = tank
		if (fuel > 0)
			tank.reagents.add_reagent("diesel", min(fuel, tank.volume))
	// She comes off the ways with her sides closed (hull_sides.dm).
	hull_rail_sides_free(deck)
	var/obj/structure/hull_tiller/tiller = new(helm_at)
	var/problem = tiller.commission(hull_name, heading)
	if (problem)
		log_game("Slipway hull: [hull_name] at [helm_at.x],[helm_at.y],[helm_at.z] could not be commissioned: [problem]")
		return null
	if (register)
		register.name = hull_name
		tiller.craft.register = register
	log_game("Slipway hull: [hull_name] at [helm_at.x],[helm_at.y],[helm_at.z] now sails as a built hull ([deck.len] tiles, [hold.len] of hold).")
	return tiller

// After a load, a slipway ship restored as a turf-built vessel is turned into
// a built hull once the load has finished.
/datum/vessel/proc/restored()
	if (sails_as_built_hull())
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(vessel_to_built_hull), src), 50)

#undef SLIPWAY_ENGINE_CC
