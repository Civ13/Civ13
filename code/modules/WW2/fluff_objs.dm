/* objects that don't actually do anything, used in a few areas on the map
 for flavor. It's mostly atmospherics stuff I removed - Kachnov */

/obj/structure/atmospherics_pipe_tank
	icon = 'icons/atmos/tank.dmi'
	icon_state = "examplemapstate_map"
/obj/structure/atmospherics_pipe_tank/New()
	..()
	icon_state = replacetext(icon_state, "_map", "")


/obj/structure/atmospherics_pipe_tank/oxygen
	name = "Pressure Tank (Oxygen)"
	icon_state = "o2_map"
/obj/structure/atmospherics_pipe_tank/nitrogen
	name = "Pressure Tank (Nitrogen)"
	icon_state = "n2_map"

// ores

/obj/item/weapon/ore
	name = "rock"
	icon = 'icons/obj/mining.dmi'
	icon_state = "ore2"
	w_class = 2

/obj/item/weapon/ore/uranium
	name = "pitchblende"
	icon_state = "ore_uranium"
//	origin_tech = list(TECH_MATERIAL = 5)

/obj/item/weapon/ore/iron
	name = "hematite"
	icon_state = "ore_iron"
//	origin_tech = list(TECH_MATERIAL = TRUE)

/obj/item/weapon/ore/coal
	name = "raw carbon"
	icon_state = "ore_coal"
//	origin_tech = list(TECH_MATERIAL = TRUE)

/obj/item/weapon/ore/glass
	name = "sand"
	icon_state = "ore_glass"
//	origin_tech = list(TECH_MATERIAL = TRUE)
	slot_flags = SLOT_HOLSTER

/obj/item/weapon/ore/plasma
	name = "plasma crystals"
	icon_state = "ore_plasma"
//	origin_tech = list(TECH_MATERIAL = 2)

/obj/item/weapon/ore/silver
	name = "native silver ore"
	icon_state = "ore_silver"
//	origin_tech = list(TECH_MATERIAL = 3)

/obj/item/weapon/ore/gold
	name = "native gold ore"
	icon_state = "ore_gold"
//	origin_tech = list(TECH_MATERIAL = 4)

/obj/item/weapon/ore/diamond
	name = "diamonds"
	icon_state = "ore_diamond"
//	origin_tech = list(TECH_MATERIAL = 6)

/obj/item/weapon/ore/osmium
	name = "raw platinum"
	icon_state = "ore_platinum"

/obj/item/weapon/ore/hydrogen
	name = "raw hydrogen"
	icon_state = "ore_hydrogen"

/obj/item/weapon/ore/slag
	name = "Slag"
	desc = "Someone screwed up..."
	icon_state = "slag"

/obj/item/weapon/ore/New()
	pixel_x = rand(0,16)-8
	pixel_y = rand(0,8)-8

// from mining/machine_processing.dm

/obj/structure/processing_unit_console
	name = "production machine console"
	icon = 'icons/obj/machines/mining_machines.dmi'
	icon_state = "console"
	density = TRUE
	anchored = TRUE
