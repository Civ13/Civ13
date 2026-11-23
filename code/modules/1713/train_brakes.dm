// Brakes (docs/trains.md#brakes). A train stops by the weight its brakes
// hold, not by one lever: the driver's brake grips the engine alone, and
// every car has a handbrake of its own. A long train needs more of it braked
// to stop short, which is the work of a guard at the brake wheel of a brake
// van.
//
// - Every car that is not an engine has `handbrake`. It is pinned down from
//   beside a standing car (the Handbrake verb), or screwed on from a brake
//   wheel aboard, which also works while the train runs.
// - The drive loop (trains.dm) slows the train by brake_decel(): the share of
//   the train's weight that is braked. Handbrakes left on drag while the
//   engine pulls (pull_ratio()).

#define TRAIN_BRAKE_DECEL 1.2 // tiles per second lost with the whole train braked: each second while an engine drives it, each tile while it rolls free
#define TRAIN_BRAKE_DRAG 3 // a braked car pulls like this many times its weight more
#define TRAIN_HANDBRAKE_TIME 20
#define TRAIN_BRAKE_WHEEL_DELAY 10

/obj/structure/trains
	var/handbrake = FALSE

/obj/structure/trains/locomotive
	var/tmp/consist_braked = 0 // weight of the cars with their handbrakes on
	var/tmp/consist_own = 0 // weight the driver's brake holds: the engine itself

// Engines are braked from the cab; everything else has a handbrake.
/obj/structure/trains/proc/has_handbrake()
	return TRUE

/obj/structure/trains/locomotive/has_handbrake()
	return FALSE

/obj/structure/trains/platform/has_handbrake()
	return !unit_engine()

// The sections one handbrake holds: the whole of a car.
/obj/structure/trains/proc/brake_sections()
	return list(src)

/obj/structure/trains/platform/brake_sections()
	return car_segments()

// Speed lost each step with `held` of a train's `weight` braked.
/proc/train_brake_decel(held, weight)
	if (held <= 0)
		return 0
	return TRAIN_BRAKE_DECEL * min(1, held / max(1, weight))

// Speed lost each step to the brakes, for the engine that drives the train.
/obj/structure/trains/locomotive/proc/brake_decel()
	return train_brake_decel(consist_braked + (braking ? consist_own : 0), consist_weight)

// The weight the engine drags, braked cars counted heavier and a car with a
// hot axle box (train_servicing.dm) twice.
/obj/structure/trains/locomotive/proc/drag_weight()
	return consist_weight + TRAIN_BRAKE_DRAG * consist_braked + consist_hot

/obj/structure/trains/proc/train_rolling()
	var/obj/structure/trains/head = train_head()
	if (head.roll_speed > 0)
		return TRUE
	for (var/obj/structure/trains/locomotive/L in train_consist_list(head))
		if (L.rail_speed > 0)
			return TRUE
	return FALSE

// How many cars of this train have their handbrakes on.
/obj/structure/trains/proc/train_handbrakes()
	var/n = 0
	var/list/counted = list()
	for (var/obj/structure/trains/car in train_consist_list(train_head()))
		if (!car.handbrake)
			continue
		if (car.car_id)
			if (counted[car.car_id])
				continue
			counted[car.car_id] = TRUE
		n++
	return n

/obj/structure/trains/proc/set_handbrake(state)
	if (!has_handbrake())
		return FALSE
	state = !!state
	for (var/obj/structure/trains/S in brake_sections())
		S.handbrake = state
		for (var/turf/T in S.crash_tiles())
			for (var/obj/structure/train_brake_wheel/W in T)
				W.update_icon()
	if (isturf(loc))
		playsound(loc, 'sound/effects/lever.ogg', 60, TRUE)
	// The engine driving the train feels it at once, and so does a train
	// that rolls free (train_rolling.dm).
	var/obj/structure/trains/head = train_head()
	head.roll_steps = 0
	for (var/obj/structure/trains/locomotive/L in train_consist_list(head))
		if (L.driving)
			L.refresh_consist()
	return TRUE

/obj/structure/trains/verb/handbrake_lever()
	set category = null
	set name = "Handbrake"
	set desc = "Pin down or let off this car's handbrake."
	set src in view(1)
	work_handbrake(usr)

