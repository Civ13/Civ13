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
	var/setd = FALSE
	New()
		..()
		spawn(5)
			if (!setd)
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

/obj/item/clothing/accessory/custom/apron
	name = "apron"
	desc = "A cloth apron."
	icon_state = "apron"
	item_state = "apron"
	worn_state = "apron"
	slot = "overcloth"

/obj/item/clothing/accessory/custom/priest_band
	name = "priest band"
	desc = "A priest band."
	icon_state = "customizable_priest_band"
	item_state = "customizable_priest_band"
	worn_state = "customizable_priest_band"
	slot = "decor"

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

/obj/item/clothing/accessory/patch/marksman
	name = "marksman patch"
	desc = "A patch with a marksman logo on it. Usually worn by skilled shooters."
	icon_state = "patch_marksman"
	item_state = "patch_marksman"
	worn_state = "patch_marksman"
	slot = "armband"

/obj/item/clothing/accessory/patch/russia
	name = "Russia patch"
	desc = "A patch with the flag of Russia."
	icon_state = "patch_russia"
	item_state = "patch_russia"
	worn_state = "patch_russia"
	slot = "armband"

/obj/item/clothing/accessory/patch/spetsgruppaa
	name = "Spetsgruppa A patch"
	desc = "A special forces patch, this one is of spetsnaz."
	icon_state = "patch_spets"
	item_state = "patch_marksman"
	worn_state = "patch_marksman"
	slot = "armband"

/obj/item/clothing/accessory/patch/swat
	name = "SWAT patch"
	desc = "A SWAT tag."
	icon_state = "swat"
	item_state = "swat"
	worn_state = "swat"
	slot = "armband"

/obj/item/clothing/accessory/patch/specialforce
	name = "special forces patch"
	desc = "A patch used by special forces."
	icon_state = "patch_specialforces"
	item_state = "patch_specialforces"
	worn_state = "patch_specialforces"
	slot = "armband"

/obj/item/clothing/accessory/patch/police
	name = "POLICE"
	desc = "A tag used by police."
	icon_state = "policetag"
	item_state = "policetag"
	worn_state = "policetag"
	slot = "armband"

/obj/item/clothing/accessory/patch/security
	name = "SECURITY"
	desc = "A tag used by security forces."
	icon_state = "policetag"
	item_state = "policetag"
	worn_state = "policetag"
	slot = "armband"

/obj/item/clothing/accessory/custom/attack_self(mob/user as mob)
	if (uncolored)
		var/input = WWinput(user, "Choose the color:", "Color" , "#FFFFFF", "color")
		if (input == null || input == "")
			return
		else
			color = input
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

/obj/item/clothing/accessory/wearable_sign
	name = "wearable sign"
	desc = "A wooden sign with a string, wearable over the clothing."
	icon_state = "wearable_sign"
	item_state = "wearable_sign"
	worn_state = "wearable_sign"
	slot = "overcloth"

/obj/item/clothing/accessory/wearable_sign/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/pen))
		var/newtext = input("What do you want to write on the sign? (Up to 30 characters)","Sign", "") as text
		if (newtext == null)
			newtext = ""
		newtext = sanitize(newtext, 30, FALSE)
		name = "wooden sign: [newtext]"
		return
	else
		..()