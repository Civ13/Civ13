// Willow trees and willow bark: a mild natural painkiller.
//
// Weeping willows grow beside fresh water in temperate and taiga areas. Strip
// their bark with a knife (any intent but harm) and chew it for slow, mild
// pain relief, or steep it in water for willow bark tea. In chemistry the
// bark's salicin turns into salicylic acid with sulphuric acid, and salicylic
// acid with ethanol makes aspirin, which the tablet presses already accept.

#define WILLOW_BARK_STRIPS 4
#define WILLOW_BARK_REGROW 12000 // one strip per 20 minutes
#define WILLOW_SEED_DELAY_FIRES 150 // ticker fires (2 s) after the round starts
#define WILLOW_SEED_MAX 150
#define WILLOW_SEED_VIEW_MARGIN 20

/obj/structure/wild/tree/live_tree/willow
	name = "willow tree"
	desc = "A weeping willow, its long thin branches trailing toward the water. Its bark is known to dull pain."
	icon = 'icons/obj/flora/willow.dmi'
	icon_state = "willow_1"
	current_icon = 'icons/obj/flora/willow.dmi'
	// Gorilla leaf foraging swaps in the oak sprite sheet; willows keep their curtain.
	edible = FALSE
	leaves = 0
	max_leaves = 0
	var/bark_strips = WILLOW_BARK_STRIPS
	var/tmp/bark_regrow_pending = FALSE
	var/tmp/bark_busy = FALSE

/obj/structure/wild/tree/live_tree/willow/New()
	..()
	icon = current_icon
	icon_state = willow_state()
	deadicon = 'icons/obj/flora/deadtrees.dmi'
	deadicon_state = "tree_[willow_variant()]"
	// Restored trees get their saved strip count after New; check later.
	schedule_bark_regrowth()

/obj/structure/wild/tree/live_tree/willow/get_saved_vars()
	. = ..()
	// Wild objects use an allowlist. Include zero as well as positive stock.
	. |= "bark_strips"

/obj/structure/wild/tree/live_tree/willow/persistence_runtime_var(key)
	return key == "bark_regrow_pending" || key == "bark_busy" || ..()

// Stable per tile, so a reload shows the same tree.
/obj/structure/wild/tree/live_tree/willow/proc/willow_variant()
	var/turf/T = get_turf(src)
	if (!T)
		return 1
	return ((T.x * 7 + T.y * 13 + T.z) % 3) + 1

/obj/structure/wild/tree/live_tree/willow/proc/willow_state()
	var/suffix = ""
	if (season == "WINTER")
		suffix = "_winter"
	else if (season in list("FALL", "Dry Season"))
		suffix = "_autumn"
	return "willow_[willow_variant()][suffix]"

/obj/structure/wild/tree/live_tree/willow/update_icon()
	#if CIV13_ROOT_TREE_PRESENTATION
	root_tree_invalidate(src)
	#endif
	if (radiation >= 15)
		icon = deadicon
		icon_state = deadicon_state
		return
	icon = current_icon
	icon_state = willow_state()

/obj/structure/wild/tree/live_tree/willow/change_season()
	current_icon = 'icons/obj/flora/willow.dmi'
	update_icon()

/obj/structure/wild/tree/live_tree/willow/proc/schedule_bark_regrowth()
	if (bark_regrow_pending)
		return
	bark_regrow_pending = TRUE
	addtimer(CALLBACK(src, PROC_REF(regrow_bark)), WILLOW_BARK_REGROW)

/obj/structure/wild/tree/live_tree/willow/proc/regrow_bark()
	if (QDELETED(src))
		return
	bark_regrow_pending = FALSE
	if (!isnum(bark_strips) || bark_strips < 0)
		bark_strips = 0
	if (bark_strips < WILLOW_BARK_STRIPS)
		bark_strips++
	if (bark_strips < WILLOW_BARK_STRIPS)
		schedule_bark_regrowth()

/obj/structure/wild/tree/live_tree/willow/examine(mob/user, distance = -1)
	..()
	if (radiation >= 15)
		return
	if (bark_strips > 0)
		to_chat(user, SPAN_NOTICE("Its bark could be stripped with a knife."))
	else
		to_chat(user, SPAN_NOTICE("Its bark has been stripped bare and is growing back."))

/obj/structure/wild/tree/live_tree/willow/attackby(obj/item/W, mob/user)
	if (!willow_bark_tool(W) || !user || user.a_intent == I_HARM)
		return ..()
	user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	if (bark_busy || QDELETED(src) || !isturf(loc) || !user.Adjacent(src) || user.stat != CONSCIOUS || user.incapacitated())
		return TRUE
	if (radiation >= 15)
		to_chat(user, SPAN_WARNING("This willow is dead; its bark is dry and useless."))
		return TRUE
	if (bark_strips <= 0)
		to_chat(user, SPAN_NOTICE("The bark has already been stripped. Give it time to grow back."))
		return TRUE
	bark_busy = TRUE
	user.visible_message(SPAN_NOTICE("[user] starts stripping bark from \the [src]."), SPAN_NOTICE("You start stripping bark from \the [src]."))
	var/completed = do_after(user, 40, src)
	if (QDELETED(src))
		return TRUE
	bark_busy = FALSE
	if (!completed || QDELETED(user) || QDELETED(W) || user.get_active_hand() != W || !user.Adjacent(src) || bark_strips <= 0)
		return TRUE
	if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required)
		to_chat(user, SPAN_WARNING("You cannot strip bark during persistence operations."))
		return TRUE
	bark_strips--
	new /obj/item/weapon/reagent_containers/food/snacks/willow_bark(get_turf(user))
	to_chat(user, SPAN_NOTICE("You peel off a strip of willow bark."))
	schedule_bark_regrowth()
	return TRUE

/proc/willow_bark_tool(obj/item/W)
	return istype(W, /obj/item/weapon/material/kitchen/utensil/knife) || istype(W, /obj/item/weapon/material/thrown/throwing_knife) || istype(W, /obj/item/weapon/material/thrown/throwing_knife1)

/////////////////////////////// Willow bark ///////////////////////////////

/obj/item/weapon/reagent_containers/food/snacks/willow_bark
	name = "willow bark"
	desc = "A strip of inner willow bark. Chew it slowly to dull pain, or steep it in a container of water to make a bitter tea."
	icon = 'icons/obj/bark.dmi'
	icon_state = "bark"
	color = "#C8B48A"
	filling_color = "#8A6E3F"
	nutriment_amt = 0
	nutriment_desc = list("bitter bark" = 1)
	bitesize = 2
	decay = 0
	w_class = ITEM_SIZE_TINY
	flammable = TRUE
	value = 2

/obj/item/weapon/reagent_containers/food/snacks/willow_bark/New()
	..()
	reagents.add_reagent("salicin", 10)

// Hold the bark and click an open container with at least 10 water.
/obj/item/weapon/reagent_containers/food/snacks/willow_bark/resolve_attackby(atom/A, mob/user, icon_x, icon_y)
	if (!isobj(A) || !A.reagents || istype(A, /obj/item/weapon/reagent_containers/food/snacks))
		return ..()
	var/obj/vessel = A
	if (!vessel.is_open_container() || !vessel.reagents.has_reagent("water"))
		return ..()
	steep(vessel, user)
	return TRUE

/obj/item/weapon/reagent_containers/food/snacks/willow_bark/proc/steep(obj/vessel, mob/user)
	if (!user || QDELETED(src) || QDELETED(vessel) || !reagents || !reagents.total_volume)
		return FALSE
	if (!vessel.is_open_container() || !vessel.reagents.has_reagent("water", 10) || !(vessel.loc == user || (isturf(vessel.loc) && user.Adjacent(vessel))))
		to_chat(user, SPAN_WARNING("Steep the bark in an open container holding at least 10 units of water."))
		return FALSE
	if (vessel.reagents.get_free_space() < reagents.total_volume)
		to_chat(user, SPAN_WARNING("\The [vessel] is too full to steep the bark in."))
		return FALSE
	reagents.trans_to_obj(vessel, reagents.total_volume)
	to_chat(user, SPAN_NOTICE("You steep the willow bark in \the [vessel]. The water turns into a bitter, pale brown tea."))
	qdel(src)
	return TRUE

/////////////////////////////// Salicin ///////////////////////////////

/datum/reagent/salicin
	name = "Salicin"
	id = "salicin"
	description = "The bitter painkilling compound of willow bark. Milder and slower than aspirin, it eases pain and fever."
	taste_description = "bitter bark"
	reagent_state = LIQUID
	color = "#B59A6A"
	overdose = 40
	scannable = TRUE
	metabolism = 0.03

