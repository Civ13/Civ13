// Stone Age rites: burial mounds, cairns and feasts. See docs/stone-age-rites.md.
//
// A filled grave can be heaped into a burial mound with dirt and named for the
// dead. A cairn is a heap of stones raised as a marker. A feast is food laid on a
// feasting mat and shared by four or more people: everyone eats their fill and
// stays full for hours. Raising a mound and holding a feast are deeds for the
// totem pole (tribal_deeds.dm). Times are real minutes kept as text, as in
// stone_age_traps.dm.

#define RITES_ICON 'icons/obj/stone_age_rites.dmi'
#define MOUND_DIRT 3
#define MOUND_LEVEL_TIME 150
#define FEAST_GUESTS 4
#define FEAST_RANGE 2
#define FEAST_TIME 50
#define FEAST_MINUTES 180

// ---- Burial mounds ----

/obj/structure/religious/grave/var/mound_dirt = 0
/obj/structure/religious/grave/var/mound_raised = FALSE
/obj/structure/religious/grave/var/mound_for // the name of the dead

/obj/structure/religious/grave/proc/holds_the_dead()
	for (var/mob/living/L in contents)
		return TRUE
	if (locate(/obj/structure/religious/remains) in contents)
		return TRUE
	if (locate(/obj/structure/closet/coffin) in contents)
		return TRUE
	return FALSE

/obj/structure/religious/grave/proc/apply_mound_look()
	if (!mound_raised)
		return
	icon = RITES_ICON
	icon_state = "burial_mound"
	name = mound_for ? "burial mound of [mound_for]" : "burial mound"
	if (!desc || desc == "A grave.")
		desc = "A low mound of earth heaped over a grave."

/obj/structure/religious/grave/initialize()
	..()
	apply_mound_look()

/obj/structure/religious/grave/examine(mob/user, distance = -1, infix = "", suffix = "")
	. = ..()
	if (!open && !mound_raised)
		to_chat(user, "Heap [MOUND_DIRT] piles of dirt on it to raise a burial mound.")

/obj/structure/religious/grave/proc/add_mound_dirt(obj/item/weapon/barrier/D, mob/user, who)
	if (open || mound_raised)
		return FALSE
	if (!holds_the_dead())
		to_chat(user, SPAN_WARNING("Nobody is buried here to raise a mound over."))
		return FALSE
	mound_dirt++
	qdel(D)
	if (mound_dirt < MOUND_DIRT)
		user.visible_message(SPAN_NOTICE("[user] heaps dirt onto \the [src]."), SPAN_NOTICE("You heap dirt onto \the [src] ([mound_dirt] of [MOUND_DIRT])."))
		return TRUE
	mound_raised = TRUE
	mound_for = who
	apply_mound_look()
	user.visible_message(SPAN_NOTICE("[user] raises \a [src]."), SPAN_NOTICE("You raise \a [src]."))
	record_deed(user, "burial_mound", who ? "Raised a burial mound over [who]" : "Raised a burial mound")
	return TRUE

/obj/structure/religious/grave/proc/level_mound(mob/user)
	user.visible_message(SPAN_NOTICE("[user] starts levelling \the [src]."), SPAN_NOTICE("You start levelling \the [src]."))
	if (!do_after(user, MOUND_LEVEL_TIME, src) || !mound_raised)
		return FALSE
	log_game("[key_name(user)] levelled [name] at ([x],[y],[z]).")
	mound_raised = FALSE
	mound_dirt = 0
	mound_for = null
	icon = initial(icon)
	icon_state = "grave_filled"
	name = "grave"
	desc = "A grave."
	to_chat(user, SPAN_NOTICE("You level the mound. The grave below is still filled."))
	return TRUE

/obj/structure/religious/grave/attackby(obj/item/W, mob/user)
	if (!open && istype(W, /obj/item/weapon/barrier) && ishuman(user))
		if (mound_raised)
			to_chat(user, SPAN_NOTICE("The mound is already raised."))
			return TRUE
		var/who = null
		if (mound_dirt == MOUND_DIRT - 1)
			who = sanitizeSafe(player_input(user, "Who rests under this mound? Leave blank for no name.", "Burial mound", null, "text", null, TRUE), MAX_NAME_LEN)
			if (QDELETED(W) || W.loc != user || !Adjacent(user))
				return TRUE
		add_mound_dirt(W, user, length(who) ? who : null)
		return TRUE
	if (mound_raised && !open && is_tool(W, TOOL_SHOVEL))
		level_mound(user)
		return TRUE
	return ..()

// ---- Cairns ----

