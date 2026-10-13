// Physical relocation foundation. Account ownership/garage persistence must
// commit separately before invoking this helper; it never credits an account.
/datum/extraction_vehicle_transfer
	var/obj/structure/vehicleparts/axis/axis
	var/turf/origin
	var/list/parts = list()
	var/list/locations = list()
	var/list/tiles = list()
	var/consumed = FALSE
	var/last_error
	var/list/cargo = list()
	var/list/cargo_record
	var/with_cargo = FALSE
	var/list/cargo_roster
	persistence_runtime_var(key)
		if (key in list("axis", "origin", "parts", "locations", "tiles", "consumed", "last_error", "cargo", "cargo_record", "with_cargo", "cargo_roster")) return TRUE
		return ..()
	proc/clear_cargo_snapshot()
		cargo_record = null
		cargo_roster = null
	proc/fail(message)
		last_error = message
		return FALSE
	proc/allowed(atom/movable/O)
		return istype(O, /obj/structure/vehicleparts) || istype(O, /obj/structure/engine/internal) || istype(O, /obj/structure/bed/chair) || istype(O, /obj/structure/table/carboot) || istype(O, /obj/item/weapon/reagent_containers/glass/barrel/fueltank) || istype(O, /obj/effect/pseudovehicle)
	proc/linked(atom/movable/O, obj/structure/vehicleparts/axis/A)
		if (O in cargo) return TRUE
		if (istype(O, /obj/structure/vehicleparts/frame) && O:axis != A) return fail("Frame belongs to another controller")
		if (istype(O, /obj/structure/vehicleparts/movement) && O:axis != A) return FALSE
		if (istype(O, /obj/structure/vehicleparts/license_plate) && O:axis != A) return FALSE
		if (istype(O, /obj/effect/pseudovehicle) && O:link != A) return FALSE
		if (istype(O, /obj/structure/engine/internal) && O != A.engine) return FALSE
		if (istype(O, /obj/item/weapon/reagent_containers/glass/barrel/fueltank) && O != A.engine.fueltank) return FALSE
		if (istype(O, /obj/structure/bed/chair) && O:buckled_mob) return FALSE
		for (var/atom/movable/child in O.contents)
			if (istype(child, /atom/movable/lighting_overlay)) continue
			var/connected_wheel = istype(child, /obj/structure/vehicleparts/movement) && (child in A.wheels) && child:axis == A && child:connected == O
			if (child != A && child != A.wheel && !connected_wheel) return fail("Unexpected contained [child.type] in [O.type]")
			for (var/atom/movable/nested in child.contents)
				if (!istype(nested, /atom/movable/lighting_overlay)) return fail("Unexpected nested [nested.type] in [child.type]")
		return TRUE
	// Ordinary capture validates existing identity. Initial codec acquisition opts
	// into the legacy issuance path; its atomic issuance boundary remains deferred.
	proc/capture(obj/structure/vehicleparts/axis/A, include_cargo = FALSE, assign_new_ids = FALSE, mutate_persistence = FALSE)
		last_error = null
		axis = null
		parts.Cut()
		locations.Cut()
		tiles.Cut()
		consumed = FALSE
		cargo.Cut()
		clear_cargo_snapshot()
		with_cargo = include_cargo
		if (A?.key_service_busy) return fail("Vehicle key service is reserved")
		if (!A || A.vehicle_type != "car" || A.moving || A.currentspeed || A.movement_processes || A.transforming_vehicle || A.driver || !A.engine || A.engine.on || !A.components.len || A.components.len > 16) return FALSE
		origin = get_turf(A)
		if (!origin) return FALSE
		for (var/atom/movable/component in A.components)
			var/turf/T = get_turf(component)
			if (!T || component.loc != T || T.z != origin.z || abs(T.x-origin.x) > 3 || abs(T.y-origin.y) > 3 || (T in tiles)) return FALSE
			tiles += T
		for (var/turf/T in tiles)
			for (var/atom/movable/O in T)
				if (istype(O, /atom/movable/lighting_overlay)) continue
				if (!allowed(O) && with_cargo && istype(O, /obj/item) && (locate(/obj/structure/table/carboot) in T)) cargo += O
				if ((!allowed(O) && !(O in cargo)) || parts.len >= 96) return fail("Unsupported footprint atom [O.type] or part budget")
				if (!linked(O, A)) return fail(last_error ? last_error : "Unrelated part or occupied contents [O.type]")
				parts += O
				locations[O] = T
		axis = A
		var/datum/extraction_vehicle_cargo/C = new
		cargo_roster = list()
		cargo_record = C.encode(A, cargo, assign_new_ids, cargo_roster, mutate_persistence)
		if (isnull(cargo_record))
			clear_cargo_snapshot()
			return fail("Unsupported or over-capacity boot cargo")
		return TRUE
	proc/current()
		if (axis?.key_service_busy) return FALSE
		if (!axis || consumed || !axis.engine || get_turf(axis) != origin || axis.moving || axis.currentspeed || axis.movement_processes || axis.transforming_vehicle || axis.driver || axis.engine.on) return FALSE
		var/count = 0
		for (var/turf/T in tiles)
			for (var/atom/movable/O in T)
				if (istype(O, /atom/movable/lighting_overlay)) continue
				if (!(O in parts) || locations[O] != T || !linked(O, axis)) return FALSE
				count++
		var/datum/extraction_vehicle_cargo/C = new
		var/list/live_roster = list()
		var/list/current_cargo = C.encode(axis, cargo, FALSE, live_roster, FALSE)
		return count == parts.len && !isnull(current_cargo) && C.same_roster(cargo_roster, live_roster) && json_encode(current_cargo) == json_encode(cargo_record)
	proc/destination_tiles(turf/destination)
		if (!destination || !current()) return null
		var/list/targets = list()
		for (var/turf/T in tiles)
			var/turf/target = locate(destination.x + T.x-origin.x, destination.y + T.y-origin.y, destination.z)
			if (!istype(target, /turf/floor) || target.density || (target in tiles)) return null
			for (var/atom/movable/O in target)
				if (!istype(O, /atom/movable/lighting_overlay)) return null
			targets[T] = target
		return targets
	proc/relocate(turf/destination)
		var/list/targets = destination_tiles(destination)
		if (!targets || axis?.key_service_busy) return FALSE
		// No waits or constructors after preflight. Keep the actual engine, tank,
		// damage, seats and nested steering/controller objects in the same graph.
		consumed = TRUE
		clear_cargo_snapshot()
		axis.transporting.Cut()
		axis.matrix_current_locs.Cut()
		for (var/atom/movable/O in parts) O.forceMove(targets[locations[O]])
		axis.check_corners()
		axis.check_matrix()
		return TRUE
	Destroy()
		clear_cargo_snapshot()
		return ..()
