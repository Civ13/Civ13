/obj/item/clothing/gloves/captain
	desc = "Regal blue gloves, with a nice gold trim. Swanky."
	name = "captain's gloves"
	icon_state = "captain"
	item_state = "egloves"

/obj/item/clothing/gloves/thick
	desc = "These work gloves are thick and fire-resistant."
	name = "black gloves"
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
	desc = "These fur gloves are cold and fire-resistant."
	name = "black fur gloves"
	icon_state = "blackfur"
	item_state = "blackfur"

/obj/item/clothing/gloves/thick/leather/brown
	desc = "These fur gloves are cold and fire-resistant."
	name = "brown fur gloves"
	icon_state = "brownfur"
	item_state = "brownfur"

/obj/item/clothing/gloves/thick/leather/white
	desc = "These fur gloves are cold and fire-resistant."
	name = "white fur gloves"
	icon_state = "whitefur"
	item_state = "whitefur"

/obj/item/clothing/gloves/thick/leather/grey
	desc = "These fur gloves are cold and fire-resistant."
	name = "grey fur gloves"
	icon_state = "greyfur"
	item_state = "greyfur"

/obj/item/clothing/gloves/thick/leather/pink
	desc = "Gloves made of human skin. Barbaric."
	name = "human skin gloves"
	icon_state = "pinkfur"
	item_state = "pinkfur"

/obj/item/clothing/gloves/thick/leather/orc
	desc = "These fur gloves are cold and fire-resistant, made from orc skin."
	name = "orc fur gloves"
	icon_state = "orcfur"
	item_state = "orcfur"

/obj/item/clothing/gloves/thick/combat //Combined effect of SWAT gloves and insulated gloves
	desc = "These tactical gloves are somewhat fire and impact resistant."
	name = "combat gloves"
	icon_state = "black"
	item_state = "swat_gl"
	armor = list(melee = 80, arrow = 15, gun = FALSE, energy = 25, bomb = 50, bio = 10, rad = FALSE)
	siemens_coefficient = FALSE

/obj/item/clothing/gloves/botanic_leather
	desc = "These leather work gloves protect against thorns, barbs, prickles, spikes and other harmful objects of floral origin."
	name = "botanist's leather gloves"
	icon_state = "leather"
	item_state = "ggloves"
	permeability_coefficient = 0.05
	siemens_coefficient = 0.50 //thick work gloves

/obj/item/clothing/gloves/union_gloves
	desc = "Gloves worn by union cavalry and other military personel."
	name = "union gloves"
	icon_state = "union_gloves"
	item_state = "union_gloves"
	permeability_coefficient = 0.05
	siemens_coefficient = 0.50 //thick work gloves

