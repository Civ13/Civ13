////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////BEAR CLAN///////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////
/datum/job/roman
	faction = "Human"
	is_ancient = TRUE
/datum/job/roman/give_random_name(var/mob/living/human/H)
	if (title != "King")
		H.name = H.species.get_random_roman_name()
		H.real_name = H.name
	else
		H.name = H.species.get_random_ancient_name()
		H.real_name = H.name

/datum/job/roman/bear_king	//Roman - Centurion
	title = "Bear King"
	en_meaning = ""
	rank_abbreviation = "King"

	spawn_location = "JoinLateRO"

	is_clash = TRUE
	is_commander = TRUE
	is_officer = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/roman/bear_king/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/fur/brown(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/red2(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/red(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/iron(H), slot_l_hand)
		//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/viking(H), slot_head)
		//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/armingsword/iron(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/horn(H), slot_r_store)
	H.add_note("Role", "You are the <b>[title]</b>, the leader of the <b>Bear clan</b>, a feared clan. Organize your <b>Clan</b> and lead your fighters to victory!</b>.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_HIGH)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.f_style = "lumberjack"
	give_random_name(H)

	return TRUE



/datum/job/roman/bear_clan_jarl	//Roman - Decurion
	title = "Bear Clan Jarl"
	en_meaning = "lieutinant"
	rank_abbreviation = "Jarl"

	spawn_location = "JoinLateRO"

	is_clash = TRUE
	is_officer = TRUE
	whitelisted = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/roman/bear_clan_jarl/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/fur/brown(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/red(H), slot_w_uniform)
	//pelt randomization
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/bearpelt(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/wolfpelt(H), slot_head)
		//weapons
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/ancient/chainmail(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/hatchet/battleaxe(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/iron(H), slot_back)
	H.add_note("Role", "You are the <b>[title]</b>, the kings second in command. Lead your <b>Clan</b> to battle, following the orders of the <b>King</b>!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.f_style = "Lumberjack"
	give_random_name(H)
	return TRUE

/datum/job/roman/beserker
	title = "Beserker"
	en_meaning = "Expert fighter"
	rank_abbreviation = "Beserker"

	spawn_location = "JoinLateRO"

	is_clash = TRUE

	min_positions = 5
	max_positions = 8

/datum/job/roman/beserker/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/fur/brown(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/red(H), slot_w_uniform)

	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/ancient/chainmail(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/viking/varangian(H), slot_head)
		//weapons
	if(prob(60))
		H.equip_to_slot_or_del(new /obj/item/weapon/material/hatchet/battleaxe(H), slot_belt)
	else if (prob(20))
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/armingsword/iron(H), slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/longsword/iron(H), slot_belt)

	H.equip_to_slot_or_del(new /obj/item/weapon/shield/iron(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/horn(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/snacks/grown/mushroompsy(H), slot_l_store)
	H.add_note("Role", "You are a <b>[title]</b>, A crazed fighter that wants nothing more but to bash the skulls of your foes in! Lead your fellow clan members to battle and destroy your foes!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_HIGH)
	H.f_style = "Lumberjack"
	give_random_name(H)
	return TRUE


/datum/job/roman/bear_clan_member
	title =  "Bear Clan Member"
	en_meaning = "Standard fighter"
	rank_abbreviation = ""

	spawn_location = "JoinLateRO"

	is_clash = TRUE
	can_be_female = TRUE

	min_positions = 20
	max_positions = 100

/datum/job/roman/bear_clan_member/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/fur/brown(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/red(H), slot_w_uniform)
		//suits
	if(prob(60))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/fur/brown(H), slot_wear_suit)
	else if (prob(20))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/ancient/chainmail(H), slot_wear_suit)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/viking(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/fur/grey(H), slot_wear_suit)
	//weapons
	if(prob(60))
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/longsword(H), slot_back)
	else if (prob(20))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/bow/shortbow(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/quiver/medieval(H), slot_back)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/armingsword/iron(H), slot_r_hand)
		H.equip_to_slot_or_del(new /obj/item/weapon/shield/iron(H), slot_back)

	H.add_note("Role", "You are a <b>[title]</b>, a member of the bear clan. Help your other clanmembers win.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_MEDIUM_HIGH)
	H.setStat("medical", STAT_LOW)
	give_random_name(H)

	return TRUE



/datum/job/roman/herbalist
	title = "Herbalist"
	en_meaning = "Medic"
	rank_abbreviation = "Herbalist"

	spawn_location = "JoinLateRO"

	is_clash = TRUE
	can_be_female = TRUE

	min_positions = 4
	max_positions = 5
/datum/job/roman/herbalist/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/fur/brown(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/red(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/ancient/chainmail(H), slot_wear_suit)

	//pelt randomization
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/bone(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/goatpelt(H), slot_head)
	//pockets
	H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/bint(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/stack/medical/advanced/herbs(H), slot_l_store)
	//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/smallsword/iron(H), slot_belt)

	H.add_note("Role", "You are a <b>[title]</b>, an important part of you clan. Your job is to keep your clanmembers alive at all costs!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_HIGH)
	give_random_name(H)
	return TRUE
////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////RAVEN CLAN///////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////
/datum/job/greek
	faction = "Human"
	is_ancient = TRUE

/datum/job/greek/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_greek_name()
	H.real_name = H.name


/datum/job/greek/Raven_clan_king	//Greek Strategus
	title = "Raven King"
	en_meaning = ""
	rank_abbreviation = "King"

	spawn_location = "JoinLateGRK"

	is_clash = TRUE
	is_commander = TRUE
	is_officer = TRUE
	whitelisted = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/greek/raven_clan_king/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/fur/black(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/chainmail(H), slot_wear_suit)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/armingsword/iron(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/iron(H), slot_back)
	H.add_note("Role", "You are the <b>[title]</b>, the leader of the <b>Raven clan</b>, a well respected clan. Organize your <b>Clan</b> and lead your fighters to victory!</b>.")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_LOW)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_HIGH)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.f_style = "Lumberjack"
	give_random_name(H)
	return TRUE

/datum/job/greek/raven_clan_jarl	//Greek - Phalanx
	title = "Raven Clan Jarl"
	en_meaning = "lieutinant"
	rank_abbreviation = "Jarl"

	spawn_location = "JoinLateGR"

	is_clash = TRUE
	is_officer = TRUE
	whitelisted = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/greek/raven_clan_jarl/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/fur/black(H), slot_shoes)
//clothes
	var/randcloth = pick(1,2,3)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/celtic_blue(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/varangian(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/viking(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/longsword/iron(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/hatchet(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/iron(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/horn(H), slot_r_store)
	H.add_note("Role", "You are the <b>[title]</b>, the kings second in command. Lead your <b>Clan</b> to battle, following the orders of the <b>King</b>!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_HIGH)
	H.f_style = "Lumberjack"
	give_random_name(H)
	return TRUE

/datum/job/greek/huntsman
	title = "Huntsman"
	en_meaning = "Skilled marksman"
	rank_abbreviation = ""

	spawn_location = "JoinLateGR"

	is_clash = TRUE
	can_be_female = TRUE

	min_positions = 5
	max_positions = 8

/datum/job/greek/huntsman/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/fur/black(H), slot_shoes)
//clothes
	var/randcloth = pick(1,2,3)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/celtic_blue(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/fancy_fur_coat(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/furcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/bow/shortbow(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/quiver/medieval(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/spear/iron(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/horn(H), slot_r_store)
	H.add_note("Role", "You are a <b>[title]</b>, a very skilled archer. help your fellow clanmembers win!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_HIGH)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_HIGH)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE


/datum/job/greek/raven_clan_member
	title = "Raven Clan Member"
	en_meaning = "Standard fighter"
	rank_abbreviation = ""

	spawn_location = "JoinLateGR"

	is_clash = TRUE
	can_be_female = TRUE

	min_positions = 8
	max_positions = 100
/datum/job/greek/raven_clan_member/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/fur/black(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue(H), slot_w_uniform)
//suits
	if(prob(60))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/fur/black(H), slot_wear_suit)
	else if (prob(20))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/ancient/chainmail(H), slot_wear_suit)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/viking(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/fur/white(H), slot_wear_suit)
//weapons
	if(prob(60))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/bow/longbow(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/quiver/medieval(H), slot_back)
	else if (prob(20))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/bow/shortbow(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/quiver/medieval(H), slot_back)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/armingsword/iron(H), slot_r_hand)
		H.equip_to_slot_or_del(new /obj/item/weapon/shield/iron(H), slot_back)

	H.add_note("Role", "You are a <b>[title]</b>, a member of the raven clan. Help your other clanmembers win.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_MEDIUM_HIGH)
	H.setStat("medical", STAT_LOW)
	give_random_name(H)
	return TRUE

/datum/job/greek/mystic
	title = "Mystic"
	en_meaning = "Medic"
	rank_abbreviation = "Mystic"

	spawn_location = "JoinLateGR"

	is_clash = TRUE
	can_be_female = TRUE

	min_positions = 3
	max_positions = 4
/datum/job/greek/mystic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/fur/black(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue(H), slot_w_uniform)
//face
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/raven(H), slot_wear_mask)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/spear/iron(H), slot_r_hand)
//pockets
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/snacks/grown/mushroompsy(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/stack/medical/advanced/herbs(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, a mystical warrior. Your task is to heal your fellow clan members.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_HIGH)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_HIGH)
	give_random_name(H)
	return TRUE