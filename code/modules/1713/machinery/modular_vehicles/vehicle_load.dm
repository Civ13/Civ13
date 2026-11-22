// Vehicle load: what a land vehicle carries sets how fast it drives.
// ------------------------------------------------------------
// The time a tile takes in each gear (vehicle_speeds.dm) is multiplied by a
// load factor. The
// factor compares the vehicle as loaded against the same vehicle with steel
// walls and a normal load: one person per seat plus a little payload per
// frame. A rider in a seat counts half their weight, since the seat carries
// them low and braced; a rider standing on the deck or roof counts in full.
// Today's vehicles with a normal load drive exactly as before (factor 1.0); overloading slows them down to VEHICLE_LOAD_MAX, and a hull lighter
// than steel can speed them up to VEHICLE_LOAD_MIN, with one extra top gear
// at VEHICLE_LOAD_BONUS_GEAR or less. Turning time follows the same factor,
// held to a narrower band.
//
// Boats, ships and aircraft keep their own speed rules. The engine stall
// limit (get_weight against engine power) is unchanged.
//
// The factor is cached and recalculated at most every
// VEHICLE_LOAD_RECHECK ticks, so a moving vehicle walks its frames once a
// couple of seconds rather than on every step.
// ============================================================

#define VEHICLE_LOAD_MIN 0.7
#define VEHICLE_LOAD_MAX 1.5
#define VEHICLE_LOAD_BONUS_GEAR 0.8
#define VEHICLE_TURN_LOAD_MIN 0.7
#define VEHICLE_TURN_LOAD_MAX 1.3
#define VEHICLE_SEAT_ALLOWANCE 20     // One seated human (MOB_MEDIUM, half weight) per seat.
#define VEHICLE_FRAME_PAYLOAD 10      // Free payload per frame before it slows down.
#define VEHICLE_WALL_WEIGHT 0.5       // Weight per point of steel wall armour.
#define VEHICLE_LOAD_RECHECK 20

/obj/structure/vehicleparts/axis
	var/tmp/load_factor = 1
	var/tmp/load_checked_at = -1000

/obj/structure/vehicleparts/axis/persistence_runtime_var(key)
	return key == "load_factor" || key == "load_checked_at" || ..(key)

// TRUE for land vehicles whose speed follows their load.
/obj/structure/vehicleparts/axis/proc/uses_load_factor()
	return TRUE

/obj/structure/vehicleparts/axis/ship/uses_load_factor()
	return FALSE

/obj/structure/vehicleparts/axis/boat/uses_load_factor()
	return FALSE

/obj/structure/vehicleparts/axis/aircraft/uses_load_factor()
	return FALSE

// How heavy one wall side of F is, given its armour rating. Hull materials
// lighter or heavier than steel change this (steel_only ignores them).
/obj/structure/vehicleparts/frame/proc/wall_weight(list/wall, steel_only = FALSE)
	if (!islist(wall) || wall.len < 4 || !wall[1] || wall[1] == "none")
		return 0
	// A composite panel's armour is not part of the steel body: it weighs
	// COMPOSITE_PANEL_WEIGHT of steel and is left out of the reference
	// (composite_armour.dm).
	var/panel = composite_bonus_on(wall)
	var/weight = max(0, wall[4] - panel) * VEHICLE_WALL_WEIGHT
	// A hull material weighs its walls from their steel armour (vehicle_hulls.dm).
	var/list/stats = vehicle_hull_stats(hull_material)
	if (stats)
		weight /= stats[2]
		if (!steel_only)
			weight *= stats[1]
	if (!steel_only)
		weight += panel * VEHICLE_WALL_WEIGHT * COMPOSITE_PANEL_WEIGHT
	return weight

// TRUE for things standing on a frame that count as cargo rather than
// fitted parts: loose items (other than the fuel tank) and crates.
/proc/vehicle_load_is_cargo(obj/O)
	if (istype(O, /obj/item))
		return !istype(O, /obj/item/weapon/reagent_containers/glass/barrel/fueltank)
	return istype(O, /obj/structure/closet) || istype(O, /obj/structure/supply_crate)

