/*Index*/
/* 1 - Roman Uniform & Sandals
 * 2 - Greek Uniforms
 * 3 - Celtic Uniforms
 * 4 - Mayan & Aztec Uniforms + Sandals
 * 5 - Egyptian Uniforms
 * 6 - Ancient Armor
 * 7 - Ancient Capes
 * 8 - Ancient Headpieces
 * 9 - Ancient Helmets
 * 9a - Nomads (Craftable) Helmets
 * 10 - Royal & Imperial Headwear
 * 11 - Religious Headwear
 * 12 - Pelts
 * 13 - Fur Coats
 * 14 - Fur Shoes
 * 15 - Ancient Facemasks & Covers
 * 16 - Miscallaneous
 * 16a - Asian Uniforms*/

/*Roman Uniforms & Sandals*/

/obj/item/clothing/shoes/roman
	name = "сандали"
	desc = "Базовые кожаные сандалии длиной до колена."
	icon_state = "roman"
	item_state = "roman"
	worn_state = "roman"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 60, arrow = 5, gun = FALSE, energy = 25, bomb = 50, bio = 10, rad = FALSE)
	siemens_coefficient = 0.6

/obj/item/clothing/under/roman
	name = "форма римского легионера"
	desc = "Красная туника, покрытая железными доспехами. Использовался римской армией."
	icon_state = "roman"
	item_state = "roman"
	worn_state = "roman"
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO

/obj/item/clothing/under/toga
	name = "белая тога"
	desc = "Простая тканевая тога."
	icon_state = "toga"
	item_state = "toga"
	worn_state = "toga"
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO

/obj/item/clothing/under/toga2
	name = "белая тога до середины плеча"
	desc = "Простая матерчатая тога, закрывающая только одно плечо."
	icon_state = "toga2"
	item_state = "toga2"
	worn_state = "toga2"
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO

/obj/item/clothing/under/roman_centurion
	name = "униформа римского центуриона"
	desc = "Красная туника, покрытая железными доспехами, с добавленными золотыми пластинами. Использовался центурионами римской армии."
	icon_state = "roman_centurion"
	item_state = "roman_centurion"
	worn_state = "roman_centurion"
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO

/*Greek Uniforms*/

/obj/item/clothing/under/greek1
	name = "Афинская греческая форма"
	desc = "Легкая туника, покрытая бронзовыми и кожаными доспехами. Использовался эллинскими армиями."
	icon_state = "athens"
	item_state = "athens"
	worn_state = "athens"
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO

/obj/item/clothing/under/greek2
	name = "Фивская греческая форма"
	desc = "Легкая туника, покрытая бронзовыми и кожаными доспехами. Использовался эллинскими армиями."
	icon_state = "thebes"
	item_state = "thebes"
	worn_state = "thebes"
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO

/obj/item/clothing/under/greek3
	name = "Коринфийская греческая форма"
	desc = "Легкая туника, покрытая бронзовыми и кожаными доспехами. Использовался эллинскими армиями."
	icon_state = "corinthia"
	item_state = "corinthia"
	worn_state = "corinthia"
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO

/obj/item/clothing/under/greek_commander
	name = "форма греческого командира"
	desc = "Светло-голубая туника, покрытая бронзовыми пластинами. Использовался греческими полководцами."
	icon_state = "greek_commander"
	item_state = "greek_commander"
	worn_state = "greek_commander"
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO

/obj/item/clothing/under/toxotai
	name = "белая туника"
	desc = "Легкая белая туника."
	icon_state = "toxotai"
	item_state = "toxotai"
	worn_state = "toxotai"
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO

/*Celtic Uniforms*/

/obj/item/clothing/under/celtic_green
	name = "зеленые кельтские брюки"
	desc = "Зеленые брюки в кельтском стиле."
	icon_state = "celtic_green"
	item_state = "celtic_green"
	worn_state = "celtic_green"
	heat_protection = LOWER_TORSO|LEGS

/obj/item/clothing/under/celtic_blue
	name = "синие кельтские брюки"
	desc = "Брюки в кельтском стиле синего цвета."
	icon_state = "celtic_blue"
	item_state = "celtic_blue"
	worn_state = "celtic_blue"
	heat_protection = LOWER_TORSO|LEGS

/obj/item/clothing/under/celtic_red
	name = "красные кельтские брюки"
	desc = "Брюки в кельтском стиле красного цвета."
	icon_state = "celtic_red"
	item_state = "celtic_red"
	worn_state = "celtic_red"
	heat_protection = LOWER_TORSO|LEGS

/obj/item/clothing/under/celtic_short_braccae
	name = "короткие кельтские прицветники"
	desc = "Короткие шерстяные брюки в кельтском стиле."
	icon_state = "celtic_short_braccae"
	item_state = "celtic_short_braccae"
	worn_state = "celtic_short_braccae"
	heat_protection = LOWER_TORSO

/obj/item/clothing/under/celtic_long_braccae
	name = "длинные кельтские прицветники"
	desc = "Длинные шерстяные брюки в кельтском стиле."
	icon_state = "celtic_long_braccae"
	item_state = "celtic_long_braccae"
	worn_state = "celtic_long_braccae"
	heat_protection = LOWER_TORSO|LEGS

/*Mayan & Aztec Uniforms + Sandals*/

/obj/item/clothing/under/mayan_loincloth
	name = "набедренная повязка майя"
	desc = "Набедренная повязка в стиле майя."
	icon_state = "mayan_loincloth"
	item_state = "mayan_loincloth"
	worn_state = "mayan_loincloth"
	heat_protection = LOWER_TORSO

/obj/item/clothing/under/aztec_loincloth
	name = "ацтекская набедренная повязка"
	desc = "Набедренная повязка, подходящая для свирепого ацтекского воина."
	icon_state = "aztec_loincloth"
	item_state = "aztec_loincloth"
	worn_state = "aztec_loincloth"
	heat_protection = LOWER_TORSO

/obj/item/clothing/shoes/aztec_sandals
	name = "ацтекские сандалии"
	desc = "Простые кожаные сандалии родом из джунглей."
	icon_state = "aztec_sandals"
	item_state = "aztec_sandals"
	worn_state = "aztec_sandals"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 10, arrow = 5, gun = FALSE, energy = FALSE, bomb = 1, bio = FALSE, rad = FALSE)
	siemens_coefficient = 0.6

/*Egyptian Uniforms*/

/obj/item/clothing/under/pharaoh
	name = "фараонский шендит"
	desc = "Необычный, украшенный шендыт."
	icon_state = "pharaoh"
	item_state = "pharaoh"
	worn_state = "pharaoh"
	heat_protection = LOWER_TORSO|UPPER_TORSO

/obj/item/clothing/under/pharaoh2
	name = "немеский шендит"
	desc = "Необычный, украшенный шендыт."
	icon_state = "greatshendyt"
	item_state = "greatshendyt"
	worn_state = "greatshendyt"
	heat_protection = LOWER_TORSO|UPPER_TORSO

/*Ainu Things*/
/obj/item/clothing/under/ainu
	name = "айнская роба"
	desc = "Комплект одежды, которую носят айны."
	icon_state = "ainu_robe"
	item_state = "ainu_robe"
	worn_state = "ainu_robe"
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO

/obj/item/clothing/under/ainu2
	name = "айнская роба"
	desc = "Комплект одежды, которую носят айны."
	icon_state = "ainu_robe2"
	item_state = "ainu_robe2"
	worn_state = "ainu_robe2"
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO

/obj/item/clothing/head/ainu_bandana
	name = "повязка айну"
	desc = "Бандана с замысловатыми узорами."
	icon_state = "ainu"
	item_state = "ainu"
	worn_state = "ainu"
	var/folded = FALSE

/obj/item/clothing/head/ainu_bandana/verb/fold_bandana()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/head/ainu_bandana)
		return
	else
		if (folded)
			item_state = "ainu"
			worn_state = "ainu"
			item_state_slots["slot_w_head"] = "ainu"
			usr << "<span class = 'danger'>Разматываю бандану.</span>"
			folded = FALSE
		else if (!folded)
			item_state = "ainu_smol"
			worn_state = "ainu_smol"
			item_state_slots["slot_w_head"] = "ainu_smol"
			usr << "<span class = 'danger'>Обматываю бандану вокруг головы.</span>"
			folded = TRUE
	update_clothing_icon()

/*Ancient Armor*/

/obj/item/clothing/suit/armor
	health = 40
	ripable = FALSE
	flags = CONDUCT

/obj/item/clothing/suit/armor/ancient/scale
	name = "сегментированная броня"
	desc = "Толстая, дорогая сегментированная железная броня, покрывающая туловище."
	icon_state = "scale_armor"
	item_state = "scale_armor"
	worn_state = "scale_armor"
	body_parts_covered = UPPER_TORSO
	armor = list(melee = 65, arrow = 45, gun = ARMOR_CLASS*2, energy = 15, bomb = 45, bio = 20, rad = 45)
	value = 40
	slowdown = 0.8
	health = 47

/obj/item/clothing/suit/armor/ancient/chainmail
	name = "кольчуга"
	desc = "Носимая броня, состоящая из нескольких небольших взаимосвязанных цепей."
	icon_state = "early_chainmail"
	item_state = "early_chainmail"
	worn_state = "early_chainmail"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 50, arrow = 35, gun = ARMOR_CLASS, energy = 15, bomb = 30, bio = 20, rad = FALSE)
	value = 30
	slowdown = 0.6
	health = 50

/obj/item/clothing/suit/armor/ancient/linen
	name = "линотораксовская броня"
	desc = "Толстая льняная броня, закрывающая туловище и нижнюю часть тела."
	icon_state = "heavycloth_armor"
	item_state = "heavycloth_armor"
	worn_state = "heavycloth_armor"
	body_parts_covered = UPPER_TORSO | LOWER_TORSO
	armor = list(melee = 55, arrow = 35, gun = FALSE, energy = 15, bomb = 35, bio = 20, rad = 10)
	value = 40
	slowdown = 0.2
	health = 28
	flags = FALSE

/obj/item/clothing/suit/armor/ancient/bronze_lamellar
	name = "бронзовый египетский доспех"
	desc = "Бронзовый ламеллярный доспех, использовавшийся солдатами династий фараонов."
	icon_state = "egyptian_lamellar"
	item_state = "egyptian_lamellar"
	worn_state = "egyptian_lamellar"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 50, arrow = 35, gun = ARMOR_CLASS, energy = 15, bomb = 40, bio = 20, rad = FALSE) //identical to bronze armor
	value = 25
	slowdown = 0.7
	health = 48

/obj/item/clothing/suit/armor/ancient/bronze_lamellar/chinese
	name = "бронзовый китайский доспех"
	desc = "Бронзовый ламеллярный доспех, использовавшийся воинами ранних китайских династий."
	icon_state = "chinese_lamellar"
	item_state = "chinese_lamellar"
	worn_state = "chinese_lamellar"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 50, arrow = 35, gun = ARMOR_CLASS, energy = 15, bomb = 40, bio = 20, rad = FALSE)
	value = 25
	slowdown = 0.7
	health = 48


/obj/item/clothing/suit/armor/ancient/scaled
	name = "чешуйчатая броня"
	desc = "Броня из нескольких чешуек из бронзы."
	icon_state = "scaled_armor"
	item_state = "scaled_armor"
	worn_state = "scaled_armor"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 50, arrow = 35, gun = ARMOR_CLASS, energy = 15, bomb = 40, bio = 20, rad = FALSE)
	value = 25
	slowdown = 0.7
	health = 48


/obj/item/clothing/suit/armor/ancient/aztec_harness
	name = "ацтекская упряжь"
	desc = "Несколько металлических пластин на кожаных полосках, закрывающих туловище."
	icon_state = "aztec_harness"
	item_state = "aztec_harness"
	worn_state = "aztec_harness"
	body_parts_covered = UPPER_TORSO
	armor = list(melee = 35, arrow = 15, gun = FALSE, energy = 2, bomb = 2, bio = FALSE, rad = FALSE)
	value = 40
	slowdown = 0.2
	health = 18

/obj/item/clothing/suit/armor/ancient/gator_scale_armor
	name = "броня из чешуи аллигатора"
	desc = "Тщательно обработанная и закаленная броня из чешуи аллигатора, покрывающая туловище."
	icon_state = "gator_scale_armor"
	item_state = "gator_scale_armor"
	worn_state = "gator_scale_armor"
	body_parts_covered = UPPER_TORSO
	armor = list(melee = 45, arrow = 25, gun = FALSE, energy = 10, bomb = 20, bio = 20, rad = 10)
	value = 40
	slowdown = 0.2
	health = 18

