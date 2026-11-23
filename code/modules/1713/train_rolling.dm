// Rolling stock (docs/trains.md#runaways). Cars keep their momentum. When a
// moving train parts, by a broken coupling or a hand on the coupling as it
// coasts, the part without the engine rolls on by itself. A train that runs
// into standing cars with their brakes off sends them rolling. A train that
// rolls free slows by its own rolling resistance and by any handbrake wound
// on aboard, and hits whatever is in its way like any other train.
//
// The car at the head of the rolling train carries the state (`roll_speed`).
// roll_step() moves the train one tile and returns the wait until the next;
// roll_loop() repeats it on a timer.

#define TRAIN_ROLL_DRAG 0.2 // speed lost each tile by a light train
#define TRAIN_ROLL_MIN 0.25 // slower than this the train stands
#define TRAIN_SHOVE_SPEED 1.5 // a slower bump leaves standing cars where they are
#define TRAIN_SHOVE_SHARE 1.2 // how lively the buffers are

/obj/structure/trains
	var/tmp/roll_speed = 0 // tiles per second while this car leads a train that rolls free
	var/tmp/roll_steps = 0 // tiles until the train's weight is added up again
	var/tmp/roll_weight = 0
	var/tmp/roll_braked = 0
	var/tmp/roll_since = 0 // tiles rolled since the weight was added up

// The speed and weight of the train this car is part of, as a list, or null
// when it stands: an engine driving it, or the train rolling free.
/obj/structure/trains/proc/train_motion()
	var/obj/structure/trains/head = train_head()
	var/speed = 0
	var/weight = 0
	var/forward = TRUE
	if (head.roll_speed > 0)
		speed = head.roll_speed
		weight = head.roll_weight
	for (var/obj/structure/trains/locomotive/L in train_consist_list(head))
		if (L.driving && L.rail_speed > speed)
			speed = L.rail_speed
			weight = L.consist_weight
			forward = L.train_way() > 0
	if (speed <= 0)
		return null
	return list(speed, max(1, weight), forward)

// The way this car travels while its train moves as train_motion() says.
/obj/structure/trains/proc/travel_way(list/motion)
	return motion[3] ? train_heading() : OPPOSITE_DIR(train_heading())

// Sets this car's train rolling free at speed, this car travelling towards
// `way`. FALSE when an engine drives the train or it is too slow to roll.
/obj/structure/trains/proc/start_rolling(speed, way)
	if (speed <= TRAIN_ROLL_MIN || !isturf(loc))
		return FALSE
	for (var/obj/structure/trains/locomotive/L in train_consist_list(train_head()))
		if (L.driving)
			return FALSE
	// The car that leads the way is the head of the train's order.
	if (train_heading() == OPPOSITE_DIR(way))
		reverse_train()
	var/obj/structure/trains/head = train_head()
	if (head.roll_speed > 0)
		head.roll_speed = max(head.roll_speed, speed)
		head.roll_steps = 0
		return TRUE
	head.roll_speed = speed
	if (!head.roll_refresh())
		return FALSE
	head.roll_wait(clamp(10 / max(0.5, speed), 1, 20))
	return TRUE

// Adds up the rolling train's weight and what its brakes hold. FALSE when
// an engine has started to drive it: the engine takes the train over.
/obj/structure/trains/proc/roll_refresh()
	roll_steps = 6
	roll_weight = 0
	roll_braked = 0
	for (var/obj/structure/trains/car in train_consist_list(src))
		var/weight = car.car_load_weight()
		roll_weight += weight
		car.wear_axles(roll_since)
		if (car.handbrake)
			car.wear_shoes(roll_since)
		if (car.handbrake || car.axle_seized)
			roll_braked += weight * car.brake_hold()
		if (istype(car, /obj/structure/trains/locomotive))
			var/obj/structure/trains/locomotive/L = car
			if (L.driving)
				stop_rolling()
				return FALSE
			if (L.braking)
				L.wear_shoes(roll_since)
				roll_braked += weight * L.brake_hold()
	roll_since = 0
	return TRUE

