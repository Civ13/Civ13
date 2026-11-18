// Early rails (train scale-up, step 17; docs/trains.md#early-rails). Rails
// before the steam engine, and the small things that still run on them
// after it.
//
// - Hand car: a small platform with a walking beam. The riders standing on
//   it pump the beam and it rolls (train_rolling.dm); pumping against the
//   way it rolls slows it.
// - Draft animals: a horse or an ox harnessed to the car at one end of a
//   train with no engine walks ahead of it, and the train follows a tile
//   behind. Harnesses are not saved, like cart hitches.
// - Chaldron wagon: a wooden wagon for a wagonway.
// - Wooden rails: laid on sleepers like iron ones (track_laying.dm). Hand
//   cars and animals do them no harm; an engine wears them out fast
//   (train_trackwear.dm).

#define HANDCAR_PUMP_TIME 8 // deciseconds between one rider's strokes
#define HANDCAR_CREW_TIME 30 // a rider who pumped this lately is pumping
#define HANDCAR_PUSH 0.5 // speed one stroke adds to a light car
#define HANDCAR_SPEED 1.5 // tiles per second one rider can keep up
#define HANDCAR_CREW_SPEED 2.25 // and two
#define HANDCAR_LOAD 4 // weight it can move, itself and its riders included
#define TRAIN_DRAFT_LOAD 4 // weight an animal draws on rails for each point of its pull
#define TRAIN_DRAFT_SLACK 2 // tiles of trace: further off and it comes loose
#define TRAIN_HARNESS_TIME 30

/////////////////////////////////////////////////////////////////////////////
// Hand car

/obj/structure/trains/transport/handcar
	name = "hand car"
	desc = "A small railway platform with a walking beam. Riders standing on it pump the beam to make it roll."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "handcar"
	train_weight = 0.5
	var/pump_way = 0 // the way it was last pumped
	var/tmp/list/pumped // who pumped it, and when

/obj/structure/trains/transport/handcar/persistence_runtime_var(key)
	return key == "pumped" || ..(key)

// The riders pumping now: on the car, and at the beam lately.
/obj/structure/trains/transport/handcar/proc/pump_crew()
	. = 0
	if (!pumped)
		return
	for (var/mob/living/human/H in loc)
		var/last = pumped["\ref[H]"]
		if (!isnull(last) && world.time - last <= HANDCAR_CREW_TIME)
			.++

// Why it cannot be pumped, or null.
/obj/structure/trains/transport/handcar/proc/pump_problem(mob/living/user)
	if (!isturf(loc) || !user || user.loc != loc)
		return "Climb onto \the [src] to pump it: drag yourself onto it."
	if (handbrake)
		return "Its handbrake is pinned down."
	if (axle_seized)
		return "An axle box has seized."
	var/weight = 0
	for (var/obj/structure/trains/car in train_consist_list(train_head()))
		if (istype(car, /obj/structure/trains/locomotive))
			return "There is an engine on this train. Arms will not move it."
		if (car.draft_animal)
			return "\The [car.draft_animal] draws this train."
		if (car.handbrake)
			return "\The [car]'s handbrake is pinned down."
		weight += car.car_load_weight()
	if (weight > HANDCAR_LOAD)
		return "The load is too heavy to pump along. Leave some of it behind."
	return null

// One stroke of the beam by user, towards way (the way the car faces when
// that is not along the track). TRUE when the stroke told.
/obj/structure/trains/transport/handcar/proc/pump(mob/living/human/user, way = null)
	if (pump_problem(user))
		return FALSE
	if (!pumped)
		pumped = list()
	var/key = "\ref[user]"
	var/last = pumped[key]
	if (!isnull(last) && world.time - last < HANDCAR_PUMP_TIME)
		return FALSE
	// The dead and the departed are forgotten.
	if (pumped.len > 8)
		pumped = list()
	pumped[key] = world.time
	if (way != dir && way != OPPOSITE_DIR(dir))
		way = (pump_way == dir || pump_way == OPPOSITE_DIR(dir)) ? pump_way : dir
	pump_way = way
	var/weight = 0
	for (var/obj/structure/trains/car in train_consist_list(train_head()))
		weight += car.car_load_weight()
	var/push = HANDCAR_PUSH / max(1, weight / 1.5)
	var/limit = pump_crew() >= 2 ? HANDCAR_CREW_SPEED : HANDCAR_SPEED
	var/obj/structure/trains/head = train_head()
	var/list/motion = train_motion()
	if (motion && travel_way(motion) != way)
		// Leaning on the beam against the roll.
		head.roll_speed -= push * 2
		if (head.roll_speed <= 0.25)
			head.stop_rolling()
		return TRUE
	var/speed = motion ? motion[1] : 0
	if (speed >= limit)
		return TRUE
	return start_rolling(min(limit, max(speed, 0.3) + push), way)

/obj/structure/trains/transport/handcar/attack_hand(mob/living/human/user as mob)
	if (!istype(user) || user.incapacitated())
		return
	var/problem = pump_problem(user)
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return
	if (pump(user, user.dir) && isturf(loc))
		playsound(loc, 'sound/effects/lever.ogg', 25, TRUE)

