// Mortar and pestle: the stone-age grinder.
//
// Crafted from 2 stone. Hold an ingredient and click the mortar to grind it
// into the bowl, then pour the result like any other container:
// - wheat, oat or barley: 5 flour (half a mill's yield, no mill needed)
// - shelled sunflower seeds: 5 sunflower oil
// - one flax seed: 2 linseed oil
// - olives: 6 olive oil
// Sunflower and linseed oil burn in lamps and torches like other plant oils.

#define MORTAR_GRIND_TIME 30

/obj/item/weapon/reagent_containers/glass/mortar
	name = "mortar and pestle"
	desc = "A heavy stone bowl and a grinding stone. Grind grain into flour, or press seeds and olives into oil."
	icon = 'icons/obj/herbalism.dmi'
	icon_state = "mortar_pestle"
	item_state = null
	volume = 30
	amount_per_transfer_from_this = 5
	possible_transfer_amounts = list(5,10,15,30)
	w_class = ITEM_SIZE_NORMAL
	dropsound = 'sound/effects/drop_default.ogg'
	flammable = FALSE
	value = 3
	var/tmp/grinding = FALSE

/obj/item/weapon/reagent_containers/glass/mortar/persistence_runtime_var(key)
	return key == "grinding" || ..()

/obj/item/weapon/reagent_containers/glass/mortar/on_reagent_change()
	..()
	update_icon()

/obj/item/weapon/reagent_containers/glass/mortar/update_icon()
	icon_state = (reagents && reagents.total_volume > 0) ? "mortar_pestle_full" : "mortar_pestle"

// What one ingredient grinds into: list(reagent id = amount), or null.
/proc/mortar_grind_result(obj/item/I)
	if (istype(I, /obj/item/weapon/reagent_containers/food/snacks/grown/wheat))
		return list("flour" = 5)
	if (istype(I, /obj/item/weapon/reagent_containers/food/snacks/grown/oat))
		return list("oatflour" = 5)
	if (istype(I, /obj/item/weapon/reagent_containers/food/snacks/grown/barley))
		return list("barleyflour" = 5)
	if (istype(I, /obj/item/weapon/reagent_containers/food/snacks/grown/sunflower_seeds))
		return list("sunflower_oil" = 5)
	if (istype(I, /obj/item/stack/farming/seeds/flax))
		return list("linseed_oil" = 2)
	if (istype(I, /obj/item/weapon/reagent_containers/food/snacks/grown/olives))
		return list("olive_oil" = 6)
	return null

/obj/item/weapon/reagent_containers/glass/mortar/attackby(obj/item/W, mob/user)
	var/list/result = mortar_grind_result(W)
	if (!result)
		return ..()
	start_grinding(W, user)
	return TRUE

/obj/item/weapon/reagent_containers/glass/mortar/proc/start_grinding(obj/item/W, mob/user)
	if (grinding || !user || QDELETED(W))
		return FALSE
	if (!can_grind(W, user))
		return FALSE
	grinding = TRUE
	user.visible_message(SPAN_NOTICE("[user] starts grinding \the [W] in \the [src]."), SPAN_NOTICE("You start grinding \the [W] in \the [src]."))
	var/completed = do_after(user, MORTAR_GRIND_TIME, src)
	grinding = FALSE
	if (!completed || QDELETED(src) || QDELETED(W))
		return FALSE
	return finish_grinding(W, user)

/obj/item/weapon/reagent_containers/glass/mortar/proc/can_grind(obj/item/W, mob/user)
	var/list/result = mortar_grind_result(W)
	if (!result)
		return FALSE
	var/total = 0
	for (var/id in result)
		total += result[id]
	if (reagents.get_free_space() < total)
		to_chat(user, SPAN_WARNING("\The [src] is too full. Pour it out first."))
		return FALSE
	return TRUE

// The grinding itself, after the wait: one ingredient becomes its reagents.
/obj/item/weapon/reagent_containers/glass/mortar/proc/finish_grinding(obj/item/W, mob/user)
	if (!can_grind(W, user))
		return FALSE
	if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required)
		to_chat(user, SPAN_WARNING("You cannot grind during persistence operations."))
		return FALSE
	var/list/result = mortar_grind_result(W)
	if (istype(W, /obj/item/stack))
		var/obj/item/stack/S = W
		if (!S.use(1))
			return FALSE
	else
		qdel(W)
	for (var/id in result)
		reagents.add_reagent(id, result[id])
	to_chat(user, SPAN_NOTICE("You grind it down in \the [src]."))
	return TRUE

/////////////////////////////// Plant oils ///////////////////////////////

/datum/reagent/drink/olive_oil/sunflower_oil
	name = "Sunflower Oil"
	id = "sunflower_oil"
	description = "A light golden oil pressed from sunflower seeds. Good for cooking and lamps."
	taste_description = "sunflower seeds"
	color = "#E8C547"

/datum/reagent/drink/olive_oil/linseed_oil
	name = "Linseed Oil"
	id = "linseed_oil"
	description = "A thick amber oil pressed from flax seeds. It burns in lamps."
	taste_description = "bitter oil"
	color = "#B07A2A"

#undef MORTAR_GRIND_TIME
