////////////////////////////////////////////BRITISH///////////////////////////////////////////////////////

/datum/job/british/civilian/governor
	title = "British Governor"
	en_meaning = "Colony Leader"
	rank_abbreviation = "Governor"
	is_1713 = TRUE
	allowed_maps = list(MAP_FOUR_COLONIES)

	spawn_location = "JoinLateRN"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE

	is_governor = TRUE
	is_RP = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/british/civilian/governor/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_HIGH, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/british/civilian/governor/job_loadout = list(
	/obj/item/clothing/shoes/leatherboots = slot_shoes,
	/obj/item/clothing/under/civ4 = slot_w_uniform,
	/obj/item/clothing/suit/storage/jacket/piratejacket5 = slot_wear_suit,
	/obj/item/clothing/head/powdered_wig = slot_head,
	/obj/item/weapon/key/civ/gov = slot_r_store,
	/obj/item/weapon/key/civ/hall = slot_l_store,
	/obj/item/weapon/material/sword/spadroon = slot_belt)
/datum/job/british/civilian/governor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	equip_loadout(H)
//	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.add_note("Role", "You are a <b>[title]</b>, the leader of this colony. Organize your men and build a village!")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/british/civilian/architect
	title = "British Architect"
	en_meaning = "Colony Chief Carpenter/Planner"
	rank_abbreviation = "Architect"
	is_1713 = TRUE
	spawn_location = "JoinLateRN"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_commander = TRUE
	whitelisted = TRUE
	is_officer = TRUE
	is_RP = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/british/civilian/architect/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_VERY_HIGH, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_MEDIUM_LOW)
/datum/job/british/civilian/architect/job_loadout = list(
	/obj/item/clothing/head/powdered_wig = slot_head,
	/obj/item/weapon/key/civ/hall = slot_l_hand,
	/obj/item/weapon/storage/belt/leather = slot_belt,
	/obj/item/weapon/attachment/scope/adjustable/binoculars = slot_r_store,
	/obj/item/stack/money/real = slot_l_store)
/datum/job/british/civilian/architect/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

	//head
	equip_loadout(H)

	H.add_note("Role", "You are an <b>Architect</b>. Your job is to organize and lead the <b>Carpenters</b>, and develop the colony with your city planning skills!")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/british/civilian/officer
	title = "British Town Guard Officer"
	en_meaning = "Colony Security Leader"
	rank_abbreviation = "Officer"
	is_1713 = TRUE
	spawn_location = "JoinLateRN"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_RP = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/british/civilian/officer/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_HIGH, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_NORMAL)
/datum/job/british/civilian/officer/job_loadout = list(
	/obj/item/clothing/shoes/blackboots = slot_shoes,
	/obj/item/clothing/under/civ2 = slot_w_uniform,
	/obj/item/clothing/suit/storage/jacket/british_soldier = slot_wear_suit,
	/obj/item/clothing/head/tricorne_british_army = slot_head,
	/obj/item/weapon/material/sword/spadroon = slot_belt,
	/obj/item/stack/money/real = slot_l_store,
	/obj/item/weapon/key/civ/hall = slot_r_store)
/datum/job/british/civilian/officer/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	equip_loadout(H)

	H.add_note("Role", "You are a <b>[title]</b>, a veteran of past wars. Your job is to organize the <b>Veterans</b> and keep the colonists safe, reporting to the <b>Governor</b>.")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/british/civilian/veteran
	title = "British Town Guard"
	en_meaning = "Colony Security"
	rank_abbreviation = ""
	is_1713 = TRUE
	spawn_location = "JoinLateRN"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_RP = TRUE

	min_positions = 1
	max_positions = 30

/datum/job/british/civilian/veteran/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_HIGH, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_NORMAL)
/datum/job/british/civilian/veteran/job_loadout = list(
	/obj/item/clothing/shoes/blackboots = slot_shoes,
	/obj/item/clothing/under/civ2 = slot_w_uniform,
	/obj/item/clothing/suit/storage/jacket/british_soldier = slot_wear_suit,
	/obj/item/clothing/head/bicorne_british_soldier = slot_head,
	/obj/item/weapon/material/sword/spadroon = slot_belt,
	/obj/item/stack/money/real = slot_l_store,
	/obj/item/weapon/key/civ/hall = slot_r_store)
/datum/job/british/civilian/veteran/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	equip_loadout(H)

	H.add_note("Role", "You are a <b>[title]</b>, a veteran of past wars. Your job is to organize the colony defense and hunting parties, according to the orders of the <b>Town Guard Officer</b>.")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/british/civilian/medic
	title = "British Doctor"
	en_meaning = "Colony Medic"
	rank_abbreviation = "Doctor"
	is_1713 = TRUE
	spawn_location = "JoinLateRN"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_medic = TRUE
	is_RP = TRUE

	min_positions = 1
	max_positions = 20

/datum/job/british/civilian/medic/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_NORMAL, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_VERY_HIGH)
/datum/job/british/civilian/medic/job_loadout = list(
	/obj/item/clothing/head/powdered_wig = slot_head,
	/obj/item/weapon/storage/firstaid/surgery = slot_l_hand,
	/obj/item/weapon/doctor_handbook = slot_l_store,
	/obj/item/stack/money/real = slot_l_store)
/datum/job/british/civilian/medic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

//head
	equip_loadout(H)

	H.add_note("Role", "You are a <b>[title]</b>, in charge of keeping the newly founded colony healthy.")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/british/civilian/merchant
	title = "British Merchant"
	en_meaning = "Colony Trader"
	rank_abbreviation = "Merchant"
	is_1713 = TRUE
	spawn_location = "JoinLateRN"
	can_be_female = TRUE
	is_RP = TRUE
	is_merchant = TRUE
	allowed_maps = list(MAP_FOUR_COLONIES)

	min_positions = 1
	max_positions = 20

/datum/job/british/civilian/merchant/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_HIGH, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_MEDIUM_HIGH, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_NORMAL)
/datum/job/british/civilian/merchant/job_loadout = list(
	/obj/item/clothing/head/powdered_wig = slot_head,
	/obj/item/stack/money/real = slot_l_store)
/datum/job/british/civilian/merchant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

//head
	equip_loadout(H)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, a trader who decided to move in to the new colony to get rich. Establish your trading post and deal with both the Natives and the Colonists!")
	apply_job_stats(H)
	H.make_businessman()

	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/british/civilian/priest
	title = "British Priest"
	en_meaning = "Colony Priest"
	rank_abbreviation = ""
	is_1713 = TRUE
	spawn_location = "JoinLateRN"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_RP = TRUE
	is_religious = TRUE
	can_be_female = TRUE
	min_positions = 1
	max_positions = 20

/datum/job/british/civilian/priest/job_stats = list("strength" = STAT_MEDIUM_LOW, "crafting" = STAT_NORMAL, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_HIGH)
/datum/job/british/civilian/priest/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)

	if (H.gender == "male")
		H.equip_to_slot_or_del(new /obj/item/clothing/under/chaplain(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/chaplain_hood(H), slot_head)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/chaplain(H), slot_wear_suit)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/nun(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/nun_hood(H), slot_head)

	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, in charge of the colony's religious affairs, assisting the doctor, and if possible, of converting the natives...")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/british/civilian/prospector
	title = "British Prospector"
	en_meaning = "Colony Miner/Explorer"
	rank_abbreviation = ""
	is_1713 = TRUE
	spawn_location = "JoinLateRN"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_RP = TRUE
	can_be_female = TRUE
	min_positions = 3
	max_positions = 40

