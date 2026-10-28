// Upgrade the existing campfire into the existing stone kiln, without creating fuel.
/obj/structure/oven/fireplace/proc/stone_kiln_upgrade_valid(obj/item/stack/material/stone/S, mob/living/human/H, turf/site, epoch, datum/save_identity)
	if (QDELETED(src) || QDELETED(S) || QDELETED(H) || type != /obj/structure/oven/fireplace || S.type != /obj/item/stack/material/stone)
		return FALSE
	if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required || persistence_admission_identity != save_identity)
		return FALSE
	if (!map || !map.is_node_done(H.civilization, "basic_furniture") || H.stat != CONSCIOUS || H.incapacitated() || !H.Adjacent(src) || H.get_active_hand() != S || S.loc != H || !H.canUnEquip(S) || S.amount < 10)
		return FALSE
	if (loc != site || !isturf(site) || on || stone_boil_busy || stone_boil_epoch != epoch || contents.len || parts)
		return FALSE
	for (var/obj/item/weapon/reagent_containers/glass/small_pot/P in site)
		if (P.on_stove)
			return FALSE
	return TRUE

/obj/structure/oven/fireplace/proc/upgrade_to_stone_kiln(obj/item/stack/material/stone/S, mob/living/human/H)
	if (stone_upgrade_busy)
		return FALSE
	var/turf/site = get_turf(src)
	var/epoch = stone_boil_epoch
	var/datum/save_identity = persistence_admission_identity
	if (!stone_kiln_upgrade_valid(S, H, site, epoch, save_identity))
		to_chat(H, SPAN_NOTICE("Extinguish and empty the campfire, remove any pot, and hold ten stone. Basic Furniture must be researched."))
		return FALSE
	stone_upgrade_busy = TRUE
	to_chat(H, SPAN_NOTICE("You begin building a stone kiln around the extinguished campfire."))
	var/completed = do_after(H, 150, src)
	if (QDELETED(src))
		return FALSE
	if (!completed || !stone_kiln_upgrade_valid(S, H, site, epoch, save_identity))
		stone_upgrade_busy = FALSE
		return FALSE
	var/obj/structure/furnace/kiln/stone/campfire/K = new(site)
	if (QDELETED(K) || !stone_kiln_upgrade_valid(S, H, site, epoch, save_identity))
		if (!QDELETED(K))
			qdel(K)
		if (!QDELETED(src))
			stone_upgrade_busy = FALSE
		return FALSE
	if (!S.can_use(10))
		qdel(K)
		stone_upgrade_busy = FALSE
		return FALSE
	var/stone_before = S.amount
	S.use(10) // Verify the actual debit, including the exhausted-stack case.
	if ((!QDELETED(S) && S.amount != stone_before - 10) || (QDELETED(S) && stone_before != 10))
		qdel(K)
		stone_upgrade_busy = FALSE
		return FALSE
	if (QDELETED(src) || QDELETED(K) || persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required || persistence_admission_identity != save_identity || loc != site || on || stone_boil_epoch != epoch)
		if (!QDELETED(S))
			S.amount += 10
		else
			new /obj/item/stack/material/stone(site, 10)
		if (!QDELETED(K))
			qdel(K)
		if (!QDELETED(src))
			stone_upgrade_busy = FALSE
		return FALSE
	// No yielding between paid consumption, ownership transfer and retirement.
	var/datum/wood_fuel_residue/account = wood_residue_account()
	K.fuel = fuel
	fuel = 0
	K.wood_residue = account
	wood_residue = null
	stone_upgrade_busy = FALSE
	visible_message(SPAN_NOTICE("[H] finishes building a stone kiln around the campfire."))
	qdel(src)
	return TRUE

// This is the existing stone kiln's processing and sprite, with a vessel slot
// and the broader heat-source fuel contract for campfire-built kilns.
/obj/structure/furnace/kiln/stone/campfire
	desc = "A stone kiln built around a campfire. It can smelt molds and boil water in a suitable small pot."
	var/tmp/stone_refuel_busy = FALSE
	var/tmp/datum/stone_kiln_cycle
	var/tmp/stone_boil_busy = FALSE

/obj/structure/furnace/kiln/stone/campfire/persistence_runtime_var(key)
	return key == "stone_refuel_busy" || key == "stone_kiln_cycle" || key == "stone_boil_busy" || ..()

/obj/structure/furnace/kiln/stone/campfire/after_load()
	..()
	// A saved pending cycle is not resumed and its already burned fuel is not refunded.
	on = FALSE
	update_icon()

/obj/structure/furnace/kiln/stone/campfire/examine(mob/user)
	..()
	to_chat(user, SPAN_NOTICE("For a wooden mug, heat a stone during a lit kiln cycle and use the mug's hot-stone action; keep the mug out of the flames. A filled flammable vessel is only burned as solid fuel when used with harm intent."))

/obj/structure/furnace/kiln/stone/campfire/proc/filled_vessel_hint(mob/user)
	to_chat(user, SPAN_NOTICE("Keep the filled vessel away from the flame. To boil water in a wooden mug, use its hot-stone action beside the lit kiln."))
	return TRUE

/obj/structure/furnace/kiln/stone/campfire/proc/boil_mixture(obj/item/weapon/reagent_containers/glass/small_pot/P)
	if (QDELETED(P) || P.flammable || !P.is_open_container() || !P.reagents || P.reagents.my_atom != P || P.reagents.get_reagent_amount("water") <= 0)
		return null
	var/list/amounts = list("water" = 0, "sodiumchloride" = 0, "cholera" = 0, "food_poisoning" = 0)
	for (var/datum/reagent/R in P.reagents.reagent_list)
		if (!(R.id in amounts))
			return null
		amounts[R.id] = R.volume
	return amounts

/obj/structure/furnace/kiln/stone/campfire/attackby(obj/item/I, mob/living/human/H)
	if (!istype(H) || QDELETED(I) || I.loc != H || H.get_active_hand() != I)
		return ..()
	var/filled_flammable_vessel = istype(I, /obj/item/weapon/reagent_containers) && I.flammable && I.reagents && I.reagents.total_volume > 0
	var/deliberate_burn = filled_flammable_vessel && H.a_intent == I_HARM
	if (H.a_intent != I_HELP && !deliberate_burn)
		if (filled_flammable_vessel)
			return filled_vessel_hint(H)
		return ..()
	if (on || stone_refuel_busy || stone_kiln_cycle || persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required)
		if (filled_flammable_vessel && !deliberate_burn)
			return filled_vessel_hint(H)
		return TRUE
	if (istype(I, /obj/item/weapon/clay/mold) && (!map || !map.is_node_done(H.civilization, "bronze_working")))
		to_chat(H, SPAN_NOTICE("Research Bronze Working before using this kiln for metallurgy."))
		return TRUE
	if (!deliberate_burn && istype(I, /obj/item/weapon/reagent_containers/glass/small_pot))
		var/obj/item/weapon/reagent_containers/glass/small_pot/P = I
		if (boil_mixture(P))
			for (var/obj/item/weapon/reagent_containers/glass/small_pot/other in contents)
				to_chat(H, SPAN_NOTICE("The kiln already holds a pot."))
				return TRUE
			if (!H.transfer_held_item_to(P, src) || QDELETED(P) || P.loc != src)
				return TRUE
			P.on_stove = FALSE
			to_chat(H, SPAN_NOTICE("You place the pot in the kiln."))
			return TRUE
	// An empty flammable glass vessel is solid fuel, even with its lid closed.
	// Only trust an owned holder's actual empty state; filled vessels stay protected.
	var/empty_flammable_glass = istype(I, /obj/item/weapon/reagent_containers/glass) && I.flammable && !QDELETED(I.reagents) && I.reagents.my_atom == I && I.reagents.total_volume == 0 && islist(I.reagents.reagent_list) && !I.reagents.reagent_list.len
	if (!deliberate_burn && !empty_flammable_glass && istype(I, /obj/item/weapon/reagent_containers/glass) && !istype(I, /obj/item/weapon/reagent_containers/glass/rag))
		var/obj/item/weapon/reagent_containers/glass/G = I
		if (!G.is_open_container() || !G.reagents || G.reagents.my_atom != G)
			if (filled_flammable_vessel)
				return filled_vessel_hint(H)
			return ..()
		var/datum/reagents/holder = G.reagents
		var/amount = 0
		stone_refuel_busy = TRUE
		for (var/id in heat_source_liquid_fuels())
			var/available = holder.get_reagent_amount(id)
			if (available > 0)
				if (holder.remove_reagent(id, available, TRUE))
					if (QDELETED(src))
						return TRUE
					fuel += heat_source_liquid_fuel_energy(available) / 60
					amount += available
			if (QDELETED(G) || QDELETED(holder) || G.reagents != holder)
				break
		stone_refuel_busy = FALSE
		if (amount > 0)
			if (!QDELETED(holder))
				holder.handle_reactions()
			to_chat(H, SPAN_NOTICE("You add liquid fuel to the kiln."))
			return TRUE
		if (filled_flammable_vessel)
			return filled_vessel_hint(H)
		return ..()
	if (filled_flammable_vessel && !deliberate_burn)
		return filled_vessel_hint(H)
	var/energy = heat_source_solid_fuel_energy(I)
	if (energy > 0)
		if (!H.canUnEquip(I))
			return TRUE
		var/credit = energy / 60
		record_wood_fuel(I, credit)
		fuel += credit
		qdel(I)
		to_chat(H, SPAN_NOTICE(deliberate_burn ? "You burn the filled vessel and its contents as fuel." : "You add fuel to the kiln."))
		return TRUE
	return ..()

