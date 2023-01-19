////////////////////////////////////////////PIRATES///////////////////////////////////////////////////////
/datum/job/pirates
	faction = "Human"

/datum/job/pirates/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_english_name(H.gender)
	H.real_name = H.name

/datum/job/pirates/captain
	title = "Pirate Captain"
	en_meaning = "Ship Captain"
	rank_abbreviation = "Captain"

	is_1713 = TRUE
	spawn_location = "JoinLatePirateCap"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	can_be_female = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/pirates/captain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate3(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/piratejacket5(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/piratehat(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
	world << "<b><big>[H.real_name] is the Captain of the Pirate ship!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, the highest ranking officer present. Your job is to command the ship.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/pirates/qm
	title = "Pirate Quartermaster"
	en_meaning = "2IC / Supplies Officer"
	rank_abbreviation = "Quartermaster"
	is_1713 = TRUE
	spawn_location = "JoinLatePirateQM"
	is_commander = TRUE
	is_officer = TRUE
	whitelisted = TRUE
	can_be_female = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/pirates/qm/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate3(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/piratejacket2(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/piratehat(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
	world << "<b><big>[H.real_name] is the Quartermaster of the Pirate ship!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the ship's supply allocation. You are also the second in command, after the <b>Captain</b>.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/pirates/boatswain
	title = "Pirate Boatswain"
	en_meaning = "Head of Personnel Officer"
	rank_abbreviation = "Boatswain"
	is_1713 = TRUE

	spawn_location = "JoinLatePirateBoatswain"
	whitelisted = TRUE
	can_be_female = TRUE
	is_commander = TRUE
	is_officer = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/pirates/boatswain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate3(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/piratejacket1(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/piratehat(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
	world << "<b><big>[H.real_name] is the Boatswain of the Pirate ship!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the crew and their job allocation. The whole ship relies on you!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)

	H.make_title_changer()
	return TRUE

/datum/job/pirates/midshipman
	title = "Pirate Mate"
	en_meaning = "Petty Officer"
	rank_abbreviation = "Mate"
	is_1713 = TRUE
	spawn_location = "JoinLatePirateMidshipman"
	is_officer = TRUE
	can_be_female = TRUE


	min_positions = 1
	max_positions = 10

/datum/job/pirates/midshipman/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate3(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_black(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>, a petty officer in the ship. Organize your group according to the <b>Boatswain</b>'s orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/pirates/surgeon
	title = "Pirate Surgeon"
	en_meaning = "Medic"
	rank_abbreviation = "Surgeon"
	can_be_female = TRUE
	spawn_location = "JoinLatePirateSurgeon"
	is_1713 = TRUE
	is_medic = TRUE
	min_positions = 1
	max_positions = 10

/datum/job/pirates/surgeon/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate3(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/piratejacket2(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_black(H), slot_head)

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


	return TRUE

/datum/job/pirates/carpenter
	title = "Pirate Carpenter"
	en_meaning = "Carpenter"
	rank_abbreviation = "Carpenter"
	is_1713 = TRUE
	spawn_location = "JoinLatePirateCarpenter"
	can_be_female = TRUE


	min_positions = 1
	max_positions = 10

/datum/job/pirates/carpenter/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots2(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	var/randcloth = rand(1,5)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate3(H), slot_w_uniform)
	else if (randcloth == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate4(H), slot_w_uniform)
	else if (randcloth == 5)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate5(H), slot_w_uniform)
//jacket
	if (prob(75))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/piratejacket4(H), slot_wear_suit)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/piratejacket3(H), slot_wear_suit)

	H.equip_to_slot_or_del(new 	/obj/item/weapon/material/hatchet(H), slot_belt)
	H.equip_to_slot_or_del(new 	/obj/item/weapon/wrench(H), slot_l_store)
	H.add_note("Role", "You are a <b>[title]</b>, in charge of keeping the ship in good condition. Work with the <b>Quartermaster</b> to ensure everyting is in good conditions!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/pirates/cook
	title = "Pirate Cook"
	en_meaning = "Cook"
	rank_abbreviation = "Cook"
	is_1713 = TRUE
	spawn_location = "JoinLatePirateCook"
	can_be_female = TRUE


	min_positions = 1
	max_positions = 10

/datum/job/pirates/cook/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots2(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	var/randcloth = rand(1,5)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate3(H), slot_w_uniform)
	else if (randcloth == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate4(H), slot_w_uniform)
	else if (randcloth == 5)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate5(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/chef(H), slot_wear_suit)

//head
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/piratebandana1(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/smallsword(H), slot_belt)

	H.add_note("Role", "You are the cook of the ship. Feed the whole crew according to the <b>Quartermaster</b>'s orders!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)





////////////////////////////////////////////////////////////////////////////////////////////////////////////////


/datum/job/pirates/seaman
	title = "Pirate"
	en_meaning = "Seaman"
	rank_abbreviation = ""
	is_1713 = TRUE
	spawn_location = "JoinLatePirate"
	can_be_female = TRUE


	min_positions = 6
	max_positions = 200

/datum/job/pirates/seaman/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots2(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	var/randcloth = rand(1,5)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate3(H), slot_w_uniform)
	else if (randcloth == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate4(H), slot_w_uniform)
	else if (randcloth == 5)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate5(H), slot_w_uniform)
//jacket
	if (prob(35))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/piratejacket4(H), slot_wear_suit)
	else if (prob(25))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/piratejacket3(H), slot_wear_suit)

//head
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/piratebandana1(H), slot_head)
	var/randweapon = rand(1,5)
	if (randweapon == 1)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/cutlass(H), slot_belt)
	else if (randweapon == 2)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
	else if (randweapon == 3)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/smallsword(H), slot_belt)
	else if (randweapon == 4)
		H.equip_to_slot_or_del(new 	/obj/item/weapon/material/boarding_axe(H), slot_belt)
	else if (randweapon == 5)
		H.equip_to_slot_or_del(new 	/obj/item/weapon/material/harpoon(H), slot_belt)

	H.add_note("Role", "You are a <b>[title]</b>, a simple pirate. Follow your Captain's orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////BATTLE/ROYALE/STUFF//////////////////////////////////////////////////////


/datum/job/pirates/battleroyale
	title = "Marooned Pirate"
	en_meaning = "Marooned Pirate"
	rank_abbreviation = ""

	spawn_location = "JoinLateDM"

	is_deathmatch = TRUE
	can_be_female = TRUE

	min_positions = 0
	max_positions = 0
	total_positions = 0

/datum/job/pirates/battleroyale/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots2(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	var/randcloth = rand(1,5)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate3(H), slot_w_uniform)
	else if (randcloth == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate4(H), slot_w_uniform)
	else if (randcloth == 5)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate5(H), slot_w_uniform)
//jacket
	var/randjacket = rand(1,5)
	if (randjacket == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/piratejacket1(H), slot_wear_suit)
	else if (randjacket == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/piratejacket2(H), slot_wear_suit)
	else if (randjacket == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/piratejacket3(H), slot_wear_suit)
	else if (randjacket == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/piratejacket4(H), slot_wear_suit)
	else if (randjacket == 5)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/piratejacket5(H), slot_wear_suit)

//head
	var/randhead = rand(1,3)
	if (randhead == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/piratebandana1(H), slot_head)
	else if (randhead == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/piratehat(H), slot_head)
	else if (randhead == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_black(H), slot_head)

//food and bandages
	H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/bint(H), slot_l_store)

	H.add_note("Role", "You are one of the pirates abandoned at this island. Be the last one to live!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	spawn(200)
		if (H.client)
			H.client.screen += new/obj/screen/areashow("Area Location","8,14", H, null, "")
			H.client.screen += new/obj/screen/areaclosing("Area Closing","1,14", H, null, "")
			H.client.screen += new/obj/screen/playersleft("Players Left","12,14", H, null, "")
	spawn(20)
		if (H.client)
			H.name = H.client.ckey
	return TRUE

/datum/job/pirates/battleroyale/medieval
	title = "Medieval Battle Royale Fighter"
	en_meaning = ""
	rank_abbreviation = ""

	spawn_location = "JoinLateDM"

	is_deathmatch = TRUE
	can_be_female = TRUE
	min_positions = 0
	max_positions = 0
	total_positions = 0

/datum/job/pirates/battleroyale/medieval/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval/emirate(H), slot_shoes)
//clothes
	var/randcloth = rand(1,6)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/red2(H), slot_w_uniform)
	else if (randcloth == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/green(H), slot_w_uniform)
	else if (randcloth == 5)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/yellow(H), slot_w_uniform)
	else if (randcloth == 6)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/red(H), slot_w_uniform)

