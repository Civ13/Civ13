// Firefighting with water and wet blankets (see firefighting.dm for beaters).
//
// Water thrown on a fire: the more water, the surer. A cupful rarely works, a
// half-full bucket always does, and a full bucket also splashes the fires on
// the tiles around it and puts out anyone burning on the tile.
// Wet blanket: a bedsheet soaked in water smothers a fire tile or a burning
// person. A dry one works like any other cloth and may burn up.

#define FIRE_DOUSE_SURE_WATER 50 // units of water that always put a fire out
#define FIRE_DOUSE_SPLASH_WATER 100 // units that also splash the neighbouring tiles
#define FIRE_DOUSE_SPLASH_CHANCE 50
#define FIRE_BLANKET_SOAK_WATER 10
#define FIRE_BLANKET_WET_USES 4
#define FIRE_BLANKET_WET_CHANCE 80
#define FIRE_BLANKET_DRY_CHANCE 30
#define FIRE_BLANKET_BURN_CHANCE 25
#define FIRE_BLANKET_COOLDOWN 8

/proc/fire_douse_chance(water)
	return max(0, min(100, round(water * 100 / FIRE_DOUSE_SURE_WATER)))

// Emptying a container's water onto a fire. Returns TRUE when it was handled.
/proc/douse_fire_with_container(obj/effect/fire/F, obj/item/weapon/reagent_containers/CT, mob/user)
	if (QDELETED(F) || !istype(CT) || !CT.reagents || !CT.is_open_container())
		return FALSE
	if (istype(CT, /obj/item/weapon/reagent_containers/glass/fire_extinguisher))
		return FALSE // sprayed through its own handler in click.dm
	var/water = CT.reagents.get_reagent_amount("water")
	if (water <= 0)
		return FALSE
	var/turf/T = get_turf(F)
	CT.reagents.remove_reagent("water", water)
	if (user)
		user.setClickCooldown(5)
		user.visible_message("[user] empties \the [CT] onto the fire!", "You empty \the [CT] onto the fire!")
	playsound(T, 'sound/effects/watersplash.ogg', 60, TRUE)
	if (water >= FIRE_DOUSE_SPLASH_WATER)
		for (var/mob/living/L in T)
			if (L.on_fire)
				L.ExtinguishMob()
		for (var/obj/effect/fire/near in range(1, T))
			if (near != F && prob(FIRE_DOUSE_SPLASH_CHANCE))
				qdel(near)
	if (prob(fire_douse_chance(water)))
		playsound(T, 'sound/items/cig_snuff.ogg', 50, TRUE)
		T.visible_message("The fire is extinguished!")
		qdel(F)
	else if (user)
		to_chat(user, SPAN_WARNING("It was not enough water. The fire flares back up."))
	return TRUE

/obj/item/weapon/bedsheet
	var/wet_uses = 0
	var/tmp/next_smother = 0

/obj/item/weapon/bedsheet/persistence_runtime_var(key)
	return key == "next_smother" || ..()

/obj/item/weapon/bedsheet/examine(mob/user, distance = -1)
	. = ..()
	if (wet_uses > 0)
		to_chat(user, SPAN_NOTICE("It is soaking wet. Thrown over a fire or a burning person, it will smother the flames."))

/obj/item/weapon/bedsheet/proc/blanket_ready(mob/user)
	if (world.time < next_smother)
		return FALSE
	next_smother = world.time + FIRE_BLANKET_COOLDOWN
	if (user)
		user.setClickCooldown(FIRE_BLANKET_COOLDOWN)
	return TRUE

// A dry sheet in the flames may catch and burn up. Returns TRUE when it did.
/obj/item/weapon/bedsheet/proc/spend_blanket(mob/user)
	if (wet_uses > 0)
		wet_uses--
		if (wet_uses <= 0 && user)
			to_chat(user, SPAN_WARNING("\The [src] has dried out."))
		return FALSE
	if (prob(FIRE_BLANKET_BURN_CHANCE))
		if (user)
			to_chat(user, SPAN_WARNING("\The [src] catches fire and burns up!"))
		qdel(src)
		return TRUE
	return FALSE

