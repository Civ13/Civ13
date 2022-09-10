////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////ROMAN///////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////
/datum/job/roman
	faction = "Human"
	is_ancient = TRUE
/datum/job/roman/give_random_name(var/mob/living/human/H)
	if (title != "Gladiator")
		H.name = H.species.get_random_roman_name()
		H.real_name = H.name
	else
		H.name = H.species.get_random_ancient_name()
		H.real_name = H.name

/datum/job/roman/captain	//Roman - Centurion
	title = "Centurion"
	en_meaning = "Roman Commander"
	rank_abbreviation = "Cen."

	spawn_location = "JoinLateRO"

	is_commander = TRUE

	is_officer = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/roman/captain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/roman(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/roman_centurion(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/ancient/scale(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/roman/praetorian(H), slot_l_hand)
		//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/roman_centurion(H), slot_head)
		//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/gladius/iron(H), slot_belt)
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

	spawn_location = "JoinLateRO"

	is_officer = TRUE


	min_positions = 2
	max_positions = 10

/datum/job/roman/squad_leader/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/roman(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/roman(H), slot_w_uniform)
		//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/roman_decurion(H), slot_head)
		//weapons
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/ancient/scale(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/gladius/iron(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/pilum(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/roman/praetorian(H), slot_l_hand)
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

	spawn_location = "JoinLateRO"


	min_positions = 1
	max_positions = 6

/datum/job/roman/bearer/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/roman(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/roman(H), slot_w_uniform)

	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/ancient/scale(H), slot_wear_suit)
	//pelt randomization
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/bearpelt(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/lionpelt(H), slot_head)

		//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/gladius/iron(H), slot_belt)
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

	spawn_location = "JoinLateRO"


	min_positions = 12
	max_positions = 200

/datum/job/roman/soldier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/roman(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/roman(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/ancient/scale(H), slot_wear_suit)
		//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/roman(H), slot_head)
		//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/gladius/iron(H), slot_belt)
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

	spawn_location = "JoinLateRO"


	min_positions = 8
	max_positions = 100
/datum/job/roman/velites/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/roman(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/roman(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/ancient/chainmail(H), slot_wear_suit)

	//pelt randomization
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/wolfpelt(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/foxpelt(H), slot_head)

		//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/pilum(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/roman_buckler(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/bow/shortbow(H), slot_l_hand)
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
	faction = "Human"
	is_ancient = TRUE

/datum/job/greek/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_greek_name()
	H.real_name = H.name


/datum/job/greek/captain	//Greek Strategus
	title = "Lochagos"
	en_meaning = "Greek Commander"
	rank_abbreviation = "Lo."

	spawn_location = "JoinLateGR"

	is_commander = TRUE

	is_officer = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/greek/captain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/roman(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/greek_commander(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/ancient/scaled(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/greek_commander(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/xiphos/bronze(H), slot_belt)
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

	spawn_location = "JoinLateGR"

	is_officer = TRUE

	min_positions = 2
	max_positions = 10

/datum/job/greek/squad_leader/equip(var/mob/living/human/H)
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
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/ancient/scaled(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/greek_sl(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/xiphos/bronze(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/spear/dory/bronze(H), slot_r_hand)
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

	spawn_location = "JoinLateGR"



	min_positions = 12
	max_positions = 200

/datum/job/greek/soldier/equip(var/mob/living/human/H)
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
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/ancient/scaled(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/greek(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/xiphos/bronze(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/aspis(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/spear/sarissa/bronze(H), slot_r_hand)
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

	spawn_location = "JoinLateGR"



	min_positions = 8
	max_positions = 100
/datum/job/greek/toxotai/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/roman(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/toxotai(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/ancient/linen(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/toxotai(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/xiphos/bronze(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/bow/shortbow(H), slot_l_hand)
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

	spawn_location = "JoinLateRO"

	is_gladiator = TRUE

	min_positions = 100
	max_positions = 100
/datum/job/roman/gladiator/equip(var/mob/living/human/H)
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

	H.add_note("Role", "You are a <b>[title]</b>, fighting in the area. Can you become the best? You can use the beds at the Sleeping Quarters to save your character's name, stats and victories. You will be able to load on respawn.")
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

	spawn_location = "JoinLateROG"

	is_medic = TRUE
	is_gladiator = TRUE

	min_positions = 3
	max_positions = 8
/datum/job/roman/doctor/equip(var/mob/living/human/H)
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

	spawn_location = "JoinLateROG"

	is_officer = TRUE
	whitelisted = TRUE
	is_gladiator = TRUE

	min_positions = 2
	max_positions = 8

/datum/job/roman/guard/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/roman(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/roman(H), slot_w_uniform)
		//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/roman_decurion(H), slot_head)
		//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/melee/classic_baton/whip(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/gladius/iron(H), slot_back)
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

	spawn_location = "JoinLateROG"

	is_gladiator = TRUE
	is_commander = TRUE

	is_officer = TRUE
	whitelisted = TRUE


	min_positions = 1
	max_positions = 1
/datum/job/roman/emperor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/roman(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/custom/toga/purple(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/ancient/roman(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/horn(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/laurelcrown(H), slot_head)

	H.add_note("Role", "You are the <b>[title]</b>. You are responsable for organizing the games. You can use the interface of the <b>Gladiator Combat Organizer</b> to turn automatic mode on and off. If you decide to manage the games yourself, you will need to attribute the victory using the <b>Gladiator Ledger</b> - click on it and choose the winner!")

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

////////////////Germanic Tribes///////////////////

/datum/job/german/chieftain
	title = "Jarl"
	en_meaning = "Chieftain"
	rank_abbreviation = "Jarl"

	spawn_location = "JoinLateGE"
	is_ancient = TRUE
	is_commander = TRUE
	is_officer = TRUE
	can_be_female = TRUE

	min_positions = 1
	max_positions = 5

/datum/job/german/chieftain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/steppe_shoes(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/celtic_red(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/bronze_chestplate(H), slot_wear_suit)
		//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/asterix/conspicious(H), slot_head)
		//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/gaelic/iron(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/gaelic/iron(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/scutum(H), slot_r_store)
	H.add_note("Role", "You are a <b>[title]</b>, the chieftain of your tribe. Lead your men to victory!")

	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	give_random_name(H)

	return TRUE


/datum/job/german/swordsman
	title = "Sahsnotoz"
	en_meaning = "Swordsman"
	rank_abbreviation = ""

	spawn_location = "JoinLateGE"
	is_ancient = TRUE

	min_positions = 10
	max_positions = 100

/datum/job/german/swordsman/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/steppe_shoes(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/celtic_short_braccae(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/ancient/scaled(H), slot_wear_suit)
		//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/asterix(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/horned(H), slot_head)
		//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/longsword/iron(H), slot_back)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/gaelic/iron(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/scutum(H), slot_l_hand)

	H.add_note("Role", "You are a <b>[title]</b>, a germanic swordsman.")

	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_LOW)
	give_random_name(H)

	return TRUE

/datum/job/german/axeman
	title = "Teceitos"
	en_meaning = "Axeman"
	rank_abbreviation = ""

	spawn_location = "JoinLateGE"
	is_ancient = TRUE

	min_positions = 10
	max_positions = 100

/datum/job/german/axeman/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/roman(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/celtic_short_braccae(H), slot_w_uniform)
		//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/foxpelt(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/wolfpelt(H), slot_head)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/hatchet/tribal(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/hatchet/battleaxe(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/blue_buckler(H), slot_back)

	H.add_note("Role", "You are a <b>[title]</b>, a celtic axeman. Use your speed to manouver around the enemy and your axe to destroy their armor and shields.")

	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_LOW)
	give_random_name(H)

	return TRUE


/datum/job/german/spearman
	title = "Framaharjoz"
	en_meaning = "Spearman"
	rank_abbreviation = ""

	spawn_location = "JoinLateGE"
	is_ancient = TRUE

	min_positions = 20
	max_positions = 200

/datum/job/german/spearman/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/steppe_shoes(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/celtic_long_braccae(H), slot_w_uniform)
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/steppe_leather(H), slot_wear_suit)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/medieval/leather(H), slot_wear_suit)
		//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/bearpelt/brown(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/bearpelt/black(H), slot_head)
		//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/spear/sarissa/pike(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/spear/sarissa/pike(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/shield/scutum(H), slot_back)
	H.add_note("Role", "You are a <b>[title]</b>, a germanic spearman.")

	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_LOW)
	give_random_name(H)

	return TRUE

/datum/job/german/skirmisher
	title = "Swainoz"
	en_meaning = "Skirmisher"
	rank_abbreviation = ""

	spawn_location = "JoinLateGE"
	is_ancient = TRUE

	min_positions = 10
	max_positions = 100

/datum/job/german/skirmisher/equip(var/mob/living/human/H)
	if (!H)	return FALSE
		//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/sandal(H), slot_shoes)
		//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/celtic_green(H), slot_w_uniform)
		//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/hatchet(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/bow/shortbow(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/quiver/full(H), slot_back)
		//head
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/sheeppelt(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/goatpelt(H), slot_head)
	H.add_note("Role", "You are a <b>[title]</b>, a germanic skirmisher.")

	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_HIGH)
	H.setStat("medical", STAT_LOW)
	give_random_name(H)

	return TRUE