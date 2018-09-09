// ores

/obj/item/weapon/ore
	name = "rock"
	icon = 'icons/obj/mining.dmi'
	icon_state = "ore2"
	w_class = 2

/obj/item/weapon/ore/iron
	name = "iron ore"
	icon_state = "ore_iron"

/obj/item/weapon/ore/coal
	name = "mineral coal"
	icon_state = "ore_coal"

/obj/item/weapon/ore/glass
	name = "sand"
	icon_state = "ore_glass"
	slot_flags = SLOT_HOLSTER

/obj/item/weapon/ore/silver
	name = "silver ore"
	icon_state = "ore_silver"

/obj/item/weapon/ore/gold
	name = "gold ore"
	icon_state = "ore_gold"

/obj/item/weapon/ore/diamond
	name = "diamonds"
	icon_state = "ore_diamond"

/obj/item/weapon/ore/New()
	pixel_x = rand(0,16)-8
	pixel_y = rand(0,8)-8