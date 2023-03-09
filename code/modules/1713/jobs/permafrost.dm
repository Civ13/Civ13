
/datum/job/russian/perma/banditL
	title = "Wasteland Bandits Leader"
	rank_abbreviation = "L."

	spawn_location = "JoinLateCiv"

	is_yeltsin = FALSE
	is_grozny = FALSE
	is_squad_leader = TRUE
	is_permfr = TRUE

	whitelisted = TRUE
	uses_squads = TRUE

	can_get_coordinates = TRUE

	min_positions = 5
	max_positions = 10

/datum/job/russian/perma/banditL/equip(var/mob/living/human/H)
	if (!H)	return FALSE

//shoes
	var/randshoes = rand(1,3)
	switch(randshoes)
		if(1)
			H.equip_to_slot_or_del(new /obj/item/clothing/shoes/japboots(H), slot_shoes)
		if(2)
			H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)
		if(3)
			H.equip_to_slot_or_del(new /obj/item/clothing/shoes/winterboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/indian3(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/glasses/tactical_goggles(H), slot_eyes)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/scrap(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/medical/full_vc(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/nomads/civiliankevlar/under/armor = new /obj/item/clothing/accessory/armor/nomads/civiliankevlar/under(null)
	uniform.attackby(armor, H)

		H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/magic/onoff/red(H), slot_l_hand)
//jacket
	if (prob(90))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/rus_winter_vsr93(H), slot_wear_suit)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/afghanka(H), slot_wear_suit)

	H.civilization = "Bandit"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, lead your Bandits into the Underground complex, murder and eat them all!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_MEDIUM)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_HIGH)
	H.setStat("medical", STAT_HIGH)
	H.setStat("machinegun", STAT_NORMAL)
	return TRUE


/datum/job/russian/perma/bandit
	title = "Wasteland Bandit"
	rank_abbreviation = "Bd."

	spawn_location = "JoinLateCiv"

	is_yeltsin = FALSE
	is_grozny = FALSE
	is_permfr = TRUE

	uses_squads = TRUE

	min_positions = 10
	max_positions = 190

/datum/job/russian/perma/bandit/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	var/randshoes = rand(1,3)
	switch(randshoes)
		if(1)
			H.equip_to_slot_or_del(new /obj/item/clothing/shoes/japboots(H), slot_shoes)
		if(2)
			H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)
		if(3)
			H.equip_to_slot_or_del(new /obj/item/clothing/shoes/winterboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/indian2(H), slot_w_uniform)

//suit
	var/randsuits = rand(1,4)
	if (randsuits == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/prehistoricfurcoat/black(H), slot_wear_suit)
	else if (randsuits == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/prehistoricfurcoat/brown(H), slot_wear_suit)
	else if (randsuits == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/prehistoricfurcoat/grey(H), slot_wear_suit)
	else if (randsuits == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/prehistoricfurcoat/white(H), slot_wear_suit)

	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)

//head
	if (prob(90))
		H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/russia(H), slot_wear_mask)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/russia(H), slot_wear_mask)
	if (prob(90))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/grey_eisenbruck(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/grey_eisenbruck(H), slot_head)

//weapon
	var/randimpw = rand(1,5)
	switch(randimpw)
		if (1)
			H.equip_to_slot_or_del(new obj/item/weapon/material/sword/spadroon/iron(H), slot_l_hand)
		if (2)
			H.equip_to_slot_or_del(new obj/item/weapon/material/sword/wakazashi(H), slot_l_hand)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/weapon/material/scythe(H), slot_l_hand)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/smallsword/iron(H), slot_l_hand)
		if (5)
		    H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/arabsword(H), slot_l_hand)

	H.civilization = "Bandit"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, Follow your leader!")
	H.setStat("strength", STAT_MEDIUM)
	H.setStat("crafting", STAT_MEDIUM)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_MEDIUM_HIGH)
	H.setStat("medical", STAT_MEDIUM)
	H.setStat("machinegun", STAT_LOW)
	return TRUE

/////////BUNKER//////////////

