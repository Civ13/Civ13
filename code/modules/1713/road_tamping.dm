// Road tamping and grading (docs/terrain-height.md): an early stone rammer
// packs bare dirt into tamped earth. Tamped earth keeps its hill and shading
// but costs half as much to climb, never turns to mud, and a shovel breaks it
// back up. Grading moves the ground itself one level at a time: a shovel on
// disarm intent cuts a tile down and leaves a dirt pile; the rammer on a tile
// with a dirt pile on it packs the pile in and raises the tile. A tile moves
// at most TERRAIN_GRADE_LIMIT levels from the map's height, so truly flat
// ground takes planning, hauling dirt and time.

#define TAMPING_TIME 30
#define GRADING_TIME 100
#define TERRAIN_GRADE_LIMIT 2

/obj/item/weapon/stone_rammer
	name = "stone rammer"
	desc = "A flat stone block lashed to a wooden pole. Pound bare dirt with it to pack a path that is easier to climb and stays firm in the rain."
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
	var/turf/T = isturf(A) ? A : null
	if (!T && istype(A, /obj/item/weapon/barrier) && isturf(A.loc))
		T = A.loc // Clicking the dirt pile itself fills its tile.
	if (!T)
		return ..()
	if (locate(/obj/item/weapon/barrier) in T)
		terrain_grade_work(T, user, 1, src)
	else
		tamp(T, user)
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
	user.visible_message(SPAN_NOTICE("[user] packs the dirt into a firm path."), SPAN_NOTICE("You pack the dirt into a firm path."))
	if (istype(H))
		H.adaptStat("strength", 1)
	return TRUE

// Natural ground that is packed, not levelled: the hill stays, the climb is easier.
/turf/floor/tamped_earth
	name = "tamped earth"
	desc = "Dirt pounded hard into a path. It is easier to climb than loose ground, stays firm in the rain, and a shovel will break it back up."
	icon = 'icons/turf/tamped_earth.dmi'
	icon_state = "tamped_earth"
	stepsound = "dirt"
	interior = FALSE
	uses_winter_overlay = TRUE
	may_become_muddy = FALSE
	is_diggable = FALSE

/turf/floor/tamped_earth/terrain_smoothed()
	return terrain_floor_covered()

/turf/floor/tamped_earth/terrain_packed()
	return TRUE

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

// Grading: player-made changes to the map's hill heights, saved with the turf.
/turf/var/terrain_grade = 0

/turf/get_saved_vars()
	. = ..()
	if (terrain_grade)
		. |= "terrain_grade"

/turf/after_load()
	..()
	if (terrain_grade)
		terrain_grade_apply()

// Puts this turf's grade into the map's heights and reshades around it.
/turf/proc/terrain_grade_apply()
	var/datum/terrain_heights/H = map ? map.terrain_heights() : null
	if (!H || !H.rows_by_z["[z]"])
		return FALSE
	terrain_grade = clamp(round(terrain_grade), -TERRAIN_GRADE_LIMIT, TERRAIN_GRADE_LIMIT)
	H.set_level(x, y, z, H.base_at(x, y, z) + terrain_grade)
	if (terrain_shading_applied)
		for (var/turf/near in block(locate(max(1, x - 3), max(1, y - 3), z), locate(min(world.maxx, x + 3), min(world.maxy, y + 3), z)))
			near.terrain_shade_refresh()
	return TRUE

