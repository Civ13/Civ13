
/datum/job/spanish
	faction = "Human"

/datum/job/spanish/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_spanish_name(H.gender)
	H.real_name = H.name

/datum/job/spanish/captain
	title = "Capitan"
	en_meaning = "Ship Captain"
	rank_abbreviation = "Capitan"


	spawn_location = "JoinLateSPCap"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE



	min_positions = 1
	max_positions = 1

/datum/job/spanish/captain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/generic_officer, slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/spanish_captain(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_spanish(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
	world << "<b><big>[H.real_name] is the Captain of the Spanish Navy ship!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, the highest ranking officer present. Your job is to command the ship.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE

/datum/job/spanish/qm
	title = "Intendente"
	en_meaning = "2IC / Supplies Officer"
	rank_abbreviation = "Intendente"

	spawn_location = "JoinLateSPQM"
	is_commander = TRUE
	is_officer = TRUE
	whitelisted = TRUE



	min_positions = 1
	max_positions = 1

/datum/job/spanish/qm/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/generic_officer, slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/spanish_officer, slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_spanish(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
	world << "<b><big>[H.real_name] is the Quartermaster of the Spanish Navy ship!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the ship's supply allocation. You are also the second in command, after the <b>Capitan</b>.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE

/datum/job/spanish/boatswain
	title = "Contramaestre"
	en_meaning = "Head of Personnel Officer"
	rank_abbreviation = "Contramaestre"


	spawn_location = "JoinLateSPBoatswain"
	whitelisted = TRUE

	is_commander = TRUE
	is_officer = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/spanish/boatswain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/generic_officer, slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/spanish_officer, slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_spanish(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
	world << "<b><big>[H.real_name] is the Boatswain of the Spanish Navy ship!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the crew and their job allocation. The whole ship relies on you!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE

/datum/job/spanish/midshipman
	title = "Guardiamarina"
	en_meaning = "Petty Officer"
	rank_abbreviation = "Guardiamarina"

	spawn_location = "JoinLateSPMidshipman"
	is_officer = TRUE



	min_positions = 1
	max_positions = 10

/datum/job/spanish/midshipman/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/spanish_sailor1(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/spanish_officer, slot_wear_suit)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>, a petty officer in the ship. Organize your group according to the <b>Contramaestre</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE

/datum/job/spanish/surgeon
	title = "Cirujano"
	en_meaning = "Medic"
	rank_abbreviation = "Cirujano"

	spawn_location = "JoinLateSPSurgeon"
	is_medic = TRUE

	min_positions = 1
	max_positions = 10

/datum/job/spanish/surgeon/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/spanish_sailor1(H), slot_w_uniform) // for now
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/powdered_wig(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/surgery(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, the most qualified medic present, and you are in charge of keeping the sailors healthy.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)
	give_random_name(H)

	return TRUE

/datum/job/spanish/carpenter
	title = "Carpintero Naval"
	en_meaning = "Carpenter"
	rank_abbreviation = "Carpintero"

	spawn_location = "JoinLateSPCarpenter"



	min_positions = 1
	max_positions = 10

/datum/job/spanish/carpenter/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots2(H), slot_shoes)

//clothes
	var/randcloth = rand(1,3)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/spanish_sailor1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/spanish_sailor2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/spanish_sailor3(H), slot_w_uniform)

	H.equip_to_slot_or_del(new 	/obj/item/weapon/material/hatchet(H), slot_belt)
	H.equip_to_slot_or_del(new 	/obj/item/weapon/wrench(H), slot_l_store)
	H.add_note("Role", "You are a <b>[title]</b>, in charge of keeping the ship in good condition. Work with the <b>Intendente</b> to ensure everyting is in good conditions!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE

/datum/job/spanish/cook
	title = "Cocinero"
	en_meaning = "Cook"
	rank_abbreviation = "Cocinero"

	spawn_location = "JoinLateSPCook"



	min_positions = 1
	max_positions = 10

/datum/job/spanish/cook/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots2(H), slot_shoes)

//clothes
	var/randcloth = rand(1,3)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/spanish_sailor1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/spanish_sailor2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/spanish_sailor3(H), slot_w_uniform)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/smallsword(H), slot_belt)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/chef(H), slot_wear_suit)

	H.add_note("Role", "You are the cook of the ship. Feed the whole crew according to the <b>Intendente</b> orders!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE




////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/datum/job/spanish/seaman
	title = "Marinero"
	en_meaning = "Seaman"
	rank_abbreviation = ""

	spawn_location = "JoinLateSP"



	min_positions = 6
	max_positions = 200

/datum/job/spanish/seaman/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots2(H), slot_shoes)

