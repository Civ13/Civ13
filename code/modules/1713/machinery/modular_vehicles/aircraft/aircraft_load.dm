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
// - cruise pace: a heavy plane cruises one tick slower per tile.
// Past AIRCRAFT_LOAD_LIMIT the wheels never leave the ground.
//
// Step pace (aircraft_step_delay()): on the ground a plane taxis at the car
// pace of its gear. In low flight it holds at least two ticks a tile, so a
// landing approach stays controllable; at cruise it flies one tick quicker
// than its gear's delay, down to one tick a tile, about three times a car.
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
#define AIRCRAFT_LOW_FLIGHT_MIN_DELAY 2

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

// Ticks per tile at the current gear and flight state.
/obj/structure/vehicleparts/axis/aircraft/proc/aircraft_step_delay()
	if (!airborne())
		return vehicle_m_delay + 1
	if (flight_state != AIRCRAFT_CRUISE)
		return max(AIRCRAFT_LOW_FLIGHT_MIN_DELAY, vehicle_m_delay)
	. = max(1, vehicle_m_delay - 1)
	if (load_scale() > AIRCRAFT_HEAVY_LOAD)
		.++

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

#undef AIRCRAFT_LOW_FLIGHT_MIN_DELAY
#undef AIRFRAME_STEEL_WEIGHT
#undef AIRCRAFT_LOAD_RECHECK
#undef AIRCRAFT_LIGHT_LOAD
#undef AIRCRAFT_HEAVY_LOAD
#undef AIRCRAFT_LOAD_LIMIT
#undef AIRCRAFT_LOAD_MAX
#undef AIRCRAFT_LOAD_MIN
