/mob/living/human/proc/give_random_civ_name()
	name = species.get_random_english_name(gender)
	real_name = name

/mob/living/human/proc/give_clothes()
	if (map.ID == MAP_NOMADS_MOUNTAIN)
		if (map.ordinal_age == 0)
			equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/bone(src), slot_l_store)
			equip_to_slot_or_del(new /obj/item/weapon/material/pickaxe/bone(src), slot_back)
			equip_to_slot_or_del(new /obj/item/weapon/material/shovel/bone(src), slot_belt)
		else if (map.ordinal_age == 1)
			equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/bronze(src), slot_l_store)
			equip_to_slot_or_del(new /obj/item/weapon/material/pickaxe/bone(src), slot_back)
			equip_to_slot_or_del(new /obj/item/weapon/material/shovel/bone(src), slot_belt)
		else if (map.ordinal_age == 2)
			equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/iron(src), slot_l_store)
			equip_to_slot_or_del(new /obj/item/weapon/material/pickaxe(src), slot_back)
			equip_to_slot_or_del(new /obj/item/weapon/material/shovel(src), slot_belt)
		else if (map.ordinal_age >= 3)
			equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/steel(src), slot_l_store)
			equip_to_slot_or_del(new /obj/item/weapon/material/pickaxe(src), slot_back)
			equip_to_slot_or_del(new /obj/item/weapon/material/shovel(src), slot_belt)
	if (map.chad_mode)
		add_note("Chad Mode", "Starting epoch is the Stone Age, research is done by sacrificing players <b>Sacrificing someone from your own faction will reduce the research level!</b>. Reduced starting items and more hostile conditions.")
	if (!map.chad_mode)

