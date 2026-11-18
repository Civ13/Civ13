// ============================================================
// Slipway ships as player-built hulls (docs/slipway.md)
// ------------------------------------------------------------
// A schooner comes off the ways as a hull of objects, the same as one players
// lay plank by plank (craft/built_body.dm): ship floors over the water, her two
// rigged masts and a tiller where her wheel stood, commissioned under her name.
// She then sails like any built hull: by pixels while someone is near, with
// her bilge, seams, anchor and rigging (naval/hull_*.dm).
//
// A schooner still afloat from before, which was a turf-built vessel, is
// turned into one the same way shortly after the world loads. Everyone and
// everything on her deck stays where it stands; her crew register goes with
// her. Ships with a deck below the waterline (the freighter) stay turf-built.
// ============================================================

// TRUE for a vessel this file can turn into a built hull: a single deck at
// the sea's surface.
/datum/vessel/proc/hull_convertible()
	if (!placed || levels.len != 1)
		return FALSE
	var/datum/vessel_level/L = levels[1]
	if (L.dz)
		return FALSE
	// Built hulls float on the sea, lakes and rivers, not in flooded trenches.
	for (var/turf/T in cells())
		var/original = L.originals["[T.x],[T.y]"]
		if (!ispath(original, /turf/floor/beach/water))
			return FALSE
	return TRUE

// Only the schooner is launched and kept as a built hull.
/datum/vessel/proc/sails_as_built_hull()
	return FALSE

/datum/vessel/schooner/sails_as_built_hull()
	return TRUE

// Turns a placed vessel into a commissioned built hull. Returns her tiller,
// or null (and leaves her as she was) when she cannot be.
/proc/vessel_to_built_hull(datum/vessel/V)
	if (!V || QDELETED(V) || !V.hull_convertible())
		return null
	var/list/cells = V.cells()
	if (!cells.len || cells.len > BUILT_HULL_MAX_TILES)
		return null
	var/turf/helm_at = null
	var/list/mast_at = list()
	for (var/turf/T in cells)
		for (var/obj/structure/vessel_helm/H in T)
			if (!helm_at)
				helm_at = T
		for (var/obj/structure/vessel_mast/M in T)
			mast_at += T
	if (!helm_at)
		return null
	var/hull_name = V.name
	var/heading = V.dir
	var/datum/craft/old = craft_of_vessel(V, FALSE)
	var/datum/craft_register/register = old ? old.register : null
	if (old)
		if (old.name)
			hull_name = old.name
		old.register = null
	for (var/turf/T in cells)
		for (var/obj/structure/vessel_helm/H in T)
			qdel(H)
		for (var/obj/structure/vessel_mast/M in T)
			qdel(M)
	// Her deck turfs go back to the water they stood on; what stood on them stays.
	V.remove()
	qdel(V)
	for (var/turf/T in cells)
		var/obj/covers/repairedfloor/ship/F = new(T)
		F.updateturf()
	for (var/turf/T in mast_at)
		var/obj/structure/vehicleparts/movement/sail/premade/S = new(T)
		S.anchored = TRUE
	var/obj/structure/hull_tiller/tiller = new(helm_at)
	var/problem = tiller.commission(hull_name, heading)
	if (problem)
		log_game("Slipway hull: [hull_name] at [helm_at.x],[helm_at.y],[helm_at.z] could not be commissioned: [problem]")
		return null
	if (register)
		register.name = hull_name
		tiller.craft.register = register
	log_game("Slipway hull: [hull_name] at [helm_at.x],[helm_at.y],[helm_at.z] now sails as a built hull ([cells.len] tiles).")
	return tiller

// After a load, a schooner restored as a turf-built vessel is turned into a
// built hull once the load has finished.
/datum/vessel/proc/restored()
	if (sails_as_built_hull())
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(vessel_to_built_hull), src), 50)
