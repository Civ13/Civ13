/datum/job/russian
	faction = "Human"

/datum/job/russian/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_russian_name(H.gender)
	H.real_name = H.name

/datum/job/russian/captain
	title = "Kapitan"
	en_meaning = "Army Captain"
	rank_abbreviation = "Kpt."
	is_russojapwar = TRUE
	spawn_location = "JoinLateRUCap"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/russian/captain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/rusuni, slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/rusoffcoat(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/rusoffcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/nagant_revolver(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c762x38mmR(H), slot_l_store)
	H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/russian/soldier(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_r_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	world << "<b><big>[H.real_name] is the Captain of the Russian Forces!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, the highest ranking officer present. Your job is to command the company.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/russian/lieutenant
	title = "Poruchik"
	en_meaning = "Lieutenant"
	rank_abbreviation = "Po."
	is_russojapwar = TRUE

	spawn_location = "JoinLateRUCap"
	whitelisted = TRUE

	is_commander = TRUE
	is_officer = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/russian/lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/rusuni(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/rusoffcoat(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/rusoffcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c762x38mmR(H), slot_l_store)
	H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/russian/soldier(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/nagant_revolver(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	world << "<b><big>[H.real_name] is the Lieutenant of the Russian forces!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the troops and their orders. The whole operation relies on you!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)

	return TRUE


/datum/job/russian/second_lieutenant
	title = "Podporuchik"
	en_meaning = "Sub-Lieutenant"
	rank_abbreviation = "Ppo."
	spawn_location = "JoinLateRUCap"
	whitelisted = TRUE
	is_russojapwar = TRUE
	is_commander = TRUE
	is_officer = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/russian/second_lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/rusuni(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/rusoffcoat(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/rusoffcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c762x38mmR(H), slot_l_store)
	H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/russian/soldier(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/nagant_revolver(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	world << "<b><big>[H.real_name] is the Lieutenant of the Russian forces!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the troops and their orders. The whole operation relies on you!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)

	return TRUE


/datum/job/russian/sergeant
	title = "Feldvebel"
	en_meaning = "Sergeant"
	rank_abbreviation = "Fv."
	is_russojapwar = TRUE
	spawn_location = "JoinLateRU"
	is_squad_leader = TRUE
	uses_squads = TRUE


	min_positions = 2
	max_positions = 12

/datum/job/russian/sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/rusuni(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/rusoffcoat(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/rusoffcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/nagant_revolver(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c762x38mmR(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin(H), slot_shoulder)
	H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/russian/soldier(H), slot_belt)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a sergeant leading a squad. Organize your group according to the <b>Captain or Leiutenant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/russian/doctor
	title = "Medik"
	en_meaning = "Doctor"
	rank_abbreviation = "Dr."
	is_russojapwar = TRUE
	spawn_location = "JoinLateRUDoc"

	is_medic = TRUE
	min_positions = 1
	max_positions = 10

/datum/job/russian/doctor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/rusuni(H), slot_w_uniform) // for now
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ruscap(H), slot_head)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ruscoat(H), slot_wear_suit)

	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/surgery(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, the most qualified medic present, and you are in charge of keeping the soldiers healthy.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)


	return TRUE

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/russian/infantry_first_class
	title = "Yefreytor"
	en_meaning = "Soldier First-class"
	rank_abbreviation = "Ye."
	is_russojapwar = TRUE
	spawn_location = "JoinLateRU" //for testing!
	uses_squads = TRUE


	min_positions = 6
	max_positions = 200

/datum/job/russian/infantry_first_class/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/rusuni(H), slot_w_uniform)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ruscap(H), slot_head)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ruscoat(H), slot_wear_suit)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin(H), slot_shoulder)

	H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/russian/soldier(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/bint(H), slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/russbando = new /obj/item/clothing/accessory/storage/webbing/russband(null)
	uniform.attackby(russbando, H)
	russbando.attackby(new/obj/item/ammo_magazine/mosin, H)
	russbando.attackby(new/obj/item/ammo_magazine/mosin, H)
	russbando.attackby(new/obj/item/ammo_magazine/mosin, H)
	russbando.attackby(new/obj/item/ammo_magazine/mosin, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a simple soldier first-class employed by the Imperial Russian Army. Follow your <b>Officer's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE
/datum/job/russian/infantry
	title = "Ryadovoy"
	en_meaning = "Soldier Second-class"
	rank_abbreviation = "Ry."
	is_russojapwar = TRUE
	spawn_location = "JoinLateRU" //for testing!
	uses_squads = TRUE


	min_positions = 6
	max_positions = 200

/datum/job/russian/infantry/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/rusuni(H), slot_w_uniform)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ruscap(H), slot_head)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ruscoat(H), slot_wear_suit)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin(H), slot_shoulder)

	H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/russian/soldier(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/russbando = new /obj/item/clothing/accessory/storage/webbing/russband(null)
	uniform.attackby(russbando, H)
	russbando.attackby(new/obj/item/ammo_magazine/mosin, H)
	russbando.attackby(new/obj/item/ammo_magazine/mosin, H)
	russbando.attackby(new/obj/item/ammo_magazine/mosin, H)
	russbando.attackby(new/obj/item/ammo_magazine/mosin, H)
	give_random_name(H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a simple soldier second-class employed by the Imperial Russian Army. Follow your <b>Officer's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

//////////////////////////////////////////////WW2/////////////////////////////////////////

/datum/job/russian/captain_soviet
	title = "K.A. Kapitan"
	en_meaning = "Red Army Captain"
	rank_abbreviation = "Kpt."


	spawn_location = "JoinLateRUCap"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_ww2 = TRUE
	is_karelia = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/russian/captain_soviet/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet_officer(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_officercap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/nagant_revolver(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c762x38mmR(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/soviet(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/rusoff(H), slot_belt)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	if (map.ID == MAP_STALINGRAD || map.ID == MAP_SMALLSIEGEMOSCOW || map.ID == MAP_KARELIA)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/soviet_officer(H), slot_wear_suit)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	world << "<b><big>[H.real_name] is the Captain of the Russian Forces!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, the highest ranking officer present. Your job is to command the company.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE


/datum/job/russian/nkvd_soviet
	title = "NKVD Leytenant"
	en_meaning = "NKVD Officer"
	rank_abbreviation = "NKVD Leyt."


	spawn_location = "JoinLateRUCap"
	is_officer = TRUE
	whitelisted = TRUE
	is_karelia = TRUE
	is_ww2 = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/russian/nkvd_soviet/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet_nkvd(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/nkvd_cap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/nagant_revolver(H), slot_l_hand)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/gulagguard/filled(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/soviet(H), slot_r_store)
	if (map.ID == MAP_STALINGRAD || map.ID == MAP_SMALLSIEGEMOSCOW || map.ID == MAP_KARELIA)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/soviet_officer(H), slot_wear_suit)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a member of the NKVD attached to this army unit. Your job is to make sure the soldiers follow STAVKA's orders. You can even discipline the officers if need be!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/russian/sergeant_soviet
	title = "K.A. Serjant"
	en_meaning = "Squad Leader"
	rank_abbreviation = "Srj."

	spawn_location = "JoinLateRU"
	is_squad_leader = TRUE
	uses_squads = TRUE
	is_ww2 = TRUE
	is_karelia = TRUE

	min_positions = 2
	max_positions = 12

/datum/job/russian/sergeant_soviet/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(40))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet(H), slot_w_uniform)

	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/rusoff(H), slot_belt)
//head
	if (prob(70))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/soviet(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/soviet_fieldcap(H), slot_head)

//weapons
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	if (map.ID == MAP_KHALKHYN_GOL)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin/m30(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mosin(H), slot_r_store)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mosin(H), slot_l_store)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/pps(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c762x25_pps(H), slot_r_store)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c762x25_pps(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction2(H), slot_back)
	if (map.ID == MAP_STALINGRAD || map.ID == MAP_SMALLSIEGEMOSCOW || map.ID == MAP_KARELIA)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/sovcoat(H), slot_wear_suit)
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/nagant_revolver(H), slot_l_hand)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/tt30(H), slot_l_hand)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a sergeant leading a squad. Organize your squad according to the <b>Kapitan's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/russian/doctor_soviet
	title = "K.A. Voynenvrach"
	en_meaning = "Combat Medic"
	rank_abbreviation = "Srj."

	spawn_location = "JoinLateRUDoc"
	is_karelia = TRUE
	is_ww2 = TRUE
	is_bordersov = FALSE
	is_medic = TRUE
	min_positions = 1
	max_positions = 4

/datum/job/russian/doctor_soviet/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet(H), slot_w_uniform) // for now
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/soviet_medic(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/tt30(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	if (map.ID == MAP_STALINGRAD || map.ID == MAP_SMALLSIEGEMOSCOW)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/sovcoat(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_belt)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/redcross/armband = new /obj/item/clothing/accessory/armband/redcross(null)
	uniform.attackby(armband, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, the most qualified medic present, and you are in charge of keeping the soldiers healthy.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)
	return TRUE

/datum/job/russian/machinegunner_soviet
	title = "K.A. Pulemetchik"
	en_meaning = "Red Army Machinegunner"
	rank_abbreviation = ""

	spawn_location = "JoinLateRU"
	is_karelia = TRUE
	is_ww2 = TRUE
	uses_squads = TRUE


	min_positions = 2
	max_positions = 12

/datum/job/russian/machinegunner_soviet/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet(H), slot_w_uniform)
//head
	if (prob(80))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_pilotka(H), slot_head)
	if (map.ID == MAP_STALINGRAD || map.ID == MAP_SMALLSIEGEMOSCOW || map.ID == MAP_KARELIA)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/sovcoat(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/sovietmg(H), slot_belt)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/dp28(H), slot_l_hand)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
