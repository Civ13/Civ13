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
	name = "sandals"
	desc = "Basic leather sandals, going up to the knee."
	icon_state = "roman"
	item_state = "roman"
	worn_state = "roman"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 60, arrow = 5, gun = FALSE, energy = 25, bomb = 50, bio = 10, rad = FALSE)
	siemens_coefficient = 0.6

/obj/item/clothing/under/roman
	name = "roman legionary uniform"
	desc = "A red tunic covered with iron armor. Used by the roman army."
	icon_state = "roman"
	item_state = "roman"
	worn_state = "roman"
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO

/obj/item/clothing/under/toga
	name = "white toga"
	desc = "A simple cloth toga."
	icon_state = "toga"
	item_state = "toga"
	worn_state = "toga"
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO

/obj/item/clothing/under/toga2
	name = "half-shoulder white toga"
	desc = "A simple cloth toga, covering just one of the shoulders."
	icon_state = "toga2"
	item_state = "toga2"
	worn_state = "toga2"
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO

/obj/item/clothing/under/roman_centurion
	name = "roman centurion uniform"
	desc = "A red tunic covered with iron armor, with added golden plates. Used by the roman army's centurions."
	icon_state = "roman_centurion"
	item_state = "roman_centurion"
	worn_state = "roman_centurion"
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO

/*Greek Uniforms*/

/obj/item/clothing/under/greek1
	name = "greek uniform"
	desc = "A light tunic, covered with bronze and leather armor. Used by the hellenic armies."
	icon_state = "athens"
	item_state = "athens"
	worn_state = "athens"
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO

/obj/item/clothing/under/greek2
	name = "greek uniform"
	desc = "A light tunic, covered with bronze and leather armor. Used by the hellenic armies."
	icon_state = "thebes"
	item_state = "thebes"
	worn_state = "thebes"
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO

/obj/item/clothing/under/greek3
	name = "greek uniform"
	desc = "A light tunic, covered with bronze and leather armor. Used by the hellenic armies."
	icon_state = "corinthia"
	item_state = "corinthia"
	worn_state = "corinthia"
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO

/obj/item/clothing/under/greek_commander
	name = "greek commander uniform"
	desc = "A light blue tunic covered by a bronze plate armor. Used by hellenic commanders."
	icon_state = "greek_commander"
	item_state = "greek_commander"
	worn_state = "greek_commander"
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO

/obj/item/clothing/under/toxotai
	name = "white tunic"
	desc = "A light white tunic."
	icon_state = "toxotai"
	item_state = "toxotai"
	worn_state = "toxotai"
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO

/*Celtic Uniforms*/

/obj/item/clothing/under/celtic_green
	name = "green celtic trousers"
	desc = "Celtic-style trousers, in green."
	icon_state = "celtic_green"
	item_state = "celtic_green"
	worn_state = "celtic_green"
	heat_protection = LOWER_TORSO|LEGS

/obj/item/clothing/under/celtic_blue
	name = "blue celtic trousers"
	desc = "Celtic-style trousers, in blue."
	icon_state = "celtic_blue"
	item_state = "celtic_blue"
	worn_state = "celtic_blue"
	heat_protection = LOWER_TORSO|LEGS

/obj/item/clothing/under/celtic_red
	name = "red celtic trousers"
	desc = "Celtic-style trousers, in red."
	icon_state = "celtic_red"
	item_state = "celtic_red"
	worn_state = "celtic_red"
	heat_protection = LOWER_TORSO|LEGS

/obj/item/clothing/under/celtic_short_braccae
	name = "short celtic braccae"
	desc = "Short, celtic-style wool trousers."
	icon_state = "celtic_short_braccae"
	item_state = "celtic_short_braccae"
	worn_state = "celtic_short_braccae"
	heat_protection = LOWER_TORSO

/obj/item/clothing/under/celtic_long_braccae
	name = "long celtic braccae"
	desc = "Long, celtic-style wool trousers."
	icon_state = "celtic_long_braccae"
	item_state = "celtic_long_braccae"
	worn_state = "celtic_long_braccae"
	heat_protection = LOWER_TORSO|LEGS

/*Mayan & Aztec Uniforms + Sandals*/

/obj/item/clothing/under/mayan_loincloth
	name = "mayan loincloth"
	desc = "Mayan-style loincloth."
	icon_state = "mayan_loincloth"
	item_state = "mayan_loincloth"
	worn_state = "mayan_loincloth"
	heat_protection = LOWER_TORSO

/obj/item/clothing/under/aztec_loincloth
	name = "aztec loincloth"
	desc = "A loincloth fit for a ferocious aztec warrior."
	icon_state = "aztec_loincloth"
	item_state = "aztec_loincloth"
	worn_state = "aztec_loincloth"
	heat_protection = LOWER_TORSO

/obj/item/clothing/shoes/aztec_sandals
	name = "aztec sandals"
	desc = "Basic leather sandals, hailing from the jungles."
	icon_state = "aztec_sandals"
	item_state = "aztec_sandals"
	worn_state = "aztec_sandals"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 10, arrow = 5, gun = FALSE, energy = FALSE, bomb = 1, bio = FALSE, rad = FALSE)
	siemens_coefficient = 0.6

