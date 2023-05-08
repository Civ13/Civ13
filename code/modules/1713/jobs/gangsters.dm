///////////BALLAS/////////////////

/datum/job/indians/ballas
	title = "Ballas Gangster"
	en_meaning = FALSE
	can_be_female = FALSE
	spawn_location = "JoinLateBAL"
	selection_color = "#9605a0"
	is_gta = TRUE
	min_positions = 1
	max_positions = 100
	default_language = "English"
	additional_languages = list()

/datum/job/indians/ballas/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.name = H.species.get_random_english_name(H.gender)
	H.real_name = H.name
	var/new_hair = "Black"
	var/hex_hair = hair_colors[new_hair]
	H.r_hair = hex2num(copytext(hex_hair, 2, 4))
	H.g_hair = hex2num(copytext(hex_hair, 4, 6))
	H.b_hair = hex2num(copytext(hex_hair, 6, 8))
	H.r_facial = hex2num(copytext(hex_hair, 2, 4))
	H.g_facial = hex2num(copytext(hex_hair, 4, 6))
	H.b_facial = hex2num(copytext(hex_hair, 6, 8))

//clothing
	var/outfit = rand(1,3)
	switch(outfit)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/shoes/flipflops(H), slot_shoes)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/ballas1(H), slot_w_uniform)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/bandana_ballas(H), slot_head)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/shoes/color/white(H), slot_shoes)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/ballas2(H), slot_w_uniform)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/bandana_ballas/two(H), slot_head)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/shoes/black(H), slot_shoes)
			H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses(H), slot_eyes)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/ballas3(H), slot_w_uniform)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/custom/custom_beanie/black(H), slot_head)

//weapons
	var/weap = rand(1,4)
	switch(weap)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/melee/knuckle_duster(H), slot_r_hand)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/melee/baseball_bat(H), slot_r_hand)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/weapon/melee/baseball_bat/aluminium(H), slot_r_hand)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/shaggers(H), slot_r_hand)
	
	var/obj/map_metadata/east_los_santos/EL = map
	if (EL.ballas_points >= 10 && EL.ballas_points < 20)
		var/rand_pistol = rand(1,3)
		switch(rand_pistol)
			if (1)
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m1911(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m1911(H), slot_l_store)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m1911(H), slot_r_store)
			if (2)
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/glock17(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/glock17(H), slot_l_store)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/glock17(H), slot_r_store)
			if (3)
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m9beretta(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m9beretta(H), slot_l_store)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m9beretta(H), slot_r_store)
	else if (EL.ballas_points >= 20 && EL.ballas_points < 30)
		var/rand_smg = rand(1,3)
		switch(rand_smg)
			if (1)
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/tec9(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/tec9(H), slot_l_store)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/tec9(H), slot_r_store)
			if (2)
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/uzi(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/uzi(H), slot_l_store)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/uzi(H), slot_r_store)
			if (3)
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mac10(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mac10(H), slot_l_store)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mac10(H), slot_r_store)
	else if (EL.ballas_points >= 30)
		var/rand_rifle = pick(1,2)
		switch(rand_rifle)
			if (1)
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak47(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/ak47(H), slot_l_store)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/ak47(H), slot_r_store)
			if (2)
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40/mp5(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mp40/mp5(H), slot_l_store)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mp40/mp5(H), slot_r_store)

/datum/job/american/grove
	title = "Grove Sreet Gangster"
	en_meaning = FALSE
	can_be_female = FALSE
	spawn_location = "JoinLateGRV"
	selection_color = "#058a00"
	is_gta = TRUE
	min_positions = 1
	max_positions = 100
	default_language = "English"
	additional_languages = list()

/datum/job/american/grove/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.name = H.species.get_random_english_name(H.gender)
	H.real_name = H.name
	var/new_hair = "Black"
	var/hex_hair = hair_colors[new_hair]
	H.r_hair = hex2num(copytext(hex_hair, 2, 4))
	H.g_hair = hex2num(copytext(hex_hair, 4, 6))
	H.b_hair = hex2num(copytext(hex_hair, 6, 8))
	H.r_facial = hex2num(copytext(hex_hair, 2, 4))
	H.g_facial = hex2num(copytext(hex_hair, 4, 6))
	H.b_facial = hex2num(copytext(hex_hair, 6, 8))
	H.s_tone = rand(-150,-120)

//clothing
	var/outfit = pick(1,2,3)
	switch(outfit)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/clothing/shoes/color/white(H), slot_shoes)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/grove1(H), slot_w_uniform)
			H.equip_to_slot_or_del(new /obj/item/clothing/head/bandana_grove(H), slot_head)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/clothing/shoes/black(H), slot_shoes)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/grove2(H), slot_w_uniform)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/clothing/shoes/black(H), slot_shoes)
			H.equip_to_slot_or_del(new /obj/item/clothing/under/grove3(H), slot_w_uniform)
			var/obj/item/clothing/head/cap/cap1 = new /obj/item/clothing/head/cap(null)
			cap1.flipped = TRUE
			H.equip_to_slot_or_del(cap1, slot_head)

//weapons
	var/weap = rand(1,4)
	switch(weap)
		if (1)
			H.equip_to_slot_or_del(new /obj/item/weapon/melee/knuckle_duster(H), slot_r_hand)
		if (2)
			H.equip_to_slot_or_del(new /obj/item/weapon/melee/baseball_bat(H), slot_r_hand)
		if (3)
			H.equip_to_slot_or_del(new /obj/item/weapon/melee/baseball_bat/aluminium(H), slot_r_hand)
		if (4)
			H.equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/shaggers(H), slot_r_hand)
	
	var/obj/map_metadata/east_los_santos/EL = map
	if (EL.grove_points >= 10 && EL.grove_points < 20)
		var/rand_pistol = rand(1,3)
		switch(rand_pistol)
			if (1)
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m1911(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m1911(H), slot_l_store)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m1911(H), slot_r_store)
			if (2)
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/glock17(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/glock17(H), slot_l_store)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/glock17(H), slot_r_store)
			if (3)
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/pistol/m9beretta(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m9beretta(H), slot_l_store)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/m9beretta(H), slot_r_store)
	else if (EL.grove_points >= 20 && EL.grove_points < 30)
		var/rand_smg = rand(1,3)
		switch(rand_smg)
			if (1)
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/tec9(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/tec9(H), slot_l_store)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/tec9(H), slot_r_store)
			if (2)
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/uzi(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/uzi(H), slot_l_store)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/uzi(H), slot_r_store)
			if (3)
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mac10(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mac10(H), slot_l_store)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mac10(H), slot_r_store)
	else if (EL.grove_points >= 30)
		var/rand_rifle = pick(1,2)
		switch(rand_rifle)
			if (1)
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/ak47(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/ak47(H), slot_l_store)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/ak47(H), slot_r_store)
			if (2)
				H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/submachinegun/mp40/mp5(H), slot_l_hand)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mp40/mp5(H), slot_l_store)
				H.equip_to_slot_or_del(new /obj/item/ammo_magazine/mp40/mp5(H), slot_r_store)
