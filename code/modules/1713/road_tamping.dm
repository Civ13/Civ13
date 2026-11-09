// Road tamping (docs/terrain-height.md#tamped-earth): an early stone rammer
// packs bare dirt into tamped earth, a level path. Tamped earth has no hill
// cost or slope shading, never turns to mud, and a shovel breaks it back up.

#define TAMPING_TIME 30

/obj/item/weapon/stone_rammer
	name = "stone rammer"
	desc = "A flat stone block lashed to a wooden pole. Pound bare dirt with it to pack a level path that stays firm in the rain."
	icon = 'icons/obj/stone_rammer.dmi'
	icon_state = "stone_rammer"
	item_state = "pickaxe"
	w_class = ITEM_SIZE_LARGE
	slot_flags = SLOT_BACK
	force = WEAPON_FORCE_NORMAL
	throwforce = WEAPON_FORCE_WEAK
	attack_verb = list("bludgeoned", "pounded", "rammed")
	flammable = TRUE

// Why this turf cannot be tamped, or null when it can.
/proc/road_tamping_problem(turf/T)
	if (!istype(T, /turf/floor/dirt))
		if (istype(T, /turf/floor/grass))
			return "Clear the grass with a shovel first; the rammer only packs bare dirt."
		return "The rammer only packs bare dirt."
	var/turf/floor/dirt/D = T
	if (D.density || !D.is_diggable)
		return "This ground is too hard to pack."
	if (D.weather_snow > 0)
		return "Clear the snow before packing the ground."
	if (locate(/obj/covers) in D)
		return "Something is already built here."
	if (locate(/obj/structure/farming/plant) in D)
		return "Something is growing here."
	return null

/obj/item/weapon/stone_rammer/resolve_attackby(atom/A, mob/user, icon_x, icon_y)
	if (!isturf(A))
		return ..()
	tamp(A, user)
	return TRUE

/obj/item/weapon/stone_rammer/proc/tamp(turf/T, mob/user)
	var/problem = road_tamping_problem(T)
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return FALSE
	var/delay = TAMPING_TIME
	var/mob/living/human/H = user
	if (istype(H))
		delay /= max(0.5, H.getStatCoeff("strength"))
	user.visible_message(SPAN_NOTICE("[user] starts pounding the dirt flat."), SPAN_NOTICE("You start pounding the dirt flat."), "You hear dull thudding.")
	playsound(T, 'sound/effects/shovelling.ogg', 60, TRUE)
	if (!do_after(user, delay, T))
		return FALSE
	problem = road_tamping_problem(T)
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return FALSE
	T.ChangeTurf(/turf/floor/tamped_earth)
	user.visible_message(SPAN_NOTICE("[user] packs the dirt into a firm, level path."), SPAN_NOTICE("You pack the dirt into a firm, level path."))
	if (istype(H))
		H.adaptStat("strength", 1)
	return TRUE

// A /turf/floor, so terrain_smoothed() is TRUE: no hill cost, no shading.
/turf/floor/tamped_earth
	name = "tamped earth"
	desc = "Dirt pounded hard and level into a path. It stays firm in the rain, and a shovel will break it back up."
	icon = 'icons/turf/tamped_earth.dmi'
	icon_state = "tamped_earth"
	stepsound = "dirt"
	interior = FALSE
	uses_winter_overlay = TRUE
	may_become_muddy = FALSE
	is_diggable = FALSE

/turf/floor/tamped_earth/attackby(obj/item/C, mob/user)
	if (!istype(C, /obj/item/weapon/material/shovel))
		return ..()
	if (weather_snow > 0 && user.a_intent != I_HARM)
		return ..() // Shovels clear snow first, as on other ground.
	user.visible_message(SPAN_NOTICE("[user] starts breaking up the tamped earth."), SPAN_NOTICE("You start breaking up the tamped earth."), "You hear digging.")
	playsound(src, 'sound/effects/shovelling.ogg', 85, TRUE)
	if (!do_after(user, TAMPING_TIME, src))
		return TRUE
	if (!istype(src, /turf/floor/tamped_earth))
		return TRUE
	user.visible_message(SPAN_NOTICE("[user] breaks the tamped earth back into loose dirt."), SPAN_NOTICE("You break the tamped earth back into loose dirt."))
	ChangeTurf(/turf/floor/dirt)
	return TRUE

#undef TAMPING_TIME
