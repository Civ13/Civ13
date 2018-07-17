// not locked at all - no key, of course
#define ANYONE_CODE 995 * 3
/datum/keyslot/anyone
	code = -1

/obj/structure/simple_door/key_door/anyone
	keyslot_type = /datum/keyslot/anyone

/obj/structure/simple_door/key_door/anyone/wood
	material = "wood"

/obj/structure/simple_door/key_door/anyone/train
	material = "morgue"

/obj/structure/simple_door/key_door/anyone/train/New()
	..()
	name = "Train Door"

/obj/structure/simple_door/key_door/anyone/cell
	material = "cell"

#undef ANYONE_CODE

