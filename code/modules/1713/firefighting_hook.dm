// Fire hook: a long pole with an iron spike and hook, for pulling down what
// burns before the fire reaches it. It tears down flammable roofs, walls and
// floors and rips out brush, leaving a firebreak. Pulling a building apart is
// slow unless a fire is close, so it is a firefighting tool before it is a
// demolition tool. Stone, brick and metal are beyond it, and so are trees.

#define FIRE_HOOK_URGENT_RANGE 3 // a fire this close makes the work urgent
#define FIRE_HOOK_CALM_FACTOR 3 // how much slower the work is with no fire near
#define FIRE_HOOK_TIME_BRUSH 15
#define FIRE_HOOK_TIME_ROOF 25
#define FIRE_HOOK_TIME_FLOOR 30
#define FIRE_HOOK_TIME_WALL 50

/obj/item/weapon/fire_hook
	name = "fire hook"
	desc = "A long pole with an iron spike and hook, for pulling down burning thatch, timber walls and roofs before a fire spreads. It works fastest with a fire close by."
	icon = 'icons/obj/firefighting.dmi'
	icon_state = "fire_hook"
	item_state = "fire_hook"
	item_icons = list(
		slot_l_hand_str = 'icons/obj/firefighting.dmi',
		slot_r_hand_str = 'icons/obj/firefighting.dmi',
		)
	item_state_slots = list(
		slot_l_hand_str = "fire_hook_l",
		slot_r_hand_str = "fire_hook_r",
		)
	force = WEAPON_FORCE_NORMAL
	throwforce = WEAPON_FORCE_HARMLESS
	w_class = ITEM_SIZE_LARGE
	sharp = TRUE
	attack_verb = list("hooked", "jabbed", "gouged")
	flags = CONDUCT
	var/tmp/hooking = FALSE

/obj/item/weapon/fire_hook/persistence_runtime_var(key)
	return key == "hooking" || ..()

// What the hook can pull down, and the base time it takes. 0 means it cannot.
/proc/fire_hook_base_time(atom/A)
	if (istype(A, /obj/roof))
		var/obj/roof/R = A
		return R.flammable ? FIRE_HOOK_TIME_ROOF : 0
	if (istype(A, /obj/covers))
		var/obj/covers/C = A
		if (!C.flammable || C.invisibility)
			return 0
		return (C.wall || C.density) ? FIRE_HOOK_TIME_WALL : FIRE_HOOK_TIME_FLOOR
	if (istype(A, /obj/structure/wild/bush) || istype(A, /obj/structure/wild/junglebush) || istype(A, /obj/structure/wild/smallbush) || istype(A, /obj/structure/wild/tallgrass))
		var/obj/structure/wild/W = A
		return W.flammable ? FIRE_HOOK_TIME_BRUSH : 0
	return 0

/proc/fire_hook_fire_near(atom/A)
	var/turf/T = get_turf(A)
	if (!T)
		return FALSE
	for (var/obj/effect/fire/F in range(FIRE_HOOK_URGENT_RANGE, T))
		return TRUE
	return FALSE

/proc/fire_hook_time(atom/A)
	var/base = fire_hook_base_time(A)
	if (!base)
		return 0
	return fire_hook_fire_near(A) ? base : base * FIRE_HOOK_CALM_FACTOR

// Tears the target down. A pulled-down wall or floor gives back half its
// material, and nothing if it was already burning. Returns TRUE when it went.
/obj/item/weapon/fire_hook/proc/pull_down(atom/A, mob/user)
	if (QDELETED(A) || !fire_hook_base_time(A))
		return FALSE
	var/turf/T = get_turf(A)
	if (istype(A, /obj/covers))
		var/obj/covers/C = A
		var/salvage = round(C.buildstackamount / 2)
		if (ispath(C.buildstack, /obj/item/stack) && salvage > 0 && !C.onfire && !(locate(/obj/effect/fire) in T))
			new C.buildstack(T, salvage)
	if (user)
		user.visible_message(SPAN_WARNING("[user] pulls down \the [A] with \the [src]!"), SPAN_NOTICE("You pull down \the [A] with \the [src]."))
	playsound(T, 'sound/effects/wood_cutting.ogg', 100, TRUE)
	qdel(A)
	return TRUE

/obj/item/weapon/fire_hook/proc/hook_target(atom/A, mob/user)
	var/time = fire_hook_time(A)
	if (!time || hooking)
		return FALSE
	hooking = TRUE
	user.visible_message(SPAN_WARNING("[user] sets \the [src] into \the [A] and starts pulling it down."), SPAN_NOTICE("You set \the [src] into \the [A] and start pulling it down.[time > fire_hook_base_time(A) ? " With no fire close by, this is slow work." : ""]"))
	playsound(get_turf(A), 'sound/effects/wood_cutting.ogg', 60, TRUE)
	var/done = do_after(user, time, A)
	hooking = FALSE
	if (!done || QDELETED(src) || QDELETED(A) || user.get_active_hand() != src)
		return TRUE
	pull_down(A, user)
	return TRUE

/obj/item/weapon/fire_hook/resolve_attackby(atom/A, mob/user, icon_x, icon_y)
	if (user.a_intent != I_HARM && fire_hook_base_time(A))
		if (hooking)
			return TRUE
		hook_target(A, user)
		return TRUE
	// Clicking a roofed tile's ground reaches for the flammable roof over it.
	if (isturf(A) && user.a_intent != I_HARM)
		var/turf/T = A
		for (var/obj/roof/R in T)
			if (fire_hook_base_time(R))
				if (!hooking)
					hook_target(R, user)
				return TRUE
	return ..()

#undef FIRE_HOOK_URGENT_RANGE
#undef FIRE_HOOK_CALM_FACTOR
#undef FIRE_HOOK_TIME_BRUSH
#undef FIRE_HOOK_TIME_ROOF
#undef FIRE_HOOK_TIME_FLOOR
#undef FIRE_HOOK_TIME_WALL
