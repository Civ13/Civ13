/obj/item/weapon/material/star
	name = "shuriken"
	desc = "A sharp, perfectly weighted piece of metal."
	icon_state = "star"
	force_divisor = 0.1 // 6 with hardness 60 (steel)
	thrown_force_divisor = 0.65 // 15 with weight 20 (steel)
	throw_speed = 10
	throw_range = 15
	sharp = TRUE
	edge =  TRUE

/obj/item/weapon/material/star/New()
	..()
	pixel_x = rand(-12, 12)
	pixel_y = rand(-12, 12)

/obj/item/weapon/material/kunai_normal
	name = "Kunai"
	desc = "Tool of some ninjas."
	icon_state = "throwing_knife"
	force_divisor = 0.18 // 10? when wielded with hardness 60 (steel)
	thrown_force_divisor = 0.70
	throw_speed = 9
	throw_range = 13
	sharp = TRUE
	edge =  TRUE

/obj/item/weapon/material/kunai_normal/New()
	..()
	pixel_x = rand(-8, 8)
	pixel_y = rand(-8, 8)

/obj/item/weapon/material/throwing_knife
	name = "Throwing knife"
	desc = "A balanced knife for throwing."
	icon_state = "throwing_knife"
	force_divisor = 0.25 // 15 when wielded with hardness 60 (steel)
	thrown_force_divisor = 0.75
	throw_speed = 8
	throw_range = 12
	sharp = TRUE
	edge =  TRUE

/obj/item/weapon/material/throwing_knife/New()
	..()
	pixel_x = rand(-8, 8)
	pixel_y = rand(-8, 8)