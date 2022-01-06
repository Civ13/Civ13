/datum/job/civilian/ukrainian
	faction = "Human"
	default_language = "Ukrainian"
	additional_languages = list("English" = 25, "Russian" = 85, "German" = 65)
	male_tts_voice = "Maxim"
	female_tts_voice = "Tatyana"
	spawn_location = "JoinLateCiv"

/datum/job/civilian/ukrainian/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_ukrainian_name(H.gender)
	H.real_name = H.name

/datum/job/civilian/ukrainian/upa_officer
	title = "UPA Khorunzhyj"
	en_meaning = "UPA 2nd Lieutenant"
	rank_abbreviation = "Khj."

	spawn_location = "JoinLateCiv"

	is_officer = TRUE
	whitelisted = TRUE
	is_commander = TRUE
	is_ww2 = TRUE
	is_upa = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/civilian/ukrainian/upa_officer/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/upa/off(H), slot_w_uniform)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/upa_cap_commander(H), slot_head)
//back
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	holsterh.attackby(new/obj/item/weapon/gun/projectile/pistol/waltherp38, H)
	var/obj/item/clothing/accessory/rank/upa_lt = new /obj/item/clothing/accessory/rank/upa_lt(null)
	uniform.attackby(upa_lt, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ppsh(H), slot_l_hand)
	give_random_name(H)
	H.s_tone = rand(-35,-25)
	H.add_note("Role", "You are a <b>[title]</b>, lead the UPA in the fight against the invaders!")
	H.add_note("Partisan Mechanics", "- Press <b>C</b> to place a booby trap while holding a grenade.")
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

/datum/job/civilian/ukrainian/upa_doctor
	title = "UPA Likar"
	en_meaning = "UPA Doctor"
	rank_abbreviation = "Buj."
	can_be_female = TRUE
	spawn_location = "JoinLateCiv"

	is_medic = TRUE
	is_ww2 = TRUE
	is_upa = TRUE

	min_positions = 2
	max_positions = 2

/datum/job/civilian/ukrainian/upa_doctor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/upa(H), slot_w_uniform)

//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/gerhelm_medic(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/upa_cap(H), slot_head)

//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/waltherp38(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/doctor(H), slot_wear_suit)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/rank/upa_sgt = new /obj/item/clothing/accessory/rank/upa_sgt(null)
	uniform.attackby(upa_sgt, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.s_tone = rand(-35,-25)
	H.add_note("Role", "You are a <b>[title]</b>. Keep your comrades healthy!")
	H.add_note("Partisan Mechanics", "- Press <b>C</b> to place a booby trap while holding a grenade.")
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

/datum/job/civilian/ukrainian/sergeant_upa
	title = "UPA Vistun"
	en_meaning = "UPA Sergeant"
	rank_abbreviation = "Vtn."
	can_be_female = TRUE
	spawn_location = "JoinLateCiv"

	is_ww2 = TRUE
	uses_squads = TRUE
	is_squad_leader = TRUE
	is_upa = TRUE

	min_positions = 1
	max_positions = 2

/datum/job/civilian/ukrainian/sergeant_upa/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/upa(H), slot_w_uniform)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/upa_cap_off(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40(H), slot_l_hand)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/rank/upa_sgt = new /obj/item/clothing/accessory/rank/upa_sgt(null)
	uniform.attackby(upa_sgt, H)
	var/obj/item/clothing/accessory/storage/webbing/ww1/germanh = new /obj/item/clothing/accessory/storage/webbing/ww1/german(null)
	uniform.attackby(germanh, H)
	germanh.attackby(/obj/item/ammo_magazine/mp40, H)
	germanh.attackby(/obj/item/ammo_magazine/mp40, H)
	germanh.attackby(/obj/item/ammo_magazine/mp40, H)
	germanh.attackby(/obj/item/weapon/grenade/ww2/stg1924, H)
	give_random_name(H)
	H.s_tone = rand(-35,-25)

	H.add_note("Role", "You are a <b>[title]</b>, a sergeant in the Ukrayins'ka Povstans'ka Armiya, in charge of a squad.")
	H.add_note("Partisan Mechanics", "- Press <b>C</b> to place a booby trap while holding a grenade.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_VERY_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	H.setStat("stamina", STAT_VERY_HIGH)

	return TRUE

/datum/job/civilian/ukrainian/upa_infantry
	title = "UPA Strilets"
	en_meaning = "UPA Infantry"
	rank_abbreviation = ""

	spawn_location = "JoinLateCiv"
	can_be_female = TRUE
	is_ww2 = TRUE
	uses_squads = TRUE
	is_upa = TRUE

	min_positions = 5
	max_positions = 15

/datum/job/civilian/ukrainian/upa_infantry/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/upa(H), slot_w_uniform)
//head
	if (prob(70))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/upa_pilotka(H), slot_head)
	else if (prob(10))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/upa_cap(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka/nomads(H), slot_head)
