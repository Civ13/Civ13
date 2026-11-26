// ============================================================
// Hitching a hand cart behind a horse, an ox or a carriage
// ------------------------------------------------------------
// A cart hitched to an animal rolls into the tile the animal leaves, so it
// trails a ridden or led horse like a pulled cart trails a person. A cart
// hitched to a carriage rolls centred behind the carriage's rear wheels and
// follows its steps and turns. Its load slows the leader: a mount by the
// cart's drag shared out over the animal's pull, a carriage by its weight.
//
// Hitch with the cart's Hitch Cart verb next to the leader, by dragging the
// cart onto a horse or an ox, or by dragging a cart standing right behind a
// carriage onto it. A hitched cart cannot be pulled or pushed by hand; it
// comes loose when it is left too far behind or cannot follow.
//
// Hitches are not saved: carts stand where they were after a restart.
// ============================================================

// A cart left further behind than this comes loose.
#define CART_HITCH_SLACK 2

/mob/living/simple_animal
	var/tmp/obj/structure/closet/crate/cart/hitched_cart = null

/obj/structure/vehicle/carriage
	var/tmp/obj/structure/closet/crate/cart/hitched_cart = null

/obj/structure/closet/crate/cart
	var/tmp/atom/movable/hitched_to = null

/mob/living/simple_animal/persistence_runtime_var(key)
	return key == "hitched_cart" || key == "hitched_train" || ..()

/obj/structure/closet/crate/cart/persistence_runtime_var(key)
	return key == "hitched_to" || ..()

// ---- What a cart may hitch to ----

// Why this cart cannot be hitched to leader (a sentence), or null.
/obj/structure/closet/crate/cart/proc/hitch_refusal(atom/movable/leader)
	if (QDELETED(src) || !isturf(loc))
		return "\The [src] has to stand on the ground."
	if (anchored)
		return "\The [src] is fixed in place."
	if (istype(leader, /obj/structure/vehicle/carriage))
		var/obj/structure/vehicle/carriage/C = leader
		if (QDELETED(C) || !isturf(C.loc))
			return "There is nothing to hitch to."
		if (C.hitched_cart && C.hitched_cart != src)
			return "\The [C] already has a cart behind it."
		if (C.is_aboard(src))
			return "Take \the [src] off \the [C] first."
		var/turf/T = C.hitch_turf(C.facing)
		if (!T || get_dist(src, T) > 1 || z != T.z)
			return "Bring \the [src] round behind \the [C] first."
		if (loc != T && !cart_hitch_cell_clear(T, src, C))
			return "There is no room behind \the [C]."
		return null
	if (istype(leader, /mob/living/simple_animal))
		var/mob/living/simple_animal/A = leader
		if (!is_draft_animal(A) || A.stat == DEAD)
			return "\The [A] cannot pull a cart."
		if (A.buckled)
			return "\The [A] is already in harness."
		if (A.hitched_cart && A.hitched_cart != src)
			return "\The [A] already pulls a cart."
		if (A.hitched_train)
			return "\The [A] is harnessed to a rail wagon."
		if (!isturf(A.loc) || A.z != z || get_dist(src, A) > 1)
			return "\The [src] has to stand next to \the [A]."
		return null
	return "\The [src] can only be hitched behind a horse, an ox or a carriage."

// TRUE when a cart can roll onto T: no wall or dense structure, ignoring the
// cart itself and the carriage it follows (and everything aboard it).
/proc/cart_hitch_cell_clear(turf/T, obj/structure/closet/crate/cart/cart, atom/movable/leader)
	if (!T || T.density)
		return FALSE
	if (istype(T, /turf/floor/beach/water/deep))
		var/bridged = FALSE
		for (var/obj/covers/CV in T)
			if (!CV.density && !CV.wall)
				bridged = TRUE
		if (!bridged)
			return FALSE
	var/obj/structure/vehicle/carriage/C = istype(leader, /obj/structure/vehicle/carriage) ? leader : null
	for (var/obj/O in T)
		if (O == cart || O == leader || !O.density)
			continue
		if (C && C.is_aboard(O))
			continue
		if (istype(O, /obj/structure) || istype(O, /obj/covers))
			return FALSE
	return TRUE

