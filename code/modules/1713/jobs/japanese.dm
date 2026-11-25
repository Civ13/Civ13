/datum/job/japanese
	faction = "Human"

/datum/job/japanese/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_japanese_name(H.gender)
	H.real_name = H.name
	var/new_hair = "Black"
	var/hex_hair = hair_colors[new_hair]
	H.r_hair = hex2num(copytext(hex_hair, 2, 4))
	H.g_hair = hex2num(copytext(hex_hair, 4, 6))
	H.b_hair = hex2num(copytext(hex_hair, 6, 8))
	H.r_facial = hex2num(copytext(hex_hair, 2, 4))
	H.g_facial = hex2num(copytext(hex_hair, 4, 6))
	H.b_facial = hex2num(copytext(hex_hair, 6, 8))
	if (!H.f_style == "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee" && H.f_style != "Watson Mustache")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee","Watson Mustache")
	if(H.h_style != "Bald" && H.h_style != "Crewcut" && H.h_style != "Undercut" && H.h_style != "Short Hair" && H.h_style != "Cut Hair" && H.h_style != "Skinhead" && H.h_style != "Average Joe" && H.h_style != "Fade" && H.h_style != "Combover" && H.h_style != "Father")
		H.h_style = pick("Bald","Crewcut","Undercut","Short Hair","Cut Hair","Skinhead","Average Joe","Fade","Combover","Father")
/datum/job/japanese/captain
	title = "Rikugun-Tai-i"
	en_meaning = "Army Captain"
	rank_abbreviation = "Ri-Tai"
	is_russojapwar = TRUE
	allowed_maps = list(MAP_HILL_203, MAP_PORT_ARTHUR)

	spawn_location = "JoinLateJPCap"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE



	min_positions = 1
	max_positions = 1
/datum/job/japanese/captain/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_HIGH, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
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
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")
	to_chat(world, "<big><b>[H.real_name] is the Captain of the Japanese Forces!</b></big>")
	H.add_note("Role", "You are a <b>[title]</b>, the highest ranking officer present. Your job is to command the company.")
	apply_job_stats(H)
	return TRUE

/datum/job/japanese/lieutenant
	title = "Rikugun-Chui"
	en_meaning = "1st Lieutenant"
	rank_abbreviation = "1lt."
	is_russojapwar = TRUE
	allowed_maps = list(MAP_HILL_203, MAP_PORT_ARTHUR)

	spawn_location = "JoinLateJPCap"
	whitelisted = TRUE

	is_commander = TRUE
	is_officer = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/japanese/lieutenant/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/japanese/lieutenant/job_loadout = list(
	/obj/item/clothing/shoes/japboots = slot_shoes,
	/obj/item/clothing/under/japoffuni = slot_w_uniform,
	/obj/item/clothing/suit/storage/coat/japcoat2 = slot_wear_suit,
	/obj/item/clothing/head/japoffcap = slot_head,
	/obj/item/weapon/gun/projectile/pistol/nambu = slot_l_hand,
	/obj/item/ammo_magazine/c8mmnambu = slot_l_store,
	/obj/item/weapon/key/japanese = slot_r_store,
	/obj/item/weapon/attachment/scope/adjustable/binoculars = slot_l_store,
	/obj/item/weapon/material/sword/katana = slot_belt)
/datum/job/japanese/lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")
	to_chat(world, "<big><b>[H.real_name] is the 1st Lieutenant of the Japanese forces!</b></big>")
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the troops and their orders. The whole operation relies on you!")
	apply_job_stats(H)
	return TRUE

/datum/job/japanese/lieutenant2
	title = "Rikugun-Shoi"
	en_meaning = "2nd Lieutenant"
	rank_abbreviation = "2lt."
	is_russojapwar = TRUE
	allowed_maps = list(MAP_HILL_203, MAP_PORT_ARTHUR)

	spawn_location = "JoinLateJPCap"
	whitelisted = TRUE

	is_commander = TRUE
	is_officer = TRUE


	min_positions = 1
	max_positions = 1

/datum/job/japanese/lieutenant2/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/japanese/lieutenant2/job_loadout = list(
	/obj/item/clothing/shoes/japboots = slot_shoes,
	/obj/item/clothing/under/japoffuni = slot_w_uniform,
	/obj/item/clothing/suit/storage/coat/japcoat2 = slot_wear_suit,
	/obj/item/clothing/head/japoffcap = slot_head,
	/obj/item/weapon/gun/projectile/pistol/nambu = slot_l_hand,
	/obj/item/ammo_magazine/c8mmnambu = slot_l_store,
	/obj/item/weapon/key/japanese = slot_r_store,
	/obj/item/weapon/attachment/scope/adjustable/binoculars = slot_l_store,
	/obj/item/weapon/material/sword/katana = slot_belt)
/datum/job/japanese/lieutenant2/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")
	to_chat(world, "<big><b>[H.real_name] is the 2nd Lieutenant of the Japanese forces!</b></big>")
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the troops and their orders. Second to 1st Lieutenant. The whole operation relies on you and your orders!")
	apply_job_stats(H)
	return TRUE

/datum/job/japanese/sergeant
	title = "Gunso"
	en_meaning = "Sergeant"
	rank_abbreviation = "Gunso"
	is_russojapwar = TRUE
	spawn_location = "JoinLateJP"
	is_squad_leader = TRUE
	uses_squads = TRUE
	allowed_maps = list(MAP_HILL_203, MAP_PORT_ARTHUR)

	min_positions = 1
	max_positions = 10

/datum/job/japanese/sergeant/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_HIGH, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/japanese/sergeant/job_loadout = list(
	/obj/item/clothing/shoes/japboots = slot_shoes,
	/obj/item/clothing/under/japuni = slot_w_uniform,
	/obj/item/clothing/suit/storage/coat/japcoat = slot_wear_suit,
	/obj/item/clothing/head/japoffcap = slot_head,
	/obj/item/weapon/gun/projectile/revolver/t26_revolver = slot_l_hand,
	/obj/item/ammo_magazine/c9mm_jap_revolver = slot_l_store,
	/obj/item/weapon/gun/projectile/boltaction/arisaka30 = slot_shoulder,
	/obj/item/weapon/attachment/scope/adjustable/binoculars = slot_l_store,
	/obj/item/weapon/material/sword/katana = slot_belt)
/datum/job/japanese/sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")
	H.add_note("Role", "You are a <b>[title]</b>, a sergeant leading a squad. Organize your group according to the <b>Captain or Leiutenant's</b> orders!")
	apply_job_stats(H)
	return TRUE

/datum/job/japanese/doctor
	title = "Gun-i"
	en_meaning = "Doctor"
	rank_abbreviation = "Gun-i"
	is_russojapwar = TRUE
	spawn_location = "JoinLateJPDoc"
	allowed_maps = list(MAP_HILL_203, MAP_PORT_ARTHUR)

	is_medic = TRUE


	min_positions = 1
	max_positions = 10

/datum/job/japanese/doctor/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_NORMAL, "medical" = STAT_VERY_HIGH)
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
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")
	H.add_note("Role", "You are a <b>[title]</b>, the most qualified medic present, and you are in charge of keeping the soldiers healthy.")
	apply_job_stats(H)
	return TRUE


/datum/job/japanese/sniper
	title = " Ittohei"
	en_meaning = "Soldier First-class"
	rank_abbreviation = "Itto."
	is_russojapwar = TRUE
	spawn_location = "JoinLateJP"
	uses_squads = TRUE
	allowed_maps = list(MAP_HILL_203, MAP_PORT_ARTHUR)


	min_positions = 3
	max_positions = 10

