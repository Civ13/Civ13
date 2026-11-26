// The metal sickle and the hoe (docs/material-roles.md, "Sickle and hoe").
//
// Two farm tools that come in any metal, each asking its material what it is
// worth rather than carrying numbers of its own:
//   sickle_reach(name) -> ripe neighbours of the same crop reaped in one cut
//   the hoe's speed    -> tool_speed(), like every other plain tool
// The flint sickle and the ploughs in code/modules/1713 are untouched.

// Neighbours the softest sickle reaps, the same as the flint sickle.
#define SICKLE_REACH_MIN 2
// One more neighbour for each this much firmness: bronze and iron 3, steel 4.
#define SICKLE_REACH_FIRMNESS 50

/proc/sickle_reach(material_name)
	var/material/M = get_material_by_name(material_name)
	return M ? SICKLE_REACH_MIN + round(M.firmness / SICKLE_REACH_FIRMNESS) : SICKLE_REACH_MIN

/obj/item/weapon/material/kitchen/utensil/knife/sickle
	name = "sickle"
	desc = "A curved blade on a short haft. It cuts like a knife, and reaps the ripe crops of the same kind beside the one you harvest. A harder blade reaps more of them in one cut."
	icon = 'icons/obj/farm_tools.dmi'
	icon_state = "sickle"
	item_state = "knife"
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand_weapons.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_weapons.dmi',
		)
	default_material = "iron"
	value = 8

/obj/item/weapon/material/kitchen/utensil/knife/sickle/set_material(new_material)
	..()
	if (material)
		name = "[material.display_name] sickle"

/obj/item/weapon/material/kitchen/utensil/knife/sickle/examine(mob/user, distance)
	..(user, distance)
	if (material)
		to_chat(user, "It reaps up to [sickle_reach(material.name)] ripe neighbours with each cut.")

/obj/structure/farming/plant/proc/metal_sickle_neighbours(reach)
	. = list()
	for (var/obj/structure/farming/plant/P in orange(1, src))
		if (length(.) >= reach)
			break
		if (P.type == type && P.plant == plant && P.readyHarvest() && P.Adjacent(src))
			. += P

// The flint sickle's reaping in stone_age_extras.dm wraps this one; both
// call ..() and sickle_reaping stops either from reaping a neighbour's
// neighbours.
/obj/structure/farming/plant/attackby(obj/item/weapon/W as obj, mob/user as mob)
	var/list/extra = null
	var/obj/item/weapon/material/kitchen/utensil/knife/sickle/S = W
	if (!sickle_reaping && istype(S) && S.material && stage >= readyStageMin && readyHarvest())
		extra = metal_sickle_neighbours(sickle_reach(S.material.name))
	. = ..()
	if (!length(extra))
		return
	sickle_reaping = TRUE
	for (var/obj/structure/farming/plant/P in extra)
		if (!QDELETED(P) && P.readyHarvest())
			P.attackby(W, user)
	sickle_reaping = FALSE

// A hoe breaks ground the way a plough does, one-handed and from one piece
// of material. Wood is the usual one; metal hoes are quicker.
/obj/item/weapon/plough/hoe
	name = "hoe"
	desc = "A blade set across a long haft. Use it on dirt to break ground for planting, as you would a plough. It is slower than a plough and small enough to hang from a belt."
	icon = 'icons/obj/farm_tools.dmi'
	icon_state = "hoe"
	item_state = "plough"
	color = "#824B28"
	w_class = ITEM_SIZE_SMALL
	usespeed = 1
	tool_material = "wood"
	tool_noun = "hoe"
	tool_role = ROLE_WORK_HEAD

/obj/item/weapon/plough/hoe/set_tool_material(material_name)
	. = ..()
	if (.)
		usespeed = initial(usespeed) * tool_speed(src)
		var/material/M = get_material_by_name(tool_material)
		if (M && !M.flammable)
			flammable = FALSE

// Persistence restores usespeed, including the handle multiplier. Do not
// rebuild it here from the head alone.

#undef SICKLE_REACH_MIN
#undef SICKLE_REACH_FIRMNESS
