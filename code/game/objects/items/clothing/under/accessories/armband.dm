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

/obj/item/clothing/accessory/armband/british
	name = "red armband"
	desc = "A fancy red armband!"
	icon_state = "british"
	slot = "armband"

/obj/item/clothing/accessory/armband/spanish
	name = "yellow armband"
	desc = "A fancy yellow armband!"
	icon_state = "spanish"
	slot = "armband"

/obj/item/clothing/accessory/armband/french
	name = "blue armband"
	desc = "A fancy blue armband!"
	icon_state = "french"
	slot = "armband"

/obj/item/clothing/accessory/armband/portuguese
	name = "green armband"
	desc = "A fancy green armband!"
	icon_state = "portuguese"
	slot = "armband"

/obj/item/clothing/accessory/armband/dutch
	name = "orange armband"
	desc = "A fancy orange armband!"
	icon_state = "dutch"
	slot = "armband"

//jewelry

/obj/item/clothing/accessory/armband/armbangle
	name = "iron arm bangle"
	desc = "Iron bangles to wear on your arms."
	icon_state = "iron_arm"
	icon_state = "iron_arm"
	slot = "decor"

/obj/item/clothing/accessory/armband/armbangle/gold
	name = "gold arm bangle"
	desc = "Gold bangles to wear on your arms."
	icon_state = "gold_arm"
	icon_state = "gold_arm"
	slot = "decor"

/obj/item/clothing/accessory/armband/armbangle/silver
	name = "silver arm bangle"
	desc = "Silver bangles to wear on your arms."
	icon_state = "silver_arm"
	icon_state = "silver_arm"
	slot = "decor"

/obj/item/clothing/accessory/armband/armbangle/copper
	name = "copper arm bangle"
	desc = "Copper bangles to wear on your arms."
	icon_state = "copper_arm"
	icon_state = "copper_arm"
	slot = "decor"

/obj/item/clothing/accessory/armband/armbangle/bronze
	name = "bronze arm bangle"
	desc = "Bronze bangles to wear on your arms."
	icon_state = "bronze_arm"
	icon_state = "bronze_arm"
	slot = "decor"