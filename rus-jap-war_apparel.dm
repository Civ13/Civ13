/obj/item/clothing/shoes/japboots
	name = "Winter wrapped boots"
	desc = "A pair of simple, thin leather boots. Covers up to the lower leg."
	icon = 'icons/mob/russo-jap_uni.dmi'
	icon_state = "japboots"
	item_state = "japboots"
	worn_state = "japboots"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 15, bullet = 10, laser = 10,energy = 8, bomb = 15, bio = 10, rad = FALSE)
	item_flags = NOSLIP
	siemens_coefficient = 0.6
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE
	var/colorn = 1

/obj/item/clothing/under/japuni
	name = "Japanese Army Uniform"
	desc = "A standard imperial japanese army uniform."
	icon = 'icons/mob/russo-jap_uni.dmi'
	icon_state = "japuni"
	item_state = "japuni"
	worn_state = "japuni"

/obj/item/clothing/accessory/armband/white_sash
	name = "White Sash"
	desc = "A white sash, used by the Japanese White Sash Brigade."
	icon_state = "sash"
	item_state = "sash"

/obj/item/clothing/under/rusuni
	name = "Russian Army Uniform"
	desc = "A standard imperial russian army uniform."
	icon = 'icons/mob/russo-jap_uni.dmi'
	icon_state = "rusuni"
	item_state = "rusuni"
	worn_state = "rusuni"

/obj/item/clothing/suit/storage/armycoat
	min_cold_protection_temperature = COAT_MIN_COLD_PROTECTION_TEMPERATURE

/obj/item/clothing/suit/storage/armycoat/japcoat
	name = "Japanese Coat"
	desc = "A japanese army coat."
	icon = 'icons/mob/russo-jap_uni.dmi'
	icon_state = "japcoat"
	item_state = "japcoat"
	worn_state = "japcoat"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, bullet = 0, laser = 10,energy = 15, bomb = 5, bio = 30, rad = FALSE)
	value = 65
	var/colorn = 1


/obj/item/clothing/suit/storage/armycoat/japcoat2
	name = "Japanese Coat"
	desc = "A japanese army coat."
	icon = 'icons/mob/russo-jap_uni.dmi'
	icon_state = "japcoat2"
	item_state = "japcoat2"
	worn_state = "japcoat2"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, bullet = 0, laser = 10,energy = 15, bomb = 5, bio = 30, rad = FALSE)
	value = 65
	var/colorn = 1

/obj/item/clothing/suit/storage/armycoat/ruscoat
	name = "Russian Coat"
	desc = "A russian army coat."
	icon = 'icons/mob/russo-jap_uni.dmi'
	icon_state = "ruscoat1"
	item_state = "ruscoat1"
	worn_state = "ruscoat1"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, bullet = 0, laser = 10,energy = 15, bomb = 5, bio = 30, rad = FALSE)
	value = 65
	var/colorn = 1

/obj/item/clothing/suit/storage/armycoat/rusoffcoat
	name = "Russian Officer Coat."
	desc = "A russian army  officer coat. Worn by officers, acknowledge their rank."
	icon = 'icons/mob/russo-jap_uni.dmi'
	icon_state = "rusoffcoat"
	item_state = "rusoffcoat"
	worn_state = "rusoffcoat"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, bullet = 0, laser = 10,energy = 15, bomb = 5, bio = 30, rad = FALSE)
	value = 65
	var/colorn = 1

/obj/item/clothing/suit/armor/japmisc
	min_cold_protection_temperature = COAT_MIN_COLD_PROTECTION_TEMPERATURE

/obj/item/clothing/suit/armor/japmisc/japvest
	name = "Matagi Vest"
	desc = "A warm, fur lined vest made of leather."
	icon = 'icons/mob/russo-jap_uni.dmi'
	icon_state = "japvest"
	item_state = "japvest"
	worn_state = "japvest"
	body_parts_covered = UPPER_TORSO
	cold_protection = UPPER_TORSO
	armor = list(melee = 10, bullet = 10, laser = 10,energy = 10, bomb = 10, bio = 10, rad = FALSE)
	value = 10

/obj/item/clothing/head/japcap
	name = "Japanese Cap"
	desc = "A cap worn by japanese soldiers."
	icon = 'icons/mob/russo-jap_uni.dmi'
	icon_state = "japcap"
	item_state = "japcap"

/obj/item/clothing/head/japcap2
	name = "Japanese Cap"
	desc = "A cap worn by japanese soldiers."
	icon = 'icons/mob/russo-jap_uni.dmi'
	icon_state = "japcap2"
	item_state = "japcap2"

obj/item/clothing/head/japoffcap
	name = "Japanese Officer Cap"
	desc = "A cap worn by japanese officers."
	icon = 'icons/mob/russo-jap_uni.dmi'
	icon_state = "japoffcap"
	item_state = "japoffcap"

/obj/item/clothing/head/ruscap
	name = "Russian Cap"
	desc = "A cap worn by russian soldiers."
	icon = 'icons/mob/russo-jap_uni.dmi'
	icon_state = "ruscap1"
	item_state = "ruscap1"

/obj/item/clothing/head/rusoffcap
	name = "Russian Officer Cap"
	desc = "A cap worn by russian army officers."
	icon = 'icons/mob/russo-jap_uni.dmi'
	icon_state = "rusoffcap"
	item_state = "rusoffcap"