//knives and other tools/////////////////////////////////////////////////
//knives removed since flint was introduced
/*
		if (map.civilizations && map.ID != MAP_NOMADS_MOUNTAIN)
			if (map.ordinal_age == 0)
				equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/bone(src), slot_belt)
			else if (map.ordinal_age == 1)
				equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/bronze(src), slot_belt)
			else if (map.ordinal_age == 2)
				equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/iron(src), slot_belt)
			else if (map.ordinal_age >= 3)
				equip_to_slot_or_del(new /obj/item/weapon/material/kitchen/utensil/knife/steel(src), slot_belt)
*/
//clothes/////////////////////////////////////////////////
		if (map.ordinal_age == 0)
			if (map && map.ID == MAP_NOMADS_ISLAND)
				if (gender=="male")
					equip_to_slot_or_del(new /obj/item/clothing/under/leaves_skirt(src), slot_w_uniform)
				else
					equip_to_slot_or_del(new /obj/item/clothing/under/leaves_skirt/long(src), slot_w_uniform)
			else
				equip_to_slot_or_del(new /obj/item/clothing/under/loinleather(src), slot_w_uniform)

		else if (map.ordinal_age == 1)
			equip_to_slot_or_del(new /obj/item/clothing/under/celtic_short_braccae(src), slot_w_uniform)
			equip_to_slot_or_del(new /obj/item/clothing/shoes/roman(src), slot_shoes)
			equip_to_slot_or_del(new /obj/item/stack/money/coppercoin/twohundred(src), slot_r_store)

		else if (map.ordinal_age == 2)
			if (map && map.ID == MAP_CIVILIZATIONS)
				equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval(src), slot_shoes)
				spawn(5)
					if (gender == "male")
						if (civilization == "West Kingdom")
							equip_to_slot_or_del(new /obj/item/clothing/under/medieval/red(src), slot_w_uniform)
						else
							equip_to_slot_or_del(new /obj/item/clothing/under/medieval/green(src), slot_w_uniform)
					else
						if (civilization == "West Kingdom")
							equip_to_slot_or_del(new /obj/item/clothing/under/civfr(src), slot_w_uniform)
							equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(src), slot_head)
						else
							equip_to_slot_or_del(new /obj/item/clothing/under/civfg(src), slot_w_uniform)
							equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(src), slot_head)
			else if(map && (map.ID == MAP_TRIBES || map.ID == MAP_THREE_TRIBES|| map.is_fantrace))
				if (orc)
					equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval(src), slot_shoes)
					var/obj/item/clothing/under/customtribalrobe/C = new/obj/item/clothing/under/customtribalrobe(src)
					spawn(10)
						C.uncolored = FALSE
					C.shirtcolor = "#000000"
					C.pantscolor = "#9A1313"
					var/image/pants = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "tribalrobe_decoration")
					pants.color = C.pantscolor
					var/image/shirt = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "tribalrobe_robe")
					shirt.color = C.shirtcolor
					var/image/belt = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "tribalrobe_robebelt")
					overlays += pants
					overlays += shirt
					overlays += belt
					equip_to_slot_or_del(C, slot_w_uniform)
					update_icons(1)
				else if (gorillaman)
					equip_to_slot_or_del(new /obj/item/clothing/under/loinleather(src), slot_w_uniform)
				else if (ant)
					equip_to_slot_or_del(new /obj/item/clothing/shoes/sandal(src), slot_shoes)
					equip_to_slot_or_del(new /obj/item/clothing/under/celtic_blue(src), slot_w_uniform)
				else if (lizard)
					equip_to_slot_or_del(new /obj/item/clothing/under/mayan_loincloth(src), slot_w_uniform)
				else if (wolfman || crab)
					equip_to_slot_or_del(new /obj/item/clothing/under/loincotton(src), slot_w_uniform)
				else
					equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval(src), slot_shoes)
					equip_to_slot_or_del(new /obj/item/clothing/under/medieval/leather(src), slot_w_uniform)

		else if (map.ordinal_age == 3)
			equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(src), slot_shoes)
			if (map.ID == MAP_CIVILIZATIONS)
				spawn(5)
					make_nomad()
					if (gender == "male")
						if (civilization == "West Kingdom")
							equip_to_slot_or_del(new /obj/item/clothing/under/medieval/red(src), slot_w_uniform)
						else
							equip_to_slot_or_del(new /obj/item/clothing/under/medieval/green(src), slot_w_uniform)
					else
						if (civilization == "West Kingdom")
							equip_to_slot_or_del(new /obj/item/clothing/under/civfr(src), slot_w_uniform)
							equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(src), slot_head)
						else
							equip_to_slot_or_del(new /obj/item/clothing/under/civfg(src), slot_w_uniform)
							equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(src), slot_head)
			else if(map.ID == MAP_FOUR_KINGDOMS)
				if (orc)
					equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval(src), slot_shoes)
					var/obj/item/clothing/under/customtribalrobe/C = new/obj/item/clothing/under/customtribalrobe(src)
					spawn(10)
						C.uncolored = FALSE
					C.shirtcolor = "#000000"
					C.pantscolor = "#688463"
					var/image/pants = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "tribalrobe_decoration")
					pants.color = C.pantscolor
					var/image/shirt = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "tribalrobe_robe")
					shirt.color = C.shirtcolor
					var/image/belt = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "tribalrobe_robebelt")
					overlays += pants
					overlays += shirt
					overlays += belt
					equip_to_slot_or_del(C, slot_w_uniform)
					update_icons(1)
				else if (gorillaman)
					equip_to_slot_or_del(new /obj/item/clothing/under/loinleather(src), slot_w_uniform)
				else if (ant)
					equip_to_slot_or_del(new /obj/item/clothing/shoes/sandal(src), slot_shoes)
					equip_to_slot_or_del(new /obj/item/clothing/under/celtic_blue(src), slot_w_uniform)
				else if (lizard)
					if(prob(80))
						equip_to_slot_or_del(new /obj/item/clothing/under/halfhuipil(src), slot_w_uniform)
					else
						equip_to_slot_or_del(new /obj/item/clothing/under/huipil(src), slot_w_uniform)
				else if (wolfman)
					equip_to_slot_or_del(new /obj/item/clothing/under/loincotton(src), slot_w_uniform)
				else if (crab)
					if (prob(30))
						equip_to_slot_or_del(new /obj/item/clothing/head/helmet/kasa(src), slot_head)
						equip_to_slot_or_del(new /obj/item/clothing/under/haori(src), slot_w_uniform)
						equip_to_slot_or_del(new /obj/item/clothing/shoes/geta(src), slot_shoes)
					if (prob(30))
						equip_to_slot_or_del(new /obj/item/clothing/head/helmet/jingasa(src), slot_head)
						equip_to_slot_or_del(new /obj/item/clothing/under/haori/blue(src), slot_w_uniform)
						equip_to_slot_or_del(new /obj/item/clothing/shoes/geta(src), slot_shoes)
					else
						equip_to_slot_or_del(new /obj/item/clothing/head/rice_hat(src), slot_head)
						equip_to_slot_or_del(new /obj/item/clothing/under/haori/red(src), slot_w_uniform)
						equip_to_slot_or_del(new /obj/item/clothing/shoes/geta(src), slot_shoes)
				else if (civilization == "Human Kingdom")
					if (gender == "male")
						if (prob(20))
							equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_black(src), slot_head)
							equip_to_slot_or_del(new /obj/item/clothing/under/civ2(src), slot_w_uniform)
						else
							equip_to_slot_or_del(new /obj/item/clothing/under/civ2(src), slot_w_uniform)
					else
						equip_to_slot_or_del(new /obj/item/clothing/under/civf1(src), slot_w_uniform)
						equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(src), slot_head)
			else
				if (gender == "male")
					equip_to_slot_or_del(new /obj/item/clothing/under/civ2(src), slot_w_uniform)
					if (prob(20))
						equip_to_slot_or_del(new /obj/item/clothing/head/tricorne_black(src), slot_head)
				else
					equip_to_slot_or_del(new /obj/item/clothing/under/civf1(src), slot_w_uniform)
					equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(src), slot_head)
			equip_to_slot_or_del(new /obj/item/stack/money/coppercoin/twohundred(src), slot_r_store)
			equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(src), slot_shoes)

		else if (map.ordinal_age == 4)
			if (gender == "male")
				equip_to_slot_or_del(new /obj/item/clothing/under/industrial3(src), slot_w_uniform)
			else
				equip_to_slot_or_del(new /obj/item/clothing/under/civf1(src), slot_w_uniform)
				equip_to_slot_or_del(new /obj/item/clothing/head/kerchief(src), slot_head)
			equip_to_slot_or_del(new /obj/item/stack/money/coppercoin/twohundred(src), slot_r_store)
			equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(src), slot_shoes)

		else if (map.ordinal_age == 5)
			if (gender == "male")
				equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(src), slot_shoes)
				equip_to_slot_or_del(new /obj/item/clothing/under/modern4(src), slot_w_uniform)
			else
				equip_to_slot_or_del(new /obj/item/clothing/under/civf1(src), slot_w_uniform)
				equip_to_slot_or_del(new /obj/item/clothing/shoes/sandal(src), slot_shoes)
			equip_to_slot_or_del(new /obj/item/stack/money/coppercoin/twohundred(src), slot_r_store)

		else if (map.ordinal_age == 6)
			if (map.ID == MAP_NATIONSRP || map.ID == MAP_NATIONSRP_TRIPLE || map.ID == MAP_NATIONSRPMED || map.ID == MAP_NATIONSRP_WW2 || map.ID == MAP_NATIONSRP_COLDWAR || map.ID == MAP_NATIONSRP_COLDWAR_CAMPAIGN)
				equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(src), slot_shoes)
				spawn(5)
					if (gender == "male")
						if (original_job_title == "Civilization A Citizen")
							equip_to_slot_or_del(new /obj/item/clothing/under/modern2(src), slot_w_uniform)
							update_icons(1)
						else if (original_job_title == "Civilization B Citizen")
							equip_to_slot_or_del(new /obj/item/clothing/under/modern3(src), slot_w_uniform)
							update_icons(1)
						else if (original_job_title == "Civilization C Citizen")
							equip_to_slot_or_del(new /obj/item/clothing/under/modern3(src), slot_w_uniform)
							update_icons(1)
					else
						if (original_job_title == "Civilization A Citizen")
							equip_to_slot_or_del(new /obj/item/clothing/under/modern8(src), slot_w_uniform)
							update_icons(1)
						else if (original_job_title == "Civilization B Citizen")
							equip_to_slot_or_del(new /obj/item/clothing/under/modern8(src), slot_w_uniform)
							update_icons(1)
						else if (original_job_title == "Civilization C Citizen")
							equip_to_slot_or_del(new /obj/item/clothing/under/modern3(src), slot_w_uniform)
							update_icons(1)
			else
				if (gender == "male")
					equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(src), slot_shoes)
					equip_to_slot_or_del(new /obj/item/clothing/under/modern4(src), slot_w_uniform)
				else
					equip_to_slot_or_del(new /obj/item/clothing/under/civf1(src), slot_w_uniform)
					equip_to_slot_or_del(new /obj/item/clothing/shoes/sandal(src), slot_shoes)
				equip_to_slot_or_del(new /obj/item/stack/money/coppercoin/twohundred(src), slot_r_store)


		else if (map.ordinal_age == 7)
			if (gender == "male")
				equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(src), slot_shoes)
				equip_to_slot_or_del(new /obj/item/clothing/under/modern4(src), slot_w_uniform)
			else
				equip_to_slot_or_del(new /obj/item/clothing/under/civf1(src), slot_w_uniform)
				equip_to_slot_or_del(new /obj/item/clothing/shoes/sandal(src), slot_shoes)
			equip_to_slot_or_del(new /obj/item/stack/money/coppercoin/twohundred(src), slot_r_store)

		else if (map.ordinal_age == 8)
			if (map.ID == MAP_NOMADS_PERSISTENCE_BETA)
				equip_to_slot_or_del(new /obj/item/clothing/shoes/jackboots(src), slot_shoes)
				spawn(5)
					if (original_job_title == "Civilization A Citizen")
						equip_to_slot_or_del(new /obj/item/clothing/under/redmenia/standard/modern(src), slot_w_uniform)
						update_icons(1)
					else if (original_job_title == "Civilization B Citizen")
						equip_to_slot_or_del(new /obj/item/clothing/under/blugoslavia/standard(src), slot_w_uniform)
						update_icons(1)
			else
				if (gender == "male")
					equip_to_slot_or_del(new /obj/item/clothing/shoes/leatherboots(src), slot_shoes)
					equip_to_slot_or_del(new /obj/item/clothing/under/modern7(src), slot_w_uniform)
				else
					equip_to_slot_or_del(new /obj/item/clothing/under/civf1(src), slot_w_uniform)
					equip_to_slot_or_del(new /obj/item/clothing/shoes/sandal(src), slot_shoes)
				equip_to_slot_or_del(new /obj/item/stack/money/coppercoin/twohundred(src), slot_r_store)

	else
		if (s_tone <= -175)
			equip_to_slot_or_del(new /obj/item/clothing/under/leaves_skirt(src), slot_w_uniform)


