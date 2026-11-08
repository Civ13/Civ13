// Electroplating: a cable-powered bath of sulphuric acid with a metal sheet
// hung in it as the anode. A metal item lowered in comes out with a thin coat
// of that metal. Gold and silver raise its trade value, copper, tin and zinc make
// worn weapons, tools and shields lose less health, and every coat renames and
// tints the item. Unlocked by Electricity (Industrial Age).

#define PLATING_ACID_PER_COAT 5
#define PLATING_STEPS 5 // powered object-process steps (2 s each) per coat

// metal id = list(sheet type, adjective, tint, value bonus, wear multiplier).
// A value bonus stays below the value of the sheet the coat uses up.
var/global/list/plating_metals = list(
	"gold" = list(/obj/item/stack/material/gold, "gold-plated", "#e8c547", 30, 1),
	"silver" = list(/obj/item/stack/material/silver, "silver-plated", "#dfe3e8", 15, 1),
	"copper" = list(/obj/item/stack/material/copper, "copper-plated", "#d08a52", 0, 0.75),
	"tin" = list(/obj/item/stack/material/tin, "tin-plated", "#cfd3d8", 0, 0.5),
	"zinc" = list(/obj/item/stack/material/zinc, "galvanized", "#b8c2c8", 0, 0.5))

// Materials a material weapon may be made of to take a coat.
var/global/list/plating_base_materials = list("iron", "steel", "bronze", "brass", "copper", "tin", "zinc", "gold", "silver", "lead")

/obj/item/var/plating = null // metal id of the item's coat, if any

/proc/plating_metal_of_sheet(obj/item/I)
	if (!istype(I, /obj/item/stack/material))
		return null
	for (var/metal in plating_metals)
		if (I.type == plating_metals[metal][1])
			return metal
	return null

// Why I cannot take a coat, or null when it can.
/proc/plating_refusal(obj/item/I)
	if (!istype(I) || istype(I, /obj/item/stack) || I.abstract)
		return "That cannot be plated."
	if (I.plating)
		return "\The [I] is already plated."
	if (I.w_class > ITEM_SIZE_LARGE)
		return "\The [I] is too big for the bath."
	// Keep dyed clothing's colours; a coat's tint would replace them.
	if (istype(I, /obj/item/clothing) && I.color && lowertext(I.color) != "#ffffff")
		return "\The [I] is dyed; the coat would not take."
	// A material weapon is metal only when made of one; others go by CONDUCT.
	if (istype(I, /obj/item/weapon/material))
		var/obj/item/weapon/material/M = I
		if (M.material && (M.material.name in plating_base_materials))
			return null
	else if (I.flags & CONDUCT)
		return null
	return "\The [I] is not metal."

/obj/item/proc/apply_plating(metal)
	var/list/data = plating_metals[metal]
	if (!data || plating)
		return FALSE
	plating = metal
	name = "[data[2]] [name]"
	color = data[3]
	value += data[4]
	return TRUE

// Health a worn plated item actually loses out of amount.
/obj/item/proc/plating_wear(amount)
	if (!plating || !plating_metals[plating])
		return amount
	return amount * plating_metals[plating][5]

/obj/item/examine(mob/user, var/distance = -1)
	. = ..()
	if (plating && plating_metals[plating])
		var/list/data = plating_metals[plating]
		if (data[5] < 1)
			to_chat(user, SPAN_NOTICE("A thin coat of [plating] protects it from wear."))
		else
			to_chat(user, SPAN_NOTICE("A thin coat of [plating] makes it worth more."))

/obj/structure/plating_bath
	name = "electroplating bath"
	desc = "A cabled tank of sulphuric acid. Hang a sheet of gold, silver, copper or tin in it, then lower a metal item in to coat it. Gold and silver add value; copper and tin resist wear."
	icon = 'icons/obj/chemical.dmi'
	icon_state = "centrifuge"
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE
	flags = NOREACT
	powerneeded = 3
	var/anode = null // metal id of the hung sheet
	var/tmp/progress = 0