/datum/job/british/civilian/prospector/job_stats = list("strength" = STAT_HIGH, "crafting" = STAT_MEDIUM_HIGH, "rifle" = STAT_NORMAL, "dexterity" = STAT_MEDIUM_HIGH, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_MEDIUM_LOW)
/datum/job/british/civilian/prospector/job_loadout = list(
	/obj/item/weapon/material/pickaxe = slot_belt,
	/obj/item/weapon/material/shovel = slot_back,
	/obj/item/stack/money/real = slot_l_store)
/datum/job/british/civilian/prospector/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)

	equip_loadout(H)
	H.add_note("Role", "You are a <b>[title]</b>, a former miner who decided to move into the New World to find riches. Explore the area, mine, and sell to the <b>Merchant</b> what you find!")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/british/civilian/farmer
	title = "British Farmer"
	en_meaning = "Colony Farmer/Rancher"
	rank_abbreviation = ""
	is_1713 = TRUE
	spawn_location = "JoinLateRN"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_RP = TRUE
	can_be_female = TRUE
	min_positions = 3
	max_positions = 50

/datum/job/british/civilian/farmer/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_HIGH, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_MEDIUM_HIGH, "swords" = STAT_NORMAL, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_NORMAL, "farming" = STAT_VERY_HIGH)
/datum/job/british/civilian/farmer/job_loadout = list(
	/obj/item/weapon/storage/belt/leather/farmer = slot_belt,
	/obj/item/weapon/plough = slot_l_hand,
	/obj/item/weapon/material/kitchen/utensil/knife = slot_r_store,
	/obj/item/stack/money/real = slot_l_store)
/datum/job/british/civilian/farmer/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)

	equip_loadout(H)

	H.add_note("Role", "You are a <b>[title]</b>, specialized in plant growth, animal husbandry, and cooking. Keep the colony fed!")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/british/civilian/carpenter
	title = "British Carpenter"
	en_meaning = "Colony Carpenter/Craftsman"
	rank_abbreviation = "Carpenter"
	is_1713 = TRUE
	spawn_location = "JoinLateRN"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_RP = TRUE
	can_be_female = TRUE
	min_positions = 3
	max_positions = 50

/datum/job/british/civilian/carpenter/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_VERY_HIGH, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_MEDIUM_LOW)
/datum/job/british/civilian/carpenter/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
//clothes
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)

	//head
		var/randhead = rand(1,5)
		if (randhead == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_sailorberet(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_sailorberet(H), slot_head)
		else if (randhead== 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/strawhat(H), slot_head)
		else if (randhead == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tarred_hat(H), slot_head)
		else if (randhead == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_black(H), slot_head)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

	//head
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)
	H.equip_to_slot_or_del(new 	/obj/item/weapon/material/hatchet(H), slot_belt)
	H.equip_to_slot_or_del(new 	/obj/item/weapon/wrench(H), slot_r_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a <b>Carpenter</b>. Organize the supplies and help the colonists build the Village!")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/british/civilian/blacksmith
	title = "British Blacksmith"
	en_meaning = "Colony Blacksmith"
	rank_abbreviation = "Blacksmith"
	is_1713 = TRUE
	spawn_location = "JoinLateRN"
	can_be_female = TRUE
	whitelisted = TRUE
	is_RP = TRUE
	allowed_maps = list(MAP_FOUR_COLONIES)


	min_positions = 2
	max_positions = 10

/datum/job/british/civilian/blacksmith/job_stats = list("strength" = STAT_VERY_HIGH, "crafting" = 200, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_HIGH, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_VERY_LOW, "medical" = STAT_VERY_LOW)
/datum/job/british/civilian/blacksmith/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
//clothes
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)

	//head
		var/randhead = rand(1,5)
		if (randhead == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_sailorberet(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_sailorberet(H), slot_head)
		else if (randhead== 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/strawhat(H), slot_head)
		else if (randhead == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tarred_hat(H), slot_head)
		else if (randhead == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_black(H), slot_head)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

	//head
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)

	H.equip_to_slot_or_del(new 	/obj/item/weapon/hammer(H), slot_belt)
	H.equip_to_slot_or_del(new 	/obj/item/stack/material/iron/twentyfive(H), slot_l_hand)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>. Your job is to craft weapons and guns. However, you probably should follow the <b>Governor's</b> orders!")
	apply_job_stats(H)
	return TRUE

/datum/job/british/civilian/inkeeper
	title = "British Inkeeper"
	en_meaning = "Colony Innkeeper/Taverner"
	rank_abbreviation = "Innkeeper"
	is_1713 = TRUE
	spawn_location = "JoinLateRN"
	can_be_female = TRUE
	is_RP = TRUE
	allowed_maps = list(MAP_FOUR_COLONIES)

	min_positions = 1
	max_positions = 2

/datum/job/british/civilian/inkeeper/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_NORMAL)
/datum/job/british/civilian/inkeeper/job_loadout = list(
	/obj/item/stack/money/real = slot_l_store,
	/obj/item/weapon/key/civ/inn = slot_r_store,
	/obj/item/weapon/material/kitchen/utensil/knife/butcher = slot_belt)
/datum/job/british/civilian/inkeeper/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)

	//head
		var/randhead = rand(1,5)
		if (randhead == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_sailorberet(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_sailorberet(H), slot_head)
		else if (randhead== 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/strawhat(H), slot_head)
		else if (randhead == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tarred_hat(H), slot_head)
		else if (randhead == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_black(H), slot_head)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

	//head
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)

	equip_loadout(H)

	H.add_note("Role", "You are a <b>Inkeeper</b>. Your job is to build an Inn or Tavern to supply the Colonists with wine and food!")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/british/civilian/worker
	title = "British Colonist"
	en_meaning = "Basic Colonist"
	rank_abbreviation = ""
	is_1713 = TRUE
	spawn_location = "JoinLateRN"
	can_be_female = TRUE
	is_RP = TRUE
	allowed_maps = list(MAP_FOUR_COLONIES)

	min_positions = 10
	max_positions = 150

/datum/job/british/civilian/worker/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_MEDIUM_LOW)
/datum/job/british/civilian/worker/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)

	//head
		var/randhead = rand(1,5)
		if (randhead == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_sailorberet(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_sailorberet(H), slot_head)
		else if (randhead== 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/strawhat(H), slot_head)
		else if (randhead == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tarred_hat(H), slot_head)
		else if (randhead == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_black(H), slot_head)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

	//head
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)

	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a simple <b>Colonist</b>. Build your village!")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

////////////////////////////////////////////SPANISH///////////////////////////////////////////////////////

