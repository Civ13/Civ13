/datum/job/civilian/starwars/rebel/lieutenant
	title = "Rebel Lieutenant"
	rank_abbreviation = ""
	allowed_maps = list(MAP_TANTIVEIV)

	spawn_location = "JoinLateJP"

	is_officer = TRUE
	whitelisted = TRUE
	is_commander = TRUE
	can_be_female = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/civilian/starwars/rebel/lieutenant/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_VERY_VERY_HIGH, "dexterity" = STAT_VERY_VERY_HIGH, "swords" = STAT_NORMAL, "pistol" = STAT_VERY_VERY_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_VERY_VERY_HIGH)
/datum/job/civilian/starwars/rebel/lieutenant/job_loadout = list(
	/obj/item/clothing/shoes/jackboots = slot_shoes,
	/obj/item/clothing/under/rebel/officer = slot_w_uniform,
	/obj/item/weapon/radio/walkietalkie/faction1/comlink = slot_wear_id,
	/obj/item/clothing/suit/storage/jacket/rebel_vest/officer = slot_wear_suit,
	/obj/item/weapon/gun/projectile/pistol/laser/westar34 = slot_l_hand,
	/obj/item/weapon/storage/belt/smallpouches/rebel = slot_belt,
	/obj/item/clothing/head/helmet/rebel = slot_head)
/datum/job/civilian/starwars/rebel/lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
//back
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	H.s_tone = rand(-35,-25)
	H.add_note("Role", "You are a <b>[title]</b>, lead the Rebel Alliance forced in the fight against the Extra-Galactic Empire!")
	apply_job_stats(H)
	return TRUE

/datum/job/civilian/starwars/rebel/doctor
	title = "Rebel Doctor"
	rank_abbreviation = ""
	can_be_female = TRUE
	spawn_location = "JoinLateJPDoc"
	allowed_maps = list(MAP_TANTIVEIV)

	is_medic = TRUE
	min_positions = 1
	max_positions = 2

/datum/job/civilian/starwars/rebel/doctor/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_MEDIUM_HIGH, "swords" = STAT_NORMAL, "pistol" = STAT_VERY_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MAX, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/civilian/starwars/rebel/doctor/job_loadout = list(
	/obj/item/clothing/shoes/jackboots = slot_shoes,
	/obj/item/clothing/under/rebel = slot_w_uniform,
	/obj/item/weapon/radio/walkietalkie/faction1/comlink = slot_wear_id,
	/obj/item/weapon/storage/firstaid/combat = slot_belt,
	/obj/item/weapon/storage/firstaid/adv = slot_back,
	/obj/item/clothing/suit/storage/jacket/doctor = slot_wear_suit,
	/obj/item/clothing/head/helmet/rebel = slot_head,
	/obj/item/weapon/gun/projectile/pistol/laser/dl44 = slot_l_hand)
/datum/job/civilian/starwars/rebel/doctor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	H.s_tone = rand(-35,-25)
	H.add_note("Role", "You are a <b>[title]</b>. Keep the Rebel Marines fighting on!")
	apply_job_stats(H)
	return TRUE

/datum/job/civilian/starwars/rebel/radio_technician
	title = "Rebel Radio Technician"
	rank_abbreviation = ""
	can_be_female = TRUE
	spawn_location = "JoinLateJP"
	allowed_maps = list(MAP_TANTIVEIV)

	can_be_female = TRUE
	uses_squads = TRUE
	min_positions = 1
	max_positions = 10

/datum/job/civilian/starwars/rebel/radio_technician/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_NORMAL, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_MEDIUM_HIGH, "swords" = STAT_NORMAL, "pistol" = STAT_VERY_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/civilian/starwars/rebel/radio_technician/job_loadout = list(
	/obj/item/clothing/shoes/jackboots = slot_shoes,
	/obj/item/clothing/under/rebel = slot_w_uniform,
	/obj/item/clothing/suit/storage/jacket/rebel_vest = slot_wear_suit,
	/obj/item/clothing/head/helmet/rebel = slot_head,
	/obj/item/weapon/radio/walkietalkie/faction1/comlink = slot_wear_id,
	/obj/item/weapon/radio/faction1/spaceradio = slot_back,
	/obj/item/weapon/gun/projectile/pistol/laser/dl44 = slot_l_hand,
	/obj/item/weapon/storage/belt/smallpouches/rebel = slot_belt)
/datum/job/civilian/starwars/rebel/radio_technician/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	//shoes
	equip_loadout(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	H.s_tone = rand(-35,-25)
	H.add_note("Role", "You are a <b>[title]</b>. Keep the Rebel forces informed and updated!")
	apply_job_stats(H)
	return TRUE

/datum/job/civilian/starwars/rebel/sergeant
	title = "Rebel Marine Squad Leader"
	rank_abbreviation = ""
	can_be_female = TRUE
	spawn_location = "JoinLateJP"
	allowed_maps = list(MAP_TANTIVEIV)

	uses_squads = TRUE
	is_squad_leader = TRUE
	min_positions = 4
	max_positions = 8

/datum/job/civilian/starwars/rebel/sergeant/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_HIGH, "dexterity" = STAT_HIGH, "swords" = STAT_NORMAL, "pistol" = STAT_VERY_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_MEDIUM_HIGH, "stamina" = STAT_VERY_HIGH)
/datum/job/civilian/starwars/rebel/sergeant/job_loadout = list(
	/obj/item/clothing/shoes/jackboots = slot_shoes,
	/obj/item/clothing/under/rebel = slot_w_uniform,
	/obj/item/clothing/suit/storage/jacket/rebel_vest = slot_wear_suit,
	/obj/item/weapon/radio/walkietalkie/faction1/comlink = slot_wear_id,
	/obj/item/clothing/head/helmet/rebel = slot_head,
	/obj/item/weapon/gun/projectile/semiautomatic/laser/a280 = slot_shoulder,
	/obj/item/weapon/storage/belt/smallpouches/rebel = slot_belt,
	/obj/item/weapon/gun/projectile/pistol/laser/dl44 = slot_l_hand)
/datum/job/civilian/starwars/rebel/sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	H.add_note("Role", "You are a <b>[title]</b>, a sergeant in the Rebel Alliance, in charge of a squad. Lead your men and fight against the Extra-Galactic Empire!")
	H.add_note("Partisan Mechanics", "- Press <b>C</b> to place a booby trap while holding a thermal detonator.")
	apply_job_stats(H)
	return TRUE

/datum/job/civilian/starwars/rebel/soldierheavy
	title = "Heavy Rebel"
	rank_abbreviation = ""
	allowed_maps = list(MAP_TANTIVEIV)

	spawn_location = "JoinLateJP"
	can_be_female = TRUE
	uses_squads = TRUE
	min_positions = 1
	max_positions = 10

/datum/job/civilian/starwars/rebel/soldierheavy/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_MEDIUM_HIGH, "swords" = STAT_NORMAL, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_VERY_HIGH)
/datum/job/civilian/starwars/rebel/soldierheavy/job_loadout = list(
	/obj/item/clothing/shoes/jackboots = slot_shoes,
	/obj/item/clothing/under/rebel = slot_w_uniform,
	/obj/item/clothing/suit/storage/jacket/rebel_vest = slot_wear_suit,
	/obj/item/ammo_magazine/tibannagas/blaster_power_pack = slot_back,
	/obj/item/weapon/storage/belt/smallpouches/rebel = slot_belt,
	/obj/item/weapon/radio/walkietalkie/faction1/comlink = slot_wear_id,
	/obj/item/clothing/head/helmet/rebel = slot_head,
	/obj/item/weapon/gun/projectile/automatic/laser/z6/empire = slot_l_hand,
	/obj/item/weapon/grenade/modern/thermaldetonator = slot_r_store)
