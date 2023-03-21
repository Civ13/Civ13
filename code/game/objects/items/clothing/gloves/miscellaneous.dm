/obj/item/clothing/gloves/captain
	name = "captain's gloves"
	desc = "Regal blue gloves, with a nice gold trim. Swanky."
	icon_state = "captain"
	item_state = "egloves"

/obj/item/clothing/gloves/thick
	name = "black gloves"
	desc = "These work gloves are thick and fire-resistant."
	icon_state = "black"
	item_state = "bgloves"
	siemens_coefficient = 0.50
	permeability_coefficient = 0.05

	cold_protection = HANDS
	min_cold_protection_temperature = GLOVES_MIN_COLD_PROTECTION_TEMPERATURE
	heat_protection = HANDS
	max_heat_protection_temperature = GLOVES_MAX_HEAT_PROTECTION_TEMPERATURE

/obj/item/clothing/gloves/thick/leather
	desc = "These leather gloves are cold and fire-resistant."
	name = "leather gloves"
	icon_state = "leather"
	item_state = "leather"

/obj/item/clothing/gloves/thick/leather/black
	name = "black fur gloves"
	icon_state = "blackfur"
	item_state = "blackfur"

/obj/item/clothing/gloves/thick/leather/brown
	name = "brown fur gloves"
	icon_state = "brownfur"
	item_state = "brownfur"

/obj/item/clothing/gloves/thick/leather/white
	name = "white fur gloves"
	icon_state = "whitefur"
	item_state = "whitefur"

/obj/item/clothing/gloves/thick/leather/grey
	name = "grey fur gloves"
	icon_state = "greyfur"
	item_state = "greyfur"

/obj/item/clothing/gloves/thick/leather/pink
	name = "human skin gloves"
	desc = "Gloves made of human skin. Barbaric."
	icon_state = "pinkfur"
	item_state = "pinkfur"

/obj/item/clothing/gloves/thick/firefighter
	name = "fire-resistant gloves"
	icon_state = "firefighter"
	item_state = "firefighter"
	max_heat_protection_temperature = GLOVES_MAX_HEAT_PROTECTION_TEMPERATURE*4
	flammable = FALSE

//orc gloves relocated to apparel_tribes.dm

/obj/item/clothing/gloves/thick/combat //Combined effect of SWAT gloves and insulated gloves
	desc = "These tactical gloves are somewhat fire and impact resistant."
	name = "combat gloves"
	icon_state = "black"
	item_state = "swat_gl"
	armor = list(melee = 80, arrow = 15, gun = 10, energy = 25, bomb = 50, bio = 10, rad = FALSE)
	siemens_coefficient = FALSE

/obj/item/clothing/gloves/thick/swat //Combined effect of SWAT gloves and insulated gloves
	name = "swat gloves"
	desc = "Combat gloves used by swat officers."
	icon_state = "swat"
	item_state = "swat"
	armor = list(melee = 80, arrow = 15, gun = 15, energy = 25, bomb = 50, bio = 10, rad = FALSE)
	siemens_coefficient = FALSE

/obj/item/clothing/gloves/thick/swat/officer
	name = "Officer gloves"
	desc = "Shiny black gloves used by officers to keep their hands clean."

/obj/item/clothing/gloves/thick/salamon //Combined effect of SWAT gloves and insulated gloves
	name = "gold plated gloves"
	desc = "Gold plated gloves. These look expensive."
	icon_state = "salamon"
	item_state = "salamon"
	armor = list(melee = 50, arrow = 15, gun = 10, energy = 25, bomb = 50, bio = 10, rad = FALSE)
	siemens_coefficient = FALSE

/obj/item/clothing/gloves/botanic_leather
	name = "botanist's leather gloves"
	desc = "These leather work gloves protect against thorns, barbs, prickles, spikes and other harmful objects of floral origin."
	icon_state = "leather"
	item_state = "ggloves"
	permeability_coefficient = 0.05
	siemens_coefficient = 0.50 //thick work gloves

/obj/item/clothing/gloves/oven
	name = "oven mittens"
	desc = "Thick padded gloves worn to protect the hands from heat retrieving food."
	icon_state = "oven_mitts"
	item_state = "oven_mitts"
	worn_state = "oven_mitts"
	permeability_coefficient = 0.05
	siemens_coefficient = 0.50 //thick work gloves

/obj/item/clothing/gloves/union_gloves
	name = "cavalry gloves"
	desc = "Gloves worn by union cavalry and other military personel."
	icon_state = "union_gloves"
	item_state = "union_gloves"
	permeability_coefficient = 0.05
	siemens_coefficient = 0.50 //thick work gloves


/obj/item/clothing/gloves/boxing
	name = "boxing gloves"
	desc = "Because you really needed another excuse to punch your crewmates."
	icon_state = "boxing"
	item_state = "boxing"

/obj/item/clothing/gloves/boxing/green
	icon_state = "boxinggreen"
	item_state = "boxinggreen"

/obj/item/clothing/gloves/boxing/blue
	icon_state = "boxingblue"
	item_state = "boxingblue"

/obj/item/clothing/gloves/boxing/yellow
	icon_state = "boxingyellow"
	item_state = "boxingyellow"

/obj/item/clothing/gloves/sterile
	name = "latex gloves"
	desc = "Sterile gloves."
	icon_state = "latex"
	item_state = "latex"
	germ_level = 0
	fingerprint_chance = 20
	armor = list(melee = 2, arrow = 1, gun = FALSE, energy = 25, bomb = 10, bio = 50, rad = FALSE)

/obj/item/clothing/gloves/sterile/nuclear
	name = "NBC gloves"
	desc = "Sterile gloves which also protect you from ambient radiation."
	icon_state = "latex"
	item_state = "latex"
	germ_level = 0
	fingerprint_chance = 10
	armor = list(melee = 2, arrow = 1, gun = FALSE, energy = 25, bomb = 10, bio = 50, rad = 10)

/obj/item/clothing/gloves/sterile/nitrile
	name = "nitrile gloves"
	desc = "Sterile gloves."
	icon_state = "blue"
	item_state = "bluegloves"

