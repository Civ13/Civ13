// ============================================================
// Building and refitting a hull at a berth (docs/berths.md)
// ------------------------------------------------------------
// A hull is floors laid over water with a tiller on one of them
// (built_hull.dm). At a berth her floors may stand where there is no open
// water as well:
//
// - in a dock basin, flooded or pumped dry (drydock.dm);
// - on the berth of an empty slipway: dry open ground in front of the post,
//   up to SHIP_DRAUGHT_SIDE tiles along the ways and half that to either
//   side (slipway_haul.dm). She is commissioned with her bow to the open
//   water the way the post faces and her stern on the tile in front of it,
//   so she lies hauled out and can be launched from the post.
//
// So a hull can be laid down from nothing on a dry berth, and one lying
// there can have floors added or lifted and be refitted at the tiller
// ("Refit the hull") like a hull afloat. A boathouse slip is open water
// already. Nothing is saved for it: the berth is asked from where she lies.
// ============================================================

// How far from a tile a dock gate is asked to look at its basin again.
#define BERTH_GATE_REACH 24

// TRUE when this berth lets hull floors stand on T off the water.
/obj/structure/proc/berth_ground(turf/T)
	return FALSE

// Why a hull of these tiles, her bow to heading, cannot be commissioned at
// this berth, or null.
/obj/structure/proc/berth_commission_refusal(list/turfs, heading)
	return null

// The berth whose ground T is, or null.
/proc/berth_ground_at(turf/T)
	if (!T)
		return null
	var/obj/structure/canal_lock/dock_gate/G = dock_basin_turfs[T]
	if (!G || QDELETED(G))
		// A basin dug or finished since its gate last looked.
		for (var/obj/structure/canal_lock/dock_gate/O in range(BERTH_GATE_REACH, T))
			O.refresh_basin()
		G = dock_basin_turfs[T]
	if (G && !QDELETED(G) && G.berth_ground(T))
		return G
	if (!slipway_haul_ground(T))
		return null
	for (var/obj/structure/slipway/S in range(SHIP_DRAUGHT_SIDE, T))
		if (S.berth_ground(T))
			return S
	return null

// ---- The dock basin ----

/obj/structure/canal_lock/dock_gate/berth_ground(turf/T)
	var/list/B = basin()
	return B && (T in B)

// ---- The slipway berth ----

/obj/structure/slipway/berth_ground(turf/T)
	if (!T || design || !isturf(loc) || T.z != z || !slipway_haul_ground(T))
		return FALSE
	var/along = ways_along(T)
	return along >= 1 && along <= SHIP_DRAUGHT_SIDE && abs(ways_aside(T)) <= SHIP_DRAUGHT_SIDE / 2

/obj/structure/slipway/berth_commission_refusal(list/turfs, heading)
	if (heading != dir)
		return "On the slipway her bow must point to the open water, [dir2text(dir)]."
	for (var/turf/T in turfs)
		if (ways_along(T) == 1 && ways_aside(T) == 0)
			return null
	return "On the slipway her stern must lie on the tile in front of the post, in line with it."

#undef BERTH_GATE_REACH