/*Egyptian Uniforms*/

/obj/item/clothing/under/pharaoh
	name = "pharaohic shendyt"
	desc = "A fancy, decorated shendyt."
	icon_state = "pharaoh"
	item_state = "pharaoh"
	worn_state = "pharaoh"
	heat_protection = LOWER_TORSO|UPPER_TORSO

/obj/item/clothing/under/pharaoh2
	name = "nemes shendyt"
	desc = "A fancy, decorated shendyt."
	icon_state = "greatshendyt"
	item_state = "greatshendyt"
	worn_state = "greatshendyt"
	heat_protection = LOWER_TORSO|UPPER_TORSO

/*Ainu Things*/
/obj/item/clothing/under/ainu
	name = "ainu robes"
	desc = "A set of robes worn by the ainu."
	icon_state = "ainu_robe"
	item_state = "ainu_robe"
	worn_state = "ainu_robe"
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO

/obj/item/clothing/under/ainu2
	name = "ainu robes"
	desc = "A set of robes worn by the ainu."
	icon_state = "ainu_robe2"
	item_state = "ainu_robe2"
	worn_state = "ainu_robe2"
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO

/obj/item/clothing/head/ainu_bandana
	name = "ainu bandana"
	desc = "a bandana with intricate patterns."
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
			usr << "<span class = 'danger'>You unfold your bandana.</span>"
			folded = FALSE
		else if (!folded)
			item_state = "ainu_smol"
			worn_state = "ainu_smol"
			item_state_slots["slot_w_head"] = "ainu_smol"
			usr << "<span class = 'danger'>You fold your bandana.</span>"
			folded = TRUE
	update_clothing_icon()

/*Ancient Armor*/

/obj/item/clothing/suit/armor
	health = 40
	ripable = FALSE
	flags = CONDUCT

/obj/item/clothing/suit/armor/ancient/scale
	name = "segmented armor"
	desc = "A thick, expensive segmented iron armor, covering the torso."
	icon_state = "scale_armor"
	item_state = "scale_armor"
	worn_state = "scale_armor"
	body_parts_covered = UPPER_TORSO
	armor = list(melee = 65, arrow = 45, gun = 10, energy = 15, bomb = 45, bio = 20, rad = 45)
	value = 40
	slowdown = 0.8
	health = 47

/obj/item/clothing/suit/armor/ancient/chainmail
	name = "early Chainmail"
	desc = "Wearable armor made of several small interlinked chains."
	icon_state = "early_chainmail"
	item_state = "early_chainmail"
	worn_state = "early_chainmail"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 50, arrow = 35, gun = 7, energy = 15, bomb = 30, bio = 20, rad = FALSE)
	value = 30
	slowdown = 0.6
	health = 50

/obj/item/clothing/suit/armor/ancient/linen
	name = "linothorax armor"
	desc = "A thick linen armor, covering the torso and lower body."
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
	name = "bronze egyptian lamellar"
	desc = "A bronze lamellar armor, used by soldiers of pharoahic dynasties."
	icon_state = "egyptian_lamellar"
	item_state = "egyptian_lamellar"
	worn_state = "egyptian_lamellar"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 50, arrow = 35, gun = 7, energy = 15, bomb = 40, bio = 20, rad = FALSE) //identical to bronze armor
	value = 25
	slowdown = 0.7
	health = 48

/obj/item/clothing/suit/armor/ancient/bronze_lamellar/chinese
	name = "bronze chinese lamellar"
	desc = "A bronze lamellar armor, used by warriors of early chinese dynasties."
	icon_state = "chinese_lamellar"
	item_state = "chinese_lamellar"
	worn_state = "chinese_lamellar"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 50, arrow = 35, gun = 7, energy = 15, bomb = 40, bio = 20, rad = FALSE)
	value = 25
	slowdown = 0.7
	health = 48


/obj/item/clothing/suit/armor/ancient/scaled
	name = "scaled armor"
	desc = "An armor made of serveral scales made of bronze."
	icon_state = "scaled_armor"
	item_state = "scaled_armor"
	worn_state = "scaled_armor"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 50, arrow = 35, gun = 7, energy = 15, bomb = 40, bio = 20, rad = FALSE)
	value = 25
	slowdown = 0.7
	health = 48


/obj/item/clothing/suit/armor/ancient/aztec_harness
	name = "aztec harness"
	desc = "A few metal plates on leather strips, covering the torso."
	icon_state = "aztec_harness"
	item_state = "aztec_harness"
	worn_state = "aztec_harness"
	body_parts_covered = UPPER_TORSO
	armor = list(melee = 35, arrow = 15, gun = 2, energy = 2, bomb = 2, bio = FALSE, rad = FALSE)
	value = 40
	slowdown = 0.2
	health = 18

