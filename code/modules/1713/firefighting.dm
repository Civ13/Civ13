// Firefighting hand tools. Fires (/obj/effect/fire in oil_fires.dm) spread
// across grass and wood on their own; these give every age an answer.
//
// Fire beater: a leafy green branch. Click a fire next to you to beat at it.
// Fire flapper: a hide flap lashed to a pole, better odds and far tougher.
// Both work better wet: dip them in open water, a well or a container of
// water. A pelt, hide, leather or cloth in hand can smother a fire too, badly.

#define FIRE_BEAT_COOLDOWN 8
#define FIRE_BEATER_WET_WATER 5 // water taken from a container to wet a beater
#define FIRE_SMOTHER_CHANCE 30
#define FIRE_SMOTHER_SCORCH_CHANCE 25

/obj/item/weapon/fire_beater
	name = "fire beater"
	desc = "A leafy green branch for beating out ground fires. Dip it in water first: a wet beater works far better and lasts longer."
	icon = 'icons/obj/firefighting.dmi'
	icon_state = "fire_beater"
	item_state = "fire_beater"
	item_icons = list(
		slot_l_hand_str = 'icons/obj/firefighting.dmi',
		slot_r_hand_str = 'icons/obj/firefighting.dmi',
		)
	item_state_slots = list(
		slot_l_hand_str = "fire_beater_l",
		slot_r_hand_str = "fire_beater_r",
		)
	force = WEAPON_FORCE_HARMLESS
	throwforce = WEAPON_FORCE_HARMLESS
	w_class = ITEM_SIZE_LARGE
	attack_verb = list("swatted", "beaten", "whacked")
	flammable = TRUE
	var/base_state = "fire_beater"
	var/dry_chance = 50 // chance per swing to put a fire out
	var/wet_chance = 85
	var/wet_capacity = 6 // swings one soaking lasts
	var/wet_swings = 0
	var/uses_left = 30
	var/dry_wear = 3 // a dry beater scorches; a wet one wears by one per swing
	var/tmp/next_beat = 0

/obj/item/weapon/fire_beater/flapper
	name = "fire flapper"
	desc = "A hide flap lashed to a pole, for smothering ground fires. Soak it in water first: a wet flap rarely fails."
	icon_state = "fire_flapper"
	item_state = "fire_flapper"
	item_state_slots = list(
		slot_l_hand_str = "fire_flapper_l",
		slot_r_hand_str = "fire_flapper_r",
		)
	attack_verb = list("swatted", "slapped", "whacked")
	base_state = "fire_flapper"
	dry_chance = 65
	wet_chance = 95
	wet_capacity = 10
	uses_left = 90
	dry_wear = 2

/obj/item/weapon/fire_beater/persistence_runtime_var(key)
	return key == "next_beat" || ..()

/obj/item/weapon/fire_beater/after_load()
	. = ..()
	update_icon()

/obj/item/weapon/fire_beater/update_icon()
	..()
	icon_state = wet_swings > 0 ? "[base_state]_wet" : base_state

/obj/item/weapon/fire_beater/examine(mob/user, distance = -1)
	. = ..()
	if (wet_swings > 0)
		to_chat(user, SPAN_NOTICE("It is dripping wet."))
	else
		to_chat(user, SPAN_NOTICE("It is dry. Dip it in water to make it work better."))
	if (uses_left <= initial(uses_left) / 3)
		to_chat(user, SPAN_WARNING("It is badly scorched and will not last much longer."))

// A swing either way: the odds this swing, and what it costs the tool.
/obj/item/weapon/fire_beater/proc/swing_chance()
	return wet_swings > 0 ? wet_chance : dry_chance

/obj/item/weapon/fire_beater/proc/spend_swing(mob/user)
	var/was_wet = wet_swings > 0
	uses_left -= was_wet ? 1 : dry_wear
	if (was_wet)
		wet_swings--
		if (wet_swings <= 0)
			update_icon()
			if (user && uses_left > 0)
				to_chat(user, SPAN_WARNING("\The [src] has dried out."))
	if (uses_left <= 0)
		if (user)
			to_chat(user, SPAN_WARNING("\The [src] falls apart, charred through."))
		qdel(src)

/obj/item/weapon/fire_beater/proc/ready_to_beat(mob/user)
	if (world.time < next_beat)
		return FALSE
	next_beat = world.time + FIRE_BEAT_COOLDOWN
	if (user)
		user.setClickCooldown(FIRE_BEAT_COOLDOWN)
	return TRUE

// Returns TRUE when the fire went out.
/obj/item/weapon/fire_beater/proc/beat_fire(obj/effect/fire/F, mob/user)
	if (QDELETED(F) || !ready_to_beat(user))
		return FALSE
	var/turf/T = get_turf(F)
	if (user)
		user.do_attack_animation(F)
	playsound(T, 'sound/weapons/thudswoosh.ogg', 50, TRUE)
	var/out = prob(swing_chance())
	if (out)
		if (user)
			user.visible_message(SPAN_NOTICE("[user] beats out the fire with \the [src]."), SPAN_NOTICE("You beat out the fire with \the [src]."))
		playsound(T, 'sound/items/cig_snuff.ogg', 50, TRUE)
		qdel(F)
	else if (user)
		to_chat(user, SPAN_WARNING("You beat at the flames with \the [src], but they flare back up."))
	spend_swing(user)
	return out

