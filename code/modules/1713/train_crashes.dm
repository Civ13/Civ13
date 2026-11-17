// Train crashes (docs/trains.md#crashes). A train that runs into another
// train, a wall or anything else that stops it dead at speed is a wreck, not
// a bump: the blow scales with speed and weight (collision_impact()), the
// leading cars are thrown off the rails, couplings break down the train,
// riders are thrown forward and hurt, and loose cargo slides off.
//
// rail_hit() (trains.dm) calls train_crash() where the train is stopped. A
// crash needs an engine in the train that is actually running: stock moved by
// hand, and a train that has only just started, still bump as before.

#define TRAIN_CRASH_IMPACT 0.75 // the least impact that is a crash
#define TRAIN_CRASH_HULL 80 // hull damage to the leading car at impact 1
#define TRAIN_CRASH_STRUCK 60 // and to the car that is hit
#define TRAIN_CRASH_COUPLING 45 // wear on the first coupling at impact 1
#define TRAIN_CRASH_HURT 12 // brute damage to a rider of the leading car at impact 1
#define TRAIN_CRASH_HURT_MAX 60
#define TRAIN_DERAIL_HEALTH 0.4 // a derailed car is left at this share of its health

// How many of the train's leading cars leave the rails.
/proc/train_crash_derailed(impact)
	if (impact >= 3)
		return 3
	if (impact >= 2)
		return 2
	if (impact >= 1.25)
		return 1
	return 0

// The cars of a train grouped into whole cars and engines, in the order given.
/proc/train_crash_units(list/cars)
	var/list/units = list()
	var/list/unit = null
	var/last_id = null
	for (var/obj/structure/trains/car in cars)
		if (!unit || !car.car_id || car.car_id != last_id)
			unit = list()
			units += list(unit)
		unit += car
		last_id = car.car_id
	return units

// The engine a group of sections belongs to, if it is one.
/proc/train_crash_engine(list/unit)
	for (var/obj/structure/trains/car in unit)
		if (istype(car, /obj/structure/trains/locomotive))
			return car
		var/obj/structure/trains/locomotive/E = car.unit_engine()
		if (E)
			return E
	return null

// Hull damage from a crash.
/obj/structure/trains/proc/crash_damage(amount)
	health = max(0, health - amount)

/obj/structure/trains/platform/crash_damage(amount)
	var/obj/structure/trains/locomotive/E = unit_engine()
	if (E)
		E.crash_damage(amount)
		return
	take_train_damage(amount)

/obj/structure/trains/locomotive/crash_damage(amount)
	if (body_kind)
		heavy_damage(amount)
		return
	..()

// Thrown off the rails. A car lies wrecked until it is welded back; a heavy
// engine is broken down the same way; a small engine loses its fire.
/obj/structure/trains/proc/derail()
	return FALSE

/obj/structure/trains/platform/derail()
	if (wrecked || unit_engine())
		return FALSE
	health = min(health, round(initial(health) * TRAIN_DERAIL_HEALTH))
	wrecked = TRUE
	apply_layout()
	return TRUE

/obj/structure/trains/locomotive/derail()
	if (!body_kind)
		stall()
		return FALSE
	if (broken_down)
		return FALSE
	health = min(health, round(initial(health) * TRAIN_DERAIL_HEALTH))
	broken_down = TRUE
	on = FALSE
	throttle = 0
	update_icon()
	return TRUE

// Derails a whole car or engine: the half of a car nearest the blow comes off.
/proc/train_crash_derail(list/unit)
	var/obj/structure/trains/locomotive/E = train_crash_engine(unit)
	if (E)
		if (E.derail())
			E.visible_message(SPAN_DANGER("\The [E] is thrown off the rails and its engine dies!"))
			return TRUE
		return FALSE
	var/off = FALSE
	for (var/i in 1 to max(1, round(unit.len / 2)))
		var/obj/structure/trains/car = unit[i]
		if (car.derail())
			off = TRUE
	if (off)
		var/obj/structure/trains/first = unit[1]
		first.visible_message(SPAN_DANGER("\The [first] is thrown off the rails!"))
	return off

// Everything a car carries: the people and loose things on its tiles.
/obj/structure/trains/proc/crash_tiles()
	if (!isturf(loc))
		return list()
	if (wide_body())
		return train_platform_tiles(loc, dir)
	return list(loc)

// The jolt on one car: way is the way the train was running, force the impact
// that reaches this car. seen keeps anybody from being thrown twice.
/obj/structure/trains/proc/crash_jolt(way, force, list/seen)
	if (force <= 0)
		return
	var/hurt = min(TRAIN_CRASH_HURT_MAX, round(TRAIN_CRASH_HURT * force))
	var/far = clamp(round(force * 1.5, 1), 1, 3)
	// Cargo chained down on a transport wagon breaks loose in a hard crash.
	if (force >= 1)
		for (var/obj/O in transporting)
			O.anchored = FALSE
			transporting -= O
	for (var/turf/T in crash_tiles())
		for (var/atom/movable/AM in T)
			if (seen[AM] || AM.loc != T || !train_platform_carries(AM))
				continue
			seen[AM] = TRUE
			if (isliving(AM))
				var/mob/living/M = AM
				var/held = M.buckled ? TRUE : FALSE
				M.adjustBruteLoss(held ? round(hurt / 2) : hurt)
				to_chat(M, SPAN_DANGER(held ? "The crash slams you against your seat!" : "The crash throws you off your feet!"))
				shake_camera(M, 4, 1)
				if (held)
					continue
				train_crash_throw(M, way, far)
				train_knock_down(M, force)
				continue
			if (AM.anchored)
				continue
			train_crash_throw(AM, way, far)