/datum/job/civilian/starwars/rebel/soldierheavy/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	//shoes
	equip_loadout(H)
	H.add_note("Role", "You are a <b>[title]</b>, a heavy soldier in the Rebel Army. Fight for the freedom of <b>the Galaxy</b>! Fight against the Galactic Empire!")
	apply_job_stats(H)
	return TRUE

/datum/job/civilian/starwars/rebel/soldier
	title = "Rebel Marine"
	rank_abbreviation = ""
	allowed_maps = list(MAP_TANTIVEIV)

	spawn_location = "JoinLateJP"
	can_be_female = TRUE
	uses_squads = TRUE
	min_positions = 24
	max_positions = 124

/datum/job/civilian/starwars/rebel/soldier/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_MEDIUM_HIGH, "swords" = STAT_NORMAL, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_MEDIUM_HIGH)
/datum/job/civilian/starwars/rebel/soldier/job_loadout = list(
	/obj/item/clothing/shoes/jackboots = slot_shoes,
	/obj/item/clothing/under/rebel = slot_w_uniform,
	/obj/item/clothing/suit/storage/jacket/rebel_vest = slot_wear_suit,
	/obj/item/weapon/storage/belt/smallpouches/rebel = slot_belt,
	/obj/item/weapon/radio/walkietalkie/faction1/comlink = slot_wear_id,
	/obj/item/clothing/head/helmet/rebel = slot_head)
/datum/job/civilian/starwars/rebel/soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	//shoes
	equip_loadout(H)
	if	(prob(80))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/laser/dh17(H), slot_l_hand)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/laser/a280(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/grenade/modern/thermaldetonator(H), slot_r_store)
	H.add_note("Role", "You are a <b>[title]</b>, a soldier in the Rebel Alliance. Fight for the freedom of <b>the Galaxy</b>! Fight against the Galactic Empire!")
	H.add_note("Partisan Mechanics", "- Press <b>C</b> to place a booby trap while holding a thermal detonator.")
	apply_job_stats(H)
	return TRUE


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////EXTRA-GALACTIC EMPIRE////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/datum/job/american/starwars/empire/lieutenant
	title = "Imperial Navy Lieutenant"
	rank_abbreviation = ""
	allowed_maps = list(MAP_TANTIVEIV)

	spawn_location = "JoinLateRUCap"

	is_officer = TRUE
	whitelisted = TRUE
	is_commander = TRUE
	can_be_female = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/american/starwars/empire/lieutenant/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_VERY_VERY_HIGH, "dexterity" = STAT_VERY_VERY_HIGH, "swords" = STAT_NORMAL, "pistol" = STAT_VERY_VERY_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_VERY_VERY_HIGH)
/datum/job/american/starwars/empire/lieutenant/job_loadout = list(
	/obj/item/clothing/shoes/jackboots = slot_shoes,
	/obj/item/clothing/under/navallieutenant = slot_w_uniform,
	/obj/item/weapon/gun/projectile/pistol/laser/westar34 = slot_l_hand,
	/obj/item/weapon/storage/belt/smallpouches/white/stormtroomper/basic = slot_belt,
	/obj/item/clothing/head/impofficercap = slot_head,
	/obj/item/weapon/radio/walkietalkie/faction2/comlink = slot_wear_id)
/datum/job/american/starwars/empire/lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
//back
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	H.s_tone = rand(-35,-25)
	H.add_note("Role", "You are a <b>[title]</b>, lead the Galactic Imperial Forces in the fight against the Rebel Alliance!")
	apply_job_stats(H)
	return TRUE

/datum/job/american/starwars/empire/doctor
	title = "Imperial Storm-Surgeon"
	rank_abbreviation = ""
	can_be_female = TRUE
	spawn_location = "JoinLateRUDoc"
	allowed_maps = list(MAP_TANTIVEIV)

	is_medic = TRUE
	min_positions = 1
	max_positions = 2