//webbing
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/dpgun/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/dpgun(null)
	uniform.attackby(webbing, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a designated automatic rifleman of the Red Army. Keep the enemy pinned down!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)

	return TRUE

/datum/job/russian/machinegunner_assistant_sov
	title = "K.A. Pomoshchnik Pulemetchika"
	en_meaning = "Red Army Machinegunner Assistant"
	rank_abbreviation = ""

	spawn_location = "JoinLateRU"
	is_karelia = TRUE
	is_ww2 = TRUE
	uses_squads = TRUE


	min_positions = 2
	max_positions = 8

/datum/job/russian/machinegunner_assistant_sov/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/soviet(H), slot_head)
	if (map.ID == MAP_STALINGRAD || map.ID == MAP_SMALLSIEGEMOSCOW || map.ID == MAP_KARELIA)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/sovcoat(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/ammo_can/dp(H), slot_belt)
//weapons
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
//webbing
	var/obj/item/clothing/under/uniform = H.w_uniform
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin/m30(H), slot_shoulder)
	if (prob(20))
		var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosin/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosin(null)
		uniform.attackby(webbing, H)
	else if (prob(40))
		var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosinaltsmoke/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosinaltsmoke(null)
		uniform.attackby(webbing, H)
	else if (prob(40))
		var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosinalt/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosinalt(null)
		uniform.attackby(webbing, H)
	else
		var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosinbay/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosinbay(null)
		uniform.attackby(webbing, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/ammo_can/dp(H), slot_back)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a Machinegunner assistant of the Red Army, Provide ammo and Cover to the Pulemetchik, Take Over if he gets incapacitated!")
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)

	return TRUE

/datum/job/russian/antitank_soldier_soviet
	title = "K.A. Protivotankovyy Strelok"
	en_meaning = "Red Army AT Rifleman"
	rank_abbreviation = ""

	spawn_location = "JoinLateRU"
	can_be_female = TRUE
	is_ww2 = TRUE
	is_sovaprif = TRUE
	uses_squads = TRUE
	is_karelia = FALSE

	min_positions = 2
	max_positions = 4

/datum/job/russian/antitank_soldier_soviet/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(20))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet(H), slot_w_uniform)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		if (prob(40))
			H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/soviet(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_pilotka(H), slot_head)
//weapons
	if (map.ID == MAP_STALINGRAD || map.ID == MAP_SMALLSIEGEMOSCOW || map.ID == MAP_KARELIA)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/sovcoat(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/ptrd_pouch(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/tt30(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/tt30(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/ww1/leather/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather(null)
	uniform.attackby(webbing, H)
	webbing.attackby(new/obj/item/stack/medical/bruise_pack/bint, H)
	webbing.attackby(new/obj/item/ammo_magazine/tt30, H)
	webbing.attackby(new/obj/item/ammo_magazine/tt30, H)
	webbing.attackby(new/obj/item/ammo_magazine/tt30, H)
	webbing.attackby(new/obj/item/ammo_magazine/tt30, H)
	webbing.attackby(new/obj/item/ammo_magazine/tt30, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/singleshot/ptrd(H), slot_l_hand)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, an anti-tank rifleman of the Red Army and you keep braging that your gun is bigger than your comrads'. Follow your <b>Sergeant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)

	return TRUE

/datum/job/russian/antitank_assistant_soldier_soviet
	title = "K.A. Pomoshnik Protivotankovo Strelka"
	en_meaning = "Red Army Assistant AT Rifleman"
	rank_abbreviation = ""

	spawn_location = "JoinLateRU"
	can_be_female = TRUE
	is_ww2 = TRUE
	uses_squads = TRUE
	is_karelia = FALSE
	is_sovaprif = TRUE

	min_positions = 2
	max_positions = 4

/datum/job/russian/antitank_assistant_soldier_soviet/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(20))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/compass(H), slot_wear_id)
//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/soviet(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_pilotka(H), slot_head)
//weapons
	if (map.ID == MAP_STALINGRAD || map.ID == MAP_SMALLSIEGEMOSCOW || map.ID == MAP_KARELIA)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/sovcoat(H), slot_wear_suit)

	var/obj/item/clothing/under/uniform = H.w_uniform
	if (mosinonly == TRUE)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin/m30(H), slot_shoulder)
		var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/snipermosin/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/snipermosin(null)
		uniform.attackby(webbing, H)
	else
		var/randimpw = rand(1,3)
		switch(randimpw)
			if (1)
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin/m30(H), slot_shoulder)
				var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/snipermosin/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/snipermosin(null)
				uniform.attackby(webbing, H)
			if (2)
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ppsh(H), slot_shoulder)
				var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/ppshassault/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/ppshassault(null)
				uniform.attackby(webbing, H)
			if (3)
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/svt(H), slot_shoulder)
				var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/svtassault/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/svtassault(null)
				uniform.attackby(webbing, H)

	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/ptrd_box(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/ptrd_box/ap(H), slot_r_store)
//Extra AT weapon
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/drinks/bottle/molotov(H), slot_l_hand)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/grenade/antitank/rpg40(H), slot_l_hand)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, an anti-tank assistant, find your Anti-tank gunner and assist him. Follow your <b>Sergeant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)

	return TRUE

/datum/job/russian/flamethrower_soviet
	title = "K.A. Ognemetchik"
	en_meaning = "Red Army Flamethrower Unit"
	rank_abbreviation = ""

	spawn_location = "JoinLateRU"
	can_be_female = TRUE
	is_ww2 = TRUE
	uses_squads = TRUE
	is_karelia = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/russian/flamethrower_soviet/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/firefighter(H), slot_gloves)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/soviet(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/soviet(H), slot_wear_mask)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/flamethrower/roks2(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/glass/flamethrower/roks2/filled(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/tt30(H), slot_belt)

	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/ww1/leather/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather(null)
	uniform.attackby(webbing, H)
	give_random_name(H)
	webbing.attackby(new/obj/item/stack/medical/bruise_pack/bint, H)
	webbing.attackby(new/obj/item/ammo_magazine/tt30, H)
	webbing.attackby(new/obj/item/ammo_magazine/tt30, H)
	webbing.attackby(new/obj/item/ammo_magazine/tt30, H)
	webbing.attackby(new/obj/item/ammo_magazine/tt30, H)
	webbing.attackby(new/obj/item/ammo_magazine/tt30, H)
	H.add_note("Role", "You are a <b>[title]</b>, a flamethrower solider of the red army, Assault enemy positions and tanks with your flamethrower. Follow your <b>Sergeant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE


/datum/job/russian/sniper_soviet
	title = "K.A. Snaiper"
	en_meaning = "Red Army Sniper"
	rank_abbreviation = ""

	spawn_location = "JoinLateRU"
	is_karelia = TRUE
	is_ww2 = TRUE
	uses_squads = TRUE


	min_positions = 2
	max_positions = 12

/datum/job/russian/sniper_soviet/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	if (map.ID == MAP_KARELIA || map.ID == MAP_STALINGRAD || map.ID == MAP_SMALLINGRAD || map.ID == MAP_SMALLSIEGEMOSCOW || map.ID == MAP_GULAG13)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet_berezka(H), slot_w_uniform)
	else
		if (prob(70))
			H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet_amoeba(H), slot_w_uniform)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet(H), slot_w_uniform)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/sovcoat(H), slot_wear_suit)
//head
	if (prob(80))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_pilotka(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin/m30/sniper(H), slot_shoulder)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/snipermosin/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/snipermosin(null)
	uniform.attackby(webbing, H)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a sniper of the Red Army. Keep the enemy pinned down!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_NORMAL)

	return TRUE

/datum/job/russian/soldier_soviet
	title = "K.A. Soldat"
	en_meaning = "Red Army Private"
	rank_abbreviation = ""

	spawn_location = "JoinLateRU"
	can_be_female = TRUE
	is_ww2 = TRUE
	uses_squads = TRUE
	is_karelia = TRUE

	min_positions = 20
	max_positions = 100

/datum/job/russian/soldier_soviet/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(20))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet(H), slot_w_uniform)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		if (prob(40))
			H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/soviet(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_pilotka(H), slot_head)
//weapons
	if (map.ID == MAP_STALINGRAD || map.ID == MAP_SMALLSIEGEMOSCOW || map.ID == MAP_KARELIA)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/sovcoat(H), slot_wear_suit)
