// Lacquer and spirit varnish (Val, 2026-11-21; plan "Resin materials plan", PR 4).
//
// Lacquer: in the silk lands (Earth Asia, and lands that are not continents) a
// living broadleaf tree is also a lacquer tree. Use an open container on it
// while holding a knife in the other hand to cut the bark: the container
// catches LACQUER_TAP_AMOUNT units of raw lacquer, and the tree bleeds again
// after LACQUER_TAP_WAIT (runtime only, world_time_stamps.dm).
//
// Spirit varnish: resin dissolved in distilled ethanol, anywhere. Mix 2 resin
// with 1 ethanol in any container for 3 units of spirit varnish.
//
// Finishing: pour lacquer or varnish into a finishing pot (a pot with a brush)
// and use it, in help intent, on an item of wood, bamboo or leather, a wooden
// shield, or leather or lamellar armour. The coat costs FINISH_UNITS and makes
// the item wear 25% slower until it has soaked up its share of wear: lacquer
// lasts longer than varnish. A finish never changes armour or weapon stats.
// The finish and what is left of it are saved with the item.
//
// Sprites by Fable (icons/obj/resin_works.dmi). Nothing here sleeps outside
// the do_after waits.

#define LACQUER_TAP_AMOUNT 5
#define LACQUER_TAP_WAIT 12000 // twenty minutes of world.time
#define LACQUER_TAP_TIME 60
#define FINISH_UNITS 5
#define FINISH_TIME 40
#define FINISH_WEAR_MULTIPLIER 0.75

// finish id = list(name, wear it soaks up, examine text)
var/global/list/item_finishes = list(
	"lacquer" = list("lacquer", 150, "A deep, glossy coat of lacquer protects it from wear."),
	"spirit_varnish" = list("spirit varnish", 80, "A glossy coat of varnish protects it from wear."))

/obj/item/var/finish = null // finish id (item_finishes), if any
/obj/item/var/finish_left = 0 // wear the coat can still soak up

/datum/reagent/lacquer
	name = "Lacquer"
	id = "lacquer"
	description = "Raw lacquer sap, grey when fresh and drying to a hard black gloss. It brings up an angry rash on bare skin."
	taste_description = "bitter sap"
	reagent_state = LIQUID
	color = "#3A2A22"

/datum/reagent/lacquer/touch_mob(mob/living/M, amount)
	if (ishuman(M) && amount >= 1)
		to_chat(M, SPAN_WARNING("Your skin itches and burns where the lacquer touched it."))

/datum/reagent/spirit_varnish
	name = "Spirit varnish"
	id = "spirit_varnish"
	description = "Resin dissolved in strong spirit. Brushed on thin, it dries quickly to a clear, glossy coat."
	taste_description = "pine and alcohol"
	reagent_state = LIQUID
	color = "#D8A24A"

/datum/chemical_reaction/spirit_varnish
	name = "Spirit varnish"
	id = "spirit_varnish"
	result = "spirit_varnish"
	required_reagents = list("resin" = 2, "ethanol" = 1)
	result_amount = 3

// The tree.

/obj/structure/wild/tree/live_tree/var/tmp/lacquer_tapped_at = null // world.time of the last tap

/obj/structure/wild/tree/live_tree/proc/lacquer_tree()
	return mulberry_tree() // silk.dm: the broadleaf trees of the silk lands

/obj/structure/wild/tree/live_tree/proc/lacquer_bled_out()
	return !isnull(lacquer_tapped_at) && world.time < lacquer_tapped_at + LACQUER_TAP_WAIT

// The waits, as procs so a test fixture can stand in for do_after.
/obj/structure/wild/tree/live_tree/proc/lacquer_tap_wait(mob/living/human/H)
	return do_after(H, LACQUER_TAP_TIME, src)

/obj/item/proc/finish_wait(mob/living/human/H, obj/item/target)
	return do_after(H, FINISH_TIME, target)

// An open container used on a tree (wild.dm). TRUE when it was handled.
/proc/lacquer_tap_attackby(obj/structure/wild/tree/T, obj/item/W, mob/living/human/H)
	if (!istype(T, /obj/structure/wild/tree/live_tree) || !istype(W, /obj/item/weapon/reagent_containers) || !ishuman(H) || H.a_intent == I_HARM)
		return FALSE
	var/obj/structure/wild/tree/live_tree/L = T
	if (!L.lacquer_tree())
		return FALSE
	var/obj/item/weapon/reagent_containers/RG = W
	if (!RG.is_open_container() || !RG.reagents)
		to_chat(H, SPAN_WARNING("Open \the [RG] first."))
		return TRUE
	if (!is_tool(H.get_inactive_hand(), TOOL_KNIFE))
		to_chat(H, SPAN_WARNING("Hold a knife in your other hand to cut the bark."))
		return TRUE
	if (RG.reagents.get_free_space() < LACQUER_TAP_AMOUNT)
		to_chat(H, SPAN_WARNING("\The [RG] needs room for [LACQUER_TAP_AMOUNT] units of lacquer."))
		return TRUE
	if (L.lacquer_bled_out())
		to_chat(H, SPAN_NOTICE("The cuts on \the [L] have stopped weeping for now. Try another tree, or come back later."))
		return TRUE
	H.visible_message(SPAN_NOTICE("[H] cuts a line in the bark of \the [L] and holds \the [RG] under it."), SPAN_NOTICE("You cut a line in the bark of \the [L] and hold \the [RG] under it."))
	if (!L.lacquer_tap_wait(H) || QDELETED(L) || !L.lacquer_tree() || RG.loc != H || !RG.reagents || !RG.is_open_container())
		return TRUE
	if (!is_tool(H.get_inactive_hand(), TOOL_KNIFE) || RG.reagents.get_free_space() < LACQUER_TAP_AMOUNT || L.lacquer_bled_out())
		return TRUE
	L.lacquer_tapped_at = world.time
	RG.reagents.add_reagent("lacquer", LACQUER_TAP_AMOUNT)
	to_chat(H, SPAN_NOTICE("Grey lacquer sap beads along the cut and drips into \the [RG]."))
	return TRUE

