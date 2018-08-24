/obj/item/clothing/accessory/armband
	name = "red armband"
	desc = "A fancy red armband!"
	icon_state = "red"
	slot = "armband"

/obj/item/clothing/accessory/armband/get_mob_overlay()
	if (!mob_overlay)
		var/tmp_icon_state = "[overlay_state? "[overlay_state]" : "[icon_state]"]"
		if (icon_override)
			if ("[tmp_icon_state]_mob" in icon_states(icon_override))
				tmp_icon_state = "[tmp_icon_state]_mob"
			mob_overlay = image("icon" = icon_override, "icon_state" = "[tmp_icon_state]", layer = 5)
		else
			mob_overlay = image("icon" = INV_ACCESSORIES_DEF_ICON, "icon_state" = "[tmp_icon_state]", layer = 5)
	return mob_overlay
