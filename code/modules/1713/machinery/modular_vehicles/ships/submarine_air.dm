// A player submarine's air (ocean phase 2).
//
// Submerged, the hull is sealed: the crew breathe one habitat air ledger
// (space/habitat_ledger.dm) for the whole boat. Breathing turns oxygen into
// CO2; the boat's blowers keep it fresh by swapping stale air for clean air
// from its compressed-air bank, a single number that saves with the boat.
// When the bank runs dry the air goes stale and the crew start to suffocate
// unless they surface or seal themselves into diving gear.
//
// On the surface the hatches stand open: the hull air is the open air and
// the compressor refills the bank. The lock-out chamber spends bank air to
// blow the water out when a diver comes back in, and the ballast station
// fills diving bottles from it. With the bank empty a diver can still pump
// the chamber dry by hand, slowly.
//
// The ledger is advanced lazily, when someone aboard breathes or reads the
// station, so an empty boat costs nothing. It is runtime only: a restored
// boat starts with fresh hull air and whatever its bank held.

// Hull volume in tiles of air per hull frame.
#define SUB_AIR_TILES_PER_FRAME 1
// Open air, in kPa: oxygen and the rest.
#define SUB_AIR_OXYGEN_KPA 21
#define SUB_AIR_INERT_KPA 80
// Compressed-air bank capacity and surface recharge (kPa-tiles of air).
#define SUB_AIR_BANK_MAX 6000
#define SUB_AIR_BANK_RECHARGE_PER_SECOND 50
// The blowers start when CO2 rises past this or oxygen drops under this (kPa)...
#define SUB_AIR_VENT_CO2_KPA 1
#define SUB_AIR_VENT_OXYGEN_KPA 19
// ...and swap at most this fraction of the hull air per second.
#define SUB_AIR_VENT_FRACTION_PER_SECOND 0.05
// Shortest interval between two lazy steps.
#define SUB_AIR_STEP (2 SECONDS)
// Longest single ledger step (the ledger caps its own steps at 10 s).
#define SUB_AIR_MAX_STEP_SECONDS 10
// Bank air spent blowing the lock-out chamber dry.
#define SUB_AIR_LOCKIN_COST 60
// Oxygen share of bank air (refilling bottles takes oxygen).
#define SUB_AIR_OXYGEN_SHARE 0.21

/obj/structure/vehicleparts/axis/ship/submarine
	// Compressed air in the bank (kPa-tiles). Saved.
	var/air_bank = SUB_AIR_BANK_MAX
	var/tmp/datum/habitat_ledger/hull_air = null
	var/tmp/last_air_step = 0
	var/tmp/air_warned = FALSE

/obj/structure/vehicleparts/axis/ship/submarine/persistence_runtime_var(key)
	return (key in list("hull_air", "last_air_step", "air_warned")) || ..(key)

/obj/structure/vehicleparts/axis/ship/submarine/proc/hull_volume()
	return max(1, frames().len * SUB_AIR_TILES_PER_FRAME)

// The hull air, made fresh the first time it is needed.
/obj/structure/vehicleparts/axis/ship/submarine/proc/hull_ledger()
	if (!hull_air)
		hull_air = new /datum/habitat_ledger(hull_volume())
		sub_air_freshen(hull_air)
		last_air_step = world.time
	return hull_air

/proc/sub_air_freshen(datum/habitat_ledger/L)
	L.oxygen = SUB_AIR_OXYGEN_KPA * L.volume
	L.co2 = 0
	L.inert = SUB_AIR_INERT_KPA * L.volume
	L.temperature = 20

// Living things aboard that breathe the hull air.
/obj/structure/vehicleparts/axis/ship/submarine/proc/air_breathers()
	. = 0
	for (var/mob/living/M in transporting)
		if (M.stat == DEAD)
			continue
		var/turf/T = get_turf(M)
		if (T && T.iscovered())
			.++

// Swaps up to fraction of the hull air for fresh bank air. Returns the bank air used.
/obj/structure/vehicleparts/axis/ship/submarine/proc/vent_hull(fraction)
	var/datum/habitat_ledger/L = hull_ledger()
	var/full = (SUB_AIR_OXYGEN_KPA + SUB_AIR_INERT_KPA) * L.volume
	var/want = full * max(0, min(1, fraction))
	var/used = min(want, air_bank)
	if (used <= 0)
		return 0
	var/f = used / full
	L.oxygen *= (1 - f)
	L.co2 *= (1 - f)
	L.inert *= (1 - f)
	L.add_gas(used * SUB_AIR_OXYGEN_SHARE, 0, used * (1 - SUB_AIR_OXYGEN_SHARE))
	air_bank -= used
	return used

