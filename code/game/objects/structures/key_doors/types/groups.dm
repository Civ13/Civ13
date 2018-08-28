////////1713 stuff//////////
#define CV_CODE 1000
/datum/keyslot/civ
	code = CV_CODE

/obj/item/weapon/key/civ
	code = CV_CODE
	name = "Key"

/obj/structure/simple_door/key_door/civ
	keyslot_type = /datum/keyslot/civ
	unique_door_name = "Locked"
#undef CV_CODE
#define CV_CODE2 1546
/datum/keyslot/civ/hall
	code = CV_CODE2

/obj/item/weapon/key/civ/hall
	code = CV_CODE2
	name = "Colony Hall Key"

/obj/structure/simple_door/key_door/civ/hall
	keyslot_type = /datum/keyslot/civ/hall
	unique_door_name = "Colony Hall"
#undef CV_CODE2
#define CV_CODE3 1311
/datum/keyslot/civ/gov
	code = CV_CODE3

/obj/item/weapon/key/civ/gov
	code = CV_CODE3
	name = "Governor's Office Key"

/obj/structure/simple_door/key_door/civ/gov
	keyslot_type = /datum/keyslot/civ/gov
	unique_door_name = "Governor's Office"
#undef CV_CODE3
#define PI_CODE 995
/datum/keyslot/pirates
	code = PI_CODE

/obj/item/weapon/key/pirates
	code = PI_CODE
	name = "Pirate key"

/obj/structure/simple_door/key_door/pirates
	keyslot_type = /datum/keyslot/pirates
	unique_door_name = "Pirate locked"
#undef PI_CODE

#define RN_CODE 995 * 2
/datum/keyslot/british
	code = RN_CODE

/obj/item/weapon/key/british
	code = RN_CODE
	name = "British key"

/obj/structure/simple_door/key_door/british
	keyslot_type = /datum/keyslot/british
	unique_door_name = "British locked"
#undef RN_CODE

#define SP_CODE 995 * 3
/datum/keyslot/spanish
	code = SP_CODE

/obj/item/weapon/key/spanish
	code = SP_CODE
	name = "Spanish Key"

/obj/structure/simple_door/key_door/spanish
	keyslot_type = /datum/keyslot/spanish
	unique_door_name = "Spanish locked"
#undef SP_CODE

#define FR_CODE 995 * 4
/datum/keyslot/french
	code = FR_CODE

/obj/item/weapon/key/french
	code = FR_CODE
	name = "French key"

/obj/structure/simple_door/key_door/french
	keyslot_type = /datum/keyslot/french
	unique_door_name = "French locked"
#undef FR_CODE

#define PT_CODE 995 * 5
/datum/keyslot/portuguese
	code = PT_CODE

/obj/item/weapon/key/portuguese
	code = PT_CODE
	name = "Portuguese key"

/obj/structure/simple_door/key_door/portuguese
	keyslot_type = /datum/keyslot/portuguese
	unique_door_name = "Portuguese locked"
#undef PT_CODE

#define NL_CODE 995 * 6
/datum/keyslot/dutch
	code = NL_CODE

/obj/item/weapon/key/dutch
	code = NL_CODE
	name = "Dutch key"

/obj/structure/simple_door/key_door/dutch
	keyslot_type = /datum/keyslot/dutch
	unique_door_name = "Dutch locked"
#undef NL_CODE