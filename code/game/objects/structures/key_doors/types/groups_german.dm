// all germans
#define GERMAN_CODE 995
/datum/keyslot/german
	code = GERMAN_CODE

/obj/item/weapon/key/german
	code = GERMAN_CODE
	name = "General Access Key"

/obj/structure/simple_door/key_door/german
	keyslot_type = /datum/keyslot/german
	unique_door_name = "General Access"
#undef GERMAN_CODE
/*
// all german SOLDAT
#define GERMAN_SOLDAT_CODE 900
/datum/keyslot/german/soldat
	code = GERMAN_SOLDAT_CODE

/obj/item/weapon/key/german/soldat
	code = GERMAN_SOLDAT_CODE
	name = "Soldier Access Key"

/obj/structure/simple_door/key_door/german/soldat
	keyslot_type = /datum/keyslot/german/soldat
	unique_door_name = "Soldier Access"
#undef GERMAN_SOLDAT_CODE*/
// medics
#define GERMAN_MEDIC_CODE 901
/datum/keyslot/german/medic
	code = GERMAN_MEDIC_CODE

/obj/item/weapon/key/german/medic
	code = GERMAN_MEDIC_CODE
	name = "Medical Access Key"

/obj/structure/simple_door/key_door/german/medic
	keyslot_type = /datum/keyslot/german/medic
	unique_door_name = "Medical Supplies"
#undef GERMAN_MEDIC_CODE
// engineering
#define GERMAN_ENGINEER_CODE 902
/datum/keyslot/german/engineer
	code = GERMAN_ENGINEER_CODE

/obj/item/weapon/key/german/engineer
	code = GERMAN_ENGINEER_CODE
	name = "Engineering Access Key"

/obj/structure/simple_door/key_door/german/engineer
	keyslot_type = /datum/keyslot/german/engineer
	unique_door_name = "Engineering"
#undef GERMAN_ENGINEER_CODE
// train
#define GERMAN_TRAIN_CODE 902
/datum/keyslot/german/train
	code = GERMAN_TRAIN_CODE

/obj/item/weapon/key/german/train
	code = GERMAN_TRAIN_CODE
	name = "Train Control Access Key"

/obj/structure/simple_door/key_door/german/train
	keyslot_type = /datum/keyslot/german/train
	unique_door_name = "Train Control"
#undef GERMAN_TRAIN_CODE
// the german quartermaster
#define GERMAN_QM_CODE 997
/datum/keyslot/german/QM
	code = GERMAN_QM_CODE

/obj/item/weapon/key/german/QM
	code = GERMAN_QM_CODE
	name = "Supply Access Key"

/obj/structure/simple_door/key_door/german/QM
	keyslot_type = /datum/keyslot/german/QM
	unique_door_name = "Cargo"
#undef GERMAN_QM_CODE
// all intermediate command
#define GERMAN_INTER_COMMAND_CODE 999
/datum/keyslot/german/command_intermediate
	code = GERMAN_INTER_COMMAND_CODE

/obj/item/weapon/key/german/command_intermediate
	code = GERMAN_INTER_COMMAND_CODE
	name = "Intermediate Command Access Key"

/obj/structure/simple_door/key_door/german/command_intermediate
	keyslot_type = /datum/keyslot/german/command_intermediate
	unique_door_name = "Intermediate Command Access"
#undef GERMAN_INTER_COMMAND_CODE
// all high (and above) command
#define GERMAN_HIGH_COMMAND_CODE 1000
/datum/keyslot/german/command_high
	code = GERMAN_HIGH_COMMAND_CODE

/obj/item/weapon/key/german/command_high
	code = GERMAN_HIGH_COMMAND_CODE
	name = "High Command Access Key"

/obj/structure/simple_door/key_door/german/command_high
	keyslot_type = /datum/keyslot/german/command_high
	unique_door_name = "High Command Access"
#undef GERMAN_HIGH_COMMAND_CODE
// SS only
#define GERMAN_SS_CODE 1001
/datum/keyslot/german/SS
	code = GERMAN_SS_CODE

/obj/item/weapon/key/german/SS
	code = GERMAN_SS_CODE
	name = "SS-Schutze Access Key"

/obj/structure/simple_door/key_door/german/SS
	keyslot_type = /datum/keyslot/german/SS
	unique_door_name = "SS-Schutze Access"
#undef GERMAN_SS_CODE