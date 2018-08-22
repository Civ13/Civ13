/obj/item/weapon/material/harpoon
	name = "harpoon"
	sharp = TRUE
	edge = TRUE
	desc = "Good for whale hunting."
	slot_flags = SLOT_BACK | SLOT_BELT
	icon_state = "harpoon"
	item_state = "harpoon"
	throw_speed = 3
	throw_range = 7
	allow_spin = FALSE
	force_divisor = 0.3 // 18 with hardness 60 (steel)
	thrown_force_divisor = 1 // 20 with weight 20 (steel)
	attack_verb = list("jabbed","impaled","ripped")


/obj/item/weapon/material/spear
	name = "spear"
	sharp = TRUE
	edge = TRUE
	desc = "A crude, yet effective weapon."
	slot_flags = SLOT_BACK | SLOT_BELT
	icon_state = "spear"
	item_state = "harpoon"
	throw_speed = 6
	throw_range = 11
	allow_spin = FALSE
	force_divisor = 0.4 // 24 with hardness 60 (steel)
	thrown_force_divisor = 10 // 20 with weight 20 (steel)
	attack_verb = list("jabbed","impaled","ripped")

/obj/item/weapon/material/hatchet
	name = "hatchet"
	desc = "A very sharp axe blade upon a short wood handle. It has a long history of chopping things, but now it is used for chopping wood."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "hatchet"
	force_divisor = 0.2 // 12 with hardness 60 (steel)
	thrown_force_divisor = 0.75 // 15 with weight 20 (steel)
	w_class = 2
	sharp = TRUE
	edge = TRUE
//	origin_tech = "materials=2;combat=1"
	attack_verb = list("chopped", "torn", "cut")
	applies_material_colour = FALSE

/obj/item/weapon/material/hatchet/New()
	name = "hatchet"

/obj/item/weapon/material/boarding_axe
	name = "boarding axe"
	desc = "A short axe, useful for breaking wood and boarding enemy ships."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "combat_axe"
	force_divisor = 0.4 // 12 with hardness 60 (steel)
	thrown_force_divisor = 0.75 // 15 with weight 20 (steel)
	w_class = 2
	sharp = TRUE
	edge = TRUE
//	origin_tech = "materials=2;combat=1"
	attack_verb = list("chopped", "torn", "cut")
	slot_flags = SLOT_BELT
	applies_material_colour = FALSE


/obj/item/weapon/material/minihoe // -- Numbers
	name = "mini hoe"
	desc = "It's used for removing weeds or scratching your back."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "hoe"
	item_state = "hoe"
	force_divisor = 0.25 // 5 with weight 20 (steel)
	thrown_force_divisor = 0.25 // as above
	w_class = 2
	attack_verb = list("slashed", "sliced", "cut", "clawed")

/obj/item/weapon/material/scythe
	icon_state = "scythe0"
	name = "scythe"
	desc = "A sharp and curved blade on a long fibremetal handle, this tool makes it easy to reap what you sow."
	force_divisor = 0.275 // 16 with hardness 60 (steel)
	thrown_force_divisor = 0.25 // 5 with weight 20 (steel)
	sharp = TRUE
	edge = TRUE
	throw_speed = TRUE
	throw_range = 3
	w_class = 4
	slot_flags = SLOT_BACK
//	origin_tech = "materials=2;combat=2"
	attack_verb = list("chopped", "sliced", "cut", "reaped")
