/datum/job/american/union_captain
	title = "Union Captain"
	rank_abbreviation = "Cpt."

	spawn_location = "JoinLateRNCap"
	is_civil_war = TRUE
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_radioman = FALSE
	is_ww2 = FALSE

	min_positions = 1
	max_positions = 1

/datum/job/american/union_captain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/union_uniform(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/unionhatlight(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/capnball/dragoon(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_hand)
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

/datum/job/american/union_lieutenant
	title = "Union Lieutenant"
	rank_abbreviation = "Lt."

	spawn_location = "JoinLateRNBoatswain"
	is_civil_war = TRUE
	is_officer = TRUE
	is_commander = FALSE
	whitelisted = TRUE
	is_radioman = FALSE
	is_ww2 = FALSE

	min_positions = 1
	max_positions = 2

/datum/job/american/union_lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/union_uniform(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/unionhatlight(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/capnball/dragoon(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_hand)
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

/datum/job/american/union_sergeant
	title = "Union Sergeant"
	rank_abbreviation = "Sgt."

	spawn_location = "JoinLateRN"
	is_squad_leader = TRUE
	uses_squads = TRUE
	is_radioman = FALSE
	can_get_coordinates = FALSE
	is_ww2 = FALSE
	is_civil_war = TRUE

	min_positions = 2
	max_positions = 10

/datum/job/american/union_sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/union_uniform(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/unionhat(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/flintlock/springfield(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/capnball/dragoon(H), slot_belt)
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

/datum/job/american/union_soldier
	title = "Union Rifleman"
	rank_abbreviation = "Pvt."

	spawn_location = "JoinLateRN"
	is_ww2 = FALSE
	uses_squads = TRUE
	is_civil_war = TRUE

	min_positions = 8
	max_positions = 100

/datum/job/american/union_soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/union_uniform(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/unioncap(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/flintlock/springfield(H), slot_shoulder)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/civil_war/fullh = new /obj/item/clothing/accessory/storage/webbing/civil_war/full(null)
	uniform.attackby(fullh, H)
	fullh.attackby(new/obj/item/ammo_casing/musketball, H)
	fullh.attackby(new/obj/item/ammo_casing/musketball, H)
	fullh.attackby(new/obj/item/ammo_casing/musketball, H)
	fullh.attackby(new/obj/item/ammo_casing/musketball, H)
	fullh.attackby(new/obj/item/ammo_casing/musketball, H)
	fullh.attackby(new/obj/item/ammo_casing/musketball, H)
	fullh.attackby(new/obj/item/ammo_casing/musketball, H)
	fullh.attackby(new/obj/item/ammo_casing/musketball, H)
	uniform.attackby(fullh, H)
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

/datum/job/american/union_doctor
	title = "Union Doctor"
	rank_abbreviation = "2lt."

	spawn_location = "JoinLateRNSurgeon"
	is_civil_war = TRUE
	is_medic = TRUE
	is_ww2 = FALSE

	min_positions = 1
	max_positions = 4

/datum/job/american/union_doctor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/capnball/dragoon(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/union_uniform(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/doctor(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/unioncap(H), slot_head)
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

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////CONFEDERATE///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/civilian/confederate_captain
	title = "Confederate Captain"
	rank_abbreviation = "Cpt."

	spawn_location = "JoinLateRUCap"
	is_civil_war = TRUE
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_radioman = FALSE
	is_ww2 = FALSE

	min_positions = 1
	max_positions = 1

/datum/job/civilian/confederate_captain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)

//clothes
	var/randcloth = rand(1,2)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/confederate_uniform/grey(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/confederate_uniform/grey_blue(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/confederatehat(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/capnball/dragoon(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_hand)
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

/datum/job/civilian/confederate_lieutenant
	title = "Confederate Lieutenant"
	rank_abbreviation = "Lt."

	spawn_location = "JoinLateRUSap"
	is_civil_war = TRUE
	is_officer = TRUE
	is_commander = FALSE
	whitelisted = TRUE
	is_radioman = FALSE
	is_ww2 = FALSE

	min_positions = 1
	max_positions = 2

/datum/job/civilian/confederate_lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	var/randshoes = rand(1,2)
	if (randshoes == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)
	else if (randshoes == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding2(H), slot_shoes)

//clothes
	var/randcloth = rand(1,2)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/confederate_uniform/grey(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/confederate_uniform/grey_blue(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/confederatehat(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/capnball/dragoon(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_hand)
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

/datum/job/civilian/confederate_sergeant
	title = "Confederate Sergeant"
	rank_abbreviation = "Sgt."

	spawn_location = "JoinLateRU"
	is_squad_leader = TRUE
	uses_squads = TRUE
	is_radioman = FALSE
	can_get_coordinates = FALSE
	is_ww2 = FALSE
	is_civil_war = TRUE

	min_positions = 2
	max_positions = 10

/datum/job/civilian/confederate_sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	var/randshoes = rand(1,2)
	if (randshoes == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)
	else if (randshoes == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding2(H), slot_shoes)

//clothes
	var/randcloth = rand(1,2)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/confederate_uniform/grey(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/confederate_uniform/grey_blue(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/confederatehat(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/flintlock/springfield(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/capnball/dragoon(H), slot_belt)
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

/datum/job/civilian/confederate_soldier
	title = "Confederate Rifleman"
	rank_abbreviation = "Pvt."

	spawn_location = "JoinLateRU"
	is_ww2 = FALSE
	uses_squads = TRUE
	is_civil_war = TRUE

	min_positions = 8
	max_positions = 100

/datum/job/civilian/confederate_soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	var/randshoes = rand(1,2)
	if (randshoes == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)
	else if (randshoes == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding2(H), slot_shoes)
//clothes
	var/randcloth = rand(1,2)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/confederate_uniform/grey(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/confederate_uniform/grey_blue(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/confederatecap(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/flintlock/springfield(H), slot_shoulder)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/civil_war/fullh = new /obj/item/clothing/accessory/storage/webbing/civil_war/full(null)
	uniform.attackby(fullh, H)
	fullh.attackby(new/obj/item/ammo_casing/musketball, H)
	fullh.attackby(new/obj/item/ammo_casing/musketball, H)
	fullh.attackby(new/obj/item/ammo_casing/musketball, H)
	fullh.attackby(new/obj/item/ammo_casing/musketball, H)
	fullh.attackby(new/obj/item/ammo_casing/musketball, H)
	fullh.attackby(new/obj/item/ammo_casing/musketball, H)
	fullh.attackby(new/obj/item/ammo_casing/musketball, H)
	fullh.attackby(new/obj/item/ammo_casing/musketball, H)
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

/datum/job/civilian/confederate_doctor
	title = "Confederate Doctor"
	rank_abbreviation = "2lt."

	spawn_location = "JoinLateRUDoc"
	is_civil_war = TRUE
	is_medic = TRUE
	is_ww2 = FALSE

	min_positions = 1
	max_positions = 4

/datum/job/civilian/confederate_doctor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	var/randshoes = rand(1,2)
	if (randshoes == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)
	else if (randshoes == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding2(H), slot_shoes)

//clothes
	var/randcloth = rand(1,2)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/confederate_uniform/grey(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/confederate_uniform/grey_blue(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/doctor(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/confederatecap(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/surgery(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/capnball/dragoon(H), slot_l_hand)

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