//weapon
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/randgun = rand(1,4)
	switch(randgun)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/svt(H), slot_shoulder)
			if (prob(50))
				var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/svt/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/svt(null)
				uniform.attackby(webbing, H)
			else
				var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/svt/frag/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/svt/frag(null)
				uniform.attackby(webbing, H)
		if (2)
			if (prob(70))
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ppd(H), slot_shoulder)
			else
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ppsh(H), slot_shoulder)
				if (prob(50))
					var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/ppsh/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/ppsh(null)
					uniform.attackby(webbing, H)
				else
					var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/ppsh/grenade/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/ppsh/grenade(null)
					uniform.attackby(webbing, H)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin/m30(H), slot_shoulder)
			if (prob(50))
				var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosin/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosin(null)
				uniform.attackby(webbing, H)
			else if (prob(30))
				var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosinaltsmoke/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosinaltsmoke(null)
				uniform.attackby(webbing, H)
			else if (prob(10))
				var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosinalt/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosinalt(null)
				uniform.attackby(webbing, H)
			else
				var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosinbay/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosinbay(null)
				uniform.attackby(webbing, H)
		if (4) //this is here so the chances to have a boltie are higher
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin/m30(H), slot_shoulder)
			if (prob(50))
				var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosin/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosin(null)
				uniform.attackby(webbing, H)
			else if (prob(30))
				var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosinaltsmoke/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosinaltsmoke(null)
				uniform.attackby(webbing, H)
			else if (prob(40))
				var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosinalt/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosinalt(null)
				uniform.attackby(webbing, H)
			else
				var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosinbay/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosinbay(null)
				uniform.attackby(webbing, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a simple soldier of the Red Army. Follow your <b>Sergeant's</b> orders!")
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

////////////////////////////////////////////////////////////////
////////////////////1941 Barbarossa/////////////////////////////

/datum/job/russian/nkvdborderley
	title = "NKVD Pogranichnik Leytenant"
	en_meaning = "NKVD Border Guard Lieutenant"
	rank_abbreviation = "NKVD Leyt."


	spawn_location = "JoinLateRUCap"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_ww2 = FALSE
	is_karelia = FALSE
	is_bordersov = TRUE
	can_be_female = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/russian/nkvdborderley/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet_officer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction2(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/soviet_officer(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/nkvd_cap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/nagant_revolver(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/gulagguard/filledwar(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/soviet(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ppsh(H), slot_shoulder)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a member of the NKVD attached to this border District. You are the highest ranking officer here, Organize your defenses Comrade and Make sure that the soliders follow orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_HIGH)
	return TRUE

/datum/job/russian/nkvdborderser
	title = "NKVD pogranichnik"
	en_meaning = "NKVD Border guard"
	rank_abbreviation = "NKVD Pgr."

	spawn_location = "JoinLateRU"
	is_squad_leader = TRUE
	uses_squads = TRUE
	whitelisted = TRUE
	is_ww2 = FALSE
	is_karelia = FALSE
	is_bordersov = TRUE
	can_be_female = TRUE

	min_positions = 2
	max_positions = 4

/datum/job/russian/nkvdborderser/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(40))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet_nkvd(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/gulagguard/filledwar(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/toughguy(H), slot_gloves)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/nkvd_cap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ppsh(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c762x25_ppsh(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/soviet(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction2(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/sovcoat(H), slot_wear_suit)
	give_random_name(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/ppsh/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/ppsh(null)
	uniform.attackby(webbing, H)
	H.add_note("Role", "You are a <b>[title]</b>, a simple border guard,help your motherland by organizing defenses according to the <b>Leytenant's</b> orders!")
	H.add_note("NKVD", "-Your job is to make sure the soldiers follow STAVKA's orders. You can even discipline the officers if need be!")
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/russian/borderscout
	title = "Razvedchik"
	en_meaning = "Soviet Scout"
	rank_abbreviation = ""

	spawn_location = "JoinLateRU"
	uses_squads = TRUE
	is_ww2 = FALSE
	is_karelia = FALSE
	is_bordersov = TRUE
	whitelisted = TRUE
	can_be_female = TRUE
	additional_languages = list("English" = 15, "German" = 25, "Polish" = 35, "Ukrainian" = 40)

	min_positions = 1
	max_positions = 2

/datum/job/russian/borderscout/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(20))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//radio
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction2(H), slot_back)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet_amoeba(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/toughguy(H), slot_gloves)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/soviet(H), slot_head)
//weapon
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/randimpw = rand(1,2)
	switch(randimpw)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ppsh(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/ww2/stormgroup/Scout/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/ww2/stormgroup/Scout(null)
			uniform.attackby(webbing, H)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/svt(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_wear_id)
			var/obj/item/clothing/accessory/storage/webbing/ww1/ww2/stormgroup/svt/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/ww2/stormgroup/svt(null)
			uniform.attackby(webbing, H)
//inhandweapon
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/tt30(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/tt30(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/tt30(H), slot_l_store)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a soviet scout, report enemy positions and movements to your squad leader, always be up front!, Follow your <b>Sergeant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/russian/borderserg
	title = "K.A. Opolchenets Serjant"
	en_meaning = "Milita Squad Leader"
	rank_abbreviation = "Srj."

	spawn_location = "JoinLateRU"
	is_squad_leader = TRUE
	uses_squads = TRUE
	can_be_female = TRUE
	is_ww2 = FALSE
	is_karelia = FALSE
	is_bordersov = TRUE

	min_positions = 2
	max_positions = 8

/datum/job/russian/borderserg/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(40))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet(H), slot_w_uniform)

	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/rusoff(H), slot_belt)
//head
	if (prob(70))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/soviet(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/soviet_fieldcap(H), slot_head)

//weapons
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ppsh(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c762x25_ppsh(H), slot_r_store)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c762x25_pps(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction2(H), slot_back)
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/nagant_revolver(H), slot_l_hand)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/tt30(H), slot_l_hand)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a sergeant leading a Milita squad. Organize your squad according to the <b>Leytenant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_NORMAL)
	return TRUE

/datum/job/russian/sovmilitamedic
	title = "Opolchenets medik"
	en_meaning = "Soviet Milita Medic"
	rank_abbreviation = "Doc."

	spawn_location = "JoinLateRUDoc"
	can_be_female = TRUE
	is_ww2 = FALSE
	is_karelia = FALSE
	is_bordersov = TRUE
	is_medic = TRUE
	min_positions = 1
	max_positions = 4
	additional_languages = list("English" = 5, "German" = 5, "Polish" = 15, "Ukrainian" = 10)

/datum/job/russian/sovmilitamedic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet(H), slot_w_uniform) // for now
//head
	if (prob(20))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/soviet_medic(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww/adrianm15medic(H), slot_head)
//other
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/sovcoat2(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_belt)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
//gun
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/randimpw = rand(1,4)
	switch(randimpw)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ppsh(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/ppsh/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/ppsh(null)
			uniform.attackby(webbing, H)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/svt(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/svt/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/svt(null)
			uniform.attackby(webbing, H)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ppd(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/ppsh/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/ppsh(null)
			uniform.attackby(webbing, H)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/tt30(H), slot_l_hand)
			H.equip_to_slot_or_del(new /obj/item/ammo_magazine/tt30(H), slot_r_store)
			H.equip_to_slot_or_del(new /obj/item/ammo_magazine/tt30(H), slot_l_store)
			var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
			uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/armband/redcross/armband = new /obj/item/clothing/accessory/armband/redcross(null)
	uniform.attackby(armband, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, you were given minimal training, now you are here to save people, or kill them. Follow your <b>Sergeant's</b> orders!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)
	return TRUE

/datum/job/russian/borderat
	title = "Protivotankovyy Prizyvnik"
	en_meaning = "Anti tank conscript"
	rank_abbreviation = ""

	spawn_location = "JoinLateRU"
	is_squad_leader = FALSE
	uses_squads = TRUE
	is_ww2 = FALSE
	is_karelia = FALSE
	is_bordersov = TRUE
	can_be_female = TRUE

	min_positions = 1
	max_positions = 2

/datum/job/russian/borderat/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(40))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet_amoeba(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)
//belt
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_belt)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/soviet(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/ww2/russian/at(H), slot_back)
//weapons
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/randimrr = rand(1,2)
	switch(randimrr)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ppd(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/singleshot/ptrd(H), slot_l_hand)
			H.equip_to_slot_or_del(new /obj/item/ammo_magazine/ptrd_pouch(H), slot_r_store)
			H.equip_to_slot_or_del(new /obj/item/ammo_magazine/ptrd_pouch/ap(H), slot_l_store)
			var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/ppsh/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/ppsh(null)
			uniform.attackby(webbing, H)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin/m30(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/singleshot/ptrd(H), slot_l_hand)
			H.equip_to_slot_or_del(new /obj/item/ammo_magazine/ptrd_pouch(H), slot_r_store)
			H.equip_to_slot_or_del(new /obj/item/ammo_magazine/ptrd_pouch/ap(H), slot_l_store)
			var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosinalt/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosinalt(null)
			uniform.attackby(webbing, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, as a anti tank specialist, you are equipped with the greatest anti tank weapons the soviet union can give you, set up ambushes and destroy enemy tanks! follow your <b>Sergeant's</b> orders!")
	H.add_note("AT", "-Your PTRD rifle can only penetrate light armor or broken armor, use your AT grenades to immobilize a enemy tank then break their door with your charge and throw in a grenade to clear it out!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_NORMAL)
	return TRUE

/datum/job/russian/bordermil
	title = "Granitsa Opolchenets"
	en_meaning = "Soviet Border Militia"
	rank_abbreviation = ""

	spawn_location = "JoinLateRU"
	uses_squads = TRUE
	is_ww2 = FALSE
	is_karelia = FALSE
	is_bordersov = TRUE
	can_be_female = TRUE
	additional_languages = list("English" = 5, "German" = 15, "Polish" = 25, "Ukrainian" = 20)

	min_positions = 10
	max_positions = 90

/datum/job/russian/bordermil/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(20))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	var/randimc = rand(1,4)
	switch(randimc)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet(H), slot_w_uniform)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/farmer_outfit(H), slot_w_uniform)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ2(H), slot_w_uniform)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ1(H), slot_w_uniform)
//head
	var/randimh = rand(1,5)
	switch(randimh)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_pilotka(H), slot_head)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka(H), slot_head)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka/down(H), slot_head)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww/adriansoviet(H), slot_head)
		if (5)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/soviet(H), slot_head)
