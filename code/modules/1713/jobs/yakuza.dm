/datum/job/japanese/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_japanese_name(H.gender)
	H.real_name = H.name

/datum/job/japanese/yakuza_underboss
	title = "Yama Wakagashira"
	en_meaning = "Underboss"
	rank_abbreviation = "Wakagashira"
	spawn_location = "JoinLateJPCap"
	whitelisted = TRUE
	is_commander = TRUE
	is_officer = TRUE
	min_positions = 1
	max_positions = 1
	is_yakuza = TRUE
	is_yama = TRUE

/datum/job/japanese/yakuza_underboss/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/peakyblinder(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/charcoal_suit(H), slot_wear_suit)
//head
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m9beretta(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/japanese(H), slot_r_store)
	if (prob(35))
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/silencer/pistol(H), slot_l_store)
	else
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m9beretta(H), slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.civilization = "Yamaguchi-Gumi"
	give_random_name(H)
	world << "<b><font color='yellow' size=3>[H.real_name] is the Underboss of the Yamaguchi-Gumi!</font></b>"
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the gangmen and their orders. The whole operation relies on you!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	if (prob(35))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/fedora(H), slot_head)
	else
		return


	return TRUE

/datum/job/japanese/yakuza_underboss_deputy
	title = "Yama Wakagashira-Hosa"
	en_meaning = "Deputy underboss"
	rank_abbreviation = "Wa-Ho"
	spawn_location = "JoinLateJP"
	whitelisted = TRUE

	is_officer = TRUE
	is_squad_leader = TRUE
	is_yakuza = TRUE
	min_positions = 1
	max_positions = 2
	is_yama = TRUE

/datum/job/japanese/yakuza_underboss_deputy/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/peakyblinder(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/charcoal_suit(H), slot_wear_suit)
//head
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m9beretta(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/japanese(H), slot_r_store)
	if (prob(15))
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/silencer/pistol(H), slot_l_store)
	else
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m9beretta(H), slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.civilization = "Yamaguchi-Gumi"
	give_random_name(H)
	world << "<b><font color='yellow' size=3>[H.real_name] is the Deputy Underboss of the Yamaguchi-Gumi Gang!!</font></b>"
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the gangmen and their orders. Second to underboss. The whole operation relies on you and your orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	if (prob(25))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/fedora(H), slot_head)
	else
		return


	return TRUE

/datum/job/japanese/yakuza
	title = "Yamaguchi-Gumi Kaiin"
	en_meaning = "Yamaguchi-Gumi Member"
	rank_abbreviation = ""
	spawn_location = "JoinLateJP"
	min_positions = 12
	max_positions = 48
	is_yakuza = TRUE
	is_yama = TRUE
/datum/job/japanese/yakuza/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new/obj/item/clothing/under/modern2(H), slot_w_uniform)

//head
//jacket

	var/randjack = rand(1,2)
	if (randjack == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/charcoal_suit(H), slot_wear_suit)
	else if (randjack == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/blackvest(H), slot_wear_suit)
//back
	if (prob(5))
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/silencer/pistol(H), slot_l_store)
	else
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m9beretta(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m9beretta(H), slot_l_hand)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.civilization = "Yamaguchi-Gumi"
	H.add_note("Role", "You are a <b>[title]</b>, a gang member employed by Yamaguchi-Gumi Clan. Follow your <b>Underboss'</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)
	if (prob(25))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/fedora(H), slot_head)
	else
		return
	return TRUE
/////////////////////////////////////////////////////////////////////////ICHI/////////////////////////////////////////////////////
/datum/job/japanese/yakuza_underboss_ichi
	title = "Ichi Wakagashira"
	en_meaning = "Underboss"
	rank_abbreviation = "Wakagashira"
	spawn_location = "JoinLateRNCap"
	whitelisted = TRUE
	is_commander = TRUE
	is_officer = TRUE
	min_positions = 1
	max_positions = 1
	is_yakuza = TRUE
	is_ichi = TRUE
/datum/job/japanese/yakuza_underboss_ichi/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/peakyblinder(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/charcoal_suit(H), slot_wear_suit)
//head
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m9beretta(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/japanese_officer(H), slot_r_store)
	if (prob(35))
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/silencer/pistol(H), slot_l_store)
	else
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m9beretta(H), slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.civilization = "Ichiwa-Kai"
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	world << "<b><font color='yellow' size=3>[H.real_name] is the Underboss of the Ichiwa-Kai!</font></b>"
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the gangmen and their orders. The whole operation relies on you!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	if (prob(35))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/fedora(H), slot_head)
	else
		return
	return TRUE

/datum/job/japanese/yakuza_underboss_deputy_ichi
	title = "Ichi Wakagashira-Hosa"
	en_meaning = "Deputy underboss"
	rank_abbreviation = "Wa-Ho"
	spawn_location = "JoinLateRN"
	whitelisted = TRUE

	is_officer = TRUE
	is_squad_leader = TRUE

	min_positions = 1
	max_positions = 2
	is_yakuza = TRUE
	is_ichi = TRUE
/datum/job/japanese/yakuza_underboss_deputy_ichi/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/peakyblinder(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/charcoal_suit(H), slot_wear_suit)
//head
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m9beretta(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/japanese_officer(H), slot_r_store)
	if (prob(15))
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/silencer/pistol(H), slot_l_store)
	else
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m9beretta(H), slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	H.civilization = "Ichiwa-Kai"
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	give_random_name(H)
	world << "<b><font color='yellow' size=3>[H.real_name] is the Deputy Underboss of the Ichiwa-Kai Gang!!</font></b>"
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the gangmen and their orders. Second to underboss. The whole operation relies on you and your orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	if (prob(25))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/fedora(H), slot_head)
	else
		return
	return TRUE

/datum/job/japanese/yakuza_ichi
	title = "Ichiwa-Kai Kaiin"
	en_meaning = "Ichiwa-Kai Member"
	rank_abbreviation = ""
	spawn_location = "JoinLateRN"
	min_positions = 12
	max_positions = 48
	is_yakuza = TRUE
	is_ichi = TRUE
/datum/job/japanese/yakuza_ichi/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new/obj/item/clothing/under/modern2(H), slot_w_uniform)

//head
//jacket

	var/randjack = rand(1,2)
	if (randjack == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/blackvest(H), slot_wear_suit)
	else if (randjack == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/black_suit(H), slot_wear_suit)
//back
	if (prob(5))
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/silencer/pistol(H), slot_l_store)
	else
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m9beretta(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m9beretta(H), slot_l_hand)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	H.civilization = "Ichiwa-Kai"
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a gang member employed by Ichiwa-Kai Clan. Follow your <b>Underboss'</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)
	return TRUE