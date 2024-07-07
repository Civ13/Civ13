
/obj/item/clothing/shoes/jackboots
	name = "jackboots"
	desc = "Military-style boots designed for combat or rugged environments."
	icon_state = "jackboots"
	item_state = "jackboots"
	force = 0
	armor = list(melee = 30, arrow = 20, gun = ARMOR_CLASS, energy = 15, bomb = 20, bio = FALSE, rad = FALSE)
	siemens_coefficient = 0.7
	can_hold_knife = TRUE
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE

/obj/item/clothing/shoes/jackboots/modern
	icon_state = "jackboots2"
	item_state = "jackboots2"
	worn_state = "jackboots2"

/obj/item/clothing/shoes/jackboots/brown
	icon_state = "brownboots"
	item_state = "brownboots"
	worn_state = "brownboots"

/obj/item/clothing/shoes/workboots
	name = "workboots"
	desc = "A pair of steel-toed work boots designed for use in industrial settings. Safety first."
	icon_state = "workboots"
	item_state = "workboots"
	armor = list(melee = 40, arrow = FALSE, gun = FALSE, energy = 15, bomb = 20, bio = FALSE, rad = 20)
	siemens_coefficient = 0.7
	can_hold_knife = TRUE
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE