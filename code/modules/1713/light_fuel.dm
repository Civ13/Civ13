// Fuel and refuelling for portable lights.
// Burning lights (torches, lanterns, tiki torches) take oil or fat, lighters
// take gasoline or alcohol, and electric lights (flashlights, smartphone
// torches) take batteries. Map fixtures marked unlimited keep burning.

#define TORCH_NEW_FUEL 600 // seconds of light a new torch is soaked for: one whole piece of animal fat

/////////////
// BATTERY //
/////////////

/obj/item/weapon/battery
	name = "battery"
	desc = "A dry-cell battery for flashlights and other small electric lights. Use it on a light to charge it."
	icon = 'icons/obj/machines/power.dmi'
	icon_state = "scell"
	item_state = "cell"
	w_class = ITEM_SIZE_TINY
	slot_flags = SLOT_BELT | SLOT_POCKET
	value = 4
	flammable = FALSE
	var/charge = 3600 // seconds of light
	var/max_charge = 3600

/obj/item/weapon/battery/examine(mob/user)
	..()
	if (charge <= 0)
		to_chat(user, "It is dead.")
	else
		to_chat(user, "It has about [round(100 * charge / max(1, max_charge))]% charge left.")

/obj/item/weapon/battery/proc/update_name()
	name = charge > 0 ? initial(name) : "dead [initial(name)]"

// Moves up to room seconds of charge out of the battery and returns what moved.
/obj/item/weapon/battery/proc/draw_charge(room)
	if (room <= 0 || charge <= 0)
		return 0
	var/taken = min(charge, room)
	charge -= taken
	update_name()
	return taken

// Moves up to room seconds of light out of the first accepted reagent in C.
// accepted is reagent id = seconds per unit. Returns list(seconds, reagent name),
// or null when C holds nothing the light can burn.
/proc/light_fuel_from_container(obj/item/weapon/reagent_containers/C, list/accepted, room)
	if (!istype(C) || !C.reagents || !accepted || room <= 0)
		return null
	for (var/datum/reagent/R in C.reagents.reagent_list)
		var/per_unit = accepted[R.id]
		if (!per_unit || R.volume <= 0)
			continue
		var/units = min(R.volume, room / per_unit)
		if (units <= 0)
			continue
		var/reagent_name = R.name
		C.reagents.remove_reagent(R.id, units, exact = TRUE)
		light_fuel_fat_used(C)
		return list(round(units * per_unit), reagent_name)
	return null

// A piece of animal fat is burnt as the lard in it, so a light takes only what
// it has room for and the rest of the piece is kept. A used-up piece is gone.
/proc/light_fuel_fat_used(obj/item/weapon/reagent_containers/food/snacks/animalfat/F)
	if (!istype(F) || QDELETED(F))
		return
	if (F.reagents && F.reagents.get_reagent_amount("lard") >= 0.1)
		return
	if (ismob(F.loc))
		var/mob/M = F.loc
		M.drop_from_inventory(F)
	qdel(F)

/obj/item/weapon/reagent_containers/food/snacks/animalfat/examine(mob/user)
	..()
	var/left = reagents ? reagents.get_reagent_amount("lard") : 0
	if (left > 0 && left < 10)
		to_chat(user, "Part of it has been used. About [max(1, round(left * 10))]% is left.")

// Human-readable list of what a light burns.
/proc/light_fuel_names(list/accepted)
	var/list/names = list()
	for (var/id in accepted)
		var/datum/reagent/R = chemical_reagents_list ? chemical_reagents_list[id] : null
		names += R ? lowertext(R.name) : replacetext(id, "_", " ")
	return english_list(names, and_text = " or ")

////////////////
// FLASHLIGHT //
////////////////

/obj/item/flashlight/proc/refuel_hint()
	if (uses_batteries)
		return "a battery"
	if (refuel_reagents)
		return light_fuel_names(refuel_reagents)
	return "nothing"

/obj/item/flashlight/examine(mob/user)
	..()
	if (unlimited || !max_fuel || (!uses_batteries && !refuel_reagents))
		return
	var/percent = round(100 * max(0, fuel) / max_fuel)
	if (uses_batteries)
		to_chat(user, "Battery: about [percent]%. Use a battery on it to recharge it.")
	else
		to_chat(user, "Fuel: about [percent]%. Refill it with [refuel_hint()].")

/obj/item/flashlight/attackby(obj/item/W as obj, mob/user as mob)
	if (uses_batteries && istype(W, /obj/item/weapon/battery))
		charge_from_battery(W, user)
		return TRUE
	if (refuel_reagents && istype(W, /obj/item/weapon/reagent_containers))
		refuel_from_container(W, user)
		return TRUE
	return ..()

/obj/item/flashlight/proc/charge_from_battery(obj/item/weapon/battery/B, mob/user)
	if (unlimited)
		to_chat(user, "\The [src] does not need batteries.")
		return 0
	if (fuel >= max_fuel)
		to_chat(user, "\The [src] is already fully charged.")
		return 0
	if (B.charge <= 0)
		to_chat(user, "<span class='warning'>\The [B] is dead.</span>")
		return 0
	var/added = B.draw_charge(max_fuel - max(0, fuel))
	fuel = min(max_fuel, max(0, fuel) + added)
	to_chat(user, "<span class='notice'>You charge \the [src] from \the [B].</span>")
	return added

/obj/item/flashlight/proc/refuel_from_container(obj/item/weapon/reagent_containers/C, mob/user)
	if (unlimited)
		to_chat(user, "\The [src] does not need refuelling.")
		return 0
	if (fuel >= max_fuel)
		to_chat(user, "\The [src] is already full.")
		return 0
	var/list/result = light_fuel_from_container(C, refuel_reagents, max_fuel - max(0, fuel))
	if (!result)
		to_chat(user, "<span class='warning'>\The [src] burns [refuel_hint()]; \the [C] has none.</span>")
		return 0
	fuel = min(max_fuel, max(0, fuel) + result[1])
	if (istype(C, /obj/item/weapon/reagent_containers/food/snacks/animalfat))
		to_chat(user, "<span class='notice'>You work [QDELETED(C) ? "the fat" : "some of the fat"] into \the [src].</span>")
	else
		to_chat(user, "<span class='notice'>You refuel \the [src] with [lowertext(result[2])].</span>")
	return result[1]

// Called when the light runs dry while lit. Returns TRUE if the light was replaced.
/obj/item/flashlight/proc/burn_out_light()
	on = FALSE
	fuel = 0
	update_icon()
	return FALSE

///////////
// TORCH //
///////////

// A burnt-out torch leaves the tool handle it was made from.
/obj/item/flashlight/torch/burn_out_light()
	var/atom/holder = loc
	var/mob/M = ismob(holder) ? holder : null
	var/turf/T = get_turf(src)
	if (!T)
		qdel(src)
		return TRUE
	if (M)
		M.drop_from_inventory(src)
	on = FALSE
	set_light(0)
	// A torch packed in a bag leaves its handle in the bag; a mount drops it below.
	var/atom/handle_loc = T
	if (istype(holder, /obj/item/weapon/storage) && !istype(holder, /obj/item/weapon/storage/internal))
		handle_loc = holder
	var/obj/item/weapon/material/handle/H = new(handle_loc, handle_material ? handle_material : "wood")
	if (M && !QDELETED(H))
		M.put_in_hands(H)
	if (H && T)
		H.visible_message("\The [src] burns down to \the [H].")
	// A torch burning out in a mount must not leave the mount lit.
	if (istype(holder, /obj/item/weapon/storage/internal))
		refresh_light_holder_later(holder)
	qdel(src)
	return TRUE

/obj/item/flashlight/torch/attackby(obj/item/W as obj, mob/user as mob)
	// Takes only the fat the torch has room for; the rest of the piece is kept.
	if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/animalfat))
		if (unlimited || fuel >= max_fuel)
			to_chat(user, "\The [src] is already well soaked.")
			return TRUE
		refuel_from_container(W, user)
		return TRUE
	return ..()