/*Ancient Capes*/

/obj/item/clothing/suit/cape
	name = "красный плащ"
	desc = "Длинный красный плащ."
	icon_state = "redcape"
	item_state = "redcape"
	worn_state = "redcape"

/obj/item/clothing/suit/cape/blue
	name = "синий плащ"
	desc = "Длинный синий плащ."
	icon_state = "bluecape"
	item_state = "bluecape"
	worn_state = "bluecape"

/*Ancient Headpieces*/

/obj/item/clothing/head/toxotai
	name = "токсотайская шляпа"
	desc = "Шляпа с широкими полями, используемая токсотай."
	icon_state = "toxotai"
	item_state = "toxotai"
	worn_state = "toxotai"

/obj/item/clothing/head/egyptian_headdress_black
	name = "черный египетский головной убор"
	desc = "Простой солнцезащитный льняной головной убор, несмотря на черные полосы."
	icon_state = "egyptian_headdress_black"
	item_state = "egyptian_headdress_black"
	worn_state = "egyptian_headdress_black"
	flags_inv = BLOCKHEADHAIR
	heat_protection = HEAD|FACE|EYES

/obj/item/clothing/head/egyptian_headdress_blue
	name = "синий египетский головной убор"
	desc = "Простой солнцезащитный синий льняной головной убор."
	icon_state = "egyptian_headdress_blue"
	item_state = "egyptian_headdress_blue"
	worn_state = "egyptian_headdress_blue"
	flags_inv = BLOCKHEADHAIR
	heat_protection = HEAD|FACE|EYES

/obj/item/clothing/head/egyptian_headdress_red
	name = "красный египетский головной убор"
	desc = "Простой солнцезащитный красный льняной головной убор."
	icon_state = "egyptian_headdress_red"
	item_state = "egyptian_headdress_red"
	worn_state = "egyptian_headdress_red"
	flags_inv = BLOCKHEADHAIR
	heat_protection = HEAD|FACE|EYES

/*Ancient Helmets*/

/obj/item/clothing/head/helmet/roman
	name = "шлем римского легионера"
	desc = "Типичный шлем римской армии."
	icon_override = 'code/modules/1713/clothing/head.dmi'
	icon_state = "roman"
	item_state = "roman"
	worn_state = "roman"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 50, arrow = 40, gun = ARMOR_CLASS, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	health = 35

/obj/item/clothing/head/helmet/roman_decurion
	name = "римский шлем декуриона"
	desc = "Железный шлем, используемый декурионами - офицерами кавалерии римской армии."
	icon_override = 'code/modules/1713/clothing/head.dmi'
	icon_state = "roman_d"
	item_state = "roman_d"
	worn_state = "roman_d"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 50, arrow = 40, gun = ARMOR_CLASS, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	health = 35

/obj/item/clothing/head/helmet/roman_centurion
	name = "шлем римского центуриона"
	desc = "Железный шлем центурионов - офицеров пехоты римской армии."
	icon_override = 'code/modules/1713/clothing/head.dmi'
	icon_state = "roman_c"
	item_state = "roman_c"
	worn_state = "roman_c"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 50, arrow = 40, gun = ARMOR_CLASS, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	health = 35

/obj/item/clothing/head/helmet/gladiator
	name = "гладиаторский шлем"
	desc = "Шлем гладиатора."
	icon_state = "gladiator"
	item_state = "gladiator"
	worn_state = "gladiator"
	body_parts_covered = HEAD|FACE|EYES
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 60, arrow = 45, gun = ARMOR_CLASS, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	health = 40

/obj/item/clothing/head/helmet/solinvictus
	name = "шлем инвиктус"
	desc = "Украшенный золотом шлем с замаскированным лицом и золотыми солнечными полосами который носили римские императоры."
	icon_state = "sol_invictus"
	item_state = "sol_invictus"
	worn_state = "sol_invictus"
	body_parts_covered = HEAD|FACE|EYES
	flags_inv = BLOCKHAIR
	armor = list(melee = 65, arrow = 50, gun = ARMOR_CLASS, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	restricts_view = 2
	health = 55
	slowdown = 0.25

/obj/item/clothing/head/helmet/anax
	name = "греческий шлем анакса"
	desc = "Укрепленный бронзовый греческий шлем, закрывающий большую часть лица, с черным оперением сверху который носили эллинские короли."
	icon_state = "leonidas"
	item_state = "leonidas"
	worn_state = "leonidas"
	body_parts_covered = HEAD|FACE|EYES
	flags_inv = BLOCKHAIR
	armor = list(melee = 60, arrow = 45, gun = ARMOR_CLASS, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	restricts_view = 1
	health = 50
	slowdown = 0.10

/obj/item/clothing/head/helmet/greek
	name = "греческий шлем"
	desc = "Бронзовый греческий шлем, закрывающий большую часть лица."
	icon_state = "new_greek"
	item_state = "new_greek"
	worn_state = "new_greek"
	body_parts_covered = HEAD|FACE|EYES
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 62, arrow = 44, gun = ARMOR_CLASS, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	health = 40

/obj/item/clothing/head/helmet/greek_commander
	name = "шлем лохагос"
	desc = "Бронзовый греческий шлем, закрывающий большую часть лица, с красным оперением наверху который носят эллинские лохаго."
	icon_state = "spartan"
	item_state = "spartan"
	worn_state = "spartan"
	body_parts_covered = HEAD|FACE|EYES
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 62, arrow = 44, gun = ARMOR_CLASS, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	health = 40

/obj/item/clothing/head/helmet/greek_sl
	name = "димеритовый шлем"
	desc = "Бронзовый греческий шлем, закрывающий большую часть лица, с голубым оперением сверху которые носят эллинские димериты."
	icon_state = "athenian"
	item_state = "athenian"
	worn_state = "athenian"
	body_parts_covered = HEAD|FACE|EYES
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 62, arrow = 44, gun = ARMOR_CLASS, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	health = 40

/obj/item/clothing/head/helmet/egyptian
	name = "египетский военный головной убор"
	desc = "Бронзовый египетский головной убор с открытым лицом для защиты от жары."
	icon_state = "egyptian_bronze_headdress"
	item_state = "egyptian_bronze_headdress"
	worn_state = "egyptian_bronze_headdress"
	body_parts_covered = HEAD|EYES
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 50, arrow = 40, gun = ARMOR_CLASS, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	health = 35
	heat_protection = HEAD|FACE|EYES

/obj/item/clothing/head/helmet/phrigian
	name = "бронзовый фригийский шлем"
	desc = "Набалдашник заканчивался бронзовым фригийским шлемом. Больше внимания уделяется стилю, чем общей защите."
	icon_state = "phrigian_helmet"
	item_state = "phrigian_helmet"
	worn_state = "phrigian_helmet"
	body_parts_covered = HEAD
	armor = list(melee = 38, arrow = 25, gun = FALSE, energy = 15, bomb = 30, bio = 20, rad = FALSE)
	health = 30


/obj/item/clothing/head/helmet/leather
	name = "кожаный шлем"
	desc = "Простой кожаный шлем."
	icon_state = "leatherhelmet"
	item_state = "leatherhelmet"
	worn_state = "leatherhelmet"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 27, arrow = 15, gun = FALSE, energy = 15, bomb = 25, bio = 20, rad = FALSE)
	health = 20

/obj/item/clothing/head/helmet/hatchigane
	name = "повязка на голову хэтчиган"
	desc = "Бронированная кожаная повязка японского дизайна, она выдерживает слабые, но не сильные атаки."
	icon_state = "hatchigane"
	item_state = "hatchigane"
	worn_state = "hatchigane"
	body_parts_covered = HEAD
	armor = list(melee = 15, arrow = 15, gun = FALSE, energy = 15, bomb = 25, bio = 20, rad = FALSE)
	health = 15

/obj/item/clothing/head/helmet/khepresh
	name = "боевая корона кепреша"
	desc = "Богато украшенная египетская военная корона из кожи и золота. Он не так защитит, как бронза или железо, но удобен для защиты вашего величества."
	icon_state = "khepresh"
	item_state = "khepresh"
	worn_state = "khepresh"
	body_parts_covered = HEAD
	armor = list(melee = 30, arrow = 20, gun = FALSE, energy = 15, bomb = 40, bio = 20, rad = FALSE) //lightly stronger than leather
	health = 30

	/* Nomads (Craftable) Helmets*/

/obj/item/clothing/head/helmet/gladiator/nomads //nerfing it down for mass consumption
	name = "гладиаторский шлем"
	desc = "Шлем гладиатора."
	icon_state = "gladiator"
	item_state = "gladiator"
	worn_state = "gladiator"
	body_parts_covered = HEAD|FACE|EYES
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 45, arrow = 30, gun = FALSE, energy = 15, bomb = 40, bio = 20, rad = FALSE)
	health = 30

/obj/item/clothing/head/helmet/horned
	name = "шлем с рогами"
	desc = "Рогатый шлем, который носили варвары."
	icon_state = "barbarian" //"viking" can be used elsewise for wagner
	item_state = "barbarian"
	worn_state = "barbarian"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 45, arrow = 30, gun = FALSE, energy = 15, bomb = 40, bio = 20, rad = FALSE)
	health = 30

/obj/item/clothing/head/helmet/asterix
	name = "шлем с крыльями"
	desc = "Крылатый шлем, используемый быстрыми воинами, которые не боятся сильных ударов по лицу."
	icon_state = "asterix"
	item_state = "asterix"
	worn_state = "asterix"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 45, arrow = 30, gun = FALSE, energy = 15, bomb = 40, bio = 20, rad = FALSE)
	health = 30

/obj/item/clothing/head/helmet/egyptian/nomads
	name = "египетский военный головной убор"
	desc = "Бронзовый египетский головной убор с открытым лицом для защиты от жары."
	icon_state = "egyptian_bronze_headdress"
	item_state = "egyptian_bronze_headdress"
	worn_state = "egyptian_bronze_headdress"
	body_parts_covered = HEAD|EYES
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 45, arrow = 30, gun = FALSE, energy = 15, bomb = 40, bio = 20, rad = FALSE)
	health = 30
	heat_protection = HEAD|FACE|EYES

/obj/item/clothing/head/helmet/greek/nomads
	name = "греческий шлем"
	desc = "Бронзовый греческий шлем, закрывающий большую часть лица."
	icon_state = "new_greek"
	item_state = "new_greek"
	worn_state = "new_greek"
	body_parts_covered = HEAD|FACE|EYES
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 45, arrow = 30, gun = FALSE, energy = 15, bomb = 40, bio = 20, rad = FALSE)
	health = 30

/obj/item/clothing/head/helmet/greek_commander/nomads
	name = "шлем лохагос"
	desc = "Бронзовый греческий шлем, закрывающий большую часть лица, с красным оперением наверху которые носят эллинские лохаго."
	icon_state = "spartan"
	item_state = "spartan"
	worn_state = "spartan"
	body_parts_covered = HEAD|FACE|EYES
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 50, arrow = 40, gun = ARMOR_CLASS, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	health = 40

/obj/item/clothing/head/helmet/greek_sl/nomads
	name = "димеритовый шлем"
	desc = "Бронзовый греческий шлем, закрывающий большую часть лица, с голубым оперением сверху которые носят эллинские димериты."
	icon_state = "athenian"
	item_state = "athenian"
	worn_state = "athenian"
	body_parts_covered = HEAD|FACE|EYES
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 50, arrow = 40, gun = ARMOR_CLASS, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	health = 40

/obj/item/clothing/head/helmet/roman/nomads
	name = "шлем римского легионера"
	desc = "Типичный шлем римской армии."
	icon_override = 'code/modules/1713/clothing/head.dmi'
	icon_state = "roman"
	item_state = "roman"
	worn_state = "roman"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 45, arrow = 30, gun = FALSE, energy = 15, bomb = 40, bio = 20, rad = FALSE) //nerfed
	health = 30

/obj/item/clothing/head/helmet/chinese_warrior
	name = "шлем китайского воина"
	desc = "Бронзовый шлем, который использовался ранними китайскими династиями."
	icon_state = "bronze_chinese"
	item_state = "bronze_chinese"
	worn_state = "bronze_chinese"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 45, arrow = 30, gun = FALSE, energy = 15, bomb = 40, bio = 20, rad = FALSE)
	health = 30

/*Royal & Laurel Headwear*/