/obj/structure/plating_bath/New()
	..()
	create_reagents(100)
	fluid_mark_dirty()

/obj/structure/plating_bath/Destroy()
	processing_objects -= src
	plating_release_power()
	fluid_mark_dirty()
	return ..()

/obj/structure/plating_bath/persistence_runtime_var(key)
	if (key == "powered" || key == "progress")
		return TRUE
	return ..()

// A coat in progress starts over after a load.
/obj/structure/plating_bath/after_load()
	. = ..()
	powered = FALSE
	progress = 0
	if (workpiece())
		processing_objects |= src
	fluid_mark_dirty()
	update_icon()

/obj/structure/plating_bath/update_icon()
	if (workpiece())
		icon_state = powered ? "centrifuge_active" : "centrifuge_powered"
	else
		icon_state = "centrifuge"

/obj/structure/plating_bath/proc/workpiece()
	for (var/obj/item/I in contents)
		return I
	return null

/obj/structure/plating_bath/proc/acid()
	return reagents.get_reagent_amount("sacid")

/obj/structure/plating_bath/proc/plating_release_power()
	if (powersource)
		powersource.update_power(-powerneeded, 1, src)
	powered = FALSE

// Why the bath cannot start a coat on I right now, or null.
/obj/structure/plating_bath/proc/start_refusal(obj/item/I)
	if (workpiece())
		return "\The [src] is already plating something."
	var/reason = plating_refusal(I)
	if (reason)
		return reason
	if (!anode)
		return "Hang a sheet of gold, silver, copper or tin in \the [src] first."
	if (acid() < PLATING_ACID_PER_COAT)
		return "\The [src] needs at least [PLATING_ACID_PER_COAT] units of sulphuric acid."
	if (!anchored || !isturf(loc))
		return "\The [src] must be secured in place."
	return null

/obj/structure/plating_bath/proc/start_coat(obj/item/I)
	I.forceMove(src)
	progress = 0
	processing_objects |= src
	update_icon()

/obj/structure/plating_bath/proc/hang_anode(obj/item/stack/material/S)
	var/metal = plating_metal_of_sheet(S)
	if (!metal || anode || !S.use(1))
		return FALSE
	anode = metal
	return TRUE

/obj/structure/plating_bath/process()
	var/obj/item/I = workpiece()
	if (!I || !anchored || !isturf(loc))
		processing_objects -= src
		plating_release_power()
		update_icon()
		return PROCESS_KILL
	// Waits, unpowered, until acid and an anode are back.
	if (!anode || acid() < PLATING_ACID_PER_COAT)
		plating_release_power()
		update_icon()
		return
	var/was_powered = powered
	powered = draw_cable_power() ? TRUE : FALSE
	if (powered != was_powered)
		update_icon()
	if (!powered || ++progress < PLATING_STEPS)
		return
	finish_coat(I)
	return PROCESS_KILL

/obj/structure/plating_bath/proc/finish_coat(obj/item/I)
	reagents.remove_reagent("sacid", PLATING_ACID_PER_COAT)
	var/metal = anode
	anode = null
	progress = 0
	processing_objects -= src
	I.apply_plating(metal)
	I.forceMove(get_turf(src))
	plating_release_power()
	update_icon()
	visible_message(SPAN_NOTICE("\The [src] hums down and \the [I] comes out [metal]-plated."))