//weapon
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/randimpw = rand(1,6)
	switch(randimpw)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin/m30(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosin/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosin(null)
			uniform.attackby(webbing, H)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin/m30(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosinalt/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosinalt(null)
			uniform.attackby(webbing, H)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin/m30(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosinaltsmoke/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosinaltsmoke(null)
			uniform.attackby(webbing, H)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin/m30(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosinbay/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosinbay(null)
			uniform.attackby(webbing, H)
		if (5)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ppd(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/ppsh/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/ppsh(null)
			uniform.attackby(webbing, H)
		if (6)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/dp28(H), slot_l_hand)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/sovietmg(H), slot_belt)
			var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/dpgun/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/dpgun(null)
			uniform.attackby(webbing, H)

	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a simple milita, Follow your <b>Sergeant's</b> orders!")
	H.add_note("Milita", "-Your aim sucks, Follow your Squad Leader and set up ambushes so you can actually achive something!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_NORMAL)
	return TRUE

////////////////////////////////////////////////////////////////
////////////////////RUSSIAN/CIVIL/WAR///////////////////////////
////////////////////////////////////////////////////////////////


/datum/job/russian/rcw_captain
	title = "Belaya Armiya Kapitan"
	en_meaning = "White Army Captain"
	rank_abbreviation = "Kpt."


	spawn_location = "JoinLateRU"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_rcw = TRUE



	min_positions = 1
	max_positions = 2

/datum/job/russian/rcw_captain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/rusuni_ww1_officer, slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/rusoffcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/nagant_revolver(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c762x38mmR(H), slot_l_store)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_r_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	world << "<b><big>[H.real_name] is the Captain of the White Forces!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, the highest ranking officer present. Your job is to command the company.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/russian/rcw_sergeant
	title = "Belaya Armiya Feldvebel"
	en_meaning = "White Army Sergeant"
	rank_abbreviation = "Fv."

	spawn_location = "JoinLateRU"
	is_squad_leader = TRUE
	uses_squads = TRUE

	is_rcw = TRUE


	min_positions = 2
	max_positions = 8

/datum/job/russian/rcw_sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/rusuni_ww1(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/rusoffcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/nagant_revolver(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin(H), slot_shoulder)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/chest/holsterh = new /obj/item/clothing/accessory/holster/chest(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a sergeant leading a squad. Organize your group according to the <b>Captain</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/russian/rcw_doctor
	title = "Belaya Armiya Medik"
	en_meaning = "White Army Doctor"
	rank_abbreviation = "Dr."

	spawn_location = "JoinLateRU"

	is_rcw = TRUE
	is_medic = TRUE

	min_positions = 1
	max_positions = 10

/datum/job/russian/rcw_doctor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/rusuni_ww1(H), slot_w_uniform) // for now
//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ruscap(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww/papakha/white(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/surgery(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches(H), slot_belt)
	var/obj/item/clothing/accessory/armband/redcross/armband = new /obj/item/clothing/accessory/armband/redcross(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(armband, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, the most qualified medic present, and you are in charge of keeping the soldiers healthy.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)


	return TRUE

/datum/job/russian/rcw_infantry
	title = "Belaya Armiya Soldat"
	en_meaning = "White Army Soldier"
	rank_abbreviation = ""

	spawn_location = "JoinLateRU" //for testing!

	is_rcw = TRUE
	uses_squads = TRUE


	min_positions = 6
	max_positions = 100

/datum/job/russian/rcw_infantry/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/rusuni_ww1(H), slot_w_uniform)
//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ruscap(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww/papakha/white(H), slot_head)
//jacket
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin(H), slot_shoulder)

	H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/russian/ww1/soldier(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/bint(H), slot_l_store)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a simple soldier of the White Army. Follow your <b>Officer's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE


/datum/job/russian/cossack_leader
	title = "Kazachy Vakhmistr"
	en_meaning = "Cossack Leader"
	rank_abbreviation = "Vakhmistr"

	spawn_location = "JoinLateRU2"

	is_rcw = TRUE
	uses_squads = TRUE
	is_squad_leader = TRUE
	is_officer = TRUE
	whitelisted = TRUE


	min_positions = 1
	max_positions = 3

/datum/job/russian/cossack_leader/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/kuban_cossak(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww/papakha/kuban(H), slot_head)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/kuban_cossak(H), slot_wear_suit)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin/obrez(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/shashka(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin/obrez(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/bint(H), slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/double/holsterh = new /obj/item/clothing/accessory/holster/hip/double(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, leading a squad of cossacks loyal to the White Army. Lead your shock troops and defeat the Reds!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/russian/cossack_soldier
	title = "Kazak"
	en_meaning = "Cossack Soldier"
	rank_abbreviation = "Kazak"

	spawn_location = "JoinLateRU2"

	is_rcw = TRUE
	uses_squads = TRUE

	min_positions = 6
	max_positions = 70

/datum/job/russian/cossack_soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding2(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/kuban_cossak(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww/papakha/kuban(H), slot_head)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/kuban_cossak(H), slot_wear_suit)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin(H), slot_shoulder)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/shashka(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/bint(H), slot_l_store)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a member of a cossack squad loyal to the White Army. Use shock tactics to defeat the Reds!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/civilian/russian
	default_language = "Russian"
/datum/job/civilian/russian/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_russian_name(H.gender)
	H.real_name = H.name


/datum/job/civilian/russian/cheka_comissar
	title = "Chekist"
	en_meaning = "VChEKA Political Comissar"
	rank_abbreviation = "Chekist"

	spawn_location = "JoinLateRU3"

	is_rcw = TRUE
	is_officer = TRUE
	whitelisted = TRUE


	min_positions = 1
	max_positions = 3

/datum/job/civilian/russian/cheka_comissar/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/rusuni_rcw(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww/cheka(H), slot_head)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/cheka(H), slot_wear_suit)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/mauser(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/gulagguard/filled(H), slot_belt)
	give_random_name(H)
	var/obj/item/clothing/accessory/armband/british/armband = new /obj/item/clothing/accessory/armband/british(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(armband, H)
	var/obj/item/clothing/accessory/holster/chest/holster = new /obj/item/clothing/accessory/holster/chest(null)
	uniform.attackby(holster, H)
	H.add_note("Role", "You are a <b>[title]</b>, A member of the feared VChEKA. Since officer ranks were abolished in the Red Army, it is your duty to keep the troops motivated and obedient, and to ensure Commanders follow the Sovnarkom's (Soviet government) orders. Do not hesitate to execute any traitors!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/civilian/russian/red_army_leader
	title = "Krasny Armiya Kommander"
	en_meaning = "Red Army Squad Leader"
	rank_abbreviation = "Kom."

	spawn_location = "JoinLateRU3"

	uses_squads = TRUE
	is_rcw = TRUE
	is_squad_leader = TRUE


	min_positions = 2
	max_positions = 12

/datum/job/civilian/russian/red_army_leader/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new/obj/item/clothing/shoes/leatherboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/rusuni_rcw(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/russian_rcw(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/soviet_fieldcap(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin/obrez(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin/obrez(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/bint(H), slot_l_store)
	give_random_name(H)
	var/obj/item/clothing/accessory/armband/british/armband = new /obj/item/clothing/accessory/armband/british(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(armband, H)
	var/obj/item/clothing/accessory/holster/hip/double/holsterh = new /obj/item/clothing/accessory/holster/hip/double(null)
	uniform.attackby(holsterh, H)
	H.add_note("Role", "You are a <b>[title]</b>, leading a squad of red army soldiers. Organize your troops and defeat the Capitalists!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE
/datum/job/civilian/russian/red_army_doctor
	title = "Krasny Armiya Medik"
	en_meaning = "Red Army Doctor"
	rank_abbreviation = "Dr."

	spawn_location = "JoinLateRU3"
	is_rcw = TRUE
	is_medic = TRUE

	min_positions = 1
	max_positions = 10

/datum/job/civilian/russian/red_army_doctor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/rusuni_rcw(H), slot_w_uniform) // for now
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/russian_rcw(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/soviet_fieldcap(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches(H), slot_belt)
	/obj/item/weapon/storage/belt/leather
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/surgery(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	var/obj/item/clothing/accessory/armband/redcross/armband = new /obj/item/clothing/accessory/armband/redcross(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(armband, H)

	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, the most qualified medic present, and you are in charge of keeping the soldiers healthy.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)


	return TRUE

/datum/job/civilian/russian/red_army_soldier
	title = "Krasny Armiya Strelok"
	en_meaning = "Red Army Rifleman"
	rank_abbreviation = ""
	can_be_female = TRUE
	spawn_location = "JoinLateRU3"

	is_rcw = TRUE
	uses_squads = TRUE


	min_positions = 10
	max_positions = 100

/datum/job/civilian/russian/red_army_soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/rusuni_rcw(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/russian_rcw(H), slot_wear_suit)
//head
	var/randhead = pick(1,2,3)
	if (randhead == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/soviet_fieldcap(H), slot_head)
	else if (randhead == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww/budenovka(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww/papakha(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/bint(H), slot_l_store)
	give_random_name(H)
	var/obj/item/clothing/accessory/armband/british/armband = new /obj/item/clothing/accessory/armband/british(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(armband, H)
	if(prob(70))
		H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/russian/soldier(H), slot_belt)
		var/obj/item/clothing/accessory/storage/webbing/russbando = new /obj/item/clothing/accessory/storage/webbing/russband(null)
		uniform.attackby(russbando, H)
		russbando.attackby(new/obj/item/ammo_magazine/mosin, H)
		russbando.attackby(new/obj/item/ammo_magazine/mosin, H)
		russbando.attackby(new/obj/item/ammo_magazine/mosin, H)
		russbando.attackby(new/obj/item/ammo_magazine/mosin, H)
	else
		H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/russian/ww1/soldier(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>, a soldier of the Red Army. Follow your Commander's and local Chekist orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE



/// ww2 tankers///
/datum/job/russian/tank_crew_leader
	title = "Komandir Tanka"
	en_meaning = "Armored Squad Leader"
	rank_abbreviation = "Kom."

	spawn_location = "JoinLateRU"
	is_karelia = TRUE
	is_ww2 = TRUE
	is_reichstag = FALSE
	uses_squads = TRUE
	is_tanker = TRUE
	whitelisted = TRUE
	is_squad_leader = TRUE
	is_tankcom = TRUE

	min_positions = 2
	max_positions = 6

/datum/job/russian/tank_crew_leader/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet_tanker(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/rusoff(H), slot_belt)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_pilotka(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ppsh(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/nagant_revolver(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick(H), slot_gloves)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/russian(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction2(H), slot_back)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, the commander of a tank. Assemble your crew and lead your tank to victory!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/russian/tank_crew
	title = "Tankist"
	en_meaning = "Armored Crewman"
	rank_abbreviation = ""
	can_be_female = TRUE
	spawn_location = "JoinLateRU"
	is_karelia = TRUE
	is_ww2 = TRUE
	is_reichstag = FALSE
	is_tanker = TRUE
	uses_squads = TRUE

	min_positions = 4
	max_positions = 32

/datum/job/russian/tank_crew/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet_tanker(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/soviet_tanker(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/tt30(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick(H), slot_gloves)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/russian(H), slot_l_store)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/hip = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(hip, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a member of an armored vehicle crew. Get your role assigned and follow your Commander!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE


/datum/job/russian/guards_mechanized_squad_leader
	title = "Gvardii Serjant"
	en_meaning = "Guards Mechanized Squad Leader"
	rank_abbreviation = "Srj."

	spawn_location = "JoinLateRU"
	is_ss_panzer = TRUE
	is_karelia = FALSE
	is_ww2 = TRUE
	is_squad_leader = TRUE
	uses_squads = TRUE

	min_positions = 2
	max_positions = 6

/datum/job/russian/guards_mechanized_squad_leader/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet_officer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/rusoff(H), slot_belt)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_pilotka(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ppsh(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction2(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c762x38mmR(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/nagant_revolver(H), slot_l_hand)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)

	H.add_note("Role", "You are a <b>[title]</b>, the leader of a squad of Soviet Guards Mechanized Infantry. Coordinate with the Tanks and defeat the enemy!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)

	return TRUE

/datum/job/russian/guards_mechanized_infantry
	title = "Gvardii Krasnoarmeyets"
	en_meaning = "Guards Mechanized Infantry"
	rank_abbreviation = ""

	spawn_location = "JoinLateRU"
	can_be_female = TRUE
	is_ww2 = TRUE
	uses_squads = TRUE
	is_ss_panzer = TRUE
	is_karelia = FALSE
	min_positions = 6
	max_positions = 30

/datum/job/russian/guards_mechanized_infantry/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet(H), slot_w_uniform)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		if (prob(60))
			H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/soviet(H), slot_head)
//weapon
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/randimpw = rand(1,3)
	switch(randimpw)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/pps(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/ppshassault/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/ppshassault(null)
			uniform.attackby(webbing, H)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ppsh(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/ppshassault/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/ppshassault(null)
			uniform.attackby(webbing, H)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/svt(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/svtassault/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/svtassault(null)
			uniform.attackby(webbing, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a member of the Soviet Guards Mechanized Infantry. Follow your commander's orders and coordinate with the Tanks!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)

	return TRUE


/datum/job/russian/guards_sapper
	title = "Gvardii Sapyor"
	en_meaning = "Guards Sapper"
	rank_abbreviation = ""

	spawn_location = "JoinLateRUSap"
	is_ss_panzer = TRUE
	is_karelia = TRUE
	is_ww2 = TRUE

	min_positions = 2
	max_positions = 12

/datum/job/russian/guards_sapper/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/leather(H), slot_gloves)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/soviet(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/glasses/pilot(H), slot_eyes)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ppsh(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c762x25_ppsh(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c762x25_ppsh(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/nagant_revolver(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/ww2/sapper/russian(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/utility/sapper(H), slot_belt)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/drinks/bottle/canteen, slot_wear_id)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a sapper of the Guards. Place mines or remove them, sandbags, barbed wire,destroy enemy tanks and positions, and help repair the vehicles!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)

	return TRUE

/datum/job/russian/mosmil
	title = "Opolchenets"
	en_meaning = "Soviet Militia"
	is_smallsiegemoscow = TRUE
	spawn_location = "JoinEarlyMilita"
	min_positions = 10
	max_positions = 55

/datum/job/russian/mosmil/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	var/randshoe2 = rand(1,5)
	if (randshoe2 == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)
	else if (randshoe2 == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/workboots(H), slot_shoes)
	else if (randshoe2 == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/black(H), slot_shoes)
	else if (randshoe2 == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	else if (randshoe2 == 5)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/winterboots(H), slot_shoes)


//clothes
	var/randjack2 = rand(1,9)
	if (randjack2 == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/farmer_outfit(H), slot_w_uniform)
	else if (randjack2 == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/mechanic_outfit(H), slot_w_uniform)
	else if (randjack2 == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
	else if (randjack2 == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/civ4(H), slot_w_uniform)
	else if (randjack2 == 5)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/oldmansuit(H), slot_w_uniform)
	else if (randjack2 == 6)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/engi(H), slot_w_uniform)
	else if (randjack2 == 7)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)
	else if (randjack2 == 8)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
	else if (randjack2 == 9)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial5(H), slot_w_uniform)


//head
	var/randhead2 = rand(1,7)
	switch(randhead2)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/sov_ushanka_new(H), slot_head)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka(H), slot_head)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/soviet(H), slot_head)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/fedora(H), slot_head)
		if (5)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/soviet_tanker(H), slot_head)
		if (6)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww/adriansoviet(H), slot_head)
		if (7)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/soviet(H), slot_head)

//gloves
	var/randglove2 = rand(1,4)
	switch(randglove2)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/leather(H), slot_gloves)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/gloves/fingerless(H), slot_gloves)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/leather(H), slot_gloves)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/clothing/gloves/motorist(H), slot_gloves)


//misc
	var/randmisc2 = rand(1,6)
	switch(randmisc2)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/glasses/pilot(H), slot_eyes)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/mask/shemagh/greykerchief(H), slot_wear_mask)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/mask/shemagh/redkerchief(H), slot_wear_mask)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/clothing/mask/smokable/cigarette(H), slot_wear_mask)
		if (5)
			H.equip_to_slot_or_del(new /obj/item/clothing/mask/smokable/cigarette/cigar(H), slot_wear_mask)
		if (6)
			H.equip_to_slot_or_del(new /obj/item/clothing/mask/smokable/cigarette(H), slot_wear_mask)

//weapon
	var/randarmw = rand(1,3)
	switch(randarmw)
		if (1)
			if (prob(75))
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/nagant_revolver(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c762x38mmR(H), slot_r_hand)
			else
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/nagant_revolver(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c762x38mmR(H), slot_r_hand)

		if (2)
			if (prob(60))
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ppd(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c762x25_ppsh(H), slot_r_hand)
			else
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ppsh(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c762x25_ppsh(H), slot_r_hand)
		if (3)
			if (prob(75))
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin/m30(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mosin(H), slot_r_hand)
			else
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin/obrez(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mosin(H), slot_r_hand)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/modern/plate/armor = new /obj/item/clothing/accessory/armor/modern/plate(null)
	uniform.attackby(armor, H)

//suit
	var/randsuits = rand(1,6)
	if (randsuits == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/expensivecoat(H), slot_wear_suit)
	else if (randsuits == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/sovcoat(H), slot_wear_suit)
	else if (randsuits == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/sovcoat2(H), slot_wear_suit)
	else if (randsuits == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/russian_rcw(H), slot_wear_suit)
	else if (randsuits == 5)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/soviet(H), slot_wear_suit)
	else if (randsuits == 6)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/soviet(H), slot_wear_suit)

	H.add_note("Role", "You are a <b>[title]</b>, you were conscripted or volunteered to fight for the soviet union,with minimal training you will defeat fascism!")

	give_random_name(H)
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	return TRUE

// Modern
/datum/job/russian/modern_lieutenant
	title = "Starshiy Leitenant"
	en_meaning = "1st Lieutenant"
	rank_abbreviation = "St. Lt."

	is_operation_falcon = TRUE
	is_commander = TRUE
	is_officer = TRUE

	whitelisted = TRUE

	additional_languages = list("English" = 70)
	min_positions = 1
	max_positions = 1

/datum/job/russian/modern_lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/russian(H), slot_w_uniform)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/b45/b45 = new /obj/item/clothing/accessory/armor/coldwar/plates/b45(null)
	uniform.attackby(b45, H)
	var/obj/item/weapon/armorplates/plates1 = new /obj/item/weapon/armorplates(null)
	var/obj/item/weapon/armorplates/plates2 = new /obj/item/weapon/armorplates(null)
	uniform.attackby(plates1, H)
	uniform.attackby(plates2, H)
//equipment
	H.equip_to_slot_or_del(new /obj/item/clothing/head/beret_rus_vdv(H), slot_head)

	var/obj/item/weapon/gun/projectile/submachinegun/ak74m/HGUN = new/obj/item/weapon/gun/projectile/submachinegun/ak74m(H)
	H.equip_to_slot_or_del(HGUN, slot_shoulder)
	var/obj/item/weapon/attachment/scope/adjustable/advanced/pso1/SP = new/obj/item/weapon/attachment/scope/adjustable/advanced/pso1(src)
	SP.attached(null,HGUN,TRUE)
	var/obj/item/weapon/attachment/under/foregrip/FP = new/obj/item/weapon/attachment/under/foregrip(src)
	FP.attached(null,HGUN,TRUE)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/laser_designator(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/russian(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/ak74m_smoke(H), slot_belt)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction2(H), slot_back)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	give_random_name(H)

	return TRUE

/datum/job/russian/modern_squadleader
	title = "Serjant"
	en_meaning = "Squad Leader"
	rank_abbreviation = "Srj."
	spawn_location = "JoinLateRU"

	is_operation_falcon = TRUE
	is_squad_leader = TRUE

	uses_squads = TRUE

	additional_languages = list("English" = 70)
	min_positions = 1
	max_positions = 10

/datum/job/russian/modern_squadleader/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/russian(H), slot_w_uniform)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/b45/b45 = new /obj/item/clothing/accessory/armor/coldwar/plates/b45(null)
	uniform.attackby(b45, H)
	var/obj/item/weapon/armorplates/plates1 = new /obj/item/weapon/armorplates(null)
	var/obj/item/weapon/armorplates/plates2 = new /obj/item/weapon/armorplates(null)
	uniform.attackby(plates1, H)
	uniform.attackby(plates2, H)
//equipment
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/russian_b7(H), slot_head)

	var/obj/item/weapon/gun/projectile/submachinegun/ak74m/HGUN = new/obj/item/weapon/gun/projectile/submachinegun/ak74m(H)
	H.equip_to_slot_or_del(HGUN, slot_shoulder)
	var/obj/item/weapon/attachment/scope/adjustable/advanced/pso1/SP = new/obj/item/weapon/attachment/scope/adjustable/advanced/pso1(src)
	SP.attached(null,HGUN,TRUE)
	var/obj/item/weapon/attachment/under/foregrip/FP = new/obj/item/weapon/attachment/under/foregrip(src)
	FP.attached(null,HGUN,TRUE)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/russian(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/ak74m_smoke(H), slot_belt)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction2(H), slot_back)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	give_random_name(H)

	return TRUE

/datum/job/russian/modern_medic
	title = "Voynenvrach"
	en_meaning = "Doctor"
	rank_abbreviation = "Efr."
	spawn_location = "JoinLateRU"

	is_operation_falcon = TRUE
	is_medic = TRUE

	uses_squads = TRUE

	additional_languages = list("English" = 15)
	min_positions = 2
	max_positions = 8

/datum/job/russian/modern_medic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/russian(H), slot_w_uniform)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/b45/b45 = new /obj/item/clothing/accessory/armor/coldwar/plates/b45(null)
	uniform.attackby(b45, H)
	var/obj/item/weapon/armorplates/plates1 = new /obj/item/weapon/armorplates(null)
	var/obj/item/weapon/armorplates/plates2 = new /obj/item/weapon/armorplates(null)
	uniform.attackby(plates1, H)
	uniform.attackby(plates2, H)
	var/obj/item/clothing/accessory/custom/armband/medicalarm = new /obj/item/clothing/accessory/armband/redcross(null)
	uniform.attackby(medicalarm, H)
//equipment
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/russian_b7(H), slot_head)

	var/obj/item/weapon/gun/projectile/submachinegun/ak74m/HGUN = new/obj/item/weapon/gun/projectile/submachinegun/ak74m(H)
	H.equip_to_slot_or_del(HGUN, slot_shoulder)
	var/obj/item/weapon/attachment/scope/adjustable/advanced/pso1/SP = new/obj/item/weapon/attachment/scope/adjustable/advanced/pso1(src)
	SP.attached(null,HGUN,TRUE)
	var/obj/item/weapon/attachment/under/foregrip/FP = new/obj/item/weapon/attachment/under/foregrip(src)
	FP.attached(null,HGUN,TRUE)

	H.equip_to_slot_or_del(new /obj/item/clothing/mask/sterile(H), slot_wear_mask)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat/modern(H), slot_belt)

	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	H.add_note("Role", "You are a <b>[title]</b>. Keep your fellow soldiers healthy and alive!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_VERY_HIGH)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE

/datum/job/russian/modern_radioman
	title = "Radio Operator"
	rank_abbreviation = "Efr."
	spawn_location = "JoinLateRU"

	is_operation_falcon = TRUE
	is_radioman = TRUE

	uses_squads = TRUE

	additional_languages = list("English" = 15)
	min_positions = 1
	max_positions = 5

/datum/job/russian/modern_radioman/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/russian(H), slot_w_uniform)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/b45/b45 = new /obj/item/clothing/accessory/armor/coldwar/plates/b45(null)
	uniform.attackby(b45, H)
	var/obj/item/weapon/armorplates/plates1 = new /obj/item/weapon/armorplates(null)
	var/obj/item/weapon/armorplates/plates2 = new /obj/item/weapon/armorplates(null)
	uniform.attackby(plates1, H)
	uniform.attackby(plates2, H)
//equipment
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/russian_b7(H), slot_head)

	var/obj/item/weapon/gun/projectile/submachinegun/ak74m/HGUN = new/obj/item/weapon/gun/projectile/submachinegun/ak74m(H)
	H.equip_to_slot_or_del(HGUN, slot_shoulder)
	var/obj/item/weapon/attachment/scope/adjustable/advanced/pso1/SP = new/obj/item/weapon/attachment/scope/adjustable/advanced/pso1(src)
	SP.attached(null,HGUN,TRUE)
	var/obj/item/weapon/attachment/under/foregrip/FP = new/obj/item/weapon/attachment/under/foregrip(src)
	FP.attached(null,HGUN,TRUE)

	H.equip_to_slot_or_del(new /obj/item/weapon/grenade/smokebomb/signal/rdg2_yellow(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/ak74m_smoke(H), slot_belt)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction2(H), slot_back)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	give_random_name(H)

	return TRUE

/datum/job/russian/modern_rifleman
	title = "Private"
	rank_abbreviation = "Ryad."
	spawn_location = "JoinLateRU"

	is_operation_falcon = TRUE

	uses_squads = TRUE

	additional_languages = list("English" = 15)
	min_positions = 5
	max_positions = 100

/datum/job/russian/modern_rifleman/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/russian(H), slot_w_uniform)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/b45/b45 = new /obj/item/clothing/accessory/armor/coldwar/plates/b45(null)
	uniform.attackby(b45, H)
	var/obj/item/weapon/armorplates/plates1 = new /obj/item/weapon/armorplates(null)
	var/obj/item/weapon/armorplates/plates2 = new /obj/item/weapon/armorplates(null)
	uniform.attackby(plates1, H)
	uniform.attackby(plates2, H)