/obj/item/clothing/head/pharoah
	name = "головной убор фараона"
	desc = "Изысканный золотой головной убор."
	icon_state = "pharoah_headdress"
	item_state = "pharoah_headdress"
	worn_state = "pharoah_headdress"
	flags_inv = BLOCKHEADHAIR
	heat_protection = HEAD|FACE|EYES

/obj/item/clothing/head/nemes
	name = "головной убор немес"
	desc = "Необычный золотой головной убор."
	icon_state = "nemes_headdress"
	item_state = "nemes_headdress"
	worn_state = "nemes_headdress"
	flags_inv = BLOCKHEADHAIR
	heat_protection = HEAD|FACE|EYES

/obj/item/clothing/head/doublecrown //replaced by hedjet/deshret/pschent following
	name = "двойная корона"
	desc = "Корона из двухцветной ткани."
	icon_state = "doublecrown"
	item_state = "doublecrown"
	worn_state = "doublecrown"

/obj/item/clothing/head/hedjet
	name = "хеджетная корона"
	desc = "Египетская корона, изготовленная из ткани. Его часто носят фараоны, властвующие над поймами." //historically the northern pharoahs nearer to the nile delta
	icon_state = "hedjet"
	item_state = "hedjet"
	worn_state = "hedjet"
	flags_inv = BLOCKHEADHAIR
	heat_protection = HEAD|FACE|EYES

/obj/item/clothing/head/deshret
	name = "корона дешрета"
	desc = "Красная египетская корона, сделанная из ткани. Его часто носят фараоны, правящие пустынными дюнами." //historically the southern pharoahs nearer to the nubian desert
	icon_state = "deshret"
	item_state = "deshret"
	worn_state = "deshret"
	flags_inv = BLOCKHEADHAIR
	heat_protection = HEAD|FACE|EYES

/obj/item/clothing/head/pschent
	name = "корона пшентов"
	desc = "Комбинированная красно-белая египетская корона, изготовленная из ткани. Сочетание дешрета и хеджета; он представляет божественную власть над их владениями." //worn by herod, of a united egyptian kingdom.
	icon_state = "pschent"
	item_state = "pschent"
	worn_state = "pschent"
	flags_inv = BLOCKHEADHAIR
	heat_protection = HEAD|FACE|EYES

/obj/item/clothing/head/laurelcrown
	name = "лавровый венец"
	desc = "Корона из лавра."
	icon_state = "laurelcrown"
	item_state = "laurelcrown"
	body_parts_covered = FALSE

/obj/item/clothing/head/laurelcrown/gold
	name = "золотой лавровый венец"
	desc = "Золотая корона, имитирующая лавровый венец."
	icon_state = "laurelcrown_gold"
	item_state = "laurelcrown_gold"
	body_parts_covered = FALSE

/* Religious Headwear*/

/obj/item/clothing/head/fiendish
	name = "зловещий головной убор"
	desc = "Угрожающий головной убор, предпочитаемый культами и шабашами."
	icon_state = "fiendish"
	item_state = "fiendish"
	worn_state = "fiendish"
	flags_inv = BLOCKHEADHAIR

/obj/item/clothing/head/fiendish/blugi
	color = "#2a28b6"


/obj/item/clothing/head/semitic_cap
	name = "семитская шапочка"
	desc = "Желтая шапка с выпуклой головкой применялась для обозначения евреев между собой и правящих ими."
	icon_state = "semitic_cap"
	item_state = "semitic_cap"
	worn_state = "semitic_cap"
	flags_inv = BLOCKHEADHAIR

/*Pelts*/

/obj/item/clothing/head/bearpelt
	name = "головной убор из медвежьей шкуры"
	desc = "Медвежья шкура переделанная под головной убор."
	icon_state = "bearpelt"
	item_state = "bearpelt"
	worn_state = "bearpelt"
	flags_inv = BLOCKHEADHAIR
	cold_protection = HEAD
	var/colortype = "black"

/obj/item/clothing/head/wolfpelt
	name = "головной убор из волчьей шкуры"
	desc = "Волчья шкура переделанная под головной убор."
	icon_state = "wolfpelt"
	item_state = "wolfpelt"
	worn_state = "wolfpelt"
	flags_inv = BLOCKHEADHAIR
	cold_protection = HEAD
	var/colortype = "grey"

/obj/item/clothing/head/wolfpelt/white
	name = "головной убор из белой волчьей шкуры"
	desc = "Волчья шкура переделанная под головной убор."
	icon_state = "whitewolfpelt"
	item_state = "whitewolfpelt"
	worn_state = "whitewolfpelt"
	colortype = "white"

/obj/item/clothing/head/pantherpelt
	name = "головной убор из пантерской шкуры"
	desc = "Пантерья шкура переделанная под головной убор."
	icon_state = "pantherpelt"
	item_state = "pantherpelt"
	worn_state = "pantherpelt"
	flags_inv = BLOCKHEADHAIR
	cold_protection = HEAD
	var/colortype = "black"

/obj/item/clothing/head/lionpelt
	name = "головной убор из львинной шкуры"
	desc = "Львинная шкура переделанная под головной убор."
	icon_state = "lionpelt"
	item_state = "lionpelt"
	worn_state = "lionpelt"
	flags_inv = BLOCKHEADHAIR
	cold_protection = HEAD
	var/colortype = "brown" //I haven't knocked together the coloration idea yet - @fantasticfwoosh

/obj/item/clothing/head/gatorpelt
	name = "головной убор из алигаторской шкуры"
	desc = "Алигаторская шкура переделанная под головной убор."
	icon_state = "gatorpelt"
	item_state = "gatorpelt"
	worn_state = "gatorpelt"
	flags_inv = BLOCKHEADHAIR
	heat_protection = HEAD
	var/colortype = "grey" //i really dont know what to put in this one - @fantasticfwoosh

/obj/item/clothing/head/foxpelt
	name = "головной убор из лисьей шкуры"
	desc = "Лисья шкура переделанная под головной убор."
	icon_state = "foxpelt"
	item_state = "foxpelt"
	worn_state = "foxpelt"
	flags_inv = BLOCKHEADHAIR
	cold_protection = HEAD
	var/colortype = "brown"

/obj/item/clothing/head/foxpelt/white
	name = "головной убор из белой лисьей шкуры"
	desc = "Лисья шкура переделанная под головной убор."
	icon_state = "whitefoxpelt"
	item_state = "whitefoxpelt"
	worn_state = "whitefoxpelt"
	colortype = "white"

/obj/item/clothing/head/sheeppelt
	name = "головной убор из овечьей шкуры"
	desc = "Овечья шкура переделанная под головной убор. Густая шерсть помогает защитить тело от холода."
	icon_state = "sheeppelt"
	item_state = "sheeppelt"
	worn_state = "sheeppelt"
	cold_protection = HEAD|ARMS
	var/colortype = "white"

/obj/item/clothing/head/goatpelt
	name = "головной убор из козьей шкуры"
	desc = "Козья шкура переделанная под головной убор. Легкий свободный мех защищает тело от солнечных лучей."
	icon_state = "goatpelt"
	item_state = "goatpelt"
	worn_state = "goatpelt"
	heat_protection = HEAD|ARMS
	var/colortype = "beige" //erm...

/obj/item/clothing/head/bisonpelt
	name = "головной убор из бизоньей шкуры"
	desc = "Шкура бизона переделанная под головной убор. Густой свалявшийся мех защищает тело от холода; рога только для вида."
	icon_state = "bisonpelt"
	item_state = "bisonpelt"
	worn_state = "bisonpelt"
	cold_protection = HEAD|ARMS
	var/colortype = "brown"

/*Fur Coats*/

/obj/item/clothing/suit/storage/coat
	var/hood = FALSE
	min_cold_protection_temperature = COAT_MIN_COLD_PROTECTION_TEMPERATURE

/obj/item/clothing/suit/storage/coat/fur
	name = "шуба"
	desc = "Толстая шуба из толстого меха отлично подойдет для зимы."
	icon_state = "fur_jacket1"
	item_state = "fur_jacket1"
	worn_state = "fur_jacket1"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 15, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 25)
	value = 65
	var/colorn = 1
	var/specific = FALSE
	flags_inv = BLOCKHEADHAIR

/obj/item/clothing/suit/storage/coat/fur/brown
	name = "коричневая шуба"
	desc = "Толстая коричневая шуба, отлично подходит для зимы."
	icon_state = "fur_jacket1"
	item_state = "fur_jacket1"
	worn_state = "fur_jacket1"
	specific = TRUE
	colorn = 1

/obj/item/clothing/suit/storage/coat/fur/white
	name = "белая шуба"
	desc = "Толстая белая шуба, отлично подходит для зимы."
	icon_state = "fur_jacket4"
	item_state = "fur_jacket4"
	worn_state = "fur_jacket4"
	specific = TRUE
	colorn = 4

/obj/item/clothing/suit/storage/coat/fur/black
	name = "чёрная шуба"
	desc = "Толстая чёрная шуба, отлично подходит для зимы."
	icon_state = "fur_jacket3"
	item_state = "fur_jacket3"
	worn_state = "fur_jacket3"
	specific = TRUE
	colorn = 3

/obj/item/clothing/suit/storage/coat/fur/grey
	name = "серая шуба"
	desc = "Толстая серая шуба, отлично подходит для зимы."
	icon_state = "fur_jacket2"
	item_state = "fur_jacket2"
	worn_state = "fur_jacket2"
	specific = TRUE
	colorn = 2

/obj/item/clothing/suit/storage/coat/fur/pink
	name = "кожаная шуба"
	desc = "Толстая шуба из кожи человека. Мерзость."
	icon_state = "fur_jacket5"
	item_state = "fur_jacket5"
	worn_state = "fur_jacket5"
	specific = TRUE
	colorn = 5

//orc fur coat & boots relocated to apparel_tribes.dm

/obj/item/clothing/suit/storage/coat/fur/New()
	..()
	if (!specific)
		colorn = pick(1,2,3,4)
		icon_state = "fur_jacket[colorn]"
		item_state = "fur_jacket[colorn]"
		worn_state = "fur_jacket[colorn]"

/obj/item/clothing/suit/storage/coat/fur/verb/toggle_hood()
	set category = null
	set src in usr
	set name = "Накинуть капюшон"

	if (ishuman(usr))
		var/mob/living/human/H = usr
		if (H.head)
			usr << "<span class = 'warning'>Сначала надо убрать [H.head]!</span>"
			return
	if (hood)
		icon_state = "fur_jacket[colorn]"
		item_state = "fur_jacket[colorn]"
		worn_state = "fur_jacket[colorn]"
		body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
		cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
		item_state_slots["slot_wear_suit"] = "fur_jacket[colorn]"
		usr << "<span class = 'danger'>Ты снимаешь капюшон.</span>"
		update_icon()
		hood = FALSE
		usr.update_inv_head(1)
		usr.update_inv_wear_suit(1)
		return
	else if (!hood)
		icon_state = "fur_jacket[colorn]h"
		item_state = "fur_jacket[colorn]h"
		worn_state = "fur_jacket[colorn]h"
		body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS|HEAD
		cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT|HEAD
		item_state_slots["slot_wear_suit"] = "fur_jacket[colorn]h"
		usr << "<span class = 'danger'>Ты прикрываешь голову капюшоном.</span>"
		update_icon()
		hood = TRUE
		usr.update_inv_head(1)
		usr.update_inv_wear_suit(1)
		return

/*Fur Shoes*/

/obj/item/clothing/shoes/fur
	name = "меховые сапоги"
	desc = "Сапожки из плотного меха."
	icon_state = "fur"
	item_state = "fur"
	worn_state = "fur"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 20, arrow = 10, gun = FALSE, energy = 25, bomb = 50, bio = 20, rad = 35)
	item_flags = NOSLIP
	siemens_coefficient = 0.6
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE
	var/colorn = 1
	var/specific = FALSE

/obj/item/clothing/shoes/fur/black
	name = "чёрные меховые сапоги"
	desc = "Сапожки из плотного меха."
	icon_state = "fur3"
	item_state = "fur3"
	worn_state = "fur3"
	specific = TRUE

/obj/item/clothing/shoes/fur/brown
	name = "коричневые меховые сапоги"
	desc = "Сапожки из плотного меха."
	icon_state = "fur1"
	item_state = "fur1"
	worn_state = "fur1"
	specific = TRUE

/obj/item/clothing/shoes/fur/white
	name = "белые меховые сапоги"
	desc = "Сапожки из плотного меха."
	icon_state = "fur4"
	item_state = "fur4"
	worn_state = "fur4"
	specific = TRUE