// Whether something thrown from A may come to rest on the next tile B: the
// rules of turf/Enter, without bumping anything. People do not stop it.
/proc/train_crash_can_slide(atom/movable/AM, turf/A, turf/B)
	if (!A || !B || A.z != B.z || B.density || !B.CanPass(AM, B))
		return FALSE
	var/d = get_dir(A, B)
	for (var/obj/O in A)
		if (O != AM && !O.CheckExit(AM, B, d))
			return FALSE
	for (var/atom/movable/O in B)
		if (O == AM || ismob(O))
			continue
		if (!O.CanPass(AM, A, TRUE, FALSE))
			return FALSE
	return TRUE

// Slides something along the train; walls, doors and furniture hold it.
/proc/train_crash_throw(atom/movable/AM, way, far)
	for (var/i in 1 to far)
		if (QDELETED(AM) || !isturf(AM.loc))
			break
		var/turf/next = get_step(AM, way)
		if (!train_crash_can_slide(AM, AM.loc, next) || !AM.persistence_set_loc(next))
			break

// The train led by src has run into hit. TRUE when that was a crash.
/obj/structure/trains/proc/train_crash(atom/hit, impact, fdir)
	if (impact < TRAIN_CRASH_IMPACT)
		return FALSE
	if (istype(hit, /obj/structure/train_part))
		var/obj/structure/train_part/part = hit
		if (part.segment)
			hit = part.segment
	var/list/cars = train_consist_list(train_head())
	if (hit in cars)
		return FALSE
	var/running = FALSE
	for (var/obj/structure/trains/locomotive/L in cars)
		if (L.rail_speed > 0)
			running = TRUE
			break
	if (!running)
		return FALSE
	// The train in the order it was travelling: the car that hit comes first.
	var/forward = (cars[1] == src)
	if (!forward)
		var/list/turned = list()
		for (var/i = cars.len, i >= 1, i--)
			turned += cars[i]
		cars = turned
	var/hit_name = (hit && !QDELETED(hit)) ? "\the [hit]" : "an obstacle"
	visible_message(SPAN_DANGER("\The [src] crashes into [hit_name][impact >= 1.25 ? " at speed" : ""]!"))
	playsound(loc, 'sound/effects/bang.ogg', 100, TRUE)
	playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
	for (var/obj/structure/trains/locomotive/L in cars)
		L.rail_speed = 0
		L.throttle = 0
		L.braking = FALSE
		L.automovement = FALSE
	automovement = FALSE

	var/list/seen = list()
	// The train that was hit.
	var/obj/structure/trains/struck = hit
	if (istype(struck) && !QDELETED(struck))
		var/list/theirs = list()
		for (var/obj/structure/trains/car in train_consist_list(struck.train_head()))
			if (car == struck || (struck.car_id && car.car_id == struck.car_id))
				theirs += car
		struck.crash_damage(round(TRAIN_CRASH_STRUCK * impact))
		for (var/front in list(TRUE, FALSE))
			for (var/obj/structure/trains/car in theirs)
				if (car.has_coupling_end(front))
					car.damage_coupling(front, round(TRAIN_CRASH_COUPLING * impact / 2))
		for (var/obj/structure/trains/car in theirs)
			car.crash_jolt(fdir, impact / 2, seen)
		if (impact >= 2)
			// The end that was hit comes off first.
			if (theirs.len > 1 && get_dist(theirs[theirs.len], src) < get_dist(theirs[1], src))
				var/list/near_first = list()
				for (var/i = theirs.len, i >= 1, i--)
					near_first += theirs[i]
				theirs = near_first
			train_crash_derail(theirs)

	// This train, from the car that hit backwards: each car takes less.
	var/list/units = train_crash_units(cars)
	var/derailed = train_crash_derailed(impact)
	// Which coupling end of each car faces the next one, before any link breaks.
	var/list/links = list()
	for (var/i in 1 to units.len - 1)
		var/list/unit = units[i]
		var/list/next = units[i + 1]
		var/obj/structure/trains/last = unit[unit.len]
		links += last.end_towards(next[1])
	for (var/i in 1 to units.len)
		var/list/unit = units[i]
		var/force = impact / i
		var/obj/structure/trains/first = unit[1]
		for (var/obj/structure/trains/car in unit)
			var/way = forward ? car.train_heading() : OPPOSITE_DIR(car.train_heading())
			car.crash_jolt(way, force, seen)
		first.crash_damage(round(TRAIN_CRASH_HULL * force))
		if (i <= derailed)
			train_crash_derail(unit)
		if (i < units.len)
			var/obj/structure/trains/last = unit[unit.len]
			if (!QDELETED(last))
				last.damage_coupling(links[i], round(TRAIN_CRASH_COUPLING * force))
	return TRUE

#undef TRAIN_CRASH_IMPACT
#undef TRAIN_CRASH_HULL
#undef TRAIN_CRASH_STRUCK
#undef TRAIN_CRASH_COUPLING
#undef TRAIN_CRASH_HURT
#undef TRAIN_CRASH_HURT_MAX
#undef TRAIN_DERAIL_HEALTH