// Returns TRUE when the fire went out.
/obj/item/weapon/bedsheet/proc/smother_fire(obj/effect/fire/F, mob/user)
	if (QDELETED(F) || !blanket_ready(user))
		return FALSE
	var/turf/T = get_turf(F)
	if (user)
		user.do_attack_animation(F)
	playsound(T, 'sound/weapons/thudswoosh.ogg', 50, TRUE)
	var/out = prob(wet_uses > 0 ? FIRE_BLANKET_WET_CHANCE : FIRE_BLANKET_DRY_CHANCE)
	if (out)
		if (user)
			user.visible_message(SPAN_NOTICE("[user] smothers the fire with \the [src]."), SPAN_NOTICE("You smother the fire with \the [src]."))
		playsound(T, 'sound/items/cig_snuff.ogg', 50, TRUE)
		qdel(F)
	else if (user)
		to_chat(user, SPAN_WARNING("You throw \the [src] over the flames, but they flare back up.[wet_uses > 0 ? "" : " Soak it in water first."]"))
	spend_blanket(user)
	return out

// Returns TRUE when the person is no longer burning.
/obj/item/weapon/bedsheet/proc/smother_mob(mob/living/L, mob/user)
	if (QDELETED(L) || !L.on_fire || !blanket_ready(user))
		return FALSE
	if (user)
		user.do_attack_animation(L)
	playsound(get_turf(L), 'sound/weapons/thudswoosh.ogg', 50, TRUE)
	if (wet_uses > 0)
		L.ExtinguishMob()
	else
		L.adjust_fire_stacks(-2)
		if (L.fire_stacks <= 0)
			L.ExtinguishMob()
	var/out = !L.on_fire
	if (user)
		if (out)
			user.visible_message(SPAN_NOTICE("[user] wraps [L] in \the [src] and smothers the flames."), SPAN_NOTICE("You wrap [L] in \the [src] and smother the flames."))
		else
			user.visible_message(SPAN_NOTICE("[user] beats at the flames on [L] with \the [src]."), SPAN_NOTICE("You beat at the flames on [L] with \the [src]. Keep going!"))
	spend_blanket(user)
	return out

/obj/item/weapon/bedsheet/proc/soak_blanket(mob/user, atom/source)
	wet_uses = FIRE_BLANKET_WET_USES
	playsound(get_turf(src), 'sound/effects/watersplash.ogg', 60, TRUE)
	if (user)
		to_chat(user, SPAN_NOTICE("You soak \the [src] in \the [source]."))

// Open water, a well, sink or puddle that is not dry, or an open container
// with enough water. Returns TRUE when the click was used.
/obj/item/weapon/bedsheet/proc/try_soak_blanket(atom/A, mob/user)
	var/already = wet_uses >= FIRE_BLANKET_WET_USES
	if (istype(A, /turf/floor/beach/water))
		if (!already)
			soak_blanket(user, A)
		return !already
	if (istype(A, /obj/structure/sink))
		var/obj/structure/sink/S = A
		if (already || S.dry || S.volume <= 0)
			return FALSE
		soak_blanket(user, S)
		S.volume = max(0, S.volume - FIRE_BLANKET_SOAK_WATER)
		return TRUE
	if (istype(A, /obj/item/weapon/reagent_containers))
		var/obj/item/weapon/reagent_containers/RC = A
		if (already || !RC.is_open_container() || !RC.reagents || RC.reagents.get_reagent_amount("water") < FIRE_BLANKET_SOAK_WATER)
			return FALSE
		soak_blanket(user, RC)
		RC.reagents.remove_reagent("water", FIRE_BLANKET_SOAK_WATER)
		return TRUE
	return FALSE

/obj/item/weapon/bedsheet/resolve_attackby(atom/A, mob/user, icon_x, icon_y)
	if (istype(A, /obj/effect/fire))
		smother_fire(A, user)
		return TRUE
	if (isliving(A))
		var/mob/living/L = A
		if (L.on_fire && user.a_intent != I_HARM)
			smother_mob(L, user)
			return TRUE
		return ..()
	if (try_soak_blanket(A, user))
		return TRUE
	return ..()

#undef FIRE_DOUSE_SURE_WATER
#undef FIRE_DOUSE_SPLASH_WATER
#undef FIRE_DOUSE_SPLASH_CHANCE
#undef FIRE_BLANKET_SOAK_WATER
#undef FIRE_BLANKET_WET_USES
#undef FIRE_BLANKET_WET_CHANCE
#undef FIRE_BLANKET_DRY_CHANCE
#undef FIRE_BLANKET_BURN_CHANCE
#undef FIRE_BLANKET_COOLDOWN
