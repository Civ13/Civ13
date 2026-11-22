// Charcoal clamp: a stack of logs around a stake, covered with earth and left
// to smoulder. It is the reliable way to make charcoal; the old routes (a
// spent campfire, an oven's leftover embers) stay as chance byproducts.

#define CHARCOAL_CLAMP_LIMIT 20 // logs one clamp holds
#define CHARCOAL_CLAMP_MIN 2 // logs needed to light it
#define CHARCOAL_CLAMP_LOGS_PER_LUMP 2 // logs burnt down to one lump of charcoal
#define CHARCOAL_CLAMP_BURN_TIME 3000 // deciseconds, five minutes
#define CHARCOAL_CLAMP_TICK 100

/obj/structure/charcoal_clamp
	name = "charcoal clamp"
	desc = "A charcoal burner: logs stacked around a stake, ready to be covered with earth and left to smoulder. Load it with wood logs, then light it by hand. Five minutes later every two logs come out as a lump of charcoal."
	icon = 'icons/obj/charcoal_clamp.dmi'
	icon_state = "charcoal_clamp"
	density = TRUE
	anchored = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE
	var/wood_charge = 0
	var/burning = FALSE
	var/burn_left = 0 // deciseconds of smouldering left; saved, so a load resumes the burn
	var/tmp/burn_epoch = 0

/obj/structure/charcoal_clamp/persistence_runtime_var(key)
	return key == "burn_epoch" || ..()

/obj/structure/charcoal_clamp/proc/charcoal_yield()
	return round(wood_charge / CHARCOAL_CLAMP_LOGS_PER_LUMP)

/obj/structure/charcoal_clamp/update_icon()
	if (burning)
		icon_state = "charcoal_clamp_on"
		set_light(1)
	else if (wood_charge > 0)
		icon_state = "charcoal_clamp_loaded"
		set_light(0)
	else
		icon_state = "charcoal_clamp"
		set_light(0)

/obj/structure/charcoal_clamp/examine(mob/user, distance)
	..(user, distance)
	if (burning)
		to_chat(user, SPAN_NOTICE("It is smouldering under its earth cover. About [max(1, round(burn_left / 600))] minute\s left, for [charcoal_yield()] charcoal."))
	else
		to_chat(user, SPAN_NOTICE("It holds [wood_charge] of [CHARCOAL_CLAMP_LIMIT] logs, enough for [charcoal_yield()] charcoal."))

/obj/structure/charcoal_clamp/attackby(obj/item/I, mob/living/human/H)
	if (!I || !I.loc || !istype(H))
		return
	if (is_tool(I, TOOL_SHOVEL))
		dig_out(H)
		return
	if (isflamesource(I))
		light(H)
		return
	if (!istype(I, /obj/item/stack/material/wood))
		return ..()
	if (burning)
		to_chat(H, SPAN_WARNING("\The [src] is already smouldering. Wait for it to finish."))
		return
	var/obj/item/stack/S = I
	var/moved = min(S.amount, CHARCOAL_CLAMP_LIMIT - wood_charge)
	if (moved <= 0)
		to_chat(H, SPAN_WARNING("\The [src] is full."))
		return
	wood_charge += moved
	S.use(moved)
	update_icon()
	visible_message(SPAN_NOTICE("[H] stacks [moved] log\s on \the [src]."))

/obj/structure/charcoal_clamp/attack_hand(mob/living/human/H)
	if (!istype(H))
		return
	light(H)

/obj/structure/charcoal_clamp/proc/light(mob/living/human/H)
	if (burning)
		to_chat(H, SPAN_NOTICE("\The [src] is already smouldering."))
		return
	if (wood_charge < CHARCOAL_CLAMP_MIN)
		to_chat(H, SPAN_WARNING("Stack at least [CHARCOAL_CLAMP_MIN] wood logs on \the [src] first."))
		return
	visible_message(SPAN_NOTICE("[H] starts covering \the [src] with earth."), SPAN_NOTICE("You start covering the logs with earth, leaving a vent at the top."))
	if (!do_after(H, 50, src) || QDELETED(src) || burning || wood_charge < CHARCOAL_CLAMP_MIN)
		return
	burning = TRUE
	burn_left = CHARCOAL_CLAMP_BURN_TIME
	update_icon()
	visible_message(SPAN_NOTICE("[H] lights \the [src]. Thin smoke starts curling out of the vent."))
	start_burn_loop()

/obj/structure/charcoal_clamp/proc/start_burn_loop()
	addtimer(CALLBACK(src, PROC_REF(burn_tick), ++burn_epoch), CHARCOAL_CLAMP_TICK)

/obj/structure/charcoal_clamp/proc/burn_tick(epoch)
	if (QDELETED(src) || !burning || epoch != burn_epoch)
		return
	burn_left -= CHARCOAL_CLAMP_TICK
	if (burn_left <= 0)
		finish_burn()
		return
	addtimer(CALLBACK(src, PROC_REF(burn_tick), epoch), CHARCOAL_CLAMP_TICK)

/obj/structure/charcoal_clamp/proc/finish_burn()
	var/lumps = charcoal_yield()
	burning = FALSE
	burn_left = 0
	wood_charge = 0
	burn_epoch++
	if (lumps > 0)
		// The yield goes to the constructor so a merge into a pile on the turf keeps all of it.
		var/obj/item/stack/ore/charcoal/C = new(get_turf(src), lumps)
		if (!QDELETED(C))
			C.update_icon()
			C.update_strings()
	update_icon()
	visible_message(SPAN_NOTICE("\The [src] burns down. Its earth cover cracks open on [lumps] lump\s of charcoal."))

// A shovel takes the clamp down and gives back logs that were never burnt.
/obj/structure/charcoal_clamp/proc/dig_out(mob/living/human/H)
	if (burning)
		to_chat(H, SPAN_WARNING("\The [src] is still smouldering. Opening it now would let the fire in and burn everything to ash."))
		return
	visible_message(SPAN_NOTICE("[H] starts digging out \the [src]."))
	if (!do_after(H, 40, src) || QDELETED(src) || burning)
		return
	var/turf/T = get_turf(src)
	if (wood_charge > 0)
		var/obj/item/stack/material/wood/W = new(T, wood_charge)
		wood_charge = 0
		if (!QDELETED(W))
			W.update_icon()
			W.update_strings()
	visible_message(SPAN_NOTICE("[H] digs out \the [src]."))
	qdel(src)

/obj/structure/charcoal_clamp/after_load()
	..()
	burn_epoch = 0
	if (burning)
		if (burn_left <= 0)
			burn_left = CHARCOAL_CLAMP_TICK
		start_burn_loop()
	update_icon()

#undef CHARCOAL_CLAMP_LIMIT
#undef CHARCOAL_CLAMP_MIN
#undef CHARCOAL_CLAMP_LOGS_PER_LUMP
#undef CHARCOAL_CLAMP_BURN_TIME
#undef CHARCOAL_CLAMP_TICK