//clothes
	var/randcloth = rand(1,3)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/spanish_sailor1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/spanish_sailor2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/spanish_sailor3(H), slot_w_uniform)

//head
	if (prob(70))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/red_sailorberet(H), slot_head)
	var/randweapon = rand(1,2)
	if (randweapon == 1)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/smallsword(H), slot_belt)
	else if (randweapon == 2)
		H.equip_to_slot_or_del(new 	/obj/item/weapon/material/harpoon(H), slot_belt)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a simple seaman employed by the Spanish Armada Real. Follow your <b>Capitan</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE
/////////////////////////////////////////////////EXTRAS FOR CORPSES///////////////////////////////////////////////////
/datum/job/spanish/corpse/soldier
	title = "Military Soldado"
	en_meaning = "Military Soldier"
	rank_abbreviation = ""

	spawn_location = "JoinLateSP"

	min_positions = 1
	max_positions = 30

/datum/job/spanish/corpse/soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/whiteputtee(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/spanish_soldier(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/spanish_soldier(H), slot_wear_suit)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_black(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)

	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, a veteran of past wars. Your job is to organize the colony defense and hunting parties, according to the orders of the <b>Town Guard Officer</b>.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)

	return TRUE

/datum/job/spanish/corpse/soldier_rifle
	title = "Rifle Soldado"
	en_meaning = "Rifleman"
	rank_abbreviation = ""

	spawn_location = "JoinLateSP"

	min_positions = 1
	max_positions = 30

/datum/job/spanish/corpse/soldier_rifle/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/whiteputtee(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/spanish_soldier(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/spanish_soldier(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/flintlock/m1752(H), slot_l_hand)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_black(H), slot_head)

	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, a veteran of past wars. Your job is to organize the colony defense and hunting parties, according to the orders of the <b>Town Guard Officer</b>.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)

	return TRUE

//nationalist spain civil war

/datum/job/spanish/cnat/capt
	title = "Capitán nacionalista"
	en_meaning = "Nationalist Captain"
	rank_abbreviation = "Cap."


	spawn_location = "JoinLateFSP"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_spainciv = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/spanish/cnat/capt/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/whiteputtee(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/spain/nationalist(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/german_fieldcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/mauser(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ermaemp(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mauser(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/whistle(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction1(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armband/spanish/white = new /obj/item/clothing/accessory/armband/spanish(null)
	uniform.attackby(white, H)
	give_random_name(H)
	world << "<b><big>[H.real_name] is the General of the Nationalist Forces!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, the highest ranking officer present. Your job is to command the company.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_NORMAL)

	return TRUE

/datum/job/spanish/cnat/serg
	title = "Sargento Nacionalista"
	en_meaning = "Nationalist Squad Leader"
	rank_abbreviation = "Sar."

	spawn_location = "JoinLateFSP"
	is_officer = FALSE
	is_squad_leader = TRUE
	uses_squads = TRUE
	is_ww2 = FALSE
	is_spainciv = TRUE


	min_positions = 2
	max_positions = 8

/datum/job/spanish/cnat/serg/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/spain/nationalist(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/german_fieldcap(H), slot_head)
//radio
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction1(H), slot_back)
//belt
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/gerbelt/officer(H), slot_belt)
//weapons
	var/obj/item/clothing/under/uniform = H.w_uniform
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mp40/erma(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mp40/erma(H), slot_r_store)
	var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2(null)
	uniform.attackby(webbing, H)
	webbing.attackby(new/obj/item/ammo_magazine/mp40/erma, H)
	webbing.attackby(new/obj/item/ammo_magazine/mp40/erma, H)
	webbing.attackby(new/obj/item/ammo_magazine/mp40/erma, H)

	var/obj/item/clothing/accessory/armband/spanish/white = new /obj/item/clothing/accessory/armband/spanish(null)
	uniform.attackby(white, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ermaemp(H), slot_shoulder)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a sergeant leading a squad. Organize your squad according to the <b>Capitans's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_NORMAL)

	return TRUE

/datum/job/spanish/cnat/med
	title = "Médico de combate nacionalista"
	en_meaning = "Nationalist Combat medic"
	rank_abbreviation = "M."

	spawn_location = "JoinLateFSP"

	is_ww2 = FALSE
	is_medic = TRUE
	is_spainciv = TRUE
	min_positions = 1
	max_positions = 5

/datum/job/spanish/cnat/med/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/spain/nationalist(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/mauser(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mauser(H), slot_r_store)

	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/adrianm26medic(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_belt)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/redcross/armband = new /obj/item/clothing/accessory/armband/redcross(null)
	uniform.attackby(armband, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, the most qualified medic present, and you are in charge of keeping the soldiers healthy.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)
	H.setStat("machinegun", STAT_NORMAL)

	return TRUE

/datum/job/spanish/cnat/rifle
	title = "Soldado nacionalista"
	en_meaning = "Nationalist Solider"
	rank_abbreviation = ""

	spawn_location = "JoinLateFSP"
	is_ww2 = FALSE
	uses_squads = TRUE
	is_spainciv = TRUE

	min_positions = 10
	max_positions = 75

/datum/job/spanish/cnat/rifle/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/spain/nationalist(H), slot_w_uniform)
//head
	if (prob(40))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/adrianm26(H), slot_head)
	else if (prob(45))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/gerhelm(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/beret_red(H), slot_head)
//weapons
	var/obj/item/clothing/under/uniform = H.w_uniform
	if (prob(80))
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/gewehr98(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/gewehr98(H), slot_r_store)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98(H), slot_shoulder)
		var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2(null)
		uniform.attackby(webbing, H)
		webbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
		webbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
		webbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
		webbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	else
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mp40/erma(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mp40/erma(H), slot_r_store)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ermaemp(H), slot_shoulder)
		var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2(null)
		uniform.attackby(webbing, H)
		webbing.attackby(new/obj/item/ammo_magazine/mp40/erma, H)
		webbing.attackby(new/obj/item/ammo_magazine/mp40/erma, H)
		webbing.attackby(new/obj/item/ammo_magazine/mp40/erma, H)
//belt
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/grenade/smokebomb(H), slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/grenade/modern/stg1915(H), slot_belt)
//armband
	var/obj/item/clothing/accessory/armband/spanish/white = new /obj/item/clothing/accessory/armband/spanish(null)
	uniform.attackby(white, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a soldier of the Nationalist army. Follow your <b>Sergeant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_NORMAL)

	return TRUE

/datum/job/spanish/cnat/tankist
	title = "Hombre Tanque"
	en_meaning = "Tankist"
	rank_abbreviation = ""

	spawn_location = "JoinLateFSP"
	is_ww2 = FALSE
	uses_squads = FALSE
	is_spainciv = TRUE

	min_positions = 2
	max_positions = 4

/datum/job/spanish/cnat/tankist/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/spain/nationalist(H), slot_w_uniform)
//head
	if (prob(80))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/german_tanker(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/ger_officercap_tanker(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/german(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/german(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ermaemp(H), slot_shoulder)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/ww1/leather/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather(null)
	uniform.attackby(webbing, H)
	webbing.attackby(new/obj/item/ammo_magazine/mp40/erma, H)
	webbing.attackby(new/obj/item/ammo_magazine/mp40/erma, H)
	webbing.attackby(new/obj/item/ammo_magazine/mp40/erma, H)
	var/obj/item/clothing/accessory/armband/spanish/white = new /obj/item/clothing/accessory/armband/spanish(null)
	uniform.attackby(white, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a tanker of the Nationalist army. Follow your <b>Sergeant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_LOW)

	return TRUE