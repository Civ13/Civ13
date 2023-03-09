////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////BEAR CLAN///////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////
/datum/job/norwegian/bear_clan
	faction = "Human"
	is_ancient = TRUE
	default_language = "Old Norse"
	additional_languages = list()

/datum/job/norwegian/bear_clan/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_oldnorse_name()
	H.real_name = H.name

/datum/job/norwegian/bear_clan/king
	title = "Bear Clan King"
	rank_abbreviation = "King"

	spawn_location = "JoinLateRO"

	is_clash = TRUE
	is_commander = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/norwegian/bear_clan/king/equip(var/mob/living/human/H)
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
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/vikingsword/iron(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/horn(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/map_tdm/clash(H), slot_l_store)
	H.f_style = pick("Lumberjack Beard")
	H.add_note("Role", "You are the <b>[title]</b>, the leader of the <b>Bear Clan</b>, a fearsome clan. Organize your <b>Clan</b> and lead your fighters to victory!</b>.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_HIGH)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE

/datum/job/norwegian/bear_clan/jarl
	title = "Bear Clan Jarl"
	rank_abbreviation = "Jarl"

	spawn_location = "JoinLateRO"

	is_clash = TRUE
	is_officer = TRUE
	whitelisted = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/norwegian/bear_clan/jarl/equip(var/mob/living/human/H)
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
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/dagger/iron(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/horn(H), slot_l_store)
	H.add_note("Role", "You are a <b>[title]</b>, a vassal of the King. Lead your <b>Clan</b> to battle according to the orders of the <b>King</b>!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.f_style = pick("Dwarf Beard", "Biker Beard","Long Beard","Very Long Beard")
	give_random_name(H)
	return TRUE

/datum/job/norwegian/bear_clan/berserker
	title = "Berserker"
	rank_abbreviation = "Berserker"

	spawn_location = "JoinLateRO"

	is_clash = TRUE
	is_squad_leader = TRUE
	uses_squads = TRUE

	min_positions = 5
	max_positions = 8

/datum/job/norwegian/bear_clan/berserker/equip(var/mob/living/human/H)
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
		H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/dagger/iron(H), slot_r_hand)
	else if (prob(20))
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/vikingsword/iron(H), slot_belt)
		H.equip_to_slot_or_del(new /obj/item/weapon/shield/iron(H), slot_back)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/dagger/iron(H), slot_r_hand)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/claymore/iron(H), slot_belt)
		H.equip_to_slot_or_del(new /obj/item/weapon/shield/iron(H), slot_back)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/dagger/iron(H), slot_r_hand)

	H.equip_to_slot_or_del(new /obj/item/weapon/horn(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/snacks/grown/mushroompsy(H), slot_l_store)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/knife/h = new /obj/item/clothing/accessory/storage/sheath/knife(null)
	uniform.attackby(h, H)

	H.add_note("Role", "You are a <b>[title]</b>, a warrior capable of supernatural frenzy in battle. Lead your fellow clan members to battle and destroy your foes!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_HIGH)
	H.f_style = pick("Dwarf Beard","Very Long Beard")
	give_random_name(H)
	return TRUE

/datum/job/norwegian/bear_clan/warrior
	title = "Bear Clan Warrior"
	rank_abbreviation = ""

	spawn_location = "JoinLateRO"

	is_clash = TRUE
	uses_squads = TRUE
	can_be_female = FALSE

	min_positions = 20
	max_positions = 100

/datum/job/norwegian/bear_clan/warrior/equip(var/mob/living/human/H)
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
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/claymore/iron(H), slot_back)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/dagger/iron(H), slot_belt)
	else if (prob(20))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/bow/shortbow(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/quiver/medieval(H), slot_back)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/dagger/iron(H), slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/armingsword/iron(H), slot_r_hand)
		H.equip_to_slot_or_del(new /obj/item/weapon/shield/iron(H), slot_back)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/dagger/iron(H), slot_belt)

	H.add_note("Role", "You are a <b>[title]</b>, a warrior of the Bear clan. Follow your leaders and help your brothers in battle.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_MEDIUM_HIGH)
	H.setStat("medical", STAT_LOW)
	if (prob(80))
		H.f_style = pick("Dwarf Beard", "Biker Beard","Long Beard","Medium Beard","Full Beard","Long Beard")
	give_random_name(H)

	return TRUE

/datum/job/norwegian/bear_clan/healer
	title = "Laekir"
	en_meaning = "Healer"
	rank_abbreviation = "Herbalist"

	spawn_location = "JoinLateRO"

	is_clash = TRUE
	is_medic = TRUE
	can_be_female = FALSE

	min_positions = 4
	max_positions = 5

/datum/job/norwegian/bear_clan/healer/equip(var/mob/living/human/H)
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
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/dagger/iron(H), slot_r_hand)

	H.add_note("Role", "You are a <b>[title]</b>, the clan's healer. Your task is to keep your fellow clanmembers fit for battle, Valhalla awaits them as victors!")
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