/obj/item/clothing/shoes/fur/grey
	name = "серые меховые сапоги"
	desc = "Сапожки из плотного меха."
	icon_state = "fur2"
	item_state = "fur2"
	worn_state = "fur2"
	specific = TRUE

/obj/item/clothing/shoes/fur/pink
	name = "кожанные сапоги"
	desc = "Сапожки из кожи человека."
	icon_state = "fur5"
	item_state = "fur5"
	worn_state = "fur5"
	specific = TRUE

/obj/item/clothing/shoes/fur/New()
	..()
	if (!specific)
		colorn = pick(1,2,3,4)
		icon_state = "fur[colorn]"
		item_state = "fur[colorn]"
		worn_state = "fur[colorn]"

/*Ancient Facemasks & Covers*/

/obj/item/clothing/mask/redkerchief
	name = "красный платок"
	desc = "Кусок легкой ткани, надеваемый на шею."
	icon_state = "redkerchief"
	item_state = "redkerchief"
	worn_state = "redkerchief"
	flags_inv = 0
	w_class = ITEM_SIZE_TINY
	var/toggled = FALSE

/obj/item/clothing/mask/shemagh
	name = "шемаг"
	desc = "Кусок легкой ткани, используемый для защиты головы и лица."
	icon_state = "shemagh0"
	item_state = "shemagh0"
	worn_state = "shemagh0"
	var/usedstate = "shemagh1"
	var/unusedstate = "shemagh0"
	var/partscovered = FACE|HEAD
	flags_inv = 0
	w_class = ITEM_SIZE_SMALL
	var/toggled = FALSE
	restricts_view = 1
	heat_protection = HEAD|FACE|EYES

/obj/item/clothing/mask/shemagh/redkerchief
	name = "красный платок"
	desc = "Кусок легкой ткани, надеваемый на шею."
	icon_state = "redkerchief0"
	item_state = "redkerchief0"
	worn_state = "redkerchief0"
	usedstate = "redkerchief1"
	unusedstate = "redkerchief0"
	partscovered = FACE
	flags_inv = 0
	w_class = ITEM_SIZE_SMALL

/obj/item/clothing/mask/shemagh/bluekerchief
	name = "синий платок"
	desc = "Кусок легкой ткани, надеваемый на шею."
	icon_state = "bluekerchief0"
	item_state = "bluekerchief0"
	worn_state = "bluekerchief0"
	usedstate = "bluekerchief1"
	unusedstate = "bluekerchief0"
	partscovered = FACE
	flags_inv = 0
	w_class = ITEM_SIZE_SMALL
/obj/item/clothing/mask/shemagh/yellowkerchief
	name = "жёлтый платок"
	desc = "Кусок легкой ткани, надеваемый на шею."
	icon_state = "yellowkerchief0"
	item_state = "yellowkerchief0"
	worn_state = "yellowkerchief0"
	usedstate = "yellowkerchief1"
	unusedstate = "yellowkerchief0"
	partscovered = FACE
	flags_inv = 0
	w_class = ITEM_SIZE_SMALL

/obj/item/clothing/mask/shemagh/greykerchief
	name = "серый платок"
	desc = "Кусок легкой ткани, надеваемый на шею."
	icon_state = "greykerchief0"
	item_state = "greykerchief0"
	worn_state = "greykerchief0"
	usedstate = "greykerchief1"
	unusedstate = "greykerchief0"
	partscovered = FACE
	flags_inv = 0
	w_class = ITEM_SIZE_SMALL

/obj/item/clothing/mask/shemagh/update_icon()
	if (toggled == FALSE)
		body_parts_covered = 0
		flags_inv = 0
		icon_state = unusedstate
		item_state = unusedstate
		worn_state = unusedstate
		heat_protection = 0
	else
		body_parts_covered = partscovered
		flags_inv = HIDEFACE
		icon_state = usedstate
		item_state = usedstate
		worn_state = usedstate
		heat_protection = HEAD|FACE|EYES
	..()

/obj/item/clothing/mask/shemagh/verb/toggle_hood()
	set category = null
	set src in usr
	set name = "Приубрать"
	if (toggled == TRUE)
		icon_state = unusedstate
		item_state = unusedstate
		worn_state = unusedstate
		body_parts_covered = 0
		flags_inv = 0
		usr << "<span class = 'danger'>Меняю положение [name].</span>"
		update_icon()
		toggled = FALSE
		usr.update_inv_wear_mask(1)
		return
	else if (toggled == FALSE)
		icon_state = usedstate
		item_state = usedstate
		worn_state = usedstate
		body_parts_covered = partscovered
		flags_inv = HIDEFACE
		usr << "<span class = 'danger'>Меняю положение [name].</span>"
		update_icon()
		toggled = TRUE
		usr.update_inv_wear_mask(1)
		return

/*Miscallaneous*/

	/* Asian Uniforms*/

/obj/item/clothing/under/kimono
	name = "белое кимоно"
	desc = "Простое кимоно в популярном азиатском стиле, под которым скрыто простое нижнее белье." //skipping the notion that its skintight.
	icon_state = "kimono"
	item_state = "kimono"
	worn_state = "kimono"

	/* Asian Uniforms - End*/

/obj/item/clothing/under/towel  //this was incorrectly reported as a exterior suit, it is actually a interior uniform
	name = "белое полотенце"
	desc = "Простое полотенце, которым можно обернуться."
	icon_state = "towel"
	item_state = "towel"
	worn_state = "towel"
	heat_protection = LOWER_TORSO

