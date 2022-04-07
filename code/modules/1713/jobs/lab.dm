/////////////////////////////////Lab////////////////////////////////////////


///////PMCs
/datum/job/american/pmcs
	default_language = "English"
	additional_languages = list("Russian" = 35, "Arabic" = 20)

/datum/job/american/pmcs/combatreport
	title = "Combat Reporter"
	rank_abbreviation = "CR."

	spawn_location = "JoinLateHF"

	is_lab = TRUE
	can_be_female = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/american/pmcs/combatreport/equip(var/mob/living/human/H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/pmc(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/kevlarhelmet(H), slot_head)
//belt
	H.equip_to_slot_or_del(new /obj/item/camera(H), slot_belt)
//pockets
	H.equip_to_slot_or_del(new /obj/item/camera_film(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/camera_film(H), slot_r_store)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/nomads/baily = new /obj/item/clothing/accessory/armor/nomads/(null)
	uniform.attackby(baily, H)
//webbing
	var/obj/item/clothing/accessory/storage/webbing/green_webbing/web = new /obj/item/clothing/accessory/storage/webbing/green_webbing(null)
	uniform.attackby(web, H)
	give_random_name(H)
	H.civilization = "Facility personnel"
	H.add_note("Role", "You are a <b>[title]</b>. Take pictures of the PMCs fighting for their recruitment propaganda!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_NORMAL)
	return TRUE

/datum/job/american/pmcs/org
	title = "PMC Organizer"
	rank_abbreviation = "Lt."

	spawn_location = "JoinLateHF"


	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_lab = TRUE
	is_radioman = TRUE
	can_be_female = TRUE

	min_positions = 1
	max_positions = 2

/datum/job/american/pmcs/org/equip(var/mob/living/human/H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/baily(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/swat(H), slot_head)
//gun
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/special/mk18(H), slot_shoulder)
//belt
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_belt)
//pockets
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mk18(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mk18(H), slot_r_store)
//goggles
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/tactical_goggles(H), slot_eyes)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/nomads/baily = new /obj/item/clothing/accessory/armor/nomads/(null)
	uniform.attackby(baily, H)
	//webbing

	var/obj/item/clothing/accessory/storage/webbing/green_webbing/web = new /obj/item/clothing/accessory/storage/webbing/green_webbing(null)
	uniform.attackby(web, H)
	H.civilization = "Facility personnel"
	H.add_note("Role", "You are a <b>[title]</b>. You are in charge of the Operation. Organize your troops and save the facility!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)
	H.setStat("machinegun", STAT_HIGH)
	return TRUE

/datum/job/american/pmcs/serg
	title = "PMC Sergeant"
	rank_abbreviation = "Sgt."

	spawn_location = "JoinLateHF"


	is_squad_leader = TRUE
	is_lab = TRUE
	can_get_coordinates = TRUE
	is_radioman = TRUE
	can_be_female = TRUE

	min_positions = 2
	max_positions = 8

/datum/job/american/pmcs/serg/equip(var/mob/living/human/H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/pmc(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/swat(H), slot_head)
//gun
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/special/mk18(H), slot_shoulder)
//belt
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_belt)
//backpack
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/rucksack(H), slot_back)
//pockets
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mk18(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mk18(H), slot_r_store)
//goggles
	if (prob(80))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/nvg(H), slot_eyes)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/nomads/baily = new /obj/item/clothing/accessory/armor/nomads/(null)
	uniform.attackby(baily, H)
