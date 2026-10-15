// Paid wood fuel, existing ash, and an optional mode of the existing compost bin.
/datum/wood_fuel_residue
	var/wood_remaining = 0
	var/ash_fraction = 0

/datum/wood_fuel_residue/New(seed = 0)
	wood_remaining = max(0, seed)

/datum/wood_fuel_residue/proc/burn(amount, available, turf/site)
	wood_remaining = clamp(wood_remaining, 0, max(0, available))
	var/paid = min(max(0, amount), wood_remaining)
	wood_remaining -= paid
	ash_fraction += paid
	while (ash_fraction >= 1)
		ash_fraction--
		if (site)
			new /obj/item/wood_ash(site)

/obj/structure/oven
	var/datum/wood_fuel_residue/wood_residue
/obj/structure/furnace
	var/datum/wood_fuel_residue/wood_residue
/obj/structure/machinery/factory
	var/datum/wood_fuel_residue/wood_residue

// Only these three fuel-bearing families call this helper. Unknown legacy fuel
// is deliberately unattributed; it must never become free wood ash after load.
/obj/structure/proc/wood_residue_account(loaded = FALSE)
	var/datum/wood_fuel_residue/account = vars["wood_residue"]
	if (!account)
		var/seed = 0
		if (!loaded && (istype(src, /obj/structure/oven/fireplace) || istype(src, /obj/structure/oven/woodstove)))
			var/obj/structure/oven/O = src
			seed = min(max(0, O.fuel), initial(O.fuel))
		account = new(seed)
		vars["wood_residue"] = account
	return account

/obj/structure/proc/record_wood_fuel(obj/item/I, amount)
	if (!I || !I.loc || amount <= 0)
		return
	var/is_plant = istype(I, /obj/item/stack/material/wood) || istype(I, /obj/item/stack/material/woodplank) || istype(I, /obj/item/stack/material/bamboo) || istype(I, /obj/item/weapon/branch) || istype(I, /obj/item/stack/material/leaf)
	if (istype(I, /obj/item/weapon/material))
		var/obj/item/weapon/material/M = I
		is_plant = M.get_material_name() == "wood"
	if (is_plant)
		var/datum/wood_fuel_residue/account = wood_residue_account()
		account.wood_remaining += amount

/obj/structure/proc/burn_structure_fuel(requested)
	var/available = max(0, vars["fuel"])
	var/paid = min(max(0, requested), available)
	var/datum/wood_fuel_residue/account = wood_residue_account()
	vars["fuel"] = available - paid
	account.burn(paid, available, get_turf(src))
	return paid

/obj/structure/oven/after_load()
	..()
	wood_residue_account(TRUE)
/obj/structure/furnace/after_load()
	..()
	wood_residue_account(TRUE)
/obj/structure/machinery/factory/after_load()
	..()
	wood_residue_account(TRUE)

/obj/structure/compost
	var/nitrary_mode = FALSE
	var/nitrary_stage = 0 // 0 loading, 1 aging, 2 mature, 3 leaching, 4 ready
	var/nitrary_plants = 0
	var/nitrary_water = 0
	var/nitrary_time_left = 0
	var/tmp/nitrary_last_tick = 0

/obj/structure/compost/persistence_runtime_var(key)
	return key == "nitrary_last_tick" || key == "composting" || ..()

/obj/structure/compost/proc/nitrary_actor(mob/living/human/H)
	return istype(H) && H.stat == CONSCIOUS && H.loc && get_turf(src) && H.z == z && get_dist(H, src) <= 1

/obj/structure/compost/verb/use_as_nitrary()
	set src in oview(1)
	set name = "Use as plant nitrary"
	set category = null
	nitrary_convert(usr)

/obj/structure/compost/proc/nitrary_convert(mob/living/human/H)
	if (!nitrary_actor(H) || nitrary_mode || current > 0 || contents.len)
		return FALSE
	nitrary_mode = TRUE
	name = "plant nitrary"
	desc = "An airy compost bin dedicated to aging plant waste for nitrate leaching."
	nitrary_last_tick = world.time
	processing_objects |= src
	to_chat(H, "This empty bin is now a plant nitrary. Add 32 leaves or eight crop plants, then ten units of water. Aging takes thirty running-server minutes. Mature compost then needs one unit of ash and a minute to leach. Draw the result with an empty small pot and boil it.")
	return TRUE

