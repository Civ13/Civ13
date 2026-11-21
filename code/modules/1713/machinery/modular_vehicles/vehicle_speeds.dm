// The speed ladder: how long one tile takes in each gear, by vehicle class.
// ------------------------------------------------------------
// One table sets the pace of every vehicle class that names a speed_class,
// so classes stay in a sensible order against each other and against people
// on foot (docs/vehicle-speeds.md). The figures are true intervals: tenths
// of a second from one tile to the next, lower is faster. The frame vehicle
// loop waits one tick more than the delay it is given, so the gear delays
// handed to it are the interval less VEHICLE_STEP_OVERHEAD.
//
// For scale: a person runs a tile in about 1.9, a bicycle rides one in 1.8
// and a carriage canters one in 2.2.
// ============================================================

#define VEHICLE_STEP_OVERHEAD 1   // What the movement loops add to a delay.
#define VEHICLE_MIN_DELAY 0.2     // Fastest delay a land vehicle may be given.

var/global/list/vehicle_speed_ladder = vehicle_speed_ladder_table()
/proc/vehicle_speed_ladder_table()
	return list(
	// Road vehicles.
	"car" = list(9, 6, 4, 2.4, 1.6),
	// Tracked vehicles, by real road speed.
	"tracked_slow" = list(13, 9, 7),                 // about 25-37 km/h: KV-1, IS-2
	"tracked_medium" = list(13, 9, 7, 6),            // about 38-48 km/h: Sherman, Panzer IV
	"tracked_quick" = list(11, 8, 6, 5),             // about 50-60 km/h: T-34, T-72
	"tracked_fast" = list(10, 7, 5, 4),              // about 65-72 km/h: M41, M113, Abrams
	"tracked_sprint" = list(13, 9, 7, 6, 5, 4, 3),   // BT-7 on its Christie suspension
)

/obj/structure/vehicleparts/axis
	// A row of vehicle_speed_ladder; null keeps the type's own speedlist.
	var/speed_class = null

/obj/structure/vehicleparts/axis/New()
	..()
	apply_speed_class()

// Takes the gears of speed_class from the ladder. Safe to call again: a
// vehicle restored from an older save picks up the current table.
/obj/structure/vehicleparts/axis/proc/apply_speed_class()
	if (!speed_class)
		return FALSE
	var/list/intervals = vehicle_speed_ladder[speed_class]
	if (!islist(intervals) || !intervals.len)
		return FALSE
	var/alist/gears = alist()
	for (var/i in 1 to intervals.len)
		gears[i] = max(VEHICLE_MIN_DELAY, intervals[i] - VEHICLE_STEP_OVERHEAD)
	speedlist = gears
	speeds = intervals.len
	return TRUE

// The time one tile takes in gear, before load (0 when it has no such gear).
/obj/structure/vehicleparts/axis/proc/gear_interval(gear)
	var/delay = gear_delay(gear)
	return delay ? delay + VEHICLE_STEP_OVERHEAD : 0

// The delay to hand the movement loop for a gear delay under a load factor.
// The load scales the whole time a tile takes, not only the listed delay,
// so a hull 30% lighter really is 30% quicker.
/obj/structure/vehicleparts/axis/proc/loaded_step_delay(delay, factor)
	return max(VEHICLE_MIN_DELAY, (delay + VEHICLE_STEP_OVERHEAD) * factor - VEHICLE_STEP_OVERHEAD)
