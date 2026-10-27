/* File reserved for custom types other than the default metal door that starts locked on /obj/structure/simple_door/key_door/custom */

/obj/structure/simple_door/key_door/custom/doubledoor
	name = "large double"
	material = "wood"
	desc = "A large set of improper doors, it has a lock. if you can see this, report this to a developer."
	unique_door_name = "doubledoor"
	icon = 'icons/obj/doors/material_doors_fwoosh.dmi'
	health = 200

/obj/structure/simple_door/key_door/custom/doubledoor/bone //for tribes
	name = "large bone double"
	material = "bone"
	desc = "A large set of bone doors, it has a lock."

/obj/structure/simple_door/key_door/custom/doubledoor/marble //psuedo-material
	name = "large marble double"
	material = "marble"
	desc = "A large set of marble doors, it has a lock."

/obj/structure/simple_door/key_door/custom/doubledoor/stone
	name = "large stone double"
	material = "stone"
	desc = "A large set of stone doors, it has a lock."

/obj/structure/simple_door/key_door/custom/doubledoor/sandstone
	name = "large sandstone double"
	material = "sandstone"
	desc = "A large set of sandstone doors, it has a lock."

/obj/structure/simple_door/key_door/custom/doubledoor/tin
	name = "large tin double"
	material = "tin"
	health = 150
	desc = "A large set of tin doors, it has a lock. With enough effort they could be soon broken through."

/obj/structure/simple_door/key_door/custom/doubledoor/lead
	name = "large lead double"
	material = "lead"
	desc = "A large set of lead doors, it has a lock."

/obj/structure/simple_door/key_door/custom/doubledoor/copper
	name = "large copper double"
	material = "copper"
	desc = "A large set of copper doors, it has a lock."

/obj/structure/simple_door/key_door/custom/doubledoor/bronze
	name = "large bronze double"
	material = "bronze"
	health = 250
	desc = "A large set of well built and sturdy bronze doors, it has a lock."

/obj/structure/simple_door/key_door/custom/doubledoor/iron
	name = "large iron double"
	material = "iron"
	health = 300
	desc = "A large set of strong iron doors, it has a lock."

/obj/structure/simple_door/key_door/custom/doubledoor/steel
	name = "large reinforced steel double"
	material = "steel"
	health = 400
	desc = "A large set of reinforced steel doors, it has a lock."
	breachable = FALSE

/obj/structure/simple_door/key_door/custom/doubledoor/silver
	name = "large silver double"
	material = "silver"
	desc = "A large set of shimmering silver doors, it has a lock."
	breachable = FALSE

/obj/structure/simple_door/key_door/custom/doubledoor/gold
	name = "large gold double"
	material = "gold"
	desc = "A large set of glimmering gold doors, it has a lock."

/obj/structure/simple_door/key_door/custom/singledoor/New(var/newloc,var/material_name)
	..(newloc, "wood")
	name = "improper single door"
	icon = 'icons/obj/doors/material_doors_fwoosh.dmi'
	basic_icon = "private"
	icon_state = "private"
	desc = "If you can see this door please report it to a developer"
	override_material = TRUE

/obj/structure/simple_door/key_door/custom/singledoor/privacy/New(var/newloc,var/material_name)
	..(newloc, "wood")
	name = "wooden privacy door"
	desc = "A wood paneled privacy door, it has a locking mechanism"
	health = 250
	override_material = FALSE
	override_opacity = TRUE
	opacity = FALSE
