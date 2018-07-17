// all soviets
#define soviet_CODE 995 * 2
/datum/keyslot/soviet
	code = soviet_CODE

/obj/item/weapon/key/soviet
	code = soviet_CODE
	name = "General Access Key"

/obj/structure/simple_door/key_door/soviet
	keyslot_type = /datum/keyslot/soviet
	unique_door_name = "General Access"
#undef soviet_CODE
/*
// all soviet SOLDAT
#define soviet_SOLDAT_CODE 900 * 2
/datum/keyslot/soviet/soldat
	code = soviet_SOLDAT_CODE

/obj/item/weapon/key/soviet/soldat
	code = soviet_SOLDAT_CODE
	name = "Soldier Access Key"

/obj/structure/simple_door/key_door/soviet/soldat
	keyslot_type = /datum/keyslot/soviet/soldat
	unique_door_name = "Soldier Access"
#undef soviet_SOLDAT_CODE*/
// medics
#define soviet_MEDIC_CODE 901 * 2
/datum/keyslot/soviet/medic
	code = soviet_MEDIC_CODE

/obj/item/weapon/key/soviet/medic
	code = soviet_MEDIC_CODE
	name = "Medical Access Key"

/obj/structure/simple_door/key_door/soviet/medic
	keyslot_type = /datum/keyslot/soviet/medic
	unique_door_name = "Medical Supplies"
#undef soviet_MEDIC_CODE
// engineering
#define soviet_ENGINEER_CODE 902 * 2
/datum/keyslot/soviet/engineer
	code = soviet_ENGINEER_CODE

/obj/item/weapon/key/soviet/engineer
	code = soviet_ENGINEER_CODE
	name = "Engineering Access Key"

/obj/structure/simple_door/key_door/soviet/engineer
	keyslot_type = /datum/keyslot/soviet/engineer
	unique_door_name = "Engineering"
#undef soviet_ENGINEER_CODE
// the soviet quartermaster
#define soviet_QM_CODE 997 * 2
/datum/keyslot/soviet/QM
	code = soviet_QM_CODE

/obj/item/weapon/key/soviet/QM
	code = soviet_QM_CODE
	name = "Supply Access Key"

/obj/structure/simple_door/key_door/soviet/QM
	keyslot_type = /datum/keyslot/soviet/QM
	unique_door_name = "Cargo"
#undef soviet_QM_CODE
// all intermediate (and above) command
#define soviet_INTER_COMMAND_CODE 999 * 2
/datum/keyslot/soviet/command_intermediate
	code = soviet_INTER_COMMAND_CODE

/obj/item/weapon/key/soviet/command_intermediate
	code = soviet_INTER_COMMAND_CODE
	name = "Intermediate Command Access Key"

/obj/structure/simple_door/key_door/soviet/command_intermediate
	keyslot_type = /datum/keyslot/soviet/command_intermediate
	unique_door_name = "Intermediate Command Access"
#undef soviet_INTER_COMMAND_CODE

// all high (and above) command
#define soviet_HIGH_COMMAND_CODE 1000 * 2
/datum/keyslot/soviet/command_high
	code = soviet_HIGH_COMMAND_CODE

/obj/item/weapon/key/soviet/command_high
	code = soviet_HIGH_COMMAND_CODE
	name = "High Command Access Key"

/obj/structure/simple_door/key_door/soviet/command_high
	keyslot_type = /datum/keyslot/soviet/command_high
	unique_door_name = "High Command Access"
#undef soviet_HIGH_COMMAND_CODE
// bunker doors
#define soviet_BUNKER_DOORS_CODE 1001 * 2
/datum/keyslot/soviet/bunker_doors
	code = soviet_BUNKER_DOORS_CODE

/obj/item/weapon/key/soviet/bunker_doors
	code = soviet_BUNKER_DOORS_CODE
	name = "Bunker Doors Access Key"

/obj/structure/simple_door/key_door/soviet/bunker_doors
	keyslot_type = /datum/keyslot/soviet/bunker_doors
	unique_door_name = "Bunker Doors Access"
	starts_open = 1
#undef soviet_BUNKER_DOORS_CODE