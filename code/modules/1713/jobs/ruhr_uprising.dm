////////////////////////////////WEIMAR REPUBLIC///////////////////////////
/datum/job/german/reichswehr_sergeant
	title = "Reichsheer Unteroffizier"
	en_meaning = "Squad Leader"
	rank_abbreviation = "Uffz."

	spawn_location = "JoinLateWR"
	is_squad_leader = TRUE
	uses_squads = TRUE
	is_interwar = TRUE

	min_positions = 1
	max_positions = 4

/datum/job/german/reichswehr_soldat
	title = "Reichsheer Soldat"
	en_meaning = "Soldier"
	rank_abbreviation = ""

	spawn_location = "JoinLateWR"

	is_interwar = TRUE
	uses_squads = TRUE

	min_positions = 1
	max_positions = 30

/datum/job/german/reichswehr_soldat/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)

//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww1/german(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww/stahlhelm(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/german(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/storage/webbing/ww1/german/fullwebbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german(null)
	uniform.attackby(fullwebbing, H)
	give_random_name(H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	H.add_note("Role", "You are a <b>[title]</b>, a seasoned veteran of the Great War, now fighting in the Reichsheer. Follow your <b>Squad Leader's</b> orders!")
	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_HIGH)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_HIGH)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_MEDIUM_HIGH)
	H.setStat("machinegun", STAT_HIGH)

	return TRUE

/datum/job/german/reichswehr_sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww1/german(H), slot_w_uniform)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww/stahlhelm(H), slot_head)
//weapons
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/german(H), slot_belt)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/mauser(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mauser(H), slot_l_store)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/whistle(H), slot_r_store)
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/holster/hip/holsterh = new /obj/item/clothing/accessory/holster/hip(null)
	uniform.attackby(holsterh, H)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a seasoned veteran of the Great War, now fighting in the Reichsheer as a squad leader.")
	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_VERY_HIGH)
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_VERY_HIGH)
	H.setStat("pistol", STAT_VERY_HIGH)
	H.setStat("bows", STAT_VERY_HIGH)
	H.setStat("medical", STAT_VERY_HIGH)
	H.setStat("machinegun", STAT_VERY_HIGH)

	return TRUE

/datum/job/german/freikorps_sergeant
	title = "Freikorps Unteroffizier"
	en_meaning = "Squad Leader"
	rank_abbreviation = "Uffz."

	spawn_location = "JoinLateFK"
	is_squad_leader = TRUE
	uses_squads = TRUE
	is_interwar = TRUE

	min_positions = 1
	max_positions = 20

/datum/job/german/freikorps_soldat
	title = "Freikorps Soldat"
	en_meaning = "Soldier"
	rank_abbreviation = ""

	spawn_location = "JoinLateFK"

	is_interwar = TRUE
	uses_squads = TRUE

	min_positions = 1
	max_positions = 160

/datum/job/german/freikorps_soldat/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	var/obj/item/clothing/accessory/storage/webbing/ww1/german/fullwebbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german(null)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)

//clothes
	if (prob(10))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ2(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww1/german(H), slot_w_uniform)
//head
	if (prob(40))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/flatcap1(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww/stahlhelm(H), slot_head)
//back
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/pickunifreikorps = rand(1,3)
	switch(pickunifreikorps)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98(H), slot_shoulder)
			uniform.attackby(fullwebbing, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98/karabiner98a(H), slot_shoulder)
			uniform.attackby(fullwebbing, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr71(H), slot_shoulder)
			uniform.attackby(fullwebbing, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr71, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr71, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr71, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr71, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr71, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr71, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr71, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr71, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/grenade/modern/stg1915(H), slot_belt)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a right-wing Freikorps paramilitary fighting begrudgingly alongside the Reichswehr. Follow your <b>Squad Leader's</b> orders!")
	H.setStat("strength", STAT_LOW)
	H.setStat("crafting", STAT_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_LOW)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_LOW)
	H.setStat("machinegun", STAT_LOW)

	return TRUE

/datum/job/german/freikorps_sergeant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	var/obj/item/clothing/accessory/storage/webbing/ww1/german/fullwebbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german(null)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)

//clothes
	if (prob(10))
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ2(H), slot_w_uniform)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ww1/german(H), slot_w_uniform)
//head
	if (prob(40))
		H.equip_to_slot_or_del(new /obj/item/clothing/head/flatcap1(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww/stahlhelm(H), slot_head)
//back
	var/obj/item/clothing/under/uniform = H.w_uniform
	var/pickunifreikorpsoffizier = rand(1,3)
	switch(pickunifreikorpsoffizier)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98(H), slot_shoulder)
			uniform.attackby(fullwebbing, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98/karabiner98a(H), slot_shoulder)
			uniform.attackby(fullwebbing, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr71(H), slot_shoulder)
			uniform.attackby(fullwebbing, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr71, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr71, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr71, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr71, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr71, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr71, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr71, H)
			fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr71, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/grenade/modern/stg1915(H), slot_belt)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a right-wing Freikorps paramilitary fighting begrudgingly alongside the Reichswehr as a squad leader.")
	H.setStat("strength", STAT_LOW)
	H.setStat("crafting", STAT_LOW)
	H.setStat("rifle", STAT_MEDIUM_LOW)
	H.setStat("dexterity", STAT_LOW)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_LOW)
	H.setStat("machinegun", STAT_LOW)

	return TRUE

