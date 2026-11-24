// Physical foundering for a commissioned hull. The tiller and the actual
// fittings, cargo and occupants are moved; no parallel wreck inventory exists.

/datum/hull_ledger
	var/depth_disabled = FALSE
	var/tmp/depth_blocked = FALSE

/datum/hull_ledger/proc/storm_capsize()
	if (depth_disabled || persistence_save_active() || persistence_active_operation || persistence_load_recovery_required)
		return FALSE
	var/obj/structure/hull_tiller/T = helm()
	var/turf/at = get_turf(T)
	return at && sink(turn(weather_wind_dir_at(at), 180))

// The pivot normally is the tiller, but a restored or concave hull can have
// its pivot off the decks. Sample an occupied XY cell instead of open water.
/datum/hull_ledger/proc/depth_reference_cell(datum/craft_body/built/B)
	var/turf/T = get_turf(helm())
	if (B.contains(T))
		return T
	for (var/turf/D in B.cells())
		return D
	return null

/datum/hull_ledger/proc/step_hull_depth()
	if (!depth_disabled || !craft || persistence_save_active() || persistence_active_operation || persistence_load_recovery_required)
		return FALSE
	var/datum/craft_body/built/B = craft.body
	if (!istype(B) || !B.placed())
		return FALSE
	var/turf/at = depth_reference_cell(B)
	if (!at)
		return FALSE
	var/rising = !holes && fill() < 0.40
	var/from_surface = sea_layer_open_surface(at)
	if (rising && is_liquid_water(at) && !sea_layer_cell(at))
		pressure_clear()
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
	if (!rising && from_surface)
		pressure_prepare_descent()
	step_waterlogged_engines()
	if (rising && sea_layer_open_surface(locate(at.x, at.y, B.z)))
		pressure_clear()
		depth_disabled = FALSE
		craft.crew_message(SPAN_NOTICE("The [craft.name] breaks the surface. Check her machinery before making way."))
	else
		craft.crew_message(SPAN_WARNING(rising ? "The [craft.name] lifts from the bottom." : "The [craft.name] goes down with everything still aboard."))
	return TRUE

// A vertical move keeps the registered XY footprint. Every deck, including a
// hold, needs an existing linked level. A hold may temporarily cover open sea
// but must not excavate rock or form any new sea cells.
/datum/craft_body/built/proc/shift_foundering_level(target, rising)
	if (!placed() || !craft || moving || craft_rigid_cargo || !target || target == z || persistence_save_active() || persistence_active_operation || persistence_load_recovery_required)
		return FALSE
	if (craft.grapple || craft.ticket || craft.carrier || craft.carried.len)
		return FALSE
	if (target != (rising ? multiz_level_above(z) : multiz_level_below(z)))
		return FALSE
	var/list/main = cells()
	if (main.len != offsets.len)
		return FALSE
	var/list/lower = lower_cells(main)
	var/list/upper = upper_cells(main)
	var/list/source_levels = list(lower, main, upper, top_cells(upper))
	var/list/hold_floors = list()
	var/list/hold_ground = list()
	var/list/hold_ground_zones = list()
	var/list/hold_destinations = list()
	var/list/hold_destination_zones = list()
	for (var/turf/S in lower)
		var/obj/covers/C = hull_hold_cover(S)
		if (!C)
			return FALSE
		hold_floors[C] = TRUE
		hold_ground[S] = hull_hold_origin_path(C.hold_origin)
		hold_ground_zones[S] = C.hold_sea_zone
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
	var/next_z = multiz_level_below(target)
	for (var/deck = 1 to source_levels.len)
		var/list/sources = source_levels[deck]
		for (var/turf/S in sources)
			if (!next_z || S.vehicle_transforming || move_tiles[S])
				return FALSE
			var/turf/D = locate(S.x, S.y, next_z)
			if (!D || D.density || D.vehicle_transforming || destinations[D])
				return FALSE
			if (deck == 1)
				// On ascent the hold can take the sea under the outgoing
				// main deck, but never ground that must be hollowed out.
				if (!sea_layer_cell(D) || !next_z)
					return FALSE
				hold_destinations[D] = D.type
				hold_destination_zones[D] = hull_hold_terrain_zone(D)
			else if (deck == 2)
				if (!(sea_layer_cell(S) || (!rising && sea_layer_open_surface(S))))
					return FALSE
				// The old hold may overlap the next main deck on descent.
				if (!(sea_layer_cell(D) || hull_depth_sea_path(hold_ground[D]) || (rising && sea_layer_open_surface(D))))
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
		next_z = deck == 1 ? target : building_upper_z(next_z)
	for (var/obj/covers/C in hold_floors)
		if (!move_set[C])
			return FALSE
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
	var/list/changed_terrain = list()
	var/list/old_zones = list()
	var/old_bulk = wall_bulk_placement
	var/move_failed = FALSE
	try
		glide_keep(null)
		wall_bulk_placement = TRUE
		// Return the old hold's terrain even when a main deck is about to
		// occupy it, then make room for the new hold in existing sea only.
		for (var/turf/S in hold_ground)
			changed_terrain[S] = S.type
			hull_restore_hold_terrain(S, hold_ground[S], hold_ground_zones[S])
			water[S] = S.water_level
		for (var/turf/D in hold_destinations)
			changed_terrain[D] = D.type
			old_zones[D] = hold_destination_zones[D]
			D.ChangeTurf(/turf/floor/plating/ship_hold)
		wall_bulk_placement = old_bulk
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
		wall_bulk_placement = old_bulk
		move_failed = TRUE
		log_game("Ship depth movement interrupted: [e].")
	if (move_failed)
		wall_bulk_placement = TRUE
		for (var/turf/T in changed_terrain)
			try
				hull_restore_hold_terrain(T, changed_terrain[T], old_zones[T])
			catch (var/exception/terrain_error)
				log_game("Ship depth terrain rollback interrupted: [terrain_error].")
		wall_bulk_placement = old_bulk
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
	for (var/obj/covers/C in hold_floors)
		var/turf/D = get_turf(C)
		C.hold_origin = "[hold_destinations[D]]"
		C.hold_sea_zone = hold_destination_zones[D]
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

// A hold made in real underwater cells must still expose that fact to
// breathing, diving and machinery rules even when its actual turf is plating.
/proc/hull_depth_sea_path(path)
	return ispath(path, /turf/floor/beach/water/deep/saltwater/underwater/sea_layer)

/proc/hull_depth_underwater(turf/T)
	if (sea_layer_cell(T))
		return TRUE
	var/obj/covers/C = hull_hold_cover(T)
	return C && hull_depth_sea_path(hull_hold_origin_path(C.hold_origin))

/proc/hull_depth_zone(turf/T)
	if (sea_layer_cell(T))
		return sea_zone_of(T)
	var/obj/covers/C = hull_hold_cover(T)
	if (C && hull_depth_sea_path(hull_hold_origin_path(C.hold_origin)))
		return C.hold_sea_zone || SEA_ZONE_SHELF
	return 0

// A cover over submerged water doesn't make a surface ship a pressure hull.
/proc/submerged_built_hull_deck(turf/T)
	if (!hull_depth_underwater(T))
		return FALSE
	var/datum/craft/C = craft_holding(T)
	return C && C.ledger && C.ledger.depth_disabled
