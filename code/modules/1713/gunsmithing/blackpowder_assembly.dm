// Adapted from Isaku4904's GRP Part 1, PR26 head 7750eaebd09be721a9d9816acd9ed8be856e8f89.
// Parts sprites: mohamed/mm2hn (@not_an_egyptian_spy). See docs/flintlock-assembly.md.

/proc/blackpowder_crafting_allowed(mob/living/human/H)
	return H && map && map.ordinal_age >= 3 && map.ordinal_age <= 4 && map.is_node_done(H.civilization, "gunsmithing")

/obj/item/blackpowder_part
	icon = 'icons/obj/guns/flintlocks.dmi'
	w_class = ITEM_SIZE_SMALL
	var/tmp/assembly_busy = FALSE
	var/tmp/assembly_consumed = FALSE

/obj/item/blackpowder_part/persistence_runtime_var(key)
	return key == "assembly_busy" || key == "assembly_consumed" || ..()

/obj/item/blackpowder_part/proc/assembly_access(obj/item/W, mob/living/human/H)
	if (QDELETED(src) || assembly_consumed || QDELETED(W) || QDELETED(H) || !blackpowder_crafting_allowed(H))
		return FALSE
	if (!isturf(H.loc) || W.loc != H || H.get_active_hand() != W || H.incapacitated())
		return FALSE
	return (loc == H || (isturf(loc) && in_range(src, H)))

/obj/item/blackpowder_part/proc/wait_for_assembly(mob/living/human/H, delay)
	return do_after(H, delay, src)

// Reserve both parts before yielding; every success predicate is checked again after the wait.
/obj/item/blackpowder_part/proc/assemble(obj/item/W, mob/living/human/H)
	return FALSE

/obj/item/blackpowder_part/attackby(obj/item/W, mob/user)
	if (ishuman(user) && (istype(W, /obj/item/blackpowder_part) || istype(W, /obj/item/weapon/flint)))
		if (!assemble(W, user))
			to_chat(user, SPAN_WARNING("These parts cannot be assembled right now. Use a compatible barrel or a flint-loaded mechanism on a stock, or sharpened flint on a mechanism. Gunsmithing is required in ages 3 and 4."))
		return
	return ..()

/obj/item/blackpowder_part/stock
	var/barrel_attached = FALSE
	var/barrel_type
	var/gun_type
	var/barreled_icon
	var/assembly_delay = 20

/obj/item/blackpowder_part/stock/pistol
	name = "pistol butt"
	desc = "A wooden flintlock pistol butt. Attach a pistol barrel, then a flint-loaded mechanism."
	icon_state = "wood_frame_pistol"
	barrel_type = /obj/item/blackpowder_part/barrel/pistol
	gun_type = /obj/item/weapon/gun/projectile/flintlock/pistol
	barreled_icon = "wood_frame_barrel_pistol"

/obj/item/blackpowder_part/stock/musket
	name = "musket stock"
	desc = "A wooden flintlock musket stock. Attach a musket barrel, then a flint-loaded mechanism."
	icon_state = "wood_frame_rifle"
	w_class = ITEM_SIZE_NORMAL
	barrel_type = /obj/item/blackpowder_part/barrel/musket
	gun_type = /obj/item/weapon/gun/projectile/flintlock/musket
	barreled_icon = "wood_frame_barrel_rifle"
	assembly_delay = 30

/obj/item/blackpowder_part/barrel/pistol
	name = "pistol barrel"
	desc = "An iron barrel for a flintlock pistol butt."
	icon_state = "pistol_barrel"

/obj/item/blackpowder_part/barrel/musket
	name = "musket barrel"
	desc = "An iron barrel for a flintlock musket stock."
	icon_state = "rifle_barrel"
	w_class = ITEM_SIZE_NORMAL

/obj/item/blackpowder_part/mechanism
	name = "flintlock mechanism"
	desc = "A steel firing mechanism. Insert sharpened flint before attaching it to a barreled stock."
	icon_state = "flintlock_mechanism"
	var/has_flint = FALSE

/obj/item/blackpowder_part/mechanism/assemble(obj/item/W, mob/living/human/H)
	if (assembly_busy || has_flint || !assembly_access(W, H) || !istype(W, /obj/item/weapon/flint))
		return FALSE
	var/obj/item/weapon/flint/F = W
	if (!F.sharpened)
		return FALSE
	assembly_busy = TRUE
	to_chat(H, SPAN_NOTICE("You begin inserting sharpened flint into the mechanism."))
	var/completed = wait_for_assembly(H, 20)
	if (!completed || !assembly_access(F, H) || has_flint || !F.sharpened)
		assembly_busy = FALSE
		return FALSE
	H.drop_from_inventory(F)
	qdel(F)
	has_flint = TRUE
	desc = "A steel firing mechanism with sharpened flint. Attach it to a barreled pistol butt or musket stock."
	assembly_busy = FALSE
	to_chat(H, SPAN_NOTICE("You insert the sharpened flint."))
	return TRUE

