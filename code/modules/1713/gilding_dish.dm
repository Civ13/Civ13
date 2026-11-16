// Gilding dish: the Bronze Age use for an early chemical cell. A copper-lined
// clay dish of grape juice with a gold or silver sheet hung in it. Set it next
// to a charged cell (a jar cell, pile or accumulator) and lower a small metal
// item in: the cell's stored energy puts a thin gold or silver coat on it. No
// cable is needed, so it works long before Electricity. The coat is the same
// one the electroplating bath gives (electroplating.dm). Unlocked by Early
// Chemical Cells.

#define GILDING_JUICE_PER_COAT 5
#define GILDING_ENERGY_PER_COAT 50 // PU s; a full jar cell gives 12 coats
#define GILDING_STEPS 10 // object-process steps (2 s each) per coat

// Only the precious metals: a weak cell gives a thin coat, good for looks and
// value, too thin to stop wear.
var/global/list/gilding_metals = list("gold", "silver")

/obj/structure/gilding_dish
	name = "gilding dish"
	desc = "A shallow copper-lined clay dish for grape juice. Hang a sheet of gold or silver in it, set a charged jar cell beside it, then lower a small metal item in to gild it."
	icon = 'icons/obj/gilding_dish.dmi' // tests/sprites/create_gilding_dish.py
	icon_state = "dish"
	anchored = TRUE
	density = FALSE
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE
	flags = NOREACT
	var/anode = null // "gold" or "silver"
	var/tmp/progress = 0

/obj/structure/gilding_dish/New()
	..()
	create_reagents(30)
	update_icon()

/obj/structure/gilding_dish/Destroy()
	processing_objects -= src
	return ..()

/obj/structure/gilding_dish/persistence_runtime_var(key)
	if (key == "progress")
		return TRUE
	return ..()

// A coat in progress starts over after a load.
/obj/structure/gilding_dish/after_load()
	. = ..()
	progress = 0
	if (workpiece())
		processing_objects |= src
	update_icon()

// The dry or filled dish, the hung sheet, and an item in it: bubbling while
// the coat goes on, still while it waits for a charged cell.
/obj/structure/gilding_dish/update_icon()
	var/state = "dish"
	if (workpiece() && anode)
		state = "dish_[anode]_[can_coat() ? "on" : "wait"]"
	else
		if (juice() >= 1)
			state += "_juice"
		if (anode)
			state += "_[anode]"
	if (icon_state != state)
		icon_state = state

// Everything a coat in progress needs is in place.
/obj/structure/gilding_dish/proc/can_coat()
	return anode && anchored && isturf(loc) && juice() >= GILDING_JUICE_PER_COAT && power_cell()

/obj/structure/gilding_dish/proc/workpiece()
	for (var/obj/item/I in contents)
		return I
	return null

/obj/structure/gilding_dish/proc/juice()
	return reagents.get_reagent_amount("grapejuice")

// A charged cell on a neighbouring tile (or this one), fullest first.
/obj/structure/gilding_dish/proc/power_cell()
	var/obj/structure/battery/best = null
	for (var/obj/structure/battery/B in range(1, src))
		if (B.retired || !isturf(B.loc) || !B.commissioned || B.stored_energy < GILDING_ENERGY_PER_COAT)
			continue
		if (!best || B.stored_energy > best.stored_energy)
			best = B
	return best

// Why the dish cannot start a coat on I right now, or null.
/obj/structure/gilding_dish/proc/start_refusal(obj/item/I)
	if (workpiece())
		return "\The [src] is already gilding something."
	var/reason = plating_refusal(I)
	if (reason)
		return reason
	if (I.w_class > ITEM_SIZE_SMALL)
		return "\The [I] is too big for \the [src]."
	if (!anode)
		return "Hang a sheet of gold or silver in \the [src] first."
	if (juice() < GILDING_JUICE_PER_COAT)
		return "\The [src] needs at least [GILDING_JUICE_PER_COAT] units of grape juice."
	if (!anchored || !isturf(loc))
		return "\The [src] must be set down and secured."
	if (!power_cell())
		return "\The [src] needs a charged cell beside it."
	return null

/obj/structure/gilding_dish/proc/start_coat(obj/item/I)
	I.forceMove(src)
	progress = 0
	processing_objects |= src
	update_icon()

/obj/structure/gilding_dish/proc/hang_anode(obj/item/stack/material/S)
	var/metal = plating_metal_of_sheet(S)
	if (!(metal in gilding_metals) || anode || !S.use(1))
		return FALSE
	anode = metal
	update_icon()
	return TRUE