/obj/structure/plating_bath/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/stack/cable_coil))
		connect_cable(user, W)
		return
	if (istype(W, /obj/item/weapon/reagent_containers/glass))
		var/obj/item/weapon/reagent_containers/glass/B = W
		var/amount = min(B.amount_per_transfer_from_this, B.reagents.get_reagent_amount("sacid"), reagents.get_free_space())
		if (amount <= 0)
			to_chat(user, SPAN_WARNING("\The [src] takes only sulphuric acid, and has room for [round(reagents.get_free_space())] units."))
			return
		B.reagents.remove_reagent("sacid", amount)
		reagents.add_reagent("sacid", amount)
		to_chat(user, SPAN_NOTICE("You pour [amount] units of sulphuric acid into \the [src]."))
		return
	if (plating_metal_of_sheet(W))
		if (anode)
			to_chat(user, SPAN_WARNING("\The [src] already has a sheet of [anode] hung in it."))
			return
		if (hang_anode(W))
			to_chat(user, SPAN_NOTICE("You hang a sheet of [anode] in \the [src]."))
		return
	if (istype(W, /obj/item/weapon/wrench) || istype(W, /obj/item/weapon/hammer))
		return ..()
	var/reason = start_refusal(W)
	if (reason)
		to_chat(user, SPAN_WARNING(reason))
		return
	if (W.loc == user && !user.unEquip(W, FALSE, src))
		return
	start_coat(W)
	to_chat(user, SPAN_NOTICE("You lower \the [W] into \the [src]."))

// Take out the item being plated, or else the hung sheet.
/obj/structure/plating_bath/attack_hand(mob/user)
	var/obj/item/I = workpiece()
	if (I)
		progress = 0
		processing_objects -= src
		plating_release_power()
		I.forceMove(get_turf(src))
		user.put_in_hands(I)
		update_icon()
		to_chat(user, SPAN_NOTICE("You lift \the [I] out of \the [src] before it is coated."))
		return
	if (anode)
		var/sheet_type = plating_metals[anode][1]
		var/obj/item/stack/S = new sheet_type(get_turf(src))
		S.amount = 1
		S.update_icon()
		to_chat(user, SPAN_NOTICE("You take the sheet of [anode] out of \the [src]."))
		anode = null
		user.put_in_hands(S)
		return
	return ..()

/obj/structure/plating_bath/examine(mob/user, distance)
	..(user, distance)
	to_chat(user, SPAN_NOTICE("It holds [round(acid())] of [reagents.maximum_volume] units of sulphuric acid, enough for [round(acid() / PLATING_ACID_PER_COAT)] coats."))
	to_chat(user, SPAN_NOTICE(anode ? "A sheet of [anode] hangs in it." : "No sheet hangs in it."))
	var/obj/item/I = workpiece()
	if (I)
		to_chat(user, SPAN_NOTICE("\The [I] is in the bath, [round(100 * progress / PLATING_STEPS)]% coated[powered ? "" : ", waiting for power"]."))

// Pipes may top the bath up with sulphuric acid.
/obj/structure/plating_bath/fluid_demand_tier()
	return anchored ? FLUID_TIER_SINK : 0

/obj/structure/plating_bath/fluid_demand(id)
	return id == "sacid" ? reagents.get_free_space() : 0

/obj/structure/plating_bath/fluid_receive(id, amount, data)
	amount = min(amount, fluid_demand(id))
	if (amount <= 0)
		return 0
	return fluid_add_to(reagents, id, amount, data)

// Factory ports: arms hang sheets, lower items and take coated items out.
/obj/structure/plating_bath/factory_accepts(obj/item/I, from_dir = 0)
	if (plating_metal_of_sheet(I))
		return anode ? 0 : 1
	return start_refusal(I) ? 0 : 1

/obj/structure/plating_bath/factory_insert(obj/item/I, from_dir = 0)
	if (factory_accepts(I, from_dir) <= 0 || !factory_movable_item(I))
		return 0
	if (plating_metal_of_sheet(I))
		return hang_anode(I) ? 1 : 0
	start_coat(I)
	return 1

/obj/structure/plating_bath/factory_offer(to_dir = 0, filter_type = null)
	for (var/obj/item/I in get_turf(src))
		if (I.plating && factory_movable_item(I) && (!filter_type || istype(I, filter_type)))
			return I
	return null

/obj/structure/plating_bath/factory_take(obj/item/I, atom/destination)
	if (!destination || !factory_movable_item(I) || I.loc != get_turf(src) || !I.plating)
		return FALSE
	I.forceMove(destination)
	return I.loc == destination

#undef PLATING_ACID_PER_COAT
#undef PLATING_STEPS