// ---- Hitching and unhitching ----

/obj/structure/closet/crate/cart/proc/hitch_to(atom/movable/leader)
	if (hitch_refusal(leader))
		return FALSE
	if (hitched_to)
		unhitch()
	if (pulledby)
		pulledby.stop_pulling()
	hitched_to = leader
	if (istype(leader, /obj/structure/vehicle/carriage))
		var/obj/structure/vehicle/carriage/C = leader
		C.hitched_cart = src
	else
		var/mob/living/simple_animal/A = leader
		A.hitched_cart = src
	GLOB.moved_event.register(leader, src, /obj/structure/closet/crate/cart/proc/leader_moved)
	GLOB.destroyed_event.register(leader, src, /obj/structure/closet/crate/cart/proc/leader_gone)
	follow_leader()
	return hitched_to == leader

// Lets go of the leader, leaving the cart where it stands. With a reason, the
// people around are told why it came loose.
/obj/structure/closet/crate/cart/proc/unhitch(reason = null)
	var/atom/movable/leader = hitched_to
	if (!leader)
		return FALSE
	hitched_to = null
	GLOB.moved_event.unregister(leader, src, /obj/structure/closet/crate/cart/proc/leader_moved)
	GLOB.destroyed_event.unregister(leader, src, /obj/structure/closet/crate/cart/proc/leader_gone)
	if (istype(leader, /obj/structure/vehicle/carriage))
		var/obj/structure/vehicle/carriage/C = leader
		if (C.hitched_cart == src)
			C.hitched_cart = null
	else if (istype(leader, /mob/living/simple_animal))
		var/mob/living/simple_animal/A = leader
		if (A.hitched_cart == src)
			A.hitched_cart = null
	pixel_x = initial(pixel_x)
	pixel_y = initial(pixel_y)
	glide_size = initial(glide_size)
	if (reason && !QDELETED(src) && isturf(loc))
		visible_message(SPAN_WARNING("\The [src] comes loose from \the [leader]: [reason]."))
	return TRUE

/obj/structure/closet/crate/cart/proc/leader_gone(atom/movable/leader)
	if (leader == hitched_to)
		unhitch()

/obj/structure/closet/crate/cart/proc/leader_moved(atom/movable/leader, atom/old_loc, atom/new_loc)
	if (leader != hitched_to)
		return
	follow_leader(isturf(old_loc) ? old_loc : null)

// Puts the cart where it belongs behind its leader, or lets it go.
// A carriage turning in place swings its cart round, however far it goes.
/obj/structure/closet/crate/cart/proc/follow_leader(turf/left = null, swing = FALSE)
	var/atom/movable/leader = hitched_to
	if (!leader || QDELETED(src) || !isturf(loc))
		unhitch()
		return FALSE
	if (QDELETED(leader) || !isturf(leader.loc) || leader.z != z)
		unhitch("it was left behind")
		return FALSE
	if (istype(leader, /obj/structure/vehicle/carriage))
		var/obj/structure/vehicle/carriage/C = leader
		var/turf/T = C.hitch_turf(C.facing)
		if (!T || (!swing && get_dist(src, T) > CART_HITCH_SLACK))
			unhitch("it was left behind")
			return FALSE
		if (loc != T)
			if (!cart_hitch_cell_clear(T, src, C))
				unhitch("there is no room for it behind \the [C]")
				return FALSE
			glide_size = C.glide_size
			forceMove(T)
		set_dir(C.facing)
		var/list/shift = carriage_hitch_shift(C.facing)
		pixel_x = shift[1]
		pixel_y = shift[2]
		return TRUE
	var/mob/living/simple_animal/A = leader
	if (A.stat == DEAD)
		unhitch("\the [A] is dead")
		return FALSE
	var/turf/L = get_turf(A)
	if (get_dist(src, L) > 1 || loc == L)
		var/turf/T = left
		if (!T || T == L || get_dist(T, L) > 1 || T.z != z)
			T = get_step(L, turn(A.dir, 180))
		if (!T || get_dist(src, T) > CART_HITCH_SLACK || !cart_hitch_cell_clear(T, src, A))
			if (get_dist(src, L) > CART_HITCH_SLACK || loc == L)
				unhitch("it could not follow")
				return FALSE
		else
			glide_size = A.glide_size
			forceMove(T)
	face_leader(A)
	return TRUE

