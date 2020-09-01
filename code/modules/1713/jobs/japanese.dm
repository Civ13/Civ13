/datum/job/japanese
	faction = "Human"

/datum/job/japanese/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_japanese_name(H.gender)
	H.real_name = H.name

/datum/job/japanese/captain
	title = "Rikugun-Tai-i"
	en_meaning = "Army Captain"
	rank_abbreviation = "Ri-Tai"


	spawn_location = "JoinLateJPCap"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE



	min_positions = 1
	max_positions = 1
/datum/job/japanese/captain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/japboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/japoffuni, slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/japcoat2(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/japoffcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/nambu(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c8mmnambu(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/japanese(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/katana(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Full Beard" && H.f_style != "Medium Beard" && H.f_style != "Long Beard" && H.f_style != "Very Long Beard" && H.f_style != "Dwarf Beard" && H.f_style != "Volaju" && H.f_style != "Abraham Lincoln Beard" && H.f_style != "Van Dyke Mustache" && H.f_style != "Hulk Hogan Mustache")
		H.f_style = pick("Shaved","Hipster Beard","Goatee","Watson Mustache")
	world << "<b><big>[H.real_name] is the Captain of the Japanese Forces!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, the highest ranking officer present. Your job is to command the company.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/japanese/lieutenant
	title = "Rikugun-Chui"
	en_meaning = "1st Lieutenant"
	rank_abbreviation = "1lt."


	spawn_location = "JoinLateJPCap"
	whitelisted = TRUE

	is_commander = TRUE
	is_officer = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/japanese/lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/japboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/japoffuni(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/japcoat2(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/japoffcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/nambu(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c8mmnambu(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/japanese(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/katana(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Full Beard" && H.f_style != "Medium Beard" && H.f_style != "Long Beard" && H.f_style != "Very Long Beard" && H.f_style != "Dwarf Beard" && H.f_style != "Volaju" && H.f_style != "Abraham Lincoln Beard" && H.f_style != "Van Dyke Mustache" && H.f_style != "Hulk Hogan Mustache")
		H.f_style = pick("Shaved","Hipster Beard","Goatee","Watson Mustache")
	world << "<b><big>[H.real_name] is the 1st Lieutenant of the Japanese forces!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the troops and their orders. The whole operation relies on you!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/japanese/lieutenant2
	title = "Rikugun-Shoi"
	en_meaning = "2nd Lieutenant"
	rank_abbreviation = "2lt."


	spawn_location = "JoinLateJPCap"
	whitelisted = TRUE

	is_commander = TRUE
	is_officer = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/japanese/lieutenant2/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/japboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/japoffuni(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/japcoat2(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/japoffcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/nambu(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c8mmnambu(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/japanese(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/katana(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Full Beard" && H.f_style != "Medium Beard" && H.f_style != "Long Beard" && H.f_style != "Very Long Beard" && H.f_style != "Dwarf Beard" && H.f_style != "Volaju" && H.f_style != "Abraham Lincoln Beard" && H.f_style != "Van Dyke Mustache" && H.f_style != "Hulk Hogan Mustache")
		H.f_style = pick("Shaved","Hipster Beard","Goatee","Watson Mustache")
	world << "<b><big>[H.real_name] is the 2nd Lieutenant of the Japanese forces!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the troops and their orders. Second to 1st Lieutenant. The whole operation relies on you and your orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/japanese/sergeant
	title = "Gunso"
	en_meaning = "Sergeant"
	rank_abbreviation = "Gunso"

	spawn_location = "JoinLateJP"
	is_officer = TRUE
	is_squad_leader = TRUE
	uses_squads = TRUE

	min_positions = 1
	max_positions = 10

/datum/job/japanese/sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/japboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/japuni(H), slot_w_uniform)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/japcoat(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/japoffcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/revolver/t26_revolver(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c9mm_jap_revolver(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka30(H), slot_shoulder)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/katana(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Full Beard" && H.f_style != "Medium Beard" && H.f_style != "Long Beard" && H.f_style != "Very Long Beard" && H.f_style != "Dwarf Beard" && H.f_style != "Volaju" && H.f_style != "Abraham Lincoln Beard" && H.f_style != "Van Dyke Mustache" && H.f_style != "Hulk Hogan Mustache")
		H.f_style = pick("Shaved","Hipster Beard","Goatee","Watson Mustache")
	H.add_note("Role", "You are a <b>[title]</b>, a sergeant leading a squad. Organize your group according to the <b>Captain or Leiutenant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/japanese/doctor
	title = "Gun-i"
	en_meaning = "Doctor"
	rank_abbreviation = "Gun-i"

	spawn_location = "JoinLateJPDoc"

	is_medic = TRUE


	min_positions = 1
	max_positions = 10

/datum/job/japanese/doctor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/japboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/japuni(H), slot_w_uniform) // for now
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/japcap(H), slot_head)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/japcoat(H), slot_wear_suit)

	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/surgery(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Full Beard" && H.f_style != "Medium Beard" && H.f_style != "Long Beard" && H.f_style != "Very Long Beard" && H.f_style != "Dwarf Beard" && H.f_style != "Volaju" && H.f_style != "Abraham Lincoln Beard" && H.f_style != "Van Dyke Mustache" && H.f_style != "Hulk Hogan Mustache")
		H.f_style = pick("Shaved","Hipster Beard","Goatee","Watson Mustache")
	H.add_note("Role", "You are a <b>[title]</b>, the most qualified medic present, and you are in charge of keeping the soldiers healthy.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_VERY_HIGH)


	return TRUE
/*
/datum/job/japanese/cook
	title = "Shefu"
	en_meaning = "Chef"
	rank_abbreviation = "Shefu"

	spawn_location = "JoinLateJP"



	min_positions = 1
	max_positions = 10

/datum/job/japanese/cook/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/japcoat(H), slot_wear_suit)

//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/japboots(H), slot_shoes)
//head//
	H.equip_to_slot_or_del(new /obj/item/clothing/head/japcap(H), slot_head)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/japuni(H), slot_w_uniform)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka30(H), slot_shoulder)

	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/jap(H), slot_belt)

	H.add_note("Role", "You are the cook of the company. Feed the whole company according to the <b>Leiutenant's</b> orders!")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW) //not used
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)

*/



////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/*
/datum/job/japanese/infantry
	title = "Nitohei"
	en_meaning = "Soldier Second-class"
	rank_abbreviation = "Ni."

	spawn_location = "JoinLateJP"



	min_positions = 6
	max_positions = 200

/datum/job/japanese/infantry/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/japboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/japuni(H), slot_w_uniform)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/japcap(H), slot_head)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/japcoat(H), slot_wear_suit)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka30(H), slot_shoulder)

	H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/jap/soldier(H), slot_belt)

	H.add_note("Role", "You are a <b>[title]</b>, a simple soldier second-class  employed by the Imperial Japanese Army. Follow your <b>Officer's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE
*/
/datum/job/japanese/sniper
	title = "Ittohei"
	en_meaning = "Soldier First-class"
	rank_abbreviation = "Itto."

	spawn_location = "JoinLateJP"
	uses_squads = TRUE


	min_positions = 3
	max_positions = 10

/datum/job/japanese/sniper/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/japboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/japuni(H), slot_w_uniform)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/japcap(H), slot_head)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/japcoat(H), slot_wear_suit)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka35(H), slot_shoulder)

	H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/jap/soldier(H), slot_belt)

	H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/bint(H), slot_l_store)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Full Beard" && H.f_style != "Medium Beard" && H.f_style != "Long Beard" && H.f_style != "Very Long Beard" && H.f_style != "Dwarf Beard" && H.f_style != "Volaju" && H.f_style != "Abraham Lincoln Beard" && H.f_style != "Van Dyke Mustache" && H.f_style != "Hulk Hogan Mustache")
		H.f_style = pick("Shaved","Hipster Beard","Goatee","Watson Mustache")
	H.add_note("Role", "You are a <b>[title]</b>, a sharpshooter promoted to soldier first-class employed by the Imperial Japanese Army. Follow your <b>Officer's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_HIGH) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/japanese/whitesash_infantry
	title = "Shiro Nitohei"
	en_meaning = "Soldier Second-class"
	rank_abbreviation = "Ni."

	spawn_location = "JoinLateJP"
	uses_squads = TRUE


	min_positions = 6
	max_positions = 200

/datum/job/japanese/whitesash_infantry/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/japboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/japuni(H), slot_w_uniform)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/japcap(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka30(H), slot_shoulder)

	var/obj/item/clothing/accessory/white_sash = new /obj/item/clothing/accessory/white_sash(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(white_sash, H)

	H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/jap/soldier(H), slot_belt)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Full Beard" && H.f_style != "Medium Beard" && H.f_style != "Long Beard" && H.f_style != "Very Long Beard" && H.f_style != "Dwarf Beard" && H.f_style != "Volaju" && H.f_style != "Abraham Lincoln Beard" && H.f_style != "Van Dyke Mustache" && H.f_style != "Hulk Hogan Mustache")
		H.f_style = pick("Shaved","Hipster Beard","Goatee","Watson Mustache")
	H.add_note("Role", "You are a <b>[title]</b>, a simple soldier second-class employed by the Imperial Japanese Army. Follow your <b>Officer's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE
//////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////WW2///////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////
/datum/job/japanese/ija_captain
	title = "IJA Rikugun-Tai-i"
	en_meaning = "Army Captain"
	rank_abbreviation = "Ri-Tai"


	spawn_location = "JoinLateJPCap"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_ww2 = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/japanese/ija_captain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japoffuni(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japoffcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/ww2/nambu(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/japanese(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/katana(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Full Beard" && H.f_style != "Medium Beard" && H.f_style != "Long Beard" && H.f_style != "Very Long Beard" && H.f_style != "Dwarf Beard" && H.f_style != "Volaju" && H.f_style != "Abraham Lincoln Beard" && H.f_style != "Van Dyke Mustache" && H.f_style != "Hulk Hogan Mustache")
		H.f_style = pick("Shaved","Hipster Beard","Goatee","Watson Mustache")
	world << "<b><big>[H.real_name] is the Captain of the Japanese Forces!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, the highest ranking officer present. Your job is to command the company.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/japanese/ija_lieutenant
	title = "IJA Rikugun-Chui"
	en_meaning = "1st Lieutenant"
	rank_abbreviation = "1lt."


	spawn_location = "JoinLateJPLT"
	whitelisted = TRUE
	is_commander = TRUE
	is_officer = TRUE
	is_ww2 = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/japanese/ija_lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japoffuni(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japoffcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/ww2/nambu(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/japanese(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/katana(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Full Beard" && H.f_style != "Medium Beard" && H.f_style != "Long Beard" && H.f_style != "Very Long Beard" && H.f_style != "Dwarf Beard" && H.f_style != "Volaju" && H.f_style != "Abraham Lincoln Beard" && H.f_style != "Van Dyke Mustache" && H.f_style != "Hulk Hogan Mustache")
		H.f_style = pick("Shaved","Hipster Beard","Goatee","Watson Mustache")
	world << "<b><big>[H.real_name] is the 1st Lieutenant of the Japanese forces!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the troops and their orders. The whole operation relies on you!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/japanese/ija_lieutenant2
	title = "IJA Rikugun-Shoi"
	en_meaning = "2nd Lieutenant"
	rank_abbreviation = "2lt."


	spawn_location = "JoinLateJPLT"
	whitelisted = TRUE
	is_commander = TRUE
	is_officer = TRUE
	is_ww2 = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/japanese/ija_lieutenant2/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japoffuni(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japoffcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/nambu(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/japanese(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/katana(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Full Beard" && H.f_style != "Medium Beard" && H.f_style != "Long Beard" && H.f_style != "Very Long Beard" && H.f_style != "Dwarf Beard" && H.f_style != "Volaju" && H.f_style != "Abraham Lincoln Beard" && H.f_style != "Van Dyke Mustache" && H.f_style != "Hulk Hogan Mustache")
		H.f_style = pick("Shaved","Hipster Beard","Goatee","Watson Mustache")
	world << "<b><big>[H.real_name] is the 2nd Lieutenant of the Japanese forces!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the troops and their orders. Second to 1st Lieutenant. The whole operation relies on you and your orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/japanese/ija_sergeant
	title = "IJA Gunso"
	en_meaning = "Sergeant"
	rank_abbreviation = "Gu."

	spawn_location = "JoinLateJP"
	is_officer = TRUE
	uses_squads = TRUE
	is_squad_leader = TRUE
	is_ww2 = TRUE
	min_positions = 1
	max_positions = 4

/datum/job/japanese/ija_sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/ww2/nambu(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka99(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/jap/ww2soldier(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/katana/fullh = new /obj/item/clothing/accessory/storage/sheath/katana/full(null)
	uniform.attackby(fullh, H)
	fullh.attackby(new/obj/item/weapon/material/sword/katana, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Full Beard" && H.f_style != "Medium Beard" && H.f_style != "Long Beard" && H.f_style != "Very Long Beard" && H.f_style != "Dwarf Beard" && H.f_style != "Volaju" && H.f_style != "Abraham Lincoln Beard" && H.f_style != "Van Dyke Mustache" && H.f_style != "Hulk Hogan Mustache")
		H.f_style = pick("Shaved","Hipster Beard","Goatee","Watson Mustache")
	H.add_note("Role", "You are a <b>[title]</b>, a sergeant leading a squad. Organize your group according to the <b>Captain or Leiutenant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/japanese/ija_doctor
	title = "IJA Gun-i"
	en_meaning = "Doctor"
	rank_abbreviation = "Gun-i"

	spawn_location = "JoinLateJPDoc"

	is_medic = TRUE
	is_ww2 = TRUE

	min_positions = 2
	max_positions = 4

/datum/job/japanese/ija_doctor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_med(H), slot_w_uniform) // for now
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap(H), slot_head)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/doctor(H), slot_wear_suit)

	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/surgery(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	H.add_note("Role", "You are a <b>[title]</b>, the most qualified medic present, and you are in charge of keeping the soldiers healthy.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_VERY_HIGH)

	return TRUE
/datum/job/japanese/ija_medic
	title = "Sento-i"
	en_meaning = "Medic"
	rank_abbreviation = "Sen-i"

	spawn_location = "JoinLateJPDoc"
	uses_squads = TRUE
	is_ww2 = TRUE


	is_medic = TRUE
	min_positions = 2
	max_positions = 10

/datum/job/japanese/ija_medic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_med(H), slot_w_uniform) // for now
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japhelm_med(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka99(H), slot_shoulder)

	H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/jap/ww2soldier(H), slot_belt)
//other
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	H.add_note("Role", "You are a <b>[title]</b>, the most qualified medic present, and you are in charge of keeping the soldiers healthy.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_VERY_HIGH)
	return TRUE

/datum/job/japanese/ija_ww2infantry
	title = "Nitohei"
	en_meaning = "Soldier Second-class"
	rank_abbreviation = "Ni."

	spawn_location = "JoinLateJP"
	uses_squads = TRUE
	is_ww2 = TRUE

	min_positions = 20
	max_positions = 100

/datum/job/japanese/ija_ww2infantry/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni(H), slot_w_uniform)

//head
	var/randhead = rand(1,3)
	if (randhead == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japhelm(H), slot_head)
	else if (randhead == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japhelm_bandana(H), slot_head)
	else if (randhead == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap(H), slot_head)
//back
	var/randweap = rand(1,2)
	if (randweap == 1)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka99(H), slot_shoulder)
		H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/jap/ww2soldier(H), slot_belt)
	else if (randweap == 2)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka38(H), slot_shoulder)
		H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/jap/soldier(H), slot_belt)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	H.add_note("Role", "You are a <b>[title]</b>, a simple soldier second-class  employed by the Imperial Japanese Army. Follow your <b>Officer's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/japanese/ija_ww2ATunit
	title = "Nitohei Taisensha"
	en_meaning = "Anti Tank Unit"
	rank_abbreviation = "Ni."

	spawn_location = "JoinLateJP"
	is_ww2 = TRUE
	is_tanker = TRUE

	min_positions = 4
	max_positions = 12


/datum/job/japanese/ija_ww2ATunit/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_korean_name(H.gender)
	H.real_name = H.name
/datum/job/japanese/ija_ww2ATunit/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni(H), slot_w_uniform)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/jap_headband(H), slot_head)
//back
	H.equip_to_slot_or_del(new 	/obj/item/weapon/grenade/suicide_vest/kamikaze(H), slot_belt)

	give_random_name(H)
	H.s_tone = rand(-32,-24)
	H.add_note("Role", "You are a <b>[title]</b>, an Anti Tank Suicide Unit  employed by the Imperial Japanese Army. Follow your <b>Officer's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE



/datum/job/japanese/ija_machinegunner
	title = "Taiho"
	en_meaning = "Machinegunner"
	rank_abbreviation = "Itto."

	spawn_location = "JoinLateJP"
	uses_squads = TRUE
	is_ww2 = TRUE

	min_positions = 4
	max_positions = 15

/datum/job/japanese/ija_machinegunner/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni(H), slot_w_uniform)

//head
	var/randhead = rand(1,3)
	if (randhead == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japhelm(H), slot_head)
	else if (randhead == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japhelm_bandana(H), slot_head)
	else if (randhead == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/type99(H), slot_shoulder)
	H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/jap/ww2soldier99(H), slot_belt)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	H.add_note("Role", "You are a <b>[title]</b>, a machine gunner, first-class,  employed by the Imperial Japanese Army. Follow your <b>Officer's</b> orders! Provide support and supressing fire for your comrades!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_HIGH)


	return TRUE

/datum/job/japanese/ija_machinegunner_assistant
	title = " Fuku Taiho"
	en_meaning = "Assistant Machinegunner"
	rank_abbreviation = ""

	spawn_location = "JoinLateJP"
	uses_squads = TRUE
	is_ww2 = TRUE
	min_positions = 2
	max_positions = 4

/datum/job/japanese/ija_machinegunner_assistant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni(H), slot_w_uniform)

//head
	var/randhead = rand(1,3)
	if (randhead == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japhelm(H), slot_head)
	else if (randhead == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japhelm_bandana(H), slot_head)
	else if (randhead == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka99(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/jap/ww2soldier(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/ww2/jap/ammo_crate/full(H), slot_back)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/rank/jap_ittoheih = new /obj/item/clothing/accessory/rank/jap_ittohei(null)
	uniform.attackby(jap_ittoheih, H)
	H.add_note("Role", "You are a <b>[title]</b>, a machine gunner, first-class,  employed by the Imperial Japanese Army. Follow your <b>Officer's</b> orders! Provide support and supressing fire for your comrades!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_HIGH)


	return TRUE

/datum/job/japanese/ija_sniper
	title = "Senmeina no Hito"
	en_meaning = "Sniper"
	rank_abbreviation = "Jo."

	spawn_location = "JoinLateJP"
	uses_squads = TRUE
	is_ww2 = TRUE

	min_positions = 2
	max_positions = 10

/datum/job/japanese/ija_sniper/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni(H), slot_w_uniform)

//head
	var/randhead = rand(1,3)
	if (randhead == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japhelm(H), slot_head)
	else if (randhead == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japhelm_bandana(H), slot_head)
	else if (randhead == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka99/sniper(H), slot_shoulder)
	H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/jap/ww2soldier(H), slot_belt)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	H.add_note("Role", "You are a <b>[title]</b>, a sniper, 1st class, employed by the Imperial Japanese Army. Follow your <b>Officer's</b> orders and take out valuable targets from a range!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_VERY_HIGH) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE
/////////////////////////////////////////////////TANK CREW//////////////////////////////////////////////////////
/datum/job/japanese/ija_sergeant_tanker
	title = "Sensha Gunso"
	en_meaning = "Tank Sergeant"
	rank_abbreviation = "Gu."

	spawn_location = "JoinLateJP"
	is_officer = TRUE
	is_tanker = TRUE
	is_ww2 = TRUE
	is_squad_leader = TRUE
	uses_squads = TRUE

	min_positions = 1
	max_positions = 3

/datum/job/japanese/ija_sergeant_tanker/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_tanker(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/ww2/nambu(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c8mmnambu(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka99(H), slot_shoulder)

	H.equip_to_slot_or_del(new /obj/item/weapon/key/japanese(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/jap/ww2soldier(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/katana/fullh = new /obj/item/clothing/accessory/storage/sheath/katana/full(null)
	uniform.attackby(fullh, H)
	fullh.attackby(new/obj/item/weapon/material/sword/katana, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	H.add_note("Role", "You are a <b>[title]</b>, a sergeant leading an armored squad. Organize your group according to the <b>Captain or Leiutenant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)


	return TRUE

/datum/job/japanese/ija_ww2_tanker
	title = "Senshahei"
	en_meaning = "Tanker"
	rank_abbreviation = ""

	spawn_location = "JoinLateJP"
	is_tanker = TRUE
	is_ww2 = TRUE
	uses_squads = TRUE

	min_positions = 5
	max_positions = 30

/datum/job/japanese/ija_ww2_tanker/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_tanker(H), slot_w_uniform)

//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japhelm_tanker(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/key/japanese(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/ww2/nambu(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	H.add_note("Role", "You are a <b>[title]</b>, a tanker  employed by the Imperial Japanese Army. Follow your <b>Sergeant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_MEDIUM_HIGH) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_MEDIUM_HIGH)


	return TRUE



////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////WW2 JAPANESE PRISON//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/japanese/ija_camp_director
	title = "Horyoshuyojo-cho"
	en_meaning = "POW Camp Director"
	rank_abbreviation = "Ho-cho"


	spawn_location = "JoinLateJPCap"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE

	is_ww2 = TRUE
	is_prison = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/japanese/ija_camp_director/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_summer(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japoffcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/ww2/nambu(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/katana(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c8mmnambu(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/jap/camp_officer(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/rank/jap_taiih = new /obj/item/clothing/accessory/rank/jap_taii(null)
	uniform.attackby(jap_taiih, H)
	give_random_name(H)
	world << "<b><big>[H.real_name] is the Camp Director of the Japanese Forces!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, the highest ranking officer present. Your job is to command the guards and organize the POWs.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/japanese/camp_officer
	title = "Horyoshuyojo Gunso"
	en_meaning = "POW Camp Sergeant"
	rank_abbreviation = "Gu."

	spawn_location = "JoinLateJP"
	is_officer = TRUE

	is_ww2 = TRUE
	is_prison = TRUE

	min_positions = 1
	max_positions = 4

/datum/job/japanese/camp_officer/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_summer(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c8mmnambu(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/type100(H), slot_shoulder)

	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/ww2/nambu(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/jap/camp_officer(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/katana/fullh = new /obj/item/clothing/accessory/storage/sheath/katana/full(null)
	uniform.attackby(fullh, H)
	var/obj/item/clothing/accessory/rank/jap_gunsoh = new /obj/item/clothing/accessory/rank/jap_gunso(null)
	uniform.attackby(jap_gunsoh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a sergeant leading a squad of guards. Organize your group according to the <b>Camp director's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/japanese/camp_medic
	title = "Horyoshuyojo Sento-i"
	en_meaning = "Camp Medic"
	rank_abbreviation = "Sen-i"

	spawn_location = "JoinLateJPDoc"

	is_medic = TRUE
	is_ww2 = TRUE
	is_prison = TRUE


	min_positions = 1
	max_positions = 4

/datum/job/japanese/camp_medic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_summer(H), slot_w_uniform) // for now
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap(H), slot_head)
//back
	H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/jap/camp_guard(H), slot_belt)
//other
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/rank/jap_jotoheih = new /obj/item/clothing/accessory/rank/jap_jotohei(null)
	uniform.attackby(jap_jotoheih, H)

	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a medic, and you are in charge of keeping the guardss and POWs healthy.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_VERY_HIGH)
	return TRUE

/datum/job/japanese/camp_guard
	title = "Horyoshuyojo Anchisukiru"
	en_meaning = "POW Camp Guard"
	rank_abbreviation = ""

	spawn_location = "JoinLateJP"

	is_ww2 = TRUE
	is_prison = TRUE

	min_positions = 10
	max_positions = 50

/datum/job/japanese/camp_guard/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_summer(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka99(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/jap/camp_guard(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/rank/jap_ittoheih = new /obj/item/clothing/accessory/rank/jap_ittohei(null)
	uniform.attackby(jap_ittoheih, H)

	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a simple POW camp guard. Keep the POWs docile and alive, follow your <b>Officer's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////PACIFIC///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/japanese/ija_pacific_captain
	title = " Rikugun-Tai-i"
	en_meaning = "Army Captain"
	rank_abbreviation = ""


	spawn_location = "JoinLateJPCap"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_ww2 = TRUE
	is_pacific = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/japanese/ija_pacific_captain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_summer(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japoffcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/ww2/nambu(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/japanese_officer(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/japanese(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/katana(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/rank/jap_taiih = new /obj/item/clothing/accessory/rank/jap_taii(null)
	uniform.attackby(jap_taiih, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Full Beard" && H.f_style != "Medium Beard" && H.f_style != "Long Beard" && H.f_style != "Very Long Beard" && H.f_style != "Dwarf Beard" && H.f_style != "Volaju" && H.f_style != "Abraham Lincoln Beard" && H.f_style != "Van Dyke Mustache" && H.f_style != "Hulk Hogan Mustache")
		H.f_style = pick("Shaved","Hipster Beard","Goatee","Watson Mustache")
	world << "<b><big>[H.real_name] is the Captain of the Japanese Forces!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, the highest ranking officer present. Your job is to command the company.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/japanese/ija_pacific_lieutenant
	title = " Rikugun-Chui"
	en_meaning = "1st Lieutenant"
	rank_abbreviation = ""


	spawn_location = "JoinLateJPLT"
	whitelisted = TRUE
	is_commander = TRUE
	is_officer = TRUE
	is_ww2 = TRUE
	is_pacific = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/japanese/ija_pacific_lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_summer(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japoffcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/ww2/nambu(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/japanese_officer(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/japanese(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/katana(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/rank/jap_1lth = new /obj/item/clothing/accessory/rank/jap_1lt(null)
	uniform.attackby(jap_1lth, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Full Beard" && H.f_style != "Medium Beard" && H.f_style != "Long Beard" && H.f_style != "Very Long Beard" && H.f_style != "Dwarf Beard" && H.f_style != "Volaju" && H.f_style != "Abraham Lincoln Beard" && H.f_style != "Van Dyke Mustache" && H.f_style != "Hulk Hogan Mustache")
		H.f_style = pick("Shaved","Hipster Beard","Goatee","Watson Mustache")
	world << "<b><big>[H.real_name] is the 1st Lieutenant of the Japanese forces!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the troops and their orders. The whole operation relies on you!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/japanese/ija_pacific_lieutenant2
	title = " Rikugun-Shoi"
	en_meaning = "2nd Lieutenant"
	rank_abbreviation = ""


	spawn_location = "JoinLateJPLT"
	whitelisted = TRUE
	is_commander = TRUE
	is_officer = TRUE
	is_ww2 = TRUE
	is_pacific = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/japanese/ija_pacific_lieutenant2/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_summer(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japoffcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/nambu(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/japanese_officer(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/japanese(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/katana(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/rank/jap_2lth = new /obj/item/clothing/accessory/rank/jap_2lt(null)
	uniform.attackby(jap_2lth, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Full Beard" && H.f_style != "Medium Beard" && H.f_style != "Long Beard" && H.f_style != "Very Long Beard" && H.f_style != "Dwarf Beard" && H.f_style != "Volaju" && H.f_style != "Abraham Lincoln Beard" && H.f_style != "Van Dyke Mustache" && H.f_style != "Hulk Hogan Mustache")
		H.f_style = pick("Shaved","Hipster Beard","Goatee","Watson Mustache")
	world << "<b><big>[H.real_name] is the 2nd Lieutenant of the Japanese forces!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the troops and their orders. Second to 1st Lieutenant. The whole operation relies on you and your orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/japanese/ija_pacific_sergeant
	title = " Gunso"
	en_meaning = "Sergeant"
	rank_abbreviation = ""

	spawn_location = "JoinLateJP"
	is_officer = TRUE
	uses_squads = TRUE
	is_squad_leader = TRUE
	is_ww2 = TRUE
	is_pacific = TRUE
	min_positions = 1
	max_positions = 4

/datum/job/japanese/ija_pacific_sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_summer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/japanese(H), slot_r_store)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/ww2/nambu(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/c8mmnambu(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka99(H), slot_shoulder)

	H.equip_to_slot_or_del(new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/jap/ww2soldier(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/katana/fullh = new /obj/item/clothing/accessory/storage/sheath/katana/full(null)
	uniform.attackby(fullh, H)
	fullh.attackby(new/obj/item/weapon/material/sword/katana, H)
	var/obj/item/clothing/accessory/rank/jap_gunsoh = new /obj/item/clothing/accessory/rank/jap_gunso(null)
	uniform.attackby(jap_gunsoh, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	H.add_note("Role", "You are a <b>[title]</b>, a sergeant leading a squad. Organize your group according to the <b>Captain or Leiutenant's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/japanese/ija_pacific_doctor
	title = " Gun-i"
	en_meaning = "Doctor"
	rank_abbreviation = "Gun-i"

	spawn_location = "JoinLateJPDoc"

	is_medic = TRUE
	is_ww2 = TRUE
	is_pacific = TRUE

	min_positions = 2
	max_positions = 4

/datum/job/japanese/ija_pacific_doctor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_summer(H), slot_w_uniform) // for now
	H.equip_to_slot_or_del(new /obj/item/weapon/key/japanese(H), slot_r_store)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap(H), slot_head)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/doctor(H), slot_wear_suit)

	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/surgery(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/rank/jap_2lth = new /obj/item/clothing/accessory/rank/jap_2lt(null)
	uniform.attackby(jap_2lth, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	H.add_note("Role", "You are a <b>[title]</b>, the most qualified medic present, and you are in charge of keeping the soldiers healthy.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_VERY_HIGH)

	return TRUE
/datum/job/japanese/ija_pacific_medic
	title = " Sento-i"
	en_meaning = "Medic"
	rank_abbreviation = "Sen-i"

	spawn_location = "JoinLateJPDoc"
	uses_squads = TRUE
	is_ww2 = TRUE
	is_pacific = TRUE


	is_medic = TRUE
	min_positions = 2
	max_positions = 10

/datum/job/japanese/ija_pacific_medic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_summer(H), slot_w_uniform) // for now
	H.equip_to_slot_or_del(new /obj/item/weapon/key/japanese(H), slot_r_store)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japhelm_med(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka99(H), slot_shoulder)

	H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/jap/ww2soldier(H), slot_belt)
//other
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/rank/jap_jotoheih = new /obj/item/clothing/accessory/rank/jap_jotohei(null)
	uniform.attackby(jap_jotoheih, H)
	H.add_note("Role", "You are a <b>[title]</b>, the most qualified medic present, and you are in charge of keeping the soldiers healthy.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_VERY_HIGH)
	return TRUE

/datum/job/japanese/ija_pacific_ww2infantry
	title = " Nitohei"
	en_meaning = "Soldier Second-class"
	rank_abbreviation = ""

	spawn_location = "JoinLateJP"
	uses_squads = TRUE
	is_ww2 = TRUE
	is_pacific = TRUE

	min_positions = 20
	max_positions = 100

/datum/job/japanese/ija_pacific_ww2infantry/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_summer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/japanese(H), slot_r_store)

//head
	var/randhead = rand(1,3)
	if (randhead == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japhelm(H), slot_head)
	else if (randhead == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japhelm_bandana(H), slot_head)
	else if (randhead == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap(H), slot_head)
//back
	var/randweap = rand(1,2)
	if (randweap == 1)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka99(H), slot_shoulder)
		H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/jap/ww2soldier(H), slot_belt)
	else if (randweap == 2)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka38(H), slot_shoulder)
		H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/jap/soldier(H), slot_belt)
	give_random_name(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/rank/jap_nitoheih = new /obj/item/clothing/accessory/rank/jap_nitohei(null)
	uniform.attackby(jap_nitoheih, H)
	H.s_tone = rand(-32,-24)
	H.add_note("Role", "You are a <b>[title]</b>, a simple soldier second-class  employed by the Imperial Japanese Army. Follow your <b>Officer's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/japanese/ija_pacific_machinegunner
	title = " Taiho"
	en_meaning = "Machinegunner"
	rank_abbreviation = ""

	spawn_location = "JoinLateJP"
	uses_squads = TRUE
	is_ww2 = TRUE
	is_pacific = TRUE
	min_positions = 4
	max_positions = 8

/datum/job/japanese/ija_pacific_machinegunner/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_summer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/japanese(H), slot_r_store)

//head
	var/randhead = rand(1,3)
	if (randhead == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japhelm(H), slot_head)
	else if (randhead == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japhelm_bandana(H), slot_head)
	else if (randhead == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/type99(H), slot_shoulder)
	H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/jap/ww2soldier99(H), slot_belt)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/rank/jap_ittoheih = new /obj/item/clothing/accessory/rank/jap_ittohei(null)
	uniform.attackby(jap_ittoheih, H)
	H.add_note("Role", "You are a <b>[title]</b>, a machine gunner, first-class,  employed by the Imperial Japanese Army. Follow your <b>Officer's</b> orders! Provide support and supressing fire for your comrades!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_HIGH)


	return TRUE
/datum/job/japanese/ija_pacific_machinegunner_assistant
	title = "Danyaku Mochinushi"
	en_meaning = "Ammo Bearer"
	rank_abbreviation = ""

	spawn_location = "JoinLateJP"
	uses_squads = TRUE
	is_ww2 = TRUE
	is_pacific = TRUE
	min_positions = 2
	max_positions = 4

/datum/job/japanese/ija_pacific_machinegunner_assistant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_summer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/japanese(H), slot_r_store)

//head
	var/randhead = rand(1,3)
	if (randhead == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japhelm(H), slot_head)
	else if (randhead == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japhelm_bandana(H), slot_head)
	else if (randhead == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka99(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/jap/ww2soldier(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/ww2/jap/ammo_crate/full(H), slot_back)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/rank/jap_ittoheih = new /obj/item/clothing/accessory/rank/jap_ittohei(null)
	uniform.attackby(jap_ittoheih, H)
	H.add_note("Role", "You are a <b>[title]</b>, a machine gunner, first-class,  employed by the Imperial Japanese Army. Follow your <b>Officer's</b> orders! Provide support and supressing fire for your comrades!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_HIGH)


	return TRUE

/datum/job/japanese/ija_pacific_sniper
	title = " Senmeina no Hito"
	en_meaning = "Sniper"
	rank_abbreviation = ""

	spawn_location = "JoinLateJP"
	uses_squads = TRUE
	is_ww2 = TRUE
	is_pacific = TRUE

	min_positions = 2
	max_positions = 10

/datum/job/japanese/ija_pacific_sniper/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_summer(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/japanese(H), slot_r_store)

//head
	var/randhead = rand(1,3)
	if (randhead == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japhelm(H), slot_head)
	else if (randhead == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japhelm_bandana(H), slot_head)
	else if (randhead == 3)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka99/sniper(H), slot_shoulder)
	H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/jap/ww2soldier(H), slot_belt)
	give_random_name(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/rank/jap_jotoheih = new /obj/item/clothing/accessory/rank/jap_jotohei(null)
	uniform.attackby(jap_jotoheih, H)
	H.s_tone = rand(-32,-24)
	H.add_note("Role", "You are a <b>[title]</b>, a sniper, 1st class, employed by the Imperial Japanese Army. Follow your <b>Officer's</b> orders and take out valuable targets from a range!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_VERY_HIGH) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////NAVY////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/japanese/ijn_captain
	title = "Kaigun-Dai-i"
	en_meaning = "Navy Lieutenant"
	rank_abbreviation = "Ka-Dai"


	spawn_location = "JoinLateJPCap"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_ww2 = TRUE
	is_navy = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/japanese/ijn_captain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_snlf(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap_snlf(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/ww2/nambu(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/japanese_officer(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/japanese(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/katana(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	world << "<b><big>[H.real_name] is the Lieutenant of the Japanese Forces!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, the highest ranking officer present. Your job is to command the company.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/japanese/ijn_lieutenant
	title = "Kaigun-Chui"
	en_meaning = "Sub-Lieutenant"
	rank_abbreviation = "Slt."


	spawn_location = "JoinLateJPLT"
	whitelisted = TRUE
	is_commander = TRUE
	is_officer = TRUE
	is_ww2 = TRUE
	is_navy = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/japanese/ijn_lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_snlf(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap_snlf(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/ww2/nambu(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/japanese_officer(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/japanese(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/katana(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	world << "<b><big>[H.real_name] is the Sub-Lieutenant of the Japanese Forces!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, the 2nd highest ranking officer present. Your job is to command half of the forces.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/japanese/ijn_lieutenant2
	title = "Kaigun-Shoi"
	en_meaning = "Ensign"
	rank_abbreviation = "En."


	spawn_location = "JoinLateJPLT"
	whitelisted = TRUE
	is_commander = TRUE
	is_officer = TRUE
	is_ww2 = TRUE
	is_navy = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/japanese/ijn_lieutenant2/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_snlf(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap_snlf(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/ww2/nambu(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/japanese_officer(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/japanese(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/katana(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	world << "<b><big>[H.real_name] is the Ensign of the Japanese Forces!</big></b>"
	H.add_note("Role", "You are a <b>[title]</b>, the 3rd highest ranking officer present. Your job is to command half of the forces.")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/japanese/ijn_sergeant
	title = "Kaigun Nitoheiso"
	en_meaning = "Petty Officer 2nd Class"
	rank_abbreviation = "Niso."

	spawn_location = "JoinLateJP"
	is_officer = TRUE
	uses_squads = TRUE
	is_squad_leader = TRUE
	is_ww2 = TRUE
	is_navy = TRUE
	min_positions = 1
	max_positions = 4

/datum/job/japanese/ijn_sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_snlf(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap_snlf(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/ww2/nambu(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka99(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/katana(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/jap/ww2soldier(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/katana/fullh = new /obj/item/clothing/accessory/storage/sheath/katana/full(null)
	uniform.attackby(fullh, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	H.add_note("Role", "You are a <b>[title]</b>, a petty officer leading a squad. Organize your group according to your <b>Superiors</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/japanese/ijn_doctor
	title = "Kaigun Gun-i"
	en_meaning = "Doctor"
	rank_abbreviation = "Gun-i"

	spawn_location = "JoinLateJPDoc"

	is_medic = TRUE
	is_ww2 = TRUE
	is_navy = TRUE

	min_positions = 1
	max_positions = 2

/datum/job/japanese/ijn_doctor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_snlf(H), slot_w_uniform) // for now
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap_snlf(H), slot_head)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/doctor(H), slot_wear_suit)

	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/surgery(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	H.add_note("Role", "You are a <b>[title]</b>, the most qualified medic present, and you are in charge of keeping the soldiers healthy.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_VERY_HIGH)

	return TRUE
/datum/job/japanese/ijn_medic
	title = "Kaigun Sento-i"
	en_meaning = "Medic"
	rank_abbreviation = "Sen-i"

	spawn_location = "JoinLateJPDoc"
	uses_squads = TRUE
	is_ww2 = TRUE
	is_navy = TRUE


	is_medic = TRUE
	min_positions = 2
	max_positions = 6

/datum/job/japanese/ijn_medic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_snlf(H), slot_w_uniform) // for now
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap_snlf(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka99(H), slot_shoulder)

	H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/jap/ww2soldier(H), slot_belt)
	H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/firstaid/adv(H), slot_back)
//other
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	give_random_name(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/redcross = new /obj/item/clothing/accessory/armband/redcross(null)
	uniform.attackby(redcross, H)
	H.s_tone = rand(-32,-24)
	H.add_note("Role", "You are a <b>[title]</b>, one of the most qualified medics present, and you are in charge of keeping the soldiers healthy.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_MEDIUM_LOW)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_VERY_HIGH)
	return TRUE

/datum/job/japanese/ijn_ww2infantry
	title = "Santosuihei"
	en_meaning = "Seaman First Class"
	rank_abbreviation = "San."

	spawn_location = "JoinLateJP"
	uses_squads = TRUE
	is_ww2 = TRUE
	is_navy = TRUE

	min_positions = 20
	max_positions = 100

/datum/job/japanese/ijn_ww2infantry/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_snlf(H), slot_w_uniform)

//head
	var/randhead = rand(1,2)
	if (randhead == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japhelm_snlf(H), slot_head)
	else if (randhead == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap_snlf(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka99(H), slot_shoulder)
	H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/jap/ww2soldier(H), slot_belt)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	H.add_note("Role", "You are a <b>[title]</b>, a simple seaman third-class  employed by the Imperial Japanese Navy. Follow your <b>Officer's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE

/datum/job/japanese/ijn_machinegunner
	title = "Hoshu"
	en_meaning = "Machinegunner"
	rank_abbreviation = "Nisu."

	spawn_location = "JoinLateJP"
	uses_squads = TRUE
	is_ww2 = TRUE
	is_navy = TRUE
	min_positions = 2
	max_positions = 4

/datum/job/japanese/ijn_machinegunner/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_snlf(H), slot_w_uniform)

//head
	var/randhead = rand(1,2)
	if (randhead == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japhelm_snlf(H), slot_head)
	else if (randhead == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap_snlf(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/type99(H), slot_shoulder)
	H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/jap/ww2soldier99(H), slot_belt)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/rank/jap_ittoheih = new /obj/item/clothing/accessory/rank/jap_ittohei(null)
	uniform.attackby(jap_ittoheih, H)
	H.add_note("Role", "You are a <b>[title]</b>, a machine gunner, second-class,  employed by the Imperial Japanese Navy. Follow your <b>Officer's</b> orders! Provide support and supressing fire for your comrades!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_VERY_HIGH)


	return TRUE

/datum/job/japanese/ijn_machinegunner_assistant
	title = " Danyaku Mochinushi"
	en_meaning = " Ammo Bearer"
	rank_abbreviation = "Nisu."

	spawn_location = "JoinLateJP"
	uses_squads = TRUE
	is_ww2 = TRUE
	is_navy = TRUE
	min_positions = 2
	max_positions = 4

/datum/job/japanese/ijn_machinegunner_assistant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_snlf(H), slot_w_uniform)

//head
	var/randhead = rand(1,2)
	if (randhead == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japhelm_snlf(H), slot_head)
	else if (randhead == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap_snlf(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka99(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/jap/ww2soldier(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/ww2/jap/ammo_crate/full(H), slot_back)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/rank/jap_ittoheih = new /obj/item/clothing/accessory/rank/jap_ittohei(null)
	uniform.attackby(jap_ittoheih, H)
	H.add_note("Role", "You are a <b>[title]</b>, an assistant machine gunner, second-class,  employed by the Imperial Japanese Navy. Follow your <b>Officer's</b> orders! Provide support to the machine gunner! Carry the ammo!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_MEDIUM_HIGH) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("machinegun", STAT_VERY_HIGH)


	return TRUE

/datum/job/japanese/ijn_sniper
	title = "Kaigun Senmeina no Hito"
	en_meaning = "Sniper"
	rank_abbreviation = "Nisu."

	spawn_location = "JoinLateJP"
	uses_squads = TRUE
	is_ww2 = TRUE
	is_navy = TRUE

	min_positions = 1
	max_positions = 8

/datum/job/japanese/ijn_sniper/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_snlf(H), slot_w_uniform)

//head
	var/randhead = rand(1,2)
	if (randhead == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japhelm_snlf(H), slot_head)
	else if (randhead == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap_snlf(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka99/sniper(H), slot_shoulder)
	H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/jap/ww2soldier(H), slot_belt)
	give_random_name(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/rank/jap_jotoheih = new /obj/item/clothing/accessory/rank/jap_jotohei(null)
	uniform.attackby(jap_jotoheih, H)
	H.s_tone = rand(-32,-24)
	H.add_note("Role", "You are a <b>[title]</b>, a sniper, 2nd class, employed by the Imperial Japanese Navy. Follow your <b>Officer's</b> orders and take out valuable targets from a range!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_VERY_HIGH) //muskets
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL) //not used
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL) //not used
	H.setStat("medical", STAT_MEDIUM_LOW)


	return TRUE