//back
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/pickgun = rand(1,4)
	if (pickgun == 1)
		var/obj/item/clothing/accessory/storage/webbing/ww1/germanh = new /obj/item/clothing/accessory/storage/webbing/ww1/german(null)
		uniform.attackby(germanh, H)
		germanh.attackby(/obj/item/ammo_magazine/mp40, H)
		germanh.attackby(/obj/item/ammo_magazine/mp40, H)
		germanh.attackby(/obj/item/ammo_magazine/mp40, H)
		germanh.attackby(/obj/item/weapon/grenade/ww2/stg1924, H)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40(H), slot_shoulder)
	else if (pickgun == 2)
		var/obj/item/clothing/accessory/storage/webbing/ww1/germanh = new /obj/item/clothing/accessory/storage/webbing/ww1/german(null)
		uniform.attackby(germanh, H)
		germanh.attackby(/obj/item/ammo_magazine/mg34, H)
		germanh.attackby(/obj/item/ammo_magazine/mg34, H)
		germanh.attackby(/obj/item/ammo_magazine/mg34, H)
		germanh.attackby(/obj/item/weapon/grenade/ww2/stg1924, H)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/mg34(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mg34belt(H), slot_belt)
	else if (pickgun == 3 && prob(10))
		var/obj/item/clothing/accessory/storage/webbing/ww1/germanh = new /obj/item/clothing/accessory/storage/webbing/ww1/german(null)
		uniform.attackby(germanh, H)
		germanh.attackby(/obj/item/ammo_magazine/c762x25_ppsh, H)
		germanh.attackby(/obj/item/ammo_magazine/c762x25_ppsh, H)
		germanh.attackby(/obj/item/ammo_magazine/c762x25_ppsh, H)
		germanh.attackby(/obj/item/weapon/grenade/ww2/stg1924, H)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ppsh(H), slot_shoulder)
	else if (pickgun == 4)
		var/obj/item/clothing/accessory/storage/webbing/ww1/germanh = new /obj/item/clothing/accessory/storage/webbing/ww1/german(null)
		uniform.attackby(germanh, H)
		germanh.attackby(/obj/item/ammo_magazine/gewehr98, H)
		germanh.attackby(/obj/item/ammo_magazine/gewehr98, H)
		germanh.attackby(/obj/item/ammo_magazine/gewehr98, H)
		germanh.attackby(/obj/item/weapon/grenade/ww2/stg1924, H)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98/karabiner98k(H), slot_shoulder)
	else
		var/obj/item/clothing/accessory/storage/webbing/ww1/germanh = new /obj/item/clothing/accessory/storage/webbing/ww1/german(null)
		uniform.attackby(germanh, H)
		germanh.attackby(/obj/item/ammo_magazine/gewehr98, H)
		germanh.attackby(/obj/item/ammo_magazine/gewehr98, H)
		germanh.attackby(/obj/item/ammo_magazine/gewehr98, H)
		germanh.attackby(/obj/item/weapon/grenade/ww2/stg1924, H)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98/karabiner98k(H), slot_shoulder)
	give_random_name(H)
	H.s_tone = rand(-35,-25)
	H.add_note("Role", "You are a <b>[title]</b>, a soldier in the Ukrayins'ka Povstans'ka Armiya. Fight for the freedom of <b>Ukraine</b>!")
	H.add_note("Partisan Mechanics", "- Press <b>C</b> to place a booby trap while holding a grenade.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_LOW)

	return TRUE