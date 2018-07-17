// all japanese
#define JAPAN_CODE 995 * 5
/datum/keyslot/japan
	code = JAPAN_CODE

/obj/item/weapon/key/japan
	code = JAPAN_CODE
	name = "General Access Key"

/obj/structure/simple_door/key_door/japan
	keyslot_type = /datum/keyslot/japan
	unique_door_name = "General Access"
#undef JAPAN_CODE
// medics
#define JAPAN_MEDIC_CODE 901 * 5
/datum/keyslot/japan/medic
	code = JAPAN_MEDIC_CODE

/obj/item/weapon/key/japan/medic
	code = JAPAN_MEDIC_CODE
	name = "Medical Access Key"

/obj/structure/simple_door/key_door/japan/medic
	keyslot_type = /datum/keyslot/japan/medic
	unique_door_name = "Medical Supplies"
#undef JAPAN_MEDIC_CODE
// engineering
#define JAPAN_ENGINEER_CODE 902 * 5
/datum/keyslot/japan/engineer
	code = JAPAN_ENGINEER_CODE

/obj/item/weapon/key/japan/engineer
	code = JAPAN_ENGINEER_CODE
	name = "Engineering Access Key"

/obj/structure/simple_door/key_door/japan/engineer
	keyslot_type = /datum/keyslot/japan/engineer
	unique_door_name = "Engineering"
#undef JAPAN_ENGINEER_CODE
// train
#define JAPAN_TRAIN_CODE 902 * 5
/datum/keyslot/japan/train
	code = JAPAN_TRAIN_CODE

/obj/item/weapon/key/japan/train
	code = JAPAN_TRAIN_CODE
	name = "Train Control Access Key"

/obj/structure/simple_door/key_door/japan/train
	keyslot_type = /datum/keyslot/japan/train
	unique_door_name = "Train Control"
#undef JAPAN_TRAIN_CODE
// the japan quartermaster
#define JAPAN_QM_CODE 997 * 5
/datum/keyslot/japan/QM
	code = JAPAN_QM_CODE

/obj/item/weapon/key/japan/QM
	code = JAPAN_QM_CODE
	name = "Supply Access Key"

/obj/structure/simple_door/key_door/japan/QM
	keyslot_type = /datum/keyslot/japan/QM
	unique_door_name = "Cargo"
#undef JAPAN_QM_CODE
// all intermediate command
#define JAPAN_INTER_COMMAND_CODE 999 * 5
/datum/keyslot/japan/command_intermediate
	code = JAPAN_INTER_COMMAND_CODE

/obj/item/weapon/key/japan/command_intermediate
	code = JAPAN_INTER_COMMAND_CODE
	name = "Intermediate Command Access Key"

/obj/structure/simple_door/key_door/japan/command_intermediate
	keyslot_type = /datum/keyslot/japan/command_intermediate
	unique_door_name = "Intermediate Command Access"
#undef JAPAN_INTER_COMMAND_CODE
// all high (and above) command
#define JAPAN_HIGH_COMMAND_CODE 1000 * 5
/datum/keyslot/japan/command_high
	code = JAPAN_HIGH_COMMAND_CODE

/obj/item/weapon/key/japan/command_high
	code = JAPAN_HIGH_COMMAND_CODE
	name = "High Command Access Key"

/obj/structure/simple_door/key_door/japan/command_high
	keyslot_type = /datum/keyslot/japan/command_high
	unique_door_name = "High Command Access"
#undef JAPAN_HIGH_COMMAND_CODE