//equipment
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/russian_b7(H), slot_head)

	var/obj/item/weapon/gun/projectile/submachinegun/ak74m/HGUN = new/obj/item/weapon/gun/projectile/submachinegun/ak74m(H)
	H.equip_to_slot_or_del(HGUN, slot_shoulder)
	var/obj/item/weapon/attachment/scope/adjustable/advanced/pso1/SP = new/obj/item/weapon/attachment/scope/adjustable/advanced/pso1(src)
	SP.attached(null,HGUN,TRUE)
	var/obj/item/weapon/attachment/under/foregrip/FP = new/obj/item/weapon/attachment/under/foregrip(src)
	FP.attached(null,HGUN,TRUE)

	H.equip_to_slot_or_del(new /obj/item/weapon/foldable_shovel/trench/etool(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/ak74m_smoke(H), slot_belt)

	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	give_random_name(H)

	return TRUE

/datum/job/russian/modern_tanker
	title = "Voditel' Tanka"
	en_meaning = "Armored Crewman"
	rank_abbreviation = "Efr."
	spawn_location = "JoinLateRU"

	is_operation_falcon = TRUE

	additional_languages = list("English" = 15)
	min_positions = 1
	max_positions = 6

/datum/job/russian/modern_tanker/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/russian(H), slot_w_uniform)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/b45/b45 = new /obj/item/clothing/accessory/armor/coldwar/plates/b45(null)
	uniform.attackby(b45, H)
	var/obj/item/weapon/armorplates/plates1 = new /obj/item/weapon/armorplates(null)
	var/obj/item/weapon/armorplates/plates2 = new /obj/item/weapon/armorplates(null)
	uniform.attackby(plates1, H)
	uniform.attackby(plates2, H)