// Wrapping a tool handle in animal fat, or soaking it in oil, makes a torch.
/obj/item/weapon/material/handle/attackby(obj/item/W as obj, mob/user as mob)
	var/list/accepted = list("fat_oil" = 120, "olive_oil" = 120, "cornoil" = 120, "sunflower_oil" = 120, "linseed_oil" = 120, "petroleum" = 120, "lard" = 60)
	// A piece of fat, whole or part used, is wrapped on as it is.
	if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/animalfat))
		var/lard = W.reagents ? W.reagents.get_reagent_amount("lard") : 0
		if (lard <= 0)
			to_chat(user, "<span class='warning'>There is no fat left on \the [W].</span>")
			return TRUE
		make_torch(user, round(lard * accepted["lard"]), W)
		return TRUE
	if (istype(W, /obj/item/weapon/reagent_containers) && W.reagents && !istype(W, /obj/item/weapon/reagent_containers/food/snacks))
		var/reagent_id
		var/units_needed = 0
		for (var/id in accepted)
			units_needed = TORCH_NEW_FUEL / accepted[id]
			if (W.reagents.get_reagent_amount(id) >= units_needed)
				reagent_id = id
				break
		if (!reagent_id)
			to_chat(user, "<span class='warning'>You need [TORCH_NEW_FUEL / accepted["fat_oil"]] units of oil or [TORCH_NEW_FUEL / accepted["lard"]] units of lard to soak a torch.</span>")
			return TRUE
		if (make_torch(user, TORCH_NEW_FUEL))
			W.reagents.remove_reagent(reagent_id, units_needed)
		return TRUE
	return ..()

/obj/item/weapon/material/handle/proc/make_torch(mob/user, fuel_amount, obj/item/consumed)
	if (!crafting_recipe_allowed(user, "/obj/item/flashlight/torch")) return null
	if (QDELETED(src) || health <= 0 || !material)
		return null
	var/turf/T = get_turf(src)
	if (!T)
		return null
	var/in_hand = (loc == user)
	var/obj/item/flashlight/torch/torch = new(T)
	torch.handle_material = material.name
	torch.fuel = min(torch.max_fuel, fuel_amount)
	if (consumed)
		user.drop_from_inventory(consumed)
		qdel(consumed)
	if (in_hand)
		user.drop_from_inventory(src)
	qdel(src)
	if (in_hand)
		user.put_in_hands(torch)
	to_chat(user, "<span class='notice'>You make \the [torch].</span>")
	return torch

////////////////
// TIKI TORCH //
////////////////

#define TIKI_TORCH_REFUND 2 // sheets returned beside the handle; the torch costs 5

/obj/item/flashlight/tiki_torch/examine(mob/user)
	..()
	if (!unlimited && !on)
		to_chat(user, "Unlit, it can be taken apart with a hammer or a blade for a handle and some [frame_material].")

// A burnt-out (or any unlit) tiki torch comes apart into a tool handle and part of its wood.
/obj/item/flashlight/tiki_torch/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/animalfat))
		if (unlimited || fuel >= max_fuel)
			to_chat(user, "\The [src] is already full.")
			return TRUE
		refuel_from_container(W, user)
		return TRUE
	if (tiki_torch_dismantle_tool(W))
		dismantle_tiki_torch(user)
		return TRUE
	return ..()

/proc/tiki_torch_dismantle_tool(obj/item/W)
	if (!W)
		return FALSE
	if (is_tool(W, TOOL_HAMMER))
		return TRUE
	return istype(W, /obj/item/weapon) && (W.edge || W.sharp) && !istype(W, /obj/item/weapon/reagent_containers)

/obj/item/flashlight/tiki_torch/proc/dismantle_tiki_torch(mob/user)
	if (unlimited)
		to_chat(user, "\The [src] is fixed in place.")
		return FALSE
	if (on)
		to_chat(user, "<span class='warning'>Put \the [src] out before taking it apart.</span>")
		return FALSE
	user.visible_message("<span class='notice'>\The [user] starts taking \the [src] apart.</span>", "<span class='notice'>You start taking \the [src] apart.</span>")
	if (!do_after(user, 30, src) || QDELETED(src) || on)
		return FALSE
	var/obj/item/weapon/material/handle/H = take_apart_tiki_torch()
	if (!H)
		return FALSE
	playsound(H.loc, 'sound/effects/woodhit.ogg', 50, TRUE)
	to_chat(user, "<span class='notice'>You take \the [src] apart into \a [H] and some [H.material.sheet_plural_name].</span>")
	qdel(src)
	return TRUE

// Leaves a handle and TIKI_TORCH_REFUND sheets of the pole material where the torch is.
// Returns the handle; the caller deletes the torch.
/obj/item/flashlight/tiki_torch/proc/take_apart_tiki_torch()
	var/turf/T = get_turf(src)
	if (!T)
		return null
	var/material/M = get_material_by_name(frame_material ? frame_material : "wood")
	if (!M || !M.stack_type)
		M = get_material_by_name("wood")
	if (ismob(loc))
		var/mob/holder = loc
		holder.drop_from_inventory(src)
	on = FALSE
	set_light(0)
	var/obj/item/weapon/material/handle/H = new(T, M.name)
	new M.stack_type(T, TIKI_TORCH_REFUND)
	return H

