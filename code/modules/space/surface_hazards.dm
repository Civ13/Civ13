// ============================================================
// Surface hazards (space settlement phase 4)
// ------------------------------------------------------------
// The barren surface has four hazards, rolled once a minute while someone
// is playing and a habitat module or landed lander is ticking there:
//
// - Dust storms blur the view of anyone on open ground and choke solar
//   arrays in the barren area. The airless Moon never rolls them.
// - Cold snaps drive the surface temperature down, so modules, landers and
//   unheated suits lose heat faster.
// - Solar flares irradiate anyone on open ground; a pressure suit blocks
//   part of the dose and a module or lander cabin blocks all of it.
// - Meteorites now and then punch a hole in a barren-area module's hull,
//   which is patched like any other breach.
//
// Event timers are plain globals counted down in seconds; they are not
// saved, so a restart ends any event in progress. Nothing scans turfs.
// ============================================================

#define BARREN_HAZARD_TICK_SECONDS 60
// Chances per minute of play (percent).
#define BARREN_DUST_CHANCE 1
#define BARREN_COLD_CHANCE 0.5
#define BARREN_FLARE_CHANCE 0.4
#define BARREN_METEOR_CHANCE 0.3
#define BARREN_DUST_SECONDS 600
#define BARREN_COLD_SECONDS 900
#define BARREN_FLARE_SECONDS 240
// Radiation per life tick on open ground during a flare, before armour.
#define BARREN_FLARE_DOSE 1
#define BARREN_DUST_BLUR 2
#define BARREN_DUST_SOLAR_FACTOR 0.2
#define BARREN_METEOR_BRUTE 15

var/global/barren_dust_seconds = 0
var/global/barren_cold_seconds = 0
var/global/barren_flare_seconds = 0
// Last pulse, this session only (never saved).
var/global/barren_hazard_last_pulse = -1

// Called by every ticking module and lander; only the first call each
// minute does anything.
/proc/barren_hazards_pulse()
	if (barren_hazard_last_pulse >= 0 && world.time < barren_hazard_last_pulse + BARREN_HAZARD_TICK_SECONDS * 10)
		return FALSE
	var/first = barren_hazard_last_pulse < 0
	barren_hazard_last_pulse = world.time
	if (first)
		return FALSE
	barren_hazards_step(BARREN_HAZARD_TICK_SECONDS, TRUE)
	return TRUE

// Counts events down and, when roll is TRUE, may start new ones.
/proc/barren_hazards_step(seconds, roll = TRUE)
	seconds = max(0, seconds)
	// Station orbits sink with the same clock (orbit_upkeep.dm).
	orbit_upkeep_step(seconds, roll)
	if (barren_dust_seconds > 0)
		barren_dust_seconds = max(0, barren_dust_seconds - seconds)
		if (!barren_dust_seconds)
			barren_hazard_announce(SPAN_NOTICE("The dust storm blows itself out."))
	if (barren_cold_seconds > 0)
		barren_cold_seconds = max(0, barren_cold_seconds - seconds)
		if (!barren_cold_seconds)
			barren_hazard_announce(SPAN_NOTICE("The bitter cold eases."))
	if (barren_flare_seconds > 0)
		barren_flare_seconds = max(0, barren_flare_seconds - seconds)
		if (!barren_flare_seconds)
			barren_hazard_announce(SPAN_NOTICE("The solar flare has passed. It is safe to go outside."))
	if (!roll)
		return
	if (!barren_dust_seconds && space_world_has_dust_storms() && prob(BARREN_DUST_CHANCE))
		barren_hazard_start("dust")
	if (!barren_cold_seconds && !orbit_world() && prob(BARREN_COLD_CHANCE))
		barren_hazard_start("cold")
	if (!barren_flare_seconds && prob(BARREN_FLARE_CHANCE))
		barren_hazard_start("flare")
	if (prob(BARREN_METEOR_CHANCE))
		barren_meteor_strike()

/proc/barren_hazard_start(kind)
	switch (kind)
		if ("dust")
			barren_dust_seconds = BARREN_DUST_SECONDS
			barren_hazard_announce(SPAN_WARNING("A dust storm rolls in across the plain. Solar arrays will barely charge until it passes."))
		if ("cold")
			barren_cold_seconds = BARREN_COLD_SECONDS
			barren_hazard_announce(SPAN_WARNING("A cold snap sets in. Keep heaters running."))
		if ("flare")
			barren_flare_seconds = BARREN_FLARE_SECONDS
			barren_hazard_announce(SPAN_DANGER("Solar flare! Radiation is rising. Get inside a module or lander."))
		else
			return FALSE
	return TRUE

// Tells everyone on barren ground, in a module or in a lander.
/proc/barren_hazard_announce(message)
	for (var/client/C in clients)
		var/mob/living/human/H = C.mob
		if (!istype(H))
			continue
		var/turf/T = get_turf(H)
		if (T && !isnull(T.outside_ambient_c()))
			to_chat(H, message)

// What a person on open ground suffers from the hazards in progress.
/mob/living/human/proc/barren_hazard_exposure(turf/T)
	if (barren_flare_seconds > 0)
		rad_act(BARREN_FLARE_DOSE)
	if (barren_dust_seconds > 0)
		eye_blurry = max(eye_blurry, BARREN_DUST_BLUR)

// Solar output multiplier for an area (modern_generation.dm).
/proc/barren_solar_factor(area/A)
	if (barren_dust_seconds > 0 && istype(A, /area/caribbean/nomads/barren))
		return BARREN_DUST_SOLAR_FACTOR
	return 1

// Holes the hull of a random module in the barren area. Returns the turf
// it hit, or null.
/proc/barren_meteor_strike(obj/structure/habitat_core/target = null)
	if (!target)
		var/list/candidates = list()
		for (var/obj/structure/habitat_core/C in habitat_cores)
			if (!QDELETED(C) && (istype(get_area(C), /area/caribbean/nomads/barren) || istype(get_area(C), /area/caribbean/nomads/orbit)))
				candidates += C
		if (!candidates.len)
			return null
		target = pick(candidates)
	if (habitat_strike_blocked(target))
		return null
	var/list/hull = list()
	for (var/turf/T in target.ring())
		if (istype(T, /turf/wall/habitat_shell))
			hull += T
	if (!hull.len)
		return null
	var/turf/hit = pick(hull)
	var/in_orbit = orbit_world()
	hit.ChangeTurf(in_orbit ? /turf/floor/space/orbit : /turf/floor/dirt/dust/regolith/crater, FALSE, FALSE)
	for (var/mob/living/M in range(1, hit))
		M.apply_damage(BARREN_METEOR_BRUTE, BRUTE)
	hit.visible_message(SPAN_DANGER(in_orbit ? "Debris punches through the hull!" : "A meteorite punches through the hull!"))
	return hit