//equipment
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/soviet_tanker(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/mp443(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/russian(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mp443(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/compass/modern/tacmap(H), slot_belt)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	give_random_name(H)

	return TRUE

/datum/job/russian/emplaced_weapon_specialist
	title = "Spetsialist po razmeshchennomu oruzhiyu"
	en_meaning = "Emplaced Weapons Specialist"
	rank_abbreviation = "Ryad."
	spawn_location = "JoinLateRU"

	is_operation_falcon = TRUE

	uses_squads = TRUE

	additional_languages = list("English" = 15)
	min_positions = 1
	max_positions = 6

/datum/job/russian/emplaced_weapon_specialist/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/russian(H), slot_w_uniform)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/b45/b45 = new /obj/item/clothing/accessory/armor/coldwar/plates/b45(null)
	uniform.attackby(b45, H)
	var/obj/item/weapon/armorplates/plates1 = new /obj/item/weapon/armorplates(null)
	var/obj/item/weapon/armorplates/plates2 = new /obj/item/weapon/armorplates(null)
	uniform.attackby(plates1, H)
	uniform.attackby(plates2, H)
//equipment
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/russian_b7(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/gunbox/emplacement(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/foldable_shovel/trench/etool(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mp443(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/mp443(H), slot_belt)

	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	give_random_name(H)

	return TRUE

/datum/job/russian/weapon_specialist
	title = "Spetsialist po oruzhiyu"
	en_meaning = "Weapons Specialist"
	rank_abbreviation = "Efr."
	spawn_location = "JoinLateRU"

	is_operation_falcon = TRUE

	uses_squads = TRUE

	additional_languages = list("English" = 15)
	min_positions = 1
	max_positions = 10

/datum/job/russian/weapon_specialist/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/russian(H), slot_w_uniform)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/b45/b45 = new /obj/item/clothing/accessory/armor/coldwar/plates/b45(null)
	uniform.attackby(b45, H)
	var/obj/item/weapon/armorplates/plates1 = new /obj/item/weapon/armorplates(null)
	var/obj/item/weapon/armorplates/plates2 = new /obj/item/weapon/armorplates(null)
	uniform.attackby(plates1, H)
	uniform.attackby(plates2, H)
//equipment
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/russian_b7(H), slot_head)

	var/obj/item/weapon/gun/projectile/submachinegun/ak74m/HGUN = new/obj/item/weapon/gun/projectile/submachinegun/ak74m(H)
	H.equip_to_slot_or_del(HGUN, slot_shoulder)
	var/obj/item/weapon/attachment/scope/adjustable/advanced/pso1/SP = new/obj/item/weapon/attachment/scope/adjustable/advanced/pso1(src)
	SP.attached(null,HGUN,TRUE)
	var/obj/item/weapon/attachment/under/foregrip/FP = new/obj/item/weapon/attachment/under/foregrip(src)
	FP.attached(null,HGUN,TRUE)

	H.equip_to_slot_or_del(new /obj/item/gunbox/specialist(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/ak74m_smoke(H), slot_belt)

	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	give_random_name(H)

	return TRUE

/datum/job/russian/modern_paratrooper
	title = "Parashyutist"
	en_meaning = "Paratrooper"
	rank_abbreviation = "Efr."
	spawn_location = "Paradrop"

	is_operation_falcon = TRUE
	is_paratrooper = TRUE

	additional_languages = list("English" = 15)
	min_positions = 1
	max_positions = 6

/datum/job/russian/modern_paratrooper/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/russian(H), slot_w_uniform)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/b45/b45 = new /obj/item/clothing/accessory/armor/coldwar/plates/b45(null)
	uniform.attackby(b45, H)
	var/obj/item/weapon/armorplates/plates1 = new /obj/item/weapon/armorplates(null)
	var/obj/item/weapon/armorplates/plates2 = new /obj/item/weapon/armorplates(null)
	uniform.attackby(plates1, H)
	uniform.attackby(plates2, H)
//equipment
	H.equip_to_slot_or_del(new /obj/item/clothing/head/beret_rus_vdv(H), slot_head)

	var/obj/item/weapon/gun/projectile/submachinegun/ak74m/HGUN = new/obj/item/weapon/gun/projectile/submachinegun/ak74m(H)
	H.equip_to_slot_or_del(HGUN, slot_shoulder)
	if(prob(70))
		var/obj/item/weapon/attachment/under/foregrip/FP = new/obj/item/weapon/attachment/under/foregrip(src)
		FP.attached(null,HGUN,TRUE)

	H.equip_to_slot_or_del(new /obj/item/weapon/grenade/smokebomb/signal/rdg2_yellow(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/ak74m_trench(H), slot_belt)

	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_HIGH)
	give_random_name(H)

	return TRUE

/////////////////////SIBERIAD//////////////////////////////////

/datum/job/russian/siberiad/lt
	title = "Operatsionnyy rukovoditel"
	en_meaning = "Operation lead"
	rank_abbreviation = "Opr."
	spawn_location = "JoinLateRU"

	is_siberiad = TRUE
	is_commander = TRUE
	is_officer = TRUE

	uses_squads = TRUE
	whitelisted = TRUE

	additional_languages = list("English" = 70)
	min_positions = 1
	max_positions = 1

/datum/job/russian/siberiad/lt/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet_amoeba/winter(H), slot_w_uniform)
//thermal
	H.equip_to_slot_or_del(new /obj/item/clothing/glasses/thermal(H), slot_eyes)
//mask
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/headscarfgrey/white(H), slot_wear_mask)
//gun
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74m/ak12(H), slot_shoulder)
//belt
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/sov_74_alt(H), slot_belt)
//helmet
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ssh_68/winter(H), slot_head)
//glove
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/leather/white(H), slot_gloves)
//id
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
//other shit
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/british/red = new /obj/item/clothing/accessory/armband/british(null)
	uniform.attackby(red, H)
	var/obj/item/clothing/accessory/armor/coldwar/plates/b5/armour2 = new /obj/item/clothing/accessory/armor/coldwar/plates/b5(null)
	uniform.attackby(armour2, H)
	var/obj/item/weapon/armorplates/plates1 = new /obj/item/weapon/armorplates(null)
	var/obj/item/weapon/armorplates/plates2 = new /obj/item/weapon/armorplates(null)
	armour2.attackby(plates1, H)
	armour2.attackby(plates2, H)
	uniform.attackby(armour2, H)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/rucksack/small/command(H), slot_back)

	H.civilization = "Soviet"
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

/datum/job/russian/siberiad/squadlead
	title = "Komandir pekhotnogo vzvoda"
	en_meaning = "Infantry Squad leader"
	rank_abbreviation = "Kpv."
	spawn_location = "JoinLateRU"

	is_siberiad = TRUE
	is_squad_leader = TRUE

	uses_squads = TRUE
	whitelisted = FALSE

	additional_languages = list("English" = 20)
	min_positions = 2
	max_positions = 8

/datum/job/russian/siberiad/squadlead/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet_berezka(H), slot_w_uniform)
//thermal
	H.equip_to_slot_or_del(new /obj/item/clothing/glasses/tactical_goggles/ballistic(H), slot_eyes)
//mask
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/headscarfgrey/asbestos(H), slot_wear_mask)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/british/red = new /obj/item/clothing/accessory/armband/british(null)
	uniform.attackby(red, H)
	var/obj/item/clothing/accessory/armor/coldwar/plates/b5/armour2 = new /obj/item/clothing/accessory/armor/coldwar/plates/b5(null)
	uniform.attackby(armour2, H)
//gun
	var/randimpw = rand(1,2)
	switch(randimpw)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74m/ak12(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/ak74m_trench(H), slot_belt)
			var/obj/item/clothing/accessory/storage/webbing/green_webbing/blue/ak74/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing/blue/ak74(null)
			uniform.attackby(webbing, H)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74m(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/ak74m_smoke(H), slot_belt)
			var/obj/item/clothing/accessory/storage/webbing/green_webbing/blue/ak74/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing/blue/ak74(null)
			uniform.attackby(webbing, H)
//helmet
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ssh_68/winter(H), slot_head)
//glove
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)
//id
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
//other shit
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_r_store)
//suit
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/fur/klyaksa(H), slot_wear_suit)
//back
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/rucksack/small/medical(H), slot_back)
	else if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/rucksack/small/extracap/medicalh(H), slot_back)
	H.civilization = "Soviet"
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

/datum/job/russian/siberiad/heavy
	title = "Tyazhelaya pekhota"
	en_meaning = "Heavy infantry"
	rank_abbreviation = "H."
	spawn_location = "JoinLateRU"

	is_siberiad = TRUE

	uses_squads = TRUE
	whitelisted = FALSE

	additional_languages = list("English" = 10)
	min_positions = 4
	max_positions = 8

/datum/job/russian/siberiad/heavy/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/gorka/frag(H), slot_w_uniform)
//thermal
	H.equip_to_slot_or_del(new /obj/item/clothing/glasses/tactical_goggles/ballistic(H), slot_eyes)
//mask
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/headscarfgrey/asbestos(H), slot_wear_mask)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/british/red = new /obj/item/clothing/accessory/armband/british(null)
	uniform.attackby(red, H)
	var/obj/item/clothing/accessory/armor/coldwar/plates/b5/armour2 = new /obj/item/clothing/accessory/armor/coldwar/plates/b5(null)
	uniform.attackby(armour2, H)
	var/obj/item/weapon/armorplates/plates1 = new /obj/item/weapon/armorplates(null)
	var/obj/item/weapon/armorplates/plates2 = new /obj/item/weapon/armorplates(null)
	armour2.attackby(plates1, H)
	armour2.attackby(plates2, H)
	uniform.attackby(armour2, H)
