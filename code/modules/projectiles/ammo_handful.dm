// A handful of loose rounds, arrows or bolts carried in one hand.
// Click a round with another of the same kind to start a handful; click more
// rounds (in hand or on the floor) with it to add them. With an empty hand,
// click the handful in your other hand to take one out. Click a gun, bow or
// magazine with it to load from it. Use it in hand to tighten your grip:
// a tight grip survives falls, stuns and most blows, but must be loosened
// before you can take rounds out or add more. A loose handful scatters when
// you are knocked down or struck on that hand.

// How many of this round fit in one hand; 0 means it can't be carried that way.
/obj/item/ammo_casing/var/handful_max = null

/obj/item/ammo_casing/proc/handful_capacity()
	if (!isnull(handful_max))
		return handful_max
	if (w_class > ITEM_SIZE_SMALL || weight >= 0.5)
		return 0
	if (weight <= 0.1)
		return 10 // cartridges, musket balls, shells
	if (weight <= 0.2)
		return 6 // arrows and bolts
	return 3 // atlatl darts, sling stones

// Only live rounds and reusable shots (arrows, balls) go in a handful; spent
// brass has its own stacks (handloading.dm).
/obj/item/ammo_casing/proc/handful_compatible(obj/item/ammo_casing/other)
	if (!other || other == src || other.type != type || other.btype != btype)
		return FALSE
	if (!handful_capacity())
		return FALSE
	return handful_loose_round() && other.handful_loose_round()

/obj/item/ammo_casing/proc/handful_loose_round()
	return BB || !spent_icon

/obj/item/ammo_handful
	name = "handful of rounds"
	desc = "A handful of loose rounds."
	icon = 'icons/obj/ammo.dmi'
	icon_state = "rifle-casing"
	w_class = ITEM_SIZE_SMALL
	slot_flags = 0
	throwforce = 1
	flags = CONDUCT
	grip_tightenable = TRUE
	jostle_drop_chance = 75

/obj/item/ammo_handful/proc/rounds()
	. = list()
	for (var/obj/item/ammo_casing/C in contents)
		. += C

/obj/item/ammo_handful/proc/top_round()
	for (var/obj/item/ammo_casing/C in contents)
		return C
	return null

/obj/item/ammo_handful/proc/round_count()
	. = 0
	for (var/obj/item/ammo_casing/C in contents)
		.++

/obj/item/ammo_handful/proc/capacity()
	var/obj/item/ammo_casing/C = top_round()
	return C ? C.handful_capacity() : 0

/obj/item/ammo_handful/proc/accepts(obj/item/ammo_casing/C)
	if (!istype(C) || C.loc == src)
		return FALSE
	var/obj/item/ammo_casing/top = top_round()
	if (!top)
		return C.handful_capacity() > 0 && C.handful_loose_round()
	return top.handful_compatible(C) && round_count() < capacity()

// Moves C (on the floor nearby, or in user's hands) into the handful.
/obj/item/ammo_handful/proc/take_in(obj/item/ammo_casing/C, mob/user)
	if (!accepts(C))
		return FALSE
	if (user && C.held_by(user))
		user.remove_from_mob(C)
	else if (!isturf(C.loc))
		return FALSE
	C.forceMove(src)
	C.transform = null
	C.pixel_x = 0
	C.pixel_y = 0
	return TRUE

/obj/item/ammo_handful/proc/update_handful()
	var/list/held = rounds()
	if (!held.len)
		qdel(src)
		return
	var/obj/item/ammo_casing/top = held[1]
	icon = top.icon
	icon_state = top.icon_state
	name = "handful of [top.name] ([held.len])"
	desc = "[held.len] loose [top.name]\s held together in one hand."
	var/total = 0
	for (var/obj/item/ammo_casing/C in held)
		total += C.weight
	weight = total
	overlays.Cut()
	var/static/list/offsets = list(list(-3, 2), list(3, -2), list(-1, -4), list(2, 4))
	for (var/i in 1 to min(held.len - 1, offsets.len))
		var/list/xy = offsets[i]
		var/image/I = image(top.icon, top.icon_state)
		I.pixel_x = xy[1]
		I.pixel_y = xy[2]
		overlays += I
	if (ismob(loc))
		var/mob/M = loc
		M.update_inv_l_hand(0)
		M.update_inv_r_hand(0)

// When one round is left in a hand or on the floor, it goes back to being a
// plain round where the handful was.
/obj/item/ammo_handful/proc/settle(mob/user)
	var/list/held = rounds()
	if (held.len != 1)
		update_handful()
		return
	var/obj/item/ammo_casing/C = held[1]
	if (isturf(loc))
		C.forceMove(loc)
		qdel(src)
		return
	var/mob/M = loc
	if (!ismob(M) || !held_by(M))
		update_handful()
		return
	var/left = M.l_hand == src
	M.remove_from_mob(src)
	C.forceMove(M.loc)
	if (!(left ? M.put_in_l_hand(C) : M.put_in_r_hand(C)))
		M.put_in_hands(C)
	qdel(src)

/obj/item/ammo_handful/examine(mob/user)
	..()
	if (grip_tightened && held_by(user))
		to_chat(user, SPAN_NOTICE("You are holding it in a tight grip. Loosen it to take rounds out."))

/obj/item/ammo_handful/attack_self(mob/user)
	toggle_grip(user)

// An empty hand takes one round out of the handful held in the other hand.
/obj/item/ammo_handful/attack_hand(mob/user)
	if (!held_by(user) || user.get_active_hand())
		return ..()
	if (grip_blocks_access(user))
		return
	var/obj/item/ammo_casing/C = top_round()
	if (!C)
		return
	C.forceMove(user.loc)
	user.put_in_active_hand(C)
	to_chat(user, SPAN_NOTICE("You take \a [C] from \the [src]."))
	settle(user)

// Adding a round with the round in your active hand.
/obj/item/ammo_handful/attackby(obj/item/W, mob/user)
	if (!istype(W, /obj/item/ammo_casing))
		return ..()
	if (grip_blocks_access(user))
		return TRUE
	if (!accepts(W))
		to_chat(user, SPAN_WARNING(round_count() >= capacity() ? "You can't hold any more in one hand." : "\The [W] doesn't go with \the [src]."))
		return TRUE
	take_in(W, user)
	update_handful()
	return TRUE

// Clicking with the handful in your active hand.
/obj/item/ammo_handful/resolve_attackby(atom/A, mob/user, icon_x, icon_y)
	if (istype(A, /obj/item/ammo_casing))
		if (grip_blocks_access(user))
			return TRUE
		var/obj/item/ammo_casing/C = A
		if (!accepts(C))
			to_chat(user, SPAN_WARNING(round_count() >= capacity() ? "You can't hold any more in one hand." : "\The [C] doesn't go with \the [src]."))
			return TRUE
		if (isturf(C.loc) && !user.Adjacent(C))
			return TRUE
		// Scoop up every matching round on that tile, as many as fit.
		var/turf/T = isturf(C.loc) ? C.loc : null
		var/count = take_in(C, user) ? 1 : 0
		if (T)
			for (var/obj/item/ammo_casing/other in T)
				if (!take_in(other, user))
					continue
				count++
		if (count)
			to_chat(user, SPAN_NOTICE("You add [count] to \the [src]."))
		update_handful()
		return TRUE
	if (istype(A, /obj/item/weapon/gun/projectile) || istype(A, /obj/item/ammo_magazine))
		if (grip_blocks_access(user))
			return TRUE
		load_into(A, user)
		return TRUE
	return ..()

// Feeds rounds into a gun, bow or magazine through its normal loading code,
// as if each round were clicked on it by hand: a gun takes one per click, a
// magazine as many as fit.
/obj/item/ammo_handful/proc/load_into(obj/item/target, mob/user)
	var/loaded = 0
	while (TRUE)
		var/obj/item/ammo_casing/C = top_round()
		if (!C || QDELETED(src) || !held_by(user))
			break
		target.attackby(C, user)
		if (C.loc == src || C.loc == user.loc)
			if (C.loc != src)
				C.forceMove(src) // refused after all: back into the hand
			break
		loaded++
		if (!istype(target, /obj/item/ammo_magazine))
			break
	if (!QDELETED(src))
		settle(user)
	return loaded

// Knocked down or struck: the rounds scatter around the holder.
/obj/item/ammo_handful/knocked_from_hand(mob/living/human/H)
	var/turf/T = get_turf(H)
	H.remove_from_mob(src)
	scatter(T)
	return TRUE

/obj/item/ammo_handful/proc/scatter(turf/T)
	if (!T)
		T = get_turf(src)
	var/list/spots = list(T)
	for (var/turf/near in orange(1, T))
		if (!near.density)
			spots += near
	for (var/obj/item/ammo_casing/C in rounds())
		C.forceMove(prob(50) ? T : pick(spots))
		C.pixel_x = rand(-10, 10)
		C.pixel_y = rand(-10, 10)
		C.transform = matrixangle(rand(1, 360))
	qdel(src)

/obj/item/ammo_handful/after_load()
	..()
	update_handful()

/obj/item/ammo_handful/Destroy()
	// A handful never deletes the rounds it was holding.
	var/turf/T = get_turf(src)
	for (var/obj/item/ammo_casing/C in contents)
		C.forceMove(T)
	return ..()

// Clicking a round with another of the same kind starts a handful in your
// active hand.
/obj/item/ammo_casing/resolve_attackby(atom/A, mob/user, icon_x, icon_y)
	if (istype(A, /obj/item/ammo_handful))
		return A.attackby(src, user, icon_x, icon_y)
	if (istype(A, /obj/item/ammo_casing) && ishuman(user) && held_by(user))
		var/obj/item/ammo_casing/other = A
		if (handful_compatible(other) && (other.held_by(user) || isturf(other.loc) && user.Adjacent(other)))
			var/left = user.l_hand == src
			var/obj/item/ammo_handful/H = new(user.loc)
			H.take_in(src, user)
			H.take_in(other, user)
			if (!(left ? user.put_in_l_hand(H) : user.put_in_r_hand(H)))
				user.put_in_hands(H)
			H.update_handful()
			to_chat(user, SPAN_NOTICE("You gather \the [other] into a handful. Use it in hand to tighten your grip."))
			return TRUE
	return ..()
