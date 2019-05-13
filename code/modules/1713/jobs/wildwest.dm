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
	min_positions = 3
	max_positions = 16

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
	H.equip_to_slot_or_del(new /obj/item/weapon/handcuffs(H), slot_l_store)

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

/datum/job/civilian/deputy2
	title = "Sheriffs Deputy"
	rank_abbreviation = "Dep."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRN"
	SL_check_independent = TRUE
	is_cowboy = TRUE

	// AUTOBALANCE
	min_positions = 6
	max_positions = 100

/datum/job/civilian/deputy2/equip(var/mob/living/carbon/human/H)
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

/datum/job/civilian/bank
	title = "Bank Worker"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLatePT"
	SL_check_independent = TRUE
	is_cowboy = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 6

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
	min_positions = 8
	max_positions = 100

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
	if (prob(80))
		var/randcloth4 = rand(1,2)
		if (randcloth4 == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/mask/shemagh/greykerchief(H), slot_wear_mask)
		else if (randcloth4 == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/mask/shemagh/redkerchief(H), slot_wear_mask)
	if (prob(50))
		if (prob(50))
			var/obj/item/clothing/accessory/armband/suspenders1/red_a = new /obj/item/clothing/accessory/armband/suspenders1(null)
			var/obj/item/clothing/under/uniform = H.w_uniform
			uniform.attackby(red_a, H)
		else
			var/obj/item/clothing/accessory/armband/suspenders2/red_a = new /obj/item/clothing/accessory/armband/suspenders2(null)
			var/obj/item/clothing/under/uniform = H.w_uniform
			uniform.attackby(red_a, H)
	H.add_note("Role", "You are a <b>[title]</b>, living in Little Creek. You've heard of the robbery, and your job is to survive!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_NORMAL)

	return TRUE

/datum/job/civilian/towndoctor
	title = "Town Doctor"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateCiv"
	SL_check_independent = TRUE
	is_cowboy = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 4

/datum/job/civilian/towndoctor/equip(var/mob/living/carbon/human/H)
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
	H.equip_to_slot_or_del(new /obj/item/clothing/head/bowler_hat(H), slot_head)

//jacket
	var/randcloth2 = rand(1,3)
	if (randcloth2 == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/bluevest(H), slot_wear_suit)
	else if (randcloth2 == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/olivevest(H), slot_wear_suit)
	else if (randcloth2 == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/blackvest(H), slot_wear_suit)
	if (prob(50))
		var/obj/item/clothing/accessory/armband/suspenders1/red_a = new /obj/item/clothing/accessory/armband/suspenders1(null)
		var/obj/item/clothing/under/uniform = H.w_uniform
		uniform.attackby(red_a, H)
	else
		var/obj/item/clothing/accessory/armband/suspenders2/red_a = new /obj/item/clothing/accessory/armband/suspenders2(null)
		var/obj/item/clothing/under/uniform = H.w_uniform
		uniform.attackby(red_a, H)
	H.add_note("Role", "You are the <b>Town's Doctor</b>, living in Little Creek. Take care of the (many) wounded...")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_VERY_HIGH)

	return TRUE

/datum/job/civilian/townbartender
	title = "Town Bartender"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateCiv"
	SL_check_independent = TRUE
	is_cowboy = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 3

/datum/job/civilian/townbartender/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)

	H.equip_to_slot_or_del(new /obj/item/clothing/under/bartender(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/bowler_hat(H), slot_head)

	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/derringer(H), slot_l_store)
	H.add_note("Role", "You are the <b>Saloon's Bartender</b>, living in Little Creek. Take care of the Saloon, shooting the drunkards out if need be.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)

	return TRUE

/datum/job/civilian/townrancher
	title = "Town Rancher"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateCiv"
	SL_check_independent = TRUE
	is_cowboy = TRUE

	// AUTOBALANCE
	min_positions = 2
	max_positions = 8

/datum/job/civilian/townrancher/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/riding2(H), slot_shoes)
	var/randcloth2 = rand(1,2)
	if (randcloth2 == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial2(H), slot_w_uniform)
	else if (randcloth2 == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial4(H), slot_w_uniform)