/obj/structure/religious/cairn
	name = "cairn"
	desc = "A heap of stones raised as a marker."
	icon = RITES_ICON
	icon_state = "cairn"
	density = FALSE
	anchored = TRUE
	flammable = FALSE

/datum/craft_product/cairn
	order = 101
	prompts = list(
		list("field" = "name", "kind" = "text", "question" = "Choose a name for this cairn:", "fallback" = "cairn", "can_cancel" = TRUE),
		list("field" = "desc", "kind" = "text", "question" = "What does this cairn mark?", "fallback" = "A heap of stones raised as a marker.", "can_cancel" = TRUE),
	)

/datum/craft_product/cairn/matches(datum/stack_recipe/R)
	return findtext(R.title, "cairn")

// ---- Feasts ----

/mob/living/human/var/feast_until // text minutes

/mob/living/human/proc/feasting(now = trap_now_minutes())
	var/until = trap_minutes(feast_until)
	return until && now < until

// Full from a feast: hunger comes on at half the rate.
/mob/living/human/survival_climate_food_m()
	. = ..()
	if (feasting())
		. *= 0.5

/obj/structure/feast_mat
	name = "feasting mat"
	desc = "A mat to spread a feast on. Lay food on it, gather at least four people around it and share it."
	icon = RITES_ICON
	icon_state = "feast_mat"
	anchored = TRUE
	density = FALSE
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE
	layer = 2.9

/obj/structure/feast_mat/proc/dishes()
	. = list()
	for (var/obj/item/weapon/reagent_containers/food/snacks/S in contents)
		. += S

/obj/structure/feast_mat/update_icon()
	icon_state = length(dishes()) ? "feast_mat_food" : "feast_mat"

/obj/structure/feast_mat/examine(mob/user, distance = -1, infix = "", suffix = "")
	. = ..()
	var/n = length(dishes())
	to_chat(user, n ? "It holds [n] dish[n == 1 ? "" : "es"]." : "It is bare.")

/obj/structure/feast_mat/attackby(obj/item/I, mob/user)
	if (istype(I, /obj/item/weapon/reagent_containers/food/snacks))
		user.drop_from_inventory(I)
		I.forceMove(src)
		update_icon()
		user.visible_message(SPAN_NOTICE("[user] lays \the [I] on \the [src]."), SPAN_NOTICE("You lay \the [I] on \the [src]."))
		return TRUE
	return ..()

/obj/structure/feast_mat/proc/guests()
	. = list()
	for (var/mob/living/human/H in range(FEAST_RANGE, src))
		if (H.stat == CONSCIOUS)
			. += H

/obj/structure/feast_mat/attack_hand(mob/user)
	if (!ishuman(user))
		return ..()
	var/list/food = dishes()
	if (user.a_intent == I_GRAB)
		if (!length(food))
			return
		var/obj/item/S = food[food.len]
		S.forceMove(get_turf(src))
		user.put_in_hands(S)
		update_icon()
		to_chat(user, SPAN_NOTICE("You take \the [S] back."))
		return
	var/refusal = feast_refusal(user)
	if (refusal)
		to_chat(user, SPAN_WARNING(refusal))
		return
	user.visible_message(SPAN_NOTICE("[user] calls everyone to the feast."), SPAN_NOTICE("You call everyone to the feast."))
	if (!do_after(user, FEAST_TIME, src) || feast_refusal(user))
		return
	hold_feast(user)

/obj/structure/feast_mat/proc/feast_refusal(mob/user)
	var/list/people = guests()
	var/n = length(dishes())
	if (length(people) < FEAST_GUESTS)
		return "A feast needs at least [FEAST_GUESTS] people gathered around the mat. Use grab intent to take food back."
	if (n < length(people))
		return "There is not enough food for everyone: lay out a dish for each of the [length(people)] people here."
	return null

/obj/structure/feast_mat/proc/hold_feast(mob/living/human/host, now = trap_now_minutes())
	var/list/people = guests()
	var/list/food = dishes()
	if (length(people) < FEAST_GUESTS || length(food) < length(people))
		return 0
	for (var/i = 1 to length(people))
		qdel(food[i])
	var/until = trap_minutes_text(now + FEAST_MINUTES)
	for (var/mob/living/human/H in people)
		H.nutrition = H.max_nutrition
		H.feast_until = until
		H.adjust_mood(10, "shared a feast")
		to_chat(H, SPAN_NOTICE("You eat your fill at the feast. You will stay full for hours."))
	update_icon()
	visible_message(SPAN_NOTICE("[length(people)] people share a feast around \the [src]."))
	record_deed(host, "feast", "Held a feast for [length(people)] people")
	return length(people)

#undef FEAST_GUESTS
#undef FEAST_RANGE
#undef FEAST_TIME