/datum/job/spanish/civilian/governor
	title = "Gobernador"
	en_meaning = "Colony Leader"
	rank_abbreviation = "Gobernador"
	is_1713 = TRUE
	allowed_maps = list(MAP_FOUR_COLONIES)

	spawn_location = "JoinLateSP"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE

	is_governor = TRUE
	is_RP = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/spanish/civilian/governor/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_HIGH, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/spanish/civilian/governor/job_loadout = list(
	/obj/item/clothing/shoes/leatherboots = slot_shoes,
	/obj/item/clothing/under/civ4 = slot_w_uniform,
	/obj/item/clothing/suit/storage/jacket/piratejacket5 = slot_wear_suit,
	/obj/item/clothing/head/powdered_wig = slot_head,
	/obj/item/weapon/key/civ/gov = slot_r_store,
	/obj/item/weapon/key/civ/hall = slot_l_store,
	/obj/item/weapon/material/sword/spadroon = slot_belt)
/datum/job/spanish/civilian/governor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	equip_loadout(H)
//	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.add_note("Role", "You are a <b>[title]</b>, the leader of this colony. Organize your men and build a village!")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/spanish/civilian/architect
	title = "Arquitecto"
	en_meaning = "Colony Chief Carpenter/Planner"
	rank_abbreviation = "Arquitecto"
	is_1713 = TRUE
	spawn_location = "JoinLateSP"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_commander = TRUE
	whitelisted = TRUE
	is_officer = TRUE
	is_RP = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/spanish/civilian/architect/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_VERY_HIGH, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_MEDIUM_LOW)
/datum/job/spanish/civilian/architect/job_loadout = list(
	/obj/item/clothing/head/powdered_wig = slot_head,
	/obj/item/weapon/key/civ/hall = slot_l_hand,
	/obj/item/weapon/storage/belt/leather = slot_belt,
	/obj/item/weapon/attachment/scope/adjustable/binoculars = slot_r_store,
	/obj/item/stack/money/real = slot_l_store)
/datum/job/spanish/civilian/architect/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

	//head
	equip_loadout(H)

	H.add_note("Role", "You are an <b>Architect</b>. Your job is to organize and lead the <b>Carpenters</b>, and develop the colony with your city planning skills!")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/spanish/civilian/officer
	title = "Oficial de la Milicia"
	en_meaning = "Colony Security Leader"
	rank_abbreviation = "Oficial"
	is_1713 = TRUE
	spawn_location = "JoinLateSP"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_RP = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/spanish/civilian/officer/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_HIGH, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_NORMAL)
/datum/job/spanish/civilian/officer/job_loadout = list(
	/obj/item/clothing/shoes/blackboots = slot_shoes,
	/obj/item/clothing/under/civ2 = slot_w_uniform,
	/obj/item/clothing/suit/storage/jacket/spanish_officer_army = slot_wear_suit,
	/obj/item/clothing/head/spanish_army = slot_head,
	/obj/item/weapon/material/sword/spadroon = slot_belt,
	/obj/item/stack/money/real = slot_l_store,
	/obj/item/weapon/key/civ/hall = slot_r_store)
/datum/job/spanish/civilian/officer/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	equip_loadout(H)

	H.add_note("Role", "You are a <b>[title]</b>, a veteran of past wars. Your job is to organize the <b>Veterans</b> and keep the colonists safe, reporting to the <b>Governor</b>.")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/spanish/civilian/veteran
	title = "Milicia"
	en_meaning = "Colony Security"
	rank_abbreviation = ""
	is_1713 = TRUE
	spawn_location = "JoinLateSP"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_RP = TRUE

	min_positions = 1
	max_positions = 30

/datum/job/spanish/civilian/veteran/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_HIGH, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_NORMAL)
/datum/job/spanish/civilian/veteran/job_loadout = list(
	/obj/item/clothing/shoes/blackboots = slot_shoes,
	/obj/item/clothing/under/civ2 = slot_w_uniform,
	/obj/item/clothing/suit/storage/jacket/spanish_officer_army = slot_wear_suit,
	/obj/item/clothing/head/bicorne_british_soldier = slot_head,
	/obj/item/weapon/material/sword/spadroon = slot_belt,
	/obj/item/stack/money/real = slot_l_store,
	/obj/item/weapon/key/civ/hall = slot_r_store)
/datum/job/spanish/civilian/veteran/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	equip_loadout(H)

	H.add_note("Role", "You are a <b>[title]</b>, a veteran of past wars. Your job is to organize the colony defense and hunting parties, according to the orders of the <b>Town Guard Officer</b>.")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/spanish/civilian/medic
	title = "Curandero"
	en_meaning = "Colony Medic"
	rank_abbreviation = "Doctor"
	is_1713 = TRUE
	spawn_location = "JoinLateSP"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_medic = TRUE
	is_RP = TRUE

	min_positions = 1
	max_positions = 20

/datum/job/spanish/civilian/medic/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_NORMAL, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_VERY_HIGH)
/datum/job/spanish/civilian/medic/job_loadout = list(
	/obj/item/clothing/head/powdered_wig = slot_head,
	/obj/item/weapon/storage/firstaid/surgery = slot_l_hand,
	/obj/item/weapon/doctor_handbook = slot_l_store,
	/obj/item/stack/money/real = slot_l_store)
/datum/job/spanish/civilian/medic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

//head
	equip_loadout(H)

	H.add_note("Role", "You are a <b>[title]</b>, in charge of keeping the newly founded colony healthy.")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/spanish/civilian/merchant
	title = "Comerciante"
	en_meaning = "Colony Trader"
	rank_abbreviation = "Comerciante"
	is_1713 = TRUE
	spawn_location = "JoinLateSP"
	can_be_female = TRUE
	is_RP = TRUE
	is_merchant = TRUE
	allowed_maps = list(MAP_FOUR_COLONIES)

	min_positions = 1
	max_positions = 20

/datum/job/spanish/civilian/merchant/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_HIGH, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_MEDIUM_HIGH, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_NORMAL)
/datum/job/spanish/civilian/merchant/job_loadout = list(
	/obj/item/clothing/head/powdered_wig = slot_head,
	/obj/item/stack/money/real = slot_l_store)
/datum/job/spanish/civilian/merchant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

//head
	equip_loadout(H)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, a trader who decided to move in to the new colony to get rich. Establish your trading post and deal with both the Natives and the Colonists!")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/spanish/civilian/priest
	title = "Cura"
	en_meaning = "Colony Priest"
	rank_abbreviation = ""
	is_1713 = TRUE
	spawn_location = "JoinLateSP"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_RP = TRUE
	is_religious = TRUE
	can_be_female = TRUE
	min_positions = 1
	max_positions = 20

/datum/job/spanish/civilian/priest/job_stats = list("strength" = STAT_MEDIUM_LOW, "crafting" = STAT_NORMAL, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_HIGH)
/datum/job/spanish/civilian/priest/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)

	if (H.gender == "male")
		H.equip_to_slot_or_del(new /obj/item/clothing/under/chaplain(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/chaplain_hood(H), slot_head)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/chaplain(H), slot_wear_suit)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/nun(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/nun_hood(H), slot_head)

	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, in charge of the colony's religious affairs, assisting the doctor, and if possible, of converting the natives...")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/spanish/civilian/prospector
	title = "Minero"
	en_meaning = "Colony Miner/Explorer"
	rank_abbreviation = ""
	is_1713 = TRUE
	spawn_location = "JoinLateSP"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_RP = TRUE
	can_be_female = TRUE
	min_positions = 3
	max_positions = 40

