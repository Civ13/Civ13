/datum/job/american/fp_captain
	title = " Army Captain"
	rank_abbreviation = "Cpt."
	allowed_maps = list(MAP_CALOOCAN, MAP_SANTO_TOMAS)

	spawn_location = "JoinLateRNCap"
	is_ph_us_war = TRUE
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_radioman = FALSE
	is_ww2 = FALSE

	min_positions = 1
	max_positions = 1

/datum/job/american/fp_captain/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_VERY_HIGH, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_NORMAL, "machinegun" = STAT_MEDIUM_HIGH)
/datum/job/american/fp_captain/job_loadout = list(
	/obj/item/clothing/shoes/riding1 = slot_shoes,
	/obj/item/clothing/under/ph_us_war/american/us_off_uni = slot_w_uniform,
	/obj/item/clothing/head/unionhatlight = slot_head,
	/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars = slot_belt,
	/obj/item/weapon/gun/projectile/revolver/colt1892 = slot_l_hand,
	/obj/item/clothing/gloves/union_gloves = slot_gloves)
/datum/job/american/fp_captain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. You are in charge of the whole company. Organize your troops accordingly!")
	apply_job_stats(H)
	return TRUE

/datum/job/american/fp_lieutenant
	title = " Army Lieutenant"
	rank_abbreviation = "Lt."
	allowed_maps = list(MAP_CALOOCAN, MAP_SANTO_TOMAS)

	spawn_location = "JoinLateRNBoatswain"
	is_ph_us_war = TRUE
	is_officer = TRUE
	is_commander = FALSE
	whitelisted = TRUE
	is_radioman = FALSE
	is_ww2 = FALSE

	min_positions = 1
	max_positions = 2

/datum/job/american/fp_lieutenant/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_VERY_HIGH, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_NORMAL, "machinegun" = STAT_MEDIUM_HIGH)
/datum/job/american/fp_lieutenant/job_loadout = list(
	/obj/item/clothing/shoes/riding1 = slot_shoes,
	/obj/item/clothing/under/ph_us_war/american/us_off_uni = slot_w_uniform,
	/obj/item/clothing/head/unionhatlight = slot_head,
	/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars = slot_belt,
	/obj/item/weapon/gun/projectile/revolver/colt1892 = slot_l_hand,
	/obj/item/clothing/gloves/union_gloves = slot_gloves)
/datum/job/american/fp_lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. You are in charge of the whole platoon. Organize your troops accordingly!")
	apply_job_stats(H)
	return TRUE

/datum/job/american/fp_sergeant
	title = " Army Sergeant"
	rank_abbreviation = "Sgt."
	allowed_maps = list(MAP_CALOOCAN, MAP_SANTO_TOMAS)

	spawn_location = "JoinLateRN"
	is_squad_leader = TRUE
	uses_squads = TRUE
	is_radioman = FALSE
	can_get_coordinates = FALSE
	is_ww2 = FALSE
	is_ph_us_war = TRUE

	min_positions = 2
	max_positions = 10

/datum/job/american/fp_sergeant/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_NORMAL, "machinegun" = STAT_MEDIUM_HIGH)
/datum/job/american/fp_sergeant/job_loadout = list(
	/obj/item/clothing/shoes/riding1 = slot_shoes,
	/obj/item/clothing/under/ph_us_war/american/us_uni = slot_w_uniform,
	/obj/item/clothing/head/ph_us_war/american/infantry_hat = slot_head,
	/obj/item/weapon/attachment/bayonet = slot_belt,
	/obj/item/weapon/gun/projectile/boltaction/singleshot/rollingblock = slot_shoulder,
	/obj/item/weapon/gun/projectile/revolver/colt1892 = slot_l_hand,
	/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars = slot_l_store)
/datum/job/american/fp_sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, lead a squad against the enemy and follow your Commanding Officer's orders!")
	apply_job_stats(H)
	return TRUE

/datum/job/american/fp_soldier
	title = " Army Rifleman"
	rank_abbreviation = "Pvt."
	allowed_maps = list(MAP_CALOOCAN, MAP_SANTO_TOMAS)

	spawn_location = "JoinLateRN"
	is_ww2 = FALSE
	uses_squads = TRUE
	is_ph_us_war = TRUE

	min_positions = 8
	max_positions = 100

/datum/job/american/fp_soldier/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_MEDIUM_LOW)
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
	apply_job_stats(H)
	return TRUE

/datum/job/american/fp_doctor
	title = " Army Doctor"
	rank_abbreviation = "2lt."
	allowed_maps = list(MAP_CALOOCAN, MAP_SANTO_TOMAS)

	spawn_location = "JoinLateRNSurgeon"
	is_ph_us_war = TRUE
	is_medic = TRUE
	is_ww2 = FALSE

	min_positions = 1
	max_positions = 4

/datum/job/american/fp_doctor/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_NORMAL, "medical" = STAT_VERY_HIGH, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/american/fp_doctor/job_loadout = list(
	/obj/item/clothing/shoes/riding1 = slot_shoes,
	/obj/item/weapon/gun/projectile/revolver/colt1892 = slot_l_hand,
	/obj/item/clothing/under/ph_us_war/american/us_uni = slot_w_uniform,
	/obj/item/clothing/suit/storage/jacket/doctor = slot_wear_suit,
	/obj/item/clothing/head/ph_us_war/american/infantry_hat = slot_head,
	/obj/item/weapon/storage/firstaid/adv = slot_back,
	/obj/item/weapon/storage/firstaid/surgery = slot_belt)
/datum/job/american/fp_doctor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/custom/armband/white = new /obj/item/clothing/accessory/custom/armband(null)
	uniform.attackby(white, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. Keep your soldiers healthy and breathing! The medics will bring you men to operate on.")
	apply_job_stats(H)
	return TRUE

/datum/job/american/fp_sniper
	title = " Army Sharpshooter"
	rank_abbreviation = "Cpl."
	allowed_maps = list(MAP_CALOOCAN, MAP_SANTO_TOMAS)

	spawn_location = "JoinLateRN"
	is_ww2 = FALSE
	uses_squads = TRUE
	is_ph_us_war = TRUE

	min_positions = 8
	max_positions = 16

/datum/job/american/fp_sniper/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_MEDIUM_LOW)
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
	apply_job_stats(H)
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
	allowed_maps = list(MAP_CALOOCAN, MAP_SANTO_TOMAS)

	spawn_location = "JoinLateFPCap"
	is_ph_us_war = TRUE
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_radioman = FALSE
	is_ww2 = FALSE

	min_positions = 1
	max_positions = 1

/datum/job/filipino/captain/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_VERY_HIGH, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_NORMAL, "machinegun" = STAT_MEDIUM_HIGH)
/datum/job/filipino/captain/job_loadout = list(
	/obj/item/clothing/shoes/riding1 = slot_shoes,
	/obj/item/clothing/under/ph_us_war/filipino/filuni = slot_w_uniform,
	/obj/item/clothing/head/ph_us_war/filipino/fil_off_cap = slot_head,
	/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars = slot_belt,
	/obj/item/weapon/gun/projectile/revolver/sw3 = slot_l_hand)
/datum/job/filipino/captain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/rank/fp_cpth = new /obj/item/clothing/accessory/rank/fp_cpt(null)
	uniform.attackby(fp_cpth, H)
	give_random_name(H)
	H.s_tone = rand(-65,-75)
	H.add_note("Role", "You are a <b>[title]</b>. You are in charge of the whole company. Organize your troops accordingly!")
	apply_job_stats(H)
	return TRUE

/datum/job/filipino/lieutenant
	title = "Tenyente"
	en_meaning = "Lieutenant"
	rank_abbreviation = "Ty."
	allowed_maps = list(MAP_CALOOCAN, MAP_SANTO_TOMAS)

	spawn_location = "JoinLateFPLt"
	is_ph_us_war = TRUE
	is_officer = TRUE
	is_commander = FALSE
	whitelisted = TRUE
	is_radioman = FALSE
	is_ww2 = FALSE

	min_positions = 1
	max_positions = 2

/datum/job/filipino/lieutenant/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_VERY_HIGH, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_NORMAL, "machinegun" = STAT_MEDIUM_HIGH)
/datum/job/filipino/lieutenant/job_loadout = list(
	/obj/item/clothing/shoes/riding1 = slot_shoes,
	/obj/item/clothing/under/ph_us_war/filipino/filuni = slot_w_uniform,
	/obj/item/clothing/head/ph_us_war/filipino/fil_off_cap = slot_head,
	/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars = slot_belt,
	/obj/item/weapon/gun/projectile/revolver/sw3 = slot_l_hand)