/datum/job/japanese/sniper/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/japanese/sniper/job_loadout = list(
	/obj/item/clothing/shoes/japboots = slot_shoes,
	/obj/item/clothing/under/japuni = slot_w_uniform,
	/obj/item/clothing/head/japcap = slot_head,
	/obj/item/clothing/suit/storage/coat/japcoat = slot_wear_suit,
	/obj/item/weapon/gun/projectile/boltaction/arisaka35 = slot_shoulder)
/datum/job/japanese/sniper/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)

	H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/jap/soldier(H), slot_belt)

	H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack/bint(H), slot_l_store)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")
	H.add_note("Role", "You are a <b>[title]</b>, a sharpshooter promoted to soldier first-class employed by the Imperial Japanese Army. Follow your <b>Officer's</b> orders!")
	apply_job_stats(H)
	return TRUE

/datum/job/japanese/whitesash_infantry
	title = "Shiro Nitohei"
	en_meaning = "Soldier Second-class"
	rank_abbreviation = "Ni."
	is_russojapwar = TRUE
	spawn_location = "JoinLateJP"
	uses_squads = TRUE
	allowed_maps = list(MAP_HILL_203, MAP_PORT_ARTHUR)


	min_positions = 6
	max_positions = 200

/datum/job/japanese/whitesash_infantry/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/japanese/whitesash_infantry/job_loadout = list(
	/obj/item/clothing/shoes/japboots = slot_shoes,
	/obj/item/clothing/under/japuni = slot_w_uniform,
	/obj/item/clothing/head/japcap = slot_head,
	/obj/item/weapon/gun/projectile/boltaction/arisaka30 = slot_shoulder)
/datum/job/japanese/whitesash_infantry/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)

	var/obj/item/clothing/accessory/white_sash = new /obj/item/clothing/accessory/white_sash(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(white_sash, H)

	H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/jap/soldier(H), slot_belt)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")
	H.add_note("Role", "You are a <b>[title]</b>, a simple soldier second-class employed by the Imperial Japanese Army. Follow your <b>Officer's</b> orders!")
	apply_job_stats(H)
	return TRUE

//////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////WW2///////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////
/datum/job/japanese/ija_captain
	title = "IJA Rikugun-Tai-i"
	en_meaning = "Army Captain"
	rank_abbreviation = "Ri-Tai"
	allowed_maps = list(MAP_INTRAMUROS, MAP_IWO_JIMA, MAP_KHALKHYN_GOL, MAP_MARCO_POLO_BRIDGE, MAP_NANJING, MAP_NANKOU, MAP_RIZAL_STADIUM)


	spawn_location = "JoinLateJPCap"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_ww2 = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/japanese/ija_captain/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_HIGH, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/japanese/ija_captain/job_loadout = list(
	/obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2 = slot_shoes,
	/obj/item/clothing/under/ww2/japoffuni = slot_w_uniform,
	/obj/item/clothing/head/ww2/japoffcap = slot_head,
	/obj/item/weapon/gun/projectile/pistol/ww2/nambu = slot_l_hand,
	/obj/item/weapon/key/japanese = slot_r_store,
	/obj/item/weapon/attachment/scope/adjustable/binoculars = slot_l_store,
	/obj/item/weapon/material/sword/katana = slot_belt)
