// Plain necklaces worn on clothing. A cut stone set into one (gemstones.dm)
// hangs from it as a pendant tinted in the stone's colour.

/obj/item/clothing/accessory/necklace
	name = "leather cord necklace"
	desc = "A plain leather cord worn around the neck. A cut stone can be set into it as a pendant."
	icon = 'icons/obj/necklaces.dmi'
	icon_state = "cord_necklace"
	icon_override = 'icons/mob/necklaces.dmi'
	slot = "decor"
	w_class = ITEM_SIZE_TINY
	value = 2

/obj/item/clothing/accessory/necklace/New()
	..()
	update_icon()

/obj/item/clothing/accessory/necklace/after_load()
	..()
	mob_overlay = null
	inv_overlay = null
	update_icon()

/obj/item/clothing/accessory/necklace/update_icon()
	overlays.Cut()
	if (set_gem_colour)
		var/image/P = image(icon, "necklace_pendant")
		P.color = set_gem_colour
		overlays += P
	add_locket_overlay(src, FALSE)
	mob_overlay = null
	inv_overlay = null

/obj/item/clothing/accessory/necklace/get_mob_overlay()
	if (!mob_overlay)
		..()
		if (set_gem_colour && mob_overlay)
			var/image/P = image(icon_override, "necklace_pendant")
			P.color = set_gem_colour
			mob_overlay.overlays += P
		add_locket_overlay(mob_overlay, TRUE)
	return mob_overlay

/obj/item/clothing/accessory/necklace/bead
	name = "bone bead necklace"
	desc = "A string of small bone beads worn around the neck. A cut stone can be set into it as a pendant."
	icon_state = "bead_necklace"

/obj/item/clothing/accessory/necklace/copper
	name = "copper chain necklace"
	desc = "A fine copper chain worn around the neck. A cut stone can be set into it as a pendant."
	icon_state = "copper_necklace"
	flags = CONDUCT
	value = 4

/obj/item/clothing/accessory/necklace/silver
	name = "silver chain necklace"
	desc = "A fine silver chain worn around the neck. A cut stone can be set into it as a pendant."
	icon_state = "silver_necklace"
	flags = CONDUCT
	value = 8

/obj/item/clothing/accessory/necklace/gold
	name = "gold chain necklace"
	desc = "A fine gold chain worn around the neck. A cut stone can be set into it as a pendant."
	icon_state = "gold_necklace"
	flags = CONDUCT
	value = 15
