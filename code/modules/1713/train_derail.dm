// Leaving the rails (docs/trains.md#leaving-the-rails). Speed and track care
// matter: a train that takes a curve or the branch of a switch too fast, or
// runs off the end of the rails at speed, puts its leading cars on the
// ground. Nothing is smashed as in a crash, but the train stands until they
// are rerailed.
//
// - The drive loop (trains.dm) calls curve_check() after each step and
//   overrun_check() when the train could not step.
// - A derailed car is lifted back a section at a time with a rerailing jack.
//   A heavy engine is far too heavy for that: it needs the crane of a braced
//   crane car within reach as well.

#define TRAIN_CURVE_SPEED 3 // tiles a second; faster than this round a curve derails
#define TRAIN_OVERRUN_SPEED 2 // faster than this off the end of the rails derails
#define TRAIN_RERAIL_TIME 100
#define TRAIN_RERAIL_REACH 5 // how near the crane has to stand to a heavy engine

/obj/structure/trains
	var/derailed = FALSE // off the rails until it is jacked back on

// Puts this car on the ground. TRUE when it came off.
/obj/structure/trains/proc/come_off()
	return FALSE

/obj/structure/trains/platform/come_off()
	if (derailed || wrecked || unit_engine())
		return FALSE
	derailed = TRUE
	apply_layout()
	return TRUE

/obj/structure/trains/locomotive/come_off()
	if (!body_kind)
		stall()
		return FALSE
	if (derailed)
		return FALSE
	set_derailed(TRUE)
	on = FALSE
	throttle = 0
	update_icon()
	return TRUE

// A heavy engine and its body sections go off and on together.
/obj/structure/trains/locomotive/proc/set_derailed(state)
	derailed = !!state
	if (!car_id || !isturf(loc))
		return
	for (var/obj/structure/trains/platform/P in range(body_length(), src))
		if (P.car_id == car_id)
			P.derailed = derailed
			P.apply_layout()

// Derails a whole car or engine: the leading half of a car comes off.
/proc/train_unit_come_off(list/unit)
	var/obj/structure/trains/locomotive/E = train_crash_engine(unit)
	if (E)
		return E.come_off()
	. = FALSE
	for (var/i in 1 to max(1, round(unit.len / 2)))
		var/obj/structure/trains/car = unit[i]
		if (car.come_off())
			. = TRUE

// The train driven by this engine leaves the rails: its first `count` cars
// or engines in the way it runs. Returns how many came off.
/obj/structure/trains/locomotive/proc/leave_rails(count, force, why)
	. = 0
	var/list/cars = train_consist_list(train_head())
	var/way = train_way()
	if (way < 0)
		var/list/turned = list()
		for (var/i = cars.len, i >= 1, i--)
			turned += cars[i]
		cars = turned
	if (!cars.len)
		return
	var/obj/structure/trains/lead = cars[1]
	var/heading = (way > 0) ? lead.train_heading() : OPPOSITE_DIR(lead.train_heading())
	var/list/units = train_crash_units(cars)
	for (var/i in 1 to min(count, units.len))
		if (train_unit_come_off(units[i]))
			.++
	if (!.)
		return
	if (isturf(lead.loc))
		lead.visible_message(SPAN_DANGER(why))
		playsound(lead.loc, 'sound/effects/clang.ogg', 100, TRUE)
	for (var/obj/structure/trains/locomotive/L in cars)
		L.rail_speed = 0
		L.throttle = 0
		L.braking = FALSE
		L.automovement = FALSE
	// The people and loose things aboard are thrown, hardest at the front.
	var/list/seen = list()
	for (var/i in 1 to min(count + 1, units.len))
		for (var/obj/structure/trains/car in units[i])
			car.crash_jolt(heading, force / i, seen)

// Looked at from the drive loop after each step: lead is the car that leads
// the train, and where it stood and faced before the step. TRUE when the
// train left the rails.
/obj/structure/trains/locomotive/proc/curve_check(obj/structure/trains/lead, before_dir, turf/before_loc)
	if (!lead || QDELETED(lead) || rail_speed <= TRAIN_CURVE_SPEED || !isturf(lead.loc))
		return FALSE
	var/turned = (lead.dir != before_dir)
	var/what = "the curve"
	if (!turned && before_loc)
		// The branch of a switch moves a car sideways without turning it.
		var/d = get_dir(before_loc, lead.loc)
		if (d & (d - 1))
			turned = TRUE
			what = "the switch"
	if (!turned)
		return FALSE
	var/over = rail_speed / TRAIN_CURVE_SPEED
	return leave_rails(over >= 2 ? 3 : (over >= 1.5 ? 2 : 1), over * 0.5, "\The [lead] takes [what] too fast and leaves the rails!") > 0

