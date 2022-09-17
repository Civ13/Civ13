////////////////////////////////////////////BANK ROBBERY///////////////////////////////////////////////////////

/datum/job/russian/robber
	title = "Bank Robber"
	rank_abbreviation = ""
	spawn_location = "JoinLateRU"

	is_heist = TRUE
	is_outlaw = TRUE
	can_be_female = FALSE

	min_positions = 1
	max_positions = 50
	additional_languages = list("English" = 100)

/datum/job/russian/robber/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.civilization = "Rednikov"
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/expensive/red(H), slot_w_uniform)
//head
	var/randcloth = rand(1,5)
	switch(randcloth)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/mask/payday1(H), slot_wear_mask)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/mask/payday2(H), slot_wear_mask)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/mask/payday3(H), slot_wear_mask)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/clothing/mask/payday4(H), slot_wear_mask)
		if (5)
			H.equip_to_slot_or_del(new /obj/item/clothing/mask/paydayclown(H), slot_wear_mask)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	if (prob(70))
		var/obj/item/clothing/accessory/armor/coldwar/plates/platecarrierblack/plate_armor = new /obj/item/clothing/accessory/armor/coldwar/plates/platecarrierblack(null)
		uniform.attackby(plate_armor, H)
		var/obj/item/weapon/armorplates/plates1 = new /obj/item/weapon/armorplates(null)
		var/obj/item/weapon/armorplates/plates2 = new /obj/item/weapon/armorplates(null)
		uniform.attackby(plates1, H)
		uniform.attackby(plates2, H)
	else
		var/obj/item/clothing/accessory/armor/modern/plate/plate_armor = new /obj/item/clothing/accessory/armor/modern/plate(null)
		uniform.attackby(plate_armor, H)
//gun
	var/randarmw = rand(1,2)
	switch(randarmw)
		if (1)
			if (prob(75))
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74/aks74(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/ak74(H), slot_belt)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/ak74(H), slot_l_store)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/ak74(H), slot_r_store)
			else
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/tec9(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/tec9(H), slot_belt)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/tec9(H), slot_l_store)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/tec9(H), slot_r_store)
		if (2)
			if (prob(75))
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74/aks74(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/ak74(H), slot_belt)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/ak74(H), slot_l_store)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/ak74(H), slot_r_store)
			else
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/uzi(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/uzi(H), slot_belt)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/uzi(H), slot_l_store)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/uzi(H), slot_r_store)

//suit
	var/randsuit = rand(1,3)
	switch(randsuit)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/charcoal_suit(H), slot_wear_suit)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/black_suit(H), slot_wear_suit)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/navy_suit(H), slot_wear_suit)
//extra
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)

	H.add_note("Role", "You are a <b>[title]</b>. One day your boss Grigoriev told you to go rob a local bank, so you did!")
	H.add_note("Objective", "Steal 10.000 from the bank's vault!")
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("machinegun", STAT_VERY_VERY_HIGH)
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_HIGH)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_HIGH)

////////////////////////////////////////////DRUG BUST///////////////////////////////////////////////////////

/datum/job/russian/rednikov/tatarin
	title = "Vyacheslav Grigoriev"
	rank_abbreviation = ""
	spawn_location = "JoinLateTatarin"

	is_officer = TRUE
	whitelisted = TRUE
	is_vip = TRUE

	is_heist = TRUE
	is_outlaw = TRUE
	can_be_female = FALSE

	min_positions = 1
	max_positions = 1
	additional_languages = list("English" = 100)

/datum/job/russian/rednikov/tatarin/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.civilization = "Rednikov"
	H.name = "Vyacheslav \"Tatarin\" Grigoriev"
	H.real_name = H.name
	H.h_style = "Bald"
	H.f_style = "Shaved"
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/black(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/trackpants(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/tracksuit(H), slot_wear_suit)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armor/coldwar/plates/platecarrierblack/plate_armor = new /obj/item/clothing/accessory/armor/coldwar/plates/platecarrierblack(null)
	uniform.attackby(plate_armor, H)
	var/obj/item/weapon/armorplates/plates1 = new /obj/item/weapon/armorplates(null)
	var/obj/item/weapon/armorplates/plates2 = new /obj/item/weapon/armorplates(null)
	uniform.attackby(plates1, H)
	uniform.attackby(plates2, H)

//extra
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)

	H.add_note("Role", "Your full name is Vyacheslav Grigoriev, but you're commonly known as \"Tatarin\", a ruthless Thief in law. You're considered Nikolay's executioner as your spontaneous and frenzy character gets stuff done, let it be the dirty or the clean way, as long as the price is right. About 2 minutes ago you recieved a call from an insider that a warrant is out for you. You can already hear the police sirens approaching the industrial complex you're supervising. There's no way out, it's time to break the glass.")
	H.setStat("strength", STAT_VERY_VERY_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_VERY_VERY_HIGH)
	H.setStat("machinegun", STAT_VERY_VERY_HIGH)
	H.setStat("dexterity", STAT_VERY_VERY_HIGH)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_VERY_VERY_HIGH)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_HIGH)

/datum/job/russian/rednikov/guard
	title = "Rednikov Guard"
	rank_abbreviation = ""
	spawn_location = "JoinLateRU"

	is_heist = TRUE
	is_outlaw = TRUE
	can_be_female = FALSE

	min_positions = 1
	max_positions = 50
	additional_languages = list("English" = 100)

/datum/job/russian/rednikov/guard/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.civilization = "Rednikov"
	give_random_name(H)
//shoes
	if (prob(25))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/black(H), slot_shoes)
//clothes
	var/randuniform = rand(1,4)
	switch(randuniform)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/trackpants(H), slot_w_uniform)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/tracksuit(H), slot_wear_suit)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/trackpants(H), slot_w_uniform)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ww2/servicejacket(H), slot_wear_suit)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/expensive/red(H), slot_w_uniform)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/trackpants(H), slot_w_uniform)
//head
	if (prob(35))
		H.equip_to_slot_or_del(new /obj/item/clothing/mask/balaclava(H), slot_wear_mask)
//armor
	var/obj/item/clothing/under/uniform = H.w_uniform
	if (prob(70))
		var/obj/item/clothing/accessory/armor/coldwar/plates/platecarrierblack/plate_armor = new /obj/item/clothing/accessory/armor/coldwar/plates/platecarrierblack(null)
		uniform.attackby(plate_armor, H)
		var/obj/item/weapon/armorplates/plates1 = new /obj/item/weapon/armorplates(null)
		var/obj/item/weapon/armorplates/plates2 = new /obj/item/weapon/armorplates(null)
		uniform.attackby(plates1, H)
		uniform.attackby(plates2, H)
	else
		var/obj/item/clothing/accessory/armor/modern/plate/plate_armor = new /obj/item/clothing/accessory/armor/modern/plate(null)
		uniform.attackby(plate_armor, H)
//gun
	var/randarmw = rand(1,2)
	switch(randarmw)
		if (1)
			if (prob(75))
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74/aks74(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/ak74(H), slot_belt)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/ak74(H), slot_l_store)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/ak74(H), slot_r_store)
			else
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/tec9(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/tec9(H), slot_belt)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/tec9(H), slot_l_store)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/tec9(H), slot_r_store)
		if (2)
			if (prob(75))
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak74/aks74(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/ak74(H), slot_belt)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/ak74(H), slot_l_store)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/ak74(H), slot_r_store)
			else
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/uzi(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/uzi(H), slot_belt)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/uzi(H), slot_l_store)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/uzi(H), slot_r_store)

//extra
	H.equip_to_slot_or_del(new /obj/item/weapon/radio/walkietalkie/faction2(H), slot_wear_id)

	H.add_note("Role", "You are a <b>[title]</b> guarding a Storage Depot in the middle of the woods. You've never had any trouble while here but all of the security has been thightend for some reason and you haven't been told why...")
	H.add_note("Command", "You follow direct orders from Vyacheslav \"Tatarin\" Grigoriev, your boss.")
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("machinegun", STAT_VERY_VERY_HIGH)
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_HIGH)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_HIGH)