//head
	var/randcloth3 = rand(1,2)
	if (randcloth3 == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/cowboyhat(H), slot_head)
	else if (randcloth3 == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/cowboyhat2(H), slot_head)
	var/randcloth4 = rand(1,2)
	if (randcloth4 == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/mask/shemagh/greykerchief(H), slot_wear_mask)
	else if (randcloth4 == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/mask/shemagh/redkerchief(H), slot_wear_mask)
	if (prob(50))
		var/obj/item/clothing/accessory/armband/suspenders1/red_a = new /obj/item/clothing/accessory/armband/suspenders1(null)
		var/obj/item/clothing/under/uniform = H.w_uniform
		uniform.attackby(red_a, H)
	else
		var/obj/item/clothing/accessory/armband/suspenders2/red_a = new /obj/item/clothing/accessory/armband/suspenders2(null)
		var/obj/item/clothing/under/uniform = H.w_uniform
		uniform.attackby(red_a, H)
	H.equip_to_slot_or_del(new/obj/item/weapon/storage/belt/leather/farmer(H), slot_belt)
	H.equip_to_slot_or_del(new/obj/item/weapon/plough(H), slot_l_hand)
	H.equip_to_slot_or_del(new/obj/item/weapon/material/kitchen/utensil/knife(H), slot_r_store)
	H.add_note("Role", "You are a <b>Rancher</b>, living in Little Creek. Take care of your farm and keep the town fed!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)

	return TRUE

/datum/job/civilian/townprospector
	title = "Town Prospector"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateCiv"
	SL_check_independent = TRUE
	is_cowboy = TRUE

	// AUTOBALANCE
	min_positions = 2
	max_positions = 8

/datum/job/civilian/townprospector/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)

	H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial1(H), slot_w_uniform)
//head
	var/randcloth3 = rand(1,2)
	if (randcloth3 == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/cowboyhat(H), slot_head)
	else if (randcloth3 == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/cowboyhat2(H), slot_head)
	var/randcloth4 = rand(1,2)
	if (randcloth4 == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/mask/shemagh/greykerchief(H), slot_wear_mask)
	else if (randcloth4 == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/mask/shemagh/redkerchief(H), slot_wear_mask)
	if (prob(50))
		var/obj/item/clothing/accessory/armband/suspenders1/red_a = new /obj/item/clothing/accessory/armband/suspenders1(null)
		var/obj/item/clothing/under/uniform = H.w_uniform
		uniform.attackby(red_a, H)
	else
		var/obj/item/clothing/accessory/armband/suspenders2/red_a = new /obj/item/clothing/accessory/armband/suspenders2(null)
		var/obj/item/clothing/under/uniform = H.w_uniform
		uniform.attackby(red_a, H)
	H.equip_to_slot_or_del(new/obj/item/weapon/pickaxe(H), slot_belt)
	H.equip_to_slot_or_del(new/obj/item/weapon/shovel(H), slot_back)
	H.add_note("Role", "You are a <b>Prospector</b>, living in Little Creek. Mine and keep the town supplied with raw materials.")
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)

	return TRUE

/datum/job/civilian/townpriest
	title = "Town Priest"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateCiv"
	SL_check_independent = TRUE
	is_cowboy = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 2

/datum/job/civilian/townpriest/equip(var/mob/living/carbon/human/H)
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
	H.add_note("Role", "You are the <b>Priest</b>, living in Little Creek. Take care of the church, act as undertaker, and make sure the population follows the Lord's commandments.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_HIGH)

	return TRUE

/datum/job/civilian/townblacksmith
	title = "Town Blacksmith"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateCiv"
	SL_check_independent = TRUE
	is_cowboy = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 2

/datum/job/civilian/townblacksmith/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots1(H), slot_shoes)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots1(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial5(H), slot_w_uniform)

//head
	var/randcloth3 = rand(1,3)
	if (randcloth3 == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/cowboyhat(H), slot_head)
	else if (randcloth3 == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/cowboyhat2(H), slot_head)
	else if (randcloth3 == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/bowler_hat(H), slot_head)
	var/randcloth4 = rand(1,2)
	if (randcloth4 == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/mask/shemagh/greykerchief(H), slot_wear_mask)
	else if (randcloth4 == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/mask/shemagh/redkerchief(H), slot_wear_mask)
	if (prob(50))
		if (prob(50))
			var/obj/item/clothing/accessory/armband/suspenders1/red_a = new /obj/item/clothing/accessory/armband/suspenders1(null)
			var/obj/item/clothing/under/uniform = H.w_uniform
			uniform.attackby(red_a, H)
		else
			var/obj/item/clothing/accessory/armband/suspenders2/red_a = new /obj/item/clothing/accessory/armband/suspenders2(null)
			var/obj/item/clothing/under/uniform = H.w_uniform
			uniform.attackby(red_a, H)
	H.add_note("Role", "You are the <b>Town's Blacksmith</b>, living in Little Creek. Take care of the blacksmith and the stables!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", 200)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)

	return TRUE

