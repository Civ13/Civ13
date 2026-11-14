// Aircraft weight: what an aircraft carries sets how it flies.
// ------------------------------------------------------------
// The aircraft is weighed like a land vehicle (vehicle_load_weights() in
// vehicle_load.dm): its fitted parts, walls and cargo against the same body
// in steel with a normal load (one rider per seat and a little payload per
// frame). Each frame's airframe adds its own weight against steel's, so a
// lighter material (wood and cloth, aluminium) makes a lighter plane.
//
// The ratio, held between AIRCRAFT_LOAD_MIN and AIRCRAFT_LOAD_MAX, sets:
// - the takeoff roll (takeoff_distance()), scaled from the model's own roll;
// - the climb rate per tile flown (aircraft_climb_rate()): heavy planes climb
//   one level a tile, light ones three, the rest two;
// - flight fuel (burn_flight_fuel()), in proportion;
// - cruise pace: a heavy plane's cruise interval stretches with its load.
// Past AIRCRAFT_LOAD_LIMIT the wheels never leave the ground.
//
// Step pace (aircraft_step_delay(), true tenths of a second per tile): on the
// ground a plane taxis at the car row of the speed ladder (vehicle_speeds.dm,
// 1.6 at full throttle). In the air each gear flies faster than the same gear
// on the road: three quarters of the time in low flight, never under 1.2 so a
// landing approach stays controllable, and half the time at cruise, 0.8 at
// full throttle (the ladder's propeller target, twice a car). A heavy load
// stretches the cruise interval in proportion.
// Today's planes with a normal load take off, climb and burn as before.
// ============================================================

#define AIRCRAFT_LOAD_MIN 0.6
#define AIRCRAFT_LOAD_MAX 1.6
#define AIRCRAFT_LOAD_LIMIT 1.8
#define AIRCRAFT_HEAVY_LOAD 1.25
#define AIRCRAFT_LIGHT_LOAD 0.85
#define AIRCRAFT_LOAD_RECHECK 20
// Weight of one steel airframe section (vehicle_load_weights() counts 10).
#define AIRFRAME_STEEL_WEIGHT 10
// Flight pace against the same gear on the ground, and the low-flight floor.
#define AIRCRAFT_LOW_FLIGHT_PACE 0.75
#define AIRCRAFT_CRUISE_PACE 0.5
#define AIRCRAFT_LOW_FLIGHT_MIN_INTERVAL 1.2
// The server tick (config TICKLAG): intervals land on whole ticks.
#define AIRCRAFT_TICK 0.4
// VEHICLE_STEP_OVERHEAD (vehicle_speeds.dm, compiled after this file).
#define AIRCRAFT_STEP_OVERHEAD 1

// How heavy this frame's own structure is. Steel is AIRFRAME_STEEL_WEIGHT;
// hull materials override it (the aluminium thread's material hook).
/obj/structure/vehicleparts/frame/proc/airframe_weight()
	return AIRFRAME_STEEL_WEIGHT

/obj/structure/vehicleparts/axis/aircraft
	// Unclamped load ratio from the last weighing; 1 is a normal load in steel.
	var/tmp/flight_load = 1
	var/tmp/flight_load_checked_at = -1000

/obj/structure/vehicleparts/axis/aircraft/persistence_runtime_var(key)
	return key == "flight_load" || key == "flight_load_checked_at" || ..(key)

// The unclamped load ratio, reweighed when stale or when force is set.
/obj/structure/vehicleparts/axis/aircraft/proc/aircraft_load(force = FALSE)
	if (!force && world.time < flight_load_checked_at + AIRCRAFT_LOAD_RECHECK)
		return flight_load
	flight_load_checked_at = world.time
	var/list/W = vehicle_load_weights()
	var/load = W[1]
	for (var/obj/structure/vehicleparts/frame/F in components)
		if (isturf(F.loc))
			load += F.airframe_weight() - AIRFRAME_STEEL_WEIGHT
	flight_load = W[2] > 0 ? max(0.1, load / W[2]) : 1
	return flight_load

// The load ratio as it acts on flight.
/obj/structure/vehicleparts/axis/aircraft/proc/load_scale(force = FALSE)
	return clamp(aircraft_load(force), AIRCRAFT_LOAD_MIN, AIRCRAFT_LOAD_MAX)

/obj/structure/vehicleparts/axis/aircraft/proc/too_heavy_to_fly(force = FALSE)
	return aircraft_load(force) > AIRCRAFT_LOAD_LIMIT

// Full-throttle tiles needed to lift off from where the aircraft is now:
// the model's roll for a normal load, longer when loaded down.
/obj/structure/vehicleparts/axis/aircraft/proc/takeoff_distance(runway = -1)
	if (runway == -1)
		runway = on_runway()
	var/base = runway ? takeoff_roll : rough_takeoff_roll
	return max(3, round(base * load_scale(), 1))

// Altitude levels gained per tile flown.
/obj/structure/vehicleparts/axis/aircraft/proc/aircraft_climb_rate()
	var/L = load_scale()
	if (L >= AIRCRAFT_HEAVY_LOAD)
		return 1
	if (L <= AIRCRAFT_LIGHT_LOAD)
		return 3
	return 2

// Tenths of a second per tile at the current gear and flight state. The
// aircraft loop schedules this interval directly, with no added overhead.
/obj/structure/vehicleparts/axis/aircraft/proc/aircraft_step_delay()
	var/interval = vehicle_m_delay + AIRCRAFT_STEP_OVERHEAD
	if (!airborne())
		return interval
	if (flight_state != AIRCRAFT_CRUISE)
		return max(AIRCRAFT_LOW_FLIGHT_MIN_INTERVAL, round(interval * AIRCRAFT_LOW_FLIGHT_PACE, AIRCRAFT_TICK))
	return max(AIRCRAFT_TICK, round(interval * AIRCRAFT_CRUISE_PACE * max(1, load_scale()), AIRCRAFT_TICK))

/obj/structure/vehicleparts/axis/aircraft/glide_step_time()
	return aircraft_step_delay()

// Plain words on how the load affects flying, for examine.
/obj/structure/vehicleparts/axis/aircraft/load_description()
	var/L = aircraft_load(TRUE)
	if (L > AIRCRAFT_LOAD_LIMIT)
		return "It is far too heavy to leave the ground. Unload it before taking off."
	if (L >= AIRCRAFT_HEAVY_LOAD)
		return "It is heavily loaded: it needs a long takeoff roll, climbs slowly and burns more fuel."
	if (L > 1.02)
		return "It is loaded down: it needs a longer takeoff roll and burns a little more fuel."
	if (L <= AIRCRAFT_LIGHT_LOAD)
		return "It is light for its engine: it lifts off soon and climbs fast."
	if (L < 0.98)
		return "It is light and lifts off a little sooner than usual."
	return null

#undef AIRCRAFT_STEP_OVERHEAD
#undef AIRCRAFT_TICK
#undef AIRCRAFT_LOW_FLIGHT_MIN_INTERVAL
#undef AIRCRAFT_CRUISE_PACE
#undef AIRCRAFT_LOW_FLIGHT_PACE
#undef AIRFRAME_STEEL_WEIGHT
#undef AIRCRAFT_LOAD_RECHECK
#undef AIRCRAFT_LIGHT_LOAD
#undef AIRCRAFT_HEAVY_LOAD
#undef AIRCRAFT_LOAD_LIMIT
#undef AIRCRAFT_LOAD_MAX
#undef AIRCRAFT_LOAD_MIN
