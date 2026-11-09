// ============================================================
// Flooding Controller - manages water accumulation, spreading,
// compartment air, and compartment integrity across all
// submarine deck turfs. Processes on a regular tick interval.
// Air is not simulated per tile: each sealed compartment holds one
// habitat ledger (code/modules/space/habitat_ledger.dm).
// ============================================================

var/global/datum/flooding_controller/subcom_flooding
// Every controller: the Submarine Commander boat's and one per turf-built
// vessel (code/modules/naval/). The submarine process ticks them all.
var/global/list/flooding_controllers = list()

// The controller a deck tile reports to: its vessel's, or the SUBCOM13 one.
/proc/flooding_for(turf/T)
	var/datum/vessel/V = vessel_at(T)
	if(V && V.flooding)
		return V.flooding
	return global.subcom_flooding

// Registered in New() so the per-second tick never has to scan the world.
// Bulkheads are turfs: ChangeTurf() retypes them in place with no Destroy(),
// so stale entries are pruned from the list when their type no longer matches.
var/global/list/sub_bulkheads = list()
var/global/list/sub_blast_doors = list()

/datum/flooding_controller
	// All tracked deck turfs, indexed by compartment_id
	var/list/tracked_turfs = list()      // list of all /turf/floor/sub_deck
	var/list/compartment_turfs = list()  // assoc: compartment_id -> list of turfs
	// Air: one habitat ledger per sealed compartment (compartment_id -> ledger).
	// Water is still per tile; air is one set of numbers per compartment.
	var/list/compartment_air = list()
	// Compartments whose ventilation was shut off from the compartment panel.
	var/list/ventilation_off = list()
	var/tick_counter = 0
	// The turf-built vessel this controller serves; null for SUBCOM13's boat.
	var/datum/vessel/vessel

/datum/flooding_controller/New(var/datum/vessel/V)
	..()
	flooding_controllers += src
	if(V)
		vessel = V
	else
		global.subcom_flooding = src

// ---- Registration ----

/datum/flooding_controller/proc/register_turf(var/turf/floor/sub_deck/T)
	if(!T) return
	if(T in tracked_turfs) return  // Already registered
	tracked_turfs += T
	T.flooding_owner = src
	if(T.compartment_id)
		if(!compartment_turfs[T.compartment_id])
			compartment_turfs[T.compartment_id] = list()
		compartment_turfs[T.compartment_id] += T
		// Each new tile brings one tile of sea-level air, so pressure is unchanged.
		var/datum/habitat_ledger/L = compartment_air[T.compartment_id]
		if(!L)
			L = new /datum/habitat_ledger(1)
			compartment_air[T.compartment_id] = L
		else
			L.resize(L.volume + 1)
		L.add_gas(SUB_AIR_SEA_O2_KPA, 0, SUB_AIR_SEA_INERT_KPA)

/datum/flooding_controller/proc/unregister_turf(var/turf/floor/sub_deck/T)
	if(!T) return
	if(T.compartment_id && compartment_turfs[T.compartment_id])
		var/list/turfs = compartment_turfs[T.compartment_id]
		if(!(T in turfs))
			tracked_turfs -= T
			return
		// The tile takes its share of the compartment's air with it.
		var/datum/habitat_ledger/L = compartment_air[T.compartment_id]
		if(L && turfs.len > 0)
			var/keep = (turfs.len - 1) / turfs.len
			L.oxygen *= keep
			L.co2 *= keep
			L.inert *= keep
			L.resize(L.volume - 1)
		turfs -= T
		if(!turfs.len)
			compartment_air -= T.compartment_id
	tracked_turfs -= T

// The partial pressures of every compartment, for rebind_turfs.
/datum/flooding_controller/proc/air_snapshot()
	var/list/snapshot = list()
	for(var/cid in compartment_air)
		var/datum/habitat_ledger/L = compartment_air[cid]
		if(L && L.volume > 0)
			snapshot[cid] = list(L.oxygen / L.volume, L.co2 / L.volume, L.inert / L.volume, L.temperature)
	return snapshot