/datum/job/japanese/ija_captain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/weapon/storage/belt/keychain/KC = new/obj/item/weapon/storage/belt/keychain(H)
	var/obj/item/weapon/key/japanese/G1 = new/obj/item/weapon/key/japanese(null)
	var/obj/item/weapon/key/japanese_officer/G2 = new/obj/item/weapon/key/japanese_officer(null)
	KC.attackby(G1,H)
	KC.attackby(G2,H)
	H.equip_to_slot_or_del(KC, slot_wear_id)
	var/obj/item/clothing/accessory/rank/jap_taii = new /obj/item/clothing/accessory/rank/jap_taii(null)
	uniform.attackby(jap_taii, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")
	to_chat(world, "<big><b>[H.real_name] is the Captain of the Japanese Forces!</b></big>")
	H.add_note("Role", "You are a <b>[title]</b>, the highest ranking officer present. Your job is to command the company.")
	apply_job_stats(H)


	return TRUE

/datum/job/japanese/ija_lieutenant
	title = "IJA Rikugun-Chui"
	en_meaning = "1st Lieutenant"
	rank_abbreviation = "1lt."
	allowed_maps = list(MAP_INTRAMUROS, MAP_IWO_JIMA, MAP_KHALKHYN_GOL, MAP_MARCO_POLO_BRIDGE, MAP_NANJING, MAP_NANKOU, MAP_RIZAL_STADIUM)


	spawn_location = "JoinLateJPCap"
	whitelisted = TRUE
	is_commander = TRUE
	is_officer = TRUE
	is_ww2 = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/japanese/ija_lieutenant/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/japanese/ija_lieutenant/job_loadout = list(
	/obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2 = slot_shoes,
	/obj/item/clothing/under/ww2/japoffuni = slot_w_uniform,
	/obj/item/clothing/head/ww2/japoffcap = slot_head,
	/obj/item/weapon/gun/projectile/pistol/ww2/nambu = slot_l_hand,
	/obj/item/weapon/key/japanese = slot_r_store,
	/obj/item/weapon/attachment/scope/adjustable/binoculars = slot_l_store,
	/obj/item/weapon/material/sword/katana = slot_belt)
/datum/job/japanese/ija_lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/weapon/storage/belt/keychain/KC = new/obj/item/weapon/storage/belt/keychain(H)
	var/obj/item/weapon/key/japanese/G1 = new/obj/item/weapon/key/japanese(null)
	var/obj/item/weapon/key/japanese_officer/G2 = new/obj/item/weapon/key/japanese_officer(null)
	KC.attackby(G1,H)
	KC.attackby(G2,H)
	H.equip_to_slot_or_del(KC, slot_wear_id)
	give_random_name(H)
	var/obj/item/clothing/accessory/rank/jap_1lt = new /obj/item/clothing/accessory/rank/jap_1lt(null)
	uniform.attackby(jap_1lt, H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")
	to_chat(world, "<big><b>[H.real_name] is the 1st Lieutenant of the Japanese forces!</b></big>")
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the troops and their orders. The whole operation relies on you!")
	apply_job_stats(H)


	return TRUE

/datum/job/japanese/ija_lieutenant2
	title = "IJA Rikugun-Shoi"
	en_meaning = "2nd Lieutenant"
	rank_abbreviation = "2lt."
	allowed_maps = list(MAP_INTRAMUROS, MAP_IWO_JIMA, MAP_KHALKHYN_GOL, MAP_MARCO_POLO_BRIDGE, MAP_NANJING, MAP_NANKOU, MAP_RIZAL_STADIUM)


	spawn_location = "JoinLateJPCap"
	whitelisted = TRUE
	is_commander = TRUE
	is_officer = TRUE
	is_ww2 = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/japanese/ija_lieutenant2/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/japanese/ija_lieutenant2/job_loadout = list(
	/obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2 = slot_shoes,
	/obj/item/clothing/under/ww2/japoffuni = slot_w_uniform,
	/obj/item/clothing/head/ww2/japoffcap = slot_head,
	/obj/item/weapon/gun/projectile/pistol/ww2/nambu = slot_l_hand,
	/obj/item/weapon/key/japanese = slot_r_store,
	/obj/item/weapon/attachment/scope/adjustable/binoculars = slot_l_store,
	/obj/item/weapon/material/sword/katana = slot_belt)
/datum/job/japanese/ija_lieutenant2/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/weapon/storage/belt/keychain/KC = new/obj/item/weapon/storage/belt/keychain(H)
	var/obj/item/weapon/key/japanese/G1 = new/obj/item/weapon/key/japanese(null)
	var/obj/item/weapon/key/japanese_officer/G2 = new/obj/item/weapon/key/japanese_officer(null)
	KC.attackby(G1,H)
	KC.attackby(G2,H)
	H.equip_to_slot_or_del(KC, slot_wear_id)
	give_random_name(H)
	var/obj/item/clothing/accessory/rank/jap_2lt = new /obj/item/clothing/accessory/rank/jap_2lt(null)
	uniform.attackby(jap_2lt, H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")
	to_chat(world, "<big><b>[H.real_name] is the 2nd Lieutenant of the Japanese forces!</b></big>")
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the troops and their orders. Second to 1st Lieutenant. The whole operation relies on you and your orders!")
	apply_job_stats(H)


	return TRUE

/datum/job/japanese/ija_sergeant
	title = "IJA Gunso"
	en_meaning = "Sergeant"
	rank_abbreviation = "Gu."
	allowed_maps = list(MAP_INTRAMUROS, MAP_IWO_JIMA, MAP_KHALKHYN_GOL, MAP_MARCO_POLO_BRIDGE, MAP_NANJING, MAP_NANKOU, MAP_RIZAL_STADIUM)

	spawn_location = "JoinLateJP"
	uses_squads = TRUE
	is_squad_leader = TRUE
	is_ww2 = TRUE
	min_positions = 1
	max_positions = 4

/datum/job/japanese/ija_sergeant/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_HIGH, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/japanese/ija_sergeant/job_loadout = list(
	/obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/puttees = slot_shoes,
	/obj/item/clothing/under/ww2/japuni = slot_w_uniform,
	/obj/item/clothing/head/ww2/japcap = slot_head,
	/obj/item/weapon/gun/projectile/pistol/ww2/nambu = slot_l_hand)
/datum/job/japanese/ija_sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	if (map.ID == MAP_NANKOU || map.ID == MAP_NANJING || map.ID == MAP_MARCO_POLO_BRIDGE)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka38(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/jap/soldier(H), slot_belt)
	else if (map.ID != MAP_NANKOU && map.ID != MAP_NANJING && prob(5))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/type100(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/jap/ww2soldier100(H), slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka99(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/jap/ww2soldier(H), slot_belt)
	if (map.ID == MAP_MARCO_POLO_BRIDGE)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/ww2/jap/full(H), slot_back)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/katana/fullh = new /obj/item/clothing/accessory/storage/sheath/katana/full(null)
	uniform.attackby(fullh, H)
	var/obj/item/weapon/storage/belt/keychain/KC = new/obj/item/weapon/storage/belt/keychain(H)
	var/obj/item/weapon/key/japanese/G1 = new/obj/item/weapon/key/japanese(null)
	KC.attackby(G1,H)
	H.equip_to_slot_or_del(KC, slot_wear_id)
	give_random_name(H)
	var/obj/item/clothing/accessory/rank/jap_gunso = new /obj/item/clothing/accessory/rank/jap_gunso(null)
	uniform.attackby(jap_gunso, H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")
	H.add_note("Role", "You are a <b>[title]</b>, a sergeant leading a squad. Organize your group according to the <b>Captain or Leiutenant's</b> orders!")
	apply_job_stats(H)


	return TRUE

/datum/job/japanese/ija_doctor
	title = "IJA Gun-i"
	en_meaning = "Doctor"
	rank_abbreviation = "Gun-i"
	allowed_maps = list(MAP_INTRAMUROS, MAP_IWO_JIMA, MAP_KHALKHYN_GOL, MAP_MARCO_POLO_BRIDGE, MAP_NANJING, MAP_NANKOU, MAP_RIZAL_STADIUM)

	spawn_location = "JoinLateJPDoc"

	is_medic = TRUE
	is_ww2 = TRUE

	min_positions = 2
	max_positions = 4

/datum/job/japanese/ija_doctor/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_NORMAL, "medical" = STAT_VERY_HIGH)
/datum/job/japanese/ija_doctor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/puttees(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni(H), slot_w_uniform) // for now
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap(H), slot_head)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/doctor(H), slot_wear_suit)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/surgery(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (map.ID == MAP_INTRAMUROS)
		var/obj/item/weapon/storage/belt/keychain/KC = new/obj/item/weapon/storage/belt/keychain(H)
		var/obj/item/weapon/key/japanese/G1 = new/obj/item/weapon/key/japanese(null)
		KC.attackby(G1,H)
		H.equip_to_slot_or_del(KC, slot_wear_id)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/flashlight/japflashlight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/rank/jap_2lt = new /obj/item/clothing/accessory/rank/jap_2lt(null)
	uniform.attackby(jap_2lt, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")
	H.add_note("Role", "You are a <b>[title]</b>, the most qualified medic present, and you are in charge of keeping the soldiers healthy.")
	apply_job_stats(H)

	return TRUE
/datum/job/japanese/ija_medic
	title = "Sento-i"
	en_meaning = "Medic"
	rank_abbreviation = "Sen-i"
	allowed_maps = list(MAP_INTRAMUROS, MAP_IWO_JIMA, MAP_KHALKHYN_GOL, MAP_MARCO_POLO_BRIDGE, MAP_NANJING, MAP_NANKOU, MAP_RIZAL_STADIUM)

	spawn_location = "JoinLateJPDoc"
	uses_squads = TRUE
	is_ww2 = TRUE


	is_medic = TRUE
	min_positions = 2
	max_positions = 10

/datum/job/japanese/ija_medic/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_NORMAL, "medical" = STAT_VERY_HIGH)
/datum/job/japanese/ija_medic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/puttees(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni(H), slot_w_uniform) // for now
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japhelm_med(H), slot_head)
//back
	if (map.ID == MAP_NANKOU || map.ID == MAP_NANJING || map.ID == MAP_MARCO_POLO_BRIDGE)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka38(H), slot_shoulder)
		H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/jap/soldier(H), slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka99(H), slot_shoulder)
		H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/jap/ww2soldier(H), slot_belt)
//other
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/firstaid/adv(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	if (map.ID == MAP_MARCO_POLO_BRIDGE)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/ww2/jap/full(H), slot_back)

	if (map.ID == MAP_INTRAMUROS)
		var/obj/item/weapon/storage/belt/keychain/KC = new/obj/item/weapon/storage/belt/keychain(H)
		var/obj/item/weapon/key/japanese/G1 = new/obj/item/weapon/key/japanese(null)
		KC.attackby(G1,H)
		H.equip_to_slot_or_del(KC, slot_wear_id)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/flashlight/japflashlight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/rank/jap_jotohei = new /obj/item/clothing/accessory/rank/jap_jotohei(null)
	uniform.attackby(jap_jotohei, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")
	H.add_note("Role", "You are a <b>[title]</b>, the most qualified medic present, and you are in charge of keeping the soldiers healthy.")
	apply_job_stats(H)
	return TRUE

/datum/job/japanese/ija_ww2infantry
	title = "Ittohei"
	en_meaning = "Soldier First-class"
	rank_abbreviation = "Itto."
	allowed_maps = list(MAP_INTRAMUROS, MAP_IWO_JIMA, MAP_KHALKHYN_GOL, MAP_MARCO_POLO_BRIDGE, MAP_NANJING, MAP_NANKOU, MAP_RIZAL_STADIUM)

	spawn_location = "JoinLateJP"
	uses_squads = TRUE
	is_ww2 = TRUE

	min_positions = 20
	max_positions = 100

/datum/job/japanese/ija_ww2infantry/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/japanese/ija_ww2infantry/job_loadout = list(
	/obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/puttees = slot_shoes,
	/obj/item/clothing/under/ww2/japuni = slot_w_uniform)
/datum/job/japanese/ija_ww2infantry/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)