//bandages
	H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/bint(H), slot_l_store)

	H.add_note("Role", "Be the last one to live!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	spawn(200)
		if (H.client)
			H.client.screen += new/obj/screen/areashow("Area Location","8,14", H, null, "")
			H.client.screen += new/obj/screen/areaclosing("Area Closing","1,14", H, null, "")
			H.client.screen += new/obj/screen/playersleft("Players Left","12,14", H, null, "")
	spawn(20)
		if (H.client)
			H.name = H.client.ckey
	return TRUE


/datum/job/pirates/battleroyale/modern
	title = "Battle Royale Fighter"
	en_meaning = ""
	rank_abbreviation = ""
	can_be_female = TRUE
	spawn_location = "JoinLateDM"

	is_deathmatch = TRUE

	min_positions = 0
	max_positions = 0
	total_positions = 0

/datum/job/pirates/battleroyale/modern/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	var/randcloth = rand(1,6)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial2(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial1(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/wastelander(H), slot_w_uniform)
	else if (randcloth == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial3(H), slot_w_uniform)
	else if (randcloth == 5)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/mechanic_outfit(H), slot_w_uniform)
	else if (randcloth == 6)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial5(H), slot_w_uniform)
//suit
	var/randsuit = rand(1,7)
	if (randsuit == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/hawaiian/orange(H), slot_wear_suit)
	else if (randsuit == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/hawaiian/green(H), slot_wear_suit)
	else if (randsuit == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/blackvest(H), slot_wear_suit)
	else if (randsuit == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/bomberjacketbrown(H), slot_wear_suit)
	else if (randsuit == 5)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/biker(H), slot_wear_suit)
	else if (randsuit == 6)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/servicejacket(H), slot_wear_suit)
	else if (randsuit == 7)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/oldyjacket(H), slot_wear_suit)