//coats/////////////////////////////////////////////////
	spawn(5)
		var/area/mob_area = get_area(src)
		if (mob_area.climate == "tundra" || mob_area.climate == "taiga" || (mob_area.climate == "temperate" && season == "WINTER") || map.ID == MAP_NOMADS_ICE_AGE)
			if (map.ordinal_age < 4)
				equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/fur(src), slot_wear_suit)
				if (map.ordinal_age == 0)
					equip_to_slot_or_del(new /obj/item/clothing/suit/prehistoricfurcoat(src), slot_wear_suit)
					equip_to_slot_or_del(new /obj/item/clothing/shoes/fur(src), slot_shoes)
				if (map.ordinal_age == 1)
					equip_to_slot_or_del(new /obj/item/clothing/shoes/fur(src), slot_shoes)
			else if (map.ordinal_age == 4)
				equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ruscoat/grey(src), slot_wear_suit)
			else if (map.ordinal_age >= 5)
				equip_to_slot_or_del(new /obj/item/clothing/suit/storage/coat/ruscoat/grey(src), slot_wear_suit)
			update_inv_wear_suit(1)
		else if (mob_area.climate == "desert")
			if (map.ordinal_age == 0)
				equip_to_slot_or_del(new /obj/item/clothing/shoes/sandal(src), slot_shoes)
			equip_to_slot_or_del(new /obj/item/clothing/suit/arabic_robe(src), slot_wear_suit)
			update_inv_w_uniform(1)
		if (mob_area.climate == "savanna" || mob_area.climate == "jungle" || mob_area.climate == "desert")
			var/f_res = FALSE
			var/f_sens = FALSE
			for (var/i in traits)
				if (i == "Cold Sensitivity")
					f_sens = TRUE
				else if (i == "Heat Tolerance")
					f_res = TRUE
				else if (i == "Heat Sensitivity")
					traits -= i
				else if (i == "Cold Tolerance")
					traits -= i
			if (!f_res)
				traits += "Heat Tolerance"
			if (!f_sens)
				traits += "Cold Sensitivity"
		else if (mob_area.climate == "tundra" || mob_area.climate == "taiga")
			var/f_res = FALSE
			var/f_sens = FALSE
			for (var/i in traits)
				if (i == "Heat Sensitivity")
					f_sens = TRUE
				else if (i == "Cold Tolerance")
					f_res = TRUE
				else if (i == "Cold Sensitivity")
					traits -= i
				else if (i == "Heat Tolerance")
					traits -= i
			if (!f_res)
				traits += "Cold Tolerance"
			if (!f_sens)
				traits += "Heat Sensitivity"