/obj/item/clothing/head/helmet/anax/aries //op fantasy helm
	name = "шлем Овна"
	desc = "Укрепленный бронзовый греческий шлем, закрывающий большую часть лица, с красным оперением сверху. Его носят божества и аватары разрушения, такие как Овен."
	icon_state = "aries"
	item_state = "aries"
	worn_state = "aries"
	armor = list(melee = 70, arrow = 60, gun = ARMOR_CLASS, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	health = 60

/obj/item/clothing/head/helmet/anax/athena
	name = "шлем Афины"
	desc = "Укрепленный бронзовый греческий шлем, закрывающий большую часть лица, с синим оперением сверху и золотым лавром. Выбрала шлем сама богиня тактической войны и знаний Афина."
	icon_state = "athena"
	item_state = "athena"
	worn_state = "athena"
	armor = list(melee = 70, arrow = 60, gun = ARMOR_CLASS, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	health = 60

/obj/item/clothing/head/helmet/asterix/apollo
	name = "заметный гэльский шлем"
	desc = "Золотой крылатый шлем бога солнца и света, а также вестника Олимпа. Владелец чувствует прилив энергии для быстрого движения."
	icon_state = "apollo"
	item_state = "apollo"
	worn_state = "apollo"
	armor = list(melee = 50, arrow = 40, gun = ARMOR_CLASS, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	health = 40
	slowdown = -0.25 //actually reduces your slowdown

/obj/item/clothing/head/helmet/asterix/conspicious //R.I.P Albert Uzdero / René Goscinny respectively.
	name = "заметный гэльский шлем"
	desc = "Трудно не заметить крылатый шлем с бело-черной отделкой и скромным красным галстуком, который часто носят предводители."
	icon_state = "vitalstatistix"
	item_state = "vitalstatistix"
	worn_state = "vitalstatistix"
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 50, arrow = 40, gun = ARMOR_CLASS, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	health = 40

/obj/item/clothing/head/helmet/egyptian/anubis
	name = "бронзовый головной убор Анубиса"
	desc = "Бронзовый египетский головной убор с изображением бога Анубиса - богом мёртвых."
	icon_state = "anubis"
	item_state = "anubis"
	worn_state = "anubis"
	flags_inv = BLOCKHAIR
	armor = list(melee = 70, arrow = 60, gun = ARMOR_CLASS, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	health = 60

/obj/item/clothing/head/helmet/egyptian/osiris
	name = "бронзовый головной убор Осирус"
	desc = "Бронзовый египетский головной убор с изображением бога Осириса - богом подземного мира."
	icon_state = "osiris"
	item_state = "osiris"
	worn_state = "osiris"
	flags_inv = BLOCKHAIR
	armor = list(melee = 70, arrow = 60, gun = ARMOR_CLASS, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	health = 60

/obj/item/clothing/head/atef
	name = "корона атеф"
	desc = "Белая египетская корона из ткани, украшенная плюмажами из перьев. Предпочитаемая корона египетской элиты."
	icon_state = "deshret"
	item_state = "deshret"
	worn_state = "deshret"
	flags_inv = BLOCKHEADHAIR
	heat_protection = HEAD|FACE|EYES

/obj/item/clothing/mask/anubis
	name = "маска анубиса"
	desc = "Бронзовая маска в виде египетского бога мёртвых Анубиса."
	icon_state = "anubis"
	item_state = "anubis"
	flags_inv = HIDEFACE
	body_parts_covered = FACE
	w_class = ITEM_SIZE_SMALL
	armor = list(melee = 15, arrow = 15, gun = FALSE, energy = 15, bomb = 45, bio = FALSE, rad = FALSE) //modest, weaker than japanese facemask
	blocks_scope = TRUE
	restricts_view = 1
	heat_protection = FACE|EYES
	flags = CONDUCT

/obj/item/clothing/under/mummywappings
	name = "льняные ткани"
	icon = 'icons/mob/uniform.dmi'
	icon_state = "mummy"
	item_state = "mummy"
	worn_state = "mummy"
	canremove = FALSE
	desc = "Затхлые ткани, кажется, рассыпаются, когда вы их рассматриваете."

/obj/item/clothing/mask/necklace/christian/gold
	name = "христианское золотое ожерелье"
	desc = " Христианское ожерелье из золота. Дорогое."
	icon_state = "necklace_christian_gold"
	item_state = "necklace_christian_gold"

/obj/item/clothing/mask/osiris
	name = "маска Осириса"
	desc = "Маска в виде египетского бога подземного мира Осириса."
	icon_state = "osiris"
	item_state = "osiris"
	flags_inv = HIDEFACE
	flags = CONDUCT
	body_parts_covered = FACE
	w_class = ITEM_SIZE_TINY
	armor = list(melee = 15, arrow = 15, gun = FALSE, energy = 15, bomb = 45, bio = FALSE, rad = FALSE)
	blocks_scope = TRUE
	restricts_view = 1
	heat_protection = FACE|EYES

/obj/item/clothing/mask/stone
	name = "каменная маска"
	desc = "Каменная маска с мужественным видом и клыками."
	icon_state = "stone_mask"
	item_state = "stone_mask"
	flags_inv = HIDEFACE
	body_parts_covered = FACE
	w_class = ITEM_SIZE_SMALL
	armor = list(melee = 5, arrow = 10, gun = FALSE, energy = 12, bomb = 45, bio = FALSE, rad = FALSE) //modest, weaker than japanese facemask
	blocks_scope = TRUE
	restricts_view = 1
	heat_protection = FACE|EYES

/obj/item/clothing/mask/stone_jewelled
	name = "каменная маска с драгоценным камнем"
	desc = "Каменная маска, украшенная драгоценным камнем, возможно, что-то вроде почетного одеяния?"
	icon_state = "stone_mask_jeweled"
	item_state = "stone_mask_jeweled"
	flags_inv = HIDEFACE
	body_parts_covered = FACE
	w_class = ITEM_SIZE_SMALL
	armor = list(melee = 20, arrow = 20, gun = FALSE, energy = 8, bomb = 67, bio = FALSE, rad = FALSE) //modest, weaker than japanese facemask
	blocks_scope = TRUE
	restricts_view = 1
	heat_protection = FACE|EYES

/obj/item/clothing/suit/armor/god_pharoah //copied broadly from /obj/item/clothing/suit/armor/sauronarmor
	name = "фараонские доспехи богов"
	desc = "Доспехи божественных богов пустыни."
	icon_state = "settra"
	item_state = "settra"
	worn_state = "settra"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 95, arrow = 90, gun = ARMOR_CLASS, energy = 20, bomb = 70, bio = 20, rad = 45)
	value = 70
	slowdown = 1
	health = 90
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO|ARMS

/obj/item/clothing/head/helmet/yellow_ninja
	name = "желтая повязка на голову ниндзя"
	desc = "Бронированная кожаная повязка на голову японского дизайна, ее ношение заставляет вас чувствовать себя быстрее и побуждает размахивать руками за спиной во время бега."
	icon_state = "yellow_ninja"
	item_state = "yellow_ninja"
	worn_state = "yellow_ninja"
	body_parts_covered = HEAD
	armor = list(melee = 30, arrow = 40, gun = FALSE, energy = 15, bomb = 25, bio = 20, rad = FALSE)
	health = 30
	slowdown = -0.40