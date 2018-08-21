////////1713 stuff//////////
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


// all allies
#define ALLIED_CODE 995 * 4
/datum/keyslot/allied
	code = ALLIED_CODE

/obj/item/weapon/key/allied
	code = ALLIED_CODE
	name = "General Access Key"

/obj/structure/simple_door/key_door/allied
	keyslot_type = /datum/keyslot/allied
	unique_door_name = "General Access"
#undef ALLIED_CODE
// medics
#define ALLIED_MEDIC_CODE 901 * 4
/datum/keyslot/allied/medic
	code = ALLIED_MEDIC_CODE

/obj/item/weapon/key/allied/medic
	code = ALLIED_MEDIC_CODE
	name = "Medical Access Key"

/obj/structure/simple_door/key_door/allied/medic
	keyslot_type = /datum/keyslot/allied/medic
	unique_door_name = "Medical Supplies"
#undef ALLIED_MEDIC_CODE
// engineering
#define ALLIED_ENGINEER_CODE 902 * 4
/datum/keyslot/allied/engineer
	code = ALLIED_ENGINEER_CODE

/obj/item/weapon/key/allied/engineer
	code = ALLIED_ENGINEER_CODE
	name = "Engineering Access Key"

/obj/structure/simple_door/key_door/allied/engineer
	keyslot_type = /datum/keyslot/allied/engineer
	unique_door_name = "Engineering"
#undef ALLIED_ENGINEER_CODE
// train
#define ALLIED_TRAIN_CODE 902
/datum/keyslot/allied/train
	code = ALLIED_TRAIN_CODE

/obj/item/weapon/key/allied/train
	code = ALLIED_TRAIN_CODE
	name = "Train Control Access Key"

/obj/structure/simple_door/key_door/allied/train
	keyslot_type = /datum/keyslot/allied/train
	unique_door_name = "Train Control"
#undef ALLIED_TRAIN_CODE
// the allied quartermaster
#define ALLIED_QM_CODE 997 * 4
/datum/keyslot/allied/QM
	code = ALLIED_QM_CODE

/obj/item/weapon/key/allied/QM
	code = ALLIED_QM_CODE
	name = "Supply Access Key"

/obj/structure/simple_door/key_door/allied/QM
	keyslot_type = /datum/keyslot/allied/QM
	unique_door_name = "Cargo"
#undef ALLIED_QM_CODE
// all intermediate command
#define ALLIED_INTER_COMMAND_CODE 999 * 4
/datum/keyslot/allied/command_intermediate
	code = ALLIED_INTER_COMMAND_CODE

/obj/item/weapon/key/allied/command_intermediate
	code = ALLIED_INTER_COMMAND_CODE
	name = "Intermediate Command Access Key"

/obj/structure/simple_door/key_door/allied/command_intermediate
	keyslot_type = /datum/keyslot/allied/command_intermediate
	unique_door_name = "Intermediate Command Access"
#undef ALLIED_INTER_COMMAND_CODE
// all high (and above) command
#define ALLIED_HIGH_COMMAND_CODE 1000 * 4
/datum/keyslot/allied/command_high
	code = ALLIED_HIGH_COMMAND_CODE

/obj/item/weapon/key/allied/command_high
	code = ALLIED_HIGH_COMMAND_CODE
	name = "High Command Access Key"

/obj/structure/simple_door/key_door/allied/command_high
	keyslot_type = /datum/keyslot/allied/command_high
	unique_door_name = "High Command Access"
#undef ALLIED_HIGH_COMMAND_CODE