///////////////LANGUAGE PROC/////////////////////////

/mob/living/human/proc/give_languages()
	if (map && map.civilizations)
		if (map.ID == MAP_NOMADS_CONTINENTAL)
			spawn(5)
				var/area/mob_area = get_area(src)
				switch (mob_area.climate)
					if ("tundra")
						add_language("Russian",TRUE)
						remove_language("English")
						for (var/datum/language/russian/A in languages)
							default_language = A
						name = species.get_random_russian_name(gender)
						real_name = name
						add_note("Known Languages", "Russian")
						return

					if ("sea")
						add_language("Spanish",TRUE)
						remove_language("English")
						for (var/datum/language/spanish/A in languages)
							default_language = A
						name = species.get_random_spanish_name(gender)
						real_name = name
						add_note("Known Languages", "Spanish")
						return

					if ("jungle")
						add_language("Japanese",TRUE)
						remove_language("English")
						for (var/datum/language/japanese/A in languages)
							default_language = A
						name = species.get_random_japanese_name(gender)
						real_name = name
						add_note("Known Languages", "Japanese")
						return

					if ("desert")
						add_language("Arabic",TRUE)
						remove_language("English")
						for (var/datum/language/arab/A in languages)
							default_language = A
						name = species.get_random_arab_name(gender)
						real_name = name
						add_note("Known Languages", "Arabic")
						return

					if ("temperate")
						add_language("Spanish",TRUE)
						remove_language("English")
						for (var/datum/language/spanish/A in languages)
							default_language = A
						name = species.get_random_spanish_name(gender)
						real_name = name
						add_note("Known Languages", "Spanish")
						return

		else if (map.ID == MAP_NOMADS_PANGEA)
			spawn(5)
				var/area/mob_area = get_area(src)
				switch (mob_area.climate)
					if ("tundra")
						add_language("Russian",TRUE)
						remove_language("English")
						for (var/datum/language/russian/A in languages)
							default_language = A
						name = species.get_random_russian_name(gender)
						real_name = name
						return
					if ("taiga")
						add_language("Russian",TRUE)
						remove_language("English")
						for (var/datum/language/russian/A in languages)
							default_language = A
						name = species.get_random_russian_name(gender)
						real_name = name
						return
					if ("semiarid")
						if (prob(50))
							add_language("Latin",TRUE)
							remove_language("English")
							for (var/datum/language/latin/A in languages)
								default_language = A
							name = species.get_random_roman_name(gender)
							real_name = name
							add_note("Known Languages", "Latin")
							return
						else
							add_language("Arabic",TRUE)
							remove_language("English")
							for (var/datum/language/arab/A in languages)
								default_language = A
							name = species.get_random_arab_name(gender)
							real_name = name
							add_note("Known Languages", "Arabic")
							return
					if ("savanna")
						add_language("Japanese",TRUE)
						remove_language("English")
						for (var/datum/language/japanese/A in languages)
							default_language = A
						name = species.get_random_japanese_name(gender)
						real_name = name
						add_note("Known Languages", "Japanese")
						return
					if ("jungle")
						add_language("Japanese",TRUE)
						remove_language("English")
						for (var/datum/language/japanese/A in languages)
							default_language = A
						name = species.get_random_japanese_name(gender)
						real_name = name
						add_note("Known Languages", "Japanese")
						return
					if ("desert")
						add_language("Arabic",TRUE)
						remove_language("English")
						for (var/datum/language/arab/A in languages)
							default_language = A
						name = species.get_random_arab_name(gender)
						real_name = name
						add_note("Known Languages", "Arabic")
						return
					if ("temperate")
						add_language("Latin",TRUE)
						remove_language("English")
						for (var/datum/language/latin/A in languages)
							default_language = A
						name = species.get_random_roman_name(gender)
						real_name = name
						add_note("Known Languages", "Latin")
						return
		else if (map.ID == MAP_NOMADS_AFRICA)
			spawn(5)
				var/area/mob_area = get_area(src)
				switch (mob_area.climate)
					if ("semiarid")
						add_language("Arabic",TRUE)
						remove_language("English")
						for (var/datum/language/arab/A in languages)
							default_language = A
						name = species.get_random_arab_name(gender)
						real_name = name
						add_note("Known Languages", "Arabic")
						return
					if ("jungle")
						add_language("Swahili",TRUE)
						remove_language("English")
						for (var/datum/language/swahili/A in languages)
							default_language = A
						name = species.get_random_swahili_name(gender)
						real_name = name
						add_note("Known Languages", "Swahili")
						return
					if ("desert")
						add_language("Egyptian",TRUE)
						remove_language("English")
						for (var/datum/language/egyptian/A in languages)
							default_language = A
						name = species.get_random_egyptian_name(gender)
						real_name = name
						add_note("Known Languages", "Egyptian")
						return
					if ("temperate")
						add_language("Zulu",TRUE)
						remove_language("English")
						for (var/datum/language/zulu/A in languages)
							default_language = A
						name = species.get_random_zulu_name(gender)
						real_name = name
						add_note("Known Languages", "Zulu")
						return
		else if (map.ID == MAP_NOMADS_MEDITERRANEAN)
			spawn(5)
				//SOUTH
				if (y<100)
					//SOUTH-WEST
					if (x<100)
						add_language("Arabic",TRUE)
						remove_language("English")
						for (var/datum/language/arab/A in languages)
							default_language = A
						name = species.get_random_arab_name(gender)
						real_name = name
						add_note("Known Languages", "Arabic")
						return
					//SOUTH-EAST
					else
						add_language("Hebrew",TRUE)
						remove_language("English")
						for (var/datum/language/hebrew/A in languages)
							default_language = A
						name = species.get_random_hebrew_name(gender)
						real_name = name
						add_note("Known Languages", "Hebrew")
						return
					//NORTH-WEST
				else
					if (x<100)
						add_language("Latin",TRUE)
						remove_language("English")
						for (var/datum/language/latin/A in languages)
							default_language = A
						name = species.get_random_roman_name(gender)
						real_name = name
						add_note("Known Languages", "Latin")
						return
					//NORTH-EAST
					else
						add_language("Greek",TRUE)
						remove_language("English")
						for (var/datum/language/greek/A in languages)
							default_language = A
						name = species.get_random_greek_name(gender)
						real_name = name
						add_note("Known Languages", "Greek")
						return