/obj/item/clothing/suit/armor/ancient/gator_scale_armor
	name = "alligator scale armor"
	desc = "A carefully cured & hardened alligator scale armor, covering the torso."
	icon_state = "gator_scale_armor"
	item_state = "gator_scale_armor"
	worn_state = "gator_scale_armor"
	body_parts_covered = UPPER_TORSO
	armor = list(melee = 45, arrow = 25, gun = 5, energy = 10, bomb = 20, bio = 20, rad = 10)
	value = 40
	slowdown = 0.2
	health = 18

/*Ancient Capes*/

/obj/item/clothing/suit/cape
	name = "red cape"
	desc = "A long red cape."
	icon_state = "redcape"
	item_state = "redcape"
	worn_state = "redcape"

/obj/item/clothing/suit/cape/blue
	name = "blue cape"
	desc = "A long blue cape."
	icon_state = "bluecape"
	item_state = "bluecape"
	worn_state = "bluecape"

/*Ancient Headpieces*/

/obj/item/clothing/head/toxotai
	name = "toxotai hat"
	desc = "a wide brim hat, used by the toxotai."
	icon_state = "toxotai"
	item_state = "toxotai"
	worn_state = "toxotai"

/obj/item/clothing/head/egyptian_headdress_black
	name = "black egyptian headdress"
	desc = "a plain sun-protective linen headdress, despite its black stripes."
	icon_state = "egyptian_headdress_black"
	item_state = "egyptian_headdress_black"
	worn_state = "egyptian_headdress_black"
	flags_inv = BLOCKHEADHAIR
	heat_protection = HEAD|FACE|EYES

/obj/item/clothing/head/egyptian_headdress_blue
	name = "blue egyptian headdress"
	desc = "a plain sun-protective blue linen headdress."
	icon_state = "egyptian_headdress_blue"
	item_state = "egyptian_headdress_blue"
	worn_state = "egyptian_headdress_blue"
	flags_inv = BLOCKHEADHAIR
	heat_protection = HEAD|FACE|EYES

/obj/item/clothing/head/egyptian_headdress_red
	name = "red egyptian headdress"
	desc = "a plain sun-protective red linen headdress."
	icon_state = "egyptian_headdress_red"
	item_state = "egyptian_headdress_red"
	worn_state = "egyptian_headdress_red"
	flags_inv = BLOCKHEADHAIR
	heat_protection = HEAD|FACE|EYES

/*Ancient Helmets*/

/obj/item/clothing/head/helmet/roman
	name = "roman legionary helmet"
	desc = "The typical helmet of the roman army."
	icon_override = 'code/modules/1713/clothing/head.dmi'
	icon_state = "roman"
	item_state = "roman"
	worn_state = "roman"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 50, arrow = 40, gun = 10, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	health = 35

/obj/item/clothing/head/helmet/roman_decurion
	name = "roman decurion helmet"
	desc = "An iron helmet, used by decurions. Officers within the cavalry of the roman army."
	icon_override = 'code/modules/1713/clothing/head.dmi'
	icon_state = "roman_d"
	item_state = "roman_d"
	worn_state = "roman_d"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 50, arrow = 40, gun = 10, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	health = 35

/obj/item/clothing/head/helmet/roman_centurion
	name = "roman centurion helmet"
	desc = "An iron helmet, used by centurions. Officers within the infantry of the roman army."
	icon_override = 'code/modules/1713/clothing/head.dmi'
	icon_state = "roman_c"
	item_state = "roman_c"
	worn_state = "roman_c"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 50, arrow = 40, gun = 10, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	health = 35

/obj/item/clothing/head/helmet/gladiator
	name = "gladiator helmet"
	desc = "A gladiator helmet."
	icon_state = "gladiator"
	item_state = "gladiator"
	worn_state = "gladiator"
	body_parts_covered = HEAD|FACE|EYES
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 60, arrow = 45, gun = 10, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	health = 40