/obj/structure/furnace/kiln/stone/campfire/verb/remove_boiling_pot()
	set name = "Remove boiling pot"
	set category = null
	set src in oview(1)
	if (on || stone_kiln_cycle || persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required)
		return
	for (var/obj/item/weapon/reagent_containers/glass/small_pot/P in contents)
		P.loc = get_turf(src)
		to_chat(usr, SPAN_NOTICE("You remove the pot."))
		return

/obj/structure/furnace/kiln/stone/campfire/attack_hand(mob/living/human/H)
	if (!istype(H) || on || stone_kiln_cycle || stone_refuel_busy || fuel < 2 || persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required)
		return
	for (var/obj/item/weapon/clay/mold/M in contents)
		if (!map || !map.is_node_done(H.civilization, "bronze_working"))
			to_chat(H, SPAN_NOTICE("Research Bronze Working before using this kiln for metallurgy."))
			return
	var/obj/item/weapon/reagent_containers/glass/small_pot/P
	for (var/obj/item/weapon/reagent_containers/glass/small_pot/candidate in contents)
		P = candidate
		break
	var/list/amounts = P ? boil_mixture(P) : null
	var/datum/reagents/holder = P ? P.reagents : null
	var/datum/identity
	var/datum/cycle = new /datum
	stone_kiln_cycle = cycle
	if (amounts)
		P.stone_kiln_reagent_identity = new /datum
		P.stone_kiln_owner = cycle
		identity = P.stone_kiln_reagent_identity
	var/datum/save_identity = persistence_admission_identity
	on = TRUE
	burn_structure_fuel(2)
	update_icon()
	visible_message(SPAN_NOTICE("[H] lights the stone kiln."))
	spawn(250)
		if (QDELETED(src))
			if (!QDELETED(P) && P.stone_kiln_owner == cycle)
				P.stone_kiln_reagent_identity = null
				P.stone_kiln_owner = null
			return
		if (stone_kiln_cycle != cycle)
			return
		if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required || persistence_admission_identity != save_identity)
			on = FALSE
			stone_kiln_cycle = null
			update_icon()
			if (!QDELETED(P) && P.stone_kiln_owner == cycle)
				P.stone_kiln_reagent_identity = null
				P.stone_kiln_owner = null
			return
		process()
		if (!QDELETED(src) && stone_kiln_cycle == cycle && !persistence_save_in_progress && !persistence_active_operation && !persistence_load_recovery_required && persistence_admission_identity == save_identity && !QDELETED(P) && P.loc == src && P.stone_kiln_owner == cycle && !QDELETED(holder) && P.reagents == holder && P.stone_kiln_reagent_identity == identity && amounts)
			var/list/current = boil_mixture(P)
			var/unchanged = !!current
			if (unchanged)
				for (var/id in amounts)
					if (amounts[id] != current[id])
						unchanged = FALSE
			if (unchanged)
				holder.del_reagent("cholera")
				holder.del_reagent("food_poisoning")
				visible_message(SPAN_NOTICE("The pot finishes boiling. Salt remains."))
		if (!QDELETED(P) && P.stone_kiln_owner == cycle)
			P.stone_kiln_reagent_identity = null
			P.stone_kiln_owner = null
		if (!QDELETED(src) && stone_kiln_cycle == cycle)
			on = FALSE
			stone_kiln_cycle = null
			update_icon()
