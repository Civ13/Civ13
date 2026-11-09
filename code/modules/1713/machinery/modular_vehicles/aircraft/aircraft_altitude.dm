// Aircraft altitude over hills.
//
// An airborne aircraft has an altitude on the terrain height scale of the
// ground below it (0-15, code/modules/1713/terrain_height.dm). The airframe
// itself rides on the open-air level above the ground, so nothing on the ground
// walks into it or is carried off by it, but up to AIRCRAFT_SURFACE_CEILING it
// flies among the ground's hills: a ridge, tree or wall that reaches its
// altitude is flown into. Only once it climbs past the top of that scale does
// it count as cruising, above the upper storeys of the level it rides on.
//
// Climb and Descend set a target altitude; the aircraft climbs or sinks toward
// it by AIRCRAFT_CLIMB_RATE levels for every tile it flies. Each step costs a
// handful of turf lookups under the footprint and a short look ahead.

// Levels gained or lost per tile flown.
#define AIRCRAFT_CLIMB_RATE 2
// Altitude above the ground when the wheels leave it, and the target it climbs to.
#define AIRCRAFT_LIFTOFF_CLEARANCE 2
#define AIRCRAFT_TAKEOFF_TARGET 6
// Tiles of ground ahead that the terrain warning watches.
#define AIRCRAFT_TERRAIN_LOOKAHEAD 5
#define AIRCRAFT_TERRAIN_WARNING_COOLDOWN (3 SECONDS)
// A rough landing needs ground within this many levels across the footprint.
#define AIRCRAFT_ROUGH_LANDING_SLOPE 1
// How far above the ground under it things reach: built walls and trees stand
// tall, a rock face is the hill itself, anything else dense is waist high.
#define AIRCRAFT_TALL_OBSTACLE 3
#define AIRCRAFT_LOW_OBSTACLE 1

/obj/structure/vehicleparts/axis/aircraft
	// Altitude on the ground's height scale; 0 on the ground.
	var/altitude = 0
	var/target_altitude = 0
	var/tmp/terrain_warned_at = 0
	var/tmp/ground_hold_warned = FALSE

/obj/structure/vehicleparts/axis/aircraft/persistence_runtime_var(key)
	return (key in list("altitude", "target_altitude", "terrain_warned_at", "ground_hold_warned")) || ..(key)

// How far above its terrain height the tallest thing on ground tile G reaches.
/proc/aircraft_obstacle_height(turf/G)
	if (!G)
		return 0
	if (G.density)
		return istype(G, /turf/wall/rockwall) ? AIRCRAFT_LOW_OBSTACLE : AIRCRAFT_TALL_OBSTACLE
	. = 0
	for (var/obj/O in G)
		if (!O.density)
			continue
		if (istype(O, /obj/structure/wild/tree) || istype(O, /obj/covers))
			return AIRCRAFT_TALL_OBSTACLE
		if (istype(O, /obj/structure))
			. = AIRCRAFT_LOW_OBSTACLE

// The highest point on ground tile G, on the altitude scale.
/proc/aircraft_ground_top(turf/G)
	if (!G)
		return 0
	return terrain_height_at(G) + aircraft_obstacle_height(G)

// What the aircraft would fly into at ground tile G: the hillside itself or
// the thing standing on it.
/proc/aircraft_ground_obstacle_name(turf/G)
	if (!G)
		return "the ground"
	if (G.density)
		return istype(G, /turf/wall/rockwall) ? "the hillside" : "\the [G]"
	for (var/obj/O in G)
		if (O.density && (istype(O, /obj/structure) || istype(O, /obj/covers)))
			return "\the [O]"
	return "the hillside"

// Ground tiles straight below the frames.
/obj/structure/vehicleparts/axis/aircraft/proc/ground_under_footprint()
	. = list()
	var/ground = ground_z()
	if (!ground)
		return
	for (var/obj/structure/vehicleparts/frame/F in frames())
		var/turf/G = locate(F.x, F.y, ground)
		if (G)
			. += G

// The highest terrain under the footprint: what the wheels would touch.
/obj/structure/vehicleparts/axis/aircraft/proc/ground_level()
	. = 0
	for (var/turf/G in ground_under_footprint())
		. = max(., terrain_height_at(G))

// Height above the ground under the airframe.
/obj/structure/vehicleparts/axis/aircraft/proc/clearance()
	return altitude - ground_level()

// Where the altitude goes on the next tile flown.
/obj/structure/vehicleparts/axis/aircraft/proc/next_altitude(ground = null)
	if (isnull(ground))
		ground = ground_level()
	var/want = max(target_altitude, ground + 1)
	if (altitude < want)
		return min(want, altitude + AIRCRAFT_CLIMB_RATE)
	if (altitude > want)
		return max(want, altitude - AIRCRAFT_CLIMB_RATE)
	return altitude

// Called on leaving the ground: lift-off just above the ground, climbing on.
/obj/structure/vehicleparts/axis/aircraft/proc/start_altitude()
	var/ground = ground_level()
	altitude = ground + AIRCRAFT_LIFTOFF_CLEARANCE
	target_altitude = max(altitude, ground + AIRCRAFT_TAKEOFF_TARGET)
	ground_hold_warned = FALSE