// What a rider adds to the load: half in a seat, in full standing.
/proc/vehicle_rider_weight(mob/living/L)
	return istype(L.buckled, /obj/structure/bed/chair) ? L.mob_size : L.mob_size * 2

// Weighs the vehicle once. Returns list(load, reference): the weight it
// drives with, and the weight of the same body in steel with a normal load.
/obj/structure/vehicleparts/axis/proc/vehicle_load_weights()
	var/fitted = 5
	var/cargo = 0
	var/seats = 0
	var/frames = 0
	var/walls = 0
	var/steel_walls = 0
	for (var/obj/structure/vehicleparts/frame/F in components)
		if (!isturf(F.loc))
			continue
		frames++
		fitted += 10
		for (var/list/wall in list(F.w_front, F.w_back, F.w_left, F.w_right))
			walls += F.wall_weight(wall)
			steel_walls += F.wall_weight(wall, TRUE)
		for (var/obj/O in F.loc)
			if (istype(O, /obj/structure/rails))
				continue
			if (vehicle_load_is_cargo(O))
				cargo += O.w_class * 2
				// A packed crate weighs what is in it too.
				if (istype(O, /obj/structure/closet))
					for (var/obj/item/I in O)
						cargo += I.w_class
			else
				fitted += O.w_class * 2
				if (istype(O, /obj/structure/bed/chair))
					seats++
		for (var/mob/living/L in F.loc)
			cargo += vehicle_rider_weight(L)
	var/allowance = seats * VEHICLE_SEAT_ALLOWANCE + frames * VEHICLE_FRAME_PAYLOAD
	return list(fitted + walls + max(cargo, allowance), fitted + steel_walls + allowance)

// The current load factor, recalculated when stale or when force is set.
/obj/structure/vehicleparts/axis/proc/get_load_factor(force = FALSE)
	if (!uses_load_factor())
		return 1
	if (!force && world.time < load_checked_at + VEHICLE_LOAD_RECHECK)
		return load_factor
	load_checked_at = world.time
	var/list/W = vehicle_load_weights()
	load_factor = W[2] > 0 ? clamp(W[1] / W[2], VEHICLE_LOAD_MIN, VEHICLE_LOAD_MAX) : 1
	return load_factor

// The highest gear the driver can select now: a light vehicle gets one more.
/obj/structure/vehicleparts/axis/proc/top_gear()
	if (uses_load_factor() && speedlist && speeds >= 1 && load_factor <= VEHICLE_LOAD_BONUS_GEAR)
		return speeds + 1
	return speeds

// The base step delay for gear, before load. The bonus gear is a tenth of a
// second per tile quicker than the last listed gear, or one server tick
// quicker when that gear is already close to the floor.
/obj/structure/vehicleparts/axis/proc/gear_delay(gear)
	if (!speedlist || gear <= 0)
		return 0
	if (gear > speeds)
		var/top = speedlist[speeds]
		if (!top)
			return 0
		return top > 1 ? max(1, top - 1) : max(0.2, top - 0.4) // VEHICLE_MIN_DELAY (vehicle_speeds.dm)
	return speedlist[gear] || 0

// How long a turn takes with this load.
/obj/structure/vehicleparts/axis/proc/loaded_turntimer()
	if (isnull(turntimer))
		return null
	if (!uses_load_factor())
		return turntimer
	return turntimer * clamp(load_factor, VEHICLE_TURN_LOAD_MIN, VEHICLE_TURN_LOAD_MAX)

// Plain words on how the load affects driving, for examine.
/obj/structure/vehicleparts/axis/proc/load_description()
	var/F = get_load_factor(TRUE)
	if (F >= 1.3)
		return "It is badly overloaded and crawls along."
	if (F > 1.02)
		return "It is loaded down and drives slower than usual."
	if (F <= VEHICLE_LOAD_BONUS_GEAR)
		return "It is light for its engine and has an extra top gear."
	if (F < 0.98)
		return "It is light and drives a little faster than usual."
	return null

#undef VEHICLE_TURN_LOAD_MIN
#undef VEHICLE_TURN_LOAD_MAX
#undef VEHICLE_SEAT_ALLOWANCE
#undef VEHICLE_FRAME_PAYLOAD
#undef VEHICLE_WALL_WEIGHT
#undef VEHICLE_LOAD_RECHECK
