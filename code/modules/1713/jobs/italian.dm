/datum/job/italian
	faction = "Human"

/datum/job/italian/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_italian_name(H.gender)
	H.real_name = H.name

/datum/job/italian/soldier
	title = "Soldato"
	en_meaning = "Soldier"
	rank_abbreviation = ""

	spawn_location = "JoinLateIT" //for testing!

	uses_squads = TRUE

	min_positions = 1
	max_positions = 999

/datum/job/italian/soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/german(H), slot_w_uniform)

//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/gerhelm(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/german_fieldcap(H), slot_head)
//back
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/randimpw = rand(1,5)
	switch(randimpw)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/g41(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98/sniper/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98/sniper(null)
			uniform.attackby(webbing, H)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/mp40/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/mp40(null)
			uniform.attackby(webbing, H)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/g43(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/g43/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/g43(null)
			uniform.attackby(webbing, H)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98(null)
			uniform.attackby(webbing, H)
		if (5)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/g41(H), slot_shoulder)
			var/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98/webbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98(null)
			uniform.attackby(webbing, H)

	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/flashlight/militarylight/alt(H), slot_wear_id)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a simple soldier of the Royal Italian Army. Follow your <b>Sergeant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE
