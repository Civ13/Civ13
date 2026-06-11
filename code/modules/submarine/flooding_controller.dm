// ============================================================
// Flooding Controller - manages water accumulation, spreading,
// atmospheric simulation, and compartment integrity across all
// submarine deck turfs. Processes on a regular tick interval.
// ============================================================

var/global/datum/flooding_controller/subcom_flooding

/datum/flooding_controller
	// All tracked deck turfs, indexed by compartment_id
	var/list/tracked_turfs = list()      // list of all /turf/floor/sub_deck
	var/list/compartment_turfs = list()  // assoc: compartment_id -> list of turfs
	var/list/list/vent_networks = list()      // assoc: vent_id -> list of connected turfs
	var/tick_counter = 0

/datum/flooding_controller/New()
	..()
	global.subcom_flooding = src

// ---- Registration ----

/datum/flooding_controller/proc/register_turf(var/turf/floor/sub_deck/T)
	if(!T) return
	if(T in tracked_turfs) return  // Already registered
	tracked_turfs += T
	if(T.compartment_id)
		if(!compartment_turfs[T.compartment_id])
			compartment_turfs[T.compartment_id] = list()
		compartment_turfs[T.compartment_id] += T

/datum/flooding_controller/proc/unregister_turf(var/turf/floor/sub_deck/T)
	if(!T) return
	tracked_turfs -= T
	if(T.compartment_id && compartment_turfs[T.compartment_id])
		compartment_turfs[T.compartment_id] -= T

// ---- Vent Network Registration ----

/datum/flooding_controller/proc/register_vent(var/vent_id, var/turf/floor/sub_deck/T)
	if(!vent_id || !T) return
	if(!vent_networks[vent_id])
		vent_networks[vent_id] = list()
	vent_networks[vent_id] += T
	T.vent_active = TRUE
	T.vent_id = vent_id

/datum/flooding_controller/proc/unregister_vent(var/vent_id, var/turf/floor/sub_deck/T)
	if(!vent_id || !T) return
	if(vent_networks[vent_id])
		vent_networks[vent_id] -= T
		if(!vent_networks[vent_id].len)
			vent_networks -= vent_id
	T.vent_active = FALSE
	T.vent_id = ""

// ---- Main Processing Loop ----

/datum/flooding_controller/proc/process_tick()
	tick_counter++

	// Process all tracked turfs
	for(var/turf/floor/sub_deck/T in tracked_turfs)
		if(QDELETED(T))
			tracked_turfs -= T
			continue
		T.flood_tick()
		T.atmos_tick()
		T.fire_tick()

	// Ambient water drip in flooded compartments (every 30 ticks)
	if(tick_counter % 30 == 0)
		var/list/wet_turfs = list()
		for(var/turf/floor/sub_deck/T in tracked_turfs)
			if(!QDELETED(T) && T.water_depth > 20)
				wet_turfs += T
		if(wet_turfs.len)
			var/turf/floor/sub_deck/drip_turf = pick(wet_turfs)
			playsound(drip_turf, 'sound/machines/submarine/water_drip.ogg', 30, 1)

	// Bulkhead integrity check: if a bulkhead adjacent to a breached area is damaged,
	// propagate water through it
	for(var/turf/wall/sub_bulkhead/B in world)
		if(QDELETED(B)) continue
		if(!B.watertight && B.health > 0)
			// This bulkhead was destroyed - check if adjacent deck turfs have water
			for(var/direction in list(NORTH, SOUTH, EAST, WEST))
				var/turf/floor/sub_deck/neighbor = get_step(B, direction)
				if(neighbor && istype(neighbor) && neighbor.water_depth > 10)
					// Spread water through the now-open bulkhead
					var/turf/floor/sub_deck/other_side = get_step(B, turn(direction, 180))
					if(other_side && istype(other_side) && !other_side.water_sealed)
						var/flow = min(neighbor.water_depth * 0.1, 3)
						other_side.add_water(flow)

	// Open blast door check: propagate water through open doors between compartments
	for(var/obj/structure/simple_door/blast/D in world)
		if(QDELETED(D)) continue
		if(!D.state) continue  // Door is closed
		// Door is open - check both sides for water
		for(var/direction in list(NORTH, SOUTH, EAST, WEST))
			var/turf/floor/sub_deck/neighbor = get_step(D, direction)
			if(!neighbor || !istype(neighbor)) continue
			if(neighbor.water_depth > 10)
				var/turf/floor/sub_deck/other_side = get_step(D, turn(direction, 180))
				if(other_side && istype(other_side) && !other_side.water_sealed)
					var/flow = min(neighbor.water_depth * 0.1, 3)
					other_side.add_water(flow)

// ---- Compartment Queries ----

/datum/flooding_controller/proc/get_compartment_water_level(var/compartment_id)
	if(!compartment_turfs[compartment_id]) return 0
	var/total = 0
	var/count = 0
	for(var/turf/floor/sub_deck/T in compartment_turfs[compartment_id])
		total += T.water_depth
		count++
	return count > 0 ? total / count : 0

/datum/flooding_controller/proc/get_compartment_oxygen(var/compartment_id)
	if(!compartment_turfs[compartment_id]) return 0
	var/total = 0
	var/count = 0
	for(var/turf/floor/sub_deck/T in compartment_turfs[compartment_id])
		total += T.oxygen_moles
		count++
	return count > 0 ? total / count : 0

/datum/flooding_controller/proc/get_compartment_co2(var/compartment_id)
	if(!compartment_turfs[compartment_id]) return 0
	var/total = 0
	var/count = 0
	for(var/turf/floor/sub_deck/T in compartment_turfs[compartment_id])
		total += T.co2_moles
		count++
	return count > 0 ? total / count : 0

/datum/flooding_controller/proc/is_compartment_flooded(var/compartment_id)
	return get_compartment_water_level(compartment_id) >= 150

/datum/flooding_controller/proc/is_compartment_vacuum(var/compartment_id)
	return get_compartment_oxygen(compartment_id) < 2

// ---- Emergency Drain ----

// Emergency drain: pumps water out of all turfs in a compartment at once
/datum/flooding_controller/proc/emergency_drain(var/compartment_id, var/drain_rate = 15)
	if(!compartment_turfs[compartment_id]) return 0
	var/drained = 0
	for(var/turf/floor/sub_deck/T in compartment_turfs[compartment_id])
		if(T.water_depth > 0)
			var/amount = min(T.water_depth, drain_rate)
			T.remove_water(amount)
			drained += amount
	return drained

// ---- Oxygen Injection ----

// Inject oxygen into all turfs in a compartment (from electrolysis, O2 tanks, etc.)
/datum/flooding_controller/proc/inject_oxygen(var/compartment_id, var/moles)
	if(!compartment_turfs[compartment_id]) return
	for(var/turf/floor/sub_deck/T in compartment_turfs[compartment_id])
		T.oxygen_moles = min(30, T.oxygen_moles + moles)  // Cap at 30 moles

// ---- Compartment Breach Status Summary ----

/datum/flooding_controller/proc/get_all_compartment_status()
	var/list/status = list()
	for(var/cid in compartment_turfs)
		var/list/comp_data = list()
		comp_data["water_level"] = get_compartment_water_level(cid)
		comp_data["oxygen"] = get_compartment_oxygen(cid)
		comp_data["co2"] = get_compartment_co2(cid)
		comp_data["flooded"] = is_compartment_flooded(cid)
		comp_data["vacuum"] = is_compartment_vacuum(cid)
		status[cid] = comp_data
	return status
