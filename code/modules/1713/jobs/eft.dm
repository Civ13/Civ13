
/datum/job/american/eft/usec
	title = "USEC PMC"
	rank_abbreviation = ""
	spawn_location = "JoinLatePMC"
	is_eft = TRUE
	is_outlaw = TRUE

	min_positions = 1
	max_positions = 4

/datum/job/american/eft/usec/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_lightuni_modern(H), slot_w_uniform)
//jacket

//head
	if(prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/cap/usec(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m9beretta/tan(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m9beretta(H), slot_l_store)

	give_random_name(H)
	H.add_note("Role", "You are a Private Military Contractor working for USEC. After the chaos died down command didn't respond. And now you're on your own.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)


	return TRUE

/datum/job/russian/eft/bear
	title = "BEAR PMC"
	rank_abbreviation = ""
	spawn_location = "JoinLatePMC"
	is_eft = TRUE
	is_outlaw = TRUE

	min_positions = 1
	max_positions = 4

/datum/job/russian/eft/bear/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/bear(H), slot_w_uniform)
//jacket

//head
	if(prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/cap/bear(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/mp443(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mp443(H), slot_l_store)

	give_random_name(H)
	H.add_note("Role", "You are a Private Military Contractor working for BEAR. After the chaos died down command didn't respond. And now you're on your own.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)

	return TRUE

/datum/job/russian/eft/scav
	title = "Scavenger"
	rank_abbreviation = ""
	spawn_location = "JoinLateScav"
	is_eft = TRUE
	is_outlaw = TRUE

	min_positions = 1
	max_positions = 6

/datum/job/russian/eft/scav/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/bear(H), slot_w_uniform)
//jacket

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/cap/bear(H), slot_head)
//main weapons
	if(prob(75))
		var/randarmM = rand(1,4)
		switch(randarmM)
			if(1)
				if(prob(40))
					H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak101/ak105(H), slot_shoulder)
					H.equip_to_slot_or_del(new /obj/item/ammo_magazine/ak74(H), slot_r_store)
				else
					H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74/aks74/aks74u(H), slot_shoulder)
					H.equip_to_slot_or_del(new /obj/item/ammo_magazine/ak74(H), slot_r_store)
			if(2)
				if(prob(15))
					H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/saiga12(H), slot_shoulder)
					H.equip_to_slot_or_del(new /obj/item/ammo_magazine/saiga12(H), slot_r_store)
				else
					H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/shotgun/pump/remington870(H), slot_shoulder)
					H.equip_to_slot_or_del(new /obj/item/ammo_casing/shotgun/buckshot(H), slot_r_store)
//sidearm
	if(prob(35))
		var/randarmS = rand(1,4)
		switch(randarmS)
			if(1)
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/mp443(H), slot_belt)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mp443(H), slot_l_store)
			if(2)
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/makarov(H), slot_belt)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/makarov(H), slot_l_store)
			if(3)
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/tt30(H), slot_belt)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/tt30(H), slot_l_store)
			if(4)
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m1911(H), slot_belt)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m1911(H), slot_l_store)
	else
		var/randarmS = rand(1,3)
		switch(randarmS)
			if(1)
				H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/dagger(H), slot_belt)
			if(2)
				H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/bowie(H), slot_belt)
			if(3)
				H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/shank(H), slot_belt)
	give_random_name(H)
	H.add_note("Role", "Amidst the chaos and lawlessness, scarcity of vital provisions and territories, you were one of first to lift up their head, unembarrassed by excessive moral or ethical restraints or quick to lose them under influence of conditions. This is how you were a civilians and now a Scav.")
	if(prob(10))
		H.setStat("strength", STAT_VERY_VERY_HIGH)
	else H.setStat("strength", STAT_LOW)
	H.setStat("crafting", STAT_NORMAL)
	if(prob(10))
		H.setStat("rifle", STAT_VERY_VERY_HIGH)
	else
		H.setStat("rifle", STAT_MEDIUM_LOW)
	if(prob(20))
		H.setStat("dexterity", STAT_MEDIUM_LOW)
	else
		H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_HIGH)
	H.setStat("bows", STAT_LOW)
	if(prob(20))
		H.setStat("medical", STAT_HIGH)
	else
		H.setStat("medical", STAT_MEDIUM_LOW)

	return TRUE