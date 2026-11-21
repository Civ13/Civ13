// Epoxy, fiberglass and aramid laminate (Val, 2026-11-21; plan "Resin materials
// plan", PR 8).
//
// From the Cold War the bakelizer (resin_laminate.dm) can be set to epoxy, a
// liquid drawn off with an empty container. Glass sheets woven at a loom
// (production.dm) make glass cloth. On a layup table, with LAYUP_RESIN units
// of epoxy poured in:
//   - LAYUP_CLOTH glass cloth lay up into 2 sheets of fiberglass,
//   - LAYUP_CLOTH Kevlar sheets bond into 2 sheets of aramid laminate.
// Fiberglass is its own material, not /material/composite (the aluminium and
// composites plan owns that).
//
// Sprites by Fable (icons/obj/resin_works.dmi, icons/obj/fabrics.dmi). Nothing
// here sleeps outside the do_after wait.

#define LAYUP_CLOTH 3
#define LAYUP_RESIN 10
#define LAYUP_SHEETS 2
#define LAYUP_TIME 80

/datum/reagent/epoxy
	name = "Epoxy"
	id = "epoxy"
	description = "Two-part epoxy resin, mixed and ready. It sets glass and Kevlar cloth into hard, light panels."
	taste_description = "plastic and solvent"
	reagent_state = LIQUID
	color = "#E6D9A8"

/material/glass_cloth
	name = "glass_cloth"
	display_name = "glass cloth"
	use_name = "glass cloth"
	icon_colour = "#E8EEF0"
	hardness = 15
	weight = 4
	sheet_singular_name = "sheet"
	sheet_plural_name = "sheets"
	stack_type = /obj/item/stack/material/glass_cloth
	door_icon_base = "wood"
	resilience = 0.0
	density = 8
	firmness = 10
	toughness = 50
	wear = 30
	heat_limit = 500
	corrosion = 0
	spring = 20
	shaping = SHAPE_SEWN

/material/fiberglass
	name = "fiberglass"
	display_name = "fiberglass"
	use_name = "fiberglass"
	icon_colour = "#D8E2C8"
	hardness = 40
	weight = 6
	sheet_singular_name = "sheet"
	sheet_plural_name = "sheets"
	stack_type = /obj/item/stack/material/fiberglass
	integrity = 110
	resilience = 0.6
	density = 12
	firmness = 55
	toughness = 60
	wear = 70
	heat_limit = 200
	corrosion = 0
	spring = 30
	shaping = SHAPE_MOULDED

/material/aramid_laminate
	name = "aramid_laminate"
	display_name = "aramid laminate"
	use_name = "aramid laminate"
	icon_colour = "#C8A84A"
	hardness = 55
	weight = 6
	sheet_singular_name = "sheet"
	sheet_plural_name = "sheets"
	stack_type = /obj/item/stack/material/aramid_laminate
	integrity = 160
	resilience = 0.8
	density = 12
	firmness = 65
	toughness = 90
	wear = 80
	heat_limit = 250
	corrosion = 0
	spring = 35
	shaping = SHAPE_MOULDED

/obj/item/stack/material/glass_cloth
	name = "glass cloth"
	desc = "Cloth woven from fine glass fibre. It itches, does not burn and wants resin to make it stiff."
	icon = 'icons/obj/fabrics.dmi'
	icon_state = "glass_cloth"
	default_type = "glass_cloth"
	apply_colour = FALSE
	value = 4
	w_class = ITEM_SIZE_SMALL

/obj/item/stack/material/glass_cloth/New()
	update_icon()
	return ..()

/obj/item/stack/material/glass_cloth/update_icon()
	icon_state = "glass_cloth[pile_suffix(amount, list(13, 26, 39))]"

/obj/item/stack/material/fiberglass
	name = "fiberglass"
	desc = "Pale, stiff panels of glass cloth set in epoxy. Light and tough; it does not rot or rust."
	icon = 'icons/obj/fabrics.dmi'
	icon_state = "fiberglass"
	default_type = "fiberglass"
	apply_colour = FALSE
	value = 8
	w_class = ITEM_SIZE_NORMAL

/obj/item/stack/material/fiberglass/New()
	update_icon()
	return ..()

/obj/item/stack/material/fiberglass/update_icon()
	icon_state = "fiberglass[pile_suffix(amount, list(13, 26, 39))]"