// Advances the hull air by seconds: breathing, the blowers, and on the
// surface open hatches and the compressor.
/obj/structure/vehicleparts/axis/ship/submarine/proc/air_step(seconds)
	var/datum/habitat_ledger/L = hull_ledger()
	if (seconds <= 0)
		return
	systems_step(seconds)
	if (!submerged)
		sub_air_freshen(L)
		air_bank = min(SUB_AIR_BANK_MAX, air_bank + SUB_AIR_BANK_RECHARGE_PER_SECOND * seconds)
		air_warned = FALSE
		return
	var/breathers = air_breathers()
	while (seconds > 0)
		var/dt = min(seconds, SUB_AIR_MAX_STEP_SECONDS)
		seconds -= dt
		L.advance(dt, breathers, hull_leaks)
		if (L.co2_kpa() > SUB_AIR_VENT_CO2_KPA || L.oxygen_kpa() < SUB_AIR_VENT_OXYGEN_KPA)
			vent_hull(SUB_AIR_VENT_FRACTION_PER_SECOND * dt)
	if (air_bank <= 0 && !air_warned)
		air_warned = TRUE
		crew_message(SPAN_DANGER("The air bank is empty. The air will go stale: surface soon!"))

// Brings the hull air up to now, at most once per SUB_AIR_STEP.
/obj/structure/vehicleparts/axis/ship/submarine/proc/air_update()
	hull_ledger()
	var/elapsed = world.time - last_air_step
	if (elapsed < SUB_AIR_STEP)
		return
	last_air_step = world.time
	// A long gap (nobody aboard) never replays more than a minute.
	air_step(min(elapsed, 60 SECONDS) / 10)

/obj/structure/vehicleparts/axis/ship/submarine/proc/air_breathable()
	if (!submerged)
		return TRUE
	air_update()
	return hull_air.breathable()

/obj/structure/vehicleparts/axis/ship/submarine/proc/air_report()
	air_update()
	var/datum/habitat_ledger/L = hull_air
	var/state = L.breathable() ? "breathable" : "NOT BREATHABLE"
	return "Hull air: [state]. Oxygen [round(L.oxygen_kpa(), 0.1)] kPa, CO2 [round(L.co2_kpa(), 0.1)] kPa, pressure [round(L.pressure_kpa())] kPa. Air bank [round(100 * air_bank / SUB_AIR_BANK_MAX)]%[submerged ? "" : ", recharging"]."

// The submarine whose hull covers T, if any.
/proc/submarine_at(turf/T)
	if (!T)
		return null
	for (var/obj/structure/vehicleparts/frame/F in T)
		var/obj/structure/vehicleparts/axis/ship/submarine/B = F.axis
		if (istype(B) && !QDELETED(B))
			return B
	return null

// Spends bank air to blow the lock-out chamber dry. FALSE when the bank is short.
/obj/structure/vehicleparts/axis/ship/submarine/proc/blow_chamber()
	if (air_bank < SUB_AIR_LOCKIN_COST)
		return FALSE
	air_bank -= SUB_AIR_LOCKIN_COST
	return TRUE

// Oxygen from the bank for a diving bottle. Returns the oxygen given.
/obj/structure/vehicleparts/axis/ship/submarine/proc/bank_oxygen(oxygen)
	var/give = max(0, min(oxygen, air_bank * SUB_AIR_OXYGEN_SHARE))
	air_bank -= give / SUB_AIR_OXYGEN_SHARE
	return give

#undef SUB_AIR_TILES_PER_FRAME
#undef SUB_AIR_OXYGEN_KPA
#undef SUB_AIR_INERT_KPA
#undef SUB_AIR_BANK_RECHARGE_PER_SECOND
#undef SUB_AIR_VENT_CO2_KPA
#undef SUB_AIR_VENT_OXYGEN_KPA
#undef SUB_AIR_VENT_FRACTION_PER_SECOND
#undef SUB_AIR_STEP
#undef SUB_AIR_MAX_STEP_SECONDS
#undef SUB_AIR_OXYGEN_SHARE
