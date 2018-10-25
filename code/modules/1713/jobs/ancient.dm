////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////ROMAN///////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////
/datum/job/roman
	faction = "Station"

/datum/job/roman/give_random_name(var/mob/living/carbon/human/H)
	H.name = H.species.get_random_roman_name()
	H.real_name = H.name

/datum/job/roman/captain	//Roman - Centurion
	title = "Centurion"
	en_meaning = "Roman Commander"
	rank_abbreviation = "Cen."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRO"
	SL_check_independent = TRUE
	is_commander = TRUE
	head_position = TRUE
	is_officer = TRUE
	// Autobalance
	min_positions = 1
	max_positions = 1

/datum/job/roman/captain/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/roman(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/roman_centurion(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/cape(H), slot_wear_suit)
		//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/roman_centurion(H), slot_head)
		//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/gladius(H), slot_belt)
	H.add_note("Role", "You are a <b>[title]</b>, the leader of a <b>Centuria</b>, a company of Legionaries. Organize your <b>Decurions</b> and lead your soldiers to victory!</b>.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE



/datum/job/roman/squad_leader	//Roman - Decurion
	title = "Decurion"
	en_meaning = "Roman Squad Leader"
	rank_abbreviation = "Dec."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRO"
	SL_check_independent = TRUE
	is_officer = TRUE

	// Autobalance
	min_positions = 2
	max_positions = 10

/datum/job/roman/squad_leader/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/roman(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/roman(H), slot_w_uniform)
		//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/roman_decurion(H), slot_head)
		//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/gladius(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/pilum(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/roman(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/pilum(H), slot_r_hand)
	H.add_note("Role", "You are a <b>[title]</b>, the leader of a Roman legionary squad. Lead your <b>Legionaries</b> to battle, following the orders of the <b>Centurion</b>!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)

/datum/job/roman/bearer
	title = "Signifer"
	en_meaning = "Roman Standard Bearer"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRO"
	SL_check_independent = TRUE
	// AUTOBALANCE
	min_positions = 1
	max_positions = 6

/datum/job/roman/bearer/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/roman(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/roman(H), slot_w_uniform)
		//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/bearpelt(H), slot_head)
		//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/gladius(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/roman_buckler(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/horn(H), slot_r_store)
	H.add_note("Role", "You are a <b>[title]</b>, the Legion's standard bearer. Lead your soldiers to battle and keep troops organized! Use your horn!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
/datum/job/roman/soldier
	title = "Legionarius"
	en_meaning = "Main Infantry"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRO"
	SL_check_independent = TRUE
	// AUTOBALANCE
	min_positions = 12
	max_positions = 200

/datum/job/roman/soldier/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/roman(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/roman(H), slot_w_uniform)
		//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/roman(H), slot_head)
		//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/gladius(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/pilum(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/roman(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/pilum(H), slot_r_hand)
	H.add_note("Role", "You are a <b>[title]</b>, a soldier of the Roman Army. You are equipped with two <b>Pila</b> javelins, your shield and a <b>Gladius</b>.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE



/datum/job/roman/velites
	title = "Saggitarius"
	en_meaning = "Light Archer"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRO"
	SL_check_independent = TRUE
	// AUTOBALANCE
	min_positions = 8
	max_positions = 100
/datum/job/roman/velites/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/roman(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/roman(H), slot_w_uniform)
		//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/wolfpelt(H), slot_head)
		//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/pilum(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/roman_buckler(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/bow(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/quiver/full(H), slot_back)
	H.add_note("Role", "You are a <b>[title]</b>, a skirmisher in the Roman Army. Your job is to harass the enemy frontline before the <b>Legionaries</b> charge.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_HIGH)
	H.setStat("medical", STAT_MEDIUM_LOW)
////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////GREEK///////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////
/datum/job/greek
	faction = "Station"

/datum/job/greek/give_random_name(var/mob/living/carbon/human/H)
	H.name = H.species.get_random_greek_name()
	H.real_name = H.name


/datum/job/greek/captain	//Greek Strategus
	title = "Lochagos"
	en_meaning = "Greek Commander"
	rank_abbreviation = "Lo."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateGR"
	SL_check_independent = TRUE
	is_commander = TRUE
	head_position = TRUE
	is_officer = TRUE
	// Autobalance
	min_positions = 1
	max_positions = 1

/datum/job/greek/captain/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/roman(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/greek_commander(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/cape/blue(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/greek_commander(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/xiphos(H), slot_belt)
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

/datum/job/greek/squad_leader	//Greek - Phalanx
	title = "Dimoerites"
	en_meaning = "Greek Squad Leader"
	rank_abbreviation = "Di."
	selection_color = "#2d2d63"
	spawn_location = "JoinLateGR"
	SL_check_independent = TRUE
	is_officer = TRUE
	// Autobalance
	min_positions = 2
	max_positions = 10

/datum/job/greek/squad_leader/equip(var/mob/living/carbon/human/H)
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
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/greek_sl(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/xiphos(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/spear/dory(H), slot_r_hand)
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

/datum/job/greek/soldier
	title = "Hoplites"
	en_meaning = "Greek Spear Infantry"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateGR"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 12
	max_positions = 200

/datum/job/greek/soldier/equip(var/mob/living/carbon/human/H)
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
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/greek(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/xiphos(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/aspis(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/spear/sarissa(H), slot_r_hand)
	H.add_note("Role", "You are a <b>[title]</b>, a soldier from the city-state of Athens. You have your <b>Sarissa</b> spear, your round <b>Aspis</b> shield and your <b>Xiphos</b> sword.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE


/datum/job/greek/toxotai
	title = "Toxotai"
	en_meaning = "Greek Light Archer"
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateGR"
	SL_check_independent = TRUE

	// AUTOBALANCE
	min_positions = 8
	max_positions = 100
/datum/job/greek/toxotai/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/roman(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/toxotai(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/toxotai(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/xiphos(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/bow(H), slot_l_hand)
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