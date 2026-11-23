// Physical foundering for a commissioned hull. The tiller and the actual
// fittings, cargo and occupants are moved; no parallel wreck inventory exists.

/datum/hull_ledger
	var/depth_disabled = FALSE
	var/tmp/depth_blocked = FALSE

/datum/hull_ledger/proc/storm_capsize()
	if (depth_disabled || persistence_save_active() || persistence_active_operation || persistence_load_recovery_required)
		return FALSE
	craft.crew_message(SPAN_DANGER("The [craft.name] rolls in the beam seas! Get off the exposed deck or hold on below."))
	add_water(capacity() - water)
	return sink()

/datum/hull_ledger/proc/step_hull_depth()
	if (!depth_disabled || !craft || persistence_save_active() || persistence_active_operation || persistence_load_recovery_required)
		return FALSE
	var/datum/craft_body/built/B = craft.body
	if (!istype(B) || !B.placed())
		return FALSE
	var/turf/at = locate(B.px, B.py, B.z)
	var/rising = !holes && fill() < 0.40
	if (rising && is_liquid_water(at) && !sea_layer_cell(at))
		depth_disabled = FALSE
		depth_blocked = FALSE
		craft.crew_message(SPAN_NOTICE("The [craft.name] floats again. Check the machinery before making way."))
		return TRUE
	var/target = rising ? multiz_level_above(B.z) : multiz_level_below(B.z)
	if (!target || !B.shift_foundering_level(target, rising))
		if (!depth_blocked && is_liquid_water(at) && !sea_layer_cell(at))
			craft.crew_message(SPAN_WARNING("The [craft.name] cannot go down here. She is waterlogged and cannot make way; patch and pump her out."))
		depth_blocked = TRUE
		return FALSE
	depth_blocked = FALSE
	step_waterlogged_engines()
	if (rising && sea_layer_open_surface(locate(B.px, B.py, B.z)))
		depth_disabled = FALSE
		craft.crew_message(SPAN_NOTICE("The [craft.name] breaks the surface. Check her machinery before making way."))
	else
		craft.crew_message(SPAN_WARNING(rising ? "The [craft.name] lifts from the bottom." : "The [craft.name] goes down with everything still aboard."))
	return TRUE