/obj/item/blackpowder_part/stock/proc/compatible_part(obj/item/blackpowder_part/P)
	if (QDELETED(P) || P.assembly_consumed)
		return FALSE
	if (!barrel_attached)
		return barrel_type && P.type == barrel_type
	if (istype(P, /obj/item/blackpowder_part/mechanism))
		var/obj/item/blackpowder_part/mechanism/M = P
		return M.has_flint
	return FALSE

/obj/item/blackpowder_part/stock/assemble(obj/item/W, mob/living/human/H)
	if (assembly_busy || !assembly_access(W, H) || !istype(W, /obj/item/blackpowder_part))
		return FALSE
	var/obj/item/blackpowder_part/P = W
	if (P.assembly_busy || !compatible_part(P))
		return FALSE
	var/expected_stage = barrel_attached
	assembly_busy = TRUE
	P.assembly_busy = TRUE
	to_chat(H, SPAN_NOTICE("You begin attaching [P.name] to [name]."))
	var/completed = wait_for_assembly(H, assembly_delay)
	if (!completed || !assembly_access(P, H) || barrel_attached != expected_stage || !compatible_part(P))
		assembly_busy = FALSE
		if (!QDELETED(P))
			P.assembly_busy = FALSE
		return FALSE
	// No yield occurs between final validation, consumption and output.
	P.assembly_consumed = TRUE
	H.drop_from_inventory(P)
	qdel(P)
	if (!expected_stage)
		barrel_attached = TRUE
		icon_state = barreled_icon
		name = "[initial(name)] with barrel"
		desc = "A barreled flintlock stock. Attach a mechanism containing sharpened flint."
		assembly_busy = FALSE
		return TRUE
	assembly_consumed = TRUE
	var/obj/item/weapon/gun/projectile/flintlock/G = new gun_type(get_turf(H))
	if (loc == H)
		H.drop_from_inventory(src)
	qdel(src)
	if (!H.put_in_hands(G))
		G.loc = get_turf(H)
	to_chat(H, SPAN_NOTICE("You finish assembling [G.name]."))
	return G

// Target-native anvil entries retain the existing finished weapons' iron costs.
/obj/structure/anvil/proc/blackpowder_part_options(obj/item/stack/material/P, mob/living/human/H)
	var/list/options = list("Cancel")
	if (!blackpowder_crafting_allowed(H) || QDELETED(P) || !(P.default_type in accepted_materials))
		return options
	var/cost_index = P.default_type == "iron" ? 6 : (P.default_type == "steel" ? 5 : 0)
	if (!cost_index)
		return options
	for (var/key in anvil_recipes)
		var/list/R = anvil_recipes[key]
		if (R[2] == "flintlock parts" && map.ordinal_age >= R[3] && map.ordinal_age <= R[4] && R[cost_index] > 0)
			options += "[key] - [R[cost_index]] [P.default_type]"
	return options

/obj/structure/anvil/proc/forge_blackpowder_part(obj/item/stack/material/P, mob/living/human/H)
	var/list/options = blackpowder_part_options(P, H)
	var/choice = WWinput(H, "Which flintlock part?", "Anvil", "Cancel", options)
	if (choice == "Cancel" || !(choice in options))
		return FALSE
	var/list/parsed = splittext(choice, " - ")
	return produce_blackpowder_part(parsed[1], P, H)

/obj/structure/anvil/proc/blackpowder_forge_access(obj/item/stack/material/P, mob/living/human/H)
	return !QDELETED(src) && !QDELETED(P) && !QDELETED(H) && isturf(H.loc) && in_range(src, H) && P.loc == H && H.get_active_hand() == P && !H.incapacitated()

/obj/structure/anvil/proc/wait_for_blackpowder_forging(mob/living/human/H, delay)
	return do_after(H, delay, src)

/obj/structure/anvil/proc/produce_blackpowder_part(key, obj/item/stack/material/P, mob/living/human/H)
	if (in_use || !blackpowder_forge_access(P, H))
		return FALSE
	var/list/options = blackpowder_part_options(P, H)
	var/cost_index = P.default_type == "iron" ? 6 : (P.default_type == "steel" ? 5 : 0)
	var/list/R = anvil_recipes[key]
	if (!cost_index || !R || !("[key] - [R[cost_index]] [P.default_type]" in options))
		return FALSE
	var/cost = R[cost_index]
	if (P.amount < cost)
		return FALSE
	in_use = TRUE
	update_icon()
	var/completed = wait_for_blackpowder_forging(H, 10 * cost)
	options = blackpowder_part_options(P, H)
	if (!completed || !blackpowder_forge_access(P, H) || P.amount < cost || !("[key] - [cost] [P.default_type]" in options))
		in_use = FALSE
		update_icon()
		return FALSE
	var/output_type = R[9]
	P.use(cost)
	var/obj/item/blackpowder_part/output = new output_type(get_turf(src))
	in_use = FALSE
	update_icon()
	to_chat(H, SPAN_NOTICE("You finish forging [output.name]."))
	return output