/datum/job/filipino/lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/rank/fp_lth = new /obj/item/clothing/accessory/rank/fp_lt(null)
	uniform.attackby(fp_lth, H)
	give_random_name(H)
	H.s_tone = rand(-65,-75)
	H.add_note("Role", "You are a <b>[title]</b>. You are in charge of the whole platoon. Organize your troops accordingly!")
	apply_job_stats(H)
	return TRUE

/datum/job/filipino/sergeant
	title = "Serhente"
	en_meaning = "Sergeant"
	rank_abbreviation = "Sht."
	allowed_maps = list(MAP_CALOOCAN, MAP_SANTO_TOMAS)

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

/datum/job/filipino/sergeant/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_NORMAL, "machinegun" = STAT_MEDIUM_HIGH)
/datum/job/filipino/sergeant/job_loadout = list(
	/obj/item/clothing/shoes/riding1 = slot_shoes,
	/obj/item/clothing/under/ph_us_war/filipino/filuni = slot_w_uniform,
	/obj/item/clothing/head/ph_us_war/filipino/baliwag = slot_head,
	/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars = slot_belt,
	/obj/item/weapon/gun/projectile/revolver/sw3 = slot_l_hand,
	/obj/item/weapon/gun/projectile/boltaction/mauser1893 = slot_shoulder)
/datum/job/filipino/sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/rank/fp_sgth = new /obj/item/clothing/accessory/rank/fp_sgt(null)
	uniform.attackby(fp_sgth, H)
	give_random_name(H)
	H.s_tone = rand(-65,-75)
	H.add_note("Role", "You are a <b>[title]</b>, lead a squad against the enemy and follow your Commanding Officer's orders!")
	apply_job_stats(H)
	return TRUE

/datum/job/filipino/soldier
	title = "Kawal"
	en_meaning = "Soldier"
	rank_abbreviation = "Kl."
	allowed_maps = list(MAP_CALOOCAN, MAP_SANTO_TOMAS)

	spawn_location = "JoinLateFP"
	is_ww2 = FALSE
	uses_squads = TRUE
	is_ph_us_war = TRUE
	can_be_female = TRUE

	min_positions = 8
	max_positions = 100

/datum/job/filipino/soldier/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_MEDIUM_LOW)
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
	apply_job_stats(H)
	return TRUE

/datum/job/filipino/doctor
	title = "Manggagamot"
	en_meaning = "Doctor"
	rank_abbreviation = "Ty."
	allowed_maps = list(MAP_CALOOCAN, MAP_SANTO_TOMAS)

	spawn_location = "JoinLateFPSurgeon"
	is_ph_us_war = TRUE
	is_medic = TRUE
	is_ww2 = FALSE
	can_be_female = TRUE

	min_positions = 1
	max_positions = 4

/datum/job/filipino/doctor/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_NORMAL, "medical" = STAT_VERY_HIGH, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/filipino/doctor/job_loadout = list(
	/obj/item/clothing/shoes/riding1 = slot_shoes,
	/obj/item/weapon/gun/projectile/revolver/colt1892 = slot_l_hand,
	/obj/item/clothing/under/modern2 = slot_w_uniform,
	/obj/item/clothing/head/ph_us_war/filipino/baliwag = slot_head,
	/obj/item/weapon/storage/firstaid/adv = slot_back,
	/obj/item/weapon/storage/firstaid/surgery = slot_belt)
/datum/job/filipino/doctor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)

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
	apply_job_stats(H)
	return TRUE

/datum/job/filipino/sniper
	title = "Tiradores"
	en_meaning = "Sharp Shooter"
	rank_abbreviation = "Ko."
	allowed_maps = list(MAP_CALOOCAN, MAP_SANTO_TOMAS)

	spawn_location = "JoinLateFP"
	is_ww2 = FALSE
	uses_squads = TRUE
	is_ph_us_war = TRUE
	can_be_female = TRUE

	min_positions = 8
	max_positions = 100

/datum/job/filipino/sniper/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_VERY_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_MEDIUM_LOW)
/datum/job/filipino/sniper/job_loadout = list(
	/obj/item/clothing/shoes/riding1 = slot_shoes,
	/obj/item/clothing/under/ph_us_war/filipino/tiradores = slot_w_uniform,
	/obj/item/weapon/material/sword/bolo = slot_belt,
	/obj/item/clothing/head/ph_us_war/filipino/baliwag = slot_head,
	/obj/item/weapon/gun/projectile/boltaction/mauser1893 = slot_shoulder)
/datum/job/filipino/sniper/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
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
	apply_job_stats(H)
	return TRUE