// Rebuilds the tracked lists from the deck tiles a vessel now stands on, after
// a hop has rewritten them. Turf references are positional, so the old lists
// point at whatever stands where the decks were. Each compartment keeps the
// air it had (from snapshot) at its new tile count; a compartment seen for
// the first time gets sea-level air.
/datum/flooding_controller/proc/rebind_turfs(var/list/turfs, var/list/snapshot)
	tracked_turfs = list()
	compartment_turfs = list()
	for(var/turf/floor/sub_deck/T in turfs)
		tracked_turfs += T
		T.flooding_owner = src
		if(T.compartment_id)
			if(!compartment_turfs[T.compartment_id])
				compartment_turfs[T.compartment_id] = list()
			compartment_turfs[T.compartment_id] += T
	for(var/cid in compartment_air.Copy())
		if(!compartment_turfs[cid])
			compartment_air -= cid
	for(var/cid in compartment_turfs)
		var/list/tiles = compartment_turfs[cid]
		var/datum/habitat_ledger/L = compartment_air[cid]
		if(!L)
			L = new /datum/habitat_ledger(tiles.len)
			compartment_air[cid] = L
		L.resize(tiles.len)
		var/list/kpa = snapshot ? snapshot[cid] : null
		if(kpa)
			L.oxygen = kpa[1] * tiles.len
			L.co2 = kpa[2] * tiles.len
			L.inert = kpa[3] * tiles.len
			L.temperature = kpa[4]
		else
			L.oxygen = 0
			L.co2 = 0
			L.inert = 0
			L.add_gas(SUB_AIR_SEA_O2_KPA * tiles.len, 0, SUB_AIR_SEA_INERT_KPA * tiles.len)

// The air a compartment shares, or null for decks outside any compartment.
/datum/flooding_controller/proc/get_air(var/compartment_id)
	if(!compartment_id)
		return null
	return compartment_air[compartment_id]

/datum/flooding_controller/proc/is_ventilated(var/compartment_id)
	return compartment_id && compartment_air[compartment_id] && !(compartment_id in ventilation_off)

// ---- Main Processing Loop ----

/datum/flooding_controller/proc/process_tick()
	tick_counter++

	// Process all tracked turfs (water and fire stay per tile)
	var/list/water_by_compartment = list()
	var/list/inflow_by_compartment = list()
	for(var/turf/floor/sub_deck/T in tracked_turfs)
		if(QDELETED(T))
			tracked_turfs -= T
			continue
		T.flood_tick()
		T.fire_tick()
		if(T.compartment_id)
			water_by_compartment[T.compartment_id] += T.water_depth / max(1, T.max_water)
			if(T.water_inflow_rate > 0)
				inflow_by_compartment[T.compartment_id] = 1  // Air bubbles out of a compartment taking water

	// Air: one ledger per compartment. A submerged breach floods but does
	// not vent: the sea pushes in and the pocket compresses (the water term
	// above). Only a surfaced boat loses air through an open hull.
	air_tick(1, water_by_compartment, breaches_vent() ? inflow_by_compartment : null)

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
	for(var/B_ref in sub_bulkheads.Copy())
		var/turf/wall/sub_bulkhead/B = B_ref
		if(!istype(B) || QDELETED(B))
			sub_bulkheads -= B_ref
			continue
		if(!B.watertight)
			// Compromised seals leak; a crumpled bulkhead (health at or below
			// zero) passes water faster. Both pass water: the destroyed case
			// used to be excluded by a health > 0 guard, so the worst damage
			// held back the most water.
			var/leak_fraction = B.health > 0 ? 0.1 : 0.25
			var/leak_cap = B.health > 0 ? 3 : 8
			for(var/direction in list(NORTH, SOUTH, EAST, WEST))
				var/turf/floor/sub_deck/neighbor = get_step(B, direction)
				if(neighbor && istype(neighbor) && neighbor.flooding_owner == src && neighbor.water_depth > 10)
					// Spread water through the now-open bulkhead
					var/turf/floor/sub_deck/other_side = get_step(B, turn(direction, 180))
					if(other_side && istype(other_side) && !other_side.water_sealed)
						var/flow = min(neighbor.water_depth * leak_fraction, leak_cap)
						other_side.add_water(flow)

	// Open blast door check: propagate water through open doors between compartments
	for(var/obj/structure/simple_door/blast/D in sub_blast_doors.Copy())
		if(QDELETED(D))
			sub_blast_doors -= D
			continue
		if(!D.state) continue  // Door is closed
		// Door is open - check both sides for water
		for(var/direction in list(NORTH, SOUTH, EAST, WEST))
			var/turf/floor/sub_deck/neighbor = get_step(D, direction)
			if(!neighbor || !istype(neighbor) || neighbor.flooding_owner != src) continue
			if(neighbor.water_depth > 10)
				var/turf/floor/sub_deck/other_side = get_step(D, turn(direction, 180))
				if(other_side && istype(other_side) && !other_side.water_sealed)
					var/flow = min(neighbor.water_depth * 0.1, 3)
					other_side.add_water(flow)

// ---- Compartment Air ----

// One air step for every compartment. Water takes up room (the air pocket
// shrinks and its pressure rises); a compartment with seawater pouring in
// counts as one breach that lets air escape. Every compartment ticks while
// the world has players, so a breached compartment keeps losing air after the
// crew leaves it; only breathing depends on who is inside. Nothing ticks
// while the world is empty.
/datum/flooding_controller/proc/air_tick(var/seconds, var/list/water_by_compartment, var/list/inflow_by_compartment)
	if(!air_may_tick())
		return
	var/list/occupants = count_breathers()
	var/anyone = FALSE
	for(var/cid in compartment_air)
		var/datum/habitat_ledger/L = compartment_air[cid]
		var/list/turfs = compartment_turfs[cid]
		var/tiles = turfs ? turfs.len : 0
		if(!L || tiles <= 0)
			continue
		var/water = water_by_compartment ? water_by_compartment[cid] : 0
		L.resize(max(1, tiles * SUB_AIR_MIN_POCKET, tiles - water))
		var/n = occupants[cid]
		if(n > 0)
			anyone = TRUE
		L.advance(seconds, n, inflow_by_compartment ? inflow_by_compartment[cid] : 0)
	if(anyone)
		ventilate()
		apply_air_effects()

// Air runs only while someone is connected to the world; an empty world
// never catches up on the time it spent idle.
/datum/flooding_controller/proc/air_may_tick()
	return clients.len > 0

// Whether an open hull lets air out: TRUE on the surface, FALSE submerged.
// With no submarine datum (fixtures, a bare map) the hull is treated as
// surfaced so a breach still vents.
/datum/flooding_controller/proc/breaches_vent()
	if(vessel)
		return vessel.breaches_vent()
	for(var/datum/submarine/S in all_submarines)
		return S.depth <= 0
	return TRUE

// Living humans on each compartment's deck (compartment_id -> count).
/datum/flooding_controller/proc/count_breathers()
	var/list/counts = list()
	for(var/mob/living/human/H in human_mob_list)
		if(H.stat == DEAD)
			continue
		var/turf/floor/sub_deck/T = get_turf(H)
		if(istype(T) && T.flooding_owner == src && T.compartment_id && compartment_air[T.compartment_id])
			counts[T.compartment_id] += 1
	return counts