// The finish.

// Why I cannot take a finish, or null when it can.
/proc/finish_refusal(obj/item/I)
	if (!istype(I) || istype(I, /obj/item/stack) || istype(I, /obj/item/weapon/reagent_containers) || I.abstract)
		return "That cannot be finished."
	if (istype(I, /obj/item/weapon/shield))
		var/obj/item/weapon/shield/S = I
		if (S.material == "wood")
			return null
		return "Only a wooden shield takes a finish."
	if (istype(I, /obj/item/clothing))
		var/path = lowertext("[I.type]")
		if (findtext(path, "leather") || findtext(path, "lamellar"))
			return null
		return "Only leather and lamellar take a finish."
	var/material/M = I.get_material()
	if (istype(M, /material/wood) && M.name != "straw")
		return null
	if (istype(M, /material/bamboo) || istype(M, /material/leather))
		return null
	return "\The [I] is not wood or leather."

/obj/item/proc/apply_finish(id)
	var/list/data = item_finishes[id]
	if (!data)
		return FALSE
	finish = id
	finish_left = data[2]
	return TRUE

// Health a worn finished item actually loses out of amount (item_wear.dm).
/obj/item/proc/finish_wear(amount)
	if (!finish || finish_left <= 0 || amount <= 0)
		return amount
	amount *= FINISH_WEAR_MULTIPLIER
	finish_left -= amount
	if (finish_left <= 0)
		finish = null
		finish_left = 0
	return amount

/obj/item/examine(mob/user, var/distance = -1)
	. = ..()
	if (finish && item_finishes[finish])
		to_chat(user, SPAN_NOTICE(item_finishes[finish][3]))

// The pot: a small brush pot for lacquer or varnish.
/obj/item/weapon/reagent_containers/glass/finishing_pot
	name = "finishing pot"
	desc = "A small lidless pot with a brush in it. Fill it with lacquer or spirit varnish and brush a coat onto wood, leather or lamellar."
	icon = 'icons/obj/resin_works.dmi'
	icon_state = "varnish_pot"
	item_state = "bucket"
	w_class = ITEM_SIZE_SMALL
	amount_per_transfer_from_this = 5
	possible_transfer_amounts = list(5, 10, 30)
	volume = 30
	flammable = TRUE

/obj/item/weapon/reagent_containers/glass/finishing_pot/update_icon()
	overlays.Cut()
	var/lacquer = reagents ? reagents.get_reagent_amount("lacquer") : 0
	var/varnish = reagents ? reagents.get_reagent_amount("spirit_varnish") : 0
	icon_state = lacquer > varnish ? "lacquer_pot" : "varnish_pot"

/obj/item/weapon/reagent_containers/glass/finishing_pot/on_reagent_change()
	update_icon()

// The finish the pot can brush on now, or null.
/obj/item/weapon/reagent_containers/glass/finishing_pot/proc/pot_finish()
	if (!reagents)
		return null
	for (var/id in item_finishes)
		if (reagents.get_reagent_amount(id) >= FINISH_UNITS)
			return id
	return null

/obj/item/weapon/reagent_containers/glass/finishing_pot/resolve_attackby(atom/A, mob/user, icon_x, icon_y)
	if (istype(A, /obj/item) && ishuman(user) && user.a_intent == I_HELP && !finish_refusal(A))
		brush_finish(A, user)
		return TRUE
	return ..()

/obj/item/weapon/reagent_containers/glass/finishing_pot/proc/brush_finish(obj/item/I, mob/living/human/H)
	var/id = pot_finish()
	if (!id)
		to_chat(H, SPAN_WARNING("\The [src] needs [FINISH_UNITS] units of lacquer or spirit varnish."))
		return FALSE
	if (I.finish && I.finish_left >= item_finishes[I.finish][2] / 2)
		to_chat(H, SPAN_NOTICE("\The [I] still has a good coat of [item_finishes[I.finish][1]]."))
		return FALSE
	H.visible_message(SPAN_NOTICE("[H] brushes a coat of [item_finishes[id][1]] onto \the [I]."), SPAN_NOTICE("You brush a thin, even coat of [item_finishes[id][1]] onto \the [I]."))
	if (!finish_wait(H, I) || persistence_save_in_progress || QDELETED(I) || QDELETED(src) || loc != H || finish_refusal(I) || pot_finish() != id)
		return FALSE
	reagents.remove_reagent(id, FINISH_UNITS)
	I.apply_finish(id)
	to_chat(H, SPAN_NOTICE("The coat dries to a hard gloss on \the [I]."))
	return TRUE

#undef LACQUER_TAP_AMOUNT
#undef LACQUER_TAP_WAIT
#undef LACQUER_TAP_TIME
#undef FINISH_UNITS
#undef FINISH_TIME
#undef FINISH_WEAR_MULTIPLIER
