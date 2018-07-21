/obj/item/clothing/accessory/medal/WW2
	icon = 'icons/WW2/medals.dmi'
	var/visual = "gold"

/obj/item/clothing/accessory/medal/WW2/get_inv_overlay()
	if (!inv_overlay)
		inv_overlay = image(icon = 'icons/WW2/medals.dmi', icon_state = "suit_[visual]", dir = SOUTH)
	return inv_overlay

/obj/item/clothing/accessory/medal/WW2/get_mob_overlay()
	return get_inv_overlay()


// German

/obj/item/clothing/accessory/medal/WW2/iron_cross_oak_leaves
	name = "Iron Cross with Oak Leaves medal"
	icon_state = "iron_cross_oak_leaves"
	visual = "bronze"
	// desc: todo