// In low flight, the first ground tile ahead of the frames (one step in m_dir)
// that reaches the given altitude, or null.
/obj/structure/vehicleparts/axis/aircraft/proc/ground_collision_ahead(m_dir, at_altitude)
	var/ground = ground_z()
	if (!ground)
		return null
	for (var/obj/structure/vehicleparts/frame/F in frames())
		var/turf/T = get_step(F.loc, m_dir)
		if (!T)
			continue
		var/turf/G = locate(T.x, T.y, ground)
		if (G && aircraft_ground_top(G) >= at_altitude)
			return G
	return null

// The highest ground top within AIRCRAFT_TERRAIN_LOOKAHEAD tiles ahead.
/obj/structure/vehicleparts/axis/aircraft/proc/highest_ground_ahead(m_dir)
	. = 0
	var/ground = ground_z()
	if (!ground)
		return
	var/list/seen = list()
	for (var/obj/structure/vehicleparts/frame/F in frames())
		var/turf/G = locate(F.x, F.y, ground)
		for (var/i = 1, i <= AIRCRAFT_TERRAIN_LOOKAHEAD && G, i++)
			G = get_step(G, m_dir)
			if (G)
				seen |= G
	for (var/turf/G in seen)
		. = max(., aircraft_ground_top(G))

// The vertical part of a step in the air, after the aircraft has moved.
/obj/structure/vehicleparts/axis/aircraft/proc/update_altitude()
	if (!airborne())
		return
	var/ground = ground_level()
	altitude = next_altitude(ground)
	if (flight_state == AIRCRAFT_LOW && altitude > AIRCRAFT_SURFACE_CEILING)
		set_flight_state(AIRCRAFT_CRUISE)
		pilot_message(SPAN_NOTICE("You climb above the hilltops to cruising height, over the rooftops."))
	else if (flight_state == AIRCRAFT_CRUISE && altitude <= AIRCRAFT_SURFACE_CEILING)
		var/hit = low_flight_blocked()
		if (hit)
			altitude = AIRCRAFT_SURFACE_CEILING + 1
			target_altitude = max(target_altitude, altitude)
			pilot_message(SPAN_WARNING("You can't descend here, [hit] is right below you."))
		else
			set_flight_state(AIRCRAFT_LOW)
			pilot_message(SPAN_NOTICE("You descend below the hilltops into low flight."))
	if (flight_state == AIRCRAFT_LOW)
		if (target_altitude <= ground + 1 && altitude <= ground + 1)
			if (!ground_hold_warned)
				ground_hold_warned = TRUE
				pilot_message(SPAN_NOTICE("You skim just above the ground. Descend again to land."))
		else
			ground_hold_warned = FALSE
		terrain_warning()

// Warns the pilot about ground ahead that reaches the aircraft's altitude.
/obj/structure/vehicleparts/axis/aircraft/proc/terrain_warning()
	if (terrain_warned_at && world.time < terrain_warned_at + AIRCRAFT_TERRAIN_WARNING_COOLDOWN)
		return FALSE
	var/top = highest_ground_ahead(reverse ? OPPOSITE_DIR(dir) : dir)
	if (top < altitude)
		return FALSE
	terrain_warned_at = world.time
	pilot_message(SPAN_DANGER("Terrain ahead at height [top]! Climb above it (you are at [altitude])."))
	return TRUE

// Why the aircraft can't sink from cruise into low flight here: an upper
// storey on its own level, or ground that reaches the top of the scale.
/obj/structure/vehicleparts/axis/aircraft/proc/low_flight_blocked()
	var/hit = clear_at_level(flight_z())
	if (hit)
		return hit
	for (var/turf/G in ground_under_footprint())
		if (aircraft_ground_top(G) >= AIRCRAFT_SURFACE_CEILING)
			return aircraft_ground_obstacle_name(G)
	return null

// Whether the ground across the footprint is level enough to set down on.
/obj/structure/vehicleparts/axis/aircraft/proc/footprint_level(target_z)
	var/low = null
	var/high = null
	for (var/obj/structure/vehicleparts/frame/F in frames())
		var/h = terrain_height_at(locate(F.x, F.y, target_z))
		low = isnull(low) ? h : min(low, h)
		high = isnull(high) ? h : max(high, h)
	return isnull(low) || high - low <= AIRCRAFT_ROUGH_LANDING_SLOPE

// The steepest step between neighbouring tiles under the footprint at
// target_z, in levels (built ground counts as level, terrain_step_levels).
/obj/structure/vehicleparts/axis/aircraft/proc/footprint_grade(target_z)
	. = 0
	var/list/tiles = list()
	for (var/obj/structure/vehicleparts/frame/F in frames())
		var/turf/T = locate(F.x, F.y, target_z)
		if (T)
			tiles += T
	for (var/turf/T in tiles)
		for (var/d in list(NORTH, EAST))
			var/turf/N = get_step(T, d)
			if (N in tiles)
				. = max(., abs(terrain_step_levels(T, N)))

#undef AIRCRAFT_LOW_OBSTACLE
#undef AIRCRAFT_TALL_OBSTACLE
#undef AIRCRAFT_ROUGH_LANDING_SLOPE
#undef AIRCRAFT_TERRAIN_WARNING_COOLDOWN
#undef AIRCRAFT_TERRAIN_LOOKAHEAD
#undef AIRCRAFT_TAKEOFF_TARGET
#undef AIRCRAFT_LIFTOFF_CLEARANCE
#undef AIRCRAFT_CLIMB_RATE
