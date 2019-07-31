// ores
/obj/item/stack/ore
	name = "ore"
	icon = 'icons/obj/mining.dmi'
	icon_state = "ore2"
	w_class = 2
	amount = 1
	max_amount = 50
	value = 1
	var/radioactive = FALSE
	var/radioactive_amt = 0

/obj/item/stack/ore/New()
	pixel_x = rand(0,16)-8
	pixel_y = rand(0,8)-8
	process_radioactivity()

/obj/item/stack/ore/proc/process_radioactivity()
	if (!src || !radioactive || radioactive_amt <= 0)
		return
	if (!istype(loc, /obj/structure/closet/crate/lead)) //lead containers block radioactivity
		radiation_pulse(get_turf(src), 3, radioactive_amt, 10, FALSE) // 0.16 rads per second, should take 10 mins to reach 1 gray

	spawn(100)
		process_radioactivity()

/obj/item/stack/ore/iron
	name = "iron ore"
	icon_state = "ore_iron"

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

/obj/item/stack/ore/uranium
	name = "uranium ore"
	icon_state = "ore_uranium"
	radioactive = TRUE
	radioactive_amt = 7
	flammable = FALSE

/obj/item/stack/ore/saltpeter
	name = "saltpeter rock"
	desc = "A yellowish cristal, consisting of potassium nitrate. A common precursor to many explosives, including gunpowder."
	icon_state = "ore_saltpeter"
	singular_name = "rock"
	flammable = TRUE

/obj/item/stack/ore/coal
	name = "mineral coal"
	desc = "A bunch of mineral coal. Very dense."
	icon_state = "ore_coal"
	singular_name = "rock"
	flammable = TRUE

/obj/item/stack/ore/sulphur
	name = "sulphur rock"
	desc = "Yellow and smelly."
	icon_state = "ore_sulphur"
	singular_name = "rock"
	flammable = TRUE

/obj/item/stack/ore/lead
	name = "lead ore"
	desc = "A rock of very dense lead ore."
	icon_state = "ore_lead"
	singular_name = "rock"
	flammable = FALSE

/obj/item/stack/ore/mercury
	name = "cinnabar ore"
	desc = "A brownish-red rock of mercury sulfide."
	icon_state = "ore_mercury"
	singular_name = "rock"
	flammable = FALSE
	
/obj/item/stack/ore/fossilskull1
	name = "Fossils"
	desc = "An ancient fossil... must be from ages ago!"
	icon_state = "fossil_skull1"
	singular_name = "fossil"
	flammable = FALSE
	
/obj/item/stack/ore/fossilskull2
	name = "Fossils"
	desc = "An ancient fossil... must be from ages ago!"
	icon_state = "fossil_skull2"
	singular_name = "fossil"
	flammable = FALSE
	
/obj/item/stack/ore/fossilskull3
	name = "Fossils"
	desc = "An ancient fossil... must be from ages ago!"
	icon_state = "fossil_skull3"
	singular_name = "fossil"
	flammable = FALSE
	
/obj/item/stack/ore/fossilleaf1
	name = "Fossils"
	desc = "An ancient fossil... must be from ages ago!"
	icon_state = "fossil_leaf1"
	singular_name = "fossil"
	flammable = FALSE
	

/obj/item/stack/ore/fossilleaf2
	name = "Fossils"
	desc = "An ancient fossil... must be from ages ago!"
	icon_state = "fossil_leaf2"
	singular_name = "fossil"
	flammable = FALSE
	
/obj/item/stack/ore/fossilleaf3
	name = "Fossils"
	desc = "An ancient fossil... must be from ages ago!"
	icon_state = "fossil_leaf3"
	singular_name = "fossil"
	flammable = FALSE
	
/obj/item/stack/ore/fossilshell1
	name = "Fossils"
	desc = "An ancient fossil... must be from ages ago!"
	icon_state = "fossil_shell1"
	singular_name = "fossil"
	flammable = FALSE
	
/obj/item/stack/ore/fossilshell2
	name = "Fossils"
	desc = "An ancient fossil... must be from ages ago!"
	icon_state = "fossil_shell2"
	singular_name = "fossil"
	flammable = FALSE
	
/obj/item/stack/ore/fossilshell3
	name = "Fossils"
	desc = "An ancient fossil... must be from ages ago!"
	icon_state = "fossil_shell3"
	singular_name = "fossil"
	flammable = FALSE
	
/obj/item/stack/ore/fossilbone1
	name = "Fossils"
	desc = "An ancient fossil... must be from ages ago!"
	icon_state = "fossil_bone1"
	singular_name = "fossil"
	flammable = FALSE
