// Carburizing (docs/steelmaking.md): wrought iron bars packed in charcoal in
// a sealed clay pot and held at red heat soak up carbon and come out as
// blister steel. Finished iron tools packed with them are case-hardened.
// A smith folds two blister steel into one even steel on an anvil that
// works steel.

#define CARBURIZE_BAR_LIMIT 10 // wrought iron bars one pot holds
#define CARBURIZE_TOOL_LIMIT 3 // iron tools one pot case-hardens
#define CARBURIZE_HEAT_FUEL 4 // charcoal burnt around the pot to hold it at heat
#define CARBURIZE_BURN_TIME 6000 // deciseconds, ten minutes
#define CARBURIZE_TICK 100
#define CARBURIZE_CRACK_CHANCE 20 // percent chance a firing cracks the pot
#define CASE_HARDEN_FACTOR 1.15 // quality gained by a case-hardened tool
#define CASE_HARDEN_MAX 1.25
#define BLISTER_PER_FOLD 2 // blister steel folded into one steel

/obj/structure/carburizing_pot
	name = "carburizing pot"
	desc = "A lidded clay box for cementation. Pack it with wrought iron bars and charcoal, add charcoal to hold it at heat, then seal it with an empty hand. Ten minutes later the bars come out as blister steel. Iron tools packed in with them come out case-hardened."
	icon = 'icons/obj/steelmaking.dmi'
	icon_state = "carburizing_pot"
	density = TRUE
	anchored = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE
	var/bars = 0
	var/charcoal = 0
	var/burning = FALSE
	var/burn_left = 0 // deciseconds of firing left; saved, so a load resumes it
	var/packer_skill = 1 // Crafting coefficient of whoever sealed it
	var/tmp/burn_epoch = 0

/obj/structure/carburizing_pot/persistence_runtime_var(key)
	return key == "burn_epoch" || ..()

/obj/structure/carburizing_pot/proc/packed_tools()
	. = list()
	for (var/obj/item/weapon/material/W in contents)
		. += W

// Charcoal the firing needs: one per bar and per tool, plus the heat.
/obj/structure/carburizing_pot/proc/charcoal_needed()
	return bars + length(packed_tools()) + CARBURIZE_HEAT_FUEL

// Percent of bars that come out unevenly carburized and stay iron.
/obj/structure/carburizing_pot/proc/uneven_chance()
	return clamp(round(20 - (packer_skill - 1) * 30), 5, 30)

/obj/structure/carburizing_pot/update_icon()
	icon_state = burning ? "carburizing_pot_on" : "carburizing_pot"
	set_light(burning ? 2 : 0)

/obj/structure/carburizing_pot/examine(mob/user, distance)
	..(user, distance)
	var/tools = length(packed_tools())
	if (burning)
		to_chat(user, SPAN_NOTICE("It glows at red heat, sealed. About [max(1, round(burn_left / 600))] minute\s left."))
	else
		to_chat(user, SPAN_NOTICE("It holds [bars] of [CARBURIZE_BAR_LIMIT] iron bars, [tools] of [CARBURIZE_TOOL_LIMIT] iron tools and [charcoal] charcoal. Sealing and firing it takes [charcoal_needed()] charcoal."))

/obj/structure/carburizing_pot/attackby(obj/item/I, mob/living/human/H)
	if (!I || !I.loc || !istype(H))
		return
	if (is_tool(I, TOOL_HAMMER))
		unpack(H)
		return
	if (burning)
		to_chat(H, SPAN_WARNING("\The [src] is sealed and firing. Wait for it to cool."))
		return
	if (istype(I, /obj/item/stack/ore/charcoal))
		var/obj/item/stack/S = I
		var/moved = min(S.amount, CARBURIZE_BAR_LIMIT + CARBURIZE_TOOL_LIMIT + CARBURIZE_HEAT_FUEL - charcoal)
		if (moved <= 0)
			to_chat(H, SPAN_WARNING("\The [src] can't take more charcoal."))
			return
		charcoal += moved
		S.use(moved)
		visible_message(SPAN_NOTICE("[H] packs [moved] charcoal into \the [src]."))
		return
	if (istype(I, /obj/item/stack/material/iron))
		var/obj/item/stack/S = I
		var/moved = min(S.amount, CARBURIZE_BAR_LIMIT - bars)
		if (moved <= 0)
			to_chat(H, SPAN_WARNING("\The [src] holds no more bars."))
			return
		bars += moved
		S.use(moved)
		visible_message(SPAN_NOTICE("[H] packs [moved] iron bar\s into \the [src]."))
		return
	if (istype(I, /obj/item/weapon/material))
		var/obj/item/weapon/material/W = I
		if (W.get_material_name() != "iron")
			to_chat(H, SPAN_WARNING("Only iron takes up carbon. Steel is hard already, and other metals gain nothing."))
			return
		if (length(packed_tools()) >= CARBURIZE_TOOL_LIMIT)
			to_chat(H, SPAN_WARNING("\The [src] holds no more tools."))
			return
		H.remove_from_mob(W)
		W.forceMove(src)
		visible_message(SPAN_NOTICE("[H] packs \the [W] into \the [src]."))
		return
	return ..()

/obj/structure/carburizing_pot/attack_hand(mob/living/human/H)
	if (!istype(H))
		return
	seal(H)

/obj/structure/carburizing_pot/proc/seal(mob/living/human/H)
	if (burning)
		to_chat(H, SPAN_NOTICE("\The [src] is already firing."))
		return
	if (!bars && !length(packed_tools()))
		to_chat(H, SPAN_WARNING("Pack wrought iron bars or iron tools into \the [src] first."))
		return
	if (charcoal < charcoal_needed())
		to_chat(H, SPAN_WARNING("\The [src] needs [charcoal_needed()] charcoal to pack and fire it; it holds [charcoal]."))
		return
	visible_message(SPAN_NOTICE("[H] starts luting the lid of \the [src] shut with clay."), SPAN_NOTICE("You lute the lid shut and bank the fire around the pot."))
	if (!do_after(H, 50, src) || QDELETED(src) || burning || charcoal < charcoal_needed())
		return
	packer_skill = H.getStatCoeff("crafting")
	charcoal -= charcoal_needed()
	burning = TRUE
	burn_left = CARBURIZE_BURN_TIME
	update_icon()
	visible_message(SPAN_NOTICE("\The [src] is sealed and set in the fire."))
	start_burn_loop()

/obj/structure/carburizing_pot/proc/start_burn_loop()
	addtimer(CALLBACK(src, PROC_REF(burn_tick), ++burn_epoch), CARBURIZE_TICK)

/obj/structure/carburizing_pot/proc/burn_tick(epoch)
	if (QDELETED(src) || !burning || epoch != burn_epoch)
		return
	burn_left -= CARBURIZE_TICK
	if (burn_left <= 0)
		finish_burn()
		return
	addtimer(CALLBACK(src, PROC_REF(burn_tick), epoch), CARBURIZE_TICK)

/obj/structure/carburizing_pot/proc/finish_burn()
	burning = FALSE
	burn_left = 0
	burn_epoch++
	var/turf/T = get_turf(src)
	var/uneven = 0
	for (var/i in 1 to bars)
		if (prob(uneven_chance()))
			uneven++
	if (bars - uneven > 0)
		spawn_stack(/obj/item/stack/material/steel/blister, T, bars - uneven)
	if (uneven > 0)
		spawn_stack(/obj/item/stack/material/iron, T, uneven)
	for (var/obj/item/weapon/material/W in packed_tools())
		case_harden(W)
		W.forceMove(T)
	var/made = bars - uneven
	bars = 0
	update_icon()
	visible_message(SPAN_NOTICE("\The [src] cools. Broken open, it gives [made] bar\s of blister steel[uneven ? " and [uneven] bar\s that took too little carbon" : ""]."))
	if (prob(CARBURIZE_CRACK_CHANCE))
		visible_message(SPAN_WARNING("\The [src] cracks as it cools and falls apart."))
		new /obj/item/weapon/clay(T)
		qdel(src)