/obj/item/clothing/head/helmet/solinvictus
	name = "sol invictus helmet"
	desc = "A gold adorned helmet with masqued visage and gold solar streaks. Worn by roman emperors."
	icon_state = "sol_invictus"
	item_state = "sol_invictus"
	worn_state = "sol_invictus"
	body_parts_covered = HEAD|FACE|EYES
	flags_inv = BLOCKHAIR
	armor = list(melee = 65, arrow = 50, gun = 10, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	restricts_view = 2
	health = 55
	slowdown = 0.25

/obj/item/clothing/head/helmet/anax
	name = "greek anax helmet"
	desc = "A reinforced bronze greek helmet, covering most of the face, with black plummage on top. Worn by hellenic kings."
	icon_state = "leonidas"
	item_state = "leonidas"
	worn_state = "leonidas"
	body_parts_covered = HEAD|FACE|EYES
	flags_inv = BLOCKHAIR
	armor = list(melee = 60, arrow = 45, gun = 5, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	restricts_view = 1
	health = 50
	slowdown = 0.10

/obj/item/clothing/head/helmet/greek
	name = "greek helmet"
	desc = "A bronze greek helmet, covering most of the face."
	icon_state = "new_greek"
	item_state = "new_greek"
	worn_state = "new_greek"
	body_parts_covered = HEAD|FACE|EYES
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 62, arrow = 44, gun = 10, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	health = 40

/obj/item/clothing/head/helmet/greek_commander
	name = "lochagos helmet"
	desc = "A bronze greek helmet, covering most of the face, with red plummage on top. Worn by hellenic lochagos."
	icon_state = "spartan"
	item_state = "spartan"
	worn_state = "spartan"
	body_parts_covered = HEAD|FACE|EYES
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 62, arrow = 44, gun = 10, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	health = 40

/obj/item/clothing/head/helmet/greek_sl
	name = "dimoerites helmet"
	desc = "A bronze greek helmet, covering most of the face, with blue plummage on top. Worn by hellenic dimoerites."
	icon_state = "athenian"
	item_state = "athenian"
	worn_state = "athenian"
	body_parts_covered = HEAD|FACE|EYES
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 62, arrow = 44, gun = 10, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	health = 40

/obj/item/clothing/head/helmet/egyptian
	name = "egyptian war headdress"
	desc = "A bronze egyptian headpiece, with a exposed face to relieve the wearer of heat."
	icon_state = "egyptian_bronze_headdress"
	item_state = "egyptian_bronze_headdress"
	worn_state = "egyptian_bronze_headdress"
	body_parts_covered = HEAD|EYES
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 50, arrow = 40, gun = 10, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	health = 35
	heat_protection = HEAD|FACE|EYES

/obj/item/clothing/head/helmet/phrigian
	name = "bronze phrigian helmet"
	desc = "A knob ended bronze phrigian helmet. With more emphasis on style than overall protection"
	icon_state = "phrigian_helmet"
	item_state = "phrigian_helmet"
	worn_state = "phrigian_helmet"
	body_parts_covered = HEAD
	armor = list(melee = 38, arrow = 25, gun = FALSE, energy = 15, bomb = 30, bio = 20, rad = FALSE)
	health = 30


/obj/item/clothing/head/helmet/leather
	name = "leather helmet"
	desc = "A simple leather helmet."
	icon_state = "leatherhelmet"
	item_state = "leatherhelmet"
	worn_state = "leatherhelmet"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 27, arrow = 15, gun = FALSE, energy = 15, bomb = 25, bio = 20, rad = FALSE)
	health = 20

/obj/item/clothing/head/helmet/hatchigane
	name = "hatchigane headband"
	desc = "A armored leather headband of japanese design, it wears away petty attacks but will not withstand heavy blows."
	icon_state = "hatchigane"
	item_state = "hatchigane"
	worn_state = "hatchigane"
	body_parts_covered = HEAD
	armor = list(melee = 15, arrow = 15, gun = FALSE, energy = 15, bomb = 25, bio = 20, rad = FALSE)
	health = 15

/obj/item/clothing/head/helmet/khepresh
	name = "khepresh war crown"
	desc = "A ornate egyptian war crown made of leather and gold. It is not as protective as bronze or iron, but practical for protecting your majesty."
	icon_state = "khepresh"
	item_state = "khepresh"
	worn_state = "khepresh"
	body_parts_covered = HEAD
	armor = list(melee = 30, arrow = 20, gun = FALSE, energy = 15, bomb = 40, bio = 20, rad = FALSE) //lightly stronger than leather
	health = 30

	/* Nomads (Craftable) Helmets*/

/obj/item/clothing/head/helmet/gladiator/nomads //nerfing it down for mass consumption
	name = "gladiator helmet"
	desc = "A gladiator helmet."
	icon_state = "gladiator"
	item_state = "gladiator"
	worn_state = "gladiator"
	body_parts_covered = HEAD|FACE|EYES
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 45, arrow = 30, gun = FALSE, energy = 15, bomb = 40, bio = 20, rad = FALSE)
	health = 30

/obj/item/clothing/head/helmet/horned
	name = "horned helmet"
	desc = "A horned helmet, used by barbarians."
	icon_state = "barbarian" //"viking" can be used elsewise for wagner
	item_state = "barbarian"
	worn_state = "barbarian"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 45, arrow = 30, gun = FALSE, energy = 15, bomb = 40, bio = 20, rad = FALSE)
	health = 30

/obj/item/clothing/head/helmet/asterix
	name = "winged helmet"
	desc = "A winged helmet, used swift warriors who don't mind brutalistic stabs to the face."
	icon_state = "asterix"
	item_state = "asterix"
	worn_state = "asterix"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 45, arrow = 30, gun = FALSE, energy = 15, bomb = 40, bio = 20, rad = FALSE)
	health = 30

/obj/item/clothing/head/helmet/egyptian/nomads
	name = "egyptian war headdress"
	desc = "A bronze egyptian headdress, with a exposed face to relieve the wearer of heat."
	icon_state = "egyptian_bronze_headdress"
	item_state = "egyptian_bronze_headdress"
	worn_state = "egyptian_bronze_headdress"
	body_parts_covered = HEAD|EYES
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 45, arrow = 30, gun = FALSE, energy = 15, bomb = 40, bio = 20, rad = FALSE)
	health = 30
	heat_protection = HEAD|FACE|EYES

