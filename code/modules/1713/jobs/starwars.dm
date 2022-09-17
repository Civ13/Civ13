/datum/job/civilian/starwars/rebel/lieutenant
	title = "Rebel Lieutenant"
	rank_abbreviation = ""

	spawn_location = "JoinLateJP"

	is_officer = TRUE
	whitelisted = TRUE
	is_commander = TRUE
	is_starwars = TRUE
	is_rebel = TRUE
	can_be_female = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/civilian/starwars/rebel/lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/rebel/officer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1/comlink(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/rebel_vest/officer(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/laser/westar34(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/rebel(H), slot_belt)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/rebel(H), slot_head)
//back
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	H.s_tone = rand(-35,-25)
	H.add_note("Role", "You are a <b>[title]</b>, lead the Rebel Alliance forced in the fight against the Extra-Galactic Empire!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_VERY_VERY_HIGH)
	H.setStat("dexterity", STAT_VERY_VERY_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_VERY_VERY_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_VERY_VERY_HIGH)
	return TRUE

/datum/job/civilian/starwars/rebel/doctor
	title = "Rebel Doctor"
	rank_abbreviation = ""
	can_be_female = TRUE
	spawn_location = "JoinLateJPDoc"

	is_medic = TRUE
	is_starwars = TRUE
	is_rebel = TRUE
	min_positions = 1
	max_positions = 2

/datum/job/civilian/starwars/rebel/doctor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/rebel(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1/comlink(H), slot_wear_id)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/doctor(H), slot_wear_suit)

	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/rebel(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/laser/dl44(H), slot_l_hand)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	H.s_tone = rand(-35,-25)
	H.add_note("Role", "You are a <b>[title]</b>. Keep the Rebel Marines fighting on!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_VERY_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MAX)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/civilian/starwars/rebel/technician
	title = "Rebel Radio Technician"
	rank_abbreviation = ""
	can_be_female = TRUE
	spawn_location = "JoinLateJP"

	is_medic = FALSE
	is_starwars = TRUE
	is_rebel = TRUE
	can_be_female = TRUE
	min_positions = 1
	max_positions = 10

/datum/job/civilian/starwars/rebel/technician/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.equip_to_slot_or_del(new /obj/item/clothing/under/rebel/officer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1/comlink(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/rebel_vest/officer(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction1/spaceradio(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/laser/dl44(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/rebel(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	H.s_tone = rand(-35,-25)
	H.add_note("Role", "You are a <b>[title]</b>. Keep the Rebel Forces Informed and Updated!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_VERY_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/civilian/starwars/rebel/sergeant
	title = "Rebel Marine Squad Leader"
	rank_abbreviation = ""
	can_be_female = TRUE
	spawn_location = "JoinLateJP"

	uses_squads = TRUE
	is_squad_leader = TRUE
	is_starwars = TRUE
	is_rebel = TRUE
	min_positions = 4
	max_positions = 8

/datum/job/civilian/starwars/rebel/sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/rebel(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/rebel_vest(H), slot_wear_suit)
//head

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1/comlink(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/rebel(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/laser/a280(H), slot_shoulder)

	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/rebel(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/laser/dl44(H), slot_l_hand)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	H.add_note("Role", "You are a <b>[title]</b>, a sergeant in the Rebel Alliance, in charge of a squad. Lead your men and fight against the Extra-Galactic Empire!")
	H.add_note("Partisan Mechanics", "- Press <b>C</b> to place a booby trap while holding a thermal detonator.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_VERY_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)
	H.setStat("stamina", STAT_VERY_HIGH)
	return TRUE

/datum/job/civilian/starwars/rebel/soldierheavy
	title = "Heavy Rebel"
	rank_abbreviation = ""

	spawn_location = "JoinLateJP"
	can_be_female = TRUE
	uses_squads = TRUE
	is_starwars = TRUE
	is_rebel = TRUE
	min_positions = 1
	max_positions = 10

/datum/job/civilian/starwars/rebel/soldierheavy/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/rebel(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/rebel_vest(H), slot_wear_suit)
//head

	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/tibannagas/blaster_power_pack(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/rebel(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1/comlink(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/rebel(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/laser/z6/empire(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/grenade/modern/thermaldetonator(H), slot_r_store)
	H.add_note("Role", "You are a <b>[title]</b>, a heavy soldier in the Rebel Army. Fight for the freedom of <b>the Galaxy</b>! Fight against the Galactic Empire!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_VERY_HIGH)
	return TRUE

/datum/job/civilian/starwars/rebel/soldier
	title = "Rebel Marine"
	rank_abbreviation = ""

	spawn_location = "JoinLateJP"
	can_be_female = TRUE
	uses_squads = TRUE
	is_starwars = TRUE
	is_rebel = TRUE
	min_positions = 24
	max_positions = 124

/datum/job/civilian/starwars/rebel/soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/rebel(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/rebel_vest(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/rebel(H), slot_belt)
//head
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1/comlink(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/rebel(H), slot_head)
	if	(prob(80))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/laser/dh17(H), slot_l_hand)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/laser/a280(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/grenade/modern/thermaldetonator(H), slot_r_store)
	H.add_note("Role", "You are a <b>[title]</b>, a soldier in the Rebel Alliance. Fight for the freedom of <b>the Galaxy</b>! Fight against the Galactic Empire!")
	H.add_note("Partisan Mechanics", "- Press <b>C</b> to place a booby trap while holding a thermal detonator.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)
	return TRUE


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////EXTRA-GALACTIC EMPIRE////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/datum/job/american/starwars/empire/lieutenant
	title = "Imperial Navy Lieutenant"
	rank_abbreviation = ""

	spawn_location = "JoinLateRUCap"

	is_officer = TRUE
	whitelisted = TRUE
	is_commander = TRUE
	is_starwars = TRUE
	is_empire = TRUE
	can_be_female = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/american/starwars/empire/lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/navallieutenant(H), slot_w_uniform)

	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/laser/westar34(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/white/stormtroomper/basic(H), slot_belt)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/impofficercap(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2/comlink(H), slot_wear_id)
//back
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	H.s_tone = rand(-35,-25)
	H.add_note("Role", "You are a <b>[title]</b>, lead the Galactic Imperial Forces in the fight against the Rebel Alliance!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_VERY_VERY_HIGH)
	H.setStat("dexterity", STAT_VERY_VERY_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_VERY_VERY_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_VERY_VERY_HIGH)
	return TRUE

/datum/job/american/starwars/empire/doctor
	title = "Imperial Storm-Surgeon"
	rank_abbreviation = ""
	can_be_female = TRUE
	spawn_location = "JoinLateRUDoc"

	is_medic = TRUE
	is_starwars = TRUE
	is_empire = TRUE
	min_positions = 1
	max_positions = 2

/datum/job/american/starwars/empire/doctor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/replicantshoes(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/bodyglove(H), slot_w_uniform)

	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/replicantgloves(H), slot_gloves)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2/comlink(H), slot_wear_id)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/laser/dh17(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/stormsurgeon(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/grenade/flashbang/galaxywars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/replicant/stormsurgeon(H), slot_head)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	H.s_tone = rand(-35,-25)
	H.add_note("Role", "You are a <b>[title]</b>. Keep the Extra-Galactic Empire fighting on!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_VERY_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MAX)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/american/starwars/empire/technician
	title = "Shocktrooper Radio Technician"
	rank_abbreviation = ""
	can_be_female = TRUE
	spawn_location = "JoinLateRU"

	is_medic = FALSE
	is_starwars = TRUE
	is_empire = TRUE
	can_be_female = TRUE
	min_positions = 1
	max_positions = 10

/datum/job/american/starwars/empire/technician/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/replicantshoes(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/bodyglove(H), slot_w_uniform)

	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/replicantgloves(H), slot_gloves)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/galacticbattles(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/stormradio(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction2/spaceradio(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/replicant/stormradio(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/laser/dh17(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/white/stormtroomper/flash(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/wrench(H), slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	H.s_tone = rand(-35,-25)
	H.add_note("Role", "You are a <b>[title]</b>. Keep the Imperial Forces Informed and Updated!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_VERY_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/american/starwars/empire/sergeant
	title = "Shocktrooper Sergeant"
	rank_abbreviation = ""
	can_be_female = TRUE
	spawn_location = "JoinLateRUSg"

	uses_squads = TRUE
	is_squad_leader = TRUE
	is_starwars = TRUE
	is_empire = TRUE
	min_positions = 4
	max_positions = 8

/datum/job/american/starwars/empire/sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/replicantshoes(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/bodyglove(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/stormtrooper(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/replicantgloves(H), slot_gloves)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/replicant/stormtrooper(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2/comlink(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/replicant/stormtrooper(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/laser/dh17(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/laser/e11(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/white/stormtroomper/sgt(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	H.add_note("Role", "You are a <b>[title]</b>, in the Extra-Galactic Imperial Army, in charge of a squad. Lead your men and fight against the Rebel Alliance!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_VERY_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)
	H.setStat("stamina", STAT_VERY_HIGH)
	return TRUE


/datum/job/american/starwars/empire/soldierheavy
	title = "Heavy Shocktrooper"
	rank_abbreviation = ""

	spawn_location = "JoinLateRU"
	can_be_female = TRUE
	uses_squads = TRUE
	is_starwars = TRUE
	is_empire = TRUE
	min_positions = 1
	max_positions = 10

/datum/job/american/starwars/empire/soldierheavy/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/replicantshoes(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/bodyglove(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/stormtrooper(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/replicantgloves(H), slot_gloves)
//head
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/tibannagas/blaster_power_pack(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2/comlink(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/replicant/stormtrooper(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/laser/z6/empire(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/grenade/flashbang/galaxywars(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/white/stormtroomper/flash(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>, a soldier in the Extra-Galactic Imperial Army. Fight for the freedom of <b>the Galaxy</b>! Fight against the Rebel Alliance!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_VERY_HIGH)
	return TRUE

/datum/job/american/starwars/empire/soldier
	title = "Shocktrooper"
	rank_abbreviation = ""

	spawn_location = "JoinLateRU"
	can_be_female = TRUE
	uses_squads = TRUE
	is_starwars = TRUE
	is_empire = TRUE
	min_positions = 24
	max_positions = 124

/datum/job/american/starwars/empire/soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/replicantshoes(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/bodyglove(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/stormtrooper(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/replicantgloves(H), slot_gloves)
//head
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2/comlink(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/replicant/stormtrooper(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/laser/e11(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/grenade/flashbang/galaxywars(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/white/stormtroomper/basic(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>, a soldier in the Extra-Galactic Imperial Army. Fight for the freedom of <b>the Galaxy</b>! Fight against the Rebel Alliance!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)
	return TRUE