// Why this turf cannot be graded by one level in direction (1 up, -1 down), or null.
/proc/terrain_grade_problem(turf/T, direction)
	if (!map || !map.terrain_height_file || !map.terrain_heights())
		return "There are no hills here to grade."
	var/datum/terrain_heights/H = map.terrain_heights()
	if (!H.rows_by_z["[T.z]"])
		return "There are no hills here to grade."
	if (!istype(T, /turf/floor/dirt) && !istype(T, /turf/floor/tamped_earth))
		return "Only dirt ground can be graded."
	var/turf/floor/dirt/D = T
	if (T.density || (istype(D) && !D.is_diggable))
		return "This ground is too hard to grade."
	if (T.weather_snow > 0)
		return "Clear the snow before grading the ground."
	if (locate(/obj/covers) in T)
		return "Something is built here."
	for (var/obj/O in T)
		if (O.density || istype(O, /obj/structure/farming/plant))
			return "Clear \the [O] off this spot first."
	for (var/turf/floor/beach/water/W in range(1, T))
		return "The ground this close to water is too wet to grade."
	var/level = terrain_height_at(T) + direction
	if (level < 0 || level > 15)
		return direction > 0 ? "The ground is as high as it can go here." : "The ground is as low as it can go here."
	if (abs(T.terrain_grade + direction) > TERRAIN_GRADE_LIMIT)
		return direction > 0 ? "You can't build this spot up any higher by hand." : "You can't dig this spot down any lower by hand."
	return null

// Cuts (direction -1) or fills (direction 1) one level. Fill uses a dirt pile
// on the tile and leaves tamped earth; cut leaves loose dirt and a dirt pile.
/proc/terrain_grade_work(turf/T, mob/user, direction, obj/item/tool)
	var/problem = terrain_grade_problem(T, direction)
	if (!problem && direction > 0 && !(locate(/obj/item/weapon/barrier) in T))
		problem = "Put a pile of dirt on the spot to build it up."
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return FALSE
	var/delay = GRADING_TIME
	var/mob/living/human/H = user
	if (istype(H))
		delay /= max(0.5, H.getStatCoeff("strength"))
	if (direction > 0)
		user.visible_message(SPAN_NOTICE("[user] starts ramming dirt into the ground to build it up."), SPAN_NOTICE("You start ramming the dirt pile into the ground to build it up."), "You hear dull thudding.")
	else
		user.visible_message(SPAN_NOTICE("[user] starts cutting the ground down."), SPAN_NOTICE("You start cutting the ground down a level."), "You hear digging.")
	playsound(T, 'sound/effects/shovelling.ogg', 70, TRUE)
	if (!do_after(user, delay, T))
		return FALSE
	problem = terrain_grade_problem(T, direction)
	var/obj/item/weapon/barrier/pile = direction > 0 ? locate(/obj/item/weapon/barrier) in T : null
	if (!problem && direction > 0 && !pile)
		problem = "The dirt pile is gone."
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return FALSE
	var/grade = T.terrain_grade + direction
	if (direction > 0)
		qdel(pile)
		if (!istype(T, /turf/floor/tamped_earth))
			T = T.ChangeTurf(/turf/floor/tamped_earth)
		user.visible_message(SPAN_NOTICE("[user] rams the dirt in, building the ground up."), SPAN_NOTICE("You ram the dirt in and build the ground up a level."))
	else
		if (!istype(T, /turf/floor/dirt) || istype(T, /turf/floor/dirt/winter))
			T = T.ChangeTurf(/turf/floor/dirt)
		new /obj/item/weapon/barrier(T)
		user.visible_message(SPAN_NOTICE("[user] cuts the ground down and piles up the dirt."), SPAN_NOTICE("You cut the ground down a level and pile up the dirt."))
	T.terrain_grade = grade
	T.terrain_grade_apply()
	if (istype(H))
		H.adaptStat("strength", 1)
	return TRUE

/turf/floor/tamped_earth/attackby(obj/item/C, mob/user)
	if (istype(C, /obj/item/weapon/material/shovel) && user.a_intent == I_DISARM && !(weather_snow > 0))
		terrain_grade_work(src, user, -1, C)
		return TRUE
	return ..()

/turf/floor/dirt/attackby(obj/item/C, mob/user)
	if (istype(C, /obj/item/weapon/material/shovel) && user.a_intent == I_DISARM && !(weather_snow > 0))
		terrain_grade_work(src, user, -1, C)
		return TRUE
	return ..()

#undef TAMPING_TIME
#undef GRADING_TIME
#undef TERRAIN_GRADE_LIMIT
