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


////Yeah, not food, i know. But i need the reagents...
/obj/item/weapon/reagent_containers/food/snacks/saltpeter
	name = "saltpeter"
	desc = "A yellowish cristal, consisting of potassium nitrate. A common precursor to many explosives, including gunpowder."
	icon = 'icons/obj/mining.dmi'
	icon_state = "ore_saltpeter"
	filling_color = "#FEFCED"
	New()
		..()
		reagents.add_reagent("potassium", 3)

/obj/item/weapon/reagent_containers/food/snacks/coal
	name = "mineral coal"
	desc = "A bunch of mineral coal. Very dense."
	icon = 'icons/obj/mining.dmi'
	icon_state = "ore_coal"
	filling_color = "#271F22"
	New()
		..()
		reagents.add_reagent("carbon", 3)
/obj/item/weapon/reagent_containers/food/snacks/sulphur
	name = "sulphur"
	desc = "Yellow and smelly."
	icon = 'icons/obj/mining.dmi'
	icon_state = "ore_sulphur"
	filling_color = "#F5E44C"
	New()
		..()
		reagents.add_reagent("sulfur", 3)