/datum/job/danish/raven_clan
	faction = "Human"
	is_ancient = TRUE
	default_language = "Old Norse"
	additional_languages = list()

/datum/job/danish/raven_clan/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_oldnorse_name()
	H.real_name = H.name

/datum/job/danish/raven_clan/king
	title = "Raven King"
	en_meaning = ""
	rank_abbreviation = "King"

	spawn_location = "JoinLateGRK"

	is_clash = TRUE
	is_commander = TRUE
	whitelisted = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/danish/raven_clan/king/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/fur/black(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/varangian(H), slot_wear_suit)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/vikingsword/iron(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/iron(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/dagger/iron(H), slot_r_hand)
	H.add_note("Role", "You are the <b>[title]</b>, the leader of the <b>Raven clan</b>, a prosperous clan. Defend and lead your kingdom to victory!</b>.")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_LOW)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_HIGH)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.f_style = pick("Sailor Beard")
	give_random_name(H)
	return TRUE

/datum/job/danish/raven_clan/jarl
	title = "Raven Clan Jarl"
	rank_abbreviation = "Jarl"

	spawn_location = "JoinLateGR"

	is_clash = TRUE
	is_officer = TRUE
	whitelisted = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/danish/raven_clan/jarl/equip(var/mob/living/human/H)
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
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/claymore/iron(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/hatchet(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/iron(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/horn(H), slot_r_store)
	H.add_note("Role", "You are a <b>[title]</b>, a vassal of the King. Lead your <b>Clan</b> to battle, following the orders of your <b>King</b>!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_HIGH)
	H.f_style = pick("Dwarf Beard", "Biker Beard","Long Beard","Very Long Beard")
	give_random_name(H)
	return TRUE

/datum/job/danish/raven_clan/huntsman
	title = "Huntsman"
	rank_abbreviation = ""

	spawn_location = "JoinLateGR"

	is_clash = TRUE
	can_be_female = FALSE

	min_positions = 5
	max_positions = 8

/datum/job/danish/raven_clan/huntsman/equip(var/mob/living/human/H)
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
	H.equip_to_slot_or_del(new /obj/item/weapon/horn(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/fancy/(H), slot_r_store)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/knife/h = new /obj/item/clothing/accessory/storage/sheath/knife(null)
	uniform.attackby(h, H)

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
	if (prob(80))
		H.f_style = pick("Dwarf Beard", "Biker Beard","Long Beard","Medium Beard","Full Beard","Long Beard")

	return TRUE

/datum/job/danish/raven_clan/warrior
	title = "Raven Clan Warrior"
	rank_abbreviation = ""

	spawn_location = "JoinLateGR"

	is_clash = TRUE
	can_be_female = FALSE

	min_positions = 8
	max_positions = 100

/datum/job/danish/raven_clan/warrior/equip(var/mob/living/human/H)
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
		H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/dagger/iron(H), slot_belt)
	else if (prob(20))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/bow/shortbow(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/quiver/medieval(H), slot_back)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/dagger/iron(H), slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/armingsword/iron(H), slot_r_hand)
		H.equip_to_slot_or_del(new /obj/item/weapon/shield/iron(H), slot_back)
		H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/dagger/iron(H), slot_belt)

	H.add_note("Role", "You are a <b>[title]</b>, a warrior of the Raven clan. Help your other clanmembers defend your settlement.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_MEDIUM_HIGH)
	H.setStat("medical", STAT_LOW)
	if (prob(80))
		H.f_style = pick("Dwarf Beard", "Biker Beard","Long Beard","Medium Beard","Full Beard","Long Beard")

	give_random_name(H)
	return TRUE

/datum/job/danish/raven_clan/shaman
	title = "Seidmadr"
	en_meaning = "Shaman"
	rank_abbreviation = "Seer"

	spawn_location = "JoinLateGR"

	is_clash = TRUE
	can_be_female = FALSE
	is_medic = TRUE

	min_positions = 3
	max_positions = 4

/datum/job/danish/raven_clan/shaman/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/fur/black(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/blue(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/fur/black(H), slot_wear_suit)
//face
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/raven(H), slot_wear_mask)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/dagger/iron(H), slot_r_hand)
//pockets
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/snacks/grown/mushroompsy(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/stack/medical/advanced/herbs(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, a magico-religious initiate. Your task is to use your mystical knowledge of medicine to aid your fellow clan members.")
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