////////////////////////////////////OUTLAWS////////////////////////////////
/datum/job/civilian/outlaw
	title = "Outlaw"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLatePirate"
	SL_check_independent = TRUE
	is_cowboy = TRUE
	// AUTOBALANCE
	min_positions = 6
	max_positions = 100

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
	if (prob(80))
		var/randcloth4 = rand(1,2)
		if (randcloth4 == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/mask/shemagh/greykerchief(H), slot_wear_mask)
		else if (randcloth4 == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/mask/shemagh/redkerchief(H), slot_wear_mask)
	if (prob(50))
		if (prob(50))
			var/obj/item/clothing/accessory/armband/suspenders1/red_a = new /obj/item/clothing/accessory/armband/suspenders1(null)
			var/obj/item/clothing/under/uniform = H.w_uniform
			uniform.attackby(red_a, H)
		else
			var/obj/item/clothing/accessory/armband/suspenders2/red_a = new /obj/item/clothing/accessory/armband/suspenders2(null)
			var/obj/item/clothing/under/uniform = H.w_uniform
			uniform.attackby(red_a, H)
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

/datum/job/civilian/outlaw1
	title = "West Side Gang"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateCiv"
	SL_check_independent = TRUE
	is_cowboy = TRUE
	// AUTOBALANCE
	min_positions = 2
	max_positions = 9

/datum/job/civilian/outlaw1/equip(var/mob/living/carbon/human/H)
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
	if (prob(80))
		var/randcloth4 = rand(1,2)
		if (randcloth4 == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/mask/shemagh/greykerchief(H), slot_wear_mask)
		else if (randcloth4 == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/mask/shemagh/redkerchief(H), slot_wear_mask)
	if (prob(50))
		if (prob(50))
			var/obj/item/clothing/accessory/armband/suspenders1/red_a = new /obj/item/clothing/accessory/armband/suspenders1(null)
			var/obj/item/clothing/under/uniform = H.w_uniform
			uniform.attackby(red_a, H)
		else
			var/obj/item/clothing/accessory/armband/suspenders2/red_a = new /obj/item/clothing/accessory/armband/suspenders2(null)
			var/obj/item/clothing/under/uniform = H.w_uniform
			uniform.attackby(red_a, H)
	if (prob(20))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/peacemaker(H), slot_r_store)
	H.add_note("Role", "You are a <b>[title]</b> member. Find your partners in crime and organize the bank robbery! Get the gold from the Bank's vault and bring it to the North stagecoach storage!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)

	return TRUE

/datum/job/civilian/outlaw2
	title = "East Side Gang"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateCiv"
	SL_check_independent = TRUE
	is_cowboy = TRUE
	// AUTOBALANCE
	min_positions = 2
	max_positions = 9

/datum/job/civilian/outlaw2/equip(var/mob/living/carbon/human/H)
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
	if (prob(80))
		var/randcloth4 = rand(1,2)
		if (randcloth4 == 1)
			H.equip_to_slot_or_del(new /obj/item/clothing/mask/shemagh/greykerchief(H), slot_wear_mask)
		else if (randcloth4 == 2)
			H.equip_to_slot_or_del(new /obj/item/clothing/mask/shemagh/redkerchief(H), slot_wear_mask)
	if (prob(50))
		if (prob(50))
			var/obj/item/clothing/accessory/armband/suspenders1/red_a = new /obj/item/clothing/accessory/armband/suspenders1(null)
			var/obj/item/clothing/under/uniform = H.w_uniform
			uniform.attackby(red_a, H)
		else
			var/obj/item/clothing/accessory/armband/suspenders2/red_a = new /obj/item/clothing/accessory/armband/suspenders2(null)
			var/obj/item/clothing/under/uniform = H.w_uniform
			uniform.attackby(red_a, H)
	if (prob(20))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/peacemaker(H), slot_r_store)
	H.add_note("Role", "You are a <b>[title]</b> member. Find your partners in crime and organize the bank robbery! Get the gold from the Bank's vault and bring it to the North stagecoach storage!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)

	return TRUE