// Ventilated compartments with a working duct draw toward the shared partial
// pressures of the ventilation system. Gas is conserved.
/datum/flooding_controller/proc/ventilate()
	var/list/pool = list()
	for(var/obj/structure/machinery/sub_physical/vent_duct/D in sub_physical_machines)
		if(QDELETED(D) || !D.active || D.health <= 0)
			continue
		var/turf/floor/sub_deck/T = get_turf(D)
		if(istype(T) && is_ventilated(T.compartment_id))
			pool |= compartment_air[T.compartment_id]
	if(pool.len < 2)
		return
	var/volume = 0
	var/o = 0
	var/c = 0
	var/n = 0
	for(var/datum/habitat_ledger/L in pool)
		volume += L.volume
		o += L.oxygen
		c += L.co2
		n += L.inert
	if(volume <= 0)
		return
	for(var/datum/habitat_ledger/L in pool)
		var/share = L.volume / volume
		L.oxygen += (o * share - L.oxygen) * SUB_AIR_VENT_FLOW
		L.co2 += (c * share - L.co2) * SUB_AIR_VENT_FLOW
		L.inert += (n * share - L.inert) * SUB_AIR_VENT_FLOW

// Bad air hurts whoever breathes it.
/datum/flooding_controller/proc/apply_air_effects()
	for(var/mob/living/human/H in human_mob_list)
		if(H.stat == DEAD)
			continue
		var/turf/floor/sub_deck/T = get_turf(H)
		if(!istype(T) || T.flooding_owner != src)
			continue
		var/datum/habitat_ledger/L = get_air(T.compartment_id)
		if(!L)
			continue
		var/o2 = L.oxygen_kpa()
		if(L.co2_kpa() > SUB_AIR_DANGER_CO2_KPA)
			H.losebreath = max(H.losebreath + 1, 1)
			if(prob(3))
				to_chat(H, "<span class='danger'>The air is thick with CO2!</span>")
		if(o2 < SUB_AIR_SUFFOCATE_O2_KPA)
			H.losebreath = max(H.losebreath + 1, 1)
			H.adjustOxyLoss(HABITAT_SUFFOCATE_OXYLOSS)
			if(prob(8))
				to_chat(H, "<span class='danger'>You gasp for air - the oxygen is gone!</span>")
		else if(o2 < HABITAT_MIN_OXYGEN_KPA && prob(3))
			to_chat(H, "<span class='warning'>The air feels thin and stale.</span>")

// ---- Compartment Queries ----

/datum/flooding_controller/proc/get_compartment_water_level(var/compartment_id)
	if(!compartment_turfs[compartment_id]) return 0
	var/total = 0
	var/count = 0
	for(var/turf/floor/sub_deck/T in compartment_turfs[compartment_id])
		total += T.water_depth
		count++
	return count > 0 ? total / count : 0

// Oxygen partial pressure in kPa (sea level is about 21).
/datum/flooding_controller/proc/get_compartment_oxygen(var/compartment_id)
	var/datum/habitat_ledger/L = get_air(compartment_id)
	return L ? L.oxygen_kpa() : 0

// CO2 partial pressure in kPa.
/datum/flooding_controller/proc/get_compartment_co2(var/compartment_id)
	var/datum/habitat_ledger/L = get_air(compartment_id)
	return L ? L.co2_kpa() : 0

/datum/flooding_controller/proc/is_compartment_flooded(var/compartment_id)
	return get_compartment_water_level(compartment_id) >= 150

/datum/flooding_controller/proc/is_compartment_vacuum(var/compartment_id)
	return get_compartment_oxygen(compartment_id) < SUB_AIR_VACUUM_O2_KPA

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

// Add oxygen to a compartment (from electrolysis, O2 tanks, etc.), in
// kPa-tiles. Stops at SUB_AIR_MAX_O2_KPA. Returns the amount added.
/datum/flooding_controller/proc/inject_oxygen(var/compartment_id, var/amount)
	var/datum/habitat_ledger/L = get_air(compartment_id)
	if(!L) return 0
	var/room = max(0, SUB_AIR_MAX_O2_KPA * L.volume - L.oxygen)
	var/added = min(room, max(0, amount))
	if(added > 0)
		L.add_gas(added, 0, 0)
	return added

// Remove CO2 from a compartment (scrubbers), in kPa-tiles. Returns the amount removed.
/datum/flooding_controller/proc/scrub_co2(var/compartment_id, var/amount)
	var/datum/habitat_ledger/L = get_air(compartment_id)
	if(!L) return 0
	return L.scrub_co2(amount)

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