/datum/job/spanish/civilian/prospector/job_stats = list("strength" = STAT_HIGH, "crafting" = STAT_MEDIUM_HIGH, "rifle" = STAT_NORMAL, "dexterity" = STAT_MEDIUM_HIGH, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_MEDIUM_LOW)
/datum/job/spanish/civilian/prospector/job_loadout = list(
	/obj/item/weapon/material/pickaxe = slot_belt,
	/obj/item/weapon/material/shovel = slot_back,
	/obj/item/stack/money/real = slot_l_store)
/datum/job/spanish/civilian/prospector/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)

	equip_loadout(H)
	H.add_note("Role", "You are a <b>[title]</b>, a former miner who decided to move into the New World to find riches. Explore the area, mine, and sell to the <b>Merchant</b> what you find!")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	H.make_businessman()
	return TRUE

/datum/job/spanish/civilian/farmer
	title = "Granjero"
	en_meaning = "Colony Farmer/Rancher"
	rank_abbreviation = ""
	is_1713 = TRUE
	spawn_location = "JoinLateSP"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_RP = TRUE
	can_be_female = TRUE
	min_positions = 3
	max_positions = 50

/datum/job/spanish/civilian/farmer/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_HIGH, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_MEDIUM_HIGH, "swords" = STAT_NORMAL, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_NORMAL, "farming" = STAT_VERY_HIGH)
/datum/job/spanish/civilian/farmer/job_loadout = list(
	/obj/item/weapon/storage/belt/leather/farmer = slot_belt,
	/obj/item/weapon/plough = slot_l_hand,
	/obj/item/weapon/material/kitchen/utensil/knife = slot_r_store,
	/obj/item/stack/money/real = slot_l_store)
/datum/job/spanish/civilian/farmer/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)

	equip_loadout(H)

	H.add_note("Role", "You are a <b>[title]</b>, specialized in plant growth, animal husbandry, and cooking. Keep the colony fed!")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/spanish/civilian/carpenter
	title = "Carpintero"
	en_meaning = "Colony Carpenter/Craftsman"
	rank_abbreviation = "Carpenter"
	is_1713 = TRUE
	spawn_location = "JoinLateSP"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_RP = TRUE
	can_be_female = TRUE
	min_positions = 3
	max_positions = 50

/datum/job/spanish/civilian/carpenter/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_VERY_HIGH, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_MEDIUM_LOW)
/datum/job/spanish/civilian/carpenter/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
//clothes
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)

	//head
		var/randhead = rand(1,5)
		if (randhead == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_sailorberet(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_sailorberet(H), slot_head)
		else if (randhead== 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/strawhat(H), slot_head)
		else if (randhead == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tarred_hat(H), slot_head)
		else if (randhead == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_black(H), slot_head)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

	//head
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)
	H.equip_to_slot_or_del(new 	/obj/item/weapon/material/hatchet(H), slot_belt)
	H.equip_to_slot_or_del(new 	/obj/item/weapon/wrench(H), slot_r_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a <b>Carpenter</b>. Organize the supplies and help the colonists build the Village!")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/spanish/civilian/blacksmith
	title = "Ferrero"
	en_meaning = "Colony Blacksmith"
	rank_abbreviation = "Ferrero"
	is_1713 = TRUE
	spawn_location = "JoinLateSP"
	allowed_maps = list(MAP_FOUR_COLONIES)

	whitelisted = TRUE
	is_RP = TRUE
	can_be_female = TRUE

	min_positions = 2
	max_positions = 10

/datum/job/spanish/civilian/blacksmith/job_stats = list("strength" = STAT_VERY_HIGH, "crafting" = 200, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_HIGH, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_VERY_LOW, "medical" = STAT_VERY_LOW)
/datum/job/spanish/civilian/blacksmith/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
//clothes
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)

	//head
		var/randhead = rand(1,5)
		if (randhead == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_sailorberet(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_sailorberet(H), slot_head)
		else if (randhead== 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/strawhat(H), slot_head)
		else if (randhead == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tarred_hat(H), slot_head)
		else if (randhead == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_black(H), slot_head)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

	//head
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)

	H.equip_to_slot_or_del(new 	/obj/item/weapon/hammer(H), slot_belt)
	H.equip_to_slot_or_del(new 	/obj/item/stack/material/iron/twentyfive(H), slot_l_hand)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>. Your job is to craft weapons and guns. However, you probably should follow the <b>Governor's</b> orders!")
	apply_job_stats(H)
	return TRUE

/datum/job/spanish/civilian/inkeeper
	title = "Ventero"
	en_meaning = "Colony Innkeeper/Taverner"
	rank_abbreviation = "Ventero"
	is_1713 = TRUE
	spawn_location = "JoinLateSP"
	can_be_female = TRUE
	is_RP = TRUE
	allowed_maps = list(MAP_FOUR_COLONIES)

	min_positions = 1
	max_positions = 2

/datum/job/spanish/civilian/inkeeper/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_NORMAL)
/datum/job/spanish/civilian/inkeeper/job_loadout = list(
	/obj/item/stack/money/real = slot_l_store,
	/obj/item/weapon/key/civ/inn = slot_r_store,
	/obj/item/weapon/material/kitchen/utensil/knife/butcher = slot_belt)
/datum/job/spanish/civilian/inkeeper/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)

	//head
		var/randhead = rand(1,5)
		if (randhead == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_sailorberet(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_sailorberet(H), slot_head)
		else if (randhead== 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/strawhat(H), slot_head)
		else if (randhead == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tarred_hat(H), slot_head)
		else if (randhead == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_black(H), slot_head)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

	//head
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)

	equip_loadout(H)

	H.add_note("Role", "You are a <b>Inkeeper</b>. Your job is to build an Inn or Tavern to supply the Colonists with wine and food!")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/spanish/civilian/worker
	title = "Colonista"
	en_meaning = "Basic Colonist"
	rank_abbreviation = ""
	is_1713 = TRUE
	spawn_location = "JoinLateSP"
	can_be_female = TRUE
	is_RP = TRUE
	allowed_maps = list(MAP_FOUR_COLONIES)

	min_positions = 10
	max_positions = 150

/datum/job/spanish/civilian/worker/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_MEDIUM_LOW)
/datum/job/spanish/civilian/worker/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)

	//head
		var/randhead = rand(1,5)
		if (randhead == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_sailorberet(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_sailorberet(H), slot_head)
		else if (randhead== 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/strawhat(H), slot_head)
		else if (randhead == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tarred_hat(H), slot_head)
		else if (randhead == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_black(H), slot_head)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

	//head
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)

	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a simple <b>Colonist</b>. Build your village!")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

////////////////////////////////////////////PORTUGUESE///////////////////////////////////////////////////////