/obj/structure/compost/proc/nitrary_feed(obj/item/W, mob/living/human/H)
	if (!nitrary_mode || !nitrary_actor(H) || !W || !W.loc || (H.l_hand != W && H.r_hand != W))
		return FALSE
	if (nitrary_stage == 0)
		var/value = 0
		if (istype(W, /obj/item/stack/material/leaf))
			value = 0.25
		else if (istype(W, /obj/item/stack/material/flax) || istype(W, /obj/item/stack/material/hemp) || istype(W, /obj/item/stack/material/poppy) || istype(W, /obj/item/stack/material/tobacco) || istype(W, /obj/item/stack/material/tobacco_green) || istype(W, /obj/item/stack/material/coca))
			value = 1
		if (value)
			var/obj/item/stack/S = W
			var/take = min(S.amount, round((8 - nitrary_plants) / value))
			// Reagent feedstock is paid in full, without religious crafting discounts.
			if (take > 0 && S.use(take))
				nitrary_plants += take * value
		else if (istype(W, /obj/item/weapon/reagent_containers/glass) && W.reagents)
			var/take = min(10 - nitrary_water, W.reagents.get_reagent_amount("water"))
			if (take > 0)
				W.reagents.remove_reagent("water", take)
				nitrary_water += take
		if (nitrary_plants >= 8 && nitrary_water >= 10)
			nitrary_stage = 1
			nitrary_time_left = 18000 // Thirty running-server minutes, not real chemistry time.
			nitrary_last_tick = world.time
		return TRUE
	if (nitrary_stage == 2 && istype(W, /obj/item/weapon/reagent_containers/glass) && W.reagents && W.reagents.get_reagent_amount("ash") >= 1)
		W.reagents.remove_reagent("ash", 1)
		nitrary_stage = 3
		nitrary_time_left = 600
		nitrary_last_tick = world.time
		return TRUE
	if (nitrary_stage == 4)
		return nitrary_draw(W, H)
	to_chat(H, "The nitrary needs paid plants and water first, then time, then ash. Examine it for progress.")
	return FALSE

/obj/structure/compost/proc/nitrary_draw(obj/item/W, mob/living/human/H)
	if (!nitrary_mode || !nitrary_actor(H) || nitrary_stage != 4 || !istype(W, /obj/item/weapon/reagent_containers/glass/small_pot) || (H.l_hand != W && H.r_hand != W) || !W.reagents || W.reagents.total_volume || W.reagents.maximum_volume < 10)
		return FALSE
	W.reagents.add_reagent("nitrate_leachate", 10)
	// The entire paid batch is spent once, after the non-yielding transfer.
	nitrary_stage = 0
	nitrary_plants = 0
	nitrary_water = 0
	nitrary_time_left = 0
	to_chat(H, "You draw the nitrate leachate. Boil this small pot on a lit stove to recover its minerals.")
	return TRUE

/obj/structure/compost/process()
	if (!nitrary_mode || !get_turf(src))
		return
	var/elapsed = min(600, max(0, world.time - nitrary_last_tick))
	nitrary_last_tick = world.time
	if (nitrary_stage != 1 && nitrary_stage != 3)
		return
	nitrary_time_left = max(0, nitrary_time_left - elapsed)
	if (!nitrary_time_left)
		nitrary_stage = nitrary_stage == 1 ? 2 : 4
		visible_message(nitrary_stage == 2 ? "The plant compost has matured. It is ready for ash-assisted leaching." : "The nitrary leachate is ready to draw into an empty small pot.")

/obj/structure/compost/proc/nitrary_examine(mob/user)
	to_chat(user, "Plant nitrary: stage [nitrary_stage]/4; plants [nitrary_plants]/8; water [nitrary_water]/10; [round(nitrary_time_left / 600, 0.1)] running-server minutes remain. Add 32 leaves or eight crop plants and ten units of water; age for thirty minutes, add one ash, leach for one minute, then draw into an empty small pot and boil. This mode does not accept ordinary food, wood, urine or fertilizer as plant credit.")

/obj/structure/compost/Del()
	processing_objects -= src
	..()

/datum/reagent/nitrate_leachate
	name = "Plant nitrate leachate"
	id = "nitrate_leachate"
	description = "A dilute, processed plant-compost extract. Boil it in a small pot to recover the game's saltpeter minerals."
	taste_description = "earthy"
	reagent_state = LIQUID
	color = "#98895C"

/datum/reagents/proc/boil_nitrary()
	var/paid = get_reagent_amount("nitrate_leachate")
	if (paid <= 0)
		return FALSE
	remove_reagent("nitrate_leachate", paid)
	// Match the existing saltpeter ore extraction's legacy chemistry IDs.
	add_reagent("potassium", paid / 10)
	add_reagent("nitrogen", paid / 10)
	return TRUE