//gun
	var/randimpw = rand(1,3)
	switch(randimpw)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/pkm(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/white/pkm(H), slot_belt)
			var/obj/item/clothing/accessory/storage/webbing/russian/guns/pkm/webbing = new /obj/item/clothing/accessory/storage/webbing/russian/guns/pkm(null)
			uniform.attackby(webbing, H)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/rpk74(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/white/rpk(H), slot_belt)
			var/obj/item/clothing/accessory/storage/webbing/russian/guns/rpk/webbing = new /obj/item/clothing/accessory/storage/webbing/russian/guns/rpk(null)
			uniform.attackby(webbing, H)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/rpd(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/white/rpd(H), slot_belt)
			var/obj/item/clothing/accessory/storage/webbing/russian/guns/rpd/webbing = new /obj/item/clothing/accessory/storage/webbing/russian/guns/rpd(null)
			uniform.attackby(webbing, H)
//helmet
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/sovietfacehelmet(H), slot_head)
//glove
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)
//id
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
//suit
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/fur/klyaksa(H), slot_wear_suit)
//other shit
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_r_store)

	H.civilization = "Soviet"
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

/datum/job/russian/siberiad/infantry
	title = "Legkaya pekhota"
	en_meaning = "Light Infantry"
	rank_abbreviation = " "
	spawn_location = "JoinLateRU"

	is_siberiad = TRUE

	uses_squads = TRUE
	whitelisted = FALSE

	additional_languages = list("English" = 5)
	min_positions = 9
	max_positions = 90

/datum/job/russian/siberiad/infantry/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet_berezka(H), slot_w_uniform)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/british/red = new /obj/item/clothing/accessory/armband/british(null)
	uniform.attackby(red, H)
	var/obj/item/clothing/accessory/armor/coldwar/plates/b3/armour2 = new /obj/item/clothing/accessory/armor/coldwar/plates/b3(null)
	uniform.attackby(armour2, H)
//gun
	var/randimpw = rand(1,4)
	switch(randimpw)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/ak74(H), slot_belt)
			var/obj/item/clothing/accessory/storage/webbing/green_webbing/blue/ak74/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing/blue/ak74(null)
			uniform.attackby(webbing, H)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74/aks74(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/ak74(H), slot_belt)
			var/obj/item/clothing/accessory/storage/webbing/green_webbing/blue/ak74/webbing = new /obj/item/clothing/accessory/storage/webbing/green_webbing/blue/ak74(null)
			uniform.attackby(webbing, H)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ppsh(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/soviet_ppsh(H), slot_belt)
			var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/ppsh/grenade/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/ppsh/grenade(null)
			uniform.attackby(webbing, H)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/mosin(H), slot_belt)
			var/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosin/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosin(null)
			uniform.attackby(webbing, H)
//helmet
	if (prob(45))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ssh_68/winter(H), slot_head)
	else if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka/down(H), slot_head)
//glove
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)
//suit
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/fur/klyaksa(H), slot_wear_suit)
//back
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/rucksack/small/milpack(H), slot_back)

	H.civilization = "Soviet"
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

//////////////////////////////Sino-Soviet Border Conflict////////////////////////////////

/datum/job/russian/soviet_border/kgb_lt
	title = "Leytenant Pogranichnikh Voysk KGB"
	en_meaning = "Soviet Border Troops Lieutenant"
	rank_abbreviation = "KGB Leyt."

	spawn_location = "JoinLateRUCap"

	is_commander = TRUE
	whitelisted = TRUE

	is_sinosovbor = TRUE
	is_ww2 = FALSE
	is_karelia = FALSE
	is_bordersov = FALSE
	is_radioman = TRUE
	can_get_coordinates = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/russian/soviet_border/kgb_lt/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet_officer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction2(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/soviet_officer(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/nkvd_cap/kgb(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/nagant_revolver(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/gulagguard/filledwarak(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/soviet(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak47/akms(H), slot_shoulder)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a member of the KGB attached to this border District. You are the highest ranking officer here, Organize your defenses!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_HIGH)
	return TRUE

/datum/job/russian/soviet_border/sergeant
	title = "Serzhant Pogranichnikh Voysk KGB"
	en_meaning = "Soviet Border Troops Sergeant"
	rank_abbreviation = "Srz."

	spawn_location = "JoinLateRU"

	is_squad_leader = TRUE
	uses_squads = TRUE
	whitelisted = FALSE

	is_sinosovbor = TRUE
	is_ww2 = FALSE
	is_karelia = FALSE
	is_bordersov = FALSE
	can_get_coordinates = TRUE

	min_positions = 2
	max_positions = 12

/datum/job/russian/soviet_border/sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(40))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet_nkvd/kgb(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/gulagguard/filled(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/toughguy(H), slot_gloves)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/nkvd_cap/kgb(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak47/akms(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/ak47(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/soviet(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction2(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/sovcoat(H), slot_wear_suit)
	give_random_name(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/russian/guns/ak47/webbing = new /obj/item/clothing/accessory/storage/webbing/russian/guns/ak47(null)
	uniform.attackby(webbing, H)
	H.add_note("Role", "You are a <b>[title]</b>. Get back to your post and follow your <b>Leytenant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/russian/soviet_border/guard
	title = "Ryadovoy Pogranichnikh Voysk KGB"
	en_meaning = "Soviet Border Troops Private"
	rank_abbreviation = ""

	spawn_location = "JoinLateRU"

	uses_squads = TRUE

	is_ww2 = FALSE
	is_sinosovbor = TRUE
	is_karelia = FALSE
	is_bordersov = FALSE

	min_positions = 2
	max_positions = 70

/datum/job/russian/soviet_border/guard/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(90))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet_berezka(H), slot_w_uniform)
//glove
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)
//gun
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/randimpw = rand(1,2)
	switch(randimpw)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak47(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/ak47(H), slot_belt)
			var/obj/item/clothing/accessory/storage/webbing/russian/guns/ak47/webbing = new /obj/item/clothing/accessory/storage/webbing/russian/guns/ak47(null)
			uniform.attackby(webbing, H)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak47/akms(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/green/ak47(H), slot_belt)
			var/obj/item/clothing/accessory/storage/webbing/russian/guns/ak47/webbing = new /obj/item/clothing/accessory/storage/webbing/russian/guns/ak47(null)
			uniform.attackby(webbing, H)
//helmet
	if (prob(45))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ssh_68/winter(H), slot_head)
	else if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka/down(H), slot_head)
//coat
	if (prob(45))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/sovcoat(H), slot_wear_suit)
	else if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/sovcoat2(H), slot_wear_suit)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/soviet(H), slot_wear_suit)
//grenade
	if (prob(20))
		H.equip_to_slot_or_del(new /obj/item/weapon/grenade/smokebomb/rdg2(H), slot_r_store)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/grenade/coldwar/rgd5(H), slot_r_store)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[en_meaning]</b>, stationed at the Soviet-Chinese border. Follow your <b>Sergeant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	return TRUE

/datum/job/russian/soviet_border/machinegunner
	title = "Pulemetchik Pogranichnikh Voysk KGB"
	en_meaning = "Soviet Border Troops Machinegunner"
	rank_abbreviation = ""

	spawn_location = "JoinLateRU"
	uses_squads = TRUE
	is_ww2 = FALSE

	is_sinosovbor = TRUE
	is_karelia = FALSE
	is_bordersov = FALSE

	min_positions = 1
	max_positions = 4

/datum/job/russian/soviet_border/machinegunner/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(40))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	if (prob(80))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet_berezka(H), slot_w_uniform)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet_amoeba/winter(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_wear_id)
//glove
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)
//gun
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/randimpw = rand(1,2)
	switch(randimpw)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/pkm(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/white/pkm(H), slot_belt)
			var/obj/item/clothing/accessory/storage/webbing/russian/guns/pkm/webbing = new /obj/item/clothing/accessory/storage/webbing/russian/guns/pkm(null)
			uniform.attackby(webbing, H)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/rpd(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/white/rpd(H), slot_belt)
			var/obj/item/clothing/accessory/storage/webbing/russian/guns/rpd/webbing = new /obj/item/clothing/accessory/storage/webbing/russian/guns/rpd(null)
			uniform.attackby(webbing, H)
//helmet
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ssh_68/winter(H), slot_head)
//coat
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/soviet(H), slot_wear_suit)
//grenade
	if (prob(10))
		H.equip_to_slot_or_del(new /obj/item/weapon/grenade/smokebomb/rdg2(H), slot_r_store)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/grenade/coldwar/rgd5(H), slot_r_store)
//extra grenade
	if (prob(10))
		H.equip_to_slot_or_del(new /obj/item/weapon/grenade/smokebomb/rdg2(H), slot_l_store)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/grenade/coldwar/rgd5(H), slot_l_store)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[en_meaning]</b>, stationed at the Soviet-Chinese border. Use your superior firepower to provide supression. Follow your <b>Sergeant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)
	return TRUE


/datum/job/russian/soviet_border/medic
	title = "Sanitar Pogranichnikh Voysk KGB"
	en_meaning = "Soviet Border Troops Corpsman"
	rank_abbreviation = "Efr."

	spawn_location = "JoinLateRU"

	is_ww2 = FALSE
	is_sinosovbor = TRUE
	is_karelia = FALSE
	is_bordersov = FALSE

	can_be_female = TRUE

	is_medic = TRUE
	min_positions = 1
	max_positions = 4

/datum/job/russian/soviet_border/medic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet_berezka(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ssh_68/winter/med(H), slot_head)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/doctor(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/early(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/tt30(H), slot_l_hand)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/redcross/white = new /obj/item/clothing/accessory/armband/redcross(null)
	uniform.attackby(white, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[en_meaning]</b>, the only qualified medical personnel present, keep the soliders healthy and well.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)

	return TRUE