/datum/job/portuguese/civilian/governor
	title = "Governador"
	en_meaning = "Colony Leader"
	rank_abbreviation = "Governador"
	is_1713 = TRUE
	allowed_maps = list(MAP_FOUR_COLONIES)

	spawn_location = "JoinLatePT"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE

	is_governor = TRUE
	is_RP = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/portuguese/civilian/governor/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_HIGH, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/portuguese/civilian/governor/job_loadout = list(
	/obj/item/clothing/shoes/leatherboots = slot_shoes,
	/obj/item/clothing/under/civ4 = slot_w_uniform,
	/obj/item/clothing/suit/storage/jacket/piratejacket5 = slot_wear_suit,
	/obj/item/clothing/head/powdered_wig = slot_head,
	/obj/item/weapon/key/civ/gov = slot_r_store,
	/obj/item/weapon/key/civ/hall = slot_l_store,
	/obj/item/weapon/material/sword/spadroon = slot_belt)
/datum/job/portuguese/civilian/governor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	equip_loadout(H)
//	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.add_note("Role", "You are a <b>[title]</b>, the leader of this colony. Organize your men and build a village!")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/portuguese/civilian/architect
	title = "Arquiteto"
	en_meaning = "Colony Chief Carpenter/Planner"
	rank_abbreviation = "Arquiteto"
	is_1713 = TRUE
	spawn_location = "JoinLatePT"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_commander = TRUE
	whitelisted = TRUE
	is_officer = TRUE
	is_RP = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/portuguese/civilian/architect/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_VERY_HIGH, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_MEDIUM_LOW)
/datum/job/portuguese/civilian/architect/job_loadout = list(
	/obj/item/clothing/head/powdered_wig = slot_head,
	/obj/item/weapon/key/civ/hall = slot_l_hand,
	/obj/item/weapon/storage/belt/leather = slot_belt,
	/obj/item/weapon/attachment/scope/adjustable/binoculars = slot_r_store,
	/obj/item/stack/money/real = slot_l_store)
/datum/job/portuguese/civilian/architect/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

	//head
	equip_loadout(H)

	H.add_note("Role", "You are an <b>Architect</b>. Your job is to organize and lead the <b>Carpenters</b>, and develop the colony with your city planning skills!")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/portuguese/civilian/officer
	title = "Comandante da Milicia"
	en_meaning = "Colony Security Leader"
	rank_abbreviation = "Comandante"
	is_1713 = TRUE
	spawn_location = "JoinLatePT"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_RP = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/portuguese/civilian/officer/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_HIGH, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_NORMAL)
/datum/job/portuguese/civilian/officer/job_loadout = list(
	/obj/item/clothing/shoes/blackboots = slot_shoes,
	/obj/item/clothing/under/civ2 = slot_w_uniform,
	/obj/item/clothing/suit/storage/jacket/portuguese_officer_army = slot_wear_suit,
	/obj/item/clothing/head/portuguese_army = slot_head,
	/obj/item/weapon/material/sword/spadroon = slot_belt,
	/obj/item/stack/money/real = slot_l_store,
	/obj/item/weapon/key/civ/hall = slot_r_store)
/datum/job/portuguese/civilian/officer/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	equip_loadout(H)

	H.add_note("Role", "You are a <b>[title]</b>, a veteran of past wars. Your job is to organize the <b>Veterans</b> and keep the colonists safe, reporting to the <b>Governor</b>.")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/portuguese/civilian/veteran
	title = "Miliciano"
	en_meaning = "Colony Security"
	rank_abbreviation = ""
	is_1713 = TRUE
	spawn_location = "JoinLatePT"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_RP = TRUE

	min_positions = 1
	max_positions = 30

/datum/job/portuguese/civilian/veteran/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_HIGH, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_NORMAL)
/datum/job/portuguese/civilian/veteran/job_loadout = list(
	/obj/item/clothing/shoes/blackboots = slot_shoes,
	/obj/item/clothing/under/civ2 = slot_w_uniform,
	/obj/item/clothing/suit/storage/jacket/portuguese_officer_army = slot_wear_suit,
	/obj/item/clothing/head/bicorne_british_soldier = slot_head,
	/obj/item/weapon/material/sword/spadroon = slot_belt,
	/obj/item/stack/money/real = slot_l_store,
	/obj/item/weapon/key/civ/hall = slot_r_store)
/datum/job/portuguese/civilian/veteran/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	equip_loadout(H)

	H.add_note("Role", "You are a <b>[title]</b>, a veteran of past wars. Your job is to organize the colony defense and hunting parties, according to the orders of the <b>Town Guard Officer</b>.")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/portuguese/civilian/medic
	title = "Medico"
	en_meaning = "Colony Medic"
	rank_abbreviation = "Medico"
	is_1713 = TRUE
	spawn_location = "JoinLatePT"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_medic = TRUE
	is_RP = TRUE

	min_positions = 1
	max_positions = 20

/datum/job/portuguese/civilian/medic/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_NORMAL, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_VERY_HIGH)
/datum/job/portuguese/civilian/medic/job_loadout = list(
	/obj/item/clothing/head/powdered_wig = slot_head,
	/obj/item/weapon/storage/firstaid/surgery = slot_l_hand,
	/obj/item/weapon/doctor_handbook = slot_l_store,
	/obj/item/stack/money/real = slot_l_store)
/datum/job/portuguese/civilian/medic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

//head
	equip_loadout(H)

	H.add_note("Role", "You are a <b>[title]</b>, in charge of keeping the newly founded colony healthy.")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/portuguese/civilian/merchant
	title = "Mercador"
	en_meaning = "Colony Trader"
	rank_abbreviation = "Mercador"
	is_1713 = TRUE
	spawn_location = "JoinLatePT"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_RP = TRUE
	is_merchant = TRUE
	can_be_female = TRUE
	min_positions = 1
	max_positions = 20

/datum/job/portuguese/civilian/merchant/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_HIGH, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_MEDIUM_HIGH, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_NORMAL)
/datum/job/portuguese/civilian/merchant/job_loadout = list(
	/obj/item/clothing/head/powdered_wig = slot_head,
	/obj/item/stack/money/real = slot_l_store)
/datum/job/portuguese/civilian/merchant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

//head
	equip_loadout(H)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, a trader who decided to move in to the new colony to get rich. Establish your trading post and deal with both the Natives and the Colonists!")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	H.make_businessman()
	return TRUE

/datum/job/portuguese/civilian/priest
	title = "Padre"
	en_meaning = "Colony Priest"
	rank_abbreviation = ""
	is_1713 = TRUE
	spawn_location = "JoinLatePT"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_religious = TRUE
	is_RP = TRUE
	can_be_female = TRUE
	min_positions = 1
	max_positions = 20

/datum/job/portuguese/civilian/priest/job_stats = list("strength" = STAT_MEDIUM_LOW, "crafting" = STAT_NORMAL, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_HIGH)
/datum/job/portuguese/civilian/priest/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)

	if (H.gender == "male")
		H.equip_to_slot_or_del(new /obj/item/clothing/under/chaplain(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/chaplain_hood(H), slot_head)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/chaplain(H), slot_wear_suit)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/nun(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/nun_hood(H), slot_head)

	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, in charge of the colony's religious affairs, assisting the doctor, and if possible, of converting the natives...")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/portuguese/civilian/prospector
	title = "Mineiro"
	en_meaning = "Colony Miner/Explorer"
	rank_abbreviation = ""
	is_1713 = TRUE
	spawn_location = "JoinLatePT"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_RP = TRUE
	can_be_female = TRUE
	min_positions = 3
	max_positions = 40

/datum/job/portuguese/civilian/prospector/job_stats = list("strength" = STAT_HIGH, "crafting" = STAT_MEDIUM_HIGH, "rifle" = STAT_NORMAL, "dexterity" = STAT_MEDIUM_HIGH, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_MEDIUM_LOW)
/datum/job/portuguese/civilian/prospector/job_loadout = list(
	/obj/item/weapon/material/pickaxe = slot_belt,
	/obj/item/weapon/material/shovel = slot_back,
	/obj/item/stack/money/real = slot_l_store)
/datum/job/portuguese/civilian/prospector/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)

	equip_loadout(H)
	H.add_note("Role", "You are a <b>[title]</b>, a former miner who decided to move into the New World to find riches. Explore the area, mine, and sell to the <b>Merchant</b> what you find!")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	H.make_businessman()
	return TRUE

/datum/job/portuguese/civilian/farmer
	title = "Fazendeiro"
	en_meaning = "Colony Farmer/Rancher"
	rank_abbreviation = ""
	is_1713 = TRUE
	spawn_location = "JoinLatePT"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_RP = TRUE
	can_be_female = TRUE
	min_positions = 3
	max_positions = 50

/datum/job/portuguese/civilian/farmer/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_HIGH, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_MEDIUM_HIGH, "swords" = STAT_NORMAL, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_NORMAL, "farming" = STAT_VERY_HIGH)
/datum/job/portuguese/civilian/farmer/job_loadout = list(
	/obj/item/weapon/storage/belt/leather/farmer = slot_belt,
	/obj/item/weapon/plough = slot_l_hand,
	/obj/item/weapon/material/kitchen/utensil/knife = slot_r_store,
	/obj/item/stack/money/real = slot_l_store)
/datum/job/portuguese/civilian/farmer/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)

	equip_loadout(H)

	H.add_note("Role", "You are a <b>[title]</b>, specialized in plant growth, animal husbandry, and cooking. Keep the colony fed!")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/portuguese/civilian/carpenter
	title = "Carpinteiro"
	en_meaning = "Colony Carpenter/Craftsman"
	rank_abbreviation = "Carpinteiro"
	is_1713 = TRUE
	spawn_location = "JoinLatePT"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_RP = TRUE
	can_be_female = TRUE
	min_positions = 3
	max_positions = 50

/datum/job/portuguese/civilian/carpenter/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_VERY_HIGH, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_MEDIUM_LOW)
/datum/job/portuguese/civilian/carpenter/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
//clothes
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)

	//head
		var/randhead = rand(1,5)
		if (randhead == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_sailorberet(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_sailorberet(H), slot_head)
		else if (randhead== 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/strawhat(H), slot_head)
		else if (randhead == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tarred_hat(H), slot_head)
		else if (randhead == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_black(H), slot_head)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

	//head
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)
	H.equip_to_slot_or_del(new 	/obj/item/weapon/material/hatchet(H), slot_belt)
	H.equip_to_slot_or_del(new 	/obj/item/weapon/wrench(H), slot_r_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a <b>Carpenter</b>. Organize the supplies and help the colonists build the Village!")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/portuguese/civilian/blacksmith
	title = "Ferreiro"
	en_meaning = "Colony Blacksmith"
	rank_abbreviation = "Ferreiro"
	is_1713 = TRUE
	spawn_location = "JoinLatePT"
	whitelisted = TRUE
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_RP = TRUE
	can_be_female = TRUE

	min_positions = 2
	max_positions = 10

/datum/job/portuguese/civilian/blacksmith/job_stats = list("strength" = STAT_VERY_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_HIGH, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_VERY_LOW, "medical" = STAT_VERY_LOW)
/datum/job/portuguese/civilian/blacksmith/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
//clothes
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)

	//head
		var/randhead = rand(1,5)
		if (randhead == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_sailorberet(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_sailorberet(H), slot_head)
		else if (randhead== 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/strawhat(H), slot_head)
		else if (randhead == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tarred_hat(H), slot_head)
		else if (randhead == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_black(H), slot_head)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

	//head
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)

	H.equip_to_slot_or_del(new 	/obj/item/weapon/hammer(H), slot_belt)
	H.equip_to_slot_or_del(new 	/obj/item/stack/material/iron/twentyfive(H), slot_l_hand)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>. Your job is to craft weapons and guns. However, you probably should follow the <b>Governor's</b> orders!")
	apply_job_stats(H)
	return TRUE

/datum/job/portuguese/civilian/inkeeper
	title = "Taberneiro"
	en_meaning = "Colony Innkeeper/Taverner"
	rank_abbreviation = "Taberneiro"
	is_1713 = TRUE
	spawn_location = "JoinLatePT"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_RP = TRUE
	can_be_female = TRUE
	min_positions = 1
	max_positions = 2

/datum/job/portuguese/civilian/inkeeper/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_NORMAL)
/datum/job/portuguese/civilian/inkeeper/job_loadout = list(
	/obj/item/stack/money/real = slot_l_store,
	/obj/item/weapon/key/civ/inn = slot_r_store,
	/obj/item/weapon/material/kitchen/utensil/knife/butcher = slot_belt)
/datum/job/portuguese/civilian/inkeeper/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)

	//head
		var/randhead = rand(1,5)
		if (randhead == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_sailorberet(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_sailorberet(H), slot_head)
		else if (randhead== 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/strawhat(H), slot_head)
		else if (randhead == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tarred_hat(H), slot_head)
		else if (randhead == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_black(H), slot_head)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

	//head
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)

	equip_loadout(H)

	H.add_note("Role", "You are a <b>Inkeeper</b>. Your job is to build an Inn or Tavern to supply the Colonists with wine and food!")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/portuguese/civilian/worker
	title = "Colono"
	en_meaning = "Basic Colonist"
	rank_abbreviation = ""
	is_1713 = TRUE
	spawn_location = "JoinLatePT"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_RP = TRUE
	can_be_female = TRUE
	min_positions = 10
	max_positions = 150

/datum/job/portuguese/civilian/worker/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_MEDIUM_LOW)
/datum/job/portuguese/civilian/worker/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)

	//head
		var/randhead = rand(1,5)
		if (randhead == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_sailorberet(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_sailorberet(H), slot_head)
		else if (randhead== 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/strawhat(H), slot_head)
		else if (randhead == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tarred_hat(H), slot_head)
		else if (randhead == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_black(H), slot_head)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

	//head
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)

	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a simple <b>Colonist</b>. Build your village!")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE


////////////////////////////////////////////FRENCH///////////////////////////////////////////////////////

