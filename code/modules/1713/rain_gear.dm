// Rain gear: clothing, capes, umbrellas, waterproofing and drying.
//
// Every rain check goes through rain_on_mob() and rain_gear_wind_at(), so the
// moving weather systems only need to change those two procs.
//
// Rain resistance is a percent of soaking blocked. Worn pieces stack as
// independent layers: 1 - (1 - a)(1 - b)..., capped at RAIN_PROTECTION_CAP.

#define RAIN_PROTECTION_CAP 0.95
#define RAIN_WETTING_BASE 0.01 // wetness per Life tick in steady rain, before gear
#define FIRE_DRYING_RATE 0.03 // wetness lost per Life tick next to a lit fire
#define FIRE_DRYING_RANGE 2
#define WRING_OUT_FLOOR 0.3 // wringing leaves clothes damp, not dry
#define WRING_OUT_TIME 50
#define WET_SLOWDOWN_MAX 0.6 // movement delay added when soaked through
#define UMBRELLA_SHADE_C 6 // sun shade under an open umbrella in hot weather
#define UMBRELLA_SHADE_FLOOR_C 25
#define WATERPROOF_REAGENT_USE 5
#define WATERPROOF_APPLY_TIME 40

/obj/item/clothing
	var/rain_resist = 0 // percent of soaking blocked while worn
	var/waterproof_resist = 0 // percent from a rubbed-in grease or oil finish
	var/waterproof_left = 0 // Life ticks of rain the finish still lasts
	var/cape_wearable = FALSE // can be fastened over a uniform, coat or armor as a cape

// Suits take one cape fastened over them.
/obj/item/clothing/suit
	rain_resist = 10
	valid_accessory_slots = list("cape")
	restricted_accessory_slots = list("cape")

/obj/item/clothing/head
	rain_resist = 10

/obj/item/clothing/suit/storage/coat
	rain_resist = 25

// Existing gear that should keep rain off.
/obj/item/clothing/suit/cape
	rain_resist = 35
	cape_wearable = TRUE
/obj/item/clothing/suit/storage/coat/fur
	rain_resist = 40
/obj/item/clothing/suit/prehistoricfurcoat
	rain_resist = 30
/obj/item/clothing/suit/storage/jacket/custom/poncho
	rain_resist = 60
/obj/item/clothing/suit/storage/coat/ww2/japcoat_rain
	rain_resist = 80
/obj/item/clothing/suit/nbcponcho
	rain_resist = 90
/obj/item/clothing/head/hooded_cape
	rain_resist = 35
/obj/item/clothing/head/strawhat
	rain_resist = 30
/obj/item/clothing/head/furhat
	rain_resist = 20
/obj/item/clothing/accessory/custom/cape
	rain_resist = 30

// Effective resistance of one worn piece, including a grease finish.
/obj/item/clothing/proc/get_rain_resist()
	if (waterproof_left > 0)
		return max(rain_resist, waterproof_resist)
	return rain_resist

// A grease finish wears off only while rain is actually falling on it.
/obj/item/clothing/proc/weather_waterproofing()
	if (waterproof_left <= 0)
		return
	waterproof_left--
	if (waterproof_left <= 0)
		waterproof_left = 0
		waterproof_resist = 0
		if (ismob(loc))
			to_chat(loc, SPAN_WARNING("The grease on \the [src] has washed out."))

/obj/item/clothing/proc/apply_waterproofing(resist, ticks)
	if (resist <= 0 || ticks <= 0)
		return FALSE
	waterproof_resist = min(resist, 100)
	waterproof_left = ticks
	return TRUE

/obj/item/clothing/proc/examine_rain_gear(mob/user)
	var/resist = get_rain_resist()
	if (resist >= 75)
		to_chat(user, SPAN_NOTICE("It keeps the rain out very well."))
	else if (resist >= 40)
		to_chat(user, SPAN_NOTICE("It sheds a good deal of rain."))
	else if (resist >= 25)
		to_chat(user, SPAN_NOTICE("It keeps off some rain."))
	if (waterproof_left > 0)
		to_chat(user, SPAN_NOTICE("It has been rubbed with grease to shed water."))