//head
	if (map.ID == MAP_MARCO_POLO_BRIDGE)
		if (prob(90))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap(H), slot_head)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japsakurahelm(H), slot_head)
	else
		if (prob(70))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japhelm(H), slot_head)
		else if (prob(10))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japhelm/bandana(H), slot_head)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap(H), slot_head)
//back
	var/randweap = rand(1,2)
	if (map.ID == MAP_NANKOU || map.ID == MAP_NANJING || map.ID == MAP_MARCO_POLO_BRIDGE)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka38(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/jap/soldier(H), slot_belt)
	else
		if (randweap == 1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka99(H), slot_shoulder)
			H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/jap/ww2soldier(H), slot_belt)
		else if (randweap == 2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka38(H), slot_shoulder)
			H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/jap/soldier(H), slot_belt)
	if (map.ID == MAP_MARCO_POLO_BRIDGE)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/ww2/jap/full(H), slot_back)
	give_random_name(H)
	if (map.ID == MAP_INTRAMUROS)
		var/obj/item/weapon/storage/belt/keychain/KC = new/obj/item/weapon/storage/belt/keychain(H)
		var/obj/item/weapon/key/japanese/G1 = new/obj/item/weapon/key/japanese(null)
		KC.attackby(G1,H)
		H.equip_to_slot_or_del(KC, slot_wear_id)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/flashlight/japflashlight(H), slot_wear_id)
	H.s_tone = rand(-32,-24)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/found = FALSE
	for (var/i in whitelist_list)
		var/temp_ckey = lowertext(i)
		temp_ckey = replacetext(temp_ckey," ", "")
		temp_ckey = replacetext(temp_ckey,"_", "")
		if (temp_ckey == H.client.ckey)
			found = TRUE
	if (found == TRUE)
		var/obj/item/clothing/accessory/rank/jap_jotohei = new /obj/item/clothing/accessory/rank/jap_jotohei(null)
		uniform.attackby(jap_jotohei, H)
	else
		var/obj/item/clothing/accessory/rank/jap_ittohei = new /obj/item/clothing/accessory/rank/jap_ittohei(null)
		uniform.attackby(jap_ittohei, H)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")
	H.add_note("Role", "You are a <b>[title]</b>, a simple soldier second-class  employed by the Imperial Japanese Army. Follow your <b>Officer's</b> orders!")
	apply_job_stats(H)


	return TRUE

/datum/job/japanese/ija_ww2ATunit
	title = "Nitohei Taisensha"
	en_meaning = "Anti Tank Unit"
	rank_abbreviation = "Ni."
	allowed_maps = list(MAP_IWO_JIMA, MAP_KENOBI, MAP_KHALKHYN_GOL, MAP_RIZAL_STADIUM)

	spawn_location = "JoinLateJP"
	is_ww2 = TRUE
	is_tanker = TRUE

	min_positions = 4
	max_positions = 12


/datum/job/japanese/ija_ww2ATunit/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_korean_name(H.gender)
	H.real_name = H.name
/datum/job/japanese/ija_ww2ATunit/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/japanese/ija_ww2ATunit/job_loadout = list(
	/obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/puttees = slot_shoes,
	/obj/item/clothing/under/ww2/japuni = slot_w_uniform,
	/obj/item/clothing/head/ww2/jap_headband = slot_head)
/datum/job/japanese/ija_ww2ATunit/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
//back
	H.equip_to_slot_or_del(new 	/obj/item/weapon/grenade/suicide_vest/kamikaze(H), slot_belt)

	give_random_name(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/rank/jap_nitohei/jap_nitohei = new/obj/item/clothing/accessory/rank/jap_nitohei(null)
	uniform.attackby(jap_nitohei, H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")
	H.add_note("Role", "You are a <b>[title]</b>, an Anti Tank Suicide Unit  employed by the Imperial Japanese Army. Follow your <b>Officer's</b> orders!")
	apply_job_stats(H)


	return TRUE



/datum/job/japanese/ija_machinegunner
	title = "Taiho"
	en_meaning = "Machinegunner"
	rank_abbreviation = "Itto."
	allowed_maps = list(MAP_INTRAMUROS, MAP_IWO_JIMA, MAP_KHALKHYN_GOL, MAP_MARCO_POLO_BRIDGE, MAP_NANJING, MAP_NANKOU, MAP_RIZAL_STADIUM)

	spawn_location = "JoinLateJP"
	uses_squads = TRUE
	is_ww2 = TRUE

	min_positions = 4
	max_positions = 15

/datum/job/japanese/ija_machinegunner/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_HIGH)
/datum/job/japanese/ija_machinegunner/job_loadout = list(
	/obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/puttees = slot_shoes,
	/obj/item/clothing/under/ww2/japuni = slot_w_uniform)
/datum/job/japanese/ija_machinegunner/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)

//head
	if (map.ID == MAP_MARCO_POLO_BRIDGE)
		if (prob(90))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap(H), slot_head)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japsakurahelm(H), slot_head)
	else
		if (prob(70))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japhelm(H), slot_head)
		else if (prob(10))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japhelm/bandana(H), slot_head)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap(H), slot_head)
//back
	if (map.ID == MAP_NANKOU || map.ID == MAP_NANJING || map.ID == MAP_MARCO_POLO_BRIDGE)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/type96(H), slot_shoulder)
		H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/jap/ww2soldier96(H), slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/type99(H), slot_shoulder)
		H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/jap/ww2soldier99(H), slot_belt)
	if (map.ID == MAP_MARCO_POLO_BRIDGE)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/ww2/jap/full(H), slot_back)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")
	if (map.ID == MAP_INTRAMUROS)
		var/obj/item/weapon/storage/belt/keychain/KC = new/obj/item/weapon/storage/belt/keychain(H)
		var/obj/item/weapon/key/japanese/G1 = new/obj/item/weapon/key/japanese(null)
		KC.attackby(G1,H)
		H.equip_to_slot_or_del(KC, slot_wear_id)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/flashlight/japflashlight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/rank/jap_jotohei = new /obj/item/clothing/accessory/rank/jap_jotohei(null)
	uniform.attackby(jap_jotohei, H)
	H.add_note("Role", "You are a <b>[title]</b>, a machine gunner, first-class,  employed by the Imperial Japanese Army. Follow your <b>Officer's</b> orders! Provide support and suppressing fire for your comrades!")
	apply_job_stats(H)


	return TRUE

/datum/job/japanese/ija_machinegunner_assistant
	title = " Fuku Taiho"
	en_meaning = "Assistant Machinegunner"
	rank_abbreviation = ""
	allowed_maps = list(MAP_INTRAMUROS, MAP_IWO_JIMA, MAP_KHALKHYN_GOL, MAP_MARCO_POLO_BRIDGE, MAP_NANJING, MAP_NANKOU, MAP_RIZAL_STADIUM)

	spawn_location = "JoinLateJP"
	uses_squads = TRUE
	is_ww2 = TRUE
	min_positions = 2
	max_positions = 4

/datum/job/japanese/ija_machinegunner_assistant/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_HIGH)
/datum/job/japanese/ija_machinegunner_assistant/job_loadout = list(
	/obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/puttees = slot_shoes,
	/obj/item/clothing/under/ww2/japuni = slot_w_uniform)
/datum/job/japanese/ija_machinegunner_assistant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)

//head
	if (map.ID == MAP_MARCO_POLO_BRIDGE)
		if (prob(90))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap(H), slot_head)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japsakurahelm(H), slot_head)
	else
		if (prob(70))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japhelm(H), slot_head)
		else if (prob(10))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japhelm/bandana(H), slot_head)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap(H), slot_head)
