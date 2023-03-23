/datum/job/dutch
	faction = "Human"

/datum/job/dutch/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_dutch_name(H.gender)
	H.real_name = H.name

/datum/job/dutch/captain
	title = "Kapitein"
	en_meaning = "Ship Captain"
	rank_abbreviation = "Kapitein"


	spawn_location = "JoinLateRNCap"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE



	min_positions = 1
	max_positions = 1

/datum/job/dutch/captain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/generic_officer, slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/dutch_captain(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_dutch(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
	world << "<b><big>[H.real_name] is the Captain of the Dutch Navy ship!</big></b>"
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

/datum/job/dutch/qm
	title = " Onderofficier"
	en_meaning = "2IC / Supplies Officer"
	rank_abbreviation = "Onderofficier"

	spawn_location = "JoinLateRNQM"
	is_commander = TRUE
	is_officer = TRUE
	whitelisted = TRUE



	min_positions = 1
	max_positions = 1

/datum/job/dutch/qm/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/generic_officer, slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/dutch_officer, slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_dutch(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
	world << "<b><big>[H.real_name] is the Quartermaster of the Dutch Navy ship!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the ship's supply allocation. You are also the second in command, after the <b>Capitaine</b>.")
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

/datum/job/dutch/boatswain
	title = "Kwartiermeester"
	en_meaning = "Head of Personnel Officer"
	rank_abbreviation = "Kwartiermeester"


	spawn_location = "JoinLateRNBoatswain"
	whitelisted = TRUE

	is_commander = TRUE
	is_officer = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/dutch/boatswain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/generic_officer, slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/dutch_officer, slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_dutch(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
	world << "<b><big>[H.real_name] is the Boatswain of the Dutch Navy ship!</big></b>"
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

/datum/job/dutch/midshipman
	title = "Adelborst"
	en_meaning = "Petty Officer"
	rank_abbreviation = "Adelborst"

	spawn_location = "JoinLateRNMidshipman"
	is_officer = TRUE



	min_positions = 1
	max_positions = 10

/datum/job/dutch/midshipman/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/dutch_sailor1(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/dutch_officer, slot_wear_suit)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>, a petty officer in the ship. Organize your group according to the <b>Chef d'equipage</b> orders!")
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

/datum/job/dutch/surgeon
	title = "Chirurg"
	en_meaning = "Medic"
	rank_abbreviation = "Chirurg"

	spawn_location = "JoinLateRNSurgeon"


	is_medic = TRUE

	min_positions = 1
	max_positions = 10

/datum/job/dutch/surgeon/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/dutch_sailor1(H), slot_w_uniform) // for now
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

/datum/job/dutch/carpenter
	title = "Timmerman"
	en_meaning = "Carpenter"
	rank_abbreviation = "Timmerman"

	spawn_location = "JoinLateRNCarpenter"



	min_positions = 1
	max_positions = 10

/datum/job/dutch/carpenter/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots2(H), slot_shoes)

//clothes
	var/randcloth = rand(1,3)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/dutch_sailor1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/dutch_sailor2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/dutch_sailor3(H), slot_w_uniform)

	H.equip_to_slot_or_del(new 	/obj/item/weapon/material/hatchet(H), slot_belt)
	H.equip_to_slot_or_del(new 	/obj/item/weapon/wrench(H), slot_l_store)
	H.add_note("Role", "You are a <b>[title]</b>, in charge of keeping the ship in good condition. Work with the <b>Quartier-ma�tre</b> to ensure everyting is in good conditions!")
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

/datum/job/dutch/cook
	title = "Kok"
	en_meaning = "Cook"
	rank_abbreviation = "Kok"

	spawn_location = "JoinLateRNCook"



	min_positions = 1
	max_positions = 10

/datum/job/dutch/cook/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots2(H), slot_shoes)

