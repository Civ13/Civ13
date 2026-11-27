// Wash basins and washstands (docs/station-water.md, docs/home-comfort.md).
//
// A fired clay wash basin set on the floor, or a wooden washstand holding
// one, keeps a little water (station_water.dm): fill it with a bucket, or set
// it beside running water. On help intent, click it to wash your hands, or
// target another body part to wash that (body_washing.dm). Each wash takes 5
// water. A basin with water in it is "a place to wash" for home comfort.

/obj/structure/washbasin
	name = "wash basin"
	desc = "A wide fired clay basin for washing your hands and face."
	icon = 'icons/obj/washstand.dmi'
	icon_state = "basin"
	anchored = TRUE
	density = FALSE
	layer = 2.9
	water_capacity = 30
	water_per_use = 5
	var/base_state = "basin"
	var/busy = FALSE

/obj/structure/washbasin/washstand
	name = "washstand"
	desc = "A wooden stand holding a clay basin and a pitcher, for washing up at home."
	icon_state = "washstand"
	base_state = "washstand"
	density = TRUE
	water_capacity = 50
	flammable = TRUE

/obj/structure/washbasin/New()
	..()
	update_icon()

/obj/structure/washbasin/update_icon()
	icon_state = station_has_water() ? "[base_state]_full" : base_state

/obj/structure/washbasin/examine(mob/user, distance = -1)
	. = ..()
	update_icon()
	station_water_examine(user)

/obj/structure/washbasin/attackby(obj/item/I, mob/user)
	if (is_tool(I, TOOL_WRENCH))
		toggle_anchor(user)
		return
	if (station_water_pour(I, user))
		update_icon()
		return
	return ..()

/obj/structure/washbasin/fluid_receive(id, amount, data)
	. = ..()
	if (. && id == "water")
		update_icon()

/obj/structure/washbasin/attack_hand(mob/user)
	var/mob/living/human/H = user
	if (!ishuman(H) || !Adjacent(H) || H.a_intent != I_HELP)
		return ..()
	if (busy)
		to_chat(H, SPAN_WARNING("Someone is already washing at \the [src]."))
		return
	if (!station_has_water())
		station_take_water(H)
		update_icon()
		return
	busy = TRUE
	var/zone = H.targeted_organ
	var/washed = FALSE
	if (source_washes_zone(zone))
		H.wash_part_of(H, zone, "\the [src]", src) // pays per part (wash_spend)
		update_icon()
	else
		to_chat(H, SPAN_NOTICE("You start washing your hands in \the [src]."))
		if (do_after(H, 20, src))
			H.clean_blood()
			H.update_inv_gloves()
			H.visible_message(SPAN_NOTICE("[H] washes their hands in \the [src]."), SPAN_NOTICE("You wash your hands."))
			playsound(loc, 'sound/effects/slosh.ogg', 25, TRUE)
			washed = TRUE
	busy = FALSE
	if (washed)
		station_take_water(H)
		update_icon()
		busy = TRUE
		H.wash_on_after_hands(src)
		busy = FALSE
		update_icon()

/obj/structure/washbasin/wash_ready()
	return station_has_water()

/obj/structure/washbasin/wash_spend(mob/living/human/user)
	if (!station_take_water(user))
		return FALSE
	update_icon()
	return TRUE

// ---- making a basin ---------------------------------------------------------

// Shaped from clay and fired like any pot; the fired basin is set down by hand.
/obj/item/weapon/clay/washbasin
	name = "unfired clay wash basin"
	icon_state = "unfired_claybowl"
	result = /obj/item/weapon/washbasin

/obj/item/weapon/washbasin
	name = "clay wash basin"
	desc = "A wide fired clay basin. Use it in your hand to set it down where you stand."
	icon = 'icons/obj/washstand.dmi'
	icon_state = "basin"
	w_class = ITEM_SIZE_LARGE

/obj/item/weapon/washbasin/attack_self(mob/user)
	var/turf/T = get_turf(user)
	if (!T || T.density || (locate(/obj/structure/washbasin) in T))
		to_chat(user, SPAN_WARNING("There is no room to set \the [src] down here."))
		return
	new /obj/structure/washbasin(T)
	to_chat(user, SPAN_NOTICE("You set \the [src] down."))
	qdel(src)

// ---- home comfort -----------------------------------------------------------

// Whether something in a room counts as "a place to wash".
/proc/home_is_wash_place(atom/movable/A)
	if (istype(A, /obj/structure/washbasin))
		var/obj/structure/washbasin/B = A
		return B.station_has_water()
	if (istype(A, /obj/structure/sink/puddle))
		return FALSE
	if (istype(A, /obj/structure/sink))
		var/obj/structure/sink/S = A
		return S.volume > 0
	if (istype(A, /obj/structure/water_tap))
		var/obj/structure/water_tap/W = A
		return W.reagents && W.reagents.get_reagent_amount("water") > 0
	return istype(A, /obj/structure/shower) || istype(A, /obj/structure/aqueduct_bath)

// Whether something in a room fouls it however tidy the rest is: a pit
// latrine or outhouse, or dung on the floor.
/proc/home_is_foul(atom/movable/A)
	if (istype(A, /obj/structure/toilet/pit_latrine) || istype(A, /obj/structure/toilet/outhouse))
		return TRUE
	return istype(A, /obj/item/weapon/reagent_containers/food/snacks/poo) && !istype(A, /obj/item/weapon/reagent_containers/food/snacks/poo/fertilizer)