//////////////////////////////////////////////////////
///////////////////Karafuta-Sakhalinsk////////////////
//////////////////////////////////////////////////////
		else if (map.ID == MAP_NOMADS_KARAFUTO)
			spawn(5)
				var/area/mob_area = get_area(src)
				switch (mob_area.climate)
					if ("tundra")
						if (x<100)
							add_language("Russian",TRUE)
							remove_language("English")
							for (var/datum/language/russian/A in languages)
								default_language = A
							name = species.get_random_russian_name(gender)
							real_name = name
							return
						else
							add_language("Ainu",TRUE)
							remove_language("English")
							for (var/datum/language/ainu/A in languages)
								default_language = A
							name = species.get_random_ainu_name(gender)
							real_name = name
							add_note("Known Languages", "Ainu")
							return

					if ("temperate")
						if (x<100)
							add_language("Japanese",TRUE)
							remove_language("English")
							for (var/datum/language/japanese/A in languages)
								default_language = A
							name = species.get_random_japanese_name(gender)
							real_name = name
							add_note("Known Languages", "Japanese")
							return
						else
							add_language("Ainu",TRUE)
							remove_language("English")
							for (var/datum/language/ainu/A in languages)
								default_language = A
							name = species.get_random_ainu_name(gender)
							real_name = name
							add_note("Known Languages", "Ainu")
							return
		else if (map && (map.ID == MAP_TRIBES || map.ID == MAP_THREE_TRIBES || map.is_fantrace))
			spawn(5)
				if (original_job_title == "Orc tribesman")
					orc = 1
					civilization = "Orc Horde"
					religion = "Followers of Morgoth"
					add_language("Black Speech",TRUE)
					remove_language("English")
					for (var/datum/language/blackspeech/A in languages)
						default_language = A
					name = species.get_random_orc_name(gender)
					real_name = name
					give_clothes()
					return
				else if (original_job_title == "Ant tribesman")
					ant = 1
					civilization = "Ant Colony"
					religion = "Followers of the Hive Mother"
					add_language("Antspeak",TRUE)
					remove_language("English")
					for (var/datum/language/ant/A in languages)
						default_language = A
					name = species.get_random_ant_name(gender)
					real_name = name
					give_clothes()
					return
				else if (original_job_title == "Gorilla tribesman")
					gorillaman = 1
					civilization = "Gorilla Tribe"
					religion = "Order of the Great Tree"
					add_language("Ape Speech",TRUE)
					remove_language("English")
					for (var/datum/language/ape/A in languages)
						default_language = A
					name = species.get_random_gorilla_name(gender)
					real_name = name
					give_clothes()
					return
				else if (original_job_title == "Wolf tribesman")
					wolfman = 1
					civilization = "Wolfpack"
					religion = "Moon Worshippers"
					add_language("Wolf Howling",TRUE)
					remove_language("English")
					for (var/datum/language/wolf/A in languages)
						default_language = A
					name = species.get_random_wolf_name(gender)
					real_name = name
					give_clothes()
					return
				else if (original_job_title == "Lizard tribesman")
					lizard = 1
					civilization = "Lizard Clan"
					religion = "The Great Serpent"
					add_language("Lizard Hissing",TRUE)
					remove_language("English")
					for (var/datum/language/lizard/A in languages)
						default_language = A
					name = species.get_random_lizard_name(gender)
					real_name = name
					give_clothes()
					return
				else if (original_job_title == "Crustacean tribesman")
					crab = 1
					civilization = "Crustacean Union"
					religion = "Cthulhu"
					add_language("Clack Tongue",TRUE)
					remove_language("English")
					for (var/datum/language/crab/A in languages)
						default_language = A
					name = species.get_random_crab_name(gender)
					real_name = name
					give_clothes()
					return
				else
					civilization = "Human Kingdom"
					religion = "Father in the Sky"
					name = species.get_random_english_name(gender)
					real_name = name
					give_clothes()
		else if (map && map.ID == MAP_FOUR_KINGDOMS)
			spawn(5)
				if (original_job_title == "Orc tribesman")
					orc = 1
					civilization = "Orc Horde"
					religion = "Code of Malacath"
					add_language("Black Speech",TRUE)
					remove_language("English")
					for (var/datum/language/blackspeech/A in languages)
						default_language = A
					name = species.get_random_orc_name(gender)
					real_name = name
					give_clothes()
					return
				else if (original_job_title == "Ant tribesman")
					ant = 1
					civilization = "Ant Colony"
					religion = "Followers of the Hive Mother"
					add_language("Antspeak",TRUE)
					remove_language("English")
					for (var/datum/language/ant/A in languages)
						default_language = A
					name = species.get_random_ant_name(gender)
					real_name = name
					give_clothes()
					return
				else if (original_job_title == "Gorilla tribesman")
					gorillaman = 1
					civilization = "Gorilla Tribe"
					religion = "Order of the Great Tree"
					add_language("Ape Speech",TRUE)
					remove_language("English")
					for (var/datum/language/ape/A in languages)
						default_language = A
					name = species.get_random_gorilla_name(gender)
					real_name = name
					give_clothes()
					return
				else if (original_job_title == "Wolf tribesman")
					wolfman = 1
					civilization = "Wolfpack"
					religion = "Moon Worshippers"
					add_language("Wolf Howling",TRUE)
					remove_language("English")
					for (var/datum/language/wolf/A in languages)
						default_language = A
					name = species.get_random_wolf_name(gender)
					real_name = name
					give_clothes()
					return
				else if (original_job_title == "Lizard tribesman")
					lizard = 1
					civilization = "Lizard Clan"
					religion = "The Great Serpent"
					add_language("Lizard Hissing",TRUE)
					remove_language("English")
					for (var/datum/language/lizard/A in languages)
						default_language = A
					name = species.get_random_lizard_name(gender)
					real_name = name
					give_clothes()
					return
				else if (original_job_title == "Crustacean tribesman")
					crab = 1
					civilization = "Crustacean Union"
					religion = "Cthulhu"
					add_language("Clack Tongue",TRUE)
					remove_language("English")
					for (var/datum/language/crab/A in languages)
						default_language = A
					name = species.get_random_crab_name(gender)
					real_name = name
					give_clothes()
					return
				else
					civilization = "Human Kingdom"
					religion = "Father in the Sky"
					name = species.get_random_english_name(gender)
					real_name = name
					give_clothes()
		else if (map.ID == MAP_NOMADS_CONTINENTAL || MAP_NOMADS_PANGEA)
			spawn(10)
				if (!isemptylist(whitelist_list) && config.use_job_whitelist && !client.prefs.be_random_name)
					var/found = FALSE
					for (var/i in whitelist_list)
						var/temp_ckey = lowertext(i)
						temp_ckey = replacetext(temp_ckey," ", "")
						temp_ckey = replacetext(temp_ckey,"_", "")
						if (temp_ckey == client.ckey)
							found = TRUE
					if (found)
						var/datum/language/currlg
						for (var/datum/language/A in languages)
							currlg = A
						var/input_msg = WWinput(src, "Welcome, [client.ckey]. You have spawned as a [currlg.name] speaker. Since you are whitelisted, you can customize your name. Do you want to?", "Custom Name", "No", list("Yes","No"))
						if (input_msg == "No")
							return
						else
							var/input_name = input(src, "Choose the new name: (Max 15 characters, please keep it language appropriate)","Custom Name", name) as text
							input_name = sanitizeName(input_name, 15, FALSE)
							if (input_name && input_name != "" && input_name != null)
								name = input_name
								real_name = input_name
								return
