/datum/job/polish
	default_language = "Polish"
	faction = "Human"

/datum/job/polish/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_polish_name(H.gender)
	H.real_name = H.name

//////////////////////////////////////////WARSAWUPRISING///////////////////////////////////////////////////
/datum/job/polish/warsaw/lead
	title = "Dowódca Armii Krajowej"
	en_meaning = "Polish Home Army Commander"
	rank_abbreviation = "Maj."

	can_be_female = TRUE
	is_warpol = TRUE
	whitelisted = TRUE
	is_commander = TRUE
	additional_languages = list("English" = 50, "German" = 75, "Russian" = 50, "Ukrainian" = 50)
	spawn_location = "JoinLatePol"
	min_positions = 1
	max_positions = 2

/datum/job/polish/warsaw/lead/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/combat(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww1/trenchsuit/poland(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/adrianm26(H), slot_head)
//gloves
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction2(H), slot_back)
//id
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_wear_id)
//coat
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/japcoat2/trench(H), slot_wear_suit)
//weapon
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/randimpw = rand(1,3)
	switch(randimpw)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/mp40/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/mp40(null)
			uniform.attackby(webbing, H)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/g41(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98(null)
			uniform.attackby(webbing, H)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/stg(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/stg/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/stg(null)
			uniform.attackby(webbing, H)

	var/obj/item/clothing/accessory/armband/poland/white = new /obj/item/clothing/accessory/armband/poland(null)
	uniform.attackby(white, H)
	H.add_note("Role", "You are a <b>[title]</b>, As a Commander You are in charge of the uprising, command your comrades and lead them to victory!")

	give_random_name(H)
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_MEDIUM_LOW)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/polish/warsaw/sl
	title = "Dowódca Drużyny Polskiej Armii Krajowej"
	en_meaning = "Polish Home Army Squad Leader"
	rank_abbreviation = "Srj."

	is_squad_leader = TRUE
	uses_squads = TRUE
	can_be_female = TRUE
	whitelisted = TRUE
	is_warpol = TRUE
	additional_languages = list("Russian" = 20, "German" = 45, "Ukrainian" = 20)
	spawn_location = "JoinLatePol"
	min_positions = 2
	max_positions = 4

/datum/job/polish/warsaw/sl/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/combat(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww1/trenchsuit/poland(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/adrianm26(H), slot_head)
//gloves
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)
//back
	if (prob(45))
		H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction2(H), slot_back)
//weapon
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/randimpw = rand(1,3)
	switch(randimpw)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/mp40/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/mp40(null)
			uniform.attackby(webbing, H)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/g41(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98(null)
			uniform.attackby(webbing, H)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/mg34(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/mg34/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/mg34(null)
			uniform.attackby(webbing, H)

	var/obj/item/clothing/accessory/armband/poland/white = new /obj/item/clothing/accessory/armband/poland(null)
	uniform.attackby(white, H)
	H.add_note("Role", "You are a <b>[title]</b>,a Squad Leader of the polish home army, Lead and organize your Squad according to the <b>Commander's</b> orders!!")

	give_random_name(H)
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_MEDIUM_LOW)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/polish/warsaw/medic
	title = "Medyk Armii Krajowej"
	en_meaning = "Polish Home Army Medic"
	rank_abbreviation = ""

	uses_squads = TRUE
	can_be_female = TRUE
	whitelisted = TRUE
	is_warpol = TRUE
	is_medic = TRUE

	additional_languages = list("Russian" = 20, "German" = 25, "Ukrainian" = 20)
	spawn_location = "JoinLatePol"
	min_positions = 2
	max_positions = 6

/datum/job/polish/warsaw/medic/equip(var/mob/living/human/H)
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
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww1/trenchsuit/poland(H), slot_w_uniform)
//coat
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/doctor(H), slot_wear_suit)
//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/adrianm26medic(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/gerhelm_medic(H), slot_head)
//belt
	if (prob(55))
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/early(H), slot_belt)
	else if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_belt)
	else if (prob(20))
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/surgery(H), slot_belt)
//back
	if (prob(60))
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_back)
//gloves
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/redcross/wze = new /obj/item/clothing/accessory/armband/redcross(null)
	uniform.attackby(wze, H)

	H.add_note("Role", "You are a <b>[title]</b>, a well trained medic,heal your comrades and make sure everyone is in a good state, Follow your <b>Squad Leader's</b> orders!")
	give_random_name(H)
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM_LOW)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_HIGH)
	return TRUE