//bandages
	H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/bint(H), slot_l_store)

	H.add_note("Role", "Be the last one to live!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	spawn(200)
		if (H.client)
			H.client.screen += new/obj/screen/areashow("Area Location","8,14", H, null, "")
			H.client.screen += new/obj/screen/areaclosing("Area Closing","1,14", H, null, "")
			H.client.screen += new/obj/screen/playersleft("Players Left","12,14", H, null, "")
	spawn(20)
		if (H.client)
			H.name = H.client.ckey
	return TRUE


/datum/job/pirates/battleroyale/wildwest
	title = "Wild West Battle Royale Fighter"
	en_meaning = ""
	rank_abbreviation = ""

	spawn_location = "JoinLateDM"

	is_deathmatch = TRUE
	can_be_female = TRUE
	min_positions = 0
	max_positions = 0
	total_positions = 0

/datum/job/pirates/battleroyale/wildwest/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding2(H), slot_shoes)
//clothes
	var/randcloth = rand(1,5)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial2(H), slot_w_uniform)
	else if (randcloth == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial4(H), slot_w_uniform)
	else if (randcloth == 5)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial5(H), slot_w_uniform)

//head
	var/randcloth3 = rand(1,3)
	if (randcloth3 == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/cowboyhat(H), slot_head)
	else if (randcloth3 == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/cowboyhat2(H), slot_head)
	else if (randcloth3 == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/bowler_hat(H), slot_head)

//jacket
	var/randcloth2 = rand(1,5)
	if (randcloth2 == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/leatherovercoat1(H), slot_wear_suit)
	else if (randcloth2 == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/leatherovercoat2(H), slot_wear_suit)
	else if (randcloth2 == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/bluevest(H), slot_wear_suit)
	else if (randcloth2 == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/olivevest(H), slot_wear_suit)
	else if (randcloth2 == 5)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/blackvest(H), slot_wear_suit)
	if (prob(80))
		var/randcloth4 = rand(1,2)
		if (randcloth4 == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/mask/shemagh/greykerchief(H), slot_wear_mask)
		else if (randcloth4 == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/mask/shemagh/redkerchief(H), slot_wear_mask)
	if (prob(50))
		if (prob(50))
			var/obj/item/clothing/accessory/suspenders/red_a = new /obj/item/clothing/accessory/suspenders(null)
			var/obj/item/clothing/under/uniform = H.w_uniform
			uniform.attackby(red_a, H)
		else
			var/obj/item/clothing/accessory/suspenders/dark/red_a = new /obj/item/clothing/accessory/suspenders/dark(null)
			var/obj/item/clothing/under/uniform = H.w_uniform
			uniform.attackby(red_a, H)

//bandages
	H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/bint(H), slot_l_store)

	H.add_note("Role", "Be the last one to live!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	spawn(200)
		if (H.client)
			H.client.screen += new/obj/screen/areashow("Area Location","8,14", H, null, "")
			H.client.screen += new/obj/screen/areaclosing("Area Closing","1,14", H, null, "")
			H.client.screen += new/obj/screen/playersleft("Players Left","12,14", H, null, "")
	spawn(20)
		if (H.client)
			H.name = H.client.ckey
	return TRUE

/datum/job/pirates/marooned
	title = "Marooned Pirate Crew"
	en_meaning = "Marooned Pirate"
	rank_abbreviation = ""

	spawn_location = "JoinLatePirate"

	is_marooned = TRUE
	can_be_female = TRUE

	min_positions = 60
	max_positions = 300

/datum/job/pirates/marooned/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots2(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sailorboots1(H), slot_shoes)
//clothes
	var/randcloth = rand(1,5)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate3(H), slot_w_uniform)
	else if (randcloth == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate4(H), slot_w_uniform)
	else if (randcloth == 5)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/pirate5(H), slot_w_uniform)
//jacket
	if (prob(40))
		var/randjacket = rand(1,5)
		if (randjacket == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/piratejacket1(H), slot_wear_suit)
		else if (randjacket == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/piratejacket2(H), slot_wear_suit)
		else if (randjacket == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/piratejacket3(H), slot_wear_suit)
		else if (randjacket == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/piratejacket4(H), slot_wear_suit)
		else if (randjacket == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/piratejacket5(H), slot_wear_suit)

//head
	if (prob(40))
		var/randhead = rand(1,3)
		if (randhead == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/piratebandana1(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/piratehat(H), slot_head)
		else if (randhead == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_black(H), slot_head)

	H.add_note("Role", "You are one of the pirates abandoned at this island. Be the last one to live!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)

	spawn(20)
		if (H.client)
			H.name = H.client.ckey

	return TRUE