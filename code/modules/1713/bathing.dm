// Bathing (docs/hygiene.md).
//
// - Bathe (IC verb), undressed on fresh water: 15 seconds, up to 200 in a
//   river with a current, 175 in still water. Foul water rolls the illness
//   of drinking it at half the chance. Soap still takes you to 250.
// - A sponge bath from a bucket (30 water or more) raises you to 175 at most.
// - Every tub and shower washes to 200 (250 with soap). On Persistence maps
//   it holds water in a tank (station_water.dm): turning it on takes a
//   tubful (100; bronze and steel 80, the big tubs twice that) unless it is
//   fed by running water or a pipe. Pour water in with a bucket.
// - Reaching 200 from below gives "freshly bathed" (+3 mood), at most once
//   every 20 minutes.

#define BATHE_RUNNING 200
#define BATHE_STILL 175
#define BATHE_TIME 150
#define FRESHLY_BATHED_MOOD 3
#define FRESHLY_BATHED_WAIT 12000

/mob/living/human/var/tmp/freshly_bathed_at = -FRESHLY_BATHED_WAIT

/mob/living/human/persistence_runtime_var(key)
	return key == "freshly_bathed_at" || ..()

/mob/living/human/raise_hygiene(amount)
	var/before = hygiene
	. = ..()
	if (before < HYGIENE_LEVEL_NORMAL && hygiene >= HYGIENE_LEVEL_NORMAL && world.time - freshly_bathed_at >= FRESHLY_BATHED_WAIT)
		freshly_bathed_at = world.time
		adjust_mood(FRESHLY_BATHED_MOOD, "being freshly bathed")

// ---- bathing in open water --------------------------------------------------

/mob/living/human/verb/bathe()
	set name = "Bathe"
	set category = "IC"
	set desc = "Undress and wash yourself in the fresh water you stand in."
	if (stat || restrained() || lying)
		return
	var/turf/floor/beach/water/W = get_turf(src)
	if (!istype(W) || W.salty || !is_liquid_water(W))
		to_chat(src, SPAN_WARNING("Stand in fresh water to bathe."))
		return
	if (!is_nude())
		to_chat(src, SPAN_WARNING("Take your clothes off first."))
		return
	visible_message(SPAN_NOTICE("[src] starts to bathe in \the [W]."), SPAN_NOTICE("You start to scrub yourself in \the [W]."))
	if (!do_after(src, BATHE_TIME, W) || get_turf(src) != W)
		return
	var/germs = W.water_germ_level()
	if (germs > 0)
		catch_dirty_water_illness(germs * 15 * 0.5)
	clean_blood()
	update_inv_gloves()
	raise_hygiene(river_current_direction(W) ? BATHE_RUNNING : BATHE_STILL)
	mark_bare_parts_washed()
	playsound(loc, 'sound/effects/watersplash.ogg', 40, TRUE)
	to_chat(src, SPAN_NOTICE("You finish bathing. [hygiene >= HYGIENE_LEVEL_NORMAL ? "You feel clean." : "The water was too still to get properly clean; soap would help."]"))

// ---- tubs and showers ---------------------------------------------------------

/obj/structure/shower
	water_capacity = 100
	water_per_use = 100

/obj/structure/shower/bathtub/bronze
	water_per_use = 80
/obj/structure/shower/bathtub/steel
	water_per_use = 80
/obj/structure/shower/bathtub/big
	water_capacity = 200
	water_per_use = 200
/obj/structure/shower/bathtub/big/bronze
	water_per_use = 160
/obj/structure/shower/bathtub/big/steel
	water_per_use = 160
// Piped showers already hold what their pipes bring (factory_plumbing.dm).
/obj/structure/shower/piped
	water_capacity = 0

// Only Persistence maps make a tub or shower hold its own water.
/obj/structure/shower/proc/needs_tank_water()
	return water_capacity && map && map.persistence

/obj/structure/shower/attack_hand(mob/M)
	if (!on && needs_tank_water() && !station_take_water(M))
		return
	return ..()

/obj/structure/shower/attackby(obj/item/I, mob/user)
	if (needs_tank_water() && station_water_pour(I, user))
		return TRUE
	return ..()

/obj/structure/shower/examine(mob/user, distance = -1)
	. = ..()
	if (needs_tank_water())
		station_water_examine(user)

#undef BATHE_RUNNING
#undef BATHE_STILL
#undef BATHE_TIME
#undef FRESHLY_BATHED_MOOD
#undef FRESHLY_BATHED_WAIT