/obj/structure/trains/transport/handcar/examine(mob/user)
	..()
	to_chat(user, "Stand on it and click it to pump the beam, facing the way you want to go. Keep pumping to keep it rolling; two riders pumping go half as fast again. Face the other way and pump to slow down.")

/////////////////////////////////////////////////////////////////////////////
// Chaldron wagon

/obj/structure/trains/storage/chaldron
	name = "chaldron wagon"
	desc = "A wooden wagon with sloping sides and flanged wooden wheels, for a wagonway. A horse or an ox draws a string of them."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "chaldron"
	max_storage = 10
	train_weight = 0.6

/////////////////////////////////////////////////////////////////////////////
// Draft animals

/obj/structure/trains
	var/tmp/mob/living/simple_animal/draft_animal = null // harnessed to this car, at an end of its train

/mob/living/simple_animal
	var/tmp/obj/structure/trains/hitched_train = null // the car it is harnessed to

// What this animal draws on rails.
/proc/train_draft_load(mob/living/simple_animal/A)
	return TRAIN_DRAFT_LOAD * draft_animal_pull(A)

/obj/structure/trains/proc/draft_weight()
	. = 0
	for (var/obj/structure/trains/car in train_consist_list(train_head()))
		. += car.car_load_weight()

// Why A cannot be harnessed to this car (a sentence), or null.
/obj/structure/trains/proc/harness_refusal(mob/living/simple_animal/A)
	if (QDELETED(src) || !isturf(loc))
		return "\The [src] has to stand on the track."
	if (!istype(A) || !is_draft_animal(A) || A.stat == DEAD)
		return "Only a horse or an ox can draw a wagon."
	if (A.buckled)
		return "\The [A] is already in harness."
	if (A.hitched_cart)
		return "\The [A] already pulls a cart."
	if (A.hitched_train && A.hitched_train != src)
		return "\The [A] already draws a train."
	var/list/cars = train_consist_list(train_head())
	if (src != cars[1] && src != cars[cars.len])
		return "Harness \the [A] to the car at one end of the train."
	var/obj/structure/trains/head = cars[1]
	if (head.roll_speed > 0)
		return "The train is moving."
	for (var/obj/structure/trains/car in cars)
		if (istype(car, /obj/structure/trains/locomotive))
			return "There is an engine on this train. Uncouple it first."
		if (car.draft_animal && car.draft_animal != A)
			return "\The [car.draft_animal] already draws this train."
	if (!isturf(A.loc) || A.z != z || get_dist(src, A) > 1)
		return "\The [A] has to stand next to \the [src]."
	var/load = train_draft_load(A)
	if (load <= 0)
		return "\The [A] is in no state to draw a wagon."
	if (draft_weight() > load)
		return "This train is too heavy for \the [A]. Uncouple some of it or lighten the load."
	return null

/obj/structure/trains/proc/harness(mob/living/simple_animal/A)
	if (harness_refusal(A))
		return FALSE
	if (draft_animal)
		unharness()
	draft_animal = A
	A.hitched_train = src
	GLOB.moved_event.register(A, src, /obj/structure/trains/proc/draft_moved)
	GLOB.destroyed_event.register(A, src, /obj/structure/trains/proc/draft_gone)
	return TRUE

// Lets the animal go. With a reason, the people around are told why.
/obj/structure/trains/proc/unharness(reason = null)
	var/mob/living/simple_animal/A = draft_animal
	if (!A)
		return FALSE
	draft_animal = null
	GLOB.moved_event.unregister(A, src, /obj/structure/trains/proc/draft_moved)
	GLOB.destroyed_event.unregister(A, src, /obj/structure/trains/proc/draft_gone)
	if (!QDELETED(A) && A.hitched_train == src)
		A.hitched_train = null
	if (reason && !QDELETED(src) && isturf(loc))
		visible_message(SPAN_WARNING("\The [A] comes out of the traces of \the [src]: [reason]."))
	return TRUE

/obj/structure/trains/proc/draft_gone(atom/movable/A)
	if (A == draft_animal)
		unharness()

/obj/structure/trains/proc/draft_moved(atom/movable/A, atom/old_loc, atom/new_loc)
	if (A == draft_animal)
		draw()

// The animal has moved: the train follows a tile behind it, or lets go.
// TRUE while the animal is still in the traces.
/obj/structure/trains/proc/draw()
	var/mob/living/simple_animal/A = draft_animal
	if (!A)
		return FALSE
	if (QDELETED(src) || !isturf(loc))
		unharness()
		return FALSE
	if (QDELETED(A) || A.stat == DEAD || !isturf(A.loc) || A.z != z)
		unharness("it is gone")
		return FALSE
	var/d = get_dist(src, A)
	if (d <= 1)
		return TRUE
	if (d > TRAIN_DRAFT_SLACK)
		unharness("it was left behind")
		return FALSE
	var/list/cars = train_consist_list(train_head())
	if (src != cars[1] && src != cars[cars.len])
		unharness("it is no longer at the end of the train")
		return FALSE
	var/weight = 0
	for (var/obj/structure/trains/car in cars)
		if (istype(car, /obj/structure/trains/locomotive))
			unharness("an engine has been coupled on")
			return FALSE
		if (car.handbrake || car.axle_seized)
			unharness("\the [car] is held fast")
			return FALSE
		weight += car.car_load_weight()
	if (weight > train_draft_load(A))
		unharness("the load is too heavy")
		return FALSE
	// The car in the traces leads the way.
	if (src != train_head())
		reverse_train()
	var/obj/structure/trains/head = train_head()
	if (head != src || head.roll_speed > 0)
		return TRUE
	var/list/route = rail_target(train_heading())
	var/turf/next = route ? route[1] : null
	if (!next || get_dist(next, A) >= d)
		unharness("the train could not follow")
		return FALSE
	automovement = TRUE
	var/moved = process_rail_movement(0.1, TRUE)
	automovement = FALSE
	if (QDELETED(src))
		return FALSE
	if (!moved)
		unharness("the train could not follow")
		return FALSE
	return TRUE

// How much the train slows the animal that draws it, in move delay.
/obj/structure/trains/proc/draft_drag(mob/living/simple_animal/A)
	var/load = train_draft_load(A)
	if (load <= 0)
		return 0
	return 3 * min(1, draft_weight() / load)

// The line examine() shows (train_couplings.dm), or null.
/obj/structure/trains/proc/draft_line()
	if (draft_animal)
		return "\The [draft_animal] is harnessed to it and draws the train: lead or ride the animal along the track. Use Harness Animal to let it go."
	return null

/obj/structure/trains/proc/player_harness(mob/living/human/user, mob/living/simple_animal/A)
	if (!istype(user) || user.incapacitated() || get_dist(user, src) > 1)
		return FALSE
	var/why = harness_refusal(A)
	if (why)
		to_chat(user, SPAN_WARNING(why))
		return FALSE
	user.visible_message(SPAN_NOTICE("[user] starts harnessing \the [A] to \the [src]..."), SPAN_NOTICE("You start harnessing \the [A] to \the [src]..."))
	if (!do_after(user, TRAIN_HARNESS_TIME, src) || get_dist(user, src) > 1)
		return FALSE
	why = harness_refusal(A)
	if (why)
		to_chat(user, SPAN_WARNING(why))
		return FALSE
	if (!harness(A))
		return FALSE
	user.visible_message(SPAN_NOTICE("[user] harnesses \the [A] to \the [src]."), SPAN_NOTICE("You harness \the [A] to \the [src]. Lead or ride it along the track and the train follows."))
	return TRUE

/obj/structure/trains/verb/harness_animal()
	set category = null
	set name = "Harness Animal"
	set desc = "Harness a horse or an ox standing next to this car to draw the train, or let it go."
	set src in view(1)
	var/mob/living/human/user = usr
	if (!istype(user) || user.incapacitated() || get_dist(user, src) > 1)
		return
	if (draft_animal)
		var/mob/living/simple_animal/was = draft_animal
		unharness()
		user.visible_message(SPAN_NOTICE("[user] takes \the [was] out of the traces of \the [src]."), SPAN_NOTICE("You take \the [was] out of the traces."))
		return
	var/list/choices = list()
	for (var/mob/living/simple_animal/A in orange(1, src))
		if (is_draft_animal(A) && A.stat != DEAD)
			choices += A
	if (!choices.len)
		to_chat(user, SPAN_WARNING("There is no horse or ox next to \the [src]."))
		return
	var/mob/living/simple_animal/pick = choices[1]
	if (choices.len > 1)
		pick = WWinput(user, "Harness which animal to \the [src]?", "Harness Animal", choices[1], choices)
	if (pick)
		player_harness(user, pick)

/////////////////////////////////////////////////////////////////////////////
// Wooden rails

/obj/item/stack/rail_lengths/wooden
	name = "wooden rails"
	singular_name = "pair of wooden rails"
	desc = "Two squared timber rails, enough for one tile of wagonway. Lay them on railway sleepers and spike them down with a hammer. They carry hand cars and wagons drawn by animals; an engine soon wears them out."
	color = WOODEN_RAIL_COLOR
	force = 6
	throwforce = 5
	flags = 0

/obj/structure/rails
	var/wooden = FALSE // timber rails: a wagonway

// Makes this tile wooden or iron track, and shows it.
/obj/structure/rails/proc/set_wooden(state)
	wooden = !!state
	color = wooden ? WOODEN_RAIL_COLOR : initial(color)
	name = wooden ? "wagonway" : initial(name)

#undef HANDCAR_PUMP_TIME
#undef HANDCAR_CREW_TIME
#undef HANDCAR_PUSH
#undef HANDCAR_SPEED
#undef HANDCAR_CREW_SPEED
#undef HANDCAR_LOAD
#undef TRAIN_DRAFT_LOAD
#undef TRAIN_DRAFT_SLACK
#undef TRAIN_HARNESS_TIME
