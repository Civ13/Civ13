/////////ATF//////////////
/datum/job/american/atf_lieutenant
	title = "ATF Lieutenant"
	rank_abbreviation = "Lt."

	spawn_location = "JoinLateJPCap"

	is_waco = TRUE
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	can_be_female = TRUE

	min_positions = 1
	max_positions = 2

/datum/job/american/atf_lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/tactical1(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/atf(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/cap/atf(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40/mp5(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/glock17(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.civilization = "ATF"
	H.add_note("Role", "You are a <b>[title]</b>. You are in charge of the whole operation. Organize your troops accordingly!")
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

/datum/job/american/atf_sergeant
	title = "ATF Sergeant"
	rank_abbreviation = "Sgt."

	spawn_location = "JoinLateJP"

	is_waco = TRUE
	is_squad_leader = TRUE
	uses_squads = TRUE
	is_radioman = TRUE
	can_be_female = TRUE

	can_get_coordinates = TRUE

	min_positions = 2
	max_positions = 8

/datum/job/american/atf_sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/tactical1(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/atf(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/swat(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40/mp5(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/glock17(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/police/modern(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	//armor
	var/obj/item/clothing/accessory/armor/nomads/civiliankevlar/under/armor = new /obj/item/clothing/accessory/armor/nomads/civiliankevlar/under(null)
	uniform.attackby(armor, H)

	give_random_name(H)
	H.civilization = "ATF"
	H.add_note("Role", "You are a <b>[title]</b>, lead a squad against the Davidians!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/american/atf_soldier
	title = "ATF Agent"
	rank_abbreviation = "Agent"

	spawn_location = "JoinLateJP"

	is_waco = TRUE

	uses_squads = TRUE
	can_be_female = TRUE
	min_positions = 10
	max_positions = 100

/datum/job/american/atf_soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/tactical1(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/atf(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/nomads/civiliankevlar/under/armor = new /obj/item/clothing/accessory/armor/nomads/civiliankevlar/under(null)
	uniform.attackby(armor, H)

//head
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/cap/atf(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/swat(H), slot_head)
//back
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m16(H), slot_shoulder)
	else if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40/mp5(H), slot_shoulder)
	else if (prob(20))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m14(H), slot_shoulder)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/shotgun/pump/remington870(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/police/modern(H), slot_belt)
	give_random_name(H)
	H.civilization = "ATF"
	H.add_note("Role", "You are a <b>[title]</b>, a ATF soldier. Follow orders and secure the home!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE

	/*
//////////SPECIAL ATF//////////
/datum/job/american/negotiator
	title = "ATF Negotiator"
	rank_abbreviation = "Agent"

	spawn_location = "JoinLateNegotiator"

	is_waco = TRUE
	whitelisted = TRUE
	can_be_female = TRUE

	min_positions = 1
	max_positions = 2

/datum/job/american/negotiator/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/modern2(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/atf(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/cap/atf(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses(H), slot_eyes)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m9beretta(H), slot_l_hand)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/interceptor/armor = new /obj/item/clothing/accessory/armor/coldwar/plates/interceptor(null)
	uniform.attackby(armor, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.civilization = "ATF"
	H.add_note("Role", "You are a <b>[title]</b>, a ATF Negotiator tasked with calming the branch davidian leader to prevent any deaths.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE
*/
/datum/job/american/atf_medic
	title = "ATF Medic"
	rank_abbreviation = "Medic"

	spawn_location = "JoinLateJPDoc"

	is_medic = TRUE
	is_waco = TRUE
	can_be_female = TRUE

	min_positions = 2
	max_positions = 8

/datum/job/american/atf_medic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/modern2(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/doctor(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/cap/atf(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat/modern(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/glock17(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/custom/armband/medicalarm = new /obj/item/clothing/accessory/armband/redcross(null)
	uniform.attackby(medicalarm, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armor/coldwar/plates/interceptor/ocp/ocp_armor = new /obj/item/clothing/accessory/armor/coldwar/plates/interceptor/ocp(null)
	uniform.attackby(ocp_armor, H)
	give_random_name(H)
	H.civilization = "ATF"
	H.add_note("Role", "You are a <b>[title]</b>. Keep your fellow ATF healthy!")
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

////////////BRANCH DAVIDIANS/////////////
/datum/job/civilian/cult_leader
	title = "Messiah"
	en_meaning = ""
	rank_abbreviation = "Great Prophet"

	spawn_location = "JoinLateRUCap"
	is_waco = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	can_be_female = FALSE

	min_positions = 1
	max_positions = 1

/datum/job/civilian/cult_leader/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leather(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial5(H), slot_w_uniform)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ph_us_war/american/infantry_hat/civie(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/glasses/regular(H), slot_eyes)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/watch/goldwatch(H), slot_gloves)
	H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/gauze(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/glock17(H), slot_belt)
	H.civilization = "Faithful"
	H.add_note("Role", "You are the great messiah who will save the people, stay alive at all costs!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_NORMAL)
	H.real_name = "David Koresh"
	H.h_style = "Volaju"
	H.f_style = "Shaved"
	var/new_hair = pick("Dark Brown")
	var/hex_hair = hair_colors[new_hair]
	H.r_hair = hex2num(copytext(hex_hair, 2, 4))
	H.g_hair = hex2num(copytext(hex_hair, 4, 6))
	H.b_hair = hex2num(copytext(hex_hair, 6, 8))
	H.r_facial = hex2num(copytext(hex_hair, 2, 4))
	H.g_facial = hex2num(copytext(hex_hair, 4, 6))
	H.b_facial = hex2num(copytext(hex_hair, 6, 8))
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/nomads/civiliankevlar/under/armor = new /obj/item/clothing/accessory/armor/nomads/civiliankevlar/under(null)
	uniform.attackby(armor, H)
	if (map && map.ID == MAP_WACO)
		if (map.gamemode == "Protect the VIP")
			var/obj/map_metadata/waco/WA = map
			WA.HVT_list |= H
		return TRUE


/datum/job/civilian/believer
	title = "David Follower"
	en_meaning = ""
	rank_abbreviation = "Follower"
	spawn_location = "JoinLateRU"
	min_positions = 10
	max_positions = 150
	is_waco = TRUE
	can_be_female = TRUE

/datum/job/civilian/believer/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
//clothes
	var/randjack = rand(1,4)
	if (randjack == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
	else if (randjack == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial1(H), slot_w_uniform)
	else if (randjack == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial4(H), slot_w_uniform)
	else if (randjack == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/modern3(H), slot_w_uniform)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/randarm = rand(1,2)
	if (randarm == 1)
		var/obj/item/clothing/accessory/armor/coldwar/pasgt/khaki/pasgt_armor = new /obj/item/clothing/accessory/armor/coldwar/pasgt/khaki(null)
		uniform.attackby(pasgt_armor, H)
	else if (randarm == 2)
		var/obj/item/clothing/accessory/armor/coldwar/plates/platecarrierblack/plate_armor = new /obj/item/clothing/accessory/armor/coldwar/plates/platecarrierblack(null)
		uniform.attackby(plate_armor, H)
	else if (randarm == 3)
		var/obj/item/clothing/accessory/armor/coldwar/plates/platecarriergreen/plate_armor = new /obj/item/clothing/accessory/armor/coldwar/plates/platecarriergreen(null)
		uniform.attackby(plate_armor, H)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
//head
	if (prob(5))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/cowboyhat2(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/cap(H), slot_head)
//gunz
	if(prob(60))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m16(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/us_stanag(H), slot_belt)
	else if (prob(20))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak47(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/ak47(H), slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74/aks74/aks74u(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/ak74(H), slot_belt)
	H.civilization = "Faithful"
	H.add_note("Role", "You are a <b>[title]</b>, Protecting your home against the evil government!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/civilian/disciple
	title = "David Desciple"
	en_meaning = ""
	rank_abbreviation = "Follower"
	spawn_location = "JoinLateRU"
	min_positions = 10
	max_positions = 150
	is_waco = TRUE
	can_be_female = TRUE

/datum/job/civilian/disciple/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)

//clothes
	if (prob(40))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/modern2(H), slot_w_uniform)
	else if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/warband2(H), slot_w_uniform)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/farmer_outfit(H), slot_w_uniform)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
//head
	if (prob(25))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/cowboyhat(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/cap(H), slot_head)
//eyewear
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses(H), slot_eyes)
//gunz
	if (prob(40))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/shotgun/pump/remington870(H), slot_shoulder)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/shotgun/pump(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/shellbox/slug(H), slot_belt)

	H.civilization = "Faithful"
	H.add_note("Role", "You are a <b>[title]</b>, Protecting your home from the goverment scum!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/civilian/healer
	title = "Healer"
	en_meaning = ""
	rank_abbreviation = "Healer"

	spawn_location = "JoinLateRUDoc"

	is_medic = TRUE
	is_waco = TRUE

	min_positions = 3
	max_positions = 10

/datum/job/civilian/healer/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/modern7(H), slot_w_uniform)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat/modern(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m9beretta(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)

	if (H.f_style != "Full Beard" && H.f_style != "Medium Beard" && H.f_style != "Long Beard")
		H.f_style = pick("Full Beard","Medium Beard","Long Beard")
	H.civilization = "Faithful"
	H.add_note("Role", "You are a <b>[title]</b>. Keep your fellow believers healthy!")
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