// Beating the flames off a burning person. Returns TRUE when they are out.
/obj/item/weapon/fire_beater/proc/beat_mob(mob/living/L, mob/user)
	if (QDELETED(L) || !L.on_fire || !ready_to_beat(user))
		return FALSE
	if (user)
		user.do_attack_animation(L)
	playsound(get_turf(L), 'sound/weapons/thudswoosh.ogg', 50, TRUE)
	L.adjust_fire_stacks(wet_swings > 0 ? -4 : -2)
	var/out = L.fire_stacks <= 0
	if (out)
		L.ExtinguishMob()
		if (user)
			user.visible_message(SPAN_NOTICE("[user] beats the flames off [L] with \the [src]."), SPAN_NOTICE("You beat the flames off [L] with \the [src]."))
	else if (user)
		user.visible_message(SPAN_NOTICE("[user] beats at the flames on [L] with \the [src]."), SPAN_NOTICE("You beat at the flames on [L] with \the [src]. Keep going!"))
	spend_swing(user)
	return out

/obj/item/weapon/fire_beater/proc/soak(mob/user, atom/source)
	if (wet_swings >= wet_capacity)
		if (user)
			to_chat(user, SPAN_NOTICE("\The [src] is already soaked."))
		return FALSE
	wet_swings = wet_capacity
	update_icon()
	playsound(get_turf(src), 'sound/effects/watersplash.ogg', 60, TRUE)
	if (user)
		to_chat(user, SPAN_NOTICE("You soak \the [src] in \the [source]."))
	return TRUE

// What can wet a beater: open water, a well, sink or puddle that is not dry,
// or an open container holding enough water.
/obj/item/weapon/fire_beater/proc/try_soak(atom/A, mob/user)
	if (istype(A, /turf/floor/beach/water))
		soak(user, A)
		return TRUE
	if (istype(A, /obj/structure/sink))
		var/obj/structure/sink/S = A
		if (S.dry || S.volume <= 0)
			return FALSE // let the sink say it is dry
		if (soak(user, S))
			S.volume = max(0, S.volume - FIRE_BEATER_WET_WATER)
		return TRUE
	if (istype(A, /obj/item/weapon/reagent_containers))
		var/obj/item/weapon/reagent_containers/RC = A
		if (!RC.is_open_container() || !RC.reagents || RC.reagents.get_reagent_amount("water") < FIRE_BEATER_WET_WATER)
			return FALSE
		if (soak(user, RC))
			RC.reagents.remove_reagent("water", FIRE_BEATER_WET_WATER)
		return TRUE
	return FALSE

/obj/item/weapon/fire_beater/resolve_attackby(atom/A, mob/user, icon_x, icon_y)
	if (istype(A, /obj/effect/fire))
		beat_fire(A, user)
		return TRUE
	if (isliving(A))
		var/mob/living/L = A
		if (L.on_fire && user.a_intent != I_HARM)
			beat_mob(L, user)
			return TRUE
		return ..()
	// A fire hidden under something else on the tile still gets beaten.
	var/turf/T = isturf(A) ? A : null
	var/obj/effect/fire/F = T ? (locate(/obj/effect/fire) in T) : null
	if (F)
		beat_fire(F, user)
		return TRUE
	if (try_soak(A, user))
		return TRUE
	return ..()

// Smothering with whatever hide or cloth is in hand: poor odds, no knowledge
// needed, and the top piece may scorch away.
/proc/smother_fire_with_stack(obj/item/stack/S, obj/effect/fire/F, mob/user)
	if (QDELETED(S) || QDELETED(F) || !user)
		return FALSE
	user.setClickCooldown(FIRE_BEAT_COOLDOWN)
	user.do_attack_animation(F)
	playsound(get_turf(F), 'sound/weapons/thudswoosh.ogg', 50, TRUE)
	var/out = prob(FIRE_SMOTHER_CHANCE)
	if (out)
		user.visible_message(SPAN_NOTICE("[user] smothers the fire with \the [S]."), SPAN_NOTICE("You smother the fire with \the [S]."))
		playsound(get_turf(F), 'sound/items/cig_snuff.ogg', 50, TRUE)
		qdel(F)
	else
		to_chat(user, SPAN_WARNING("You flap \the [S] at the flames, but they flare back up. A fire beater would do better."))
	if (prob(FIRE_SMOTHER_SCORCH_CHANCE))
		to_chat(user, SPAN_WARNING("\The [S] scorches in the flames!"))
		S.use(1)
	return out

/obj/item/stack/material/pelt/resolve_attackby(atom/A, mob/user, icon_x, icon_y)
	if (istype(A, /obj/effect/fire))
		smother_fire_with_stack(src, A, user)
		return TRUE
	return ..()

/obj/item/stack/material/leather/resolve_attackby(atom/A, mob/user, icon_x, icon_y)
	if (istype(A, /obj/effect/fire))
		smother_fire_with_stack(src, A, user)
		return TRUE
	return ..()

/obj/item/stack/material/cloth/resolve_attackby(atom/A, mob/user, icon_x, icon_y)
	if (istype(A, /obj/effect/fire))
		smother_fire_with_stack(src, A, user)
		return TRUE
	return ..()

#undef FIRE_BEAT_COOLDOWN
#undef FIRE_BEATER_WET_WATER
#undef FIRE_SMOTHER_CHANCE
#undef FIRE_SMOTHER_SCORCH_CHANCE
