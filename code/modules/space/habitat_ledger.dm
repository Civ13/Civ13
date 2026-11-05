// ============================================================
// Habitat air ledger (space settlement phase 0, inactive)
// ------------------------------------------------------------
// One small datum per connected pressurised volume: oxygen, CO2 and an
// inert buffer gas as quantities in kPa-tiles, plus a temperature.
// Partial pressure = quantity / volume. Turfs inside a habitat will ask
// their module for air instead of carrying per-turf gas, so a whole base
// costs a handful of numbers to tick and to save.
//
// Rules from docs/space-settlement-roadmap.md:
// - nothing here stores world.time; saved state is plain scalars;
// - a ledger ticks only while the world has players: leaks and cooling run
//   whether or not anyone is inside, breathing only for the people inside,
//   and nothing runs while the world is empty, frozen or asleep;
// - a late or delayed tick cannot replay a backlog (seconds are capped).
//
// Submarine compartments use one ledger each (submarine/flooding_controller.dm);
// habitat modules arrive in phase 3.
// ============================================================

#define HABITAT_MAX_STEP_SECONDS 10
#define HABITAT_MAX_VOLUME 4096
#define HABITAT_MAX_PARTIAL_KPA 1000
// Gameplay rates, not physiology: one breather turns this much oxygen into
// CO2 per second (kPa-tiles), and each open breach vents this fraction of
// the remaining air per second.
#define HABITAT_BREATH_PER_SECOND 0.01
#define HABITAT_LEAK_FRACTION_PER_BREACH 0.02
#define HABITAT_HEAT_LOSS_PER_SECOND 0.001
// Breathable thresholds (kPa).
#define HABITAT_MIN_OXYGEN_KPA 16
#define HABITAT_MAX_CO2_KPA 2
#define HABITAT_MIN_PRESSURE_KPA 60
// Oxygen damage per breath step for someone breathing unbreathable air
// (outside without a suit, or in a module whose oxygen is gone). A conscious
// human recovers 5 per life tick, so this takes about a minute to knock
// someone out (decision D4), leaving time to drag them inside.
#define HABITAT_SUFFOCATE_OXYLOSS 7

/datum/habitat_ledger
	var/volume = 1
	var/oxygen = 0
	var/co2 = 0
	var/inert = 0
	var/temperature = 20

/datum/habitat_ledger/New(new_volume = 1)
	..()
	volume = habitat_clamp(new_volume, 1, HABITAT_MAX_VOLUME)

/proc/habitat_finite(value)
	return isnum(value) && value == value && value < 1e30 && value > -1e30

/proc/habitat_clamp(value, low, high)
	if (!habitat_finite(value))
		return low
	return min(high, max(low, value))

/datum/habitat_ledger/proc/oxygen_kpa()
	return oxygen / volume

/datum/habitat_ledger/proc/co2_kpa()
	return co2 / volume

/datum/habitat_ledger/proc/pressure_kpa()
	return (oxygen + co2 + inert) / volume

/datum/habitat_ledger/proc/breathable()
	return oxygen_kpa() >= HABITAT_MIN_OXYGEN_KPA && co2_kpa() <= HABITAT_MAX_CO2_KPA && pressure_kpa() >= HABITAT_MIN_PRESSURE_KPA

// Fill from a tank or generator. Amounts are kPa-tiles and never negative.
/datum/habitat_ledger/proc/add_gas(add_oxygen = 0, add_co2 = 0, add_inert = 0)
	oxygen += max(0, habitat_clamp(add_oxygen, 0, HABITAT_MAX_PARTIAL_KPA * volume))
	co2 += max(0, habitat_clamp(add_co2, 0, HABITAT_MAX_PARTIAL_KPA * volume))
	inert += max(0, habitat_clamp(add_inert, 0, HABITAT_MAX_PARTIAL_KPA * volume))
	clamp_contents()

// Remove CO2 (a scrubber). Returns the amount actually removed.
/datum/habitat_ledger/proc/scrub_co2(amount)
	var/taken = min(co2, max(0, habitat_clamp(amount, 0, co2)))
	co2 -= taken
	return taken

// A module joins or leaves: quantities stay, so pressure changes.
/datum/habitat_ledger/proc/resize(new_volume)
	volume = habitat_clamp(new_volume, 1, HABITAT_MAX_VOLUME)
	clamp_contents()

// An open hatch joins two volumes: both end at the shared partial pressures
// and volume-weighted temperature. Total gas is conserved.
/datum/habitat_ledger/proc/mix_with(datum/habitat_ledger/other)
	if (!istype(other) || other == src)
		return FALSE
	var/total = volume + other.volume
	var/o = oxygen + other.oxygen
	var/c = co2 + other.co2
	var/n = inert + other.inert
	var/t = (temperature * volume + other.temperature * other.volume) / total
	oxygen = o * volume / total
	co2 = c * volume / total
	inert = n * volume / total
	other.oxygen = o - oxygen
	other.co2 = c - co2
	other.inert = n - inert
	temperature = t
	other.temperature = t
	return TRUE

// One bounded step. occupants: living breathers inside (0 is fine: breaches
// still vent and the module still cools). breaches: open holes to the
// outside. ambient: outside temperature (C), or null for none. The caller
// decides whether the world is awake; returns FALSE only for no time.
/datum/habitat_ledger/proc/advance(seconds, occupants = 0, breaches = 0, ambient = null)
	var/dt = habitat_clamp(seconds, 0, HABITAT_MAX_STEP_SECONDS)
	if (dt <= 0)
		return FALSE
	var/breathers = habitat_clamp(occupants, 0, 10000)
	if (breathers > 0)
		var/breath = min(oxygen, HABITAT_BREATH_PER_SECOND * breathers * dt)
		oxygen -= breath
		co2 += breath
	var/holes = habitat_clamp(breaches, 0, 1000)
	if (holes > 0)
		var/keep = max(0, 1 - HABITAT_LEAK_FRACTION_PER_BREACH * holes * dt)
		oxygen *= keep
		co2 *= keep
		inert *= keep
	if (habitat_finite(ambient))
		var/loss = min(1, HABITAT_HEAT_LOSS_PER_SECOND * (1 + holes) * dt)
		temperature += (ambient - temperature) * loss
	clamp_contents()
	return TRUE

/datum/habitat_ledger/proc/clamp_contents()
	var/limit = HABITAT_MAX_PARTIAL_KPA * volume
	oxygen = habitat_clamp(oxygen, 0, limit)
	co2 = habitat_clamp(co2, 0, limit)
	inert = habitat_clamp(inert, 0, limit)
	temperature = habitat_clamp(temperature, -273, 1000)

// Saved form: plain scalars only, no world.time and no references.
/datum/habitat_ledger/proc/to_list()
	return list("volume" = volume, "oxygen" = oxygen, "co2" = co2, "inert" = inert, "temperature" = temperature)

// Rebuild from a saved list. Bad or missing values are refused, not guessed.
/datum/habitat_ledger/proc/from_list(list/saved)
	if (!islist(saved))
		return FALSE
	for (var/key in list("volume", "oxygen", "co2", "inert", "temperature"))
		if (!habitat_finite(saved[key]))
			return FALSE
	volume = habitat_clamp(saved["volume"], 1, HABITAT_MAX_VOLUME)
	oxygen = saved["oxygen"]
	co2 = saved["co2"]
	inert = saved["inert"]
	temperature = saved["temperature"]
	clamp_contents()
	return TRUE