/datum/reagent/salicin/affect_blood(var/mob/living/human/M, var/alien, var/removed)
	M.add_chemical_effect(CE_PAINKILLER, 25)
	if (istype(M, /mob/living/human))
		var/mob/living/human/HH = M
		if (HH.disease == 1 && HH.disease_type == "flu")
			HH.disease_treatment = TRUE

// Chewed or drunk, salicin works at full strength: it is meant to be taken by mouth.
/datum/reagent/salicin/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
	affect_blood(M, alien, removed)

/datum/reagent/salicin/overdose(var/mob/living/human/M, var/alien)
	..()
	if (prob(5))
		to_chat(M, SPAN_WARNING("Your stomach churns from all the bitter bark."))
		M.adjustToxLoss(0.5)

// Willow bark extract to salicylic acid (game conversion: acid hydrolysis and oxidation).
/datum/chemical_reaction/salicylic_acid_from_salicin
	name = "Salicylic Acid"
	id = "salicylic_acid_from_salicin"
	result = "sal_acid"
	required_reagents = list("salicin" = 2, "sacid" = 1)
	result_amount = 2

// Salicylic acid to aspirin (game stand-in for acetylation).
/datum/chemical_reaction/aspirin_from_salicylic_acid
	name = "Aspirin"
	id = "aspirin_from_salicylic_acid"
	result = "aspirin"
	required_reagents = list("sal_acid" = 2, "ethanol" = 1)
	result_amount = 2

/////////////////////////////// Willow stands ///////////////////////////////

// Nomads worlds turn some ordinary riverside trees into willows once per boot,
// topping up to a target so saved worlds keep the willows they already have.
var/global/willow_seed_state = 0 // 0 waiting, 1 running, 2 done
var/global/willow_seed_wait = 0
var/global/willow_seed_report = ""

/proc/willow_seed_check()
	if (willow_seed_state || !map || !map.ecology_wildlife)
		return
	if (!ticker || ticker.current_state != GAME_STATE_PLAYING)
		return
	if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required)
		return
	if (++willow_seed_wait < WILLOW_SEED_DELAY_FIRES)
		return
	willow_seed_state = 1
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(willow_seed_run)), 1)

/proc/willow_seed_run()
	willow_seed_stands()
	willow_seed_state = 2

/proc/willow_riverside(turf/T)
	if (!T)
		return FALSE
	var/climate = ecology_outdoor_climate(T)
	if (!(climate in list("temperate", "taiga")))
		return FALSE
	for (var/turf/W in range(2, T))
		if (istype(W, /turf/floor/beach/water) && ecology_ground(W))
			return TRUE
	return FALSE

/proc/willow_seed_stands(force_visible = FALSE)
	var/list/candidates = list()
	var/willows = 0
	// One yielding pass per boot; trees have no typed registry to walk instead.
	for (var/obj/structure/wild/tree/live_tree/T in world)
		CHECK_TICK
		if (T.gcDestroyed || !isturf(T.loc))
			continue
		if (istype(T, /obj/structure/wild/tree/live_tree/willow))
			willows++
			continue
		if (T.type != /obj/structure/wild/tree/live_tree || T.radiation >= 15)
			continue
		if (willow_riverside(T.loc))
			candidates += T
	var/target = min(WILLOW_SEED_MAX, max(round(candidates.len / 5), min(candidates.len, 6)))
	var/needed = target - willows
	var/planted = 0
	while (needed > 0 && candidates.len)
		CHECK_TICK
		if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required)
			break
		var/obj/structure/wild/tree/live_tree/T = pick_n_take(candidates)
		if (!T || T.gcDestroyed || !isturf(T.loc) || T.type != /obj/structure/wild/tree/live_tree)
			continue
		var/turf/site = T.loc
		if (!force_visible && ecology_visible_to_players(site, WILLOW_SEED_VIEW_MARGIN))
			continue
		var/old_x = T.pixel_x
		var/old_y = T.pixel_y
		var/old_health = T.health
		qdel(T)
		var/obj/structure/wild/tree/live_tree/willow/W = new(site)
		W.pixel_x = old_x
		W.pixel_y = old_y
		W.health = old_health
		planted++
		needed--
	willow_seed_report = "[willows] existing, [planted] new, target [target]"
	log_game("Willow stands: [willow_seed_report].")
	return planted

#undef WILLOW_BARK_STRIPS
#undef WILLOW_BARK_REGROW
#undef WILLOW_SEED_DELAY_FIRES
#undef WILLOW_SEED_MAX
#undef WILLOW_SEED_VIEW_MARGIN