// A case-hardened iron tool keeps a soft core under a hard steel skin.
/proc/case_harden(obj/item/weapon/material/W)
	if (!istype(W) || W.get_material_name() != "iron")
		return FALSE
	var/hardened = min(CASE_HARDEN_MAX, W.crafting_quality * CASE_HARDEN_FACTOR)
	if (W.crafting_quality >= hardened)
		return FALSE
	W.crafting_quality = hardened
	W.update_force()
	return TRUE

// A hammer opens a cold pot and takes everything back out.
/obj/structure/carburizing_pot/proc/unpack(mob/living/human/H)
	if (burning)
		to_chat(H, SPAN_WARNING("\The [src] is sealed and firing. Opening it now would burn the charcoal away."))
		return
	if (!bars && !charcoal && !length(packed_tools()))
		visible_message(SPAN_NOTICE("[H] breaks up the empty [name]."))
		new /obj/item/weapon/clay(get_turf(src))
		qdel(src)
		return
	var/turf/T = get_turf(src)
	if (bars)
		spawn_stack(/obj/item/stack/material/iron, T, bars)
	if (charcoal)
		spawn_stack(/obj/item/stack/ore/charcoal, T, charcoal)
	for (var/obj/item/weapon/material/W in packed_tools())
		W.forceMove(T)
	bars = 0
	charcoal = 0
	visible_message(SPAN_NOTICE("[H] unpacks \the [src]."))

/obj/structure/carburizing_pot/after_load()
	..()
	burn_epoch = 0
	if (burning)
		if (burn_left <= 0)
			burn_left = CARBURIZE_TICK
		start_burn_loop()
	update_icon()

//////////////////////////////////////////////////////////////////////////////
// Folding blister steel: shear steel. Two uneven bars welded and drawn out
// together even out into one bar of steel.

/obj/structure/anvil/proc/fold_blister_steel(obj/item/stack/material/steel/blister/P, mob/living/human/H)
	var/choice = WWinput(H, "Fold the blister steel into even steel ([BLISTER_PER_FOLD] make 1), or forge it as it is?", "Anvil", "Cancel", list("Fold into steel", "Forge as it is", "Cancel"))
	if (choice == "Forge as it is")
		return FALSE
	if (choice != "Fold into steel")
		return TRUE
	if (P.amount < BLISTER_PER_FOLD)
		to_chat(H, SPAN_WARNING("Fold at least [BLISTER_PER_FOLD] bars of blister steel together."))
		return TRUE
	var/initial_amount = P.amount
	var/batches = round(initial_amount / BLISTER_PER_FOLD)
	to_chat(H, "You begin folding the blister steel...")
	icon_state = "[base_icon]_anvil_use"
	in_use = TRUE
	update_icon()
	playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
	var/done = do_after(H, 15 * batches * BLISTER_PER_FOLD, src)
	in_use = FALSE
	update_icon()
	if (!done || QDELETED(P) || P.amount != initial_amount)
		return TRUE
	P.use(batches * BLISTER_PER_FOLD)
	spawn_stack(/obj/item/stack/material/steel, loc, batches)
	to_chat(H, SPAN_NOTICE("You weld, fold and draw out the blister steel into [batches] bar\s of even steel."))
	return TRUE

#undef CARBURIZE_BAR_LIMIT
#undef CARBURIZE_TOOL_LIMIT
#undef CARBURIZE_HEAT_FUEL
#undef CARBURIZE_BURN_TIME
#undef CARBURIZE_TICK
#undef CARBURIZE_CRACK_CHANCE
#undef CASE_HARDEN_FACTOR
#undef CASE_HARDEN_MAX
#undef BLISTER_PER_FOLD
