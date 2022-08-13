/*///////////////////////////////submarine crew///////////////////////////////////

/datum/job/russian/crew
	faction = "Crew"

	/datum/job/russian/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_russian_name(H.gender)
	H.real_name = H.name

	/datum/job/russian/crew/Admiral
	title = "Admiral"
	rank_abbreviation = "Adm."
	is_subcrash = TRUE
	spawn_location = "JoinLateCCOM"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	can_be_female = TRUE
	additional_languages = list("English" = 95)

	min_positions = 1
	max_positions = 1

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/combat, slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/servicejacket(H), slot_wear_suit)
	//////misc
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)

						H.equip_to_slot_or_del(new /obj/item/clothing/head/cap/red(H), slot_head)

//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/makarov(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/makarov(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/makarov(H), slot_r_store)
	H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.civilization = "Crew"
	world << "<b><big>[H.real_name] is the Admiral of the submarine</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, the highest ranking officer present. Your job is to command this submarine and make sure that the enemy doesnt take it.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	/datum/job/russian/crew/Admiral Assistant
	title = "Admirals Assistant"
	rank_abbreviation = "Asm."
	is_subcrash = TRUE
	spawn_location = "JoinLateCCOM"
	is_officer = TRUE
	whitelisted = TRUE
	can_be_female = TRUE
	additional_languages = list("English" = 85)

	min_positions = 1
	max_positions = 2

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/combat, slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/a6b28(H), slot_wear_suit)
	//misc
		H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/zsh1(H), slot_head)

//weapons
	var/obj/item/clothing/accessory/armor/coldwar/plates/b3/armour2 = new /obj/item/clothing/accessory/armor/coldwar/plates/b3(null)
	uniform.attackby(armour2, H)
	var/obj/item/ammo_magazine/ak74/mag = new /obj/item/ammo_magazine/ak74(null)
	uniform.attackby(mag, H)
	var/obj/item/ammo_magazine/ak74/mag2 = new /obj/item/ammo_magazine/ak74(null)
	uniform.attackby(mag2, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74/aks74/aks74u(H), slot_shoulder)


	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/makarov(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/makarov(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/makarov(H), slot_r_store)
	H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.civilization = "Crew"
	H.add_note("Role", "You are a <b>[title]</b>, Your job is to make sure the admiral doesnt get hurt, and do his job for him incase he is hurt or missing.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_HIGH)



	/datum/job/russian/crew/medic
	title = "Submarine medic"
	rank_abbreviation = "Cpl."
	is_subcrash = TRUE
	spawn_location = "JoinLateCMED"
	can_be_female = TRUE
	additional_languages = list("English" = 55)

	min_positions = 10
	max_positions = 15

/datum/job/russian/captain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/combat, slot_w_uniform)
	//////misc
				H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
				                    H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
				                    	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat/modern(H), slot_belt)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/custom/armband/white = new /obj/item/clothing/accessory/custom/armband(null)
	uniform.attackby(white, H)

	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/makarov(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/makarov(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/makarov(H), slot_r_store)

		var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)


	give_random_name(H)
		H.civilization = "Crew"
	H.add_note("Role", "You are a <b>[title]</b>, a submarine Medic. Maintain the health of the crew.")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_HIGH)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_HIGH)

		/datum/job/russian/crew/Sgunner
	title = "Gunner"
	rank_abbreviation = "Pvt."
	is_subcrash = TRUE
	spawn_location = "JoinLateCGUN"
	additional_languages = list("English" = 75)

	min_positions = 10
	max_positions = 40

/datum/job/russian/captain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/combat, slot_w_uniform)

	//misc
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)

	var/obj/item/clothing/accessory/armor/coldwar/plates/b3/armour2 = new /obj/item/clothing/accessory/armor/coldwar/plates/b3(null)
	uniform.attackby(armour2, H)
	var/obj/item/ammo_magazine/ak74/mag = new /obj/item/ammo_magazine/ak74(null)
	uniform.attackby(mag, H)
	var/obj/item/ammo_magazine/ak74/mag2 = new /obj/item/ammo_magazine/ak74(null)
	uniform.attackby(mag2, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74/aks74/aks74u(H), slot_shoulder)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/swat(H), slot_head)

				H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)

				H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/advsmall(H), slot_belt)



H.civilization = "Crew"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a gunner of the submarine, you have been equipped with a close combat weapon and some other stuff, listen to the admiral and good luck!.")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM)
	H.setStat("dexterity", STAT_MEDIUM)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_HIGH)




	/datum/job/russian/crew/crewman
	title = "Sailor"
	rank_abbreviation = "S."
	is_subcrash = TRUE
	spawn_location = "JoinLateCCREW"
	can_be_female = TRUE
	additional_languages = list("English" = 75)

	min_positions = 10
	max_positions = 100

/datum/job/russian/captain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/combat, slot_w_uniform)
	//////misc
		H.equip_to_slot_or_del(new obj/item/weapon/material/sword/smallsword/iron(H), slot_belt)
				H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	give_random_name(H)
		H.civilization = "Crew"
	H.add_note("Role", "You are a <b>[title]</b>, a submarine sailor. Maintain the submarine and defend it.")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_HIGH)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_HIGH)


		/datum/job/russian/crew/Wcrewman
	title = "Equipped Sailor"
	rank_abbreviation = "S."
	is_subcrash = TRUE
	spawn_location = "JoinLateCCREW"
	can_be_female = TRUE
	additional_languages = list("English" = 75)

	min_positions = 10
	max_positions = 50

/datum/job/russian/captain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/combat, slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/fur/klyaksa(H), slot_wear_suit)
	//misc
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)

					H.equip_to_slot_or_del(new /obj/item/weapon/storage/toolbox/mechanical(H), slot_l_hand)
					H.equip_to_slot_or_del(new /obj/item/weapon/material/hatchet/steel(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/fire_extinguisher(H), slot_belt)

H.civilization = "Crew"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a well equipped submarine sailor. Maintain the submarine and defend it.")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_HIGH)
	H.setStat("rifle", STAT_MEDIUM)
	H.setStat("dexterity", STAT_MEDIUM)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_HIGH)



	/datum/job/russian/crew/Screw
	title = "Stuck sailor"
	rank_abbreviation = "S."
	is_subcrash = TRUE
	spawn_location = "JoinLateCSUR"
	can_be_female = TRUE
	additional_languages = list("English" = 75)

	min_positions = 2
	max_positions = 2

/datum/job/russian/captain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/combat, slot_w_uniform)
//misc
				H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	give_random_name(H)
		H.civilization = "Crew"
	H.add_note("Role", "You are a <b>[title]</b>, you are stuck in the front of the submarine, which is partially flooded and broken, gear up and break out.")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_HIGH)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_HIGH)




	/////////////////////////////////////////non crew aka bandits/////////////////////////////////////////

/datum/job/american/raid
	faction = "Raid"
	additional_languages = list("English" = 25, "Russian" = 15, "Arabic" = 5)

	/datum/job/american/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_american_name(H.gender)
	H.real_name = H.name


		/datum/job/american/raid/raiderL
	title = "Raider leader"
	rank_abbreviation = "Led."
	is_subcrash = TRUE
	spawn_location = "JoinLateRC"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	additional_languages = list("Russian" = 45)

	min_positions = 1
	max_positions = 5


//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/insurgent_leader(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/kozhanka/white(H), slot_wear_suit)
	//////misc
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)
					H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt/white(H), slot_head)
                    H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/rucksack(H), slot_back)

                    	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/utility(H), slot_belt)
//weapons
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/type100(H), slot_l_store)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/type100(H), slot_r_store)
	H.equip_to_slot_or_del(new 	/obj/item/weapon/gun/projectile/submachinegun/type100(H), slot_shoulder)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/pasgt/khaki/pasgt_armor = new /obj/item/clothing/accessory/armor/coldwar/pasgt/khaki(null)
	uniform.attackby(pasgt_armor, H)

	H.civilization = "Raid"

	H.add_note("Role", "You are a <b>[title]</b> one of the leaders, lead your raider group to victory over the submarine.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_HIGH)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_HIGH)




	/datum/job/american/raid/raiderMED
	title = "Raider medic"
	rank_abbreviation = "RMpl."
	is_subcrash = TRUE
	spawn_location = "JoinLateRC"
	can_be_female = TRUE
	additional_languages = list("Russian" = 25)

	min_positions = 5
	max_positions = 9


//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate4(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/fur/white(H), slot_wear_suit)
	//////misc
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)

                    	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/advsmall(H), slot_belt)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/custom/armband/white = new /obj/item/clothing/accessory/custom/armband(null)
	uniform.attackby(white, H)
//slots
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/pill_bottle/pervitin(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/pill_bottle/antitox(H), slot_r_store)´
	//katana
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/katana/fullh = new /obj/item/clothing/accessory/storage/sheath/katana/full(null)
	uniform.attackby(fullh, H)
	fullh.attackby(new/obj/item/weapon/material/sword/katana, H)

	give_random_name(H)
	H.civilization = "Raid"

	H.add_note("Role", "You are a <b>[title]</b> one of the medics, heal your comrades while they attempt to capture the submarine!.")
	H.setStat("strength", STAT_MEDIUM)
	H.setStat("crafting", STAT_MEDIUM)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_HIGH)


	/datum/job/american/raid/raider
	title = "Raider"
	rank_abbreviation = "R."
	is_subcrash = TRUE
	spawn_location = "JoinLateR"
	can_be_female = TRUE
	additional_languages = list("Russian" = 10)

	min_positions = 100
	max_positions = 220


//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate5(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/fur/white(H), slot_wear_suit)
	//misc
		H.equip_to_slot_or_del(new obj/item/weapon/material/sword/smallsword/iron(H), slot_l_hand)

	give_random_name(H)
	H.civilization = "Raid"

	H.add_note("Role", "You are a <b>[title]</b> a raider, follow your leader and capture the submarine!.")
	H.setStat("strength", STAT_MEDIUM)
	H.setStat("crafting", STAT_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_HIGH)
*/