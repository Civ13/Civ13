// Waste kept in a pit latrine or an outhouse pit. Plumbed fixtures carry
// their waste away (sewers.dm); these keep it in the ground, so it can be
// taken back out: dig the night soil out with a shovel, a scoop at a time,
// and draw the urine off into an open bucket or pot. Night soil spreads on
// fields like manure, goes in a compost bin, or steeps with urine in a barrel
// for saltpetre. Handling it dirties the hands (hygiene_work.dm), and a pit
// holding waste fouls wells close by, like a cesspit does (sewers.dm).

#define LATRINE_CAPACITY 30
#define LATRINE_URINE_CAPACITY 150
#define LATRINE_FOUL_RANGE 2

/obj/structure/toilet
	// Loads of night soil in the pit, one per use.
	var/night_soil = 0
	// Units of urine standing in the pit.
	var/stored_urine = 0

// Whether this fixture keeps its waste in a pit that can be dug out.
/obj/structure/toilet/proc/keeps_waste()
	return !is_plumbed()

/obj/structure/toilet/proc/latrine_full()
	return night_soil >= LATRINE_CAPACITY

// Takes one load of waste V into the pit. A full pit overflows: V is left on
// the ground beside it. Returns TRUE when the pit took it.
/obj/structure/toilet/proc/take_night_soil(obj/item/V)
	if (!latrine_full())
		night_soil++
		qdel(V)
		return TRUE
	V.forceMove(get_turf(src))
	visible_message(SPAN_WARNING("\The [src] is full to the brim and overflows. It needs digging out."))
	return FALSE

// Adds urine to the pit; what it cannot hold spills on the ground.
/obj/structure/toilet/proc/take_urine(amount)
	if (amount <= 0)
		return
	var/kept = min(amount, LATRINE_URINE_CAPACITY - stored_urine)
	stored_urine += max(0, kept)
	if (kept < amount)
		var/turf/T = get_turf(src)
		if (T && !(locate(/obj/effect/decal/cleanable/urine) in T))
			new /obj/effect/decal/cleanable/urine(T)

// Whether a hand can reach into the pit: an outhouse must be open.
/obj/structure/toilet/proc/latrine_reachable(mob/user)
	if (istype(src, /obj/structure/toilet/outhouse) && !open)
		to_chat(user, SPAN_NOTICE("Open \the [src] first."))
		return FALSE
	return TRUE

// Shovel: digs out one load of night soil. Open container: draws off urine.
// Returns TRUE when I was used on the pit.
/obj/structure/toilet/proc/latrine_waste_tool(obj/item/I, mob/living/user)
	if (!keeps_waste() || !I || !user)
		return FALSE
	if (is_tool(I, TOOL_SHOVEL))
		dig_night_soil(I, user)
		return TRUE
	if ((istype(I, /obj/item/weapon/reagent_containers/glass) || istype(I, /obj/item/weapon/reagent_containers/food/drinks)) && I.is_open_container())
		draw_urine(I, user)
		return TRUE
	return FALSE

/obj/structure/toilet/proc/dig_night_soil(obj/item/I, mob/living/user)
	if (!latrine_reachable(user))
		return
	if (night_soil <= 0)
		to_chat(user, SPAN_NOTICE("There is no night soil in \the [src] to dig out."))
		return
	user.visible_message(SPAN_NOTICE("[user] starts digging night soil out of \the [src]."), SPAN_NOTICE("You start digging night soil out of \the [src]."))
	playsound(src, 'sound/effects/shovelling.ogg', 60, TRUE)
	if (!do_after(user, 30, src) || night_soil <= 0 || !latrine_reachable(user))
		return
	night_soil--
	new /obj/item/weapon/reagent_containers/food/snacks/poo/night_soil(get_turf(user))
	if (ishuman(user))
		var/mob/living/human/H = user
		H.soil(2, DIRTY_HANDS_WASTE)
	user.visible_message(SPAN_NOTICE("[user] digs a shovelful of night soil out of \the [src]."), SPAN_NOTICE("You dig a shovelful of night soil out of \the [src][night_soil <= 0 ? ". It is empty now" : ""]."))

/obj/structure/toilet/proc/draw_urine(obj/item/weapon/reagent_containers/RC, mob/living/user)
	if (!latrine_reachable(user))
		return
	if (stored_urine < 1)
		to_chat(user, SPAN_NOTICE("There is no urine standing in \the [src] to draw off."))
		return
	if (!RC.reagents || RC.reagents.get_free_space() < 1)
		to_chat(user, SPAN_NOTICE("\The [RC] is full."))
		return
	if (!do_after(user, 15, src) || stored_urine < 1 || !latrine_reachable(user))
		return
	if (QDELETED(RC) || !RC.is_open_container() || !RC.reagents)
		return
	var/amount = round(min(stored_urine, RC.reagents.get_free_space()))
	if (amount < 1)
		return
	RC.reagents.add_reagent("urine", amount)
	stored_urine = max(0, stored_urine - amount)
	if (ishuman(user))
		var/mob/living/human/H = user
		H.soil(0, DIRTY_HANDS_WASTE)
	user.visible_message(SPAN_NOTICE("[user] draws off some urine from \the [src] with \the [RC]."), SPAN_NOTICE("You draw off [amount] units of urine from \the [src] into \the [RC]."))

/obj/structure/toilet/proc/latrine_examine(mob/user)
	if (!keeps_waste() || get_dist(src, user) > 2)
		return
	if (night_soil <= 0)
		to_chat(user, SPAN_NOTICE("The pit is empty."))
	else if (latrine_full())
		to_chat(user, SPAN_WARNING("The pit is full to the brim. Dig the night soil out with a shovel."))
	else
		to_chat(user, SPAN_NOTICE("The pit is [round(night_soil * 100 / LATRINE_CAPACITY)]% full of night soil. A shovel digs it out."))
	if (stored_urine >= 1)
		to_chat(user, SPAN_NOTICE("Urine stands in it; an open bucket or pot can draw it off."))

/obj/structure/toilet/pit_latrine/attackby(obj/item/I, mob/living/user)
	if (latrine_waste_tool(I, user))
		return TRUE
	return ..()

/obj/structure/toilet/outhouse/attackby(obj/item/I, mob/living/user)
	if (latrine_waste_tool(I, user))
		return TRUE
	return ..()

/obj/structure/toilet/pit_latrine/examine(mob/user, distance = -1)
	. = ..()
	if (.)
		latrine_examine(user)

/obj/structure/toilet/outhouse/examine(mob/user, distance = -1)
	. = ..()
	if (.)
		latrine_examine(user)

// TRUE when a pit latrine or outhouse holding waste stands close to A.
/proc/latrine_fouls_near(atom/A)
	for (var/obj/structure/toilet/T in range(LATRINE_FOUL_RANGE, A))
		if (T.night_soil > 0 && T.keeps_waste())
			return TRUE
	return FALSE

// Human waste dug out of a latrine. It keeps, and spreads on a field like
// manure, but it is still human waste: it fouls water and dirties the hands
// of whoever carries it.
/obj/item/weapon/reagent_containers/food/snacks/poo/night_soil
	name = "night soil"
	desc = "Human waste dug out of a latrine. Spread it on a field, compost it, or steep it with urine for saltpetre. Wash your hands after."
	decay = 0
	fertilizer_value = 10

#undef LATRINE_CAPACITY
#undef LATRINE_URINE_CAPACITY
#undef LATRINE_FOUL_RANGE