// Grease or oil that can be rubbed into a garment, by reagent id:
// list(resist percent, rain ticks it lasts).
/proc/waterproofing_reagents()
	var/static/list/sources = list(
		"lard" = list(60, 1800),
		"olive_oil" = list(45, 1200),
		"cornoil" = list(45, 1200))
	return sources

// Rub grease from a held container into this garment. TRUE when handled.
/obj/item/clothing/proc/try_waterproof(obj/item/I, mob/user)
	if (!istype(I, /obj/item/weapon/reagent_containers) || !I.reagents)
		return FALSE
	if (!(istype(src, /obj/item/clothing/suit) || istype(src, /obj/item/clothing/head) || cape_wearable))
		return FALSE
	var/list/sources = waterproofing_reagents()
	var/source_id = null
	for (var/id in sources)
		if (I.reagents.get_reagent_amount(id) >= WATERPROOF_REAGENT_USE)
			source_id = id
			break
	if (!source_id)
		return FALSE
	to_chat(user, SPAN_NOTICE("You start rubbing grease into \the [src]..."))
	if (!do_after(user, WATERPROOF_APPLY_TIME, src))
		return TRUE
	if (I.reagents.get_reagent_amount(source_id) < WATERPROOF_REAGENT_USE)
		return TRUE
	I.reagents.remove_reagent(source_id, WATERPROOF_REAGENT_USE)
	var/list/stats = sources[source_id]
	apply_waterproofing(stats[1], stats[2])
	to_chat(user, SPAN_NOTICE("You work the grease into \the [src]. It will shed rain for a while."))
	return TRUE

/*
 * Capes over clothing. A cape_wearable suit fastened onto a uniform, coat or
 * armor rides along as a "cape" accessory that holds the real cape inside it,
 * so taking it off gives back the same item.
 */
/obj/item/clothing/accessory/worn_cape
	name = "cape"
	desc = "A cape fastened over clothing."
	icon = 'icons/obj/clothing/suits.dmi'
	slot = "cape"
	icon_override = 'icons/mob/suit.dmi'
	ripable = FALSE

/obj/item/clothing/accessory/worn_cape/proc/get_cape()
	return locate(/obj/item/clothing/suit) in contents

/obj/item/clothing/accessory/worn_cape/proc/wrap(obj/item/clothing/suit/C)
	C.forceMove(src)
	name = C.name
	desc = C.desc
	icon = C.icon
	icon_state = C.icon_state
	overlay_state = C.item_state ? C.item_state : C.icon_state
	color = C.color
	cold_protection = C.cold_protection
	min_cold_protection_temperature = C.min_cold_protection_temperature
	body_parts_covered = 0 // a cape does not take the armor's place
	inv_overlay = null
	mob_overlay = null

/obj/item/clothing/accessory/worn_cape/get_mob_overlay()
	. = ..()
	var/image/I = .
	if (I)
		I.color = color

/obj/item/clothing/accessory/worn_cape/get_rain_resist()
	var/obj/item/clothing/suit/C = get_cape()
	return C ? C.get_rain_resist() : 0

/obj/item/clothing/accessory/worn_cape/weather_waterproofing()
	var/obj/item/clothing/suit/C = get_cape()
	if (C)
		C.weather_waterproofing()

/obj/item/clothing/accessory/worn_cape/examine_rain_gear(mob/user)
	var/obj/item/clothing/suit/C = get_cape()
	if (C)
		C.examine_rain_gear(user)

