// not locked at all - no key, of course
#define ANYONE_CODE 995 * 3
/datum/keyslot/anyone
	code = -1

/obj/structure/simple_door/key_door/anyone
	keyslot_type = /datum/keyslot/anyone

/obj/structure/simple_door/key_door/anyone/wood
	material = "wood"
	health = 150

/obj/structure/simple_door/key_door/anyone/shoji
	material = "paper"
	unique_door_name = "shoji"

/* See key_door.dm for relevant information about shoji ^, as the code is partitioned*/

/obj/structure/simple_door/key_door/anyone/rustic
	material = "log"
	unique_door_name = "rustic"
	health = 100

/obj/structure/simple_door/key_door/anyone/nordic
	material = "log"
	name = "nordic"
	unique_door_name = "nordic"
	icon_state = "nordic"
	override_material = TRUE
	health = 150

/obj/structure/simple_door/key_door/anyone/aztec
	material = "wood"
	name = "aztec"
	unique_door_name = "aztec"
	icon_state = "aztec"
	override_material = TRUE
	health = 150

/obj/structure/simple_door/key_door/anyone/roman
	material = "stone"
	name = "roman"
	unique_door_name = "roman"
	icon_state = "roman"
	override_material = TRUE
	health = 200

/obj/structure/simple_door/key_door/anyone/blast
	material = "steel"
	name = "Blast Door"
	unique_door_name = "Blast door"
	icon_state = "blast"
	health = 500

/obj/structure/simple_door/key_door/anyone/doubledoor
	material = null
	name = "large double"
	desc = "A large set of improper doors. if you can see this, report this to a developer."
	unique_door_name = "doubledoor"
	icon = 'icons/obj/doors/material_doors_fwoosh.dmi'
	health = 200

/obj/structure/simple_door/key_door/anyone/doubledoor/wood
	name = "large wood double"
	material = "wood"
	desc = "A large set of wood doors. With enough effort they could be soon broken through."
	health = 150

/obj/structure/simple_door/key_door/anyone/doubledoor/bamboo
	name = "large bamboo double"
	material = "bamboo"
	desc = "A large set of bamboo doors. With enough effort they could be soon broken through."
	health = 150

/obj/structure/simple_door/key_door/anyone/doubledoor/bone //for tribes
	name = "large bone double"
	material = "bone"
	desc = "A large set of bone doors."

/obj/structure/simple_door/key_door/anyone/doubledoor/marble
	name = "large marble double"
	material = "marble"
	desc = "A large set of marble doors."

/obj/structure/simple_door/key_door/anyone/doubledoor/stone
	name = "large stone double"
	material = "stone"
	desc = "A large set of stone doors."

/obj/structure/simple_door/key_door/anyone/doubledoor/sandstone
	name = "large stone double"
	material = "sandstone"
	desc = "A large set of sandstone doors."

/obj/structure/simple_door/key_door/anyone/doubledoor/tin
	name = "large tin double"
	material = "tin"
	health = 150
	desc = "A large set of tin doors. With enough effort they could be soon broken through."

/obj/structure/simple_door/key_door/anyone/doubledoor/lead
	name = "large lead double"
	material = "lead"
	desc = "A large set of lead doors."

/obj/structure/simple_door/key_door/anyone/doubledoor/copper
	name = "large copper double"
	material = "copper"
	desc = "A large set of copper doors."

/obj/structure/simple_door/key_door/anyone/doubledoor/bronze
	name = "large bronze double"
	material = "bronze"
	health = 250
	desc = "A large set of well built and sturdy bronze doors."

/obj/structure/simple_door/key_door/anyone/doubledoor/iron
	name = "large iron double"
	material = "iron"
	health = 300
	desc = "A large set of strong iron doors."

/obj/structure/simple_door/key_door/anyone/doubledoor/steel
	name = "large reinforced steel double"
	material = "steel"
	health = 400
	desc = "A large set of reinforced steel doors."

/obj/structure/simple_door/key_door/anyone/doubledoor/steel/store_door
	name = "large steel double store"
	health = 200
	desc = "A large store steel and glass double door."
	icon = 'icons/obj/doors/material_doors.dmi'
	basic_icon = "storedoor"
	icon_state = "storedoor"
	override_material = TRUE
	override_opacity = TRUE
	opacity = 0
	initial_opacity = 0

/obj/structure/simple_door/key_door/anyone/doubledoor/silver
	name = "large silver double"
	material = "silver"
	desc = "A large set of shimmering silver doors."

/obj/structure/simple_door/key_door/anyone/doubledoor/gold
	name = "large gold double"
	material = "gold"
	desc = "A large set of glimmering gold doors."

/obj/structure/simple_door/key_door/anyone/singledoor/New(var/newloc,var/material_name)
	..(newloc, "wood")
	name = "improper single door"
	desc = "If you can see this door please report it to a developer"
	health = 250

/obj/structure/simple_door/key_door/anyone/singledoor/privacy/New(var/newloc,var/material_name)
	..(newloc, "wood")
	name = "wooden privacy door"
	icon = 'icons/obj/doors/material_doors_fwoosh.dmi'
	basic_icon = "private"
	icon_state = "private"
	desc = "A wood paneled privacy door."
	override_material = FALSE

/obj/structure/simple_door/key_door/anyone/singledoor/housedoor/New(var/newloc,var/material_name)
	..(newloc, "wood")
	name = "wooden house door"
	icon = 'icons/obj/doors/material_doors_fwoosh.dmi'
	basic_icon = "housedoor"
	icon_state = "housedoor"
	desc = "A wood paneled house door with seethrough windows."
	override_material = FALSE
	override_opacity = TRUE
	opacity = FALSE

/obj/structure/simple_door/key_door/anyone/ship
	material = "log"
	health = 150
/obj/structure/simple_door/key_door/anyone/ship/New(var/newloc,var/material_name)
	..(newloc, "wood")
	name = "wooden ship door"
	icon = 'icons/obj/doors/material_doors_leonister.dmi'
	basic_icon = "ship"
	icon_state = "ship"
	desc = "A wood round ship door"
	override_material = TRUE

#undef ANYONE_CODE

