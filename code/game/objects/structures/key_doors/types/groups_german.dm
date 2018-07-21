// all british
#define BRITISH_CODE 995
/datum/keyslot/german
	code = BRITISH_CODE

/obj/item/weapon/key/german
	code = BRITISH_CODE
	name = "General Access Key"

/obj/structure/simple_door/key_door/german
	keyslot_type = /datum/keyslot/german
	unique_door_name = "General Access"
#undef BRITISH_CODE
/*
// all german SOLDAT
#define BRITISH_SOLDAT_CODE 900
/datum/keyslot/german/soldat
	code = BRITISH_SOLDAT_CODE

/obj/item/weapon/key/german/soldat
	code = BRITISH_SOLDAT_CODE
	name = "Soldier Access Key"

/obj/structure/simple_door/key_door/german/soldat
	keyslot_type = /datum/keyslot/german/soldat
	unique_door_name = "Soldier Access"
#undef BRITISH_SOLDAT_CODE*/
// medics
#define BRITISH_MEDIC_CODE 901
/datum/keyslot/german/medic
	code = BRITISH_MEDIC_CODE

/obj/item/weapon/key/german/medic
	code = BRITISH_MEDIC_CODE
	name = "Medical Access Key"

/obj/structure/simple_door/key_door/german/medic
	keyslot_type = /datum/keyslot/german/medic
	unique_door_name = "Medical Supplies"
#undef BRITISH_MEDIC_CODE
// engineering
#define BRITISH_ENGINEER_CODE 902
/datum/keyslot/german/engineer
	code = BRITISH_ENGINEER_CODE

/obj/item/weapon/key/german/engineer
	code = BRITISH_ENGINEER_CODE
	name = "Engineering Access Key"

/obj/structure/simple_door/key_door/german/engineer
	keyslot_type = /datum/keyslot/german/engineer
	unique_door_name = "Engineering"
#undef BRITISH_ENGINEER_CODE
// train
#define BRITISH_TRAIN_CODE 902
/datum/keyslot/german/train
	code = BRITISH_TRAIN_CODE

/obj/item/weapon/key/german/train
	code = BRITISH_TRAIN_CODE
	name = "Train Control Access Key"

/obj/structure/simple_door/key_door/german/train
	keyslot_type = /datum/keyslot/german/train
	unique_door_name = "Train Control"
#undef BRITISH_TRAIN_CODE
// the german quartermaster
#define BRITISH_QM_CODE 997
/datum/keyslot/german/QM
	code = BRITISH_QM_CODE

/obj/item/weapon/key/german/QM
	code = BRITISH_QM_CODE
	name = "Supply Access Key"

/obj/structure/simple_door/key_door/german/QM
	keyslot_type = /datum/keyslot/german/QM
	unique_door_name = "Cargo"
#undef BRITISH_QM_CODE
// all intermediate command
#define BRITISH_INTER_COMMAND_CODE 999
/datum/keyslot/german/command_intermediate
	code = BRITISH_INTER_COMMAND_CODE

/obj/item/weapon/key/german/command_intermediate
	code = BRITISH_INTER_COMMAND_CODE
	name = "Intermediate Command Access Key"

/obj/structure/simple_door/key_door/german/command_intermediate
	keyslot_type = /datum/keyslot/german/command_intermediate
	unique_door_name = "Intermediate Command Access"
#undef BRITISH_INTER_COMMAND_CODE
// all high (and above) command
#define BRITISH_HIGH_COMMAND_CODE 1000
/datum/keyslot/german/command_high
	code = BRITISH_HIGH_COMMAND_CODE

/obj/item/weapon/key/german/command_high
	code = BRITISH_HIGH_COMMAND_CODE
	name = "High Command Access Key"

/obj/structure/simple_door/key_door/german/command_high
	keyslot_type = /datum/keyslot/german/command_high
	unique_door_name = "High Command Access"
#undef BRITISH_HIGH_COMMAND_CODE