//webbing
	var/obj/item/clothing/accessory/storage/webbing/green_webbing/web = new /obj/item/clothing/accessory/storage/webbing/green_webbing(null)
	uniform.attackby(web, H)
	give_random_name(H)
	H.civilization = "Facility personnel"
	H.add_note("Role", "You are a <b>[title]</b>. Organize and Lead your Squad into the Facility!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_HIGH)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_HIGH)
	H.setStat("machinegun", STAT_NORMAL)
	return TRUE

/datum/job/american/pmcs/medic
	title = "PMC Field medic"
	rank_abbreviation = "Cpl."

	spawn_location = "JoinLateHF"

	is_medic = TRUE
	is_lab = TRUE
	can_be_female = TRUE
	uses_squads = TRUE

	min_positions = 2
	max_positions = 20

/datum/job/american/pmcs/medic/equip(var/mob/living/human/H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/pmc(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/hazard/green(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/tactical(H), slot_head)
//gun
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/special/mk18(H), slot_shoulder)
//belt
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat/modern(H), slot_belt)
//backpack
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
//pockets
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mk18(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mk18(H), slot_r_store)
//goggles
	if (prob(80))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/nvg(H), slot_eyes)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/nomads/baily = new /obj/item/clothing/accessory/armor/nomads/(null)
	uniform.attackby(baily, H)
//webbing
	var/obj/item/clothing/accessory/storage/webbing/green_webbing/web = new /obj/item/clothing/accessory/storage/webbing/green_webbing(null)
	uniform.attackby(web, H)
//armband
	var/obj/item/clothing/accessory/armband/redcross = new /obj/item/clothing/accessory/armband/redcross(null)
	uniform.attackby(redcross, H)
	give_random_name(H)
	H.civilization = "Facility personnel"
	H.add_note("Role", "You are a <b>[title]</b>. Keep your fellow soliders healthy and battleready!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)
	H.setStat("machinegun", STAT_NORMAL)
	return TRUE

/datum/job/american/pmcs/fspec
	title = "PMC Spec"
	rank_abbreviation = "Spc."

	spawn_location = "JoinLateHF"

	is_lab = TRUE
	can_be_female = TRUE
	uses_squads = TRUE

	min_positions = 2
	max_positions = 5

/datum/job/american/pmcs/fspec/equip(var/mob/living/human/H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/pmc(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/swat(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/swat(H), slot_head)
//gun
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/p90(H), slot_shoulder)
//backpack
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/glass/flamethrower/filled/New(H), slot_back)
//belt
	H.equip_to_slot_or_del(new /obj/item/weapon/flamethrower(H), slot_belt)
//pockets
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/swat(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/p90(H), slot_r_store)
//goggles
	if (prob(90))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/thermal(H), slot_eyes)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/nomads/baily = new /obj/item/clothing/accessory/armor/nomads/(null)
	uniform.attackby(baily, H)
//webbing
	var/obj/item/clothing/accessory/storage/webbing/green_webbing/web = new /obj/item/clothing/accessory/storage/webbing/green_webbing(null)
	uniform.attackby(web, H)
	give_random_name(H)
	H.civilization = "Facility personnel"
	H.add_note("Role", "You are a <b>[title]</b>.A Designated Flamethrower specialist, use your flamethrower to roast enemies alive and your self defense gun to finish them off!!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_HIGH)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_NORMAL)
	return TRUE

/datum/job/american/pmcs/mgspec
	title = "PMC Machinegunner"
	rank_abbreviation = "Spc."

	spawn_location = "JoinLateHF"

	is_lab = TRUE
	can_be_female = TRUE
	uses_squads = TRUE

	min_positions = 2
	max_positions = 10

/datum/job/american/pmcs/mgspec/equip(var/mob/living/human/H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/pmc(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/medvest(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/swat(H), slot_head)
	//gun
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/p90(H), slot_shoulder)
	//belt
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/largepouches/m249(H), slot_belt)
	//gun2
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/m249(H), slot_l_hand)
	//pockets
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/p90(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/p90(H), slot_r_store)
		//goggles
	if (prob(90))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/nvg(H), slot_eyes)
		//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/nomads/baily = new /obj/item/clothing/accessory/armor/nomads/(null)
	uniform.attackby(baily, H)
	//webbing
	var/obj/item/clothing/accessory/storage/webbing/green_webbing/web = new /obj/item/clothing/accessory/storage/webbing/green_webbing(null)
	uniform.attackby(web, H)
	give_random_name(H)
	H.civilization = "Facility personnel"
	H.add_note("Role", "You are a <b>[title]</b>. carrying a light machine gun, provide supressive fire and cover your squads!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_VERY_HIGH)
	return TRUE

/datum/job/american/pmcs/solider
	title = "PMC Rifleman"
	rank_abbreviation = "Pvt."

	spawn_location = "JoinLateHF"

	is_lab = TRUE
	can_be_female = TRUE
	uses_squads = TRUE

	min_positions = 2
	max_positions = 100

/datum/job/american/pmcs/solider/equip(var/mob/living/human/H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/pmc(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/police(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/kevlarhelmet(H), slot_head)
//gun
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/p90(H), slot_shoulder)
//belt
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/p90(H), slot_belt)
//pockets
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/p90(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/p90(H), slot_r_store)
//goggles
	if (prob(95))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/nvg(H), slot_eyes)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/nomads/baily = new /obj/item/clothing/accessory/armor/nomads/(null)
	uniform.attackby(baily, H)
