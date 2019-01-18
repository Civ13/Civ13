/datum/job/civilian/sheriff
	title = "Sheriff"
	rank_abbreviation = "Sheriff"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN"
	head_position = TRUE
	is_commander = TRUE
	is_officer = TRUE
	whitelisted = TRUE
	SL_check_independent = TRUE
	is_cowboy = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1

/datum/job/civilian/sheriff/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding2(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial3(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/cowboyhat(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/sheriff(H), slot_r_store)

	if (prob(60))
		var/randscarf = pick(1,2,3)
		if (randscarf == 1)
			var/obj/item/clothing/accessory/armband/blue_scarf/scarf_a = new /obj/item/clothing/accessory/armband/blue_scarf(null)
			var/obj/item/clothing/under/uniform = H.w_uniform
			uniform.attackby(scarf_a, H)

		else if (randscarf == 2)
			var/obj/item/clothing/accessory/armband/red_scarf/scarf_a = new /obj/item/clothing/accessory/armband/red_scarf(null)
			var/obj/item/clothing/under/uniform = H.w_uniform
			uniform.attackby(scarf_a, H)
		else if (randscarf == 3)
			var/obj/item/clothing/accessory/armband/grey_scarf/scarf_a = new /obj/item/clothing/accessory/armband/grey_scarf(null)
			var/obj/item/clothing/under/uniform = H.w_uniform
			uniform.attackby(scarf_a, H)

	var/obj/item/clothing/accessory/armband/sheriff/sheriff_a = new /obj/item/clothing/accessory/armband/sheriff(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(sheriff_a, H)
	var/obj/item/clothing/accessory/holster/hip/double/holsterh = new /obj/item/clothing/accessory/holster/hip/double(null)
	uniform.attackby(holsterh, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/peacemaker(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/peacemaker(H), slot_r_hand)

	H.add_note("Role", "You are the <b>[title]</b>, responsible for keeping the law and order in Little Creek. Organize your <b>Deputies</b> and prevent the <b>Outlaws</b> from robbing the bank!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)

	return TRUE

/datum/job/civilian/deputy
	title = "Deputy"
	rank_abbreviation = "Dep."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN"
	SL_check_independent = TRUE
	is_cowboy = TRUE

	// AUTOBALANCE
	min_positions = 6
	max_positions = 40

/datum/job/civilian/deputy/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding2(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial3(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/cowboyhat(H), slot_head)
	if (prob(60))
		var/randscarf = pick(1,2,3)
		if (randscarf == 1)
			var/obj/item/clothing/accessory/armband/blue_scarf/scarf_a = new /obj/item/clothing/accessory/armband/blue_scarf(null)
			var/obj/item/clothing/under/uniform = H.w_uniform
			uniform.attackby(scarf_a, H)

		else if (randscarf == 2)
			var/obj/item/clothing/accessory/armband/red_scarf/scarf_a = new /obj/item/clothing/accessory/armband/red_scarf(null)
			var/obj/item/clothing/under/uniform = H.w_uniform
			uniform.attackby(scarf_a, H)
		else if (randscarf == 3)
			var/obj/item/clothing/accessory/armband/grey_scarf/scarf_a = new /obj/item/clothing/accessory/armband/grey_scarf(null)
			var/obj/item/clothing/under/uniform = H.w_uniform
			uniform.attackby(scarf_a, H)

	var/obj/item/clothing/accessory/armband/deputy/deputy_a = new /obj/item/clothing/accessory/armband/deputy(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(deputy_a, H)
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/peacemaker(H), slot_r_store)

	H.add_note("Role", "You are a <b>[title]</b>, a subordinate of the <b>Sheriff</b>. Follow his orders and prevent the <b>Outlaws</b> from robbing the bank!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)

	return TRUE
/*
/datum/job/civilian/bank
	title = "Bank Worker"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLatePT"
	whitelisted = TRUE
	SL_check_independent = TRUE
	is_cowboy = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 4

/datum/job/civilian/bank/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leather(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial5(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/bowler_hat(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/key/civ/bank(H), slot_r_store)

	var/obj/item/clothing/accessory/armband/british/red_a = new /obj/item/clothing/accessory/armband/british(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(red_a, H)
	H.add_note("Role", "You are a <b>[title]</b>, a functionary of <b>Little Creek Banking Co.</b>. Your job is to keep the bank's vault safe, so work with the <b>Sheriff</b> and his <b>Deputies</b>!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)

	return TRUE

/datum/job/civilian/townsmen
	title = "Townsmen"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateCiv"
	SL_check_independent = TRUE
	is_cowboy = TRUE

	// AUTOBALANCE
	min_positions = 3
	max_positions = 30

/datum/job/civilian/townsmen/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding2(H), slot_shoes)
//clothes
	var/randcloth = rand(1,5)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial2(H), slot_w_uniform)
	else if (randcloth == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial4(H), slot_w_uniform)
	else if (randcloth == 5)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial5(H), slot_w_uniform)

//jacket
	var/randcloth2 = rand(1,5)
	if (randcloth2 == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/leatherovercoat1(H), slot_wear_suit)
	else if (randcloth2 == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/leatherovercoat2(H), slot_wear_suit)
	else if (randcloth2 == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/bluevest(H), slot_wear_suit)
	else if (randcloth2 == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/olivevest(H), slot_wear_suit)
	else if (randcloth2 == 5)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/blackvest(H), slot_wear_suit)

//head
	var/randcloth3 = rand(1,3)
	if (randcloth3 == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/cowboyhat(H), slot_head)
	else if (randcloth3 == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/tarred_hat(H), slot_head)
	else if (randcloth3 == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/strawhat(H), slot_head)
	if (prob(60))
		var/randscarf = pick(1,2,3)
		if (randscarf == 1)
			var/obj/item/clothing/accessory/armband/blue_scarf/scarf_a = new /obj/item/clothing/accessory/armband/blue_scarf(null)
			var/obj/item/clothing/under/uniform = H.w_uniform
			uniform.attackby(scarf_a, H)

		else if (randscarf == 2)
			var/obj/item/clothing/accessory/armband/red_scarf/scarf_a = new /obj/item/clothing/accessory/armband/red_scarf(null)
			var/obj/item/clothing/under/uniform = H.w_uniform
			uniform.attackby(scarf_a, H)
		else if (randscarf == 3)
			var/obj/item/clothing/accessory/armband/grey_scarf/scarf_a = new /obj/item/clothing/accessory/armband/grey_scarf(null)
			var/obj/item/clothing/under/uniform = H.w_uniform
			uniform.attackby(scarf_a, H)
	H.add_note("Role", "You are a <b>[title]</b>, living in Little Creek. You've heard of the robbery, and your job is to survive!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_HIGH)

	return TRUE
*/
/datum/job/civilian/outlaw
	title = "Outlaw"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLatePirate"
	SL_check_independent = TRUE
	is_cowboy = TRUE
	whitelisted = TRUE
	// AUTOBALANCE
	min_positions = 6
	max_positions = 40

/datum/job/civilian/outlaw/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding2(H), slot_shoes)
//clothes
	var/randcloth = rand(1,5)
	if (randcloth == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial1(H), slot_w_uniform)
	else if (randcloth == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial2(H), slot_w_uniform)
	else if (randcloth == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial2(H), slot_w_uniform)
	else if (randcloth == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial4(H), slot_w_uniform)
	else if (randcloth == 5)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial5(H), slot_w_uniform)

//head
	var/randcloth3 = rand(1,3)
	if (randcloth3 == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/cowboyhat(H), slot_head)
	else if (randcloth3 == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/cowboyhat2(H), slot_head)
	else if (randcloth3 == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/bowler_hat(H), slot_head)

//jacket
	var/randcloth2 = rand(1,5)
	if (randcloth2 == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/leatherovercoat1(H), slot_wear_suit)
	else if (randcloth2 == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/leatherovercoat2(H), slot_wear_suit)
	else if (randcloth2 == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/bluevest(H), slot_wear_suit)
	else if (randcloth2 == 4)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/olivevest(H), slot_wear_suit)
	else if (randcloth2 == 5)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/blackvest(H), slot_wear_suit)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	if (prob(60))
		var/randscarf = pick(1,2,3)
		if (randscarf == 1)
			var/obj/item/clothing/accessory/armband/blue_scarf/scarf_a = new /obj/item/clothing/accessory/armband/blue_scarf(null)
			uniform.attackby(scarf_a, H)

		else if (randscarf == 2)
			var/obj/item/clothing/accessory/armband/red_scarf/scarf_a = new /obj/item/clothing/accessory/armband/red_scarf(null)
			uniform.attackby(scarf_a, H)
		else if (randscarf == 3)
			var/obj/item/clothing/accessory/armband/grey_scarf/scarf_a = new /obj/item/clothing/accessory/armband/grey_scarf(null)
			uniform.attackby(scarf_a, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/peacemaker(H), slot_r_store)
	H.add_note("Role", "You are a <b>[title]</b>. Find your partners in crime and organize the bank robbery! Get the gold from the Bank's vault and bring it back to the starting position, placing it into the stagecoach storage.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)

	return TRUE