// The handles point at the animal pulling the cart.
/obj/structure/closet/crate/cart/proc/face_leader(atom/movable/leader)
	var/want = get_dir(src, leader)
	if (!(want in cardinal))
		want = (want & (EAST|WEST)) || want
	if (want in cardinal)
		set_dir(want)

// How much a hitched cart slows the animal pulling it, in move delay.
/mob/living/simple_animal/proc/hitch_drag()
	// Drawing a train on rails (train_early.dm).
	if (hitched_train && hitched_train.draft_animal == src)
		return hitched_train.draft_drag(src)
	return handcart_hitch_drag()

/mob/living/simple_animal/proc/handcart_hitch_drag()
	var/obj/structure/closet/crate/cart/cart = hitched_cart
	if (!cart || QDELETED(cart) || cart.hitched_to != src)
		return 0
	return cart.drag_delay(src) / max(1, draft_animal_pull(src))

// Player movement keeps its usual pace when no hand cart follows this mount.
/mob/living/human/proc/ridden_handcart_drag()
	if (!riding || QDELETED(riding_mob) || riding_mob.rider != src)
		return 0
	return riding_mob.handcart_hitch_drag()

// ---- The carriage end ----

// The tile centred behind a carriage's rear wheels when it faces that way:
// the cart stands on the left one of the two tiles and is drawn half a tile
// across.
/obj/structure/vehicle/carriage/proc/hitch_turf(way)
	if (!isturf(loc))
		return null
	switch (way)
		if (NORTH) return locate(x, y - 1, z)
		if (SOUTH) return locate(x, y + 3, z)
		if (EAST) return locate(x - 1, y, z)
		if (WEST) return locate(x + 3, y, z)
	return null

/proc/carriage_hitch_shift(way)
	if (way == NORTH || way == SOUTH)
		return list(world.icon_size / 2, 0)
	return list(0, world.icon_size / 2)

// What a hitched cart adds to the weight the team draws.
/obj/structure/vehicle/carriage/proc/hitched_cart_weight()
	var/obj/structure/closet/crate/cart/cart = hitched_cart
	if (!cart || QDELETED(cart) || cart.hitched_to != src)
		return 0
	return 30 + cart.cart_load()

// ---- Moves of the cart itself ----

// A hitched cart goes only where its leader takes it.
/obj/structure/closet/crate/cart/Move(newloc, direct)
	if (hitched_to)
		if (pulledby)
			pulledby.stop_pulling()
		return FALSE
	return ..()

/obj/structure/closet/crate/cart/Destroy()
	unhitch()
	return ..()

/mob/living/simple_animal/Destroy()
	if (hitched_cart)
		hitched_cart.unhitch()
	return ..()

/obj/structure/closet/crate/cart/examine(mob/user)
	. = ..()
	if (hitched_to)
		to_chat(user, "It is hitched behind \the [hitched_to]. Use Unhitch Cart to let it go.")
	else
		to_chat(user, "Hitch Cart, or dragging it onto a horse or an ox, hitches it behind the animal. Drag it onto a carriage from right behind it to hitch it there.")