// A vertical move keeps the registered XY footprint. Refuse the complete
// operation if any deck cannot be represented at its new level. In particular,
// opening or replacing seabed to fit a hold is not safe.
/datum/craft_body/built/proc/shift_foundering_level(target, rising)
	if (!placed() || !craft || moving || craft_rigid_cargo || !target || target == z || persistence_save_active() || persistence_active_operation || persistence_load_recovery_required)
		return FALSE
	if (craft.grapple || craft.ticket || craft.carrier || craft.carried.len || lower_tile_count())
		return FALSE
	if (target != (rising ? multiz_level_above(z) : multiz_level_below(z)))
		return FALSE
	var/list/main = cells()
	if (main.len != offsets.len)
		return FALSE
	var/list/upper = upper_cells(main)
	var/list/source_levels = list(main, upper, top_cells(upper))
	var/list/move_tiles = list()
	var/list/move_set = list()
	var/list/destinations = list()
	var/list/floors = list()
	var/list/riders = list()
	var/list/roof_pairs = list()
	var/list/water = list()
	var/list/deck_water = list()
	var/list/turf_depths = list()
	var/list/cover_depths = list()
	var/list/carried_roofs = list()
	var/list/ambient_types = list()
	var/next_z = target
	for (var/deck = 1 to source_levels.len)
		var/list/sources = source_levels[deck]
		for (var/turf/S in sources)
			if (!next_z || S.vehicle_transforming || move_tiles[S])
				return FALSE
			var/turf/D = locate(S.x, S.y, next_z)
			if (!D || D.density || D.vehicle_transforming || destinations[D])
				return FALSE
			if (deck == 1)
				if (!(sea_layer_cell(S) || (!rising && sea_layer_open_surface(S))))
					return FALSE
				if (!(sea_layer_cell(D) || (rising && sea_layer_open_surface(D))))
					return FALSE
			else if (!(building_open_turf(D) || sea_layer_open_surface(D) || sea_layer_cell(D)))
				return FALSE
			move_tiles[S] = D
			destinations[D] = TRUE
			var/area/ambient = get_area(D)
			if (ambient && !ambient_types[D])
				ambient_types[D] = ambient.type
			water[S] = true_water_level(S)
			water[D] = true_water_level(D)
			turf_depths[S] = list(S.water_level, S.move_delay)
			turf_depths[D] = list(D.water_level, D.move_delay)
			for (var/atom/movable/M in S)
				if (M.loc != S || QDELETED(M) || !M.craft_cargo())
					continue
				if (!persistence_movement_allowed(M, D))
					return FALSE
				move_set[M] = S
				if (istype(M, /obj/covers) || istype(M, /obj/structure/multiz))
					floors += M
					if (istype(M, /obj/covers))
						var/obj/covers/C = M
						cover_depths[C] = C.origin_water_level
						deck_water[D] = TRUE
				else
					riders += M
				if (istype(M, /obj/roof))
					var/obj/roof/R = M
					if (R.switch_area)
						var/area/A = get_area(S)
						carried_roofs[R] = A
						ambient_types[S] = R.current_area_type
					var/obj/covers/C = R.building_floor()
					if (C)
						roof_pairs[R] = C
		next_z = building_upper_z(next_z)
	for (var/obj/roof/R in roof_pairs)
		var/obj/covers/C = roof_pairs[R]
		if (!move_set[C])
			return FALSE
	for (var/turf/D in destinations)
		var/datum/craft/other = craft_holding(D)
		if (other && other != craft)
			return FALSE
		for (var/atom/movable/M in D)
			if (M.loc != D || QDELETED(M) || move_set[M] == D)
				continue
			if (M.density || ismob(M) || istype(M, /obj/item) || istype(M, /obj/covers) || istype(M, /obj/roof) || istype(M, /obj/structure) || istype(M, /obj/machinery))
				return FALSE
	// Use the same rigid carry as horizontal moves. Move only the captured
	// atoms, even when a new deck overlaps the old one above or below it.
	var/turf/old_origin = origin()
	moving = TRUE
	var/list/carry = craft_rigid_begin(floors + riders)
	var/list/arrived = list()
	var/move_failed = FALSE
	try
		glide_keep(null)
		for (var/turf/D in deck_water)
			D.water_level = 0
			D.move_delay = 0
		for (var/atom/movable/M in floors + riders)
			var/turf/S = move_set[M]
			var/turf/D = move_tiles[S]
			if (QDELETED(M) || M.loc != S)
				move_failed = TRUE
				break
			arrived += M
			craft_step_move(M, D, 0, 0, 0)
			if (QDELETED(M) || M.loc != D)
				move_failed = TRUE
				break
			if (istype(M, /obj/covers))
				var/obj/covers/C = M
				C.origin_water_level = water[D]
	catch (var/exception/e)
		move_failed = TRUE
		log_game("Ship depth movement interrupted: [e].")
	if (move_failed)
		// Floors return before people and crates. An unsuccessful hook may
		// already have moved an atom, so it is included in the return set.
		for (var/atom/movable/M in arrived)
			var/turf/S = move_set[M]
			if (QDELETED(M) || M.loc == S)
				continue
			try
				craft_step_move(M, S, 0, 0, 0)
			catch (var/exception/rollback_error)
				log_game("Ship depth rollback interrupted: [rollback_error].")
		for (var/turf/T in turf_depths)
			var/list/snapshot = turf_depths[T]
			T.water_level = snapshot[1]
			T.move_delay = snapshot[2]
		for (var/obj/covers/C in cover_depths)
			if (!QDELETED(C))
				C.origin_water_level = cover_depths[C]
		moving = FALSE
		craft_rigid_settle(carry)
		return FALSE
	for (var/obj/roof/R in roof_pairs)
		var/obj/covers/C = roof_pairs[R]
		R.building_floor_z = C.z
		C.building_roof_z = R.z
	// A roof owns its interior area. Restore vacated space using the
	// original area type kept by that roof, then apply all moving interiors.
	for (var/obj/roof/R in carried_roofs)
		var/turf/S = move_set[R]
		var/outside = R.current_area_type
		if (ispath(outside, /area))
			new outside(S)
	for (var/obj/roof/R in carried_roofs)
		var/turf/D = get_turf(R)
		var/area/A = carried_roofs[R]
		if (D && A && A != D.loc)
			A.contents += D
		if (ispath(ambient_types[D], /area))
			R.current_area_type = ambient_types[D]
	for (var/turf/S in move_tiles)
		if (!deck_water[S])
			S.water_level = water[S]
			S.move_delay = initial(S.move_delay)
	z = target
	plan_memo = null
	craft.ledger.bays_dirty = TRUE
	moving = FALSE
	craft_rigid_settle(carry)
	craft.on_hop(old_origin)
	return TRUE

// A cover over submerged water doesn't make a surface ship a pressure hull.
/proc/submerged_built_hull_deck(turf/T)
	if (!sea_layer_cell(T))
		return FALSE
	var/datum/craft/C = craft_holding(T)
	return C && C.ledger && C.ledger.depth_disabled