/datum/job/civilian/russian/perma/bunkL
	title = "Bunker Leader"
	rank_abbreviation = "Chairman"
	spawn_location = "JoinLateBunk"
	is_kremlin = FALSE
	is_yeltsin = FALSE
	is_grozny = FALSE
	is_permfrb = TRUE
	is_squad_leader = TRUE

	uses_squads = TRUE
	whitelisted = TRUE

	min_positions = 1
	max_positions = 3

/datum/job/civilian/russian/perma/bunkL/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)


//under
	H.equip_to_slot_or_del(new /obj/item/clothing/under/combat(H), slot_w_uniform)

	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/soviet_officer(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction1(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/watch/goldwatch(H), slot_gloves)
	H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/gauze(H), slot_l_store)
    H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/tt30/silenced(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/nomads/civiliankevlar/under/armor = new /obj/item/clothing/accessory/armor/nomads/civiliankevlar/under(null)
	uniform.attackby(armor, H)

	var/obj/item/clothing/accessory/armband/red = new/obj/item/clothing/accessory/armband(null)
	uniform.attackby(red, H)

	H.civilization = "Bunker"
	H.add_note("Role", "You Are One of the Bunker Leaders, the bandits are out to get you, rely on Firearms and Fortifications with your bunker crew to survive!")
	give_random_name(H)
	H.setStat("strength", STAT_MEDIUM)
	H.setStat("crafting", STAT_MEDIUM)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_MEDIUM)
	H.setStat("swords", STAT_MEDIUM)
	H.setStat("pistol", STAT_HIGH)
	H.setStat("bows", STAT_MEDIUM)
	H.setStat("medical", STAT_HIGH)
	H.setStat("machinegun", STAT_MEDIUM)
	return TRUE

/datum/job/civilian/russian/perma/bunk
	title = "Bunker Crew"
	rank_abbreviation = ""
	spawn_location = "JoinLateCiv"
	min_positions = 10
	max_positions = 35
	is_kremlin = FALSE
	is_yeltsin = FALSE
	is_grozny = FALSE
	is_permfrb = TRUE
	uses_squads = TRUE

/datum/job/civilian/russian/perma/bunk/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	var/randshoe = rand(1,5)
	if (randshoe == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)
	else if (randshoe == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/workboots(H), slot_shoes)
	else if (randshoe == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/black(H), slot_shoes)
	else if (randshoe == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	else if (randshoe == 5)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/winterboots(H), slot_shoes)

//under
	  H.equip_to_slot_or_del(new /obj/item/clothing/under/combat(H), slot_w_uniform)
//head
	var/randhead = rand(1,6)
	switch(randhead)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww/papakha(H), slot_head)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka(H), slot_head)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/flatcap3(H), slot_head)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/fedora(H), slot_head)
		if (5)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/soviet_tanker(H), slot_head)
		if (6)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/commando_bandana(H), slot_head)


//gloves
	var/randglove = rand(1,4)
	switch(randglove)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/leather(H), slot_gloves)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/gloves/fingerless(H), slot_gloves)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/gloves/watch/watch(H), slot_gloves)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/clothing/gloves/watch/specialwatch(H), slot_gloves)
//gun
	 H.equip_to_slot_or_del(new /obj/item/weapon/material/hatchet(H), slot_l_hand)

//suit
	var/randsuits = rand(1,6)
	if (randsuits == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/moderncoat(H), slot_wear_suit)
	else if (randsuits == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/kozhanka/white(H), slot_wear_suit)
	else if (randsuits == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/servicejacket(H), slot_wear_suit)
	else if (randsuits == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/russian_rcw(H), slot_wear_suit)
	else if (randsuits == 5)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/soviet(H), slot_wear_suit)
	else if (randsuits == 6)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/coveralls(H), slot_wear_suit)

	var/obj/item/clothing/accessory/armband/red = new/obj/item/clothing/accessory/armband(null)
	uniform.attackby(red, H)

	H.add_note("Role", "You are a <b>[title]</b>, Protect the Bunker!")
	H.civilization = "Bunker"
	give_random_name(H)
	H.setStat("strength", STAT_MEDIUM)
	H.setStat("crafting", STAT_MEDIUM)
	H.setStat("rifle", STAT_MEDIUM)
	H.setStat("dexterity", STAT_MEDIUM)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	return TRUE
