// ores
/obj/item/stack/ore
	name = "ore"
	icon = 'icons/obj/mining.dmi'
	icon_state = "ore2"
	w_class = 2
	amount = 1
	max_amount = 20

/obj/item/stack/ore/New()
	pixel_x = rand(0,16)-8
	pixel_y = rand(0,8)-8

/obj/item/stack/ore/iron
	name = "iron ore"
	icon_state = "ore_iron"

/obj/item/stack/ore/coal
	name = "mineral coal"
	icon_state = "ore_coal"

/obj/item/stack/ore/glass
	name = "sand"
	icon_state = "ore_glass"
	slot_flags = SLOT_HOLSTER

/obj/item/stack/ore/silver
	name = "silver ore"
	icon_state = "ore_silver"

/obj/item/stack/ore/gold
	name = "gold ore"
	icon_state = "ore_gold"

/obj/item/stack/ore/copper
	name = "copper ore"
	icon_state = "ore_copper"

/obj/item/stack/ore/tin
	name = "tin ore"
	icon_state = "ore_tin"

/obj/item/stack/ore/diamond
	name = "diamonds"
	icon_state = "ore_diamond"


/obj/item/stack/ore/saltpeter
	name = "saltpeter rock"
	desc = "A yellowish cristal, consisting of potassium nitrate. A common precursor to many explosives, including gunpowder."
	icon_state = "ore_saltpeter"
	singular_name = "rock"

/obj/item/stack/ore/coal
	name = "mineral coal"
	desc = "A bunch of mineral coal. Very dense."
	icon_state = "ore_coal"
	singular_name = "rock"

/obj/item/stack/ore/sulphur
	name = "sulphur rock"
	desc = "Yellow and smelly."
	icon_state = "ore_sulphur"
	singular_name = "rock"