//webbing
	var/obj/item/clothing/accessory/storage/webbing/green_webbing/web = new /obj/item/clothing/accessory/storage/webbing/green_webbing(null)
	uniform.attackby(web, H)
	give_random_name(H)
	H.civilization = "Facility personnel"
	H.add_note("Role", "You are a <b>[title]</b>. Follow your Sergeant. and his orders!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_NORMAL)
	return TRUE

//////////////////////facility personnel///////////////////////

/datum/job/civilian/lab
	default_language = "English"
	additional_languages = list("Russian" = 25, "Arabic" = 10, "Chinese" = 20, "Spanish" = 5)

/datum/job/civilian/lab/cdir
	title = "Facility Director"
	rank_abbreviation = "Dir."

	spawn_location = "JoinLateMana"

	is_commander = TRUE
	whitelisted = TRUE
	is_lab = TRUE
	can_be_female = TRUE

	min_positions = 2
	max_positions = 2

/datum/job/civilian/lab/cdir/equip(var/mob/living/human/H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/color/white(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/waistcoat(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/medvest(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight(H), slot_wear_id)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/cap/blue(H), slot_head)
	//belt
	H.equip_to_slot_or_del(new /obj/item/weapon/analyser(H), slot_belt)
	//pockets
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
	//goggles
	if (prob(70))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses(H), slot_eyes)
	H.civilization = "Facility personnel"
	H.add_note("Role", "You are a <b>[title]</b>. Director of the facility,Do whatever you think is right!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)
	H.setStat("machinegun", STAT_NORMAL)
	return TRUE

/datum/job/civilian/lab/facguard
	title = "Facility guard"
	rank_abbreviation = "Fg."

	spawn_location = "JoinLateFacGu"

	is_lab = TRUE
	can_be_female = TRUE

	min_positions = 2
	max_positions = 10

/datum/job/civilian/lab/facguard/equip(var/mob/living/human/H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/customuniform/facilityg(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/police(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/kevlarhelmet(H), slot_head)
	//gun
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/p90(H), slot_shoulder)
	//belt
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/p90(H), slot_belt)
	//pockets
	H.equip_to_slot_or_del(new /obj/item/weapon/key/american/facility(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/p90(H), slot_r_store)
//goggles
	if (prob(95))
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/nvg(H), slot_eyes)
	//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/nomads/civiliankevlar/under/armor = new /obj/item/clothing/accessory/armor/nomads/civiliankevlar/under(null)
	uniform.attackby(armor, H)
	//webbing
	var/obj/item/clothing/accessory/storage/webbing/green_webbing/web = new /obj/item/clothing/accessory/storage/webbing/green_webbing(null)
	uniform.attackby(web, H)
	give_random_name(H)
	H.civilization = "Facility personnel"
	H.add_note("Role", "You are a <b>[title]</b>. A well trained special guard. Make sure that no facility personnel gets hurt!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_HIGH)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_HIGH)
	H.setStat("machinegun", STAT_HIGH)
	return TRUE

/datum/job/civilian/lab/facciv
	title = "Facility Maintaince tech"
	rank_abbreviation = "Fg."

	spawn_location = "JoinLateFacCiv"

	is_lab = TRUE
	can_be_female = TRUE

	min_positions = 2
	max_positions = 6

/datum/job/civilian/lab/facciv/equip(var/mob/living/human/H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/color/white(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/customuniform/facilityg(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/hazard(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
//hand
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/toolbox/emergency(H), slot_l_hand)
	H.civilization = "Facility personnel"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. a Maintaince technician of this facility,make sure that the facility stays in tip top shape!")
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("crafting", STAT_HIGH)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_NORMAL)
	return TRUE

/datum/job/civilian/lab/FacSci
	title = "Facility Researcher"
	rank_abbreviation = "."

	spawn_location = "JoinLateSci"

	is_lab = TRUE
	can_be_female = TRUE

	min_positions = 2
	max_positions = 5

/datum/job/american/pmcs/serg/equip(var/mob/living/human/H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/color/white(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/customuniform/facilityg(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/surgeon(H), slot_wear_suit)
//belt
	H.equip_to_slot_or_del(new /obj/item/weapon/analyser(H), slot_belt)
//hand
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/spray/sterilizine(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/flashlight/modern(H), slot_l_hand)
	H.civilization = "Facility personnel"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. a Researcher, do your job!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_HIGH)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_HIGH)
	H.setStat("machinegun", STAT_NORMAL)
	return TRUE

/datum/job/civilian/lab/facmed
	title = "Facility Doctor"
	rank_abbreviation = "Dr."

	spawn_location = "JoinLateFacMed"

	is_lab = TRUE
	can_be_female = TRUE
	is_medic = TRUE

	min_positions = 2
	max_positions = 5

/datum/job/civilian/lab/facmed/equip(var/mob/living/human/H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/color/white(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/customuniform/facilityg(H), slot_w_uniform)
//jacket
	if (prob(55))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/hazard/green(H), slot_wear_suit)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/doctor(H), slot_wear_suit)
//hand
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/spray/sterilizine(H), slot_r_hand)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
//flashlight
	H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight_alt(H), slot_wear_id)

	H.civilization = "Facility personnel"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. a Facility doctor, Heal your fellow friends and make sure everyone is fine!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_HIGH)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)
	H.setStat("machinegun", STAT_NORMAL)
	return TRUE

////////////////Prisoners and monsters////////////////////

/datum/job/civilian/lab/prisoner
	title = "Prisoner"
	rank_abbreviation = "."

	spawn_location = "JoinLateInm"

	is_lab = TRUE
	can_be_female = TRUE

	min_positions = 50
	max_positions = 250

/datum/job/civilian/lab/prisoner/equip(var/mob/living/human/H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/color/white(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/prisoner(H), slot_w_uniform)
//weapon
	if (prob(15))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/p90(H), slot_l_hand)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/p90(H), slot_r_hand)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/military/iron(H), slot_l_hand)

	H.civilization = "prisoner"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. a prisoner, you were transferred here for whatever reason,you need to escape this hellhole!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_NORMAL)
	return TRUE

/datum/job/civilian/lab/monster
	title = "Monster"
	rank_abbreviation = "."

	spawn_location = "JoinLateMon"

	is_lab = TRUE
	can_be_female = TRUE

	min_positions = 2
	max_positions = 4

/datum/job/civilian/lab/monster/equip(var/mob/living/human/H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/color/white(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/prisoner(H), slot_w_uniform)

	H.civilization = "Monster"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. a Former prisoner, the facility has commited unspeakable acts on you, take your revenge on them all!")
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_VERY_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)
	H.setStat("machinegun", STAT_NORMAL)
	return TRUE