/datum/job/french/civilian/governor
	title = "Governeur"
	en_meaning = "Colony Leader"
	rank_abbreviation = "Governeur"
	is_1713 = TRUE
	allowed_maps = list(MAP_FOUR_COLONIES)

	spawn_location = "JoinLatePirate"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE

	is_governor = TRUE
	is_RP = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/french/civilian/governor/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_HIGH, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/french/civilian/governor/job_loadout = list(
	/obj/item/clothing/shoes/leatherboots = slot_shoes,
	/obj/item/clothing/under/civ4 = slot_w_uniform,
	/obj/item/clothing/suit/storage/jacket/piratejacket5 = slot_wear_suit,
	/obj/item/clothing/head/powdered_wig = slot_head,
	/obj/item/weapon/key/civ/gov = slot_r_store,
	/obj/item/weapon/key/civ/hall = slot_l_store,
	/obj/item/weapon/material/sword/spadroon = slot_belt)
/datum/job/french/civilian/governor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	equip_loadout(H)
//	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.add_note("Role", "You are a <b>[title]</b>, the leader of this colony. Organize your men and build a village!")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/french/civilian/architect
	title = "Architecte"
	en_meaning = "Colony Chief Carpenter/Planner"
	rank_abbreviation = "Architecte"
	is_1713 = TRUE
	spawn_location = "JoinLatePirate"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_commander = TRUE
	whitelisted = TRUE
	is_officer = TRUE
	is_RP = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/french/civilian/architect/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_VERY_HIGH, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_MEDIUM_LOW)
/datum/job/french/civilian/architect/job_loadout = list(
	/obj/item/clothing/head/powdered_wig = slot_head,
	/obj/item/weapon/key/civ/hall = slot_l_hand,
	/obj/item/weapon/storage/belt/leather = slot_belt,
	/obj/item/weapon/attachment/scope/adjustable/binoculars = slot_r_store,
	/obj/item/stack/money/real = slot_l_store)
/datum/job/french/civilian/architect/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

	//head
	equip_loadout(H)

	H.add_note("Role", "You are an <b>Architect</b>. Your job is to organize and lead the <b>Carpenters</b>, and develop the colony with your city planning skills!")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/french/civilian/officer
	title = "Officier de la Garde"
	en_meaning = "Colony Security Leader"
	rank_abbreviation = "Officier"
	is_1713 = TRUE
	spawn_location = "JoinLatePirate"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_RP = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/french/civilian/officer/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_HIGH, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_NORMAL)
/datum/job/french/civilian/officer/job_loadout = list(
	/obj/item/clothing/shoes/blackboots = slot_shoes,
	/obj/item/clothing/under/civ2 = slot_w_uniform,
	/obj/item/clothing/suit/storage/jacket/french_officer_army = slot_wear_suit,
	/obj/item/clothing/head/french_army = slot_head,
	/obj/item/weapon/material/sword/spadroon = slot_belt,
	/obj/item/stack/money/real = slot_l_store,
	/obj/item/weapon/key/civ/hall = slot_r_store)
/datum/job/french/civilian/officer/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	equip_loadout(H)

	H.add_note("Role", "You are a <b>[title]</b>, a veteran of past wars. Your job is to organize the <b>Veterans</b> and keep the colonists safe, reporting to the <b>Governor</b>.")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/french/civilian/veteran
	title = "Garde"
	en_meaning = "Colony Security"
	rank_abbreviation = ""
	is_1713 = TRUE
	spawn_location = "JoinLatePirate"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_RP = TRUE

	min_positions = 1
	max_positions = 30

/datum/job/french/civilian/veteran/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_HIGH, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_NORMAL)
/datum/job/french/civilian/veteran/job_loadout = list(
	/obj/item/clothing/shoes/blackboots = slot_shoes,
	/obj/item/clothing/under/civ2 = slot_w_uniform,
	/obj/item/clothing/suit/storage/jacket/french_officer_army = slot_wear_suit,
	/obj/item/clothing/head/bicorne_british_soldier = slot_head,
	/obj/item/weapon/material/sword/spadroon = slot_belt,
	/obj/item/stack/money/real = slot_l_store,
	/obj/item/weapon/key/civ/hall = slot_r_store)
/datum/job/french/civilian/veteran/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	equip_loadout(H)

	H.add_note("Role", "You are a <b>[title]</b>, a veteran of past wars. Your job is to organize the colony defense and hunting parties, according to the orders of the <b>Town Guard Officer</b>.")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/french/civilian/medic
	title = "Docteur"
	en_meaning = "Colony Medic"
	rank_abbreviation = "Docteur"
	is_1713 = TRUE
	spawn_location = "JoinLatePirate"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_medic = TRUE
	is_RP = TRUE

	min_positions = 1
	max_positions = 20

/datum/job/french/civilian/medic/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_NORMAL, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_VERY_HIGH)
/datum/job/french/civilian/medic/job_loadout = list(
	/obj/item/clothing/head/powdered_wig = slot_head,
	/obj/item/weapon/storage/firstaid/surgery = slot_l_hand,
	/obj/item/weapon/doctor_handbook = slot_l_store,
	/obj/item/stack/money/real = slot_l_store)
/datum/job/french/civilian/medic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

//head
	equip_loadout(H)

	H.add_note("Role", "You are a <b>[title]</b>, in charge of keeping the newly founded colony healthy.")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/french/civilian/merchant
	title = "Marchand"
	en_meaning = "Colony Trader"
	rank_abbreviation = "Marchand"
	is_1713 = TRUE
	spawn_location = "JoinLatePirate"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_merchant = TRUE
	is_RP = TRUE
	can_be_female = TRUE
	min_positions = 1
	max_positions = 20

/datum/job/french/civilian/merchant/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_HIGH, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_MEDIUM_HIGH, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_NORMAL)
/datum/job/french/civilian/merchant/job_loadout = list(
	/obj/item/clothing/head/powdered_wig = slot_head,
	/obj/item/stack/money/real = slot_l_store)
/datum/job/french/civilian/merchant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

//head
	equip_loadout(H)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, a trader who decided to move in to the new colony to get rich. Establish your trading post and deal with both the Natives and the Colonists!")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	H.make_businessman()
	return TRUE

/datum/job/french/civilian/priest
	title = "Pretre"
	en_meaning = "Colony Priest"
	rank_abbreviation = ""
	is_1713 = TRUE
	spawn_location = "JoinLatePirate"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_RP = TRUE
	is_religious = TRUE
	can_be_female = TRUE
	min_positions = 1
	max_positions = 20

/datum/job/french/civilian/priest/job_stats = list("strength" = STAT_MEDIUM_LOW, "crafting" = STAT_NORMAL, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_HIGH)
/datum/job/french/civilian/priest/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)

	if (H.gender == "male")
		H.equip_to_slot_or_del(new /obj/item/clothing/under/chaplain(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/chaplain_hood(H), slot_head)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/chaplain(H), slot_wear_suit)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/nun(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/nun_hood(H), slot_head)

	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, in charge of the colony's religious affairs, assisting the doctor, and if possible, of converting the natives...")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/french/civilian/prospector
	title = "Mineur"
	en_meaning = "Colony Miner/Explorer"
	rank_abbreviation = ""
	is_1713 = TRUE
	spawn_location = "JoinLatePirate"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_RP = TRUE
	can_be_female = TRUE
	min_positions = 3
	max_positions = 40

