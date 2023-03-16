/obj/item/clothing/shoes/
	force = 1
/obj/item/clothing/shoes/black
	name = "black shoes"
	icon_state = "black"
	desc = "A pair of black shoes."
	body_parts_covered = FEET
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE

/obj/item/clothing/shoes/heavyboots
	name = "\improper military boots"
	desc = "When you want to turn up the heat."
	icon_state = "swat"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 80, arrow = 30, gun = 10, energy = 25, bomb = 50, bio = 10, rad = FALSE)
	item_flags = NOSLIP
	siemens_coefficient = 0.6
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE

/obj/item/clothing/shoes/swat
	name = "SWAT boots"
	desc = "When you want to turn up the heat."
	icon_state = "swat"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 80, arrow = 30, gun = 10, energy = 25, bomb = 50, bio = 10, rad = FALSE)
	item_flags = NOSLIP
	siemens_coefficient = 0.6
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE

/obj/item/clothing/shoes/combat
	name = "combat boots"
	desc = "When you REALLY want to turn up the heat"
	icon_state = "swat"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 80, arrow = 30, gun = 10, energy = 25, bomb = 50, bio = 10, rad = FALSE)
	item_flags = NOSLIP
	siemens_coefficient = 0.6

	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE
	heat_protection = FEET
	max_heat_protection_temperature = SHOE_MAX_HEAT_PROTECTION_TEMPERATURE

/obj/item/clothing/shoes/iogboots
	name = "IOG boots"
	desc = "When you REALLY want to turn up the heat."
	icon_state = "iogboot"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 80, arrow = 70, gun = 50, energy = 25, bomb = 50, bio = 10, rad = FALSE)
	item_flags = NOSLIP
	siemens_coefficient = 0.6
	body_parts_covered = FEET
	flags = CONDUCT
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE
	heat_protection = FEET
	max_heat_protection_temperature = SHOE_MAX_HEAT_PROTECTION_TEMPERATURE

/obj/item/clothing/shoes/iogboots/black
	name = "combat boots"
	desc = "Sturdy military footwear."

/obj/item/clothing/shoes/sandal
	desc = "A pair of rather plain, wooden sandals."
	name = "sandals"
	icon_state = "sandals"
	species_restricted = null
	body_parts_covered = FALSE

/obj/item/clothing/shoes/sandal/leather
	name = "sandals"
	desc = "A pair of simple, thin leather strap sandals. Covers up to the lower foot."
	icon_state = "sandals"

/obj/item/clothing/shoes/sandal/marisa
	desc = "A pair of magic, black shoes."
	name = "magic shoes"
	icon_state = "black"
	worn_state = "black"
	worn_state = "black"

/obj/item/clothing/shoes/slippers
	name = "bunny slippers"
	desc = "Fluffy!"
	icon_state = "slippers"
	item_state = "slippers"
	worn_state = "slippers"
	force = FALSE
	species_restricted = null
	w_class = ITEM_SIZE_SMALL
	body_parts_covered = FEET
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE

/obj/item/clothing/shoes/slippers_worn
	name = "worn bunny slippers"
	desc = "Fluffy..."
	icon_state = "slippers_worn"
	item_state = "slippers_worn"
	worn_state = "slippers_worn"
	force = FALSE
	w_class = ITEM_SIZE_SMALL
	body_parts_covered = FEET
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE

/obj/item/clothing/shoes/laceup
	name = "laceup shoes"
	desc = "The height of fashion, and they're pre-polished!"
	icon_state = "laceups"
	item_state = "laceups"
	worn_state = "laceups"
	body_parts_covered = FEET
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE

/obj/item/clothing/shoes/laceup/brown
	name = "brown laceup shoes"
	desc = "The height of fashion, and they're pre-polished!"
	icon_state = "brown_laceups"
	item_state = "brown_laceups"
	worn_state = "brown_laceups"

/obj/item/clothing/shoes/laceup/grey
	name = "grey laceup shoes"
	desc = "The height of fashion, and they're pre-polished!"
	icon_state = "grey_laceups"
	item_state = "grey_laceups"
	worn_state = "grey_laceups"

/obj/item/clothing/shoes/laceup/white
	name = "white laceup shoes"
	desc = "The height of fashion, and they're pre-polished!"
	icon_state = "white_laceups"
	item_state = "white_laceups"
	worn_state = "white_laceups"

/obj/item/clothing/shoes/gator_laceup
	name = "alligator scale laceup shoes"
	desc = "The height of luxurious footwear, and they're pre-polished!"
	icon_state = "gator_laceups"
	item_state = "gator_laceups"
	worn_state = "gator_laceups"
	body_parts_covered = FEET

/obj/item/clothing/shoes/leather
	name = "leather shoes"
	desc = "A sturdy pair of leather shoes."
	icon_state = "leather"
	item_state = "leather"
	worn_state = "leather"
	body_parts_covered = FEET
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE