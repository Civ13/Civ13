
/datum/job/vietnamese
	faction = "Station"

/datum/job/vietnamese/give_random_name(var/mob/living/carbon/human/H)
	H.name = H.species.get_random_vietnamese_name(H.gender)
	H.real_name = H.name

/datum/job/vietnamese/vietcong_officer
	title = "Si Quan"
	en_meaning = "Vietcong Officer"
	rank_abbreviation = "Si Quan"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateJPCap"
	SL_check_independent = TRUE
	is_coldwar = TRUE
	is_officer = TRUE
	// AUTOBALANCE
	min_positions = 2
	max_positions = 8

/datum/job/vietnamese/vietcong_officer/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/vietcong(H), slot_w_uniform)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/pith(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ppsh(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_l_store)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/ww1/british/fullwebbing = new /obj/item/clothing/accessory/storage/webbing/ww1/british(null)
	uniform.attackby(fullwebbing, H)
	var/obj/item/clothing/accessory/armband/red_scarf/rscarf = new /obj/item/clothing/accessory/armband/red_scarf(null)
	uniform.attackby(rscarf, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, lead the Viet Cong in the fight against the imperialists!")
	H.add_note("Vietcong Mechanics", "- Press <b>C</b> to place a booby trap while holding a grenade.<br>- The tunnel entrances connecting to your underground compound are only accessible by fellow Vietnamese. Americans won't be able to crawl inside.<br>- Drag yourself to a Jungle Tree to hide on it.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL) //muskets
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/vietnamese/vietcong_doctor
	title = "Bac Si"
	en_meaning = "Vietcong Medic"
	rank_abbreviation = "Bac Si"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateJP"
	SL_check_independent = TRUE
	is_coldwar = TRUE
	// AUTOBALANCE
	min_positions = 3
	max_positions = 18

/datum/job/vietnamese/vietcong_doctor/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sandal(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/vietcong(H), slot_w_uniform)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/jungle_hat/khaki(H), slot_head)
//back
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/m1892(H), slot_l_store)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/luger(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/medical/full_vc(H), slot_belt)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/custom/armband/white = new /obj/item/clothing/accessory/custom/armband(null)
	uniform.attackby(white, H)
	var/obj/item/clothing/accessory/armband/blue_scarf/bscarf = new /obj/item/clothing/accessory/armband/blue_scarf(null)
	uniform.attackby(bscarf, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. Keep your comrades healthy!")
	H.add_note("Vietcong Mechanics", "- Press <b>C</b> to place a booby trap while holding a grenade.<br>- The tunnel entrances connecting to your underground compound are only accessible by fellow Vietnamese. Americans won't be able to crawl inside.<br>- Drag yourself to a Jungle Tree to hide on it.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL) //muskets
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_HIGH)
	return TRUE


/datum/job/vietnamese/vietcong
	title = "Binh Ni"
	en_meaning = "Vietcong Soldier"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateJP"
	SL_check_independent = TRUE
	is_coldwar = TRUE
	// AUTOBALANCE
	min_positions = 20
	max_positions = 200

/datum/job/vietnamese/vietcong/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sandal(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/vietcong(H), slot_w_uniform)

//head
	if (prob(40))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/rice_hat(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/jungle_hat(H), slot_head)
//back
	var/pickgun = rand(1,4)
	if (pickgun == 1)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/semiautomatic/sks(H), slot_back)
	else if (pickgun == 2)
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/m1892(H), slot_belt)
		else
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/luger(H), slot_belt)
	else if (pickgun == 3)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak47(H), slot_back)
	else if (pickgun == 4)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/mosin(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet/military(H), slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/ww1/british/fullwebbing = new /obj/item/clothing/accessory/storage/webbing/ww1/british(null)
	uniform.attackby(fullwebbing, H)
	if (prob(60))
		var/obj/item/clothing/accessory/armband/khan_ran_scarf/krscarf = new /obj/item/clothing/accessory/armband/khan_ran_scarf(null)
		uniform.attackby(krscarf, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, fighting guerilla warfare against the imperialists!")
	H.add_note("Vietcong Mechanics", "- Press <b>C</b> to place a booby trap while holding a grenade.<br>- The tunnel entrances connecting to your underground compound are only accessible by fellow Vietnamese. Americans won't be able to crawl inside.<br>- Drag yourself to a Jungle Tree to hide on it.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_NORMAL) //muskets
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)

	return TRUE

////////////////////////////////////////////////US////////////////////////////////////////

/datum/job/american
	faction = "Station"

/datum/job/american/give_random_name(var/mob/living/carbon/human/H)
	H.name = H.species.get_random_english_name(H.gender)
	H.real_name = H.name


/datum/job/american/american_lieutenant
	title = "US Lieutenant"
	rank_abbreviation = "Lt."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN"
	SL_check_independent = TRUE
	is_coldwar = TRUE
	is_officer = TRUE
	is_commander = TRUE
	// AUTOBALANCE
	min_positions = 1
	max_positions = 2

/datum/job/american/american_lieutenant/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)

//clothes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_lightuni(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/us_jacket(H), slot_wear_suit)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_lightuni2(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/us_jacket(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ushelmet/lt(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/glasses/sunglasses(H), slot_wear_mask)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m16(H), slot_back)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/yellow_scarf/yscarf = new /obj/item/clothing/accessory/armband/yellow_scarf(null)
	uniform.attackby(yscarf, H)

	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. You are in charge of the whole platoon. Organize your troops accordingly!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_NORMAL) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_NORMAL)
	return TRUE