/datum/job/german/weimarpolice
	title = "Sicherheitspolizei"
	en_meaning = "Security Police"
	rank_abbreviation = ""

	spawn_location = "JoinLateWR"

	is_interwar = TRUE
	uses_squads = TRUE

	min_positions = 1
	max_positions = 100

/datum/job/german/weimarpolice/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	var/obj/item/clothing/accessory/storage/webbing/ww1/german/fullwebbing = new /obj/item/clothing/accessory/storage/webbing/ww1/german(null)
//shoes
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(H), slot_shoes)
//clothes
	H.equip_to_slot_or_del(new /obj/item/clothing/under/ww1/german(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/germcoat(H), slot_wear_suit)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/ww/germcap(H), slot_head)
//back
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/boltaction/gewehr98/karabiner98a(H), slot_shoulder)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/belt/police/old(H), slot_belt)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(fullwebbing, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	fullwebbing.attackby(new/obj/item/ammo_magazine/gewehr98, H)
	H.equip_to_slot_or_del(new /obj/item/weapon/melee/classic_baton/guard(H), slot_r_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/grenade/chemical/xylyl_bromide, (H), slot_l_hand)
	give_random_name(H)
	H.add_note("Role", "You are a <b>[title]</b>, a riot police officer fighting begrudgingly alongside the Reichswehr. Follow your <b>Squad Leader's</b> orders!")
	H.setStat("strength", STAT_LOW)
	H.setStat("crafting", STAT_LOW)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_LOW)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("machinegun", STAT_LOW)

	return TRUE


////////////////////////////////RUHR RED ARMY///////////////////////////

/datum/job/civilian/ruhrunteroffizier
	title = "Ruhr Red Army Unteroffizier"
	rank_abbreviation = "Uffz."
	default_language = "German"
	spawn_location = "JoinLateCiv"

	is_interwar = TRUE
	is_squad_leader = TRUE
	uses_squads = TRUE

	min_positions = 1
	max_positions = 50

/datum/job/civilian/ruhrsoldat
	title = "Ruhr Red Army Soldat"
	rank_abbreviation = ""

	spawn_location = "JoinLateCiv"
	default_language = "German"
	can_be_female = TRUE
	is_interwar = TRUE
	uses_squads = TRUE

	min_positions = 1
	max_positions = 1000

/datum/job/civilian/ruhrsoldat/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	var/pickshoesruhr = rand(1,4)
	switch(pickshoesruhr)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup/brown(H), slot_shoes)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
//head
	var/pickhatruhr = rand(1,4)
	switch(pickhatruhr)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/flatcap1(H), slot_head)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/flatcap3(H), slot_head)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/red_sailorberet(H), slot_head)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/bowler_hat(H), slot_head)
//clothes
	var/pickuniruhr = rand(1,7)
	switch(pickuniruhr)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ1(H), slot_w_uniform)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ2(H), slot_w_uniform)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/industrial5(H), slot_w_uniform)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/oldmansuit(H), slot_w_uniform)
		if (5)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/farmer_outfit(H), slot_w_uniform)
		if (6)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/mechanic_outfit(H), slot_w_uniform)
		if (7)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/detective1(H), slot_w_uniform)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/british/armband = new /obj/item/clothing/accessory/armband/british(null)
	uniform.attackby(armband, H)

	H.add_note("Role", "You are a member of the Ruhr Red Army, attempting to overthrow the Weimar Republic to establish a communist state. Fight the Bourgeoisie and the reactionaries!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_LOW)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_LOW)
	H.setStat("machinegun", STAT_LOW)
	H.name = H.species.get_random_german_name(H.gender)
	H.real_name = H.name

	return TRUE

/datum/job/civilian/ruhrunteroffizier/equip(var/mob/living/human/H)
	if (!H)	return FALSE
//shoes
	var/pickshoesruhroffizier = rand(1,4)
	switch (pickshoesruhroffizier)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup(H), slot_shoes)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup/brown(H), slot_shoes)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
//head
	H.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/ww/stahlhelm(H), slot_head)
//clothes
	var/pickuniruhroffizier = rand(1,2)
	switch (pickuniruhroffizier)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ1(H), slot_w_uniform)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/germcoat, slot_wear_suit)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/ww2/civ2(H), slot_w_uniform)
			H.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/japcoat2(H), slot_w_uniform)

	var/obj/item/clothing/under/uniform = H.w_uniform
	var/obj/item/clothing/accessory/armband/british/armband = new /obj/item/clothing/accessory/armband/british(null)
	uniform.attackby(armband, H)

	H.add_note("Role", "You are a member of the Ruhr Red Army, attempting to overthrow the Weimar Republic to establish a communist state. Lead your squad to defeat the Bourgeoisie and the reactionaries!")
	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_LOW)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_LOW)
	H.setStat("machinegun", STAT_LOW)
	H.name = H.species.get_random_german_name(H.gender)
	H.real_name = H.name

	return TRUE
