/datum/job/american/fp_captain
	title = " Army Captain"
	rank_abbreviation = "Cpt."

	spawn_location = "JoinLateRNCap"
	is_ph_us_war = TRUE
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_radioman = FALSE
	is_ww2 = FALSE

	min_positions = 1
	max_positions = 1

/datum/job/american/fp_captain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ph_us_war/american/us_off_uni(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/unionhatlight(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/colt1892(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/union_gloves(H), slot_gloves)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. You are in charge of the whole company. Organize your troops accordingly!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)
	return TRUE

/datum/job/american/fp_lieutenant
	title = " Army Lieutenant"
	rank_abbreviation = "Lt."

	spawn_location = "JoinLateRNBoatswain"
	is_ph_us_war = TRUE
	is_officer = TRUE
	is_commander = FALSE
	whitelisted = TRUE
	is_radioman = FALSE
	is_ww2 = FALSE

	min_positions = 1
	max_positions = 2

/datum/job/american/fp_lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ph_us_war/american/us_off_uni(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/unionhatlight(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/colt1892(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/union_gloves(H), slot_gloves)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. You are in charge of the whole platoon. Organize your troops accordingly!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)
	return TRUE

/datum/job/american/fp_sergeant
	title = " Army Sergeant"
	rank_abbreviation = "Sgt."

	spawn_location = "JoinLateRN"
	is_squad_leader = TRUE
	uses_squads = TRUE
	is_radioman = FALSE
	can_get_coordinates = FALSE
	is_ww2 = FALSE
	is_ph_us_war = TRUE

	min_positions = 2
	max_positions = 10

/datum/job/american/fp_sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ph_us_war/american/us_uni(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ph_us_war/american/infantry_hat(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/singleshot/rollingblock(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/colt1892(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, lead a squad against the enemy and follow your Commanding Officer's orders!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)
	return TRUE

/datum/job/american/fp_soldier
	title = " Army Rifleman"
	rank_abbreviation = "Pvt."

	spawn_location = "JoinLateRN"
	is_ww2 = FALSE
	uses_squads = TRUE
	is_ph_us_war = TRUE

	min_positions = 8
	max_positions = 100

/datum/job/american/fp_soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ph_us_war/american/us_uni (H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ph_us_war/american/infantry_hat(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/singleshot/rollingblock(H), slot_shoulder)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a basic grunt. Follow orders and defeat the enemy!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/american/fp_doctor
	title = " Army Doctor"
	rank_abbreviation = "2lt."

	spawn_location = "JoinLateRNSurgeon"
	is_ph_us_war = TRUE
	is_medic = TRUE
	is_ww2 = FALSE

	min_positions = 1
	max_positions = 4

/datum/job/american/fp_doctor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/colt1892(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ph_us_war/american/us_uni(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/doctor(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ph_us_war/american/infantry_hat(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/surgery(H), slot_belt)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/custom/armband/white = new /obj/item/clothing/accessory/custom/armband(null)
	uniform.attackby(white, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. Keep your soldiers healthy and breathing! The medics will bring you men to operate on.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/american/fp_sniper
	title = " Army Sharpshooter"
	rank_abbreviation = "Cpl."

	spawn_location = "JoinLateRN"
	is_ww2 = FALSE
	uses_squads = TRUE
	is_ph_us_war = TRUE

	min_positions = 8
	max_positions = 16

/datum/job/american/fp_sniper/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ph_us_war/american/us_uni (H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ph_us_war/american/infantry_hat(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/singleshot/rollingblock(H), slot_shoulder)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a well trained sniper. Follow orders and take out priority targets from a distance!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////FILIPINO////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/filipino
	faction = "Human"

/datum/job/filipino/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_filipino_name(H.gender)
	H.real_name = H.name
	var/new_hair = "Black"
	var/hex_hair = hair_colors[new_hair]
	H.r_hair = hex2num(copytext(hex_hair, 2, 4))
	H.g_hair = hex2num(copytext(hex_hair, 4, 6))
	H.b_hair = hex2num(copytext(hex_hair, 6, 8))
	H.r_facial = hex2num(copytext(hex_hair, 2, 4))
	H.g_facial = hex2num(copytext(hex_hair, 4, 6))
	H.b_facial = hex2num(copytext(hex_hair, 6, 8))
/datum/job/filipino/captain
	title = " Kapitan"
	en_meaning = "captain"
	rank_abbreviation = "Kpt."

	spawn_location = "JoinLateFPCap"
	is_ph_us_war = TRUE
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_radioman = FALSE
	is_ww2 = FALSE

	min_positions = 1
	max_positions = 1

/datum/job/filipino/captain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ph_us_war/filipino/filuni(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ph_us_war/filipino/fil_off_cap(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/sw3(H), slot_l_hand)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/rank/fp_cpth = new /obj/item/clothing/accessory/rank/fp_cpt(null)
	uniform.attackby(fp_cpth, H)
	give_random_name(H)
	H.s_tone = rand(-65,-75)
	H.add_note("Role", "You are a <b>[title]</b>. You are in charge of the whole company. Organize your troops accordingly!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)
	return TRUE

/datum/job/filipino/lieutenant
	title = "Tenyente"
	en_meaning = "Lieutenant"
	rank_abbreviation = "Ty."

	spawn_location = "JoinLateFPLt"
	is_ph_us_war = TRUE
	is_officer = TRUE
	is_commander = FALSE
	whitelisted = TRUE
	is_radioman = FALSE
	is_ww2 = FALSE

	min_positions = 1
	max_positions = 2

/datum/job/filipino/lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ph_us_war/filipino/filuni(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ph_us_war/filipino/fil_off_cap(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/sw3(H), slot_l_hand)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/rank/fp_lth = new /obj/item/clothing/accessory/rank/fp_lt(null)
	uniform.attackby(fp_lth, H)
	give_random_name(H)
	H.s_tone = rand(-65,-75)
	H.add_note("Role", "You are a <b>[title]</b>. You are in charge of the whole platoon. Organize your troops accordingly!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)
	return TRUE

/datum/job/filipino/sergeant
	title = "Serhente"
	en_meaning = "Sergeant"
	rank_abbreviation = "Sht."

	spawn_location = "JoinLateFP"
	is_squad_leader = TRUE
	uses_squads = TRUE
	is_radioman = FALSE
	can_get_coordinates = FALSE
	is_ww2 = FALSE
	is_ph_us_war = TRUE
	can_be_female = TRUE

	min_positions = 2
	max_positions = 10

/datum/job/filipino/sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ph_us_war/filipino/filuni(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ph_us_war/filipino/baliwag(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/sw3(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mauser1893(H), slot_shoulder)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/rank/fp_sgth = new /obj/item/clothing/accessory/rank/fp_sgt(null)
	uniform.attackby(fp_sgth, H)
	give_random_name(H)
	H.s_tone = rand(-65,-75)
	H.add_note("Role", "You are a <b>[title]</b>, lead a squad against the enemy and follow your Commanding Officer's orders!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)
	return TRUE

/datum/job/filipino/soldier
	title = "Kawal"
	en_meaning = "Soldier"
	rank_abbreviation = "Kl."

	spawn_location = "JoinLateFP"
	is_ww2 = FALSE
	uses_squads = TRUE
	is_ph_us_war = TRUE
	can_be_female = TRUE

	min_positions = 8
	max_positions = 100

/datum/job/filipino/soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ph_us_war/filipino/filuni (H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ph_us_war/filipino/baliwag(H), slot_head)
//back
	if (prob(10))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mauser1893(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/bolo(H), slot_belt)
		var/obj/item/clothing/under/uniform = H.w_uniform
		var/obj/item/clothing/accessory/storage/webbing/filipinoh = new /obj/item/clothing/accessory/storage/webbing/filipino(null)
		uniform.attackby(filipinoh, H)
		filipinoh.attackby(new/obj/item/ammo_magazine/mauser1893, H)
		filipinoh.attackby(new/obj/item/ammo_magazine/mauser1893, H)
		filipinoh.attackby(new/obj/item/ammo_magazine/mauser1893, H)
		filipinoh.attackby(new/obj/item/ammo_magazine/mauser1893, H)
		filipinoh.attackby(new/obj/item/ammo_magazine/mauser1893box, H)
	else if (prob(80))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/singleshot/rollingblock/spanish(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/bolo(H), slot_belt)
		var/obj/item/clothing/under/uniform = H.w_uniform
		var/obj/item/clothing/accessory/storage/webbing/filipinoh = new /obj/item/clothing/accessory/storage/webbing/filipino(null)
		uniform.attackby(filipinoh, H)
		filipinoh.attackby(new/obj/item/ammo_magazine/c43, H)
		filipinoh.attackby(new/obj/item/ammo_magazine/c43, H)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/bolo(H), slot_belt)
	give_random_name(H)
	H.s_tone = rand(-65,-75)
	H.add_note("Role", "You are a <b>[title]</b>, a basic grunt. Follow orders and defeat the enemy!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/filipino/doctor
	title = "Manggagamot"
	en_meaning = "Doctor"
	rank_abbreviation = "Ty."

	spawn_location = "JoinLateFPSurgeon"
	is_ph_us_war = TRUE
	is_medic = TRUE
	is_ww2 = FALSE
	can_be_female = TRUE

	min_positions = 1
	max_positions = 4

/datum/job/filipino/doctor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/colt1892(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/modern2(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ph_us_war/filipino/baliwag(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/surgery(H), slot_belt)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/custom/armband/white = new /obj/item/clothing/accessory/custom/armband(null)
	uniform.attackby(white, H)
	var/obj/item/clothing/accessory/custom/apron = new /obj/item/clothing/accessory/custom/apron(null)
	uniform.attackby(apron, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.s_tone = rand(-65,-75)
	H.add_note("Role", "You are a <b>[title]</b>. Keep your soldiers healthy and breathing! Find the wounded and help them.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/filipino/sniper
	title = "Tiradores"
	en_meaning = "Sharp Shooter"
	rank_abbreviation = "Ko."

	spawn_location = "JoinLateFP"
	is_ww2 = FALSE
	uses_squads = TRUE
	is_ph_us_war = TRUE
	can_be_female = TRUE

	min_positions = 8
	max_positions = 100

/datum/job/filipino/sniper/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ph_us_war/filipino/tiradores(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/bolo(H), slot_belt)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ph_us_war/filipino/baliwag(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mauser1893(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/bolo(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/filipinoh = new /obj/item/clothing/accessory/storage/webbing/filipino(null)
	uniform.attackby(filipinoh, H)
	filipinoh.attackby(new/obj/item/ammo_magazine/mauser1893, H)
	filipinoh.attackby(new/obj/item/ammo_magazine/mauser1893, H)
	filipinoh.attackby(new/obj/item/ammo_magazine/mauser1893, H)
	filipinoh.attackby(new/obj/item/ammo_magazine/mauser1893, H)
	filipinoh.attackby(new/obj/item/ammo_magazine/mauser1893box, H)
	var/obj/item/clothing/accessory/rank/fp_cplh = new /obj/item/clothing/accessory/rank/fp_cpl(null)
	uniform.attackby(fp_cplh, H)
	give_random_name(H)
	H.s_tone = rand(-65,-75)
	H.add_note("Role", "You are a <b>[title]</b>, a well trained sniper. Follow orders and take out priority targets from a distance!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE