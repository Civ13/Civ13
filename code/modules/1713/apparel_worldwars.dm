/obj/item/clothing/suit/storage/coat/germcoat
	name = "German Coat"
	desc = "A german coat."
	icon_state = "germtrench"
	item_state = "germtrench"
	worn_state = "germtrench"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, bullet = 0, laser = 10,energy = 15, bomb = 5, bio = 30, rad = FALSE)
	value = 65
	var/colorn = 1

/obj/item/clothing/suit/storage/coat/frenchcoat
	name = "French Trench Coat"
	desc = "A french trench coat."
	icon_state = "frenchtrench"
	item_state = "frenchtrench"
	worn_state = "frenchtrench"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, bullet = 0, laser = 10,energy = 15, bomb = 5, bio = 30, rad = FALSE)
	value = 65
	var/colorn = 1

/obj/item/clothing/head/germcap
	name = "German Cap"
	desc = "A cap worn by german soldiers."
	icon_state = "germcap"
	item_state = "germcap"

/obj/item/clothing/head/frenchcap
	name = "French Cap"
	desc = "A cap worn by french soldiers."
	icon_state = "frenchcap"
	item_state = "frenchcap"

/obj/item/clothing/head/britishcap
	name = "British Cap"
	desc = "A cap worn by british soldiers."
	icon_state = "brittcap"
	item_state = "brittcap"

/obj/item/clothing/head/helmet/ww/stahlhelm
	name = "iron stahlhelm"
	desc = "A typical pointed helmet."
	icon_state = "stahlhelm_old"
	item_state = "stahlhelm_old"
	worn_state = "stahlhelm_old"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 45, bullet = 35, laser = 10,energy = 15, bomb = 45, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww/adrian
	name = "Adrian Helmet"
	desc = "A typical french adrian helmet."
	icon_state = "adrian"
	item_state = "adrian"
	worn_state = "adrian"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, bullet = 30, laser = 10,energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/mask/glasses/pilot
	name = "pilot goggles"
	desc = "Early 20th century pilot goggles."
	icon_state = "biker"
	item_state = "biker"
	worn_state = "biker"