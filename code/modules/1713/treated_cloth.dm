// Treated cloth (Val, 2026-11-21; plan "Resin materials plan", PR 3).
//
// Plain cloth soaked in a coating keeps out rain and spray:
//   - pitch from the tar kiln (castle_pour.dm) makes tarred canvas,
//   - linseed, olive, sunflower or corn oil makes oilcloth,
//   - a cake of beeswax (wild_bees.dm) rubbed in makes waxed cloth,
//   - latex (rubber_tapping.dm) cured with sulphur makes rubberised cloth (PR 5).
//
// Use an open container on a stack of cloth: each sheet soaks up
// CLOTH_COAT_UNITS of the coating, up to CLOTH_COAT_BATCH sheets at a time. Use
// a cake of beeswax on cloth (or cloth on the cake) to wax up to CLOTH_WAX_BATCH
// sheets; the cake is used up. For rubberised cloth hold sulphur in the other
// hand while working the latex in: one lump of sulphur cures a whole batch.
// Harm intent hits as before.
//
// Clothing sewn from a coated cloth keeps out more rain (rain_gear.dm): the
// crafting hook in stack.dm raises its rain_resist to the cloth's.
//
// Sprites by Fable (icons/obj/fabrics.dmi). The cloth hook is in the base
// /obj/item/stack/material/attackby (material_sheets.dm) and the wax hook in the
// beeswax attackby. Nothing here sleeps outside the do_after waits.

#define CLOTH_COAT_UNITS 5
#define CLOTH_COAT_BATCH 5
#define CLOTH_WAX_BATCH 3
#define CLOTH_COAT_TIME 40

// stack type = rain_resist of clothing sewn from it
var/global/list/coated_cloth_rain_resist = list(
	/obj/item/stack/material/tarred_canvas = 75,
	/obj/item/stack/material/oilcloth = 75,
	/obj/item/stack/material/waxed_cloth = 70,
	/obj/item/stack/material/rubberised_cloth = 90)

/material/tarred_canvas
	name = "tarred_canvas"
	display_name = "tarred canvas"
	use_name = "tarred canvas"
	icon_colour = "#3B3025"
	hardness = 14
	weight = 8
	sheet_singular_name = "sheet"
	sheet_plural_name = "sheets"
	stack_type = /obj/item/stack/material/tarred_canvas
	door_icon_base = "wood"
	flags = MATERIAL_PADDING
	resilience = 0.0
	density = 9
	firmness = 10
	toughness = 45
	wear = 35
	heat_limit = 90
	corrosion = 0
	spring = 15
	shaping = SHAPE_SEWN

/material/oilcloth
	name = "oilcloth"
	display_name = "oilcloth"
	use_name = "oilcloth"
	icon_colour = "#C9B27A"
	hardness = 11
	weight = 5
	sheet_singular_name = "sheet"
	sheet_plural_name = "sheets"
	stack_type = /obj/item/stack/material/oilcloth
	door_icon_base = "wood"
	flags = MATERIAL_PADDING
	resilience = 0.0
	density = 6
	firmness = 6
	toughness = 35
	wear = 25
	heat_limit = 120
	corrosion = 0
	spring = 25
	shaping = SHAPE_SEWN

/material/waxed_cloth
	name = "waxed_cloth"
	display_name = "waxed cloth"
	use_name = "waxed cloth"
	icon_colour = "#8A7B4E"
	hardness = 12
	weight = 5
	sheet_singular_name = "sheet"
	sheet_plural_name = "sheets"
	stack_type = /obj/item/stack/material/waxed_cloth
	door_icon_base = "wood"
	flags = MATERIAL_PADDING
	resilience = 0.0
	density = 6
	firmness = 7
	toughness = 40
	wear = 30
	heat_limit = 60
	corrosion = 0
	spring = 25
	shaping = SHAPE_SEWN

/material/rubberised_cloth
	name = "rubberised_cloth"
	display_name = "rubberised cloth"
	use_name = "rubberised cloth"
	icon_colour = "#2E2E2A"
	hardness = 14
	weight = 6
	sheet_singular_name = "sheet"
	sheet_plural_name = "sheets"
	stack_type = /obj/item/stack/material/rubberised_cloth
	door_icon_base = "wood"
	flags = MATERIAL_PADDING
	resilience = 0.0
	density = 8
	firmness = 8
	toughness = 50
	wear = 40
	heat_limit = 110
	corrosion = 0
	spring = 45
	shaping = SHAPE_SEWN