//clothes
	var/randcloth = rand(1,3)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/dutch_sailor1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/dutch_sailor2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/dutch_sailor3(H), slot_w_uniform)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/smallsword(H), slot_belt)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/chef(H), slot_wear_suit)

	H.add_note("Role", "You are the cook of the ship. Feed the whole crew according to the <b>Quartier-ma�tre</b> orders!")
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

/datum/job/dutch/seaman
	title = "Matroos"
	en_meaning = "Seaman"
	rank_abbreviation = ""

	spawn_location = "JoinLateRN" //for testing!



	min_positions = 6
	max_positions = 200

/datum/job/dutch/seaman/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots2(H), slot_shoes)

//clothes
	var/randcloth = rand(1,3)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/dutch_sailor1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/dutch_sailor2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/dutch_sailor3(H), slot_w_uniform)

//head
	if (prob(70))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/strawhat(H), slot_head)
	var/randweapon = rand(1,2)
	if (randweapon == 1)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/smallsword(H), slot_belt)
	else if (randweapon == 2)
		H.equip_to_slot_or_del(new 	/obj/item/weapon/material/harpoon(H), slot_belt)

	H.add_note("Role", "You are a <b>[title]</b>, a simple seaman employed by the United Provinces Nay. Follow your <b>Capitaine</b> orders!")
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/dutch/army_commander
	title = "Luitenant"
	en_meaning = "Infantry Commander"
	rank_abbreviation = "Luit."

	spawn_location = "JoinLateRNCap"
	is_officer = TRUE

	is_army = TRUE
	is_commander = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/dutch/army_commander/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/generic_officer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/dutch_officer(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_dutch(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)

	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/flintlock/pistol(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/flintlock/pistol(H), slot_r_store)

	H.add_note("Role", "You are a <b>[title]</b>, the commander or this company. Organize your <b>Sergeant</b> and lead your country to victory!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_VERY_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE
/datum/job/dutch/army_officer
	title = "Sergeant"
	en_meaning = "Infantry Squad Leader"
	rank_abbreviation = "Srg."

	spawn_location = "JoinLateRNMidshipman"
	is_officer = TRUE

	is_army = TRUE


	min_positions = 2
	max_positions = 20

/datum/job/dutch/army_officer/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/dutch_soldier(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/dutch_officer(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/bicorne_british_soldier(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)

	H.add_note("Role", "You are a <b>[title]</b>, squad leader. Organize your group of <b>Soldaat</b> according to your <b>Luitenant</b>'s orders!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE

/datum/job/dutch/field_medic
	title = "Veld Dokter"
	en_meaning = "Infantry Field Medic"
	rank_abbreviation = "V. Dk."

	spawn_location = "JoinLateRNSurgeon"

	is_medic = TRUE
	is_army = TRUE


	min_positions = 1
	max_positions = 6

/datum/job/dutch/field_medic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/generic_officer(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/powdered_wig(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/surgery(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, the most qualified medic present, and you are in charge of keeping the infantry healthy.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_VERY_HIGH)
	give_random_name(H)

	return TRUE

/datum/job/dutch/soldier
	title = "Soldaat"
	en_meaning = "Infantry Soldier"
	rank_abbreviation = ""

	spawn_location = "JoinLateRN"

	is_army = TRUE


	min_positions = 12
	max_positions = 100

/datum/job/dutch/soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/dutch_soldier(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/dutch_officer_army(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/bicorne_british_soldier(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/smallsword(H), slot_belt)

	H.add_note("Role", "You are a <b>[title]</b>, a basic infantry soldier of the United Provinces Colonial Army. Follow your Officer's orders!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE

/datum/job/dutch/chasseur
	title = "Jager"
	en_meaning = "Light Infantry"
	rank_abbreviation = "Jag."

	spawn_location = "JoinLateRN"

	is_army = TRUE

	min_positions = 4
	max_positions = 20

/datum/job/dutch/chasseur/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/soldiershoes(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/dutch_soldier(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/dutch_officer_army(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/chasseur_dutch(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/cutlass(H), slot_belt)

	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/flintlock/musketoon(H), slot_shoulder)
	H.add_note("Role", "You are a <b>[title]</b>, a light infantry soldier. You are very skilled in melee weapons and can move fast. Your job relies on hit-and-run tactics.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_VERY_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE

// Modern
/datum/job/dutch/modern_lieutenant
	title = "Eerste Luitenant"
	en_meaning = "Lieutenant"
	rank_abbreviation = "Lt."
	spawn_location = "JoinLateRNCap"

	is_operation_falcon = TRUE
	is_commander = TRUE
	is_officer = TRUE

	whitelisted = TRUE

	additional_languages = list("English" = 70)
	min_positions = 1
	max_positions = 1

/datum/job/dutch/modern_lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo(H), slot_w_uniform)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/platecarriergreen/carrier = new /obj/item/clothing/accessory/armor/coldwar/plates/platecarriergreen(null)
	uniform.attackby(carrier, H)
	var/obj/item/weapon/armorplates/plates1 = new /obj/item/weapon/armorplates(null)
	var/obj/item/weapon/armorplates/plates2 = new /obj/item/weapon/armorplates(null)
	uniform.attackby(plates1, H)
	uniform.attackby(plates2, H)
//equipment
	H.equip_to_slot_or_del(new /obj/item/clothing/head/beret_green/insig(H), slot_head)

	var/obj/item/weapon/gun/projectile/submachinegun/c7/c8/HGUN = new/obj/item/weapon/gun/projectile/submachinegun/c7/c8(H)
	H.equip_to_slot_or_del(HGUN, slot_shoulder)
	var/obj/item/weapon/attachment/under/foregrip/FP = new/obj/item/weapon/attachment/under/foregrip(src)
	FP.attached(null,HGUN,TRUE)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/laser_designator(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/dutch(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/olive/m16_smoke(H), slot_belt)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction1(H), slot_back)
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

/datum/job/dutch/modern_squadleader
	title = "Sergeant der Eerste Klasse"
	en_meaning = "Squad Leader"
	rank_abbreviation = "Sgt."
	spawn_location = "JoinLateRN"

	is_operation_falcon = TRUE
	is_squad_leader = TRUE

	uses_squads = TRUE

	additional_languages = list("English" = 70)
	min_positions = 1
	max_positions = 10

/datum/job/dutch/modern_squadleader/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo(H), slot_w_uniform)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/platecarriergreen/carrier = new /obj/item/clothing/accessory/armor/coldwar/plates/platecarriergreen(null)
	uniform.attackby(carrier, H)
	var/obj/item/weapon/armorplates/plates1 = new /obj/item/weapon/armorplates(null)
	var/obj/item/weapon/armorplates/plates2 = new /obj/item/weapon/armorplates(null)
	uniform.attackby(plates1, H)
	uniform.attackby(plates2, H)
//equipment
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt(H), slot_head)

	var/obj/item/weapon/gun/projectile/submachinegun/c7/c8/HGUN = new/obj/item/weapon/gun/projectile/submachinegun/c7/c8(H)
	H.equip_to_slot_or_del(HGUN, slot_shoulder)
	var/obj/item/weapon/attachment/under/foregrip/FP = new/obj/item/weapon/attachment/under/foregrip(src)
	FP.attached(null,HGUN,TRUE)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/dutch(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/olive/m16_smoke(H), slot_belt)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction1(H), slot_back)
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

/datum/job/dutch/modern_medic
	title = "Veld Arts"
	en_meaning = "Doctor"
	rank_abbreviation = "Ar."
	spawn_location = "JoinLateRN"

	is_operation_falcon = TRUE
	is_medic = TRUE

	uses_squads = TRUE

	additional_languages = list("English" = 15)
	min_positions = 2
	max_positions = 8

/datum/job/dutch/modern_medic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo(H), slot_w_uniform)
//armor
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt(H), slot_head)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/platecarriergreen/carrier = new /obj/item/clothing/accessory/armor/coldwar/plates/platecarriergreen(null)
	uniform.attackby(carrier, H)
	var/obj/item/weapon/armorplates/plates1 = new /obj/item/weapon/armorplates(null)
	var/obj/item/weapon/armorplates/plates2 = new /obj/item/weapon/armorplates(null)
	uniform.attackby(plates1, H)
	uniform.attackby(plates2, H)
	var/obj/item/clothing/accessory/custom/armband/medicalarm = new /obj/item/clothing/accessory/armband/redcross(null)
	uniform.attackby(medicalarm, H)
//equipment
	var/obj/item/weapon/gun/projectile/submachinegun/c7/HGUN = new/obj/item/weapon/gun/projectile/submachinegun/c7(H)
	H.equip_to_slot_or_del(HGUN, slot_shoulder)
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

/datum/job/dutch/modern_radioman
	title = "Korporaal der Eerste Klasse"
	en_meaning = "Radioman"
	rank_abbreviation = "Kpl1."
	spawn_location = "JoinLateRN"

	is_operation_falcon = TRUE
	is_radioman = TRUE

	uses_squads = TRUE

	additional_languages = list("English" = 15)
	min_positions = 1
	max_positions = 5

/datum/job/dutch/modern_radioman/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo(H), slot_w_uniform)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/platecarriergreen/carrier = new /obj/item/clothing/accessory/armor/coldwar/plates/platecarriergreen(null)
	uniform.attackby(carrier, H)
	var/obj/item/weapon/armorplates/plates1 = new /obj/item/weapon/armorplates(null)
	var/obj/item/weapon/armorplates/plates2 = new /obj/item/weapon/armorplates(null)
	uniform.attackby(plates1, H)
	uniform.attackby(plates2, H)
//equipment
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt(H), slot_head)

	var/obj/item/weapon/gun/projectile/submachinegun/c7/HGUN = new/obj/item/weapon/gun/projectile/submachinegun/c7(H)
	H.equip_to_slot_or_del(HGUN, slot_shoulder)
	var/obj/item/weapon/attachment/under/foregrip/FP = new/obj/item/weapon/attachment/under/foregrip(src)
	FP.attached(null,HGUN,TRUE)

	H.equip_to_slot_or_del(new /obj/item/weapon/grenade/smokebomb/signal/m18_red(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/olive/m16_smoke(H), slot_belt)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction1(H), slot_back)
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

/datum/job/dutch/modern_rifleman
	title = "Soldaat der Eerste Klasse"
	en_meaning = "Soldier First Class"
	rank_abbreviation = "Sld1."
	spawn_location = "JoinLateRN"

	is_operation_falcon = TRUE

	uses_squads = TRUE

	additional_languages = list("English" = 15)
	min_positions = 5
	max_positions = 100

/datum/job/dutch/modern_rifleman/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo(H), slot_w_uniform)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/platecarriergreen/carrier = new /obj/item/clothing/accessory/armor/coldwar/plates/platecarriergreen(null)
	uniform.attackby(carrier, H)
	var/obj/item/weapon/armorplates/plates1 = new /obj/item/weapon/armorplates(null)
	var/obj/item/weapon/armorplates/plates2 = new /obj/item/weapon/armorplates(null)
	uniform.attackby(plates1, H)
	uniform.attackby(plates2, H)
//equipment
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt(H), slot_head)

	var/obj/item/weapon/gun/projectile/submachinegun/c7/HGUN = new/obj/item/weapon/gun/projectile/submachinegun/c7(H)
	H.equip_to_slot_or_del(HGUN, slot_shoulder)
	var/obj/item/weapon/attachment/under/foregrip/FP = new/obj/item/weapon/attachment/under/foregrip(src)
	FP.attached(null,HGUN,TRUE)

	H.equip_to_slot_or_del(new /obj/item/weapon/foldable_shovel/trench/etool(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/olive/m16_smoke(H), slot_belt)

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

/datum/job/dutch/modern_tanker
	title = "Huzaar Cavalerie"
	en_meaning = "Tanker"
	rank_abbreviation = "Sgt."
	spawn_location = "JoinLateRN"

	is_operation_falcon = TRUE

	additional_languages = list("English" = 15)
	min_positions = 1
	max_positions = 6

/datum/job/dutch/modern_tanker/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo(H), slot_w_uniform)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/platecarriergreen/carrier = new /obj/item/clothing/accessory/armor/coldwar/plates/platecarriergreen(null)
	uniform.attackby(carrier, H)
	var/obj/item/weapon/armorplates/plates1 = new /obj/item/weapon/armorplates(null)
	var/obj/item/weapon/armorplates/plates2 = new /obj/item/weapon/armorplates(null)
	uniform.attackby(plates1, H)
	uniform.attackby(plates2, H)
//equipment
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ushelmet/crewman(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/glock17(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/dutch(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/glock17(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/compass/modern/tacmap(H), slot_belt)

	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	give_random_name(H)

	return TRUE

/datum/job/dutch/emplaced_weapon_specialist
	title = "Emplaced Wapen Specialist"
	en_meaning = "Emplaced Weapons Specialist"
	rank_abbreviation = "Kpl"
	spawn_location = "JoinLateRN"

	is_operation_falcon = TRUE

	uses_squads = TRUE

	additional_languages = list("English" = 15)
	min_positions = 1
	max_positions = 6

/datum/job/dutch/emplaced_weapon_specialist/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo(H), slot_w_uniform)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/platecarriergreen/carrier = new /obj/item/clothing/accessory/armor/coldwar/plates/platecarriergreen(null)
	uniform.attackby(carrier, H)
	var/obj/item/weapon/armorplates/plates1 = new /obj/item/weapon/armorplates(null)
	var/obj/item/weapon/armorplates/plates2 = new /obj/item/weapon/armorplates(null)
	uniform.attackby(plates1, H)
	uniform.attackby(plates2, H)
//equipment
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/gunbox/emplacement(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/foldable_shovel/trench/etool(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/glock17(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/glock17(H), slot_belt)

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

/datum/job/dutch/weapon_specialist
	title = "Wapen Specialist"
	en_meaning = "Weapons Specialist"
	rank_abbreviation = "Kpl."
	spawn_location = "JoinLateRN"

	is_operation_falcon = TRUE

	uses_squads = TRUE

	additional_languages = list("English" = 15)
	min_positions = 1
	max_positions = 10

/datum/job/dutch/weapon_specialist/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/modern(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo(H), slot_w_uniform)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/platecarriergreen/carrier = new /obj/item/clothing/accessory/armor/coldwar/plates/platecarriergreen(null)
	uniform.attackby(carrier, H)
	var/obj/item/weapon/armorplates/plates1 = new /obj/item/weapon/armorplates(null)
	var/obj/item/weapon/armorplates/plates2 = new /obj/item/weapon/armorplates(null)
	uniform.attackby(plates1, H)
	uniform.attackby(plates2, H)
//equipment
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pasgt(H), slot_head)

	var/obj/item/weapon/gun/projectile/submachinegun/c7/HGUN = new/obj/item/weapon/gun/projectile/submachinegun/c7(H)
	H.equip_to_slot_or_del(HGUN, slot_shoulder)
	var/obj/item/weapon/attachment/under/foregrip/FP = new/obj/item/weapon/attachment/under/foregrip(src)
	FP.attached(null,HGUN,TRUE)

	H.equip_to_slot_or_del(new /obj/item/gunbox/specialist(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/olive/m16_smoke(H), slot_belt)

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