/obj/structure/gilding_dish/process()
	var/obj/item/I = workpiece()
	if (!I || !anchored || !isturf(loc))
		processing_objects -= src
		update_icon()
		return PROCESS_KILL
	update_icon()
	// Waits until juice, an anode and a charged cell are back.
	if (!can_coat())
		return
	if (++progress < GILDING_STEPS)
		return
	return finish_coat(I) ? PROCESS_KILL : null

/obj/structure/gilding_dish/proc/finish_coat(obj/item/I)
	var/obj/structure/battery/B = power_cell()
	if (!B)
		return FALSE
	B.stored_energy -= GILDING_ENERGY_PER_COAT
	reagents.remove_reagent("grapejuice", GILDING_JUICE_PER_COAT)
	var/metal = anode
	anode = null
	progress = 0
	processing_objects -= src
	I.apply_plating(metal)
	I.forceMove(get_turf(src))
	update_icon()
	visible_message(SPAN_NOTICE("\The [I] comes out of \the [src] with a thin [metal] coat."))
	return TRUE

/obj/structure/gilding_dish/attackby(obj/item/W, mob/user)
	if ((istype(W, /obj/item/weapon/reagent_containers/glass) || istype(W, /obj/item/weapon/reagent_containers/food/drinks)) && W.reagents)
		var/obj/item/weapon/reagent_containers/C = W
		var/amount = min(C.amount_per_transfer_from_this, C.reagents.get_reagent_amount("grapejuice"), reagents.get_free_space())
		if (amount <= 0)
			to_chat(user, SPAN_WARNING("\The [src] takes only grape juice, and has room for [round(reagents.get_free_space())] units."))
			return
		C.reagents.remove_reagent("grapejuice", amount)
		reagents.add_reagent("grapejuice", amount)
		update_icon()
		to_chat(user, SPAN_NOTICE("You pour [amount] units of grape juice into \the [src]."))
		return
	var/metal = plating_metal_of_sheet(W)
	if (metal)
		if (!(metal in gilding_metals))
			to_chat(user, SPAN_WARNING("A cell this weak can only lay down gold or silver."))
			return
		if (anode)
			to_chat(user, SPAN_WARNING("\The [src] already has a sheet of [anode] hung in it."))
			return
		if (hang_anode(W))
			to_chat(user, SPAN_NOTICE("You hang a sheet of [anode] in \the [src]."))
		return
	if (is_tool(W, TOOL_WRENCH) || is_tool(W, TOOL_HAMMER))
		return ..()
	var/reason = start_refusal(W)
	if (reason)
		to_chat(user, SPAN_WARNING(reason))
		return
	if (W.loc == user && !user.unEquip(W, FALSE, src))
		return
	start_coat(W)
	to_chat(user, SPAN_NOTICE("You lower \the [W] into \the [src]."))

// Take out the item being gilded, or else the hung sheet.
/obj/structure/gilding_dish/attack_hand(mob/user)
	var/obj/item/I = workpiece()
	if (I)
		progress = 0
		processing_objects -= src
		I.forceMove(get_turf(src))
		update_icon()
		user.put_in_hands(I)
		to_chat(user, SPAN_NOTICE("You lift \the [I] out of \the [src] before it is coated."))
		return
	if (anode)
		var/sheet_type = plating_metals[anode][1]
		var/obj/item/stack/S = new sheet_type(get_turf(src))
		S.amount = 1
		S.update_icon()
		to_chat(user, SPAN_NOTICE("You take the sheet of [anode] out of \the [src]."))
		anode = null
		update_icon()
		user.put_in_hands(S)
		return
	return ..()

/obj/structure/gilding_dish/examine(mob/user, distance)
	..(user, distance)
	to_chat(user, SPAN_NOTICE("It holds [round(juice())] of [reagents.maximum_volume] units of grape juice, enough for [round(juice() / GILDING_JUICE_PER_COAT)] coats."))
	to_chat(user, SPAN_NOTICE(anode ? "A sheet of [anode] hangs in it." : "No sheet hangs in it."))
	var/obj/structure/battery/B = power_cell()
	to_chat(user, SPAN_NOTICE(B ? "\The [B] beside it has charge for [round(B.stored_energy / GILDING_ENERGY_PER_COAT)] more coats." : "No charged cell sits beside it."))
	var/obj/item/I = workpiece()
	if (I)
		to_chat(user, SPAN_NOTICE("\The [I] is in the dish, [round(100 * progress / GILDING_STEPS)]% coated[B ? "" : ", waiting for a charged cell"]."))

#undef GILDING_JUICE_PER_COAT
#undef GILDING_ENERGY_PER_COAT
#undef GILDING_STEPS