/obj/item/clothing/head/helmet/greek/nomads
	name = "greek helmet"
	desc = "A bronze greek helmet, covering most of the face."
	icon_state = "new_greek"
	item_state = "new_greek"
	worn_state = "new_greek"
	body_parts_covered = HEAD|FACE|EYES
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 45, arrow = 30, gun = FALSE, energy = 15, bomb = 40, bio = 20, rad = FALSE)
	health = 30

/obj/item/clothing/head/helmet/greek_commander/nomads
	name = "lochagos helmet"
	desc = "A bronze greek helmet, covering most of the face, with red plummage on top. Worn by hellenic lochagos."
	icon_state = "spartan"
	item_state = "spartan"
	worn_state = "spartan"
	body_parts_covered = HEAD|FACE|EYES
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 50, arrow = 40, gun = 5, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	health = 40

/obj/item/clothing/head/helmet/greek_sl/nomads
	name = "dimoerites helmet"
	desc = "A bronze greek helmet, covering most of the face, with blue plummage on top. Worn by hellenic dimoerites."
	icon_state = "athenian"
	item_state = "athenian"
	worn_state = "athenian"
	body_parts_covered = HEAD|FACE|EYES
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 50, arrow = 40, gun = 5, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	health = 40

/obj/item/clothing/head/helmet/roman/nomads
	name = "roman legionary helmet"
	desc = "The typical helmet of the roman army."
	icon_override = 'code/modules/1713/clothing/head.dmi'
	icon_state = "roman"
	item_state = "roman"
	worn_state = "roman"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 45, arrow = 30, gun = FALSE, energy = 15, bomb = 40, bio = 20, rad = FALSE) //nerfed
	health = 30

/obj/item/clothing/head/helmet/chinese_warrior
	name = "chinese warrior helmet"
	desc = "A bronze helmet, used by early chinese dynasties."
	icon_state = "bronze_chinese"
	item_state = "bronze_chinese"
	worn_state = "bronze_chinese"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 45, arrow = 30, gun = FALSE, energy = 15, bomb = 40, bio = 20, rad = FALSE)
	health = 30

/*Royal & Laurel Headwear*/

/obj/item/clothing/head/pharoah
	name = "pharoah headdress"
	desc = "A ornate, golden headdress."
	icon_state = "pharoah_headdress"
	item_state = "pharoah_headdress"
	worn_state = "pharoah_headdress"
	flags_inv = BLOCKHEADHAIR
	heat_protection = HEAD|FACE|EYES

/obj/item/clothing/head/nemes
	name = "nemes headdress"
	desc = "A fancy, golden headdress."
	icon_state = "nemes_headdress"
	item_state = "nemes_headdress"
	worn_state = "nemes_headdress"
	flags_inv = BLOCKHEADHAIR
	heat_protection = HEAD|FACE|EYES

/obj/item/clothing/head/doublecrown //replaced by hedjet/deshret/pschent following
	name = "double crown"
	desc = "A double-coloured cloth crown."
	icon_state = "doublecrown"
	item_state = "doublecrown"
	worn_state = "doublecrown"

/obj/item/clothing/head/hedjet
	name = "hedjet crown"
	desc = "A egyptian crown made from cloth. It is often worn by pharoahs ruling over the floodplains." //historically the northern pharoahs nearer to the nile delta
	icon_state = "hedjet"
	item_state = "hedjet"
	worn_state = "hedjet"
	flags_inv = BLOCKHEADHAIR
	heat_protection = HEAD|FACE|EYES

/obj/item/clothing/head/deshret
	name = "deshret crown"
	desc = "A red egyptian crown made from cloth. It is often worn by pharoahs ruling over desert dunes." //historically the southern pharoahs nearer to the nubian desert
	icon_state = "deshret"
	item_state = "deshret"
	worn_state = "deshret"
	flags_inv = BLOCKHEADHAIR
	heat_protection = HEAD|FACE|EYES

/obj/item/clothing/head/pschent
	name = "pschent crown"
	desc = "A combined red and white egyptian crown made from cloth. Combined of deshret & hedjet; it represents divine authority over their domain." //worn by herod, of a united egyptian kingdom.
	icon_state = "pschent"
	item_state = "pschent"
	worn_state = "pschent"
	flags_inv = BLOCKHEADHAIR
	heat_protection = HEAD|FACE|EYES

/obj/item/clothing/head/laurelcrown
	name = "laurel crown"
	desc = "A crown made of laurel."
	icon_state = "laurelcrown"
	item_state = "laurelcrown"
	body_parts_covered = FALSE

/obj/item/clothing/head/laurelcrown/gold
	name = "gold laurel crown"
	desc = "A crown made of gold, imitating a laurel crown."
	icon_state = "laurelcrown_gold"
	item_state = "laurelcrown_gold"
	body_parts_covered = FALSE

/* Religious Headwear*/

/obj/item/clothing/head/fiendish
	name = "fiendish headdress"
	desc = "A menacing headdress, preferred by cults & covens."
	icon_state = "fiendish"
	item_state = "fiendish"
	worn_state = "fiendish"
	flags_inv = BLOCKHEADHAIR

/obj/item/clothing/head/fiendish/blugi
	color = "#2a28b6"


