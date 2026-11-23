// Heavy moving storms use local wind as the direction the sea is coming
// from. Sea state is sampled once per awake hull ledger step, never per hop.
// Use the existing bilge: a storm does not create holes or bypass pumps.

#define HULL_STORM_STEP_MAX 30
#define HULL_STORM_ROLL_SECONDS 90
#define HULL_STORM_WATER_SHARE 0.08
#define HULL_STORM_HELM_AGE (2 MINUTES)

/datum/hull_ledger
	// Transient exposure, not hull damage. Restarting never advances the clock.
	var/tmp/storm_beam_seconds = 0
	var/tmp/storm_warned = FALSE
	var/tmp/datum/weakref/storm_pilot
	var/tmp/storm_pilot_until = 0

// Relative bearing: bow or stern seas (0), quartering (0.5), beam seas (1).
/proc/hull_storm_beam(heading, from_dir)
	if (heading != NORTH && heading != EAST && heading != SOUTH && heading != WEST)
		return 0
	if (from_dir == turn(heading, 90) || from_dir == turn(heading, -90))
		return 1
	if (from_dir == NORTHEAST || from_dir == NORTHWEST || from_dir == SOUTHEAST || from_dir == SOUTHWEST)
		return 0.5
	return 0

/datum/hull_ledger/proc/storm_beam()
	if (!weather_storm_count || !craft || sinking || grounded || depth_disabled || tiles < 1)
		return 0
	var/datum/craft_body/built/B = craft.body
	if (!istype(B) || istype(B, /datum/craft_body/built/air) || !B.placed())
		return 0
	// Sample at the helm, on a hull tile. The box origin can be outside
	// the hull on a nonrectangular ship.
	var/obj/structure/hull_tiller/T = helm()
	// An abstract voyage must not take damage from the weather beside its
	// mooring. The voyage and crossing own those ships until they return.
	if (!T || T.voyage || T.crossing_hold)
		return 0
	var/turf/at = get_turf(T)
	// The deck covering the turf is our own. Do not treat planks as shelter.
	if (!is_open_sea(at) || weather_storm_strength(at.x, at.y) < WEATHER_BAND_HEAVY)
		return 0
	return hull_storm_beam(B.heading(), weather_wind_dir_at(at))

/datum/hull_ledger/proc/storm_full_canvas()
	if (!under_way())
		return FALSE
	for (var/datum/craft_drive/fitted/sail/D in craft.drives)
		var/obj/structure/vehicleparts/movement/sail/S = D.source
		if (istype(S) && !QDELETED(S) && !S.torn && S.canvas == initial(S.canvas) && D.ready())
			return TRUE
	return FALSE

// A built small craft has little reserve; a larger one has to be dangerously
// laden, already awash, or carrying too much canvas for her ballast.
/datum/hull_ledger/proc/storm_unstable()
	return hull_class() == HULL_CLASS_SMALL || load > burden() * 2 || depth() >= HULL_DEPTH_AWASH || (crank() && storm_full_canvas())

/datum/hull_ledger/proc/step_storm(seconds)
	var/beam = storm_beam()
	if (!beam)
		storm_warned = FALSE
		storm_beam_seconds = 0
		return FALSE
	var/elapsed = clamp(seconds, 0, HULL_STORM_STEP_MAX)
	if (!elapsed)
		return FALSE
	var/unstable = beam == 1 && storm_unstable()
	if (!unstable)
		storm_beam_seconds = 0
	if (beam == 1 && !storm_warned)
		storm_warned = TRUE
		craft.crew_message(SPAN_WARNING("Heavy seas are striking the [craft.name] broadside. Turn her bow into the waves. Reef or furl her sails and keep ahead of the incoming water."))
	if (beam < 1)
		storm_warned = FALSE
	// Flooding alone uses the normal awash cap. Capsizing is the separate
	// result of continuing to take heavy seas broadside while unstable.
	var/water_share = hull_class() == HULL_CLASS_SMALL ? HULL_STORM_WATER_SHARE * 2 : HULL_STORM_WATER_SHARE
	add_water(capacity() * water_share * beam * elapsed / 60)
	if (!unstable)
		return FALSE
	storm_beam_seconds = min(HULL_STORM_ROLL_SECONDS, storm_beam_seconds + elapsed)
	if (storm_beam_seconds == elapsed)
		craft.crew_message(SPAN_DANGER("The [craft.name] heels dangerously in the sea. Turn her out of the broadside or she may roll."))
	if (storm_beam_seconds < HULL_STORM_ROLL_SECONDS)
		return FALSE
	return storm_capsize()

// A recent accepted helm command, not proximity alone, identifies a pilot.
// Someone passively watching a course without any recent command is not
// observable as the pilot. Never keep a disconnected body alive for this.
/datum/hull_ledger/proc/note_storm_pilot(mob/living/human/H)
	storm_pilot = null
	storm_pilot_until = 0
	if (!H?.client || H.incapacitated() || !under_way())
		return
	storm_pilot = WEAKREF(H)
	storm_pilot_until = world.time + HULL_STORM_HELM_AGE

// A save decision samples live heading/sail trim, not the last storm tick.
// Look only near a conscious, connected player physically on their helm's
// deck; abandoned ships, passengers far from the helm, and voyages do not
// defer a save. Never walk cargo or all hulls for this test.
/proc/any_crew_at_capsize_risk()
	if (!weather_storm_count)
		return FALSE
	for (var/client/C in clients)
		var/mob/living/human/H = C.mob
		if (!istype(H) || !watch_fit(H) || H.incapacitated() || !isturf(H.loc))
			continue
		var/turf/at = H.loc
		for (var/obj/structure/hull_tiller/T in range(1, at))
			var/datum/hull_ledger/L = T.craft?.ledger
			if (!L || !L.under_way() || !L.deck_holds(at))
				continue
			if (world.time >= L.storm_pilot_until || L.storm_pilot?.resolve() != H)
				continue
			if (L.storm_beam() == 1 && L.storm_unstable())
				return TRUE
	return FALSE

#undef HULL_STORM_STEP_MAX
#undef HULL_STORM_ROLL_SECONDS
#undef HULL_STORM_WATER_SHARE
#undef HULL_STORM_HELM_AGE