/obj/item/stack/material/aramid_laminate
	name = "aramid laminate"
	desc = "Yellow panels of Kevlar bonded in epoxy. Stiff, light and very hard to cut through."
	icon = 'icons/obj/fabrics.dmi'
	icon_state = "aramid_laminate"
	default_type = "aramid_laminate"
	apply_colour = FALSE
	value = 20
	w_class = ITEM_SIZE_NORMAL

/obj/item/stack/material/aramid_laminate/New()
	update_icon()
	return ..()

/obj/item/stack/material/aramid_laminate/update_icon()
	icon_state = "aramid_laminate[pile_suffix(amount, list(13, 26, 39))]"

// What LAYUP_CLOTH sheets of this stack lay up into, or null.
/proc/layup_product(obj/item/stack/material/S)
	if (istype(S, /obj/item/stack/material/glass_cloth))
		return /obj/item/stack/material/fiberglass
	if (istype(S, /obj/item/stack/material/kevlar))
		return /obj/item/stack/material/aramid_laminate
	return null

/obj/structure/layup_table
	name = "layup table"
	desc = "A flat steel table with rollers and resin pans. Pour epoxy in, then lay three sheets of glass cloth or Kevlar on it to set fiberglass or aramid laminate."
	icon = 'icons/obj/resin_works.dmi'
	icon_state = "layup_table"
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE

/obj/structure/layup_table/New()
	..()
	create_reagents(60)

// The wait, as a proc so a test fixture can stand in for do_after.
/obj/structure/layup_table/proc/layup_wait(mob/living/human/H)
	return do_after(H, LAYUP_TIME, src)

/obj/structure/layup_table/attackby(obj/item/W, mob/user)
	if (!ishuman(user) || user.a_intent == I_HARM)
		return ..()
	var/mob/living/human/H = user
	if (istype(W, /obj/item/weapon/reagent_containers) && W.reagents && W.reagents.has_reagent("epoxy"))
		var/units = min(W.reagents.get_reagent_amount("epoxy"), reagents.get_free_space())
		if (units <= 0)
			to_chat(H, SPAN_WARNING("\The [src]'s resin pans are full."))
			return TRUE
		W.reagents.remove_reagent("epoxy", units)
		reagents.add_reagent("epoxy", units)
		to_chat(H, SPAN_NOTICE("You pour [units] units of epoxy into \the [src]'s pans."))
		return TRUE
	if (istype(W, /obj/item/stack/material) && layup_product(W))
		lay_up(W, H)
		return TRUE
	return ..()

/obj/structure/layup_table/proc/lay_up(obj/item/stack/material/S, mob/living/human/H)
	var/path = layup_product(S)
	if (!path)
		return FALSE
	if (reagents.get_reagent_amount("epoxy") < LAYUP_RESIN)
		to_chat(H, SPAN_WARNING("\The [src] needs [LAYUP_RESIN] units of epoxy first."))
		return FALSE
	if (S.amount < LAYUP_CLOTH)
		to_chat(H, SPAN_WARNING("You need [LAYUP_CLOTH] sheets of \the [S] for one layup."))
		return FALSE
	H.visible_message(SPAN_NOTICE("[H] lays [S.name] on \the [src] and rolls epoxy through it."), SPAN_NOTICE("You lay the [S.name] down in layers and roll epoxy through each one."))
	icon_state = "layup_table_on"
	var/done = layup_wait(H)
	icon_state = initial(icon_state)
	if (!done || persistence_save_in_progress || QDELETED(src) || QDELETED(S) || S.amount < LAYUP_CLOTH || reagents.get_reagent_amount("epoxy") < LAYUP_RESIN || layup_product(S) != path)
		return FALSE
	if (!S.use(LAYUP_CLOTH))
		return FALSE
	reagents.remove_reagent("epoxy", LAYUP_RESIN)
	var/obj/item/stack/material/P = new path(get_turf(src), LAYUP_SHEETS)
	H.put_in_hands(P)
	to_chat(H, SPAN_NOTICE("The epoxy cures: [LAYUP_SHEETS] sheets of [P.name]."))
	return TRUE

/obj/structure/layup_table/examine(mob/user, distance = -1)
	. = ..()
	var/epoxy = reagents.get_reagent_amount("epoxy")
	if (epoxy)
		to_chat(user, SPAN_NOTICE("Its pans hold [epoxy] units of epoxy."))

#undef LAYUP_CLOTH
#undef LAYUP_RESIN
#undef LAYUP_SHEETS
#undef LAYUP_TIME