/datum/job/polish/warsaw/armedmilita
	title = "Uzbrojona Milicja"
	en_meaning = "Polish Home Army Armed Militia"
	rank_abbreviation = ""

	uses_squads = TRUE
	can_be_female = TRUE
	is_warpol = TRUE
	additional_languages = list("Russian" = 5, "German" = 25, "Ukrainian" = 20)
	spawn_location = "JoinLatePol"
	min_positions = 10
	max_positions = 45

/datum/job/polish/warsaw/armedmilita/equip(var/mob/living/human/H)
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
	var/randjack2 = rand(1,7)
	if (randjack2 == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ1(H), slot_w_uniform)
	else if (randjack2 == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ2(H), slot_w_uniform)
	else if (randjack2 == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
	else if (randjack2 == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/civ4(H), slot_w_uniform)
	else if (randjack2 == 5)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/oldmansuit(H), slot_w_uniform)
	else if (randjack2 == 6)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)
	else if (randjack2 == 7)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
	else if (randjack2 == 8)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial5(H), slot_w_uniform)
//head
	var/randhead2 = rand(1,7)
	switch(randhead2)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/german_fieldcap(H), slot_head)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/gerhelm(H), slot_head)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/flatcap2(H), slot_head)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/flatcap3(H), slot_head)
		if (5)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/flatcap1(H), slot_head)
		if (6)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka/nomads(H), slot_head)
		if (7)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka/nomads/down(H), slot_head)
//gloves
	if (prob(25))
		H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)
//belt
	if (prob(25))
		H.equip_to_slot_or_del(new /obj/item/weapon/grenade/antitank/stg24_bundle(H), slot_belt)
	else if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/weapon/grenade/modern/custom(H), slot_belt)
	else if (prob(20))
		H.equip_to_slot_or_del(new /obj/item/weapon/grenade/ww2/stg1924(H), slot_belt)
//weapon
	var/randarmw = rand(1,3)
	switch(randarmw)
		if (1)
			if (prob(55))
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mp40(H), slot_r_hand)
			else
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40/blyskawica(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mp40(H), slot_r_hand)

		if (2)
			if (prob(40))
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98/karabiner98k(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/gewehr98(H), slot_r_hand)
			else
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/gewehr98(H), slot_r_hand)
		if (3)
			if (prob(75))
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/mg34(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mg34(H), slot_r_hand)
			else
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/mg34(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mg34belt(H), slot_r_hand)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/poland/white = new /obj/item/clothing/accessory/armband/poland(null)
	uniform.attackby(white, H)
	if (prob(55))
		var/obj/item/clothing/accessory/storage/webbing/ww1/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1(null)
		uniform.attackby(webbing, H)
	H.add_note("Role", "You are a <b>[title]</b>, A simple Milita of the polish home army, Follow your <b>Squad Leader's</b> orders!!")

	give_random_name(H)
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM_LOW)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/polish/warsaw/unarmedmilita
	title = "Nieuzbrojona Milicja"
	en_meaning = "Civilian Unarmed Milita"
	rank_abbreviation = ""

	uses_squads = TRUE
	is_warpol = TRUE
	can_be_female = TRUE
	additional_languages = list("Russian" = 15, "German" = 15, "Ukrainian" = 10)
	spawn_location = "JoinLatePol"
	min_positions = 10
	max_positions = 90

/datum/job/polish/warsaw/unarmedmilita/equip(var/mob/living/human/H)
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
	var/randjack2 = rand(1,7)
	if (randjack2 == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ1(H), slot_w_uniform)
	else if (randjack2 == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ2(H), slot_w_uniform)
	else if (randjack2 == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
	else if (randjack2 == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/civ4(H), slot_w_uniform)
	else if (randjack2 == 5)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/oldmansuit(H), slot_w_uniform)
	else if (randjack2 == 6)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)
	else if (randjack2 == 7)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
	else if (randjack2 == 8)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial5(H), slot_w_uniform)
//head
	var/randhead2 = rand(1,7)
	switch(randhead2)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/fedora(H), slot_head)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_sailorberet(H), slot_head)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/flatcap2(H), slot_head)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/flatcap3(H), slot_head)
		if (5)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/flatcap1(H), slot_head)
		if (6)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka/nomads(H), slot_head)
		if (7)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka/nomads/down(H), slot_head)
//gloves
	if (prob(15))
		H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/combat(H), slot_gloves)
//weapon
	if (prob(15))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/waltherp38(H), slot_l_hand)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/walther(H), slot_r_hand)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/poland/white = new /obj/item/clothing/accessory/armband/poland(null)
	uniform.attackby(white, H)

	H.add_note("Role", "You are a <b>[title]</b>, you are a inexperienced pole who decided to join the uprising,use teamwork and ambushes in order to destroy the fascists! Follow your <b>Squad Leader's</b> orders!")
	give_random_name(H)
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	return TRUE