/obj/item/clothing/head/semitic_cap
	name = "semitic cap"
	desc = "A yellow knob-headed hat applied to denote jews amongst themselves and those ruling over them."
	icon_state = "semitic_cap"
	item_state = "semitic_cap"
	worn_state = "semitic_cap"
	flags_inv = BLOCKHEADHAIR

/*Pelts*/

/obj/item/clothing/head/bearpelt
	name = "bearpelt headcover"
	desc = "a bear pelt turned into a headcover."
	icon_state = "bearpelt"
	item_state = "bearpelt"
	worn_state = "bearpelt"
	flags_inv = BLOCKHEADHAIR
	cold_protection = HEAD
	var/colortype = "black"

/obj/item/clothing/head/wolfpelt
	name = "wolfpelt headcover"
	desc = "a wolf pelt turned into a headcover."
	icon_state = "wolfpelt"
	item_state = "wolfpelt"
	worn_state = "wolfpelt"
	flags_inv = BLOCKHEADHAIR
	cold_protection = HEAD
	var/colortype = "grey"

/obj/item/clothing/head/wolfpelt/white
	name = "white wolfpelt headcover"
	desc = "A wolf pelt turned into a headcover."
	icon_state = "whitewolfpelt"
	item_state = "whitewolfpelt"
	worn_state = "whitewolfpelt"
	colortype = "white"

/obj/item/clothing/head/pantherpelt
	name = "pantherpelt headcover"
	desc = "A panther pelt turned into a headcover."
	icon_state = "pantherpelt"
	item_state = "pantherpelt"
	worn_state = "pantherpelt"
	flags_inv = BLOCKHEADHAIR
	cold_protection = HEAD
	var/colortype = "black"

/obj/item/clothing/head/lionpelt
	name = "lionpelt headcover"
	desc = "A lion pelt turned into a headcover."
	icon_state = "lionpelt"
	item_state = "lionpelt"
	worn_state = "lionpelt"
	flags_inv = BLOCKHEADHAIR
	cold_protection = HEAD
	var/colortype = "brown" //I haven't knocked together the coloration idea yet - @fantasticfwoosh

/obj/item/clothing/head/gatorpelt
	name = "alligator pelt headcover"
	desc = "A alligator pelt turned into a headcover."
	icon_state = "gatorpelt"
	item_state = "gatorpelt"
	worn_state = "gatorpelt"
	flags_inv = BLOCKHEADHAIR
	heat_protection = HEAD
	var/colortype = "grey" //i really dont know what to put in this one - @fantasticfwoosh

/obj/item/clothing/head/foxpelt
	name = "foxpelt headcover"
	desc = "A fox pelt turned into a headcover."
	icon_state = "foxpelt"
	item_state = "foxpelt"
	worn_state = "foxpelt"
	flags_inv = BLOCKHEADHAIR
	cold_protection = HEAD
	var/colortype = "brown"

/obj/item/clothing/head/foxpelt/white
	name = "white foxpelt headcover"
	desc = "A fox pelt turned into a headcover."
	icon_state = "whitefoxpelt"
	item_state = "whitefoxpelt"
	worn_state = "whitefoxpelt"
	colortype = "white"

/obj/item/clothing/head/sheeppelt
	name = "sheep-pelt headcover"
	desc = "A sheep pelt turned into a headcover. The thick wool helps keep the cold off your body."
	icon_state = "sheeppelt"
	item_state = "sheeppelt"
	worn_state = "sheeppelt"
	cold_protection = HEAD|ARMS
	var/colortype = "white"

/obj/item/clothing/head/goatpelt
	name = "goatpelt headcover"
	desc = "A goat pelt turned into a headcover. The light loose fur helps keep the sun's rays off your body."
	icon_state = "goatpelt"
	item_state = "goatpelt"
	worn_state = "goatpelt"
	heat_protection = HEAD|ARMS
	var/colortype = "beige" //erm...

/obj/item/clothing/head/bisonpelt
	name = "bisonpelt headcover"
	desc = "A bison pelt turned into a headcover. The thick matted fur keeps the cold off your body; the horns are just for show."
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
	name = "fur coat"
	desc = "A thick fur coat, great for the winter."
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
	name = "brown fur coat"
	desc = "A thick brown fur coat, great for the winter."
	icon_state = "fur_jacket1"
	item_state = "fur_jacket1"
	worn_state = "fur_jacket1"
	specific = TRUE
	colorn = 1

/obj/item/clothing/suit/storage/coat/fur/white
	name = "white fur coat"
	desc = "A thick white fur coat, great for the winter."
	icon_state = "fur_jacket4"
	item_state = "fur_jacket4"
	worn_state = "fur_jacket4"
	specific = TRUE
	colorn = 4

/obj/item/clothing/suit/storage/coat/fur/black
	name = "black fur coat"
	desc = "A thick black fur coat, great for the winter."
	icon_state = "fur_jacket3"
	item_state = "fur_jacket3"
	worn_state = "fur_jacket3"
	specific = TRUE
	colorn = 3

