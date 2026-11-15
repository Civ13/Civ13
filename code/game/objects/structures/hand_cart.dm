// ============================================================
// Hand carts: the wheeled carts people pull by hand
// ------------------------------------------------------------
// A cart turns its handles toward whoever pulls it, and its load decides how
// much it slows them: an empty cart rolls more easily than other furniture,
// a full one drags. Cargo is weighed the way a carriage weighs it.
// ============================================================

#define HAND_CART_EMPTY_DRAG 0.35
#define HAND_CART_LOAD_PER_DRAG 40
#define HAND_CART_MAX_DRAG 3
#define HAND_CART_PERSON_WEIGHT 70

// How much pulling this slows the puller, in move delay.
/obj/structure/proc/drag_delay(mob/puller)
	return 0.75

/obj/structure/closet/crate/cart
	dir = WEST

/obj/structure/closet/crate/cart/proc/cart_load()
	. = carriage_cargo_weight(src)
	for (var/mob/living/L in contents)
		. += HAND_CART_PERSON_WEIGHT

/obj/structure/closet/crate/cart/drag_delay(mob/puller)
	return min(HAND_CART_MAX_DRAG, HAND_CART_EMPTY_DRAG + cart_load() / HAND_CART_LOAD_PER_DRAG)

/obj/structure/closet/crate/cart/Move(newloc, direct)
	var/turf/old = loc
	var/old_dir = dir
	. = ..()
	if (. && isturf(loc) && loc != old)
		face_puller(old)
	else if (dir != old_dir)
		// A blocked pull does not swing the handles round.
		set_dir(old_dir)

// The handles point at the puller; going round a corner they follow the step.
/obj/structure/closet/crate/cart/proc/face_puller(turf/old)
	var/moved = isturf(old) ? get_dir(old, loc) : 0
	var/want = (pulledby && pulledby.z == z) ? get_dir(src, pulledby) : moved
	if (!(want in cardinal))
		if (moved in cardinal)
			want = moved
		else
			want &= (EAST|WEST)
	if (want in cardinal)
		set_dir(want)

/obj/structure/closet/crate/cart/examine(mob/user)
	. = ..()
	var/drag = drag_delay(user)
	if (drag >= HAND_CART_MAX_DRAG)
		to_chat(user, "It is loaded about as heavily as anyone can pull.")
	else if (drag >= 1.5)
		to_chat(user, "It is heavy to pull.")
	else if (drag > HAND_CART_EMPTY_DRAG)
		to_chat(user, "It rolls along easily.")

#undef HAND_CART_EMPTY_DRAG
#undef HAND_CART_LOAD_PER_DRAG
#undef HAND_CART_MAX_DRAG
#undef HAND_CART_PERSON_WEIGHT