//back
	if (map.ID == MAP_NANKOU || map.ID == MAP_NANJING || map.ID == MAP_MARCO_POLO_BRIDGE)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka38(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/jap/soldier(H), slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka99(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/jap/ww2soldier(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/ww2/jap/ammo_crate/full(H), slot_back)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/rank/jap_jotohei = new /obj/item/clothing/accessory/rank/jap_jotohei(null)
	uniform.attackby(jap_jotohei, H)
	if (map.ID == MAP_INTRAMUROS)
		var/obj/item/weapon/storage/belt/keychain/KC = new/obj/item/weapon/storage/belt/keychain(H)
		var/obj/item/weapon/key/japanese/G1 = new/obj/item/weapon/key/japanese(null)
		KC.attackby(G1,H)
		H.equip_to_slot_or_del(KC, slot_wear_id)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/flashlight/japflashlight(H), slot_wear_id)
	H.add_note("Role", "You are a <b>[title]</b>, a machine gunner, first-class,  employed by the Imperial Japanese Army. Follow your <b>Officer's</b> orders! Provide support and suppressing fire for your comrades!")
	apply_job_stats(H)


	return TRUE

/datum/job/japanese/ija_sniper
	title = "Senmeina no Hito"
	en_meaning = "Sniper"
	rank_abbreviation = "Jo."
	allowed_maps = list(MAP_INTRAMUROS, MAP_IWO_JIMA, MAP_KHALKHYN_GOL, MAP_MARCO_POLO_BRIDGE, MAP_NANJING, MAP_NANKOU, MAP_RIZAL_STADIUM)

	spawn_location = "JoinLateJP"
	uses_squads = TRUE
	is_ww2 = TRUE

	min_positions = 2
	max_positions = 10

/datum/job/japanese/ija_sniper/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_VERY_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/japanese/ija_sniper/job_loadout = list(
	/obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/puttees = slot_shoes,
	/obj/item/clothing/under/ww2/japuni = slot_w_uniform)
/datum/job/japanese/ija_sniper/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)

//head
	if (map.ID == MAP_MARCO_POLO_BRIDGE)
		if (prob(90))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap(H), slot_head)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japsakurahelm(H), slot_head)
	else
		if (prob(70))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japhelm(H), slot_head)
		else if (prob(10))
			H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japhelm/bandana(H), slot_head)
		else
			H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap(H), slot_head)
//back
	if (map.ID == MAP_NANKOU || map.ID == MAP_NANJING)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka38/sniper(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/jap/soldier(H), slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka99/sniper(H), slot_shoulder)
		H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/jap/ww2soldier(H), slot_belt)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (map.ID == MAP_INTRAMUROS)
		var/obj/item/weapon/storage/belt/keychain/KC = new/obj/item/weapon/storage/belt/keychain(H)
		var/obj/item/weapon/key/japanese/G1 = new/obj/item/weapon/key/japanese(null)
		KC.attackby(G1,H)
		H.equip_to_slot_or_del(KC, slot_wear_id)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/flashlight/japflashlight(H), slot_wear_id)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")
	H.add_note("Role", "You are a <b>[title]</b>, a sniper, 1st class, employed by the Imperial Japanese Army. Follow your <b>Officer's</b> orders and take out valuable targets from a range!")
	apply_job_stats(H)


	return TRUE
/////////////////////////////////////////////////TANK CREW//////////////////////////////////////////////////////
/datum/job/japanese/ija_sergeant_tanker
	title = "Sensha Gunso"
	en_meaning = "Tank Sergeant"
	rank_abbreviation = "Gu."
	allowed_maps = list(MAP_IWO_JIMA, MAP_KENOBI, MAP_NANJING, MAP_RIZAL_STADIUM)

	spawn_location = "JoinLateJP"
	is_officer = TRUE
	is_tanker = TRUE
	is_ww2 = TRUE
	is_squad_leader = TRUE
	is_tankcom = TRUE
	uses_squads = TRUE
	whitelisted = TRUE
	min_positions = 1
	max_positions = 3

/datum/job/japanese/ija_sergeant_tanker/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_HIGH, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_MEDIUM_HIGH)
/datum/job/japanese/ija_sergeant_tanker/job_loadout = list(
	/obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/puttees = slot_shoes,
	/obj/item/clothing/under/ww2/japuni_tanker = slot_w_uniform,
	/obj/item/clothing/head/ww2/japcap = slot_head,
	/obj/item/weapon/gun/projectile/pistol/ww2/nambu = slot_l_hand,
	/obj/item/ammo_magazine/c8mmnambu = slot_l_store)
/datum/job/japanese/ija_sergeant_tanker/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	if (map.ID == MAP_NANKOU || map.ID == MAP_NANJING)
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka38(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/jap/soldier(H), slot_belt)
	else if (map.ID != MAP_NANKOU && map.ID != MAP_NANJING && prob(35))
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/type100(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/jap/ww2soldier100(H), slot_belt)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka99(H), slot_shoulder)
		H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/jap/ww2soldier(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/key/japanese(H), slot_r_store)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/japflashlight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/katana/fullh = new /obj/item/clothing/accessory/storage/sheath/katana/full(null)
	uniform.attackby(fullh, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")
	H.add_note("Role", "You are a <b>[title]</b>, a sergeant leading an armored squad. Organize your group according to the <b>Captain or Leiutenant's</b> orders!")
	apply_job_stats(H)


	return TRUE

/datum/job/japanese/ija_ww2_tanker
	title = "Senshahei"
	en_meaning = "Tanker"
	rank_abbreviation = ""
	allowed_maps = list(MAP_IWO_JIMA, MAP_KENOBI, MAP_NANJING, MAP_RIZAL_STADIUM)

	spawn_location = "JoinLateJP"
	is_tanker = TRUE
	is_ww2 = TRUE
	uses_squads = TRUE
	whitelisted = TRUE
	min_positions = 4
	max_positions = 8

/datum/job/japanese/ija_ww2_tanker/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_HIGH, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_MEDIUM_HIGH)
/datum/job/japanese/ija_ww2_tanker/job_loadout = list(
	/obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/puttees = slot_shoes,
	/obj/item/clothing/under/ww2/japuni_tanker = slot_w_uniform,
	/obj/item/clothing/head/helmet/ww2/japhelm_tanker = slot_head,
	/obj/item/weapon/key/japanese = slot_r_store,
	/obj/item/weapon/gun/projectile/pistol/ww2/nambu = slot_belt)
/datum/job/japanese/ija_ww2_tanker/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/flashlight/japflashlight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")
	H.add_note("Role", "You are a <b>[title]</b>, a tanker  employed by the Imperial Japanese Army. Follow your <b>Sergeant's</b> orders!")
	apply_job_stats(H)


	return TRUE



