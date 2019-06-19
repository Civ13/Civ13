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


#undef ANYONE_CODE

