////////////////////////////////////////////BRITISH///////////////////////////////////////////////////////

/datum/job/british/civilian/governor
	title = "British Governor"
	en_meaning = "Colony Leader"
	rank_abbreviation = "Governor"
	head_position = TRUE
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	SL_check_independent = TRUE
	is_governor = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/british/civilian/governor/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/civ4(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/piratejacket5(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/powdered_wig(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/gov(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/hall(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
//	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.add_note("Role", "You are a <b>[title]</b>, the leader of this colony. Organize your men and build a village!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)

	return TRUE

/datum/job/british/civilian/architect
	title = "British Architect"
	en_meaning = "Colony Chief Carpenter/Planner"
	rank_abbreviation = "Architect"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN"
	SL_check_independent = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_officer = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/british/civilian/architect/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
	H.equip_to_slot_or_del(new /obj/item/clothing/head/powdered_wig(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/hall(H), slot_l_hand)
	H.equip_to_slot_or_del(new/obj/item/weapon/storage/belt/leather(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_r_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are an <b>Architect</b>. Your job is to organize and lead the <b>Carpenters</b>, and develop the colony with your city planning skills!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)

	return TRUE

/datum/job/british/civilian/officer
	title = "British Town Guard Officer"
	en_meaning = "Colony Security Leader"
	rank_abbreviation = "Officer"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN"
	SL_check_independent = TRUE
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/british/civilian/officer/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/british_soldier(H), slot_wear_suit)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_british_army(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)

	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/hall(H), slot_r_store)

	H.add_note("Role", "You are a <b>[title]</b>, a veteran of past wars. Your job is to organize the <b>Veterans</b> and keep the colonists safe, reporting to the <b>Governor</b>.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)

	return TRUE


/datum/job/british/civilian/veteran
	title = "British Town Guard"
	en_meaning = "Colony Security"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN"
	SL_check_independent = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 1
	max_positions = 30

/datum/job/british/civilian/veteran/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/british_soldier(H), slot_wear_suit)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/bicorne_british_soldier(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)

	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/hall(H), slot_r_store)

	H.add_note("Role", "You are a <b>[title]</b>, a veteran of past wars. Your job is to organize the colony defense and hunting parties, according to the orders of the <b>Town Guard Officer</b>.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)

	return TRUE



/datum/job/british/civilian/medic
	title = "British Doctor"
	en_meaning = "Colony Medic"
	rank_abbreviation = "Doctor"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN"
	SL_check_independent = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 1
	max_positions = 20

/datum/job/british/civilian/medic/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
	H.equip_to_slot_or_del(new /obj/item/clothing/head/powdered_wig(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/surgery(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, in charge of keeping the newly founded colony healthy.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_VERY_HIGH)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)

	return TRUE
/datum/job/british/civilian/merchant
	title = "British Merchant"
	en_meaning = "Colony Trader"
	rank_abbreviation = "Merchant"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN"
	SL_check_independent = TRUE
	is_RP = TRUE
	is_merchant = TRUE
	// AUTOBALANCE
	min_positions = 1
	max_positions = 20

/datum/job/british/civilian/merchant/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
	H.equip_to_slot_or_del(new /obj/item/clothing/head/powdered_wig(H), slot_head)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, a trader who decided to move in to the new colony to get rich. Establish your trading post and deal with both the Natives and the Colonists!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_NORMAL)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE
/datum/job/british/civilian/priest
	title = "British Priest"
	en_meaning = "Colony Priest"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN"
	SL_check_independent = TRUE
	is_RP = TRUE
	is_religious = TRUE
	// AUTOBALANCE
	min_positions = 1
	max_positions = 20

/datum/job/british/civilian/priest/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)

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
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_HIGH)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/british/civilian/prospector
	title = "British Prospector"
	en_meaning = "Colony Miner/Explorer"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN"
	SL_check_independent = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 3
	max_positions = 40

/datum/job/british/civilian/prospector/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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

	H.equip_to_slot_or_del(new/obj/item/weapon/pickaxe(H), slot_belt)
	H.equip_to_slot_or_del(new/obj/item/weapon/shovel(H), slot_back)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.add_note("Role", "You are a <b>[title]</b>, a former miner who decided to move into the New World to find riches. Explore the area, mine, and sell to the <b>Merchant</b> what you find!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/british/civilian/farmer
	title = "British Farmer"
	en_meaning = "Colony Farmer/Rancher"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN"
	SL_check_independent = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 3
	max_positions = 50

/datum/job/british/civilian/farmer/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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

	H.equip_to_slot_or_del(new/obj/item/weapon/storage/belt/leather/farmer(H), slot_belt)
	H.equip_to_slot_or_del(new/obj/item/weapon/plough(H), slot_l_hand)
	H.equip_to_slot_or_del(new/obj/item/weapon/material/kitchen/utensil/knife(H), slot_r_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, specialized in plant growth, animal husbandry, and cooking. Keep the colony fed!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_NORMAL)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE
/datum/job/british/civilian/carpenter
	title = "British Carpenter"
	en_meaning = "Colony Carpenter/Craftsman"
	rank_abbreviation = "Carpenter"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN"
	SL_check_independent = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 3
	max_positions = 50

/datum/job/british/civilian/carpenter/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_beret(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_beret(H), slot_head)
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
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)

	return TRUE

/datum/job/british/civilian/blacksmith
	title = "British Blacksmith"
	en_meaning = "Colony Blacksmith"
	rank_abbreviation = "Blacksmith"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN"
	SL_check_independent = TRUE
	is_RP = TRUE

	// AUTOBALANCE
	min_positions = 2
	max_positions = 10

/datum/job/british/civilian/blacksmith/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_beret(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_beret(H), slot_head)
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
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_VERY_LOW)
	H.setStat("medical", STAT_VERY_LOW)
	return TRUE

/datum/job/british/civilian/inkeeper
	title = "British Inkeeper"
	en_meaning = "Colony Innkeeper/Taverner"
	rank_abbreviation = "Innkeeper"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN"
	SL_check_independent = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 1
	max_positions = 2

/datum/job/british/civilian/inkeeper/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_beret(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_beret(H), slot_head)
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
	H.equip_to_slot_or_del(new/obj/item/weapon/key/civ/inn(H), slot_r_store)
	H.equip_to_slot_or_del(new/obj/item/weapon/material/knife/butcher(H), slot_belt)

	H.add_note("Role", "You are a <b>Inkeeper</b>. Your job is to build an Inn or Tavern to supply the Colonists with wine and food!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_NORMAL)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)

	return TRUE



/datum/job/british/civilian/worker
	title = "British Colonist"
	en_meaning = "Basic Colonist"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN"
	SL_check_independent = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 10
	max_positions = 150

/datum/job/british/civilian/worker/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_beret(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_beret(H), slot_head)
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
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)

	return TRUE

////////////////////////////////////////////SPANISH///////////////////////////////////////////////////////

/datum/job/spanish/civilian/governor
	title = "Gobernador"
	en_meaning = "Colony Leader"
	rank_abbreviation = "Gobernador"
	head_position = TRUE
	selection_color = "#2d2d63"
	spawn_location = "JoinLateSP"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	SL_check_independent = TRUE
	is_governor = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/spanish/civilian/governor/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/civ4(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/piratejacket5(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/powdered_wig(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/gov(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/hall(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
//	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.add_note("Role", "You are a <b>[title]</b>, the leader of this colony. Organize your men and build a village!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)

	return TRUE

/datum/job/spanish/civilian/architect
	title = "Arquitecto"
	en_meaning = "Colony Chief Carpenter/Planner"
	rank_abbreviation = "Arquitecto"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateSP"
	SL_check_independent = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_officer = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/spanish/civilian/architect/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
	H.equip_to_slot_or_del(new /obj/item/clothing/head/powdered_wig(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/hall(H), slot_l_hand)
	H.equip_to_slot_or_del(new/obj/item/weapon/storage/belt/leather(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_r_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are an <b>Architect</b>. Your job is to organize and lead the <b>Carpenters</b>, and develop the colony with your city planning skills!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)

	return TRUE

/datum/job/spanish/civilian/officer
	title = "Oficial de la Milicia"
	en_meaning = "Colony Security Leader"
	rank_abbreviation = "Oficial"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateSP"
	SL_check_independent = TRUE
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/spanish/civilian/officer/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/spanish_officer_army(H), slot_wear_suit)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/spanish_army(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)

	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/hall(H), slot_r_store)

	H.add_note("Role", "You are a <b>[title]</b>, a veteran of past wars. Your job is to organize the <b>Veterans</b> and keep the colonists safe, reporting to the <b>Governor</b>.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)

	return TRUE


/datum/job/spanish/civilian/veteran
	title = "Milicia"
	en_meaning = "Colony Security"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateSP"
	SL_check_independent = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 1
	max_positions = 30

/datum/job/spanish/civilian/veteran/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/spanish_officer_army(H), slot_wear_suit)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/bicorne_british_soldier(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)

	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/hall(H), slot_r_store)

	H.add_note("Role", "You are a <b>[title]</b>, a veteran of past wars. Your job is to organize the colony defense and hunting parties, according to the orders of the <b>Town Guard Officer</b>.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)

	return TRUE



/datum/job/spanish/civilian/medic
	title = "Curandero"
	en_meaning = "Colony Medic"
	rank_abbreviation = "Doctor"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateSP"
	SL_check_independent = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 1
	max_positions = 20

/datum/job/spanish/civilian/medic/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
	H.equip_to_slot_or_del(new /obj/item/clothing/head/powdered_wig(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/surgery(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, in charge of keeping the newly founded colony healthy.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_VERY_HIGH)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)

	return TRUE
/datum/job/spanish/civilian/merchant
	title = "Comerciante"
	en_meaning = "Colony Trader"
	rank_abbreviation = "Comerciante"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateSP"
	SL_check_independent = TRUE
	is_RP = TRUE
	is_merchant = TRUE
	// AUTOBALANCE
	min_positions = 1
	max_positions = 20

/datum/job/spanish/civilian/merchant/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
	H.equip_to_slot_or_del(new /obj/item/clothing/head/powdered_wig(H), slot_head)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, a trader who decided to move in to the new colony to get rich. Establish your trading post and deal with both the Natives and the Colonists!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_NORMAL)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE
/datum/job/spanish/civilian/priest
	title = "Cura"
	en_meaning = "Colony Priest"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateSP"
	SL_check_independent = TRUE
	is_RP = TRUE
	is_religious = TRUE
	// AUTOBALANCE
	min_positions = 1
	max_positions = 20

/datum/job/spanish/civilian/priest/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)

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
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_HIGH)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/spanish/civilian/prospector
	title = "Minero"
	en_meaning = "Colony Miner/Explorer"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateSP"
	SL_check_independent = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 3
	max_positions = 40

/datum/job/spanish/civilian/prospector/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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

	H.equip_to_slot_or_del(new/obj/item/weapon/pickaxe(H), slot_belt)
	H.equip_to_slot_or_del(new/obj/item/weapon/shovel(H), slot_back)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.add_note("Role", "You are a <b>[title]</b>, a former miner who decided to move into the New World to find riches. Explore the area, mine, and sell to the <b>Merchant</b> what you find!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/spanish/civilian/farmer
	title = "Granjero"
	en_meaning = "Colony Farmer/Rancher"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateSP"
	SL_check_independent = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 3
	max_positions = 50

/datum/job/spanish/civilian/farmer/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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

	H.equip_to_slot_or_del(new/obj/item/weapon/storage/belt/leather/farmer(H), slot_belt)
	H.equip_to_slot_or_del(new/obj/item/weapon/plough(H), slot_l_hand)
	H.equip_to_slot_or_del(new/obj/item/weapon/material/kitchen/utensil/knife(H), slot_r_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, specialized in plant growth, animal husbandry, and cooking. Keep the colony fed!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_NORMAL)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE
/datum/job/spanish/civilian/carpenter
	title = "Carpintero"
	en_meaning = "Colony Carpenter/Craftsman"
	rank_abbreviation = "Carpenter"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateSP"
	SL_check_independent = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 3
	max_positions = 50

/datum/job/spanish/civilian/carpenter/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_beret(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_beret(H), slot_head)
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
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)

	return TRUE
/datum/job/spanish/civilian/blacksmith
	title = "Ferrero"
	en_meaning = "Colony Blacksmith"
	rank_abbreviation = "Ferrero"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateSP"
	SL_check_independent = TRUE
	is_RP = TRUE

	// AUTOBALANCE
	min_positions = 2
	max_positions = 10

/datum/job/spanish/civilian/blacksmith/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_beret(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_beret(H), slot_head)
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
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_VERY_LOW)
	H.setStat("medical", STAT_VERY_LOW)
	return TRUE

/datum/job/spanish/civilian/inkeeper
	title = "Ventero"
	en_meaning = "Colony Innkeeper/Taverner"
	rank_abbreviation = "Ventero"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateSP"
	SL_check_independent = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 1
	max_positions = 2

/datum/job/spanish/civilian/inkeeper/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_beret(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_beret(H), slot_head)
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
	H.equip_to_slot_or_del(new/obj/item/weapon/key/civ/inn(H), slot_r_store)
	H.equip_to_slot_or_del(new/obj/item/weapon/material/knife/butcher(H), slot_belt)

	H.add_note("Role", "You are a <b>Inkeeper</b>. Your job is to build an Inn or Tavern to supply the Colonists with wine and food!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_NORMAL)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)

	return TRUE



/datum/job/spanish/civilian/worker
	title = "Colonista"
	en_meaning = "Basic Colonist"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateSP"
	SL_check_independent = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 10
	max_positions = 150

/datum/job/spanish/civilian/worker/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_beret(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_beret(H), slot_head)
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
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)

	return TRUE



////////////////////////////////////////////PORTUGUESE///////////////////////////////////////////////////////

/datum/job/portuguese/civilian/governor
	title = "Governador"
	en_meaning = "Colony Leader"
	rank_abbreviation = "Governador"
	head_position = TRUE
	selection_color = "#2d2d63"
	spawn_location = "JoinLatePT"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	SL_check_independent = TRUE
	is_governor = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/portuguese/civilian/governor/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/civ4(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/piratejacket5(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/powdered_wig(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/gov(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/hall(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
//	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.add_note("Role", "You are a <b>[title]</b>, the leader of this colony. Organize your men and build a village!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)

	return TRUE

/datum/job/portuguese/civilian/architect
	title = "Arquiteto"
	en_meaning = "Colony Chief Carpenter/Planner"
	rank_abbreviation = "Arquiteto"
	selection_color = "#2d2d63"
	spawn_location = "JoinLatePT"
	SL_check_independent = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_officer = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/portuguese/civilian/architect/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
	H.equip_to_slot_or_del(new /obj/item/clothing/head/powdered_wig(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/hall(H), slot_l_hand)
	H.equip_to_slot_or_del(new/obj/item/weapon/storage/belt/leather(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_r_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are an <b>Architect</b>. Your job is to organize and lead the <b>Carpenters</b>, and develop the colony with your city planning skills!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)

	return TRUE

/datum/job/portuguese/civilian/officer
	title = "Comandante da Milícia"
	en_meaning = "Colony Security Leader"
	rank_abbreviation = "Comandante"
	selection_color = "#2d2d63"
	spawn_location = "JoinLatePT"
	SL_check_independent = TRUE
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/portuguese/civilian/officer/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/portuguese_officer_army(H), slot_wear_suit)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/portuguese_army(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)

	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/hall(H), slot_r_store)

	H.add_note("Role", "You are a <b>[title]</b>, a veteran of past wars. Your job is to organize the <b>Veterans</b> and keep the colonists safe, reporting to the <b>Governor</b>.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)

	return TRUE


/datum/job/portuguese/civilian/veteran
	title = "Miliciano"
	en_meaning = "Colony Security"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLatePT"
	SL_check_independent = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 1
	max_positions = 30

/datum/job/portuguese/civilian/veteran/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/portuguese_officer_army(H), slot_wear_suit)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/bicorne_british_soldier(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)

	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/hall(H), slot_r_store)

	H.add_note("Role", "You are a <b>[title]</b>, a veteran of past wars. Your job is to organize the colony defense and hunting parties, according to the orders of the <b>Town Guard Officer</b>.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)

	return TRUE



/datum/job/portuguese/civilian/medic
	title = "Médico"
	en_meaning = "Colony Medic"
	rank_abbreviation = "Médico"
	selection_color = "#2d2d63"
	spawn_location = "JoinLatePT"
	SL_check_independent = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 1
	max_positions = 20

/datum/job/portuguese/civilian/medic/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
	H.equip_to_slot_or_del(new /obj/item/clothing/head/powdered_wig(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/surgery(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, in charge of keeping the newly founded colony healthy.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_VERY_HIGH)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)

	return TRUE
/datum/job/portuguese/civilian/merchant
	title = "Mercador"
	en_meaning = "Colony Trader"
	rank_abbreviation = "Mercador"
	selection_color = "#2d2d63"
	spawn_location = "JoinLatePT"
	SL_check_independent = TRUE
	is_RP = TRUE
	is_merchant = TRUE
	// AUTOBALANCE
	min_positions = 1
	max_positions = 20

/datum/job/portuguese/civilian/merchant/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
	H.equip_to_slot_or_del(new /obj/item/clothing/head/powdered_wig(H), slot_head)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, a trader who decided to move in to the new colony to get rich. Establish your trading post and deal with both the Natives and the Colonists!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_NORMAL)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE
/datum/job/portuguese/civilian/priest
	title = "Padre"
	en_meaning = "Colony Priest"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLatePT"
	SL_check_independent = TRUE
	is_religious = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 1
	max_positions = 20

/datum/job/portuguese/civilian/priest/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)

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
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_HIGH)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/portuguese/civilian/prospector
	title = "Mineiro"
	en_meaning = "Colony Miner/Explorer"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLatePT"
	SL_check_independent = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 3
	max_positions = 40

/datum/job/portuguese/civilian/prospector/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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

	H.equip_to_slot_or_del(new/obj/item/weapon/pickaxe(H), slot_belt)
	H.equip_to_slot_or_del(new/obj/item/weapon/shovel(H), slot_back)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.add_note("Role", "You are a <b>[title]</b>, a former miner who decided to move into the New World to find riches. Explore the area, mine, and sell to the <b>Merchant</b> what you find!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/portuguese/civilian/farmer
	title = "Fazendeiro"
	en_meaning = "Colony Farmer/Rancher"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLatePT"
	SL_check_independent = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 3
	max_positions = 50

/datum/job/portuguese/civilian/farmer/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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

	H.equip_to_slot_or_del(new/obj/item/weapon/storage/belt/leather/farmer(H), slot_belt)
	H.equip_to_slot_or_del(new/obj/item/weapon/plough(H), slot_l_hand)
	H.equip_to_slot_or_del(new/obj/item/weapon/material/kitchen/utensil/knife(H), slot_r_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, specialized in plant growth, animal husbandry, and cooking. Keep the colony fed!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_NORMAL)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE
/datum/job/portuguese/civilian/carpenter
	title = "Carpinteiro"
	en_meaning = "Colony Carpenter/Craftsman"
	rank_abbreviation = "Carpinteiro"
	selection_color = "#2d2d63"
	spawn_location = "JoinLatePT"
	SL_check_independent = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 3
	max_positions = 50

/datum/job/portuguese/civilian/carpenter/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_beret(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_beret(H), slot_head)
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
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)

	return TRUE

/datum/job/portuguese/civilian/blacksmith
	title = "Ferreiro"
	en_meaning = "Colony Blacksmith"
	rank_abbreviation = "Ferreiro"
	selection_color = "#2d2d63"
	spawn_location = "JoinLatePT"
	SL_check_independent = TRUE
	is_RP = TRUE

	// AUTOBALANCE
	min_positions = 2
	max_positions = 10

/datum/job/portuguese/civilian/blacksmith/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_beret(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_beret(H), slot_head)
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
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_VERY_LOW)
	H.setStat("medical", STAT_VERY_LOW)
	return TRUE

/datum/job/portuguese/civilian/inkeeper
	title = "Taberneiro"
	en_meaning = "Colony Innkeeper/Taverner"
	rank_abbreviation = "Taberneiro"
	selection_color = "#2d2d63"
	spawn_location = "JoinLatePT"
	SL_check_independent = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 1
	max_positions = 2

/datum/job/portuguese/civilian/inkeeper/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_beret(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_beret(H), slot_head)
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
	H.equip_to_slot_or_del(new/obj/item/weapon/key/civ/inn(H), slot_r_store)
	H.equip_to_slot_or_del(new/obj/item/weapon/material/knife/butcher(H), slot_belt)

	H.add_note("Role", "You are a <b>Inkeeper</b>. Your job is to build an Inn or Tavern to supply the Colonists with wine and food!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_NORMAL)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)

	return TRUE



/datum/job/portuguese/civilian/worker
	title = "Colono"
	en_meaning = "Basic Colonist"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLatePT"
	SL_check_independent = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 10
	max_positions = 150

/datum/job/portuguese/civilian/worker/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_beret(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_beret(H), slot_head)
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
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)

	return TRUE


////////////////////////////////////////////FRENCH///////////////////////////////////////////////////////

/datum/job/french/civilian/governor
	title = "Governeur"
	en_meaning = "Colony Leader"
	rank_abbreviation = "Governeur"
	head_position = TRUE
	selection_color = "#2d2d63"
	spawn_location = "JoinLatePirate"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	SL_check_independent = TRUE
	is_governor = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/french/civilian/governor/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/civ4(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/piratejacket5(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/powdered_wig(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/gov(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/hall(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)
//	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.add_note("Role", "You are a <b>[title]</b>, the leader of this colony. Organize your men and build a village!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)

	return TRUE

/datum/job/french/civilian/architect
	title = "Architecte"
	en_meaning = "Colony Chief Carpenter/Planner"
	rank_abbreviation = "Architecte"
	selection_color = "#2d2d63"
	spawn_location = "JoinLatePirate"
	SL_check_independent = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_officer = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/french/civilian/architect/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
	H.equip_to_slot_or_del(new /obj/item/clothing/head/powdered_wig(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/hall(H), slot_l_hand)
	H.equip_to_slot_or_del(new/obj/item/weapon/storage/belt/leather(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_r_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are an <b>Architect</b>. Your job is to organize and lead the <b>Carpenters</b>, and develop the colony with your city planning skills!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)

	return TRUE

/datum/job/french/civilian/officer
	title = "Officier de la Garde"
	en_meaning = "Colony Security Leader"
	rank_abbreviation = "Officier"
	selection_color = "#2d2d63"
	spawn_location = "JoinLatePirate"
	SL_check_independent = TRUE
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/french/civilian/officer/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/french_officer_army(H), slot_wear_suit)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/french_army(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)

	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/hall(H), slot_r_store)

	H.add_note("Role", "You are a <b>[title]</b>, a veteran of past wars. Your job is to organize the <b>Veterans</b> and keep the colonists safe, reporting to the <b>Governor</b>.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)

	return TRUE


/datum/job/french/civilian/veteran
	title = "Garde"
	en_meaning = "Colony Security"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLatePirate"
	SL_check_independent = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 1
	max_positions = 30

/datum/job/french/civilian/veteran/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/civ2(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/french_officer_army(H), slot_wear_suit)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/bicorne_british_soldier(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/spadroon(H), slot_belt)

	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/hall(H), slot_r_store)

	H.add_note("Role", "You are a <b>[title]</b>, a veteran of past wars. Your job is to organize the colony defense and hunting parties, according to the orders of the <b>Town Guard Officer</b>.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)

	return TRUE



/datum/job/french/civilian/medic
	title = "Docteur"
	en_meaning = "Colony Medic"
	rank_abbreviation = "Docteur"
	selection_color = "#2d2d63"
	spawn_location = "JoinLatePirate"
	SL_check_independent = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 1
	max_positions = 20

/datum/job/french/civilian/medic/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
	H.equip_to_slot_or_del(new /obj/item/clothing/head/powdered_wig(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/surgery(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, in charge of keeping the newly founded colony healthy.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_VERY_HIGH)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)

	return TRUE
/datum/job/french/civilian/merchant
	title = "Marchand"
	en_meaning = "Colony Trader"
	rank_abbreviation = "Marchand"
	selection_color = "#2d2d63"
	spawn_location = "JoinLatePirate"
	SL_check_independent = TRUE
	is_merchant = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 1
	max_positions = 20

/datum/job/french/civilian/merchant/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
	H.equip_to_slot_or_del(new /obj/item/clothing/head/powdered_wig(H), slot_head)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, a trader who decided to move in to the new colony to get rich. Establish your trading post and deal with both the Natives and the Colonists!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_NORMAL)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE
/datum/job/french/civilian/priest
	title = "Prêtre"
	en_meaning = "Colony Priest"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLatePirate"
	SL_check_independent = TRUE
	is_RP = TRUE
	is_religious = TRUE
	// AUTOBALANCE
	min_positions = 1
	max_positions = 20

/datum/job/french/civilian/priest/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)

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
	H.setStat("strength", STAT_MEDIUM_LOW)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_HIGH)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/french/civilian/prospector
	title = "Mineur"
	en_meaning = "Colony Miner/Explorer"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLatePirate"
	SL_check_independent = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 3
	max_positions = 40

/datum/job/french/civilian/prospector/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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

	H.equip_to_slot_or_del(new/obj/item/weapon/pickaxe(H), slot_belt)
	H.equip_to_slot_or_del(new/obj/item/weapon/shovel(H), slot_back)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)
	H.add_note("Role", "You are a <b>[title]</b>, a former miner who decided to move into the New World to find riches. Explore the area, mine, and sell to the <b>Merchant</b> what you find!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE

/datum/job/french/civilian/farmer
	title = "Fermier"
	en_meaning = "Colony Farmer/Rancher"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLatePirate"
	SL_check_independent = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 3
	max_positions = 50

/datum/job/french/civilian/farmer/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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

	H.equip_to_slot_or_del(new/obj/item/weapon/storage/belt/leather/farmer(H), slot_belt)
	H.equip_to_slot_or_del(new/obj/item/weapon/plough(H), slot_l_hand)
	H.equip_to_slot_or_del(new/obj/item/weapon/material/kitchen/utensil/knife(H), slot_r_store)
	H.equip_to_slot_or_del(new/obj/item/stack/money/real(H), slot_l_store)

	H.add_note("Role", "You are a <b>[title]</b>, specialized in plant growth, animal husbandry, and cooking. Keep the colony fed!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_NORMAL)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)
	return TRUE
/datum/job/french/civilian/carpenter
	title = "Charpentier"
	en_meaning = "Colony Carpenter/Craftsman"
	rank_abbreviation = "Charpentier"
	selection_color = "#2d2d63"
	spawn_location = "JoinLatePirate"
	SL_check_independent = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 3
	max_positions = 50

/datum/job/french/civilian/carpenter/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_beret(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_beret(H), slot_head)
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
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)

	return TRUE

/datum/job/french/civilian/blacksmith
	title = "Forgeron"
	en_meaning = "Colony Blacksmith"
	rank_abbreviation = "Forgeron"
	selection_color = "#2d2d63"
	spawn_location = "JoinLatePirate"
	SL_check_independent = TRUE
	is_RP = TRUE

	// AUTOBALANCE
	min_positions = 2
	max_positions = 10

/datum/job/french/civilian/blacksmith/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_beret(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_beret(H), slot_head)
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
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_VERY_LOW)
	H.setStat("medical", STAT_VERY_LOW)
	return TRUE

/datum/job/french/civilian/inkeeper
	title = "Aubergiste"
	en_meaning = "Colony Innkeeper/Taverner"
	rank_abbreviation = "Aubergiste"
	selection_color = "#2d2d63"
	spawn_location = "JoinLatePirate"
	SL_check_independent = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 1
	max_positions = 2

/datum/job/french/civilian/inkeeper/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_beret(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_beret(H), slot_head)
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
	H.equip_to_slot_or_del(new/obj/item/weapon/key/civ/inn(H), slot_r_store)
	H.equip_to_slot_or_del(new/obj/item/weapon/material/knife/butcher(H), slot_belt)

	H.add_note("Role", "You are a <b>Inkeeper</b>. Your job is to build an Inn or Tavern to supply the Colonists with wine and food!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_NORMAL)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)

	return TRUE



/datum/job/french/civilian/worker
	title = "Coloniste"
	en_meaning = "Basic Colonist"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLatePirate"
	SL_check_independent = TRUE
	is_RP = TRUE
	// AUTOBALANCE
	min_positions = 10
	max_positions = 150

/datum/job/french/civilian/worker/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE

//shoes
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
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
			H.equip_to_slot_or_del(new /obj/item/clothing/head/blue_beret(H), slot_head)
		else if (randhead == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_beret(H), slot_head)
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
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.equip_to_slot_or_del(new /obj/item/clothing/accessory/storage/coinpouch(H),  slot_wear_id)

	return TRUE