// Unfastening hands back the cape itself; the wrapper goes away.
/obj/item/clothing/accessory/worn_cape/on_removed(mob/user)
	if (!has_suit)
		return
	has_suit.overlays -= get_inv_overlay()
	has_suit = null
	var/obj/item/clothing/suit/C = get_cape()
	if (C)
		if (user)
			C.forceMove(get_turf(user))
			user.put_in_hands(C)
		else
			C.forceMove(get_turf(src))
	qdel(src)

/obj/item/clothing/accessory/worn_cape/Destroy()
	var/obj/item/clothing/suit/C = get_cape()
	if (C && !QDELETED(C))
		C.forceMove(get_turf(src))
	return ..()

// A cape fastened over a garment adds its own cold coverage to it.
/obj/item/clothing/get_cold_coverage()
	. = ..()
	for (var/obj/item/clothing/accessory/worn_cape/W in accessories)
		. |= W.cold_protection

// Fasten a held cape onto this garment. TRUE when handled.
/obj/item/clothing/proc/try_fasten_cape(obj/item/clothing/suit/C, mob/user)
	if (!istype(C) || !C.cape_wearable || C == src || istype(src, /obj/item/clothing/accessory))
		return FALSE
	if (!valid_accessory_slots || !("cape" in valid_accessory_slots))
		return FALSE
	for (var/obj/item/clothing/accessory/A in accessories)
		if (A.slot == "cape")
			to_chat(user, SPAN_WARNING("\The [src] already has a cape over it."))
			return TRUE
	if (C.accessories.len)
		to_chat(user, SPAN_WARNING("Take the accessories off \the [C] first."))
		return TRUE
	if (user && !user.unEquip(C))
		return TRUE
	var/obj/item/clothing/accessory/worn_cape/W = new(src)
	W.wrap(C)
	accessories += W
	W.on_attached(src, user)
	verbs |= /obj/item/clothing/proc/removetie_verb
	update_clothing_icon()
	if (ismob(loc))
		var/mob/M = loc
		M.update_inv_w_uniform()
		M.update_inv_wear_suit()
	return TRUE

/*
 * Umbrellas: held open in either hand they keep most rain off and give shade
 * in hot sun. Strong wind can blow one inside out until it is fixed.
 */
/obj/item/weapon/umbrella
	name = "umbrella"
	desc = "Open it to keep the rain off. Strong wind can turn it inside out."
	icon = 'icons/obj/items.dmi'
	icon_state = "umbrella"
	item_state = "umbrella"
	w_class = ITEM_SIZE_NORMAL
	force = 4
	flammable = TRUE
	var/open = FALSE
	var/inside_out = FALSE
	var/rain_resist = 80
	var/wind_flip_chance = 3 // percent per tick in a gale

/obj/item/weapon/umbrella/paper
	name = "oiled-paper umbrella"
	desc = "Oiled paper stretched over a bamboo frame. It keeps rain off but tears in a gale."
	icon_state = "umbrella_paper"
	item_state = "umbrella_paper"
	rain_resist = 70
	wind_flip_chance = 5

/obj/item/weapon/umbrella/cloth
	name = "cloth umbrella"
	desc = "Waxed cloth on a steel frame."
	icon_state = "umbrella_cloth"
	item_state = "umbrella_cloth"

/obj/item/weapon/umbrella/folding
	name = "folding umbrella"
	desc = "A compact nylon umbrella that folds small enough for a pocket."
	icon_state = "umbrella_folding"
	item_state = "umbrella_folding"
	w_class = ITEM_SIZE_SMALL
	rain_resist = 85
	wind_flip_chance = 2

/obj/item/weapon/umbrella/proc/shelters()
	return open && !inside_out

/obj/item/weapon/umbrella/update_icon()
	var/base = initial(icon_state)
	if (inside_out)
		icon_state = "[base]_broken"
	else if (open)
		icon_state = "[base]_open"
	else
		icon_state = base
	item_state = open && !inside_out ? "[initial(item_state)]_open" : initial(item_state)
	if (ismob(loc))
		var/mob/M = loc
		M.update_inv_l_hand()
		M.update_inv_r_hand()

