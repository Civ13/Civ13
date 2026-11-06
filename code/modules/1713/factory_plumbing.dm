// Plumbing on pipe networks (factory_pipes.dm). A water tap and a piped
// shower are pipe sinks: they hold what the network has pumped to them and
// run dry when it stops, unlike the ordinary sink and shower, which never
// run out. A tap hands out exactly what came down the pipe, so unboiled
// river water from an intake is still unboiled at the tap.
// Reuses the sink and shower sprites; no new art.

#define PLUMBING_TAP_VOLUME 100
#define PLUMBING_TAP_DRINK 10
#define PLUMBING_TAP_WASH 5
#define PLUMBING_SHOWER_VOLUME 200
#define PLUMBING_SHOWER_USE 5 // units of water a running shower uses each process tick

// ---------------------------------------------------------------- tap

/obj/structure/water_tap
	name = "water tap"
	desc = "A basin and tap on a pipe network. It gives whatever the pipes bring it: fill a container, drink from it with a grab, or wash your hands."
	icon = 'icons/obj/watercloset.dmi'
	icon_state = "sink"
	anchored = TRUE
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE
	flags = NOREACT
	var/tmp/busy = FALSE

/obj/structure/water_tap/New()
	..()
	create_reagents(PLUMBING_TAP_VOLUME)
	fluid_mark_dirty()

/obj/structure/water_tap/Destroy()
	fluid_mark_dirty()
	return ..()

/obj/structure/water_tap/fluid_demand_tier()
	return anchored ? FLUID_TIER_SINK : 0

/obj/structure/water_tap/fluid_demand(id)
	return anchored ? reagents.get_free_space() : 0

/obj/structure/water_tap/fluid_receive(id, amount, data)
	if (fluid_demand(id) <= 0)
		return 0
	return fluid_add_to(reagents, id, amount, data)

/obj/structure/water_tap/examine(mob/user, distance)
	..(user, distance)
	if (reagents.total_volume)
		to_chat(user, SPAN_NOTICE("It holds [round(reagents.total_volume)] of [PLUMBING_TAP_VOLUME] units, mostly [reagents.get_master_reagent_name()]."))
	else
		to_chat(user, SPAN_WARNING("It is dry. Pipe it to a pumped network with water on it."))

/obj/structure/water_tap/proc/dry_check(mob/user, amount = 1)
	if (reagents.total_volume < amount)
		to_chat(user, SPAN_WARNING("\The [src] is dry."))
		return TRUE
	return FALSE

/obj/structure/water_tap/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/reagent_containers) && W.reagents && W.is_open_container())
		if (dry_check(user))
			return TRUE
		var/obj/item/weapon/reagent_containers/RG = W
		var/room = RG.reagents.get_free_space()
		if (room <= 0)
			to_chat(user, SPAN_WARNING("\The [RG] is full."))
			return TRUE
		var/moved = reagents.trans_to_obj(RG, min(room, RG.amount_per_transfer_from_this))
		user.visible_message(SPAN_NOTICE("[user] fills \the [RG] at \the [src]."), SPAN_NOTICE("You fill \the [RG] with [round(moved, 0.1)] units at \the [src]."))
		playsound(loc, 'sound/effects/sink.ogg', 50, TRUE)
		user.setClickCooldown(5)
		return TRUE
	return ..()

/obj/structure/water_tap/attack_hand(mob/living/user as mob)
	if (!istype(user) || !Adjacent(user) || busy)
		return
	if (ishuman(user) && user.a_intent == I_GRAB)
		var/mob/living/human/H = user
		if (dry_check(H, PLUMBING_TAP_DRINK))
			return
		H.visible_message("[H] starts drinking from \the [src]...", "You start drinking from \the [src]...")
		busy = TRUE
		if (do_after(H, 30, src) && reagents.total_volume >= PLUMBING_TAP_DRINK)
			reagents.trans_to_mob(H, PLUMBING_TAP_DRINK, CHEM_INGEST)
			to_chat(H, "You drink from \the [src].")
			playsound(H.loc, "drink", rand(10, 50), TRUE)
		busy = FALSE
		return
	if (reagents.get_reagent_amount("water") < PLUMBING_TAP_WASH)
		to_chat(user, SPAN_WARNING("\The [src] has no clean water to wash with."))
		return
	to_chat(user, SPAN_NOTICE("You start washing your hands."))
	busy = TRUE
	playsound(loc, 'sound/effects/sink.ogg', 50, TRUE)
	if (do_after(user, 40, src) && reagents.get_reagent_amount("water") >= PLUMBING_TAP_WASH)
		reagents.remove_reagent("water", PLUMBING_TAP_WASH)
		user.clean_blood()
		if (ishuman(user))
			var/mob/living/human/H = user
			H.update_inv_gloves()
		user.visible_message(SPAN_NOTICE("[user] washes their hands at \the [src]."))
	busy = FALSE

// ---------------------------------------------------------------- shower

/obj/structure/shower/piped
	name = "piped shower"
	desc = "A shower head on a pipe network. It only runs while the pipes keep it supplied with water."
	not_movable = FALSE
	var/water_stored = 0

/obj/structure/shower/piped/New()
	..()
	fluid_mark_dirty()

/obj/structure/shower/piped/Destroy()
	fluid_mark_dirty()
	return ..()

/obj/structure/shower/piped/fluid_demand_tier()
	return anchored ? FLUID_TIER_SINK : 0

/obj/structure/shower/piped/fluid_demand(id)
	if (!anchored || id != "water")
		return 0
	return max(0, PLUMBING_SHOWER_VOLUME - water_stored)

/obj/structure/shower/piped/fluid_receive(id, amount, data)
	var/taken = min(amount, fluid_demand(id))
	if (taken <= 0)
		return 0
	water_stored += taken
	return taken

/obj/structure/shower/piped/examine(mob/user, distance)
	..(user, distance)
	to_chat(user, SPAN_NOTICE("Water in the line: [round(water_stored)]/[PLUMBING_SHOWER_VOLUME] units."))

/obj/structure/shower/piped/attack_hand(mob/M as mob)
	if (!on && water_stored < PLUMBING_SHOWER_USE)
		to_chat(M, SPAN_WARNING("Nothing comes out of \the [src]. Its pipe has no water."))
		return
	return ..()

/obj/structure/shower/piped/process()
	if (!on)
		return
	if (water_stored < PLUMBING_SHOWER_USE)
		on = FALSE
		update_icon()
		visible_message(SPAN_WARNING("\The [src] sputters and runs dry."))
		return
	water_stored -= PLUMBING_SHOWER_USE
	return ..()

#undef PLUMBING_TAP_VOLUME
#undef PLUMBING_TAP_DRINK
#undef PLUMBING_TAP_WASH
#undef PLUMBING_SHOWER_VOLUME
#undef PLUMBING_SHOWER_USE