/datum/job/american/starwars/empire/doctor/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_MEDIUM_HIGH, "swords" = STAT_NORMAL, "pistol" = STAT_VERY_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MAX, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/american/starwars/empire/doctor/job_loadout = list(
	/obj/item/clothing/shoes/replicantshoes = slot_shoes,
	/obj/item/clothing/under/bodyglove = slot_w_uniform,
	/obj/item/clothing/gloves/replicantgloves = slot_gloves,
	/obj/item/weapon/radio/walkietalkie/faction2/comlink = slot_wear_id,
	/obj/item/weapon/gun/projectile/pistol/laser/dh17 = slot_l_hand,
	/obj/item/weapon/storage/firstaid/combat = slot_belt,
	/obj/item/weapon/storage/firstaid/adv = slot_back,
	/obj/item/clothing/suit/armor/stormsurgeon = slot_wear_suit,
	/obj/item/weapon/grenade/flashbang/galaxywars = slot_l_store,
	/obj/item/clothing/head/helmet/replicant/stormsurgeon = slot_head)
/datum/job/american/starwars/empire/doctor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	H.s_tone = rand(-35,-25)
	H.add_note("Role", "You are a <b>[title]</b>. Keep the Extra-Galactic Empire fighting on!")
	apply_job_stats(H)
	return TRUE

/datum/job/american/starwars/empire/technician
	title = "Shocktrooper Radio Technician"
	rank_abbreviation = ""
	can_be_female = TRUE
	spawn_location = "JoinLateRU"
	allowed_maps = list(MAP_TANTIVEIV)

	is_medic = FALSE
	can_be_female = TRUE
	min_positions = 1
	max_positions = 10

/datum/job/american/starwars/empire/technician/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_NORMAL, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_MEDIUM_HIGH, "swords" = STAT_NORMAL, "pistol" = STAT_VERY_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/american/starwars/empire/technician/job_loadout = list(
	/obj/item/clothing/shoes/replicantshoes = slot_shoes,
	/obj/item/clothing/under/bodyglove = slot_w_uniform,
	/obj/item/clothing/gloves/replicantgloves = slot_gloves,
	/obj/item/weapon/radio/galacticbattles = slot_back,
	/obj/item/clothing/suit/armor/stormradio = slot_wear_suit,
	/obj/item/weapon/radio/faction2/spaceradio = slot_back,
	/obj/item/clothing/head/helmet/replicant/stormradio = slot_head,
	/obj/item/weapon/gun/projectile/pistol/laser/dh17 = slot_l_hand,
	/obj/item/weapon/storage/belt/smallpouches/white/stormtroomper/flash = slot_belt,
	/obj/item/weapon/wrench = slot_l_store)
/datum/job/american/starwars/empire/technician/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	H.s_tone = rand(-35,-25)
	H.add_note("Role", "You are a <b>[title]</b>. Keep the Imperial Forces Informed and Updated!")
	apply_job_stats(H)
	return TRUE

/datum/job/american/starwars/empire/sergeant
	title = "Shocktrooper Sergeant"
	rank_abbreviation = ""
	can_be_female = TRUE
	spawn_location = "JoinLateRUSg"
	allowed_maps = list(MAP_TANTIVEIV)

	uses_squads = TRUE
	is_squad_leader = TRUE
	min_positions = 4
	max_positions = 8

/datum/job/american/starwars/empire/sergeant/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_HIGH, "dexterity" = STAT_HIGH, "swords" = STAT_NORMAL, "pistol" = STAT_VERY_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_MEDIUM_HIGH, "stamina" = STAT_VERY_HIGH)
/datum/job/american/starwars/empire/sergeant/job_loadout = list(
	/obj/item/clothing/shoes/replicantshoes = slot_shoes,
	/obj/item/clothing/under/bodyglove = slot_w_uniform,
	/obj/item/clothing/suit/armor/stormtrooper = slot_wear_suit,
	/obj/item/clothing/gloves/replicantgloves = slot_gloves,
	/obj/item/clothing/head/helmet/replicant/stormtrooper = slot_head,
	/obj/item/weapon/radio/walkietalkie/faction2/comlink = slot_wear_id)