/obj/item/stack/material/tarred_canvas
	name = "tarred canvas"
	desc = "Heavy cloth soaked black with pitch. It smells of the kiln and sheds water like a hull."
	icon = 'icons/obj/fabrics.dmi'
	icon_state = "tarred_canvas"
	default_type = "tarred_canvas"
	apply_colour = FALSE
	value = 4
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE

/obj/item/stack/material/tarred_canvas/New()
	update_icon()
	return ..()

/obj/item/stack/material/tarred_canvas/update_icon()
	icon_state = "tarred_canvas[pile_suffix(amount, list(13, 26, 39))]"

/obj/item/stack/material/oilcloth
	name = "oilcloth"
	desc = "Cloth worked with drying oil until it turned stiff and yellow. Rain runs straight off it."
	icon = 'icons/obj/fabrics.dmi'
	icon_state = "oilcloth"
	default_type = "oilcloth"
	apply_colour = FALSE
	value = 4
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE

/obj/item/stack/material/oilcloth/New()
	update_icon()
	return ..()

/obj/item/stack/material/oilcloth/update_icon()
	icon_state = "oilcloth[pile_suffix(amount, list(13, 26, 39))]"

/obj/item/stack/material/waxed_cloth
	name = "waxed cloth"
	desc = "Cloth rubbed through with beeswax. It is supple, smells faintly of honey and keeps out the wet."
	icon = 'icons/obj/fabrics.dmi'
	icon_state = "waxed_cloth"
	default_type = "waxed_cloth"
	apply_colour = FALSE
	value = 4
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE

/obj/item/stack/material/waxed_cloth/New()
	update_icon()
	return ..()

/obj/item/stack/material/waxed_cloth/update_icon()
	icon_state = "waxed_cloth[pile_suffix(amount, list(13, 26, 39))]"

/obj/item/sail/tarred
	name = "small tarred sail"
	desc = "A small sail of tarred canvas rolled on its spars. It shrugs off spray and rot. Used on an outrigger canoe, it steps a mast."

/obj/item/stack/material/rubberised_cloth
	name = "rubberised cloth"
	desc = "Cloth soaked through with latex and cured with sulphur. It is airtight and waterproof."
	icon = 'icons/obj/fabrics.dmi'
	icon_state = "rubberised_cloth"
	default_type = "rubberised_cloth"
	apply_colour = FALSE
	value = 6
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE

/obj/item/stack/material/rubberised_cloth/New()
	update_icon()
	return ..()

/obj/item/stack/material/rubberised_cloth/update_icon()
	icon_state = "rubberised_cloth[pile_suffix(amount, list(13, 26, 39))]"

// Clothing crafted from a coated cloth (stack.dm) sheds more rain.
/proc/coated_cloth_crafted(obj/item/stack/S, atom/O)
	if (!istype(S) || !istype(O, /obj/item/clothing))
		return FALSE
	var/resist = coated_cloth_rain_resist[S.type]
	if (!resist)
		return FALSE
	var/obj/item/clothing/C = O
	if (C.rain_resist >= resist)
		return FALSE
	C.rain_resist = resist
	return TRUE

// The wait, as a proc so a test fixture can stand in for do_after.
/obj/item/stack/material/proc/cloth_treat_wait(mob/living/human/H)
	return do_after(H, CLOTH_COAT_TIME, src)

/proc/treatable_cloth(obj/item/stack/material/C)
	return istype(C, /obj/item/stack/material/cloth) && C.material && C.material.name == "cloth" && C.amount > 0

// The coating in a container and the cloth it makes, or null.
/proc/cloth_coating(datum/reagents/R)
	if (!R)
		return null
	for (var/id in list("pitch", "linseed_oil", "olive_oil", "sunflower_oil", "cornoil"))
		if (R.get_reagent_amount(id) >= CLOTH_COAT_UNITS)
			return id
	return null

/proc/cloth_coating_product(id)
	return id == "pitch" ? /obj/item/stack/material/tarred_canvas : /obj/item/stack/material/oilcloth

/proc/cloth_give(mob/living/human/H, path, amount)
	var/obj/item/stack/material/S = new path(get_turf(H), amount)
	H.put_in_hands(S)
	return S

// Something used on a stack of cloth (material_sheets.dm). TRUE when handled.
/proc/cloth_treat_attackby(obj/item/stack/material/C, obj/item/W, mob/living/human/H)
	if (!treatable_cloth(C) || !ishuman(H) || H.a_intent == I_HARM)
		return FALSE
	if (istype(W, /obj/item/weapon/beeswax))
		cloth_wax(C, W, H)
		return TRUE
	if (!istype(W, /obj/item/weapon/reagent_containers) || !W.reagents || !W.reagents.total_volume)
		return FALSE
	var/obj/item/weapon/reagent_containers/RG = W
	if (RG.reagents.get_reagent_amount("latex") >= CLOTH_COAT_UNITS)
		cloth_rubberise(C, RG, H)
		return TRUE
	var/id = cloth_coating(RG.reagents)
	if (!id)
		return FALSE
	if (!RG.is_open_container())
		to_chat(H, SPAN_WARNING("Open \the [RG] first."))
		return TRUE
	H.visible_message(SPAN_NOTICE("[H] works [id == "pitch" ? "pitch" : "oil"] into \the [C]."), SPAN_NOTICE("You pour a little from \the [RG] and work it into \the [C]."))
	if (!C.cloth_treat_wait(H) || persistence_save_in_progress || QDELETED(C) || QDELETED(RG) || RG.loc != H || !RG.reagents || !treatable_cloth(C))
		return TRUE
	var/sheets = min(CLOTH_COAT_BATCH, C.amount, round(RG.reagents.get_reagent_amount(id) / CLOTH_COAT_UNITS))
	if (sheets < 1)
		return TRUE
	var/path = cloth_coating_product(id)
	RG.reagents.remove_reagent(id, sheets * CLOTH_COAT_UNITS)
	C.use(sheets)
	cloth_give(H, path, sheets)
	if (path == /obj/item/stack/material/tarred_canvas)
		to_chat(H, SPAN_NOTICE("The pitch soaks in and sets. You have [sheets] sheet\s of tarred canvas."))
	else
		to_chat(H, SPAN_NOTICE("The oil soaks in and dries stiff. You have [sheets] sheet\s of oilcloth."))
	return TRUE

// Work latex into cloth and cure it with sulphur held in the other hand.
/proc/cloth_rubberise(obj/item/stack/material/C, obj/item/weapon/reagent_containers/RG, mob/living/human/H)
	if (!RG.is_open_container())
		to_chat(H, SPAN_WARNING("Open \the [RG] first."))
		return FALSE
	var/obj/item/stack/ore/sulphur/S = H.get_inactive_hand()
	if (!istype(S) || S.amount < 1)
		to_chat(H, SPAN_WARNING("Hold sulphur in your other hand to cure the latex."))
		return FALSE
	H.visible_message(SPAN_NOTICE("[H] works latex and crushed sulphur into \the [C]."), SPAN_NOTICE("You work latex and crushed sulphur into \the [C] and let it cure."))
	if (!C.cloth_treat_wait(H) || persistence_save_in_progress || QDELETED(C) || QDELETED(RG) || RG.loc != H || !RG.reagents || !treatable_cloth(C) || H.get_inactive_hand() != S || QDELETED(S))
		return FALSE
	var/sheets = min(CLOTH_COAT_BATCH, C.amount, round(RG.reagents.get_reagent_amount("latex") / CLOTH_COAT_UNITS))
	if (sheets < 1 || !S.use(1))
		return FALSE
	RG.reagents.remove_reagent("latex", sheets * CLOTH_COAT_UNITS)
	C.use(sheets)
	cloth_give(H, /obj/item/stack/material/rubberised_cloth, sheets)
	to_chat(H, SPAN_NOTICE("The latex cures into a smooth, airtight skin. You have [sheets] sheet\s of rubberised cloth."))
	return TRUE

// Rub a cake of beeswax into cloth. Called from both sides.
/proc/cloth_wax(obj/item/stack/material/C, obj/item/weapon/beeswax/B, mob/living/human/H)
	if (!treatable_cloth(C) || !istype(B) || !ishuman(H))
		return FALSE
	H.visible_message(SPAN_NOTICE("[H] rubs \the [B] into \the [C]."), SPAN_NOTICE("You warm \the [B] in your hands and rub it into \the [C]."))
	if (!C.cloth_treat_wait(H) || persistence_save_in_progress || QDELETED(C) || QDELETED(B) || !treatable_cloth(C))
		return TRUE
	var/sheets = min(CLOTH_WAX_BATCH, C.amount)
	var/mob/M = B.loc
	if (istype(M))
		M.drop_from_inventory(B)
	qdel(B)
	C.use(sheets)
	cloth_give(H, /obj/item/stack/material/waxed_cloth, sheets)
	to_chat(H, SPAN_NOTICE("The wax is all worked in. You have [sheets] sheet\s of waxed cloth."))
	return TRUE

#undef CLOTH_COAT_UNITS
#undef CLOTH_COAT_BATCH
#undef CLOTH_WAX_BATCH
#undef CLOTH_COAT_TIME
