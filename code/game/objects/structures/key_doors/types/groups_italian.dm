// all italians
#define ITALIAN_CODE 995 * 3
/datum/keyslot/italian
	code = ITALIAN_CODE

/obj/item/weapon/key/italian
	code = ITALIAN_CODE
	name = "General Access Key"

/obj/structure/simple_door/key_door/italian
	keyslot_type = /datum/keyslot/italian
	unique_door_name = "General Access"
#undef ITALIAN_CODE
/*
// all italian SOLDAT
#define ITALIAN_SOLDAT_CODE 900
/datum/keyslot/italian/soldat
	code = ITALIAN_SOLDAT_CODE

/obj/item/weapon/key/italian/soldat
	code = ITALIAN_SOLDAT_CODE
	name = "Soldier Access Key"

/obj/structure/simple_door/key_door/italian/soldat
	keyslot_type = /datum/keyslot/italian/soldat
	unique_door_name = "Soldier Access"
#undef ITALIAN_SOLDAT_CODE*/
// medics
#define ITALIAN_MEDIC_CODE 901
/datum/keyslot/italian/medic
	code = ITALIAN_MEDIC_CODE

/obj/item/weapon/key/italian/medic
	code = ITALIAN_MEDIC_CODE
	name = "Medical Access Key"

/obj/structure/simple_door/key_door/italian/medic
	keyslot_type = /datum/keyslot/italian/medic
	unique_door_name = "Medical Supplies"
#undef ITALIAN_MEDIC_CODE
// engineering
#define ITALIAN_ENGINEER_CODE 902
/datum/keyslot/italian/engineer
	code = ITALIAN_ENGINEER_CODE

/obj/item/weapon/key/italian/engineer
	code = ITALIAN_ENGINEER_CODE
	name = "Engineering Access Key"

/obj/structure/simple_door/key_door/italian/engineer
	keyslot_type = /datum/keyslot/italian/engineer
	unique_door_name = "Engineering"
#undef ITALIAN_ENGINEER_CODE
// train
#define ITALIAN_TRAIN_CODE 902
/datum/keyslot/italian/train
	code = ITALIAN_TRAIN_CODE

/obj/item/weapon/key/italian/train
	code = ITALIAN_TRAIN_CODE
	name = "Train Control Access Key"

/obj/structure/simple_door/key_door/italian/train
	keyslot_type = /datum/keyslot/italian/train
	unique_door_name = "Train Control"
#undef ITALIAN_TRAIN_CODE
// the italian quartermaster
#define ITALIAN_QM_CODE 997
/datum/keyslot/italian/QM
	code = ITALIAN_QM_CODE

/obj/item/weapon/key/italian/QM
	code = ITALIAN_QM_CODE
	name = "Supply Access Key"

/obj/structure/simple_door/key_door/italian/QM
	keyslot_type = /datum/keyslot/italian/QM
	unique_door_name = "Cargo"
#undef ITALIAN_QM_CODE
// all intermediate command
#define ITALIAN_INTER_COMMAND_CODE 999
/datum/keyslot/italian/command_intermediate
	code = ITALIAN_INTER_COMMAND_CODE

/obj/item/weapon/key/italian/command_intermediate
	code = ITALIAN_INTER_COMMAND_CODE
	name = "Intermediate Command Access Key"

/obj/structure/simple_door/key_door/italian/command_intermediate
	keyslot_type = /datum/keyslot/italian/command_intermediate
	unique_door_name = "Intermediate Command Access"
#undef ITALIAN_INTER_COMMAND_CODE
// all high (and above) command
#define ITALIAN_HIGH_COMMAND_CODE 1000
/datum/keyslot/italian/command_high
	code = ITALIAN_HIGH_COMMAND_CODE

/obj/item/weapon/key/italian/command_high
	code = ITALIAN_HIGH_COMMAND_CODE
	name = "High Command Access Key"

/obj/structure/simple_door/key_door/italian/command_high
	keyslot_type = /datum/keyslot/italian/command_high
	unique_door_name = "High Command Access"
#undef ITALIAN_HIGH_COMMAND_CODE