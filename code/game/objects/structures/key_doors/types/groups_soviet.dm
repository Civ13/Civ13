// all pirates
#define pirates_CODE 995 * 2
/datum/keyslot/pirates
	code = pirates_CODE

/obj/item/weapon/key/pirates
	code = pirates_CODE
	name = "General Access Key"

/obj/structure/simple_door/key_door/pirates
	keyslot_type = /datum/keyslot/pirates
	unique_door_name = "General Access"
#undef pirates_CODE
/*
// all pirates SOLDAT
#define pirates_SOLDAT_CODE 900 * 2
/datum/keyslot/pirates/soldat
	code = pirates_SOLDAT_CODE

/obj/item/weapon/key/pirates/soldat
	code = pirates_SOLDAT_CODE
	name = "Soldier Access Key"

/obj/structure/simple_door/key_door/pirates/soldat
	keyslot_type = /datum/keyslot/pirates/soldat
	unique_door_name = "Soldier Access"
#undef pirates_SOLDAT_CODE*/
// medics
#define pirates_MEDIC_CODE 901 * 2
/datum/keyslot/pirates/medic
	code = pirates_MEDIC_CODE

/obj/item/weapon/key/pirates/medic
	code = pirates_MEDIC_CODE
	name = "Medical Access Key"

/obj/structure/simple_door/key_door/pirates/medic
	keyslot_type = /datum/keyslot/pirates/medic
	unique_door_name = "Medical Supplies"
#undef pirates_MEDIC_CODE
// engineering
#define pirates_ENGINEER_CODE 902 * 2
/datum/keyslot/pirates/engineer
	code = pirates_ENGINEER_CODE

/obj/item/weapon/key/pirates/engineer
	code = pirates_ENGINEER_CODE
	name = "Engineering Access Key"

/obj/structure/simple_door/key_door/pirates/engineer
	keyslot_type = /datum/keyslot/pirates/engineer
	unique_door_name = "Engineering"
#undef pirates_ENGINEER_CODE
// the pirates quartermaster
#define pirates_QM_CODE 997 * 2
/datum/keyslot/pirates/QM
	code = pirates_QM_CODE

/obj/item/weapon/key/pirates/QM
	code = pirates_QM_CODE
	name = "Supply Access Key"

/obj/structure/simple_door/key_door/pirates/QM
	keyslot_type = /datum/keyslot/pirates/QM
	unique_door_name = "Cargo"
#undef pirates_QM_CODE
// all intermediate (and above) command
#define pirates_INTER_COMMAND_CODE 999 * 2
/datum/keyslot/pirates/command_intermediate
	code = pirates_INTER_COMMAND_CODE

/obj/item/weapon/key/pirates/command_intermediate
	code = pirates_INTER_COMMAND_CODE
	name = "Intermediate Command Access Key"

/obj/structure/simple_door/key_door/pirates/command_intermediate
	keyslot_type = /datum/keyslot/pirates/command_intermediate
	unique_door_name = "Intermediate Command Access"
#undef pirates_INTER_COMMAND_CODE

// all high (and above) command
#define pirates_HIGH_COMMAND_CODE 1000 * 2
/datum/keyslot/pirates/command_high
	code = pirates_HIGH_COMMAND_CODE

/obj/item/weapon/key/pirates/command_high
	code = pirates_HIGH_COMMAND_CODE
	name = "High Command Access Key"

/obj/structure/simple_door/key_door/pirates/command_high
	keyslot_type = /datum/keyslot/pirates/command_high
	unique_door_name = "High Command Access"
#undef pirates_HIGH_COMMAND_CODE
// bunker doors
#define pirates_BUNKER_DOORS_CODE 1001 * 2
/datum/keyslot/pirates/bunker_doors
	code = pirates_BUNKER_DOORS_CODE

/obj/item/weapon/key/pirates/bunker_doors
	code = pirates_BUNKER_DOORS_CODE
	name = "Bunker Doors Access Key"

/obj/structure/simple_door/key_door/pirates/bunker_doors
	keyslot_type = /datum/keyslot/pirates/bunker_doors
	unique_door_name = "Bunker Doors Access"
	starts_open = 1
#undef pirates_BUNKER_DOORS_CODE