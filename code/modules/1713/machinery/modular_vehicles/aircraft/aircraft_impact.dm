// Aircraft crashing into buildings (structure_impact.dm, building_collapse.dm).
//
// A plane in low flight that meets a wall, pillar or door hits it with its
// loaded weight times its speed. The blow is shared between the frames' lanes
// that meet something and carries on through up to AIRCRAFT_IMPACT_DEPTH tiles
// along the heading while it lasts: a light plane knocks a hole in a wooden
// house, a heavy one at speed goes through it, and stone mostly holds. The
// plane then breaks up where it hit (wreck()). A fuelled plane sets wood and
// thatch it hits alight.
//
// A plane that breaks up over a building (no clear ground to crash-land on)
// comes down on its roof with the same force.

// Force per frame per speed gear, in wood-part hit points (structure_impact.dm).
#define AIRCRAFT_IMPACT_PER_FRAME 60
#define AIRCRAFT_IMPACT_DEPTH 3

/obj/structure/vehicleparts/axis/aircraft/proc/impact_force()
	return AIRCRAFT_IMPACT_PER_FRAME * max(1, length(frames())) * load_scale() * max(1, currentspeed)

/obj/structure/vehicleparts/axis/aircraft/proc/impact_fuelled()
	return engine && engine.fueltank && engine.fueltank.reagents && engine.fueltank.reagents.total_volume > 0

// Whether T holds a part of a building a plane can fly into (not a hillside).
/proc/aircraft_building_at(turf/T)
	if (!T)
		return FALSE
	if (T.density && is_structure_impact_part(T))
		return TRUE
	for (var/obj/covers/C in T)
		if (C.density && is_structure_impact_part(C))
			return TRUE
	for (var/obj/structure/S in T)
		if (S.density && is_structure_impact_part(S))
			return TRUE
	return FALSE

/proc/aircraft_burns(atom/A)
	switch (lowertext("[A.structure_impact_material()]"))
		if ("wood", "bamboo", "thatch", "straw", "palm", "leaves", "cloth")
			return TRUE
	return FALSE

// The blow reaches every building part on T in turn: walls, pillars and doors,
// then the roof. Returns the force left over.
/proc/aircraft_impact_tile(turf/T, force, dir, atom/source, fuelled = FALSE)
	if (!T || force <= 0)
		return force
	var/list/parts = list()
	if (T.density && is_structure_impact_part(T))
		parts += T
	for (var/obj/covers/C in T)
		if (C.density && is_structure_impact_part(C))
			parts += C
	for (var/obj/structure/S in T)
		if (S.density && is_structure_impact_part(S))
			parts += S
	for (var/obj/roof/R in T)
		parts += R
	var/burn = FALSE
	for (var/atom/A in parts)
		if (fuelled && aircraft_burns(A))
			burn = TRUE
		force = A.structure_impact(force, IMPACT_CRUSH, source, dir)
		if (force <= 0)
			break
	if (burn && !T.density && !(locate(/obj/effect/fire) in T))
		new /obj/effect/fire(T)
	return force

// The plane flies into a building on level z: every lane ahead that meets a
// part takes a share of the blow, then the plane breaks up where it hit.
/obj/structure/vehicleparts/axis/aircraft/proc/building_crash(m_dir, z, reason)
	var/force = impact_force()
	var/fuelled = impact_fuelled()
	var/list/lanes = list()
	for (var/obj/structure/vehicleparts/frame/F in frames())
		var/turf/S = get_step(F.loc, m_dir)
		if (S)
			S = locate(S.x, S.y, z)
		if (S && aircraft_building_at(S))
			lanes |= S
	if (lanes.len)
		var/share = force / lanes.len
		for (var/turf/S in lanes)
			var/left = share
			var/turf/T = S
			for (var/i in 1 to AIRCRAFT_IMPACT_DEPTH)
				left = aircraft_impact_tile(T, left, m_dir, src, fuelled)
				if (left <= 0)
					break
				T = get_step(T, m_dir)
				if (!T)
					break
		var/turf/first = lanes[1]
		first.visible_message(SPAN_DANGER("\The [src] smashes into the building!"))
		for (var/mob/M in range(7, first))
			if (M.client)
				shake_camera(M, 4, 2)
	return wreck(reason, FALSE)

// A breaking-up airframe comes down on whatever building is under it: the
// upper floor its frames lie on and the roof below.
/obj/structure/vehicleparts/axis/aircraft/proc/wreck_onto_buildings(down)
	var/list/F = frames()
	if (!F.len)
		return
	var/share = impact_force() / F.len
	var/fuelled = impact_fuelled()
	for (var/obj/structure/vehicleparts/frame/FR in F)
		var/turf/here = get_turf(FR)
		var/left = share
		if (here && building_open_turf(here))
			for (var/obj/covers/C in here)
				if (!QDELETED(C) && !C.wall && C.building_roof())
					left = C.structure_impact(left, IMPACT_CRUSH, src, DOWN)
					break
		if (left > 0 && down)
			aircraft_impact_tile(locate(FR.x, FR.y, down), left, DOWN, src, fuelled)

#undef AIRCRAFT_IMPACT_PER_FRAME
#undef AIRCRAFT_IMPACT_DEPTH
