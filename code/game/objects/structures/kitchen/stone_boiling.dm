// Heat is carried by a stone; the wooden mug never enters the fire or kiln.
/obj/structure/proc/stone_heat_ready()
	return FALSE
/obj/structure/proc/stone_heat_token()
	return null
/obj/structure/proc/stone_heat_busy()
	return TRUE
/obj/structure/proc/stone_heat_claim()
	return FALSE
/obj/structure/proc/stone_heat_release()
	return

/obj/structure/oven/fireplace/stone_heat_ready()
	return on && fuel >= 1
/obj/structure/oven/fireplace/stone_heat_token()
	return stone_boil_epoch
/obj/structure/oven/fireplace/stone_heat_busy()
	return stone_boil_busy
/obj/structure/oven/fireplace/stone_heat_claim()
	if (stone_boil_busy || !stone_heat_ready())
		return FALSE
	stone_boil_busy = TRUE
	return TRUE
/obj/structure/oven/fireplace/stone_heat_release()
	stone_boil_busy = FALSE

/obj/structure/furnace/kiln/stone/campfire/stone_heat_ready()
	return on && stone_kiln_cycle && fuel >= 1
/obj/structure/furnace/kiln/stone/campfire/stone_heat_token()
	return stone_kiln_cycle
/obj/structure/furnace/kiln/stone/campfire/stone_heat_busy()
	return stone_boil_busy
/obj/structure/furnace/kiln/stone/campfire/stone_heat_claim()
	if (stone_boil_busy || !stone_heat_ready())
		return FALSE
	stone_boil_busy = TRUE
	return TRUE
/obj/structure/furnace/kiln/stone/campfire/stone_heat_release()
	stone_boil_busy = FALSE

/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/wood
	var/tmp/stone_boil_busy = FALSE
	var/tmp/datum/stone_boil_reagent_identity

/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/wood/persistence_runtime_var(key)
	return key == "stone_boil_busy" || key == "stone_boil_reagent_identity" || ..()

/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/wood/on_reagent_change()
	// Ordinary holder add/remove/delete operations notify the owning atom,
	// including safety-mode transfers. Never let an equal refill reuse the wait.
	if (stone_boil_busy)
		stone_boil_reagent_identity = new /datum
	..()

/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/wood/examine(mob/user)
	..()
	to_chat(user, SPAN_NOTICE("To boil water away from the flames, hold a stick or handle and use this mug's hot-stone action beside a lit campfire or active stone kiln with a stone on it. Boiling removes cholera and food poisoning, but leaves salt."))

/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/wood/proc/stone_boil_mixture()
	if (!reagents || reagents.get_reagent_amount("water") <= 0)
		return null
	var/list/mixture = list("water" = 0, "sodiumchloride" = 0, "cholera" = 0, "food_poisoning" = 0)
	for (var/datum/reagent/R in reagents.reagent_list)
		if (!(R.id in mixture))
			return null
		mixture[R.id] = R.volume
	return mixture

/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/wood/proc/stone_boil_valid(mob/living/human/H, obj/structure/F, obj/item/stack/material/stone/S, obj/item/tool, datum/reagents/holder, turf/site, epoch, datum/save_identity, datum/reagent_identity, list/mixture)
	if (QDELETED(src) || QDELETED(H) || QDELETED(F) || QDELETED(S) || QDELETED(tool) || QDELETED(holder))
		return FALSE
	if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required || persistence_admission_identity != save_identity)
		return FALSE
	if (H.stat != CONSCIOUS || H.incapacitated() || !H.Adjacent(F) || get_active_hand_owner(H) == FALSE)
		return FALSE
	if (!(istype(tool, /obj/item/weapon/branch) || istype(tool, /obj/item/weapon/material/handle)) || tool.loc != H || (H.l_hand != tool && H.r_hand != tool) || F.loc != site || S.loc != site || S.amount < 1 || !F.stone_heat_ready() || F.stone_heat_token() != epoch || reagents != holder || holder.my_atom != src || stone_boil_reagent_identity != reagent_identity || !is_open_container())
		return FALSE
	var/list/current = stone_boil_mixture()
	if (!current)
		return FALSE
	for (var/id in mixture)
		if (current[id] != mixture[id])
			return FALSE
	return TRUE

/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/wood/proc/get_active_hand_owner(mob/living/human/H)
	return loc == H && H.get_active_hand() == src

/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/wood/verb/stone_boil_water()
	set name = "Boil water with a hot stone"
	set category = null
	set src in usr
	if (!ishuman(usr))
		return
	var/mob/living/human/H = usr
	var/obj/item/tool = H.l_hand == src ? H.r_hand : H.l_hand
	var/obj/structure/F
	var/obj/item/stack/material/stone/S
	for (var/obj/structure/oven/fireplace/candidate in range(1, H))
		var/turf/T = get_turf(candidate)
		var/obj/item/stack/material/stone/stone = locate(/obj/item/stack/material/stone) in T
		if (candidate.loc == T && candidate.stone_heat_ready() && !candidate.stone_heat_busy() && stone && stone.amount >= 1)
			F = candidate
			S = stone
			break
	if (!F)
		for (var/obj/structure/furnace/kiln/stone/campfire/candidate in range(1, H))
			var/turf/T = get_turf(candidate)
			var/obj/item/stack/material/stone/stone = locate(/obj/item/stack/material/stone) in T
			if (candidate.loc == T && candidate.stone_heat_ready() && !candidate.stone_heat_busy() && stone && stone.amount >= 1)
				F = candidate
				S = stone
				break
	var/list/mixture = stone_boil_mixture()
	if (!(istype(tool, /obj/item/weapon/branch) || istype(tool, /obj/item/weapon/material/handle)) || !F || !S || !mixture || stone_boil_busy || F.stone_heat_busy())
		to_chat(H, SPAN_NOTICE("Hold this open mug and a stick or handle, with a stone on a lit campfire or active stone kiln that has spare fuel. The mug must contain water, salt, cholera or food poisoning only."))
		return
	var/datum/reagents/holder = reagents
	var/turf/site = get_turf(F)
	var/epoch = F.stone_heat_token()
	var/datum/save_identity = persistence_admission_identity
	stone_boil_reagent_identity = new /datum
	var/datum/reagent_identity = stone_boil_reagent_identity
	if (!stone_boil_valid(H, F, S, tool, holder, site, epoch, save_identity, reagent_identity, mixture))
		return
	if (!F.stone_heat_claim())
		return
	stone_boil_busy = TRUE
	to_chat(H, SPAN_NOTICE("You heat a stone and use the tool to move it into the mug, keeping the wood away from the fire."))
	var/completed = do_after(H, 100, F)
	if (completed && stone_boil_valid(H, F, S, tool, holder, site, epoch, save_identity, reagent_identity, mixture))
		F.burn_structure_fuel(1)
		holder.del_reagent("cholera")
		holder.del_reagent("food_poisoning")
		to_chat(H, SPAN_NOTICE("The water has boiled. Salt remains in the mug."))
	if (!QDELETED(src))
		stone_boil_busy = FALSE
	if (!QDELETED(F))
		F.stone_heat_release()