////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////WW2 JAPANESE PRISON//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/japanese/ija_camp_director
	title = "Horyoshuyojo-Cho"
	en_meaning = "POW Camp Director"
	rank_abbreviation = "Cho."
	allowed_maps = list(MAP_RIVER_KWAI)


	spawn_location = "JoinLateJPCap"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE

	is_ww2 = TRUE
	is_prison = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/japanese/ija_camp_director/job_stats = list("strength" = STAT_MAX, "crafting" = STAT_NORMAL, "rifle" = STAT_MAX, "dexterity" = STAT_MAX, "swords" = STAT_MAX, "pistol" = STAT_MAX, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/japanese/ija_camp_director/job_loadout = list(
	/obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/puttees = slot_shoes,
	/obj/item/clothing/under/ww2/japuni = slot_w_uniform,
	/obj/item/clothing/head/ww2/japoffcap = slot_head,
	/obj/item/weapon/gun/projectile/pistol/ww2/nambu = slot_l_hand,
	/obj/item/weapon/material/sword/katana = slot_r_hand,
	/obj/item/ammo_magazine/c8mmnambu = slot_r_store,
	/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars = slot_l_store,
	/obj/item/weapon/storage/belt/jap/camp_officer = slot_belt)
/datum/job/japanese/ija_camp_director/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	var/obj/item/clothing/accessory/rank/jap_taiih = new /obj/item/clothing/accessory/rank/jap_taii(null)
	uniform.attackby(jap_taiih, H)
	var/obj/item/weapon/storage/belt/keychain/KC = new/obj/item/weapon/storage/belt/keychain(H)
	var/obj/item/weapon/key/japanese/G1 = new/obj/item/weapon/key/japanese(null)
	var/obj/item/weapon/key/japanese_officer/G2 = new/obj/item/weapon/key/japanese_officer(null)
	KC.attackby(G1,H)
	KC.attackby(G2,H)
	H.equip_to_slot_or_del(KC, slot_wear_id)
	give_random_name(H)
	to_chat(world, "<big><b>[H.real_name] is the Camp Director of the Japanese Forces!</b></big>")
	H.add_note("Role", "You are a <b>[title]</b>, the highest ranking officer present. Your job is to command the guards and organize the POWs.")
	apply_job_stats(H)


	return TRUE

/datum/job/japanese/camp_officer
	title = "Horyoshuyojo Gunso"
	en_meaning = "POW Camp Sergeant"
	rank_abbreviation = "Gu."
	allowed_maps = list(MAP_RIVER_KWAI)

	spawn_location = "JoinLateJP"
	is_officer = TRUE

	is_ww2 = TRUE
	is_prison = TRUE

	min_positions = 1
	max_positions = 4

/datum/job/japanese/camp_officer/job_stats = list("strength" = STAT_VERY_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_VERY_HIGH, "dexterity" = STAT_VERY_HIGH, "swords" = STAT_VERY_HIGH, "pistol" = STAT_VERY_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/japanese/camp_officer/job_loadout = list(
	/obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/puttees = slot_shoes,
	/obj/item/clothing/under/ww2/japuni = slot_w_uniform,
	/obj/item/clothing/head/ww2/japcap = slot_head,
	/obj/item/ammo_magazine/c8mmnambu = slot_r_store,
	/obj/item/weapon/gun/projectile/submachinegun/type100 = slot_shoulder,
	/obj/item/weapon/storage/belt/jap/camp_officer = slot_belt)
/datum/job/japanese/camp_officer/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	// The Nambu cannot go in a pocket; use either free hand.
	H.put_in_hands(new /obj/item/weapon/gun/projectile/pistol/ww2/nambu(H))
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/katana/fullh = new /obj/item/clothing/accessory/storage/sheath/katana/full(null)
	uniform.attackby(fullh, H)
	var/obj/item/clothing/accessory/rank/jap_gunsoh = new /obj/item/clothing/accessory/rank/jap_gunso(null)
	uniform.attackby(jap_gunsoh, H)
	var/obj/item/weapon/storage/belt/keychain/KC = new/obj/item/weapon/storage/belt/keychain(H)
	var/obj/item/weapon/key/japanese/G1 = new/obj/item/weapon/key/japanese(null)
	var/obj/item/weapon/key/japanese_officer/G2 = new/obj/item/weapon/key/japanese_officer(null)
	KC.attackby(G1,H)
	KC.attackby(G2,H)
	H.equip_to_slot_or_del(KC, slot_wear_id)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a sergeant leading a squad of guards. Organize your group according to the <b>Camp director's</b> orders!")
	apply_job_stats(H)


	return TRUE

/datum/job/japanese/camp_medic
	title = "Horyoshuyojo Sento-i"
	en_meaning = "Camp Medic"
	rank_abbreviation = "Sen-i"
	allowed_maps = list(MAP_RIVER_KWAI)

	spawn_location = "JoinLateJPDoc"

	is_medic = TRUE
	is_ww2 = TRUE
	is_prison = TRUE


	min_positions = 1
	max_positions = 4

/datum/job/japanese/camp_medic/job_stats = list("strength" = STAT_HIGH, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_HIGH, "dexterity" = STAT_HIGH, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_VERY_HIGH)
/datum/job/japanese/camp_medic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/puttees(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni(H), slot_w_uniform) // for now
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
	var/obj/item/weapon/storage/belt/keychain/KC = new/obj/item/weapon/storage/belt/keychain(H)
	var/obj/item/weapon/key/japanese/G1 = new/obj/item/weapon/key/japanese(null)
	KC.attackby(G1,H)
	H.equip_to_slot_or_del(KC, slot_wear_id)

	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a medic, and you are in charge of keeping the guardss and POWs healthy.")
	apply_job_stats(H)
	return TRUE

/datum/job/japanese/camp_guard
	title = "Horyoshuyojo Anchisukiru"
	en_meaning = "POW Camp Guard"
	rank_abbreviation = ""
	allowed_maps = list(MAP_RIVER_KWAI)

	spawn_location = "JoinLateJP"

	is_ww2 = TRUE
	is_prison = TRUE

	min_positions = 10
	max_positions = 50

/datum/job/japanese/camp_guard/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_MEDIUM_HIGH, "swords" = STAT_NORMAL, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/japanese/camp_guard/job_loadout = list(
	/obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/puttees = slot_shoes,
	/obj/item/clothing/under/ww2/japuni = slot_w_uniform,
	/obj/item/clothing/head/ww2/japcap = slot_head,
	/obj/item/weapon/gun/projectile/boltaction/arisaka99 = slot_shoulder,
	/obj/item/weapon/storage/belt/jap/camp_guard = slot_belt)
/datum/job/japanese/camp_guard/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/rank/jap_ittoheih = new /obj/item/clothing/accessory/rank/jap_ittohei(null)
	uniform.attackby(jap_ittoheih, H)
	var/obj/item/clothing/accessory/storage/sheath/baton/fullh = new /obj/item/clothing/accessory/storage/sheath/baton(null)
	uniform.attackby(fullh, H)
	var/obj/item/weapon/storage/belt/keychain/KC = new/obj/item/weapon/storage/belt/keychain(H)
	var/obj/item/weapon/key/japanese/G1 = new/obj/item/weapon/key/japanese(null)
	KC.attackby(G1,H)
	H.equip_to_slot_or_del(KC, slot_wear_id)

	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a simple POW camp guard. Keep the POWs docile and alive, follow your <b>Officer's</b> orders!")
	apply_job_stats(H)


	return TRUE

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////NAVY////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/datum/job/japanese/ijn_captain
	title = "Kaigun-Dai-i"
	en_meaning = "Navy Lieutenant"
	rank_abbreviation = "Ka-Dai"
	allowed_maps = list(MAP_IWO_JIMA, MAP_RIZAL_STADIUM, MAP_WAKE_ISLAND)


	spawn_location = "JoinLateJPCap"
	is_officer = TRUE
	is_commander = TRUE
	whitelisted = TRUE
	is_ww2 = TRUE
	is_navy = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/japanese/ijn_captain/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_HIGH, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/japanese/ijn_captain/job_loadout = list(
	/obj/item/weapon/gun/projectile/pistol/ww2/nambu = slot_l_hand,
	/obj/item/weapon/key/japanese_officer = slot_r_store,
	/obj/item/weapon/key/japanese = slot_l_store,
	/obj/item/weapon/material/sword/katana = slot_belt)
/datum/job/japanese/ijn_captain/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	if (map.ID == MAP_BATTLE_SHIPS)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/navy(H), slot_shoes)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_navy_officer(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap_navy_officer(H), slot_head)
	else
//shoes
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/navy(H), slot_shoes)
//clothes
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_snlf(H), slot_w_uniform)
//head
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap_snlf(H), slot_head)
//weapons
	equip_loadout(H)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/japflashlight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")
	to_chat(world, "<big><b>[H.real_name] is the Lieutenant of the Japanese Forces!</b></big>")
	H.add_note("Role", "You are a <b>[title]</b>, the highest ranking officer present. Your job is to command the ship or company.")
	apply_job_stats(H)


	return TRUE