/obj/item/weapon/umbrella/attack_self(mob/user)
	if (inside_out)
		to_chat(user, SPAN_NOTICE("You start bending \the [src] back into shape..."))
		if (do_after(user, 30, src))
			inside_out = FALSE
			open = FALSE
			to_chat(user, SPAN_NOTICE("You fix \the [src]."))
			update_icon()
		return
	open = !open
	to_chat(user, SPAN_NOTICE("You [open ? "open" : "close"] \the [src]."))
	update_icon()

/obj/item/weapon/umbrella/examine(mob/user, distance)
	..(user, distance)
	if (inside_out)
		to_chat(user, SPAN_WARNING("It has been blown inside out. Use it in hand to fix it."))

/obj/item/weapon/umbrella/proc/wind_step(mob/user, wind)
	if (!shelters() || wind < 3 || !prob(wind_flip_chance))
		return
	inside_out = TRUE
	if (user)
		to_chat(user, SPAN_WARNING("A gust of wind turns \the [src] inside out!"))
	update_icon()

/*
 * Lean-to: a sloped frame of branches and leaves that keeps rain off like a
 * canopy. under_canopy() counts it.
 */
/obj/structure/lean_to
	name = "lean-to"
	desc = "A sloped frame of branches thatched with leaves. It keeps the rain off whoever sits under it."
	icon = 'icons/obj/structures.dmi'
	icon_state = "lean_to"
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	flammable = TRUE
	not_movable = TRUE

/obj/structure/lean_to/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/material/hatchet) || istype(W, /obj/item/weapon/material/machete))
		to_chat(user, SPAN_NOTICE("You start pulling down \the [src]..."))
		if (do_after(user, 40, src))
			to_chat(user, SPAN_NOTICE("You pull down \the [src]."))
			new /obj/item/stack/material/wood(get_turf(src), 2)
			qdel(src)
		return
	..()

/*
 * Weather reads. Area based until the moving weather systems replace them.
 */
// Rain intensity falling on this mob's tile: 0 when dry or sheltered, else 1-3.
/mob/living/human/proc/rain_on_mob()
	var/turf/T = get_turf(src)
	if (!T)
		return 0
	var/area/A = get_area(T)
	if (!A || A.location != AREA_OUTSIDE || A.weather != WEATHER_WET)
		return 0
	if (under_canopy(T))
		return 0
	switch (A.icon_state)
		if ("rain1")
			return 1
		if ("rain", "rain2")
			return 2
		if ("rain3", "monsoon")
			return 3
	return 0

// Wind strength on a tile, 0-3. Gales come with extreme weather.
/proc/rain_gear_wind_at(turf/T)
	var/area/A = get_area(T)
	if (!A || A.location != AREA_OUTSIDE)
		return 0
	if (A.weather == WEATHER_EXTREME || A.icon_state == "monsoon")
		return 3
	if (A.weather == WEATHER_WET && A.icon_state == "rain3")
		return 2
	return 0

/mob/living/human/proc/held_umbrella()
	for (var/obj/item/weapon/umbrella/U in list(l_hand, r_hand))
		if (U.shelters())
			return U
	return null

// Capes fastened over the uniform or suit.
/mob/living/human/proc/worn_capes()
	. = list()
	for (var/obj/item/clothing/C in list(w_uniform, wear_suit))
		for (var/obj/item/clothing/accessory/A in C.accessories)
			if (A.slot == "cape")
				. += A

// Fraction (0-0.95) of rain kept off by worn gear and a held umbrella.
/mob/living/human/proc/get_rain_protection()
	var/dry = 1
	for (var/obj/item/clothing/C in list(wear_suit, head) + worn_capes())
		dry *= 1 - min(100, max(0, C.get_rain_resist())) / 100
	var/obj/item/weapon/umbrella/U = held_umbrella()
	if (U)
		dry *= 1 - U.rain_resist / 100
	return min(RAIN_PROTECTION_CAP, 1 - dry)

// One Life tick of rain: soak through the gaps in the gear and wear finishes.
/mob/living/human/proc/rain_soak_step(intensity)
	var/protection = get_rain_protection()
	cold_wetness = min(1, cold_wetness + RAIN_WETTING_BASE * (0.5 + 0.25 * intensity) * (1 - protection))
	for (var/obj/item/clothing/C in list(wear_suit, head) + worn_capes())
		C.weather_waterproofing()
	var/obj/item/weapon/umbrella/U = held_umbrella()
	if (U)
		U.wind_step(src, rain_gear_wind_at(get_turf(src)))

// A lit fire close enough to dry clothes by.
/proc/near_drying_fire(turf/T)
	if (!T)
		return FALSE
	for (var/obj/structure/brazier/BR in range(FIRE_DRYING_RANGE, T))
		if (BR.on)
			return TRUE
	for (var/obj/structure/heatsource/HS in range(FIRE_DRYING_RANGE, T))
		if (HS.on)
			return TRUE
	for (var/obj/structure/oven/fireplace/FP in range(FIRE_DRYING_RANGE, T))
		if (FP.on)
			return TRUE
	return FALSE

// Wetness lost this tick when out of the rain.
/mob/living/human/proc/drying_rate(loc_temp_c)
	if (near_drying_fire(get_turf(src)))
		return FIRE_DRYING_RATE
	return loc_temp_c >= 18 ? 0.01 : 0.002

// Open umbrellas shade the wearer from hot sun outdoors.
/mob/living/human/proc/umbrella_shade_temperature(loc_temp_c)
	if (loc_temp_c <= UMBRELLA_SHADE_FLOOR_C || !held_umbrella())
		return loc_temp_c
	var/area/A = get_area(src)
	if (!A || A.location != AREA_OUTSIDE)
		return loc_temp_c
	return max(UMBRELLA_SHADE_FLOOR_C, loc_temp_c - UMBRELLA_SHADE_C)

// Wet clothes drag on settlement maps, where wetness and cold matter.
/mob/living/human/proc/wet_clothes_slowdown()
	if (cold_wetness <= 0 || !map || !map.civilizations)
		return 0
	return WET_SLOWDOWN_MAX * cold_wetness

/mob/living/human/proc/in_soaking_water()
	var/turf/T = get_turf(src)
	return istype(T, /turf/floor/beach/water) && !istype(T, /turf/floor/beach/water/ice) && !T.iscovered() && !seabed_diving_rating()

/mob/living/human/verb/wring_out_clothes()
	set name = "Wring Out Clothes"
	set category = "IC"
	if (stat || restrained())
		return
	if (cold_wetness <= WRING_OUT_FLOOR)
		to_chat(src, SPAN_NOTICE("Your clothes are not wet enough to wring out."))
		return
	if (in_soaking_water())
		to_chat(src, SPAN_WARNING("You need to get out of the water first."))
		return
	visible_message(SPAN_NOTICE("[src] starts wringing water out of their clothes."), SPAN_NOTICE("You start wringing the water out of your clothes..."))
	if (!do_after(src, WRING_OUT_TIME, src))
		return
	cold_wetness = min(cold_wetness, WRING_OUT_FLOOR)
	to_chat(src, SPAN_NOTICE("You wring out your clothes. They are still damp, but much lighter."))

#undef RAIN_PROTECTION_CAP
#undef RAIN_WETTING_BASE
#undef FIRE_DRYING_RATE
#undef FIRE_DRYING_RANGE
#undef WRING_OUT_FLOOR
#undef WRING_OUT_TIME
#undef WET_SLOWDOWN_MAX
#undef UMBRELLA_SHADE_C
#undef UMBRELLA_SHADE_FLOOR_C
#undef WATERPROOF_REAGENT_USE
#undef WATERPROOF_APPLY_TIME