/datum/job/polish/warsaw/greyrank
	title = "Szare Szeregi"
	en_meaning = "Grey Rank"
	rank_abbreviation = ""

	uses_squads = TRUE
	can_be_female = TRUE
	is_warpol = TRUE
	can_be_minor = TRUE
	additional_languages = list("Russian" = 15, "German" = 15, "Ukrainian" = 15)
	spawn_location = "JoinLatePol"
	min_positions = 10
	max_positions = 20

/datum/job/polish/warsaw/greyrank/equip(var/mob/living/human/H)
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
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial4(H), slot_w_uniform)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial2(H), slot_w_uniform)
//weapon
	if (prob(20))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/waltherp38(H), slot_l_hand)
		H.equip_to_slot_or_del(new /obj/item/ammo_magazine/walther(H), slot_r_hand)
	else if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet(H), slot_l_hand)
//belt
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt(H), slot_belt)
	else if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/early(H), slot_belt)
//backpack
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/satchel(H), slot_back)
	else if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/civbag(H), slot_back)
	else if (prob(20))
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/combat(H), slot_back)
//armband
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/poland/white = new /obj/item/clothing/accessory/armband/poland(null)
	uniform.attackby(white, H)
	var/obj/item/clothing/accessory/armband/grey_scarf/carf = new /obj/item/clothing/accessory/armband/grey_scarf(null)
	uniform.attackby(carf, H)

	H.add_note("Role", "You are a <b>[title]</b>, a polish teenager scout. you volunteered to fight for poland, Follow your <b>Squad Leader's</b> orders!")
	H.add_note("Age", "Due to your young age you are overall less skilled than the regular soldier. Instead of directly fighting, you should assist with static weaponry, help out with logistics and distract enemies.")
	give_random_name(H)
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_LOW)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_LOW)
	return TRUE

/////////////////////////////////////////////Red army warsaw reinforcements////////////////////////////////////

/datum/job/polish/warsaw/redarmypolsl
	title = "Polski Sierżant Armii Czerwonej"
	en_meaning = "Polish Red Army Sergeant"
	rank_abbreviation = "Srj."

	spawn_location = "JoinLatePol"
	uses_squads = TRUE
	whitelisted = TRUE
	is_warpol = TRUE
	is_squad_leader = TRUE

	can_be_female = TRUE
	additional_languages = list("Ukrainian" = 10, "German" = 15, "Russian" = 100)

	min_positions = 1
	max_positions = 2

/datum/job/polish/warsaw/redarmypolsl/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet_officer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/smallpouches/rusoff(H), slot_belt)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_officercap(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ppsh(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/faction2(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/grenade/ww2/rgd33(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c762x25_ppsh(H), slot_r_store)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
//armband webbing
	var/obj/item/clothing/under/uniform = H.w_uniform

	var/obj/item/clothing/accessory/armband/poland/white = new /obj/item/clothing/accessory/armband/poland(null)
	uniform.attackby(white, H)

	var/obj/item/clothing/accessory/storage/webbing/ww1/ww2/stormgroup/Scout/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/ww2/stormgroup/Scout(null)
	uniform.attackby(webbing, H)
	give_random_name(H)

	H.add_note("Role", "You are a <b>[title]</b>, you were sent here to help the polish, coordinate with them and defeat the germans. command your squad!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)

	return TRUE

/datum/job/polish/warsaw/redarmypol
	title = "Polski Żołnierz Armii Czerwonej"
	en_meaning = "Polish Red Army Soldier"
	rank_abbreviation = ""

	spawn_location = "JoinLatePol"
	uses_squads = TRUE
	whitelisted = TRUE
	is_warpol = TRUE
	can_be_female = TRUE
	additional_languages = list("Ukrainian" = 5, "German" = 15, "Russian" = 100)

	min_positions = 10
	max_positions = 10

/datum/job/polish/warsaw/redarmypol/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(20))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots/soviet(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/soviet(H), slot_w_uniform)
//head
	var/randimh = rand(1,4)
	switch(randimh)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_pilotka(H), slot_head)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka(H), slot_head)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/sov_ushanka/down(H), slot_head)
		if (4)
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
//armband
	var/obj/item/clothing/accessory/armband/poland/white = new /obj/item/clothing/accessory/armband/poland(null)
	uniform.attackby(white, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a simple solider from the people's army of poland,you were sent here to assist, Follow your <b>Sergeant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM_LOW)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_LOW)
	return TRUE