// Looked at from the drive loop when the train could not step. TRUE when it
// ran off the end of the rails.
/obj/structure/trains/locomotive/proc/overrun_check()
	if (rail_speed <= TRAIN_OVERRUN_SPEED)
		return FALSE
	var/way = train_way()
	var/obj/structure/trains/lead = (way > 0) ? drive_head : drive_tail
	if (!lead || QDELETED(lead) || !isturf(lead.loc))
		return FALSE
	var/heading = (way > 0) ? lead.train_heading() : OPPOSITE_DIR(lead.train_heading())
	var/turf/ahead = get_step(lead, heading)
	if (!ahead || (locate(/obj/structure/rails) in ahead))
		return FALSE // something else stopped it
	if (locate(/obj/structure/rails/end) in lead.loc)
		return FALSE // a buffer stop
	return leave_rails(1, 0.5 * rail_speed / TRAIN_OVERRUN_SPEED, "\The [lead] runs off the end of the rails!") > 0

/////////////////////////////////////////////////////////////////////////////
// Rerailing

// The fired crane of a braced crane car near enough to lift A, or null.
/proc/train_breakdown_crane(atom/A)
	if (!A)
		return null
	for (var/obj/structure/workshop_machine/shear_legs/crane/steam/rail/C in range(TRAIN_RERAIL_REACH, A))
		if (!C.rail_problem() && C.fuel >= 1)
			return C
	return null

// The heavy engine this car is, or is a section of.
/obj/structure/trains/proc/heavy_engine()
	var/obj/structure/trains/locomotive/E = istype(src, /obj/structure/trains/locomotive) ? src : unit_engine()
	return (E && E.body_kind) ? E : null

// Why this car cannot be put back on the rails, or null when it can.
/obj/structure/trains/proc/rerail_problem()
	if (!derailed)
		return "\The [src] stands on the rails."
	if (!(locate(/obj/structure/rails) in loc))
		return "There is no rail under \the [src]. Lay the track again first."
	var/obj/structure/trains/locomotive/E = heavy_engine()
	if (E && !train_breakdown_crane(E))
		return "\The [E] is far too heavy for a jack alone. Bring up a crane car, lower its outriggers within [TRAIN_RERAIL_REACH] tiles of the engine and fire its crane."
	return null

// Puts it back on the rails: a section of a car, or a whole heavy engine
// under the crane. TRUE when it is back on.
/obj/structure/trains/proc/rerail()
	if (rerail_problem())
		return FALSE
	var/obj/structure/trains/locomotive/E = heavy_engine()
	if (E)
		var/obj/structure/workshop_machine/shear_legs/crane/steam/rail/C = train_breakdown_crane(E)
		C.fuel = max(0, C.fuel - 1)
		E.set_derailed(FALSE)
		E.update_icon()
		return TRUE
	derailed = FALSE
	if (istype(src, /obj/structure/trains/platform))
		var/obj/structure/trains/platform/P = src
		P.apply_layout()
	return TRUE

// A rerailing jack used on the car, from service_use() (train_servicing.dm).
/obj/structure/trains/proc/jack_use(obj/item/train_jack/J, mob/living/user)
	var/problem = rerail_problem()
	if (problem)
		to_chat(user, derailed ? SPAN_WARNING(problem) : problem)
		return TRUE
	var/obj/structure/trains/locomotive/E = heavy_engine()
	user.visible_message("[user] starts jacking \the [src] back onto the rails...", "You set the jack under \the [src] and start lifting[E ? " while the crane takes the weight" : ""]...")
	playsound(loc, 'sound/effects/lever.ogg', 60, TRUE)
	if (!do_after(user, TRAIN_RERAIL_TIME, src))
		return TRUE
	if (rerail())
		user.visible_message("[user] sets \the [src] back on the rails.", "You set \the [src] back on the rails.")
	return TRUE

/obj/item/train_jack
	name = "rerailing jack"
	desc = "A heavy screw jack with a sliding head, for lifting a derailed railway car back onto the track a section at a time. A heavy locomotive needs a crane car as well."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "rerail_jack"
	w_class = 4
	force = 8
	throwforce = 4

#undef TRAIN_CURVE_SPEED
#undef TRAIN_OVERRUN_SPEED
#undef TRAIN_RERAIL_TIME
#undef TRAIN_RERAIL_REACH