// By hand from beside the car: only while it stands.
/obj/structure/trains/proc/work_handbrake(mob/living/user)
	if (!istype(user, /mob/living/human) || user.incapacitated() || !isturf(loc) || get_dist(user, src) > 1)
		return FALSE
	if (!has_handbrake())
		to_chat(user, "\The [src] is braked from its cab.")
		return FALSE
	if (train_rolling())
		to_chat(user, SPAN_WARNING("The train is moving. Only a brake wheel aboard can be worked on the move."))
		return FALSE
	var/state = !handbrake
	user.visible_message("[user] starts [state ? "pinning down" : "letting off"] the handbrake of \the [src]...", "You start [state ? "pinning down" : "letting off"] the handbrake of \the [src]...")
	if (!do_after(user, TRAIN_HANDBRAKE_TIME, src) || handbrake == state || train_rolling())
		return FALSE
	set_handbrake(state)
	user.visible_message("[user] [state ? "pins down" : "lets off"] the handbrake of \the [src].", "You [state ? "pin down" : "let off"] the handbrake of \the [src].")
	return TRUE

/obj/structure/trains/examine(mob/user)
	..()
	if (handbrake)
		to_chat(user, "Its handbrake is on.")

/////////////////////////////////////////////////////////////////////////////
// The brake wheel: a handbrake worked from aboard, standing or on the move.
// A brake van is built with one; it can be bolted to the deck of any car.

/obj/structure/train_brake_wheel
	name = "brake wheel"
	desc = "A hand wheel on a column that screws a railway car's brakes on and off. It works the car it is bolted to, even while the train runs."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "brake_wheel"
	anchored = TRUE
	density = FALSE
	flammable = FALSE
	layer = 3.1
	var/tmp/next_use = 0

// The car this wheel is bolted to, if any.
/obj/structure/train_brake_wheel/proc/brake_car()
	if (!anchored || !isturf(loc))
		return null
	for (var/obj/structure/trains/platform/P in range(1, src))
		if (P.has_handbrake() && (loc in train_platform_tiles(P.loc, P.dir)))
			return P
	return null

/obj/structure/train_brake_wheel/update_icon()
	var/obj/structure/trains/platform/P = brake_car()
	icon_state = (P && P.handbrake) ? "brake_wheel_on" : "brake_wheel"

/obj/structure/train_brake_wheel/examine(mob/user)
	..()
	update_icon()
	var/obj/structure/trains/platform/P = brake_car()
	if (!anchored)
		to_chat(user, "It is unbolted. Stand it on the deck of a railway car and use a wrench.")
	else if (!P)
		to_chat(user, "It has to stand on the deck of a railway car to work.")
	else
		to_chat(user, "The brakes of \the [P] are [P.handbrake ? "on" : "off"].")

// Winds the brake on or off. TRUE when the brake changed.
/obj/structure/train_brake_wheel/proc/wind(mob/user)
	var/obj/structure/trains/platform/P = brake_car()
	if (!P)
		if (user)
			to_chat(user, anchored ? "\The [src] has to stand on the deck of a railway car to work." : "\The [src] is unbolted.")
		return FALSE
	if (world.time < next_use)
		return FALSE
	next_use = world.time + TRAIN_BRAKE_WHEEL_DELAY
	var/state = !P.handbrake
	P.set_handbrake(state)
	if (user)
		user.visible_message("[user] winds the brake of \the [P] [state ? "hard on" : "off"].", "You wind the brake of \the [P] [state ? "hard on" : "off"].")
	return TRUE

/obj/structure/train_brake_wheel/attack_hand(mob/user)
	if (!istype(user, /mob/living/human) || user.incapacitated() || get_dist(user, src) > 1)
		return
	wind(user)

/obj/structure/train_brake_wheel/attackby(obj/item/W as obj, mob/user as mob)
	if (is_tool(W, TOOL_WRENCH))
		var/obj/structure/trains/platform/P = brake_car()
		if (P && P.handbrake)
			to_chat(user, SPAN_WARNING("Wind the brake off first."))
			return
		user.visible_message("[user] starts [anchored ? "unbolting" : "bolting down"] \the [src]...", "You start [anchored ? "unbolting" : "bolting down"] \the [src]...")
		if (!do_after(user, 30, src))
			return
		anchored = !anchored
		update_icon()
		to_chat(user, anchored ? "You bolt \the [src] down." : "You unbolt \the [src]. It can be dragged off the car.")
		return
	return ..()

#undef TRAIN_BRAKE_DECEL
#undef TRAIN_BRAKE_DRAG
#undef TRAIN_HANDBRAKE_TIME
#undef TRAIN_BRAKE_WHEEL_DELAY