/datum/job/japanese/ijn_lieutenant
	title = "Kaigun-Chui"
	en_meaning = "Sub-Lieutenant"
	rank_abbreviation = "Slt."
	allowed_maps = list(MAP_IWO_JIMA, MAP_RIZAL_STADIUM, MAP_WAKE_ISLAND)


	spawn_location = "JoinLateJPCap"
	whitelisted = TRUE
	is_commander = TRUE
	is_officer = TRUE
	is_ww2 = TRUE
	is_navy = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/japanese/ijn_lieutenant/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_HIGH, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/japanese/ijn_lieutenant/job_loadout = list(
	/obj/item/weapon/gun/projectile/pistol/ww2/nambu = slot_l_hand,
	/obj/item/weapon/key/japanese_officer = slot_r_store,
	/obj/item/weapon/key/japanese = slot_l_store,
	/obj/item/weapon/material/sword/katana = slot_belt)
/datum/job/japanese/ijn_lieutenant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	if (map.ID == MAP_BATTLE_SHIPS)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/navy(H), slot_shoes)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_navy_officer(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap_navy_officer(H), slot_head)
	else
//shoes
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/navy(H), slot_shoes)
//clothes
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_snlf(H), slot_w_uniform)
//head
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap_snlf(H), slot_head)
//weapons
	equip_loadout(H)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/japflashlight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")
	to_chat(world, "<big><b>[H.real_name] is the Sub-Lieutenant of the Japanese Forces!</b></big>")
	H.add_note("Role", "You are a <b>[title]</b>, the 2nd highest ranking officer present. Your job is to command half of the forces.")
	apply_job_stats(H)


	return TRUE

/datum/job/japanese/ijn_lieutenant2
	title = "Kaigun-Shoi"
	en_meaning = "Ensign"
	rank_abbreviation = "En."
	allowed_maps = list(MAP_IWO_JIMA, MAP_RIZAL_STADIUM, MAP_WAKE_ISLAND)


	spawn_location = "JoinLateJPCap"
	whitelisted = TRUE
	is_commander = TRUE
	is_officer = TRUE
	is_ww2 = TRUE
	is_navy = TRUE

	min_positions = 1
	max_positions = 1

/datum/job/japanese/ijn_lieutenant2/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_HIGH, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/japanese/ijn_lieutenant2/job_loadout = list(
	/obj/item/weapon/gun/projectile/pistol/ww2/nambu = slot_l_hand,
	/obj/item/weapon/key/japanese_officer = slot_r_store,
	/obj/item/weapon/key/japanese = slot_l_store,
	/obj/item/weapon/material/sword/katana = slot_belt)
/datum/job/japanese/ijn_lieutenant2/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	if (map.ID == MAP_BATTLE_SHIPS)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/navy(H), slot_shoes)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_navy_officer(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap_navy_officer(H), slot_head)
	else
//shoes
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/navy(H), slot_shoes)
//clothes
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_snlf(H), slot_w_uniform)
//head
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap_snlf(H), slot_head)
//weapons
	equip_loadout(H)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/japflashlight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")
	to_chat(world, "<big><b>[H.real_name] is the Ensign of the Japanese Forces!</b></big>")
	H.add_note("Role", "You are a <b>[title]</b>, the 3rd highest ranking officer present. Your job is to command half of the forces.")
	apply_job_stats(H)


	return TRUE

/datum/job/japanese/ijn_sergeant
	title = "Kaigun Nitoheiso"
	en_meaning = "Petty Officer 2nd Class"
	rank_abbreviation = "Niso."
	allowed_maps = list(MAP_IWO_JIMA, MAP_RIZAL_STADIUM, MAP_WAKE_ISLAND)

	spawn_location = "JoinLateJP"
	uses_squads = TRUE
	is_squad_leader = TRUE
	is_ww2 = TRUE
	is_navy = TRUE
	min_positions = 1
	max_positions = 4

/datum/job/japanese/ijn_sergeant/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_NORMAL, "rifle" = STAT_NORMAL, "dexterity" = STAT_NORMAL, "swords" = STAT_HIGH, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/japanese/ijn_sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	if (map.ID == MAP_BATTLE_SHIPS)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/navy(H), slot_shoes)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_navy_po(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap_navy_po(H), slot_head)
	else
//shoes
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/navy/puttees(H), slot_shoes)
//clothes
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_snlf(H), slot_w_uniform)
//head
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap_snlf(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka99(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/katana(H), slot_l_hand)
	H.put_in_hands(new /obj/item/weapon/gun/projectile/pistol/ww2/nambu(H))
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/jap/ww2soldier(H), slot_belt)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/japflashlight(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/katana/fullh = new /obj/item/clothing/accessory/storage/sheath/katana(null)
	uniform.attackby(fullh, H)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")
	H.add_note("Role", "You are a <b>[title]</b>, a petty officer leading a squad. Organize your group according to your <b>Superiors</b> orders!")
	apply_job_stats(H)


	return TRUE

/datum/job/japanese/ijn_doctor
	title = "Kaigun Gun-i"
	en_meaning = "Doctor"
	rank_abbreviation = "Gun-i"
	allowed_maps = list(MAP_IWO_JIMA, MAP_RIZAL_STADIUM, MAP_WAKE_ISLAND)

	spawn_location = "JoinLateJPDoc"

	is_medic = TRUE
	is_ww2 = TRUE
	is_navy = TRUE

	min_positions = 1
	max_positions = 2

/datum/job/japanese/ijn_doctor/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_NORMAL, "medical" = STAT_VERY_HIGH)
/datum/job/japanese/ijn_doctor/job_loadout = list(
	/obj/item/clothing/suit/storage/jacket/doctor = slot_wear_suit,
	/obj/item/weapon/storage/firstaid/surgery = slot_l_hand,
	/obj/item/weapon/doctor_handbook = slot_l_store)
/datum/job/japanese/ijn_doctor/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	if (map.ID == MAP_BATTLE_SHIPS)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/navy(H), slot_shoes)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_navy_po(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap_navy_po(H), slot_head)
	else
//shoes
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/navy/puttees(H), slot_shoes)
//clothes
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_snlf(H), slot_w_uniform) // for now
//head
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap_snlf(H), slot_head)
//jacket
	equip_loadout(H)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/japflashlight(H), slot_wear_id)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")
	H.add_note("Role", "You are a <b>[title]</b>, the most qualified medic present, and you are in charge of keeping the soldiers healthy.")
	apply_job_stats(H)

	return TRUE
/datum/job/japanese/ijn_medic
	title = "Kaigun Sento-i"
	en_meaning = "Medic"
	rank_abbreviation = "Sen-i"
	allowed_maps = list(MAP_IWO_JIMA, MAP_RIZAL_STADIUM, MAP_WAKE_ISLAND)

	spawn_location = "JoinLateJPDoc"
	uses_squads = TRUE
	is_ww2 = TRUE
	is_navy = TRUE


	is_medic = TRUE
	min_positions = 2
	max_positions = 6

/datum/job/japanese/ijn_medic/job_stats = list("strength" = STAT_NORMAL, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_LOW, "dexterity" = STAT_NORMAL, "swords" = STAT_MEDIUM_LOW, "pistol" = STAT_MEDIUM_LOW, "bows" = STAT_NORMAL, "medical" = STAT_VERY_HIGH)
/datum/job/japanese/ijn_medic/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	if (map.ID == MAP_BATTLE_SHIPS)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/navy(H), slot_shoes)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_navy(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap_navy_cap(H), slot_head)
	else
//shoes
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/navy/puttees(H), slot_shoes)
//clothes
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_snlf(H), slot_w_uniform) // for now
//head
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap_snlf(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka99(H), slot_shoulder)
	H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/jap/ww2soldier(H), slot_belt)
	H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/firstaid/adv(H), slot_back)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		H.equip_to_slot_or_del(new /obj/item/flashlight/japflashlight(H), slot_wear_id)
//other
	H.equip_to_slot_or_del(new /obj/item/weapon/doctor_handbook(H), slot_l_store)
	give_random_name(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/redcross = new /obj/item/clothing/accessory/armband/redcross(null)
	uniform.attackby(redcross, H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")
	H.add_note("Role", "You are a <b>[title]</b>, one of the most qualified medics present, and you are in charge of keeping the soldiers healthy.")
	apply_job_stats(H)
	return TRUE

/datum/job/japanese/ijn_ww2infantry
	title = "Santosuihei"
	en_meaning = "Seaman First Class"
	rank_abbreviation = "San."
	allowed_maps = list(MAP_IWO_JIMA, MAP_RIZAL_STADIUM, MAP_WAKE_ISLAND)

	spawn_location = "JoinLateJP"
	uses_squads = TRUE
	is_ww2 = TRUE
	is_navy = TRUE

	min_positions = 20
	max_positions = 100

/datum/job/japanese/ijn_ww2infantry/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/japanese/ijn_ww2infantry/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	if (map.ID == MAP_BATTLE_SHIPS)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/navy(H), slot_shoes)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/japuni_navy(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap_navy_cap(H), slot_head)
	else
//shoes
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/navy/puttees(H), slot_shoes)

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
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/flashlight/japflashlight(H), slot_wear_id)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")
	H.add_note("Role", "You are a <b>[title]</b>, a simple seaman third-class  employed by the Imperial Japanese Navy. Follow your <b>Officer's</b> orders!")
	apply_job_stats(H)


	return TRUE

/datum/job/japanese/ijn_machinegunner
	title = "Hoshu"
	en_meaning = "Machinegunner"
	rank_abbreviation = "Nisu."
	allowed_maps = list(MAP_IWO_JIMA, MAP_RIZAL_STADIUM, MAP_WAKE_ISLAND)

	spawn_location = "JoinLateJP"
	uses_squads = TRUE
	is_ww2 = TRUE
	is_navy = TRUE
	min_positions = 2
	max_positions = 4

/datum/job/japanese/ijn_machinegunner/job_stats = list("strength" = STAT_HIGH, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_VERY_HIGH)
/datum/job/japanese/ijn_machinegunner/job_loadout = list(
	/obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/navy/puttees = slot_shoes,
	/obj/item/clothing/under/ww2/japuni_snlf = slot_w_uniform)
/datum/job/japanese/ijn_machinegunner/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
//head
	var/randhead = rand(1,2)
	if (randhead == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japhelm_snlf(H), slot_head)
	else if (randhead == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap_snlf(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/automatic/type99(H), slot_shoulder)
	H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/jap/ww2soldier99(H), slot_belt)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/flashlight/japflashlight(H), slot_wear_id)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/rank/jap_ittoheih = new /obj/item/clothing/accessory/rank/jap_ittohei(null)
	uniform.attackby(jap_ittoheih, H)
	H.add_note("Role", "You are a <b>[title]</b>, a machine gunner, second-class,  employed by the Imperial Japanese Navy. Follow your <b>Officer's</b> orders! Provide support and suppressing fire for your comrades!")
	apply_job_stats(H)


	return TRUE

/datum/job/japanese/ijn_machinegunner_assistant
	title = " Danyaku Mochinushi"
	en_meaning = " Ammo Bearer"
	rank_abbreviation = "Nisu."
	allowed_maps = list(MAP_IWO_JIMA, MAP_RIZAL_STADIUM, MAP_WAKE_ISLAND)

	spawn_location = "JoinLateJP"
	uses_squads = TRUE
	is_ww2 = TRUE
	is_navy = TRUE
	min_positions = 2
	max_positions = 4

/datum/job/japanese/ijn_machinegunner_assistant/job_stats = list("strength" = STAT_HIGH, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_MEDIUM_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_NORMAL, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW, "machinegun" = STAT_VERY_HIGH)
/datum/job/japanese/ijn_machinegunner_assistant/job_loadout = list(
	/obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/navy/puttees = slot_shoes,
	/obj/item/clothing/under/ww2/japuni_snlf = slot_w_uniform)
/datum/job/japanese/ijn_machinegunner_assistant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
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
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		if (prob(50))
			H.equip_to_slot_or_del(new /obj/item/flashlight/japflashlight(H), slot_wear_id)
	give_random_name(H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/rank/jap_ittoheih = new /obj/item/clothing/accessory/rank/jap_ittohei(null)
	uniform.attackby(jap_ittoheih, H)
	H.add_note("Role", "You are a <b>[title]</b>, an assistant machine gunner, second-class,  employed by the Imperial Japanese Navy. Follow your <b>Officer's</b> orders! Provide support to the machine gunner! Carry the ammo!")
	apply_job_stats(H)


	return TRUE

/datum/job/japanese/ijn_sniper
	title = "Kaigun Senmeina no Hito"
	en_meaning = "Sniper"
	rank_abbreviation = "Nisu."
	allowed_maps = list(MAP_IWO_JIMA, MAP_RIZAL_STADIUM, MAP_WAKE_ISLAND)

	spawn_location = "JoinLateJP"
	uses_squads = TRUE
	is_ww2 = TRUE
	is_navy = TRUE

	min_positions = 1
	max_positions = 8

/datum/job/japanese/ijn_sniper/job_stats = list("strength" = STAT_MEDIUM_HIGH, "crafting" = STAT_MEDIUM_LOW, "rifle" = STAT_VERY_HIGH, "dexterity" = STAT_NORMAL, "swords" = STAT_NORMAL, "pistol" = STAT_MEDIUM_HIGH, "bows" = STAT_NORMAL, "medical" = STAT_MEDIUM_LOW)
/datum/job/japanese/ijn_sniper/job_loadout = list(
	/obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/navy/puttees = slot_shoes,
	/obj/item/clothing/under/ww2/japuni_snlf = slot_w_uniform)
/datum/job/japanese/ijn_sniper/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	equip_loadout(H)
//head
	var/randhead = rand(1,2)
	if (randhead == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww2/japhelm_snlf(H), slot_head)
	else if (randhead == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/ww2/japcap_snlf(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/arisaka99/sniper(H), slot_shoulder)
	H.equip_to_slot_or_del(new 	/obj/item/weapon/storage/belt/jap/ww2soldier(H), slot_belt)
	if (time_of_day == "Night" || time_of_day == "Evening" || time_of_day == "Early Morning")
		if (prob(60))
			H.equip_to_slot_or_del(new /obj/item/flashlight/japflashlight(H), slot_wear_id)
	give_random_name(H)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/rank/jap_jotoheih = new /obj/item/clothing/accessory/rank/jap_jotohei(null)
	uniform.attackby(jap_jotoheih, H)
	H.s_tone = rand(-32,-24)
	if (H.f_style != "Shaved" && H.f_style != "Short Facial Hair" && H.f_style != "Goatee")
		H.f_style = pick("Shaved","Short Facial Hair","Goatee")
	H.add_note("Role", "You are a <b>[title]</b>, a sniper, 2nd class, employed by the Imperial Japanese Navy. Follow your <b>Officer's</b> orders and take out valuable targets from a range!")
	apply_job_stats(H)


	return TRUE
