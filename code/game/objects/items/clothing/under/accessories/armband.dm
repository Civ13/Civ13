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
			mob_overlay = image("icon" = icon_override, "icon_state" = "[tmp_icon_state]", layer = 4.1)
		else
			mob_overlay = image("icon" = INV_ACCESSORIES_DEF_ICON, "icon_state" = "[tmp_icon_state]", layer = 4.1)
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
/obj/item/clothing/accessory/armband/japanese
	name = "Japanese armband"
	desc = "An armband with japan's flag on it!"
	icon_state = "jap"
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

/obj/item/clothing/accessory/armband/sheriff
	name = "Sheriff Star"
	desc = "a golden star of the town's Sheriff."
	icon_state = "sheriff"
	icon_state = "sheriff"
	slot = "armband"

/obj/item/clothing/accessory/armband/deputy
	name = "deputy armband"
	desc = "A yellow armband, used to identify the Sheriff's deputies."
	icon_state = "spanish"
	slot = "armband"

//customizable
/obj/item/clothing/accessory/custom
	var/uncolored = FALSE
	var/icon/customoverlay = null
	color = "#FFFFFF"
	New()
		..()
		spawn(5)
			uncolored = TRUE

/obj/item/clothing/accessory/custom/scarf
	name = "scarf"
	desc = "A cloth scarf."
	icon_state = "customscarf"
	item_state = "customscarf"
	worn_state = "customscarf"
	slot = "decor"

/obj/item/clothing/accessory/custom/armband
	name = "armband"
	desc = "A cloth armband."
	icon_state = "customarmband"
	item_state = "customarmband"
	worn_state = "customarmband"
	slot = "armband"

/obj/item/clothing/accessory/custom/sash
	name = "sash"
	desc = "A cloth sash."
	icon_state = "customsash"
	item_state = "customsash"
	worn_state = "customsash"
	slot = "sash"

/obj/item/clothing/accessory/custom/tabard
	name = "tabard"
	desc = "A cloth tabard."
	icon_state = "customtabard"
	item_state = "customtabard"
	worn_state = "customtabard"
	slot = "overcloth"

/obj/item/clothing/accessory/custom/cape
	name = "cape"
	desc = "A cloth cape."
	icon_state = "customcape"
	item_state = "customcape"
	worn_state = "customcape"
	slot = "cape"

/obj/item/clothing/accessory/custom/tie
	name = "tie"
	desc = "A cloth tie."
	icon_state = "custom_tie"
	item_state = "custom_tie"
	worn_state = "custom_tie"
	slot = "tie"

/obj/item/clothing/accessory/custom/bowtie
	name = "bowtie"
	desc = "A cloth bowtie."
	icon_state = "custom_bowtie"
	item_state = "custom_bowtie"
	worn_state = "custom_bowtie"
	slot = "tie"


/obj/item/clothing/accessory/custom/attack_self(mob/user as mob)
	if (uncolored)
		var/input = input(user, "Choose a hex color (without the #):", "Color" , "FFFFFF")
		if (input == null || input == "")
			return
		else
			input = uppertext(input)
			if (lentext(input) != 6)
				return
			var/list/listallowed = list("A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0")
			for (var/i = 1, i <= 6, i++)
				var/numtocheck = 0
				if (i < 6)
					numtocheck = copytext(input,i,i+1)
				else
					numtocheck = copytext(input,i,0)
				if (!(numtocheck in listallowed))
					return
			color = addtext("#",input)
//			user << "Color: [color]"
			uncolored = FALSE
			return
	else
		..()

/obj/item/clothing/accessory/custom/get_mob_overlay()
	if (!mob_overlay)
		var/tmp_icon_state = "[overlay_state? "[overlay_state]" : "[icon_state]"]"
		if (icon_override)
			if ("[tmp_icon_state]_mob" in icon_states(icon_override))
				tmp_icon_state = "[tmp_icon_state]_mob"
			mob_overlay = image("icon" = icon_override, "icon_state" = "[tmp_icon_state]", layer = 4.11)
		else
			mob_overlay = image("icon" = INV_ACCESSORIES_DEF_ICON, "icon_state" = "[tmp_icon_state]", layer = 4.11)

		var/image/NI =  mob_overlay
		NI.color = color
		return NI
	return mob_overlay

/obj/item/clothing/accessory/custom/get_inv_overlay()
	if (!inv_overlay)
		if (!mob_overlay)
			get_mob_overlay()
		var/tmp_icon_state = "[overlay_state? "[overlay_state]" : "[icon_state]"]"
		inv_overlay = image(icon = mob_overlay.icon, icon_state = tmp_icon_state, dir = SOUTH)
		var/image/NI =  inv_overlay
		NI.color = color
		return NI
	return inv_overlay