/datum/job/american/starwars/empire/sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/replicant/stormtrooper(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/laser/dh17(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/laser/e11(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/white/stormtroomper/sgt(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	H.add_note("Role", "You are a <b>[title]</b>, in the Extra-Galactic Imperial Army, in charge of a squad. Lead your men and fight against the Rebel Alliance!")
	apply_job_stats(H)
	return TRUE


/datum/job/american/starwars/empire/soldierheavy
	title = "Heavy Shocktrooper"
	rank_abbreviation = ""
	allowed_maps = list(MAP_TANTIVEIV)

	spawn_location = "JoinLateRU"
	can_be_female = TRUE
	uses_squads = TRUE
	min_positions = 1
	max_positions = 10

/datum/job/american/starwars/empire/soldierheavy/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_MEDIUM_HIGH, "swords" = STAT_NORMAL, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_VERY_HIGH)
/datum/job/american/starwars/empire/soldierheavy/job_loadout = list(
	/obj/item/clothing/shoes/replicantshoes = slot_shoes,
	/obj/item/clothing/under/bodyglove = slot_w_uniform,
	/obj/item/clothing/suit/armor/stormtrooper = slot_wear_suit,
	/obj/item/clothing/gloves/replicantgloves = slot_gloves,
	/obj/item/ammo_magazine/tibannagas/blaster_power_pack = slot_back,
	/obj/item/weapon/radio/walkietalkie/faction2/comlink = slot_wear_id,
	/obj/item/clothing/head/helmet/replicant/stormtrooper = slot_head,
	/obj/item/weapon/gun/projectile/automatic/laser/z6/empire = slot_l_hand,
	/obj/item/weapon/grenade/flashbang/galaxywars = slot_r_store,
	/obj/item/weapon/storage/belt/smallpouches/white/stormtroomper/flash = slot_belt)
/datum/job/american/starwars/empire/soldierheavy/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	//shoes
	equip_loadout(H)
	H.add_note("Role", "You are a <b>[title]</b>, a soldier in the Extra-Galactic Imperial Army. Fight for the freedom of <b>the Galaxy</b>! Fight against the Rebel Alliance!")
	apply_job_stats(H)
	return TRUE

/datum/job/american/starwars/empire/soldier
	title = "Shocktrooper"
	rank_abbreviation = ""
	allowed_maps = list(MAP_TANTIVEIV)

	spawn_location = "JoinLateRU"
	can_be_female = TRUE
	uses_squads = TRUE
	min_positions = 24
	max_positions = 124

/datum/job/american/starwars/empire/soldier/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_MEDIUM_HIGH, "swords" = STAT_NORMAL, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_MEDIUM_HIGH)
/datum/job/american/starwars/empire/soldier/job_loadout = list(
	/obj/item/clothing/shoes/replicantshoes = slot_shoes,
	/obj/item/clothing/under/bodyglove = slot_w_uniform,
	/obj/item/clothing/suit/armor/stormtrooper = slot_wear_suit,
	/obj/item/clothing/gloves/replicantgloves = slot_gloves,
	/obj/item/weapon/radio/walkietalkie/faction2/comlink = slot_wear_id,
	/obj/item/clothing/head/helmet/replicant/stormtrooper = slot_head,
	/obj/item/weapon/gun/projectile/semiautomatic/laser/e11 = slot_l_hand,
	/obj/item/weapon/grenade/flashbang/galaxywars = slot_r_store,
	/obj/item/weapon/storage/belt/smallpouches/white/stormtroomper/basic = slot_belt)
/datum/job/american/starwars/empire/soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	//shoes
	equip_loadout(H)
	H.add_note("Role", "You are a <b>[title]</b>, a soldier in the Extra-Galactic Imperial Army. Fight for the freedom of <b>the Galaxy</b>! Fight against the Rebel Alliance!")
	apply_job_stats(H)
	return TRUE