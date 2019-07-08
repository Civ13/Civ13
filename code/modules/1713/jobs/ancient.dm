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
	give_random_name(H)

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
	give_random_name(H)
	return TRUE

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
	H.equip_to_slot_or_del(new /obj/item/weapon/material/roman_standard(H), slot_r_hand)
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
	give_random_name(H)
	return TRUE
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
	give_random_name(H)

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
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/roman_buckler(H), slot_r_hand)
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
	give_random_name(H)
	return TRUE
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
	give_random_name(H)
	return TRUE
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
	give_random_name(H)
	return TRUE
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
	give_random_name(H)

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
	give_random_name(H)
	return TRUE


////////////////////GLADIATOR///////////////

/datum/job/roman/gladiator
	title = "Gladiator"
	en_meaning = ""
	rank_abbreviation = ""
	selection_color = "#2d2d63"
	spawn_location = "JoinLateRO"
	SL_check_independent = TRUE
	is_gladiator = TRUE
	// AUTOBALANCE
	min_positions = 100
	max_positions = 100
/datum/job/roman/gladiator/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/roman(H), slot_shoes)
		//clothes
	var/pickuni = rand(1,3)
	if (pickuni == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/celtic_green(H), slot_w_uniform)
	else if (pickuni == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/celtic_red(H), slot_w_uniform)
	else if (pickuni == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/celtic_blue(H), slot_w_uniform)

	H.add_note("Role", "You are a <b>[title]</b>, fighting in the area. Can you become the best?")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_HIGH)
	give_random_name(H)
	H.check_profiles() //this will trigger the "give a custom name" proc
	return TRUE


/datum/job/roman/doctor
	title = "Medicus"
	en_meaning = "Doctor"
	rank_abbreviation = "Medicus"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateROG"
	SL_check_independent = TRUE
	is_gladiator = TRUE
	// AUTOBALANCE
	min_positions = 3
	max_positions = 8
/datum/job/roman/doctor/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/roman(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/custom/toga(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/ancient/roman(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_r_store)

	H.add_note("Role", "You are a <b>[title]</b>. Keep the arena clean and the men alive.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	give_random_name(H)
	return TRUE



/datum/job/roman/guard
	title = "Custos"
	en_meaning = "Arena Guard"
	rank_abbreviation = "Custos"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateROG"
	SL_check_independent = TRUE
	is_officer = TRUE
	whitelisted = TRUE
	is_gladiator = TRUE
	// Autobalance
	min_positions = 2
	max_positions = 8

/datum/job/roman/guard/equip(var/mob/living/carbon/human/H)
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
	H.add_note("Role", "You are a <b>[title]</b>, guarding the arena. Keep the gladiators organized and following the rules, while protecting the Emperor!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_HIGH)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_HIGH)
	H.setStat("medical", STAT_NORMAL)
	give_random_name(H)
	return TRUE

/datum/job/roman/emperor
	title = "Imperator"
	en_meaning = "Emperor"
	rank_abbreviation = "Imperator"
	selection_color = "#2d2d63"
	spawn_location = "JoinLateROM"
	SL_check_independent = TRUE
	is_gladiator = TRUE
	is_commander = TRUE
	head_position = TRUE
	is_officer = TRUE
	whitelisted = TRUE

	// AUTOBALANCE
	min_positions = 1
	max_positions = 1
/datum/job/roman/emperor/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/roman(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/custom/toga/purple(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/ancient/roman(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/laurelcrown(H), slot_head)

	H.add_note("Role", "You are the <b>[title]</b>. Organize the games!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_MEDIUM_HIGH)
	H.setStat("medical", STAT_VERY_HIGH)
	give_random_name(H)
	return TRUE

/mob/living/carbon/human/proc/check_profiles()
	spawn(10)
		if (map.ID == MAP_GLADIATORS && client)
			var/obj/map_metadata/gladiators/GD = map
			var/done = FALSE
			var/list/loadinglist = list("Cancel")
			if (GD.gladiator_stats.len && client)
				for (var/i = 1, i <= GD.gladiator_stats.len, i++)
					if (GD.gladiator_stats[i][1] == client.ckey && GD.gladiator_stats[i][4] == 0)
						loadinglist += GD.gladiator_stats[i][2]
						done = TRUE
			if (done == TRUE)
				var/input_msg = WWinput(src, "Welcome, [client.ckey]. Do you want to load any of your Gladiators?", "Load Gladiators", "Cancel", loadinglist)
				if (input_msg == "Cancel")
					done = FALSE
				else
					for (var/i = 1, i <= GD.gladiator_stats.len, i++)
						if (GD.gladiator_stats[i][1] == client.ckey && GD.gladiator_stats[i][2] == input_msg && GD.gladiator_stats[i][4] == 0)
							name = GD.gladiator_stats[i][2]
							real_name = name
							var/statsplit = splittext(GD.gladiator_stats[i][3],",")
							stats["strength"][1] = text2num(statsplit[1])
							stats["strength"][2] = text2num(statsplit[1])
							stats["crafting"][1] = text2num(statsplit[2])
							stats["crafting"][2] = text2num(statsplit[2])
							stats["rifle"][1] = text2num(statsplit[3])
							stats["rifle"][2] = text2num(statsplit[3])
							stats["dexterity"][1] = text2num(statsplit[4])
							stats["dexterity"][2] = text2num(statsplit[4])
							stats["swords"][1] = text2num(statsplit[5])
							stats["swords"][2] = text2num(statsplit[5])
							stats["pistol"][1] = text2num(statsplit[6])
							stats["pistol"][2] = text2num(statsplit[6])
							stats["bows"][1] = text2num(statsplit[7])
							stats["bows"][2] = text2num(statsplit[7])
							stats["medical"][1] = text2num(statsplit[8])
							stats["medical"][2] = text2num(statsplit[8])
							stats["philosophy"][1] = text2num(statsplit[9])
							stats["philosophy"][2] = text2num(statsplit[9])
							stats["mg"][1] = text2num(statsplit[10])
							stats["mg"][2] = text2num(statsplit[10])
							src << "<font size=2><b>Successfully loaded <b>[name]</b>.</font>"
							return
			if (done == FALSE)
				var/input_msg = WWinput(src, "Welcome, [client.ckey]. You have spawned as a gladiator named [name]. You can customize your name. Do you want to?", "Custom name", "No", list("Yes","No"))
				if (input_msg == "No")
					return
				else
					var/input_name = input(src, "Choose the new name: (Max 25 characters)","Custom Name", name) as text
					input_name = sanitizeName(input_name, 25, FALSE)
					if (input_name != "" && input_name)
						name = input_name
						real_name = input_name
					if (!name || !real_name)
						name = capitalize(pick(first_names_male_roman)) + " " + capitalize(pick(middle_names_roman)) + " " + capitalize(pick(last_names_roman))
						real_name = name