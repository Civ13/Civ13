////////////////////////////////////////////////Soviet army (1985's)////////////////////////////////////////

/datum/job/russian/msa_lieutenant
	title = "Soviet Army Afgan lieutenant"
	rank_abbreviation = "lt."

	spawn_location = "JoinLateRUCap"

	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_radioman = TRUE
	can_get_coordinates = TRUE

	min_positions = 1
	max_positions = 2

/datum/job/russian/msa_lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/glasses/gglasses(H), slot_eyes)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_officercap(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/special/ak74mtactical(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/tt30(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/russia(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armor/coldwar/platecarriergreen/armour = new /obj/item/clothing/accessory/armor/coldwar/platecarriergreen(null)
	uniform.attackby(armour, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/soviet(H), slot_l_store)
//jacket
	if (prob(15))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/servicejacket(H), slot_wear_suit)
	H.civilization = "Soviet Army"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. You are in charge of the whole platoon. Organize your troops accordingly!")
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/russian/msa_sergeant
	title = "Soviet Army Afgan Sergeant"
	rank_abbreviation = "Sgt."

	spawn_location = "JoinLateRUCap"

	is_squad_leader = TRUE
	uses_squads = TRUE
	is_radioman = TRUE

	can_get_coordinates = TRUE

	min_positions = 2
	max_positions = 8

/datum/job/russian/msa_sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/glasses/tactical_goggles(H), slot_eyes)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ssh_68(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/special/ak74mtactical(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/tt30(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/russia(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armor/coldwar/platecarriergreen/armour = new /obj/item/clothing/accessory/armor/coldwar/platecarriergreen(null)
	uniform.attackby(armour, H)

	H.equip_to_slot_or_del(new /obj/item/weapon/key/soviet(H), slot_l_store)
//jacket
	if (prob(15))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/servicejacket(H), slot_wear_suit)

	H.civilization = "Soviet Army"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, lead a squad against the Insurgents!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE


/datum/job/russian/msa_medic
	title = "Soviet Army Afgan Field Medic"
	rank_abbreviation = "Cpl."

	spawn_location = "JoinLateRU"

	is_medic = TRUE

	min_positions = 2
	max_positions = 8

/datum/job/russian/msa_medic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/glasses/tactical_goggles(H), slot_eyes)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/russia(H), slot_wear_mask)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/soviet_medic(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat/modern(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/tt30(H), slot_l_hand)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/color/white(H), slot_gloves)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/custom/armband/white = new /obj/item/clothing/accessory/custom/armband(null)
	uniform.attackby(white, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armor/coldwar/platecarriergreen/armour = new /obj/item/clothing/accessory/armor/coldwar/platecarriergreen(null)

	uniform.attackby(armour, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/soviet(H), slot_l_store)
//jacket
	if (prob(15))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/servicejacket(H), slot_wear_suit)
	H.civilization = "Soviet Army"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. Keep your fellow soldiers healthy!")
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

/datum/job/russian/msa_soldier
	title = "Soviet Army Afgan Rifleman"
	rank_abbreviation = "Pvt."

	spawn_location = "JoinLateRU"


	uses_squads = TRUE

	min_positions = 10
	max_positions = 200

/datum/job/russian/msa_soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/platecarriergreen/armour = new /obj/item/clothing/accessory/armor/coldwar/platecarriergreen(null)
	uniform.attackby(armour, H)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/russia(H), slot_wear_mask)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ssh_68(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/sov_74(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/soviet(H), slot_l_store)
//jacket
	if (prob(15))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/servicejacket(H), slot_wear_suit)
	H.civilization = "Soviet Army"
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

/datum/job/russian/msa_tankmen
	title = "Soviet army Afgan tankist"
	rank_abbreviation = "Tankist"

	spawn_location = "JoinLateRU"

	uses_squads = TRUE

	min_positions = 10
	max_positions = 200

/datum/job/russian/msa_tankmen/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet_tanker(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/platecarriergreen/armour = new /obj/item/clothing/accessory/armor/coldwar/platecarriergreen(null)
	uniform.attackby(armour, H)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/russia(H), slot_wear_mask)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ssh_68(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/key/russian(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/sov_74(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/soviet(H), slot_l_store)
//jacket
	if (prob(15))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/servicejacket(H), slot_wear_suit)
	H.civilization = "Soviet Army"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a tankmen. Follow orders and defeat the enemy with heavy soviet armor!")
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

/datum/job/russian/mspetznaz
	title = "Spetznaz Afgan "
	rank_abbreviation = "Spz."

	spawn_location = "JoinLateRUsptz"
	whitelisted = TRUE
	is_yeltsin = TRUE

	uses_squads = TRUE

	min_positions = 1
	max_positions = 10

/datum/job/russian/mspetznaz/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/iogboots/black(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/gorka(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/platecarriergreen/armour = new /obj/item/clothing/accessory/armor/coldwar/platecarriergreen(null)
	uniform.attackby(armour, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/toughguy(H), slot_gloves)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/glasses/thermal(H), slot_eyes)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/russia(H), slot_wear_mask)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ssh_68(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/special/ak74mtactical(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/sov_spz(H), slot_belt)

	H.equip_to_slot_or_del(new /obj/item/clothing/suit/b3(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/tt30(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/soviet(H), slot_l_store)
	H.civilization = "Soviet Army"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, Spetznaz Response Team. You are the best of the best; end this insurrection!")
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_VERY_HIGH)
	H.setStat("pistol", STAT_VERY_HIGH)
	H.setStat("bows", STAT_VERY_HIGH)
	H.setStat("medical", STAT_VERY_HIGH)
	H.setStat("machinegun", STAT_HIGH)
	return TRUE

/////////DRA Goverment//////////////

/datum/job/civilian/afgan/presidentafg
	title = "President"
	en_meaning = "President"
	rank_abbreviation = "Pr."
	spawn_location = "JoinLatessm"

	is_commander = TRUE
	whitelisted = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/civilian/afgan/presidentafg/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/expensive/red(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/black_suit(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/smokable/cigarette/cigar(H), slot_wear_mask)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/tt30/silenced(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/nomads/civiliankevlar/under/armor = new /obj/item/clothing/accessory/armor/nomads/civiliankevlar/under(null)
	uniform.attackby(armor, H)

	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/gov(H), slot_l_store)
	H.civilization = "Afgov"
	H.add_note("Role", "You are an essential member of the DRA goverment,Command the Goverment and Rely on the Army and stay alive!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_NORMAL)
	return TRUE

/datum/job/civilian/afgan/mayorafg
	title = "Governor"
	rank_abbreviation = "Gv."
	spawn_location = "JoinLatessm"

	is_commander = TRUE
	whitelisted = TRUE

	min_positions = 1
	max_positions = 2

/datum/job/civilian/afgan/mayorafg/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/expensive(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/black_suit(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/smokable/cigarette/cigar(H), slot_wear_mask)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/nomads/civiliankevlar/under/armor = new /obj/item/clothing/accessory/armor/nomads/civiliankevlar/under(null)
	uniform.attackby(armor, H)

	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/gov(H), slot_l_store)
	H.civilization = "Afgov"
	H.add_note("Role", "You are an member of the DRA Goverment,manage the city,and cooperate with the soviets!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_NORMAL)
	return TRUE

////////////DRA soliders/////////////


/datum/job/afgan/dra/sergant
	title = "DRA sergant"
	rank_abbreviation = "Sgt."

	spawn_location = "JoinLateRNCap"

	is_squad_leader = TRUE
	uses_squads = TRUE
	is_radioman = TRUE

	can_get_coordinates = TRUE

	min_positions = 2
	max_positions = 5

/datum/job/afgan/dra/sergant/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/combat(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/glasses/tactical_goggles(H), slot_eyes)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ssh_68(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/special/ak74mtactical(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/tt30(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/russia(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armband/armbangle/gold = new/obj/item/clothing/accessory/armband/armbangle(null)
	uniform.attackby(gold, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/soviet(H), slot_l_store)
//jacket
	if (prob(15))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/servicejacket(H), slot_wear_suit)
	H.civilization = "Afgov"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, lead a squad against the Terrorists!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/afgan/dra/medic
	title = "DRA field medic"
	rank_abbreviation = "Cpl."

	spawn_location = "JoinLateRN"

	is_medic = TRUE
	is_yeltsin = TRUE

	min_positions = 2
	max_positions = 4

/datum/job/afgan/dra/medic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/insurgent_black(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/glasses/tactical_goggles(H), slot_eyes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/insurgent_black(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat/modern(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/tt30(H), slot_l_hand)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/color/white(H), slot_gloves)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/custom/armband/white = new /obj/item/clothing/accessory/custom/armband(null)
	uniform.attackby(white, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armor/modern/plate = new /obj/item/clothing/accessory/armor/modern(null)
	uniform.attackby(plate, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/soviet(H), slot_l_store)

	H.civilization = "Afgov"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. Keep your fellow soldiers healthy!")
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

/datum/job/afgan/dra/soldier
	title = "DRA Rifleman"
	rank_abbreviation = "Pvt."

	spawn_location = "JoinLateRN"


	uses_squads = TRUE

	min_positions = 10
	max_positions = 45

/datum/job/afgan/dra/soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/combat(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/modern/plate = new /obj/item/clothing/accessory/armor/modern(null)
	uniform.attackby(plate, H)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/russia(H), slot_wear_mask)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ssh_68(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/sov_74(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/soviet(H), slot_l_store)

	H.civilization = "Afgov"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a basic grunt of the DRA. Follow orders and defeat the terrorists!")
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

/datum/job/afgan/dra/palg
	title = "DRA palace guard"
	rank_abbreviation = "Ppg."

	spawn_location = "JoinLateRN"


	uses_squads = TRUE

	min_positions = 10
	max_positions = 45

/datum/job/afgan/dra/palg/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/combat(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/modern/plate = new /obj/item/clothing/accessory/armor/modern(null)
	uniform.attackby(plate, H)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)
	var/obj/item/clothing/accessory/ruffle/neck = new /obj/item/clothing/accessory/ruffle(null)
	uniform.attackby(neck, H)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/russia(H), slot_wear_mask)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ssh_68(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/sov_74(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/soviet(H), slot_l_store)

	H.civilization = "Afgov"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a basic grunt of the DRA. Follow orders and defeat the terrorists!")
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

////////////////////////////////////////////////afgan civilians////////////////////////////////////////

/datum/job/civilian/afgan/facworker
	title = "factory worker"
	en_meaning = " "
	rank_abbreviation = " "

	spawn_location = "JoinLateAR"

	min_positions = 1
	max_positions = 45

/datum/job/civilian/afgan/facworker/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/arab(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/arabic_tunic(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/turban(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/mechanic(H), slot_l_store)

	H.civilization = "civilian"

	H.add_note("Role", "You are an <b>[title]</b>, an local factory worker")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_LOW)
	give_random_name(H)

	return TRUE

/datum/job/civilian/afgan/miner
	title = "miner"
	en_meaning = " "
	rank_abbreviation = " "

	spawn_location = "JoinLateAR"

	min_positions = 1
	max_positions = 50

/datum/job/civilian/afgan/miner/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/arab(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/arabic_tunic(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/turban(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/material/pickaxe/stone(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/mechanic(H), slot_l_store)

	H.civilization = "civilian"

	H.add_note("Role", "You are an <b>[title]</b>, an local miner, good luck mining!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_LOW)
	give_random_name(H)

	return TRUE

/datum/job/civilian/afgan/villager
	title = "villager"
	en_meaning = " "
	rank_abbreviation = " "

	spawn_location = "JoinLateAR"

	min_positions = 1
	max_positions = 90

/datum/job/civilian/afgan/villager/equip(var/mob/living/human/H)

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/arab(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/arabic_tunic(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/turban(H), slot_head)

	H.civilization = "civilian"

	H.add_note("Role", "You are a <b>[title]</b>,a poor villager")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_LOW)
	give_random_name(H)

	return TRUE

/datum/job/civilian/afgan/doctor
	title = "Doctor"
	en_meaning = " "
	rank_abbreviation = "Dr."

	spawn_location = "JoinLateAR"

	min_positions = 1
	max_positions = 15

/datum/job/civilian/afgan/doctor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/arab(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/arabic_tunic(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/turban(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/paramedics(H), slot_l_store)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.civilization = "civilian"

	H.add_note("Role", "You are an <b>[title]</b>, an local doctor, keep your fellow citizens healthy!!")
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_HIGH)
	give_random_name(H)
	return TRUE

/datum/job/civilian/afgan/urbanciv
	title = "urban unemployed civilian"
	en_meaning = " "
	rank_abbreviation = " "

	spawn_location = "JoinLateAR"

	min_positions = 1
	max_positions = 45

/datum/job/civilian/afgan/urbanciv/equip(var/mob/living/human/H)

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/arab(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/arabic_tunic(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/turban(H), slot_head)

	H.civilization = "civilian"

	H.add_note("Role", "You are an <b>[title]</b>, a local civilian,you are unemployed. Good luck finding a job!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_LOW)
	give_random_name(H)
	return TRUE

/datum/job/civilian/afgan/ubrec
	title = "factory overseer"
	en_meaning = " "
	rank_abbreviation = " "

	spawn_location = "JoinLateAR"

	min_positions = 1
	max_positions = 2

/datum/job/civilian/afgan/ubrec/equip(var/mob/living/human/H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/arabic_tunic(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/turban(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/mechanic(H), slot_l_store)
	H.civilization = "civilian"

	H.add_note("Role", "You are an <b>[title]</b>, an local factory overseer, command your workers and recruit new people!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	give_random_name(H)

	return TRUE

/datum/job/civilian/afgan/ubmin
	title = "miner overseer"
	en_meaning = "Mine Overseer "
	rank_abbreviation = "Overseer "

	spawn_location = "JoinLateAR"

	min_positions = 1
	max_positions = 2

/datum/job/civilian/afgan/ubmin/equip(var/mob/living/human/H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/arabic_tunic(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/turban(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/mechanic(H), slot_l_store)
	H.civilization = "civilian"

	H.add_note("Role", "You are an <b>[H.title]</b>, an local mine overseer, command your workers and recruit new people!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	give_random_name(H)

	return TRUE
////////////////////////////////////////////////Insurgents////////////////////////////////////////

/datum/job/arab/hezbollah/ainsurgentleader
	title = "Insurgent Leader"
	en_meaning = " "
	rank_abbreviation = "Leader"

	spawn_location = "JoinLateAR"

	is_religious = TRUE

	min_positions = 1
	max_positions = 5

/datum/job/arab/hezbollah/ainsurgentleader/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/arab(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/arabic_tunic(H), slot_w_uniform)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/modern/british = new /obj/item/clothing/accessory/armor/modern(null)
	uniform.attackby(british, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches(H), slot_belt)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/turban/imam(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m16/m16a4/att(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)

	H.civilization = "mujahideen"

	H.add_note("Role", "You are an <b>[title]</b>, an islamic leader. lead the holy war against the red menace!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_HIGH)
	give_random_name(H)

	return TRUE

/datum/job/arab/hezbollah/ainsurgent
	title = "Insurgent"
	en_meaning = " "
	rank_abbreviation = " "

	spawn_location = "JoinLateAR"


	min_positions = 10
	max_positions = 250

/datum/job/arab/hezbollah/ainsurgent/equip(var/mob/living/human/H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/arab(H), slot_shoes)
//clothes
	var/randcloth = pick(1,2,3)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/arab1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/arab2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/arab3(H), slot_w_uniform)
//gun and belt
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m16/m16a4/att(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches(H), slot_belt)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/turban(H), slot_head)

	H.civilization = "mujahideen"

	H.add_note("Role", "You are a <b>[title]</b>, an islamic rifleman milita. Use guerrila warfare tactics to defeat the infidels!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE