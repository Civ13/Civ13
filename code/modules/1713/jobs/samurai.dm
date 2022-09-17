/datum/job/japanese/give_random_name(var/mob/living/human/H)
	H.name = H.species.get_random_japanese_name(H.gender)
	H.real_name = H.name

/datum/job/japanese/eastern_lord
	title = "Azuma no Daimyo"
	en_meaning = "Eastern Lord"
	rank_abbreviation = "Dai."
	spawn_location = "JoinLateJPCap"
	whitelisted = TRUE
	is_commander = TRUE
	is_officer = TRUE
	min_positions = 1
	max_positions = 1
	is_samurai = TRUE
	is_eastern = TRUE

/datum/job/japanese/eastern_lord/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/tsuranuki(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/haori/samurai/red(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/gauntlets/kote(H), slot_gloves)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/samurai/lord/red(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/samurai/lord/red(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/katana(H), slot_l_hand)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/daishoh = new /obj/item/clothing/accessory/storage/sheath/daisho(null)
	uniform.attackby(daishoh, H)
	daishoh.attackby(new/obj/item/weapon/material/sword/wakazashi, H)
	daishoh.attackby(new/obj/item/weapon/material/sword/katana, H)
	uniform.attackby(daishoh, H)
	H.civilization = "Eastern Army"
	give_random_name(H)
	world << "<b><font color='yellow' size=3>[H.real_name] is the Daimyo of the Eastern Army!</font></b>"
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the Eastern Army and their orders. The whole operation relies on you!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_VERY_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/japanese/samurai_eastern
	title = "Azuma no Samurai"
	en_meaning = "Eastern Samurai"
	rank_abbreviation = "Wa-Ho"
	spawn_location = "JoinLateJP"
	whitelisted = TRUE

	is_officer = TRUE
	is_squad_leader = TRUE
	is_samurai = TRUE
	min_positions = 1
	max_positions = 2
	is_eastern = TRUE

/datum/job/japanese/samurai_eastern/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/tsuranuki(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/haori/samurai/red(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/gauntlets/kote(H), slot_gloves)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/samurai/warrior/red(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/samurai/red(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/ancient/tanegashima(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/drinks/gunpowder/full(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/stack/ammopart/stoneball(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/flashlight/torch(H), slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/daishoh = new /obj/item/clothing/accessory/storage/sheath/daisho(null)
	uniform.attackby(daishoh, H)
	daishoh.attackby(new/obj/item/weapon/material/sword/wakazashi, H)
	daishoh.attackby(new/obj/item/weapon/material/sword/katana, H)
	uniform.attackby(daishoh, H)
	H.civilization = "Eastern Army"
	give_random_name(H)
	world << "<b><font color='yellow' size=3>[H.real_name] is a Samurai of the Eastern Army!</font></b>"
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the Eastern Army and their troops. The whole operation relies on you!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_VERY_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_VERY_HIGH)
	H.setStat("medical", STAT_MEDIUM_LOW)
	return TRUE


	return TRUE

/datum/job/japanese/ashigaru_ranged
	title = "Tobu Enkyori Ashigaru"
	en_meaning = "Ranged Eastern Infantryman"
	rank_abbreviation = ""
	spawn_location = "JoinLateJP"
	min_positions = 12
	max_positions = 24
	is_samurai = TRUE
	is_eastern = TRUE
/datum/job/japanese/ashigaru_ranged/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/tsuranuki(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/haori/red(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/gauntlets/kote(H), slot_gloves)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/samurai/red(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/kasa(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/ancient/tanegashima(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/wakazashi(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/drinks/gunpowder/full(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/stack/ammopart/stoneball(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/flashlight/torch(H), slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbingh = new /obj/item/clothing/accessory/storage/webbing(null)
	uniform.attackby(webbingh, H)
	webbingh.attackby(new/obj/item/stack/ammopart/stoneball, H)
	webbingh.attackby(new/obj/item/stack/ammopart/stoneball, H)
	webbingh.attackby(new/obj/item/stack/ammopart/stoneball, H)
	webbingh.attackby(new/obj/item/stack/ammopart/stoneball, H)
	webbingh.attackby(new/obj/item/stack/ammopart/stoneball, H)
	webbingh.attackby(new/obj/item/stack/ammopart/stoneball, H)
	webbingh.attackby(new/obj/item/stack/ammopart/stoneball, H)
	webbingh.attackby(new/obj/item/stack/ammopart/stoneball, H)
	uniform.attackby(webbingh, H)
	H.civilization = "Eastern Army"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a Ranged Ashigaru of the Eastern Army. Follow your <b>Superior's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_VERY_HIGH)
	H.setStat("medical", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/japanese/ashigaru
	title = "Tobu-Ashigaru"
	en_meaning = "Eastern Infantryman"
	rank_abbreviation = ""
	spawn_location = "JoinLateJP"
	min_positions = 12
	max_positions = 48
	is_samurai = TRUE
	is_eastern = TRUE
/datum/job/japanese/ashigaru/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/tsuranuki(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/haori/red(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/gauntlets/kote(H), slot_gloves)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/samurai/red(H), slot_wear_suit)
//head
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/samurai/guard/red(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/jingasa(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/wakazashi(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/drinks/gunpowder/full(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/stack/ammopart/stoneball(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/naginata/steel(H), slot_shoulder)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/katanah = new /obj/item/clothing/accessory/storage/sheath/katana(null)
	uniform.attackby(katanah, H)
	katanah.attackby(new/obj/item/weapon/material/sword/katana, H)
	H.civilization = "Eastern Army"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a foot soldier of the western army. Follow your <b>Superior's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_VERY_HIGH)
	H.setStat("medical", STAT_MEDIUM_LOW)
	return TRUE
/////////////////////////////////////////////////////////////////////////ICHI/////////////////////////////////////////////////////
/datum/job/japanese/western_lord
	title = "Sei no Daimyo"
	en_meaning = "Western Lord"
	rank_abbreviation = ""
	spawn_location = "JoinLateRNCap"
	whitelisted = TRUE
	is_commander = TRUE
	is_officer = TRUE
	min_positions = 1
	max_positions = 1
	is_samurai = TRUE
	is_western = TRUE

/datum/job/japanese/western_lord/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/tsuranuki(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/haori/samurai/blue(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/gauntlets/kote(H), slot_gloves)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/samurai/lord/blue(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/samurai/lord/blue(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/material/sword/katana(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/stack/ammopart/stoneball(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/drinks/gunpowder/full(H), slot_wear_id)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/daishoh = new /obj/item/clothing/accessory/storage/sheath/daisho(null)
	uniform.attackby(daishoh, H)
	daishoh.attackby(new/obj/item/weapon/material/sword/wakazashi, H)
	daishoh.attackby(new/obj/item/weapon/material/sword/katana, H)
	uniform.attackby(daishoh, H)
	H.civilization = "Western Army"
	give_random_name(H)
	world << "<b><font color='yellow' size=3>[H.real_name] is the Daimyo of the Western Army!</font></b>"
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the Western Army and their orders. The whole operation relies on you!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_VERY_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/japanese/samurai_western
	title = "Sei no Samurai"
	en_meaning = "Western Samurai"
	rank_abbreviation = ""
	spawn_location = "JoinLateRN"
	whitelisted = TRUE

	is_officer = TRUE
	is_squad_leader = TRUE
	is_samurai = TRUE
	min_positions = 1
	max_positions = 2
	is_western = TRUE

/datum/job/japanese/samurai_western/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/tsuranuki(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/haori/samurai/blue(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/gauntlets/kote(H), slot_gloves)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/samurai/warrior/blue(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/samurai/blue(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/ancient/tanegashima(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/drinks/gunpowder/full(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/stack/ammopart/stoneball(H), slot_r_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/daishoh = new /obj/item/clothing/accessory/storage/sheath/daisho(null)
	uniform.attackby(daishoh, H)
	daishoh.attackby(new/obj/item/weapon/material/sword/wakazashi, H)
	daishoh.attackby(new/obj/item/weapon/material/sword/katana, H)
	uniform.attackby(daishoh, H)
	H.civilization = "Western Army"
	give_random_name(H)
	world << "<b><font color='yellow' size=3>[H.real_name] is a Samurai of the Western Army!</font></b>"
	H.add_note("Role", "You are a <b>[title]</b>, an officer in charge of the Western Army and their troops. The whole operation relies on you!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_MEDIUM_HIGH)
	H.setStat("dexterity", STAT_MEDIUM_HIGH)
	H.setStat("swords", STAT_VERY_HIGH)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_VERY_HIGH)
	H.setStat("medical", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/japanese/ashigaru_ranged_western
	title = "Sei Enkyori Ashigaru"
	en_meaning = "Ranged Western Infantryman"
	rank_abbreviation = ""
	spawn_location = "JoinLateRN"
	min_positions = 12
	max_positions = 24
	is_samurai = TRUE
	is_western = TRUE
/datum/job/japanese/ashigaru_ranged_western/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/tsuranuki(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/haori/blue(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/gauntlets/kote(H), slot_gloves)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/samurai/blue(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/kasa(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/ancient/tanegashima(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/drinks/gunpowder/full(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/stack/ammopart/stoneball(H), slot_r_store)
	H.equip_to_slot_or_del(new /obj/item/flashlight/torch(H), slot_l_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbingh = new /obj/item/clothing/accessory/storage/webbing(null)
	uniform.attackby(webbingh, H)
	webbingh.attackby(new/obj/item/stack/ammopart/stoneball, H)
	webbingh.attackby(new/obj/item/stack/ammopart/stoneball, H)
	webbingh.attackby(new/obj/item/stack/ammopart/stoneball, H)
	webbingh.attackby(new/obj/item/stack/ammopart/stoneball, H)
	webbingh.attackby(new/obj/item/stack/ammopart/stoneball, H)
	webbingh.attackby(new/obj/item/stack/ammopart/stoneball, H)
	webbingh.attackby(new/obj/item/stack/ammopart/stoneball, H)
	webbingh.attackby(new/obj/item/stack/ammopart/stoneball, H)
	uniform.attackby(webbingh, H)
	H.civilization = "Western Army"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a Ranged Ashigaru of the Western Army. Follow your <b>Superior's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_VERY_HIGH)
	H.setStat("medical", STAT_MEDIUM_LOW)
	return TRUE

/datum/job/japanese/ashigaru_western
	title = "Sei-Ashigaru"
	en_meaning = "Western Infantryman"
	rank_abbreviation = ""
	spawn_location = "JoinLateRN"
	min_positions = 12
	max_positions = 48
	is_samurai = TRUE
	is_western = TRUE
/datum/job/japanese/ashigaru_western/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/tsuranuki(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/haori/blue(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/gloves/gauntlets/kote(H), slot_gloves)
//jacket
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/armor/samurai/blue(H), slot_wear_suit)
//head
	if (prob(30))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/samurai/guard/blue(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/jingasa(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/weapon/reagent_containers/food/drinks/gunpowder/full(H), slot_wear_id)
	H.equip_to_slot_or_del(new /obj/item/weapon/material/naginata/steel(H), slot_shoulder)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/sheath/katanah = new /obj/item/clothing/accessory/storage/sheath/katana(null)
	uniform.attackby(katanah, H)
	katanah.attackby(new/obj/item/weapon/material/sword/katana, H)
	H.civilization = "Western Army"
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a foot soldier of the western army. Follow your <b>Superior's</b> orders!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_VERY_HIGH)
	H.setStat("medical", STAT_MEDIUM_LOW)
	return TRUE