/////////////////////////CIVS////////////////////////

/datum/job/civilian/civa
	title = "Civilization A Citizen"
	rank_abbreviation = ""
	can_be_female = TRUE
	spawn_location = "JoinLateCivA"

	is_civilizations = TRUE

	min_positions = 9999
	max_positions = 9999

/datum/job/civilian/civa/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	//H.civilization = civname_a
	H.give_clothes()
	H.make_nation()

	H.add_note("Role", "You are a <b>citizen</b>. Stick with your fellow tribesmen, build your village, and honor the Gods!")
	H.add_note("Civilization", "You are a member of the <b>[civname_a]</b> civilization.")

	H.setStat("strength", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("crafting", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("rifle", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("dexterity", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("swords", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("pistol", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("bows", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("medical", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("philosophy", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))


	return TRUE


/datum/job/civilian/civb
	title = "Civilization B Citizen"
	rank_abbreviation = ""

	spawn_location = "JoinLateCivB"
	can_be_female = TRUE
	is_civilizations = TRUE

	min_positions = 9999
	max_positions = 9999

/datum/job/civilian/civb/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	//H.civilization = civname_b
	H.give_clothes()
	H.make_nation()

	H.add_note("Role", "You are a <b>citizen</b>. Stick with your fellow tribesmen, build your village, and honor the Gods!")
	H.add_note("Civilization", "You are a member of the <b>[civname_b]</b> civilization.")

	H.setStat("strength", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("crafting", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("rifle", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("dexterity", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("swords", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("pistol", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("bows", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("medical", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("philosophy", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))


	return TRUE


/datum/job/civilian/civc
	title = "Civilization C Citizen"
	rank_abbreviation = ""

	spawn_location = "JoinLateCivC"
	can_be_female = TRUE
	is_civilizations = TRUE

	min_positions = 9999
	max_positions = 9999

/datum/job/civilian/civc/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	if (map.ID == MAP_NATIONSRP_TRIPLE)
		H.make_nation()
	else
		H.civilization = civname_c
	H.give_clothes()

	H.add_note("Role", "You are a <b>citizen</b>. Stick with your fellow tribesmen, build your village, and honor the Gods!")
	H.add_note("Civilization", "You are a member of the <b>[civname_c]</b> civilization.")

	H.setStat("strength", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("crafting", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("rifle", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("dexterity", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("swords", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("pistol", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("bows", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("medical", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("philosophy", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))


	return TRUE


/datum/job/civilian/civd
	title = "Civilization D Citizen"
	rank_abbreviation = ""
	can_be_female = TRUE
	spawn_location = "JoinLateCivD"

	is_civilizations = TRUE

	min_positions = 9999
	max_positions = 9999

/datum/job/civilian/civd/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.civilization = civname_d
	H.give_clothes()

	H.add_note("Role", "You are a <b>citizen</b>. Stick with your fellow tribesmen, build your village, and honor the Gods!")
	H.add_note("Civilization", "You are a member of the <b>[civname_d]</b> civilization.")

	H.setStat("strength", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("crafting", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("rifle", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("dexterity", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("swords", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("pistol", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("bows", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("medical", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("philosophy", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))


	return TRUE


/datum/job/civilian/cive
	title = "Civilization E Citizen"
	rank_abbreviation = ""

	spawn_location = "JoinLateCivE"
	can_be_female = TRUE
	is_civilizations = TRUE

	min_positions = 9999
	max_positions = 9999

/datum/job/civilian/cive/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.civilization = civname_e
	H.give_clothes()

	H.add_note("Role", "You are a <b>citizen</b>. Stick with your fellow tribesmen, build your village, and honor the Gods!")
	H.add_note("Civilization", "You are a member of the <b>[civname_e]</b> civilization.")

	H.setStat("strength", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("crafting", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("rifle", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("dexterity", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("swords", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("pistol", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("bows", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("medical", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("philosophy", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))


	return TRUE


/datum/job/civilian/civf
	title = "Civilization F Citizen"
	rank_abbreviation = ""
	can_be_female = TRUE
	spawn_location = "JoinLateCivF"

	is_civilizations = TRUE

	min_positions = 9999
	max_positions = 9999

/datum/job/civilian/civf/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.civilization = civname_f
	H.give_clothes()

	H.add_note("Role", "You are a <b>citizen</b>. Stick with your fellow tribesmen, build your village, and honor the Gods!")
	H.add_note("Civilization", "You are a member of the <b>[civname_f]</b> civilization.")

	H.setStat("strength", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("crafting", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("rifle", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("dexterity", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("swords", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("pistol", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("bows", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("medical", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("philosophy", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))


	return TRUE


/datum/job/civilian/civnomad
	title = "Nomad"
	rank_abbreviation = ""
	can_be_female = TRUE
	spawn_location = "JoinLateCiv"

	is_nomad = TRUE

	min_positions = 9999
	max_positions = 9999

/datum/job/civilian/civnomad/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.give_clothes()
	H.make_nomad()
//	H.give_languages()

	H.add_note("Role", "You are a <b>Nomad</b>. Form a tribe and survive!")

	H.setStat("strength", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("crafting", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("rifle", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("dexterity", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("swords", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("pistol", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("bows", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("medical", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))
	H.setStat("philosophy", pick(STAT_NORMAL, STAT_MEDIUM_LOW, STAT_MEDIUM_HIGH))


	return TRUE
//////////////////////////////////////SPECIES/////////////////////////
/datum/job/civilian/fantasy

/datum/job/civilian/fantasy/orc
	title = "Orc tribesman"
	rank_abbreviation = ""
	can_be_female = TRUE
	spawn_location = "JoinLateIND1"


	min_positions = 9999
	max_positions = 9999

/datum/job/civilian/fantasy/orc/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.give_languages()
	H.make_tribesman()
	H.civilization = "Orc Host"
	H.religion = "Followers of Morgoth"

	H.add_note("Role", "You are a <b>[title]</b>. You are stronger than the other races but somewhat limited in what to build and use.")
	H.add_note("Race Mechanics", "- Stronger than humans, good starting strength and average construction skills.<br>- Second most advanced after humans, but no gunpowder.<br>- Radioactive resistance, can't get cholera or food posioning from raw meat, no bad mood from raw meat, gore, or hygiene.<br>- Need to eat more often.<br>- Can handle extreme heat better.")

	H.setStat("strength", STAT_HIGH)
	H.setStat("crafting", STAT_MEDIUM_LOW)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_MEDIUM_HIGH)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_MEDIUM_LOW)
	H.setStat("philosophy", STAT_NORMAL)


	return TRUE


/datum/job/civilian/fantasy/ant
	title = "Ant tribesman"
	rank_abbreviation = ""
	can_be_female = TRUE
	spawn_location = "JoinLateIND2"


	min_positions = 9999
	max_positions = 9999

/datum/job/civilian/fantasy/ant/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.give_languages()
	H.make_tribesman()
	H.civilization = "Ant Colony"
	H.religion = "Followers of the Hive Mother"

	H.add_note("Role", "You are a <b>[title]</b>. You have very high strength and crafting skills, and can dig much faster, but are very limited in what you can build.")
	H.add_note("Race Mechanics", "- Very good strength and dexterity, decent construction skills.<br>- Lowest technology of all races. Can't build walls besides dirt walls, can't build doors.<br>- Can dig holes, mine, and collect dirt/sand without tools use grab intent and click on a floor. To dig a hole, right click and use the Dig verb.<br>- Natural armoured skin gives some melee and radioactive defense.<br>- Can't handle the extreme cold or extreme heat.")

	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("crafting", STAT_VERY_HIGH)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("philosophy", STAT_LOW)



	return TRUE


/datum/job/civilian/fantasy/gorilla
	title = "Gorilla tribesman"
	rank_abbreviation = ""
	can_be_female = TRUE
	spawn_location = "JoinLateIND3"


	min_positions = 9999
	max_positions = 9999

/datum/job/civilian/fantasy/gorilla/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.give_languages()
	H.make_tribesman()
	H.civilization = "Gorilla Tribe"
	H.religion = "Order of the Great Tree"

	H.add_note("Role", "You are a <b>[title]</b>. You are strong and nimble and can craft a wide range of things.")
	H.add_note("Race Mechanics", "- Very high strength, dexterity, and stamina. Good on unarmed fights.<br>- Can jump further than other races. <br>- Doesn't need to drink as often as other races, as they get water from their food.<br>- Since you are an herbivore, you cannot eat meat, eggs, and so on. You can use grab intent to collect and eat leaves from trees.")

	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("crafting", STAT_LOW)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_MEDIUM_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_MEDIUM_LOW)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("philosophy", STAT_LOW)
	H.stats["stamina"][1] = 150
	H.stats["stamina"][2] = 150

	return TRUE

/datum/job/civilian/fantasy/human
	title = "Human tribesman"
	rank_abbreviation = ""
	can_be_female = TRUE
	spawn_location = "JoinLateIND4"


	min_positions = 9999
	max_positions = 9999

/datum/job/civilian/fantasy/human/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.give_languages()
	H.make_tribesman()
	H.civilization = "Human Kingdom"
	H.religion = "Father in the Sky"

	H.add_note("Role", "You are a <b>[title]</b>. You have weak and soft pink skin but are very intelligent and can craft a wide range of things.")
	H.add_note("Race Mechanics", "- Advanced technology compared to all other races (can build crude gunpowder weapons like arquebuses)<br>- Good crafting and intelligence.<br>- The weakest race physically, compared to other races.")

	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_MEDIUM_HIGH)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_MEDIUM_HIGH)
	H.setStat("bows", STAT_MEDIUM_HIGH)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("philosophy", STAT_MEDIUM_HIGH)


	return TRUE

/datum/job/civilian/fantasy/wolf
	title = "Wolf tribesman"
	rank_abbreviation = ""
	can_be_female = TRUE
	spawn_location = "JoinLateIND5"


	min_positions = 9999
	max_positions = 9999

/datum/job/civilian/fantasy/wolf/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.give_languages()
	H.make_tribesman()
	H.civilization = "Wolfpack"
	H.religion = "Moon Worshippers"

	H.add_note("Role", "You are a <b>[title]</b>. You are very nimble, strong and with a great sense of organization.")
	H.add_note("Race Mechanics", "- Fastest race and highest stamina. <br>- Can use howls to communicate with members far away.<br>- Powerful bite.<br>- Not attacked by wild wolves.<br>- Can only eat meat.<br>- Can handle the cold without a coat.")

	H.setStat("strength", STAT_MEDIUM_HIGH)
	H.setStat("crafting", STAT_LOW)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_VERY_HIGH)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_NORMAL)
	H.setStat("philosophy", STAT_LOW)
	H.stats["stamina"][1] = 180
	H.stats["stamina"][2] = 180

	return TRUE

/datum/job/civilian/fantasy/lizard
	title = "Lizard tribesman"
	rank_abbreviation = ""
	can_be_female = TRUE
	spawn_location = "JoinLateIND6"


	min_positions = 9999
	max_positions = 9999

/datum/job/civilian/fantasy/lizard/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.give_languages()
	H.make_tribesman()
	H.civilization = "Lizard Clan"
	H.religion = "The Great Serpent"

	H.add_note("Role", "You are a <b>[title]</b>. You have a poisonous bite and faster movement in rough terrain.")
	H.add_note("Race Mechanics", "- Not slowed down by rough terrain (mud, snow). <br>- Poisonous bite gives toxic damage. <br>- Not attacked by wild reptiles.<br>- Can't handle the extreme cold or extreme heat.")

	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_LOW)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_HIGH)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_MEDIUM_HIGH)
	H.setStat("philosophy", STAT_LOW)

	return TRUE

/datum/job/civilian/fantasy/crab
	title = "Crustacean tribesman"
	rank_abbreviation = ""
	can_be_female = TRUE
	spawn_location = "JoinLateIND7"


	min_positions = 9999
	max_positions = 9999

/datum/job/civilian/fantasy/crab/equip(var/mob/living/human/H)
	if (!H)	return FALSE
	H.give_languages()
	H.make_tribesman()
	H.civilization = "Crustacean Union"
	H.religion = "Cthulhu"

	H.add_note("Role", "You are a <b>[title]</b>. You have a very hard shell and strong claws, but need water to survive.")
	H.add_note("Race Mechanics", "- Natural armoured skin gives good melee and radioactive defense.<br>- Cannot wear shoes or gloves.<br>- Can only eat meat (including rotten, doesn't get food poisoning).<br>- No movement delay on water or sand.")

	H.setStat("strength", STAT_VERY_HIGH)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_LOW)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_LOW)
	H.setStat("pistol", STAT_LOW)
	H.setStat("bows", STAT_LOW)
	H.setStat("medical", STAT_MEDIUM_HIGH)
	H.setStat("philosophy", STAT_LOW)

	return TRUE