#undef TIKI_TORCH_REFUND

/////////////////////////
// DYNAMO FLASHLIGHT   //
/////////////////////////

/obj/item/flashlight/japflashlight/refuel_hint()
	return "a few turns of its dynamo"

/obj/item/flashlight/japflashlight/attack_self(mob/user)
	if (!on && fuel <= 0)
		wind_dynamo(user)
		return FALSE
	return ..()

/obj/item/flashlight/japflashlight/verb/wind()
	set name = "Wind Dynamo"
	set category = null
	set src in usr
	wind_dynamo(usr)

/obj/item/flashlight/japflashlight/proc/wind_dynamo(mob/user)
	if (!user || user.incapacitated() || loc != user)
		return
	if (fuel >= max_fuel)
		to_chat(user, "\The [src] is fully wound.")
		return
	to_chat(user, "You start winding \the [src].")
	if (!do_after(user, 30, src) || loc != user)
		return
	fuel = min(max_fuel, max(0, fuel) + 120)
	to_chat(user, "<span class='notice'>You wind \the [src]. It has about [round(100 * fuel / max_fuel)]% charge.</span>")

/////////////
// LIGHTER //
/////////////

/obj/item/weapon/flame/lighter/examine(mob/user)
	..()
	if (max_fuel <= 0) // fire strikers burn no fluid
		return
	to_chat(user, "Fluid: about [round(100 * max(0, fuel) / max(1, max_fuel))]%. Refill it with [light_fuel_names(refuel_reagents)].")

/obj/item/weapon/flame/lighter/attackby(obj/item/W as obj, mob/user as mob)
	if (max_fuel > 0 && istype(W, /obj/item/weapon/reagent_containers) && !istype(W, /obj/item/weapon/reagent_containers/food/snacks))
		if (fuel >= max_fuel)
			to_chat(user, "\The [src] is already full.")
			return TRUE
		var/list/result = light_fuel_from_container(W, refuel_reagents, max_fuel - max(0, fuel))
		if (!result)
			to_chat(user, "<span class='warning'>\The [src] takes [light_fuel_names(refuel_reagents)]; \the [W] has none.</span>")
			return TRUE
		fuel = min(max_fuel, max(0, fuel) + result[1])
		to_chat(user, "<span class='notice'>You refill \the [src] with [lowertext(result[2])].</span>")
		return TRUE
	return ..()

// A lighter saved while lit keeps burning fluid after a load.
/obj/item/weapon/flame/lighter/after_load()
	..()
	if (lit)
		processing_objects |= src

////////////////
// SMARTPHONE //
////////////////

/obj/item/weapon/telephone/mobile/smartphone/examine(mob/user)
	..()
	to_chat(user, "Battery: about [round(100 * max(0, torch_charge) / max(1, torch_max_charge))]%. Use a battery on it to charge it.")

/obj/item/weapon/telephone/mobile/smartphone/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/battery))
		var/obj/item/weapon/battery/B = W
		if (torch_charge >= torch_max_charge)
			to_chat(user, "\The [src] is already fully charged.")
			return TRUE
		if (B.charge <= 0)
			to_chat(user, "<span class='warning'>\The [B] is dead.</span>")
			return TRUE
		torch_charge = min(torch_max_charge, max(0, torch_charge) + B.draw_charge(torch_max_charge - max(0, torch_charge)))
		to_chat(user, "<span class='notice'>You charge \the [src] from \the [B].</span>")
		return TRUE
	return ..()

/obj/item/weapon/telephone/mobile/smartphone/process()
	return process_interval(2)

/obj/item/weapon/telephone/mobile/smartphone/process_interval(configured_seconds = 2)
	if (!torch_on)
		return PROCESS_KILL
	torch_charge = max(0, torch_charge - configured_seconds)
	if (torch_charge <= 0)
		torch_on = FALSE
		set_light(0)
		visible_message("\The [src]'s flashlight flickers off as its battery dies.")
		return PROCESS_KILL

#undef TORCH_NEW_FUEL
