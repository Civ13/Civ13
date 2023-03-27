/datum/job/finnish
	faction = "Human"

/datum/job/finnish/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_finnish_name(H.gender)
	H.real_name = H.name

/datum/job/finnish/kapteeni
	title = "Kapteeni"
	en_meaning = "Captain"
	rank_abbreviation = "Kap."


	spawn_location = "JoinLateGECap"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE

	is_karelia = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/finnish/kapteeni/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/japboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/finnish(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/fur/white(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka/nomads(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/waltherp38(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_r_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	world << "<b><big>[H.real_name] is the commander of the Finnish Forces!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, the highest ranking officer present. Your job is to command the german troops and organize them to victory.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/finnish/luutnantti
	title = " Luutnantti"
	en_meaning = "First Lieutenant"
	rank_abbreviation = "Luut."


	spawn_location = "JoinLateGECap"
	is_officer = TRUE
	whitelisted = TRUE

	is_karelia = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/finnish/luutnantti/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/japboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/finnish(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/fur/white(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka/nomads(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/waltherp38(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/german(H), slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, the second highest ranking officer present. Your job is to command the finnish troops and organize them to victory according to the kapteeni's orders.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/finnish/vanrikki
	title = "Vanrikki"
	en_meaning = "Second Lieutenant"
	rank_abbreviation = "Lt."


	spawn_location = "JoinLateGECap"
	is_officer = TRUE
	whitelisted = TRUE

	is_karelia = TRUE

	min_positions = 1
	max_positions = 2

/datum/job/finnish/vanrikki/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/japboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/finnish(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/fur/white(H), slot_wear_suit)
//head
	if (prob(20))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka/nomads(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/foxpelt/white(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/waltherp38(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/german(H), slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, the second highest ranking officer present. Your job is to command the finnish troops and organize them to victory according to the kapteeni's orders.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/finnish/kersantti
	title = "Kersantti"
	en_meaning = "Squad Leader"
	rank_abbreviation = "Ker."

	spawn_location = "JoinLateGE"
	is_squad_leader = TRUE
	is_karelia = TRUE
	uses_squads = TRUE

	min_positions = 2
	max_positions = 12

/datum/job/finnish/kersantti/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/japboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/finnish(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/fur/white(H), slot_wear_suit)
//head
	if (prob(25))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka/nomads(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/foxpelt/white(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40(H), slot_belt)
	var/obj/item/clothing/accessory/storage/webbing/ww1/german/fullwebbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(fullwebbing, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a sergeant leading a squad. Organize your group according to the <b>kapteeni's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/finnish/sotamies
	title = "Sotamies"
	en_meaning = "Soldier"
	rank_abbreviation = ""

	spawn_location = "JoinLateGE"

	is_karelia = TRUE
	uses_squads = TRUE

	min_positions = 8
	max_positions = 70

/datum/job/finnish/sotamies/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/japboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/finnish(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/fur/white(H), slot_wear_suit)
//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/gerhelm/winter(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/foxpelt/white(H), slot_head)
//back
	if (prob(45))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40(H), slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin(H), slot_shoulder)
	var/obj/item/clothing/accessory/storage/webbing/ww1/german/fullwebbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(fullwebbing, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a simple soldier of the Maavoimat forces. Follow your <b>Sergeant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_VERY_HIGH)


	return TRUE

/datum/job/finnish/salaampuja
	title = "Ampuja"
	en_meaning = "Sniper"
	rank_abbreviation = ""

	spawn_location = "JoinLateGE"

	is_karelia = TRUE
	uses_squads = TRUE

	min_positions = 2
	max_positions = 12

/datum/job/finnish/salaampuja/equip(var/mob/living/human/H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/japboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/finnish(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/fur/white(H), slot_wear_suit)

//head
	if (prob(85))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/gerhelm/winter(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/foxpelt/white(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin(H), slot_shoulder)
//pockets
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/sniper_scope(H), slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/ww1/german/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german(null)
	if (map.ID == MAP_STALINGRAD)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/german(H), slot_wear_suit)
	uniform.attackby(webbing, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a sniper of the Maavoimat forces,take out high ranking soviets,provide supressing fire,and follow your <b>Sergeant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/finnish/itpar
	title = "Taistelulaakari"
	en_meaning = "Combat Medic"
	rank_abbreviation = "Dr."

	spawn_location = "JoinLateGEDoc"

	is_medic = TRUE
	is_karelia = TRUE


	min_positions = 2
	max_positions = 4

/datum/job/finnish/itpar/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/japboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/finnish(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/doctor(H), slot_wear_suit)
//head
	if (prob(25))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/gerhelm/winter(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/gerhelm_medic(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/waltherp38(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_belt)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/redcross/armband = new /obj/item/clothing/accessory/armband/redcross(null)
	uniform.attackby(armband, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, the most qualified medic present, and you are in charge of keeping the soldiers healthy.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)


	return TRUE

/datum/job/finnish/Pioneeri
	title = "Pioneeri"
	en_meaning = "Sapper"
	rank_abbreviation = ""

	spawn_location = "JoinLateGESap"
	is_karelia = TRUE

	min_positions = 2
	max_positions = 12

/datum/job/finnish/Pioneeri/equip(var/mob/living/human/H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/japboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/finnish(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/fur/white(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/leather/white(H), slot_gloves)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/gerhelm/winter(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/glasses/pilot(H), slot_eyes)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/utility/sapper(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/waltherp38(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/ww2/sapper/german(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/drinks/bottle/canteen/ww2/german(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/hip = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(hip, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a sapper of the Maavoimat forces. Place mines, sabotage the soviets,ambush the soviets,and steal soviet equiptment!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_VERY_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_VERY_HIGH)

	return TRUE