// A rolling train hits by its own speed and weight.
/obj/structure/trains/proc/roll_impact()
	return (roll_speed / 4) * clamp(sqrt(max(1, roll_weight) / 4), 1, 2)

/obj/structure/trains/proc/roll_wait(delay)
	if (SStimer)
		addtimer(CALLBACK(src, PROC_REF(roll_loop)), delay)

/obj/structure/trains/proc/roll_loop()
	var/delay = roll_step()
	if (delay > 0)
		roll_wait(delay)

/obj/structure/trains/proc/stop_rolling()
	roll_speed = 0
	roll_steps = 0
	automovement = FALSE
	set_light(0)
	train_glide_rest(src)
	return 0

// One tile of a free roll. Returns the wait before the next, 0 when the
// train has stopped.
/obj/structure/trains/proc/roll_step()
	if (QDELETED(src) || !isturf(loc) || roll_speed <= 0 || train_head() != src)
		return stop_rolling()
	if (roll_steps <= 0 && !roll_refresh())
		return 0
	roll_steps--
	roll_since++
	roll_speed -= TRAIN_ROLL_DRAG / max(1, roll_weight / 6) + train_brake_decel(roll_braked, roll_weight)
	if (roll_speed <= TRAIN_ROLL_MIN)
		return stop_rolling()
	automovement = TRUE
	train_glide_begin(src, clamp(10 / max(0.5, roll_speed), 1, 20))
	var/moved = process_rail_movement(roll_impact(), TRUE)
	train_glide_end(src)
	automovement = FALSE
	if (!moved || QDELETED(src))
		return stop_rolling()
	return clamp(10 / max(0.5, roll_speed), 1, 20)

// A moving train parts between this car and other: the part an engine does
// not drive rolls on. motion is train_motion() from before they parted, and
// the ways each car was travelling.
/obj/structure/trains/proc/parted_rolls(obj/structure/trains/other, list/motion, way, other_way)
	if (!motion)
		return
	start_rolling(motion[1], way)
	if (other && !QDELETED(other))
		other.start_rolling(motion[1], other_way)

// Hit at the end by a train moving as strike (its train_motion()), towards
// way: standing cars with nothing holding them roll away.
/obj/structure/trains/proc/shoved(list/strike, way)
	if (!strike || strike[1] < TRAIN_SHOVE_SPEED || !isturf(loc))
		return FALSE
	var/obj/structure/trains/head = train_head()
	if (head.roll_speed > 0)
		return FALSE
	var/list/cars = train_consist_list(head)
	// Only a blow on the end of a train sends it along the line, away from
	// the blow: the car that was hit trails.
	if (cars.len > 1)
		if (src == head)
			way = OPPOSITE_DIR(train_heading())
		else if (src == cars[cars.len])
			way = train_heading()
		else
			return FALSE
	var/weight = 0
	for (var/obj/structure/trains/car in cars)
		if (car.handbrake || car.axle_seized)
			return FALSE
		if (istype(car, /obj/structure/trains/platform))
			var/obj/structure/trains/platform/P = car
			if (P.wrecked || P.braced)
				return FALSE
		if (istype(car, /obj/structure/trains/locomotive))
			var/obj/structure/trains/locomotive/L = car
			if (L.driving || L.braking)
				return FALSE
		weight += car.car_load_weight()
	var/speed = min(strike[1], strike[1] * TRAIN_SHOVE_SHARE * strike[2] / (strike[2] + max(1, weight)))
	if (!start_rolling(speed, way))
		return FALSE
	visible_message(SPAN_WARNING("\The [src] is knocked rolling down the line!"))
	return TRUE

#undef TRAIN_ROLL_DRAG
#undef TRAIN_ROLL_MIN
#undef TRAIN_SHOVE_SPEED
#undef TRAIN_SHOVE_SHARE
