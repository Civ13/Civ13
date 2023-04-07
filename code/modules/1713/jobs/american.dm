/datum/job/american/captain_ww2
	title = "US Captain"
	rank_abbreviation = "Cpt."

	spawn_location = "JoinLateRNCap"

	is_officer = TRUE
	is_commander = FALSE
	whitelisted = TRUE
	is_radioman = FALSE
	is_ww2 = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/american/captain_ww2/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/us(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/us_cap(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/thompson(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/us/officer(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m1911(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/american(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction1(H), slot_back)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
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

/datum/job/american/lieutenant_ww2
	title = "US Lieutenant"
	rank_abbreviation = "Lt."

	spawn_location = "JoinLateRNBoatswain"

	is_officer = TRUE
	whitelisted = TRUE
	is_radioman = FALSE
	is_ww2 = TRUE
	is_ardeness = TRUE

	min_positions = 1
	max_positions = 2

/datum/job/american/lieutenant_ww2/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/us(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/us_1lt(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/thompson(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/us_ww2_sgt(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m1911(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/american(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction1(H), slot_back)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
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
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/american/sergeant_ww2
	title = "US Sergeant"
	rank_abbreviation = "Sgt."

	spawn_location = "JoinLateRN"

	is_squad_leader = TRUE
	uses_squads = TRUE
	is_radioman = FALSE
	can_get_coordinates = TRUE
	is_ww2 = TRUE
	is_ardeness = TRUE

	min_positions = 2
	max_positions = 10

/datum/job/american/sergeant_ww2/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/us(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/us_2lt(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction1(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m1911(H), slot_l_hand)
//gun
	if (prob(65))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/thompson(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/us_ww2_sgt(H), slot_belt)
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_r_store)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/m1carbine(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/us_ww2_sgtc(H), slot_belt)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m1911(H), slot_r_hand)

	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, lead a squad against the Axis enemy and follow your CO's orders!")
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

/datum/job/american/medic_ww2
	title = "US Field Medic"
	rank_abbreviation = "Cpl."

	spawn_location = "JoinLateRNSurgeon"
	is_medic = TRUE
	is_ww2 = TRUE
	uses_squads = TRUE
	is_ardeness = TRUE

	min_positions = 2
	max_positions = 8

/datum/job/american/medic_ww2/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/us(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/us_medic(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m1911(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/roller(H), slot_r_hand)
//gun
	if (prob(65))
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m1carbine(H), slot_r_store)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m1carbine(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/m1carbine(H), slot_shoulder)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_store)
//lamp
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/custom/armband/white = new /obj/item/clothing/accessory/custom/armband(null)
	uniform.attackby(white, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. Keep your fellow soldiers healthy and breathing!")
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

/datum/job/american/doctor_ww2
	title = "US Doctor"
	rank_abbreviation = "2lt."

	spawn_location = "JoinLateRNSurgeon"
	is_ardeness = TRUE
	is_medic = TRUE
	is_ww2 = TRUE
	can_be_female = TRUE
	min_positions = 1
	max_positions = 4

/datum/job/american/doctor_ww2/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/us(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/doctor(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/us_medic(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/roller(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/bint/medic(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/surgery(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m1911(H), slot_l_hand)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)

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

/datum/job/american/sniper_ww2
	title = "US Sniper"
	rank_abbreviation = "Pfc."

	spawn_location = "JoinLateRN"

	is_ww2 = TRUE
	uses_squads = TRUE
	is_ardeness = TRUE

	min_positions = 2
	max_positions = 8

/datum/job/american/sniper_ww2/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/us(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/usm1(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/springfield/sniper, slot_shoulder)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
//pocket
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/us_ww2_sniper(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/us_ww2/web = new /obj/item/clothing/accessory/storage/webbing/us_ww2(null)
	uniform.attackby(web, H)
	web.attackby(new/obj/item/stack/medical/bruise_pack/gauze, H)
	web.attackby(new/obj/item/ammo_magazine/m3006box, H)
	web.attackby(new/obj/item/ammo_magazine/springfield, H)
	web.attackby(new/obj/item/ammo_magazine/springfield, H)
	web.attackby(new/obj/item/ammo_magazine/springfield, H)
	web.attackby(new/obj/item/ammo_magazine/springfield, H)
	web.attackby(new/obj/item/ammo_magazine/springfield, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, fighting against the Axis! Keep the enemy off our guys and take out high value targets from a distance!")
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

/datum/job/american/machine_gunner_ww2
	title = "US Machine Gunner"
	rank_abbreviation = "Pfc."

	spawn_location = "JoinLateRN"

	is_ww2 = TRUE
	uses_squads = TRUE
	is_ardeness = TRUE

	min_positions = 2
	max_positions = 8

/datum/job/american/machine_gunner_ww2/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/us(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/usm1(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m1911(H), slot_l_hand)
	if (prob(85))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/bar(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/us_ww2_gunner(H), slot_belt)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun_cleaning_kit(H), slot_l_store)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/browning_lmg(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/browning(H), slot_belt)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/browning(H), slot_back)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun_cleaning_kit(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/gauze(H), slot_r_store)
//more shit
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, carrying a light machine gun. Keep your squad covered!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_VERY_HIGH)
	return TRUE

/datum/job/american/ammo_bearer_ww2
	title = "Ammo Bearer"
	rank_abbreviation = "Pfc."

	spawn_location = "JoinLateRN"

	is_ww2 = TRUE
	uses_squads = TRUE
	is_ardeness = TRUE

	min_positions = 2
	max_positions = 4

/datum/job/american/ammo_bearer_ww2/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/us(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/usm1(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/ammo_can/american_mg(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m1911(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/ammo_can/american_bar(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_store)

	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/us_ww2 = new /obj/item/clothing/accessory/storage/webbing/us_ww2(null)
	uniform.attackby(us_ww2, H)
	us_ww2.attackby(new/obj/item/stack/medical/bruise_pack/gauze, H)
	us_ww2.attackby(new/obj/item/ammo_magazine/m1911, H)
	us_ww2.attackby(new/obj/item/ammo_magazine/m1911, H)
	us_ww2.attackby(new/obj/item/ammo_magazine/m1911, H)
	us_ww2.attackby(new/obj/item/ammo_magazine/m1911, H)
	us_ww2.attackby(new/obj/item/ammo_magazine/m1911, H)
	us_ww2.attackby(new/obj/item/ammo_magazine/m1911, H)
	us_ww2.attackby(new/obj/item/ammo_magazine/m1911, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, carrying the ammo for a light machine gun. Keep your squad gunner supplied!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_VERY_HIGH)
	return TRUE

/datum/job/american/soldier_ww2
	title = "US Rifleman"
	rank_abbreviation = "Pvt."

	spawn_location = "JoinLateRN"

	is_ww2 = TRUE
	uses_squads = TRUE
	is_ardeness = TRUE

	min_positions = 8
	max_positions = 100

/datum/job/american/soldier_ww2/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/us(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/usm1(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/m1garand(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/us_ww2(H), slot_belt)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/us_ww2 = new /obj/item/clothing/accessory/storage/webbing/us_ww2(null)
	uniform.attackby(us_ww2, H)
	us_ww2.attackby(new/obj/item/stack/medical/bruise_pack/gauze, H)
	us_ww2.attackby(new/obj/item/ammo_magazine/garand, H)
	us_ww2.attackby(new/obj/item/ammo_magazine/garand, H)
	us_ww2.attackby(new/obj/item/ammo_magazine/garand, H)
	us_ww2.attackby(new/obj/item/ammo_magazine/garand, H)
	us_ww2.attackby(new/obj/item/ammo_magazine/garand, H)
	us_ww2.attackby(new/obj/item/ammo_magazine/garand, H)
	us_ww2.attackby(new/obj/item/ammo_magazine/garand, H)
	us_ww2.attackby(new/obj/item/ammo_magazine/garand, H)

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

/datum/job/american/tanker_ww2
	title = "US Tanker"
	rank_abbreviation = "Cpl."

	spawn_location = "JoinLateRN"

	is_ww2 = TRUE
	is_tanker = TRUE
	uses_squads = FALSE

	min_positions = 4
	max_positions = 12

/datum/job/american/tanker_ww2/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/us_tanker(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/us_tanker(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/m1garand(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m1911(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/american(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m1911(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/us_ww2(H), slot_belt)

	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)


	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a crewman. Follow orders and use your armor to defeat the enemy!")
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

/datum/job/american/mp_ww2
	title = "US Military Police"
	rank_abbreviation = "Ssgt."

	spawn_location = "JoinLateRNMidshipman"
	is_officer = TRUE
	is_ww2 = TRUE
	whitelisted = TRUE
	is_ardeness = TRUE

	min_positions = 1
	max_positions = 4

/datum/job/american/mp_ww2/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/us_mp(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/usm1mpblack(H), slot_head)
//back
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m1911(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/gulagguard/filled(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, an MP. Follow orders of your CO, stay at base, and arrest the soldiers commiting war crimes or not following protocol!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/american/chef_ww2
	title = "US Chef"
	rank_abbreviation = "Pfc."

	spawn_location = "JoinLateRNCook"

	is_ww2 = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/american/chef_ww2/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/us_shirtless(H), slot_w_uniform)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/butcher(H), slot_l_hand)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a chef. Stay at base and cook meals for the soldiers! You can try interesting recipes in your spare time or can the food to make it last.")
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


/datum/job/american/soldier_ww2_filipino/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_filipino_name(H.gender)
	H.real_name = H.name

/datum/job/american/soldier_ww2_filipino
	title = "Filipino Scout"
	rank_abbreviation = ""

	spawn_location = "JoinLateRN"
	is_pacific = TRUE
	is_ww2 = TRUE
	uses_squads = TRUE
	can_be_female = TRUE
	min_positions = 4
	max_positions = 24
	default_language = "Filipino"
	additional_languages = list("English" = 95, "Spanish" = 45, "Japanese" = 25)

/datum/job/american/soldier_ww2_filipino/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	var/pickuni = rand(1,5)
	if (pickuni == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/us(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/usm1(H), slot_head)
	if (pickuni == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/us_shirtless(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/usm1(H), slot_head)
	if (pickuni == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ1(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/flatcap1(H), slot_head)
	if (pickuni == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ2(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/flatcap1(H), slot_head)
	if (pickuni == 5)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial5(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/jungle_hat/khaki(H), slot_head)
	if (pickuni == 6)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/us(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/flatcap1(H), slot_head)
	if (pickuni == 7)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/us_shirtless(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/flatcap1(H), slot_head)
//back
	if (prob(65))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/springfield(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/us_ww2_sniper(H), slot_belt)
	if (prob(25))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/m1garand(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/us_ww2(H), slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/thompson(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/us_ww2_sgt(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_store)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
	give_random_name(H)
	H.s_tone = rand(-65,-75)
	H.add_note("Role", "You are a <b>[title]</b>, a basic grunt. Follow orders and defeat the enemy!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE
////////////////////////NAVY/////////////////////////////
/datum/job/american/sailor_ww2
	title = "US Sailor"
	rank_abbreviation = "Pvt."

	spawn_location = "JoinLateRNNavy"

	is_ww2 = TRUE
	whitelisted = TRUE

	is_navy = TRUE

	min_positions = 1
	max_positions = 4

/datum/job/american/sailor_ww2/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/us_navy(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/us_sailor_hat(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m1911(H), slot_belt)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a US Navy Sailor. Follow orders of your CO, stay at base, and provide covering artillery fire for the army and marines!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE

////////////////////////////KOREAN WAR///////////////////////////////////
/datum/job/american/captain_korean_war
	title = " US Captain"
	rank_abbreviation = "Cpt."

	spawn_location = "JoinLateRNCap"

	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_radioman = FALSE
	is_korean_war = TRUE
	min_positions = 1
	max_positions = 1

/datum/job/american/captain_korean_war/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni_korean(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/american(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/korean/us_cap(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/thompson(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m1911(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/american(H), slot_r_store)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
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

/datum/job/american/lieutenant_korean_war
	title = " US Lieutenant"
	rank_abbreviation = "Lt."

	spawn_location = "JoinLateRNBoatswain"

	is_officer = TRUE
	whitelisted = TRUE
	is_radioman = FALSE
	is_korean_war = TRUE

	min_positions = 1
	max_positions = 2

/datum/job/american/lieutenant_korean_war/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni_korean(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/american(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/korean/us_1lt(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/thompson(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m1911(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/american(H), slot_r_store)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
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
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/american/sergeant_korean_war
	title = " US Sergeant"
	rank_abbreviation = "Sgt."

	spawn_location = "JoinLateRN"

	is_squad_leader = TRUE
	uses_squads = TRUE
	is_radioman = FALSE
	can_get_coordinates = TRUE
	is_korean_war = TRUE

	min_positions = 2
	max_positions = 10

/datum/job/american/sergeant_korean_war/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni_korean(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/american(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/korean/us_2lt(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m1911(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/thompson(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/us_ww2_sgt(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_store)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, lead a squad against the Chinese enemy and follow your CO's orders!")
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

/datum/job/american/medic_korean_war
	title = " US Field Medic"
	rank_abbreviation = "Cpl."

	spawn_location = "JoinLateRNSurgeon"
	is_medic = TRUE
	is_korean_war = TRUE
	uses_squads = TRUE

	min_positions = 2
	max_positions = 8

/datum/job/american/medic_korean_war/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni_korean(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/american(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/korean/us_medic(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m1911(H), slot_l_hand)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/custom/armband/white = new /obj/item/clothing/accessory/custom/armband(null)
	uniform.attackby(white, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. Keep your fellow soldiers healthy and breathing!")
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

/datum/job/american/doctor_korean_war
	title = " US Doctor"
	rank_abbreviation = "2lt."

	spawn_location = "JoinLateRNSurgeon"

	is_medic = TRUE
	is_korean_war = TRUE
	can_be_female = TRUE
	min_positions = 1
	max_positions = 4

/datum/job/american/doctor_korean_war/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni_korean(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/doctor(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/korean/us_medic(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m1911(H), slot_l_hand)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)

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

/datum/job/american/sniper_korean_war
	title = " US Sniper"
	rank_abbreviation = "Pfc."

	spawn_location = "JoinLateRN"

	is_korean_war = TRUE
	uses_squads = TRUE

	min_positions = 2
	max_positions = 8

/datum/job/american/sniper_korean_war/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni_korean(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/american(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/korean/usm1(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/springfield/sniper, slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/us_ww2_sniper(H), slot_belt)
//pocket
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_store)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)

	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, fighting against the Chinese! Keep the enemy off our guys and take out high value targets from a distance!")
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

/datum/job/american/machine_gunner_korean_war
	title = " US Machine Gunner"
	rank_abbreviation = "Pfc."

	spawn_location = "JoinLateRN"

	is_korean_war = TRUE
	uses_squads = TRUE

	min_positions = 2
	max_positions = 8

/datum/job/american/machine_gunner_korean_war/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni_korean(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/american(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/korean/usm1(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/bar(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/us_ww2_gunner(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m1911(H), slot_l_hand)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, carrying a light machine gun. Keep your squad covered!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_VERY_HIGH)
	return TRUE

/datum/job/american/soldier_korean_war
	title = " US Rifleman"
	rank_abbreviation = "Pvt."

	spawn_location = "JoinLateRN"

	is_korean_war = TRUE
	uses_squads = TRUE

	min_positions = 8
	max_positions = 100

/datum/job/american/soldier_korean_war/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni_korean(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/american(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/korean/usm1(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/m1garand(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/us_ww2(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_store)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
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

/datum/job/american/american_radioman_korea
	title = " USA Radio Operator"
	rank_abbreviation = "Cpl."

	spawn_location = "JoinLateRN"

	is_korean_war = TRUE
	is_radioman = TRUE
	uses_squads = TRUE

	min_positions = 1
	max_positions = 5

/datum/job/american/american_radioman_korea/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni_korean(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/american(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/korean/usm1(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/us_ww2_grease(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/greasegun(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction1(H), slot_back)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)

	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, in charge of your squad communications. Keep the line open between the <b>Squad Leader</b> and HQ!")
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

/////////////////////SIBERIAD//////////////////////////////////

/datum/job/american/siberiad/lt
	title = "Operation lead"
	en_meaning = "Operation lead"
	rank_abbreviation = "Opl."
	spawn_location = "JoinLateFAR"

	is_siberiad = TRUE
	is_commander = TRUE
	is_officer = TRUE

	uses_squads = TRUE
	whitelisted = TRUE

	additional_languages = list("Russian" = 70)
	min_positions = 1
	max_positions = 1

/datum/job/american/siberiad/lt/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/usmc(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo_ucp(H), slot_w_uniform)
//thermal
	H.equip_to_slot_or_del(new /obj/item/clothing/glasses/thermal(H), slot_eyes)
//mask
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/headscarfgrey/white(H), slot_wear_mask)
//gun
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/special/mk18(H), slot_shoulder)
//belt
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/mk18(H), slot_belt)
//helmet
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt/white(H), slot_head)
//glove
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/leather/white(H), slot_gloves)
//id
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
//other shit
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/french/red = new /obj/item/clothing/accessory/armband/french(null)
	uniform.attackby(red, H)
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/blizzard/armour2 = new /obj/item/clothing/accessory/armor/coldwar/pasgt/blizzard(null)
	uniform.attackby(armour2, H)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/rucksack/small/commandami(H), slot_back)

	H.civilization = "Coalition"
	H.add_note("Role", "You are a <b>[title]</b>. Command your men and lead them well, Your men count on you!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_MEDIUM_LOW)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_HIGH)
	give_random_name(H)

	return TRUE

/datum/job/american/siberiad/squadlead
	title = "Infantry Squad leader"
	en_meaning = "Infantry Squad leader"
	rank_abbreviation = "Sl."
	spawn_location = "JoinLateFAR"

	is_siberiad = TRUE
	is_squad_leader = TRUE

	uses_squads = TRUE
	whitelisted = FALSE

	additional_languages = list("Russian" = 20)
	min_positions = 2
	max_positions = 8

/datum/job/american/siberiad/squadlead/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/usmc(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo_ucp(H), slot_w_uniform)
//thermal
	H.equip_to_slot_or_del(new /obj/item/clothing/glasses/tactical_goggles/ballistic(H), slot_eyes)
//mask
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/headscarfgrey/asbestos(H), slot_wear_mask)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/french/red = new /obj/item/clothing/accessory/armband/french(null)
	uniform.attackby(red, H)
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/blizzard/armour2 = new /obj/item/clothing/accessory/armor/coldwar/pasgt/blizzard(null)
	uniform.attackby(armour2, H)
//gun
	var/randimpw = rand(1,2)
	switch(randimpw)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m16(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/olive/m16_grenade(H), slot_belt)
			var/obj/item/clothing/accessory/storage/webbing/us_vest/m16/webbing = new /obj/item/clothing/accessory/storage/webbing/us_vest/m16(null)
			uniform.attackby(webbing, H)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m16/commando/m4mws/att(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/olive/m16/sf(H), slot_belt)
			var/obj/item/clothing/accessory/storage/webbing/us_vest/m16/webbing = new /obj/item/clothing/accessory/storage/webbing/us_vest/m16(null)
			uniform.attackby(webbing, H)
//helmet
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ach/white(H), slot_head)
//glove
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)
//id
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
//other shit
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_r_store)
//suit
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/fur/m05(H), slot_wear_suit)
//back
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/rucksack/small/medical(H), slot_back)
	else if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/rucksack/small/extracap/medicalh(H), slot_back)
	H.civilization = "Coalition"
	H.add_note("Role", "You are a <b>[title]</b>. Take orders from your Operation Leader and lead your squad towards victory!")
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_MEDIUM_LOW)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)
	give_random_name(H)

	return TRUE

/datum/job/american/siberiad/heavy
	title = "Heavy infantry"
	en_meaning = "Heavy infantry"
	rank_abbreviation = "Mg."
	spawn_location = "JoinLateFAR"

	is_siberiad = TRUE

	uses_squads = TRUE
	whitelisted = FALSE

	additional_languages = list("Russian" = 10)
	min_positions = 4
	max_positions = 8

/datum/job/american/siberiad/heavy/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/usmc(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo_ucp(H), slot_w_uniform)
//thermal
	H.equip_to_slot_or_del(new /obj/item/clothing/glasses/tactical_goggles/ballistic(H), slot_eyes)
//mask
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/headscarfgrey/asbestos(H), slot_wear_mask)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/french/red = new /obj/item/clothing/accessory/armband/french(null)
	uniform.attackby(red, H)
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/blizzard/armour2 = new /obj/item/clothing/accessory/armor/coldwar/pasgt/blizzard(null)
	uniform.attackby(armour2, H)
//gun
	var/randimpw = rand(1,3)
	switch(randimpw)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/m60(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/olive/m60(H), slot_belt)
			var/obj/item/clothing/accessory/storage/webbing/us_vest/m60/webbing = new /obj/item/clothing/accessory/storage/webbing/us_vest/m60(null)
			uniform.attackby(webbing, H)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/m249(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/green/m249(H), slot_belt)
			var/obj/item/clothing/accessory/storage/webbing/us_vest/m249/webbing = new /obj/item/clothing/accessory/storage/webbing/us_vest/m249(null)
			uniform.attackby(webbing, H)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/c6(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c6belt(H), slot_belt)
			var/obj/item/clothing/accessory/storage/webbing/us_vest/c6/webbing = new /obj/item/clothing/accessory/storage/webbing/us_vest/c6(null)
			uniform.attackby(webbing, H)
//helmet
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ach/white(H), slot_head)
//glove
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)
//id
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
//suit
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/fur/m05(H), slot_wear_suit)
//other shit
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_r_store)

	H.civilization = "Coalition"
	H.add_note("Role", "You are a <b>[title]</b>.As a heavy infantryman You Provide Firepower and Suppresive fire for your squad!")
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_MEDIUM_LOW)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)
	give_random_name(H)

	return TRUE

/datum/job/american/siberiad/infantry
	title = "Light Infantry"
	en_meaning = "Light Infantry"
	rank_abbreviation = " ."
	spawn_location = "JoinLateFAR"

	is_siberiad = TRUE

	uses_squads = TRUE
	whitelisted = FALSE

	additional_languages = list("Russian" = 10)
	min_positions = 9
	max_positions = 90

/datum/job/american/siberiad/infantry/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/usmc(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo_ucp(H), slot_w_uniform)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/french/red = new /obj/item/clothing/accessory/armband/french(null)
	uniform.attackby(red, H)
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/blizzard/armour2 = new /obj/item/clothing/accessory/armor/coldwar/pasgt/blizzard(null)
	uniform.attackby(armour2, H)
//gun
	var/randimpw = rand(1,5)
	switch(randimpw)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/m1garand(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/grenade/coldwar/nonfrag/m26(H), slot_belt)
			var/obj/item/clothing/accessory/storage/webbing/us_ww2/garand/webbing = new /obj/item/clothing/accessory/storage/webbing/us_ww2/garand(null)
			uniform.attackby(webbing, H)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m16(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/olive/m16_smoke(H), slot_belt)
			var/obj/item/clothing/accessory/storage/webbing/us_vest/m16/webbing = new /obj/item/clothing/accessory/storage/webbing/us_vest/m16(null)
			uniform.attackby(webbing, H)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/sten(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/sten(H), slot_belt)
			var/obj/item/clothing/accessory/storage/webbing/us_vest/sten/webbing = new /obj/item/clothing/accessory/storage/webbing/us_vest/sten(null)
			uniform.attackby(webbing, H)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/springfield(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/ammo_magazine/springfield(H), slot_belt)
			var/obj/item/clothing/accessory/storage/webbing/us_vest/springfield/webbing = new /obj/item/clothing/accessory/storage/webbing/us_vest/springfield(null)
			uniform.attackby(webbing, H)
		if (5)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/m1garand/match(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/grenade/coldwar/m67(H), slot_belt)
			var/obj/item/clothing/accessory/storage/webbing/us_ww2/garand/webbing = new /obj/item/clothing/accessory/storage/webbing/us_ww2/garand(null)
			uniform.attackby(webbing, H)
//helmet
	if (prob(45))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt/white(H), slot_head)
	else if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ach/white(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/us_tanker(H), slot_head)
//glove
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)
//suit
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/fur/m05(H), slot_wear_suit)
//back
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/rucksack/small/milpack(H), slot_back)

	H.civilization = "Coalition"
	H.add_note("Role", "You are a <b>[title]</b>. Follow your Squad Leader and his orders!")
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_NORMAL)
	give_random_name(H)

	return TRUE
