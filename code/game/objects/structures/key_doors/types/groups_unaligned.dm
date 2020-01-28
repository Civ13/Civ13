// not locked at all - no key, of course
#define ANYONE_CODE 995 * 3
/datum/keyslot/anyone
	code = -1

/obj/structure/simple_door/key_door/anyone
	keyslot_type = /datum/keyslot/anyone

/obj/structure/simple_door/key_door/anyone/wood
	material = "wood"

/obj/structure/simple_door/key_door/anyone/shoji
	material = "paper"
	unique_door_name = "shoji"

/obj/structure/simple_door/key_door/anyone/rustic
	material = "log"
	unique_door_name = "rustic"

/obj/structure/simple_door/key_door/anyone/nordic
	material = "log"
	name = "nordic"
	unique_door_name = "nordic"
	icon_state = "nordic"
	override_material = TRUE

/obj/structure/simple_door/key_door/anyone/aztec
	material = "wood"
	name = "aztec"
	unique_door_name = "aztec"
	icon_state = "aztec"
	override_material = TRUE

/obj/structure/simple_door/key_door/anyone/roman
	material = "stone"
	name = "roman"
	unique_door_name = "roman"
	icon_state = "roman"
	override_material = TRUE

/obj/structure/simple_door/key_door/anyone/blast
	material = "steel"
	name = "Blast Door"
	unique_door_name = "Blast door"
	icon_state = "blast"

#undef ANYONE_CODE

