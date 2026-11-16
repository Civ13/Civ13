// Migrating shoals at sea (docs/fishing-grounds.md, "Shoals").
//
// A few great shoals travel the salt water of every level. Each keeps to its
// own circuit, a belt round the middle of the map, and goes round it a whole
// number of times a day, so a shoal is in the same water at the same hour
// every day and a crew can learn its timetable.
//
// A shoal is not an object and holds no state: where it is follows from the
// clock (fish_shoal_position), so nothing ticks, nothing is saved and a hull
// cannot carry one off. Water under a shoal fishes better, gives mostly
// herring, shows gulls and leaping fish, and half of what is landed came with
// the shoal and leaves the ground's own stock alone. Even a fished-out
// stretch gives fish while a shoal is passing.

// Tiles from the middle of a shoal that fish as part of it.
#define FISH_SHOAL_RADIUS 12
#define FISH_SHOAL_FACTOR 1.5
// Tiles a minute along the circuit, before rounding to whole laps a day.
#define FISH_SHOAL_SPEED 3
// One shoal for this many tiles of level, between one and FISH_SHOAL_MAX.
#define FISH_SHOAL_AREA 90000
#define FISH_SHOAL_MAX 8
// How far a sonar set hears a shoal.
#define FISH_SHOAL_SONAR 96
#define FISH_SHOAL_DAY 864000

// A fixed time of day for the shoals instead of the clock, for tests.
var/global/fish_shoal_clock = null

/proc/fish_shoal_count()
	return max(1, min(FISH_SHOAL_MAX, round(world.maxx * world.maxy / FISH_SHOAL_AREA)))

// Where shoal number index of level z is at time of day t (deciseconds since
// midnight): list(x, y). The circuits are ellipses about the middle of the
// map, each shoal's a different size, neighbours going round opposite ways.
/proc/fish_shoal_position(z, index, t)
	var/reach = 0.45 - 0.08 * (index % 3)
	var/rx = world.maxx * reach
	var/ry = world.maxy * reach
	// Whole laps a day, so the circuit joins up at midnight.
	var/laps = max(1, round(1440 * FISH_SHOAL_SPEED / (3.1416 * (rx + ry))))
	var/angle = 360 * laps * (t / FISH_SHOAL_DAY) + (index * 137 + z * 71) % 360
	if (index % 2)
		angle = -angle
	return list(round(world.maxx / 2 + rx * cos(angle)), round(world.maxy / 2 + ry * sin(angle)))

// The nearest shoal to T on its level: list(x, y, tiles away).
/proc/fish_shoal_nearest(turf/T, t)
	if (isnull(t))
		t = isnull(fish_shoal_clock) ? world.timeofday : fish_shoal_clock
	var/best = null
	for (var/index = 1 to fish_shoal_count())
		var/list/at = fish_shoal_position(T.z, index, t)
		var/away = max(abs(at[1] - T.x), abs(at[2] - T.y))
		if (!best || away < best[3])
			best = list(at[1], at[2], away)
	return best

// TRUE while a shoal is passing through the salt water at T.
/proc/fish_shoal_at(turf/T, t)
	if (!T || fish_water_kind(T) != FISH_WATER_SALT)
		return FALSE
	var/list/near = fish_shoal_nearest(T, t)
	return near[3] <= FISH_SHOAL_RADIUS

// What a passing shoal does to a tool's chance.
/proc/fish_shoal_factor(turf/T, t)
	return fish_shoal_at(T, t) ? FISH_SHOAL_FACTOR : 1

// What a sonar set makes of the shoals: a line, or null when none is in range.
/proc/fish_shoal_finder_line(turf/T, t)
	if (!T || fish_water_kind(T) != FISH_WATER_SALT)
		return null
	var/list/near = fish_shoal_nearest(T, t)
	if (near[3] <= FISH_SHOAL_RADIUS)
		return "A great shoal is passing overhead."
	if (near[3] > FISH_SHOAL_SONAR)
		return null
	var/dx = near[1] - T.x
	var/dy = near[2] - T.y
	var/bearing = 0
	if (abs(dx) * 2 >= abs(dy))
		bearing |= dx > 0 ? EAST : WEST
	if (abs(dy) * 2 >= abs(dx))
		bearing |= dy > 0 ? NORTH : SOUTH
	return "A great shoal bears [dir2text(bearing)], about [max(10, round(near[3], 10))] tiles off."

#undef FISH_SHOAL_RADIUS
#undef FISH_SHOAL_FACTOR
#undef FISH_SHOAL_SPEED
#undef FISH_SHOAL_AREA
#undef FISH_SHOAL_MAX
#undef FISH_SHOAL_SONAR
#undef FISH_SHOAL_DAY