/datum/job/american/american_sergeant
	title = "US Sergeant"
	rank_abbreviation = "Sgt."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN"
	SL_check_independent = TRUE
	is_coldwar = TRUE
	is_officer = TRUE
	// AUTOBALANCE
	min_positions = 2
	max_positions = 8

/datum/job/american/american_sergeant/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)

//clothes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_lightuni(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/us_jacket(H), slot_wear_suit)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_lightuni2(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/us_jacket(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ushelmet/sgt(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m16(H), slot_back)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet/military(H), slot_l_store)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, lead a squad against the Vietcong!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_NORMAL)
	return TRUE

/datum/job/american/american_medic
	title = "US Field Medic"
	rank_abbreviation = "Cpl."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN"
	SL_check_independent = TRUE
	is_coldwar = TRUE
	// AUTOBALANCE
	min_positions = 2
	max_positions = 8

/datum/job/american/american_medic/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)

//clothes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_lightuni(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/us_jacket(H), slot_wear_suit)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_lightuni2(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/us_jacket(H), slot_wear_suit)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ushelmet/medical(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m14(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/medical/full_us(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/custom/armband/white = new /obj/item/clothing/accessory/custom/armband(null)
	uniform.attackby(white, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>. Keep your fellow soldiers healthy!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW) //not used
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_VERY_HIGH)
	return TRUE

/datum/job/american/american_marksman
	title = "US Marksman"
	rank_abbreviation = "Spc."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN"
	SL_check_independent = TRUE
	is_coldwar = TRUE
	// AUTOBALANCE
	min_positions = 2
	max_positions = 12

/datum/job/american/american_marksman/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)

//clothes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_lightuni(H), slot_w_uniform)
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/us_jacket(H), slot_wear_suit)
	else
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_lightuni2(H), slot_w_uniform)
			if (prob(50))
				H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/us_jacket(H), slot_wear_suit)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_greentrousers(H), slot_w_uniform)
			var/obj/item/clothing/under/uniform = H.w_uniform
			var/obj/item/clothing/accessory/storage/webbing/us_vest/fullwebbing = new /obj/item/clothing/accessory/storage/webbing/us_vest(null)
			uniform.attackby(fullwebbing, H)
//head
	if (prob(70))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ushelmet/camo(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ushelmet/late(H), slot_head)
//back
	var/obj/item/weapon/gun/projectile/submachinegun/m14/m14sniper = new /obj/item/weapon/gun/projectile/submachinegun/m14(H)
	H.equip_to_slot_or_del(m14sniper, slot_back)
	var/obj/item/weapon/attachment/scope/adjustable/sniper_scope/snipsc = new /obj/item/weapon/attachment/scope/adjustable/sniper_scope(null)
	m14sniper.attach_A(snipsc,H)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet/military(H), slot_l_store)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, fighting against the Vietcong!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_VERY_HIGH) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)

	return TRUE

/datum/job/american/american_soldier
	title = "US Soldier"
	rank_abbreviation = "Pvt."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN"
	SL_check_independent = TRUE
	is_coldwar = TRUE
	// AUTOBALANCE
	min_positions = 10
	max_positions = 100

/datum/job/american/american_soldier/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)

//clothes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_lightuni(H), slot_w_uniform)
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/us_jacket(H), slot_wear_suit)
	else
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_lightuni2(H), slot_w_uniform)
			if (prob(50))
				H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/us_jacket(H), slot_wear_suit)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_greentrousers(H), slot_w_uniform)
			var/obj/item/clothing/under/uniform = H.w_uniform
			var/obj/item/clothing/accessory/storage/webbing/us_vest/fullwebbing = new /obj/item/clothing/accessory/storage/webbing/us_vest(null)
			uniform.attackby(fullwebbing, H)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/modern/ushelmet/late(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/m16(H), slot_back)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/bayonet/military(H), slot_l_store)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, fighting against the Vietcong!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)
	return TRUE