/obj/item/clothing/suit/storage/coat/fur/grey
	name = "grey fur coat"
	desc = "A thick grey fur coat, great for the winter."
	icon_state = "fur_jacket2"
	item_state = "fur_jacket2"
	worn_state = "fur_jacket2"
	specific = TRUE
	colorn = 2

/obj/item/clothing/suit/storage/coat/fur/pink
	name = "human skin coat"
	desc = "A coat made of human skin. Spooky..."
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
	set name = "Toggle Hood"

	if (ishuman(usr))
		var/mob/living/human/H = usr
		if (H.head)
			usr << "<span class = 'warning'>You cannot put your hood up, the [H.head] is in the way!</span>"
			return
	if (hood)
		icon_state = "fur_jacket[colorn]"
		item_state = "fur_jacket[colorn]"
		worn_state = "fur_jacket[colorn]"
		body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
		cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
		item_state_slots["slot_wear_suit"] = "fur_jacket[colorn]"
		usr << "<span class = 'danger'>You take off your coat's hood.</span>"
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
		usr << "<span class = 'danger'>You cover your head with your coat's hood.</span>"
		update_icon()
		hood = TRUE
		usr.update_inv_head(1)
		usr.update_inv_wear_suit(1)
		return

/*Fur Shoes*/

/obj/item/clothing/shoes/fur
	name = "fur boots"
	desc = "Dense fur boots."
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
	name = "black fur boots"
	desc = "Dense fur boots."
	icon_state = "fur3"
	item_state = "fur3"
	worn_state = "fur3"
	specific = TRUE

/obj/item/clothing/shoes/fur/brown
	name = "brown fur boots"
	desc = "Dense fur boots."
	icon_state = "fur1"
	item_state = "fur1"
	worn_state = "fur1"
	specific = TRUE

/obj/item/clothing/shoes/fur/white
	name = "white fur boots"
	desc = "Dense fur boots."
	icon_state = "fur4"
	item_state = "fur4"
	worn_state = "fur4"
	specific = TRUE

/obj/item/clothing/shoes/fur/grey
	name = "grey fur boots"
	desc = "Dense fur boots."
	icon_state = "fur2"
	item_state = "fur2"
	worn_state = "fur2"
	specific = TRUE

/obj/item/clothing/shoes/fur/pink
	name = "human skin boots"
	desc = "Human skin boots."
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
	name = "red kerchief"
	desc = "A piece of light cloth, worn around the neck."
	icon_state = "redkerchief"
	item_state = "redkerchief"
	worn_state = "redkerchief"
	flags_inv = 0
	w_class = ITEM_SIZE_TINY
	var/toggled = FALSE

/obj/item/clothing/mask/shemagh
	name = "shemagh"
	desc = "A piece of light cloth, used to protect the head and face."
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
	name = "red kerchief"
	desc = "A piece of light cloth, worn around the neck."
	icon_state = "redkerchief0"
	item_state = "redkerchief0"
	worn_state = "redkerchief0"
	usedstate = "redkerchief1"
	unusedstate = "redkerchief0"
	partscovered = FACE
	flags_inv = 0
	w_class = ITEM_SIZE_SMALL

/obj/item/clothing/mask/shemagh/bluekerchief
	name = "blue kerchief"
	desc = "A piece of light cloth, worn around the neck."
	icon_state = "bluekerchief0"
	item_state = "bluekerchief0"
	worn_state = "bluekerchief0"
	usedstate = "bluekerchief1"
	unusedstate = "bluekerchief0"
	partscovered = FACE
	flags_inv = 0
	w_class = ITEM_SIZE_SMALL
/obj/item/clothing/mask/shemagh/yellowkerchief
	name = "yellow kerchief"
	desc = "A piece of light cloth, worn around the neck."
	icon_state = "yellowkerchief0"
	item_state = "yellowkerchief0"
	worn_state = "yellowkerchief0"
	usedstate = "yellowkerchief1"
	unusedstate = "yellowkerchief0"
	partscovered = FACE
	flags_inv = 0
	w_class = ITEM_SIZE_SMALL

/obj/item/clothing/mask/shemagh/greykerchief
	name = "grey kerchief"
	desc = "A piece of light cloth, worn around the neck."
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
	set name = "Toggle"
	if (toggled == TRUE)
		icon_state = unusedstate
		item_state = unusedstate
		worn_state = unusedstate
		body_parts_covered = 0
		flags_inv = 0
		usr << "<span class = 'danger'>You adjust the [name].</span>"
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
		usr << "<span class = 'danger'>You adjust the [name].</span>"
		update_icon()
		toggled = TRUE
		usr.update_inv_wear_mask(1)
		return

/*Miscallaneous*/

	/* Asian Uniforms*/

/obj/item/clothing/under/kimono
	name = "white kimono"
	desc = "A plain kimono in popular asian style, with simplistic underwear concealed beneath." //skipping the notion that its skintight.
	icon_state = "kimono"
	item_state = "kimono"
	worn_state = "kimono"

	/* Asian Uniforms - End*/

/obj/item/clothing/under/towel  //this was incorrectly reported as a exterior suit, it is actually a interior uniform
	name = "white towel"
	desc = "A simple towel to wrap around yourself."
	icon_state = "towel"
	item_state = "towel"
	worn_state = "towel"
	heat_protection = LOWER_TORSO

/obj/item/clothing/head/helmet/anax/aries //op fantasy helm
	name = "aries helmet"
	desc = "A reinforced bronze greek helmet, covering most of the face, with red plummage on top. Worn by dieties and avatars of destruction such as aries."
	icon_state = "aries"
	item_state = "aries"
	worn_state = "aries"
	armor = list(melee = 70, arrow = 60, gun = 20, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	health = 60

/obj/item/clothing/head/helmet/anax/athena
	name = "athena helmet"
	desc = "A reinforced bronze greek helmet, covering most of the face, with blue plummage on top and a gold laurel. Chosen helm of the god of tactical warfare and knowledge athena herself."
	icon_state = "athena"
	item_state = "athena"
	worn_state = "athena"
	armor = list(melee = 70, arrow = 60, gun = 20, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	health = 60

/obj/item/clothing/head/helmet/asterix/apollo
	name = "conspicious gaelic helmet"
	desc = "The gold winged helmet of the god of the sun and light, as well a a messenger of olympus. The wearer feels energized to move quickly"
	icon_state = "apollo"
	item_state = "apollo"
	worn_state = "apollo"
	armor = list(melee = 50, arrow = 40, gun = 5, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	health = 40
	slowdown = -0.25 //actually reduces your slowdown

/obj/item/clothing/head/helmet/asterix/conspicious //R.I.P Albert Uzdero / René Goscinny respectively.
	name = "conspicious gaelic helmet"
	desc = "A hard to miss winged helmet with white & black trimmings and modest red necktie, often worn by chieftains."
	icon_state = "vitalstatistix"
	item_state = "vitalstatistix"
	worn_state = "vitalstatistix"
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 50, arrow = 40, gun = 5, energy = 15, bomb = 50, bio = 20, rad = FALSE)
	health = 40

/obj/item/clothing/head/helmet/egyptian/anubis
	name = "bronze anubis headdress"
	desc = "A bronze egyptian headpiece, with the visage of the god anubis; god of the dead."
	icon_state = "anubis"
	item_state = "anubis"
	worn_state = "anubis"
	flags_inv = BLOCKHAIR
	armor = list(melee = 70, arrow = 60, gun = 20, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	health = 60

/obj/item/clothing/head/helmet/egyptian/osiris
	name = "bronze osirus headdress"
	desc = "A bronze egyptian headpiece, with the visage of the god osiris; god of the underworld."
	icon_state = "osiris"
	item_state = "osiris"
	worn_state = "osiris"
	flags_inv = BLOCKHAIR
	armor = list(melee = 70, arrow = 60, gun = 20, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	health = 60

/obj/item/clothing/head/atef
	name = "atef crown"
	desc = "A white egyptian crown made from cloth adorned with plumes of feathers. The preferred crown of egyptian dieties."
	icon_state = "deshret"
	item_state = "deshret"
	worn_state = "deshret"
	flags_inv = BLOCKHEADHAIR
	heat_protection = HEAD|FACE|EYES

/obj/item/clothing/mask/anubis
	name = "anubis mask"
	desc = "A bronze mask in the form of a the egyptian god of the dead, anubis."
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
	name = "linnen wrappings"
	icon = 'icons/mob/uniform.dmi'
	icon_state = "mummy"
	item_state = "mummy"
	worn_state = "mummy"
	canremove = FALSE
	desc = "The musty wrappings seem to disintigrate as you examine them."

/obj/item/clothing/mask/necklace/christian/gold
	name = "christian gold necklace"
	desc = " A golden necklace with a christian cross. It is made out of gold. Looks expensive."
	icon_state = "necklace_christian_gold"
	item_state = "necklace_christian_gold"

/obj/item/clothing/mask/osiris
	name = "osiris mask"
	desc = "A mask in the form of a the egyptian god of the underworld, osiris."
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
	name = "stone mask"
	desc = "A stone mask with a masculine apperance with fangs."
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
	name = "jewelled stone mask"
	desc = "A jewelled stone mask, possibly sometype of honorific attire?"
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
	name = "pharoahic armor of the gods"
	desc = "The armor of the divine gods of the desert"
	icon_state = "settra"
	item_state = "settra"
	worn_state = "settra"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 95, arrow = 90, gun = 30, energy = 20, bomb = 70, bio = 20, rad = 45)
	value = 70
	slowdown = 1
	health = 90
	heat_protection = LOWER_TORSO|LEGS|UPPER_TORSO|ARMS

/obj/item/clothing/head/helmet/yellow_ninja
	name = "yellow ninja headband"
	desc = "A armored leather headband of japanese design, wearing it makes you feel faster and the urge to flail your arms behind you as you run."
	icon_state = "yellow_ninja"
	item_state = "yellow_ninja"
	worn_state = "yellow_ninja"
	body_parts_covered = HEAD
	armor = list(melee = 30, arrow = 40, gun = FALSE, energy = 15, bomb = 25, bio = 20, rad = FALSE)
	health = 30
	slowdown = -0.40