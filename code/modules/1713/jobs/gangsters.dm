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
	var/pick1 = pick(1,2,3)
	if (pick1 == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/flipflops(H), slot_shoes)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ballas1(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/bandana_ballas(H), slot_head)
	else if (pick1 == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/color/white(H), slot_shoes)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ballas2(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/bandana_ballas/two(H), slot_head)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/black(H), slot_shoes)
		H.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses(H), slot_eyes)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/ballas3(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/custom/custom_beanie/black(H), slot_head)

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
	var/pick1 = pick(1,2,3)
	if (pick1 == 1)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/color/white(H), slot_shoes)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/grove1(H), slot_w_uniform)
		H.equip_to_slot_or_del(new /obj/item/clothing/head/bandana_grove(H), slot_head)
	else if (pick1 == 2)
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/black(H), slot_shoes)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/grove2(H), slot_w_uniform)
	else
		H.equip_to_slot_or_del(new /obj/item/clothing/shoes/black(H), slot_shoes)
		H.equip_to_slot_or_del(new /obj/item/clothing/under/grove3(H), slot_w_uniform)
		var/obj/item/clothing/head/cap/cap1 = new /obj/item/clothing/head/cap(null)
		cap1.flipped = TRUE
		H.equip_to_slot_or_del(cap1, slot_head)