/datum/job/french/civilian/prospector/job_stats = list("strength" = STAT_HIGH, "crafting" = STAT_MEDIUM_HIGH, "rifle" = STAT_NORMAL, "dexterity" = STAT_MEDIUM_HIGH, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_MEDIUM_LOW)
/datum/job/french/civilian/prospector/job_loadout = list(
	/obj/item/weapon/material/pickaxe = slot_belt,
	/obj/item/weapon/material/shovel = slot_back,
	/obj/item/stack/money/real = slot_l_store)
/datum/job/french/civilian/prospector/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)

	equip_loadout(H)
	H.add_note("Role", "You are a <b>[title]</b>, a former miner who decided to move into the New World to find riches. Explore the area, mine, and sell to the <b>Merchant</b> what you find!")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	H.make_businessman()
	return TRUE

/datum/job/french/civilian/farmer
	title = "Fermier"
	en_meaning = "Colony Farmer/Rancher"
	rank_abbreviation = ""
	is_1713 = TRUE
	spawn_location = "JoinLatePirate"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_RP = TRUE
	can_be_female = TRUE
	min_positions = 3
	max_positions = 50

/datum/job/french/civilian/farmer/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_HIGH, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_MEDIUM_HIGH, "swords" = STAT_NORMAL, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_NORMAL, "farming" = STAT_VERY_HIGH)
/datum/job/french/civilian/farmer/job_loadout = list(
	/obj/item/weapon/storage/belt/leather/farmer = slot_belt,
	/obj/item/weapon/plough = slot_l_hand,
	/obj/item/weapon/material/kitchen/utensil/knife = slot_r_store,
	/obj/item/stack/money/real = slot_l_store)
/datum/job/french/civilian/farmer/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)

	equip_loadout(H)

	H.add_note("Role", "You are a <b>[title]</b>, specialized in plant growth, animal husbandry, and cooking. Keep the colony fed!")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/french/civilian/carpenter
	title = "Charpentier"
	en_meaning = "Colony Carpenter/Craftsman"
	rank_abbreviation = "Charpentier"
	is_1713 = TRUE
	spawn_location = "JoinLatePirate"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_RP = TRUE
	can_be_female = TRUE
	min_positions = 3
	max_positions = 50

/datum/job/french/civilian/carpenter/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_VERY_HIGH, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_MEDIUM_LOW)
/datum/job/french/civilian/carpenter/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
//clothes
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)

	//head
		var/randhead = rand(1,5)
		if (randhead == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_sailorberet(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_sailorberet(H), slot_head)
		else if (randhead== 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/strawhat(H), slot_head)
		else if (randhead == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tarred_hat(H), slot_head)
		else if (randhead == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_black(H), slot_head)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

	//head
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)
	H.equip_to_slot_or_del(new 	/obj/item/weapon/material/hatchet(H), slot_belt)
	H.equip_to_slot_or_del(new 	/obj/item/weapon/wrench(H), slot_r_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a <b>Carpenter</b>. Organize the supplies and help the colonists build the Village!")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/french/civilian/blacksmith
	title = "Forgeron"
	en_meaning = "Colony Blacksmith"
	rank_abbreviation = "Forgeron"
	is_1713 = TRUE
	spawn_location = "JoinLatePirate"
	whitelisted = TRUE
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_RP = TRUE

	can_be_female = TRUE
	min_positions = 2
	max_positions = 10

/datum/job/french/civilian/blacksmith/job_stats = list("strength" = STAT_VERY_HIGH, "crafting" = 200, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_HIGH, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_VERY_LOW, "medical" = STAT_VERY_LOW)
/datum/job/french/civilian/blacksmith/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
//clothes
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)

	//head
		var/randhead = rand(1,5)
		if (randhead == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_sailorberet(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_sailorberet(H), slot_head)
		else if (randhead== 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/strawhat(H), slot_head)
		else if (randhead == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tarred_hat(H), slot_head)
		else if (randhead == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_black(H), slot_head)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

	//head
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)

	H.equip_to_slot_or_del(new 	/obj/item/weapon/hammer(H), slot_belt)
	H.equip_to_slot_or_del(new 	/obj/item/stack/material/iron/twentyfive(H), slot_l_hand)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>. Your job is to craft weapons and guns. However, you probably should follow the <b>Governor's</b> orders!")
	apply_job_stats(H)
	return TRUE

/datum/job/french/civilian/inkeeper
	title = "Aubergiste"
	en_meaning = "Colony Innkeeper/Taverner"
	rank_abbreviation = "Aubergiste"
	is_1713 = TRUE
	spawn_location = "JoinLatePirate"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_RP = TRUE
	can_be_female = TRUE
	min_positions = 1
	max_positions = 2

/datum/job/french/civilian/inkeeper/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_NORMAL)
/datum/job/french/civilian/inkeeper/job_loadout = list(
	/obj/item/stack/money/real = slot_l_store,
	/obj/item/weapon/key/civ/inn = slot_r_store,
	/obj/item/weapon/material/kitchen/utensil/knife/butcher = slot_belt)
/datum/job/french/civilian/inkeeper/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)

	//head
		var/randhead = rand(1,5)
		if (randhead == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_sailorberet(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_sailorberet(H), slot_head)
		else if (randhead== 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/strawhat(H), slot_head)
		else if (randhead == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tarred_hat(H), slot_head)
		else if (randhead == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_black(H), slot_head)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

	//head
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)

	equip_loadout(H)

	H.add_note("Role", "You are a <b>Inkeeper</b>. Your job is to build an Inn or Tavern to supply the Colonists with wine and food!")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/french/civilian/worker
	title = "Coloniste"
	en_meaning = "Basic Colonist"
	rank_abbreviation = ""
	is_1713 = TRUE
	spawn_location = "JoinLatePirate"
	allowed_maps = list(MAP_FOUR_COLONIES)

	is_RP = TRUE
	can_be_female = TRUE
	min_positions = 10
	max_positions = 150

/datum/job/french/civilian/worker/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_MEDIUM_LOW, "medical" = STAT_MEDIUM_LOW)
/datum/job/french/civilian/worker/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	give_random_name(H)

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	if (H.gender == "male")
		var/randcloth = rand(1,5)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ3(H), slot_w_uniform)
		else if (randcloth == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ5(H), slot_w_uniform)
		else if (randcloth == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civ6(H), slot_w_uniform)

	//head
		var/randhead = rand(1,5)
		if (randhead == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_sailorberet(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_sailorberet(H), slot_head)
		else if (randhead== 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/strawhat(H), slot_head)
		else if (randhead == 4)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tarred_hat(H), slot_head)
		else if (randhead == 5)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_black(H), slot_head)
	else
		var/randcloth = rand(1,3)
		if (randcloth == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf1(H), slot_w_uniform)
		else if (randcloth == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf2(H), slot_w_uniform)
		else if (randcloth == 3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/civf3(H), slot_w_uniform)

	//head
		H.equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(H), slot_head)

	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a simple <b>Colonist</b>. Build your village!")
	apply_job_stats(H)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