// ---- Player actions ----

/obj/structure/closet/crate/cart/proc/player_hitch(mob/living/human/user, atom/movable/leader)
	if (!istype(user) || user.incapacitated() || !Adjacent(user))
		return FALSE
	var/why = hitch_refusal(leader)
	if (why)
		to_chat(user, SPAN_WARNING(why))
		return FALSE
	user.visible_message(SPAN_NOTICE("[user] starts hitching \the [src] behind \the [leader]..."), SPAN_NOTICE("You start hitching \the [src] behind \the [leader]..."))
	if (!do_after(user, 30, src) || !Adjacent(user))
		return FALSE
	why = hitch_refusal(leader)
	if (why)
		to_chat(user, SPAN_WARNING(why))
		return FALSE
	if (!hitch_to(leader))
		return FALSE
	user.visible_message(SPAN_NOTICE("[user] hitches \the [src] behind \the [leader]."), SPAN_NOTICE("You hitch \the [src] behind \the [leader]. It follows wherever \the [leader] goes."))
	log_game("[key_name(user)] hitched [src] behind [leader] at [x],[y],[z].")
	return TRUE

/obj/structure/closet/crate/cart/verb/hitch_cart_verb()
	set category = null
	set name = "Hitch Cart"
	set desc = "Hitch this cart behind a horse, an ox or a carriage next to it."
	set src in view(1)
	var/mob/living/human/user = usr
	if (!istype(user) || user.incapacitated() || !Adjacent(user))
		return
	var/list/choices = list()
	for (var/mob/living/simple_animal/A in orange(1, src))
		if (is_draft_animal(A) && A.stat != DEAD && !A.buckled)
			choices += A
	for (var/obj/structure/vehicle/carriage/C in range(3, src))
		var/turf/T = C.hitch_turf(C.facing)
		if (T && get_dist(src, T) <= 1)
			choices += C
	if (!choices.len)
		to_chat(user, SPAN_WARNING("There is no horse, ox or carriage to hitch \the [src] to. Bring it next to an animal, or round behind a carriage."))
		return
	var/atom/movable/leader = choices[1]
	if (choices.len > 1)
		leader = WWinput(user, "Hitch \the [src] behind what?", "Hitch Cart", choices[1], choices)
	if (leader)
		player_hitch(user, leader)

/obj/structure/closet/crate/cart/verb/unhitch_cart_verb()
	set category = null
	set name = "Unhitch Cart"
	set desc = "Unhitch this cart from whatever pulls it."
	// A carriage's riders sit on its front corner, up to three tiles away.
	set src in view(3)
	var/mob/living/human/user = usr
	if (!istype(user) || user.incapacitated() || !hitched_to)
		return
	var/atom/movable/leader = hitched_to
	var/obj/structure/vehicle/carriage/C = istype(leader, /obj/structure/vehicle/carriage) ? leader : null
	if (!Adjacent(user) && !(user.riding && user.riding_mob == leader) && !(C && C.is_aboard(user)))
		return
	unhitch()
	user.visible_message(SPAN_NOTICE("[user] unhitches \the [src] from \the [leader]."), SPAN_NOTICE("You unhitch \the [src] from \the [leader]."))

// Dragging a cart onto a horse or an ox hitches it behind the animal.
/mob/living/simple_animal/MouseDrop_T(atom/movable/M, mob/living/human/user)
	if (istype(M, /obj/structure/closet/crate/cart) && istype(user))
		var/obj/structure/closet/crate/cart/cart = M
		if (Adjacent(user) || cart.Adjacent(user))
			cart.player_hitch(user, src)
		return
	// A rail wagon dragged onto the animal: harnessed to draw it (train_early.dm).
	if (istype(M, /obj/structure/trains) && istype(user))
		var/obj/structure/trains/car = M
		car.player_harness(user, src)
		return
	return ..()

#undef CART_HITCH_SLACK
