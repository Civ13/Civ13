/datum/job/greek
	faction = "Human"
	is_ancient = TRUE

/datum/job/greek/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_greek_name()
	H.real_name = H.name


/datum/job/greek/captain	//Greek Strategus
	title = "Lochagos"
	en_meaning = "Greek Commander"
	rank_abbreviation = "Lo."

	spawn_location = "JoinLateGR"

	is_commander = TRUE

	is_officer = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/greek/captain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/roman(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/greek_commander(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/ancient/scaled(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/greek_commander(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/xiphos/bronze(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/aspis(H), slot_back)
	H.add_note("Role", "You are a <b>[title]</b>, a commander in charge of a <b>Lochos</b>, a group of Hoplites in a Phalanx. Give orders to your <b>Dimoerites</b> and lead your troops to victory!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)
	return TRUE

/datum/job/greek/squad_leader	//Greek - Phalanx
	title = "Dimoerites"
	en_meaning = "Greek Squad Leader"
	rank_abbreviation = "Di."

	spawn_location = "JoinLateGR"

	is_officer = TRUE

	min_positions = 2
	max_positions = 10

/datum/job/greek/squad_leader/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/roman(H), slot_shoes)
//clothes
	var/randcloth = pick(1,2,3)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/greek1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/greek2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/greek3(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/ancient/scaled(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/greek_sl(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/xiphos/bronze(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/spear/dory/bronze(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/aspis(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/horn(H), slot_r_store)
	H.add_note("Role", "You are a <b>[title]</b>, a squad leader in charge of a <b>Stichos</b>, a squad of Hoplites in a Phalanx. Receive orders from the <b>Lochagos</b> and lead your squad to victory!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)
	return TRUE

/datum/job/greek/soldier
	title = "Hoplites"
	en_meaning = "Greek Spear Infantry"
	rank_abbreviation = ""

	spawn_location = "JoinLateGR"

	min_positions = 12
	max_positions = 200

/datum/job/greek/soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/roman(H), slot_shoes)
//clothes
	var/randcloth = pick(1,2,3)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/greek1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/greek2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/greek3(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/ancient/scaled(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/greek(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/xiphos/bronze(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/aspis(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/spear/sarissa/bronze(H), slot_r_hand)
	H.add_note("Role", "You are a <b>[title]</b>, a soldier from the city-state of Athens. You have your <b>Sarissa</b> spear, your round <b>Aspis</b> shield and your <b>Xiphos</b> sword.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE


/datum/job/greek/toxotai
	title = "Toxotai"
	en_meaning = "Greek Light Archer"
	rank_abbreviation = ""

	spawn_location = "JoinLateGR"



	min_positions = 8
	max_positions = 100
/datum/job/greek/toxotai/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/roman(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/toxotai(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/ancient/linen(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/toxotai(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/xiphos/bronze(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/bow/shortbow(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/quiver/full(H), slot_back)
	H.add_note("Role", "You are a <b>[title]</b>, a skirmisher. You have your <b>Xiphos</b> sword and your <b>Bow</b>.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_HIGH)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)
	return TRUE

/datum/job/greek/squad_leader_ww2
	title = "Dekaneas"
	en_meaning = "Squad Leader"
	rank_abbreviation = "Di."

	spawn_location = "JoinLateGR"
	is_squad_leader = TRUE

	min_positions = 2
	max_positions = 12

/datum/job/greek/squad_leader_ww2/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/greek(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/thick/swat/officer(H), slot_gloves)
//head

//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40/modello38(H), slot_shoulder)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/ww1/italian/ww2/modello38/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/italian/ww2/modello38(null)
	uniform.attackby(webbing, H)

	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)

	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a Sergeant leading a squad. Organize your group according to the <b>Tenente's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/greek/soldier_ww2
	title = "Stratiotis"
	en_meaning = "Soldier"
	rank_abbreviation = ""

	spawn_location = "JoinLateGR"

	uses_squads = TRUE

	min_positions = 1
	max_positions = 999

/datum/job/greek/soldier_ww2/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/greek(H), slot_w_uniform)

//head
	if (prob(70))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/m1934(H), slot_head)
	else if (prob(80))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww/adrian/greek(H), slot_head)
//back
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/randimpw = rand(1,3)
	switch(randimpw)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/lebel(H), slot_shoulder)
			if (prob(50))
				var/obj/item/clothing/accessory/storage/webbing/ww1/greek/ww2/c8x50/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/greek/ww2/c8x50(null)
				uniform.attackby(webbing, H)
			else
				var/obj/item/clothing/accessory/storage/webbing/ww1/greek/ww2/c8x50/assault/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/greek/ww2/c8x50/assault(null)
				uniform.attackby(webbing, H)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/lebel(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/greek/ww2/c8x50/smoke/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/greek/ww2/c8x50/smoke(null)
			uniform.attackby(webbing, H)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40/modello38(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/italian/ww2/modello38/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/italian/ww2/modello38(null)
			uniform.attackby(webbing, H)

	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a simple soldier of the Hellenic Army. Follow your <b>Dekaneas'</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE