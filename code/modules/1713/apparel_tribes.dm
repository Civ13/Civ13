/* Created by @FantasticFwoosh for extra-racial tribes mode content or surreal fantasy content.
All eras are accepted, preferably store them in relevant sections with appropriate typepaths, index is sorted as of time of writing.*/

/*Index*/
/*	* - 1. Stone Age Tribes & Content (Others)
	* - 2. Classical Era Tribes & Content (Crabs)
	* - 3. Medieval Era Tribes & Content (Orcs)
	* - 3a. Sauron & Orc Cultural Clothes
	* - 3b. Other Orc Clothes & Accessories
	* - 3c. Orc Weapons
	* - 4. Imperial Era Tribes & Content (Humans)
	* - 5. Other Fantasy Objects
	* - 5a. Other Fantasy Clothing
	* - 5b. Fantasy Materials*/


/* - 1. Stone Age Tribes & Content (Wolfmen, Gorillas, Ants, Lizards)*/

/obj/item/clothing/mask/chitinmask
	name = "chitin mask"
	desc = "A mask made from insect chitin."
	icon_state = "chitin_mask"
	item_state = "chitin_mask"
	body_parts_covered = FACE|EYES
	armor = list(melee = 19, arrow = 9, gun = 0, energy = 0, bomb = 12, bio = 0, rad = FALSE)

/obj/item/clothing/head/helmet/chitin // name and description fixed & tidied up.
	name = "chitin helmet"
	desc = "A helmet made from insect chitin."
	icon_state = "chitin_helmet"
	item_state = "chitin_helmet"
	worn_state = "chitin_helmet"
	armor = list(melee = 30, arrow = 19, gun = 12, energy = 18, bomb = 18, bio = 19, rad = FALSE)

/obj/item/clothing/suit/armor/chitin
	name = "chitin chestplate"
	desc = "A chitin chestplate, specially crafted from insects."
	icon_state = "chitin_armor"
	item_state = "chitin_armor"
	worn_state = "chitin_armor"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 50, arrow = 15, gun = 5, energy = 15, bomb = 25, bio = 0, rad = FALSE) //weaker than bronze, stronger than bone.
	slowdown = 0.90
	health = 30

/* - 2. Classical Era Tribes & Content (Crabs)*/

/* - 3. Medieval Era Tribes & Content (Orcs)*/
	/* - 3a. Sauron & Orc Cultural Clothes*/

/obj/item/clothing/head/helmet/sauronhelm
	name = "sauron's helmet"
	desc = "The helmet to the armor of sauron"
	icon_state = "sauronhelmet"
	item_state = "sauronhelmet"
	worn_state = "sauronhelmet"
	body_parts_covered = HEAD|FACE|EYES
	armor = list(melee = 80, arrow = 90, gun = 30, energy = 20, bomb = 70, bio = 20, rad = 45)
	value = 70
	slowdown = 1
	health = 90

/obj/item/clothing/suit/armor/sauronarmor
	name = "sauron's armor"
	desc = "The armor of sauron"
	icon_state = "sauronarmor"
	item_state = "sauronarmor"
	worn_state = "sauronarmor"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 95, arrow = 90, gun = 30, energy = 20, bomb = 70, bio = 20, rad = 45)
	value = 70
	slowdown = 1
	health = 90

/obj/item/clothing/suit/armor/darkplate
	name = "plated armor"
	desc = "A cheap dark iron armor."
	icon_state = "ork_plate_elite"
	item_state = "ork_plate_elite"
	worn_state = "ork_plate_elite"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 70, arrow = 90, gun = 10, energy = 15, bomb = 60, bio = 20, rad = 45)
	value = 50
	slowdown = 1.5
	health = 60

/obj/item/clothing/suit/armor/darkplateelite
	name = "plated armor"
	desc = "A cheap dark iron armor."
	icon_state = "ork_plate_commander"
	item_state = "ork_plate_commander"
	worn_state = "ork_plate_commander"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 80, arrow = 90, gun = 10, energy = 15, bomb = 60, bio = 20, rad = 45)
	value = 50
	slowdown = 1.5
	health = 60

/obj/item/clothing/head/helmet/orc_beserker
	name = "orc beserker helm"
	desc = "Orc make good helmet!"
	icon_state = "beserkerhelmet"
	item_state = "beserkerhelmet"
	worn_state = "beserkerhelmet"
	body_parts_covered = HEAD|FACE|EYES
	force = WEAPON_FORCE_PAINFUL
	armor = list(melee = 70, arrow = 80, gun = FALSE, energy = FALSE, bomb = 50, bio = 20, rad = 10)

/obj/item/clothing/head/helmet/eliteorc
	name = "iron helmet"
	desc = "A helmet with front plate, made of dark iron."
	icon_state = "ork_elite_helmet_2"
	item_state = "ork_elite_helmet_2"
	worn_state = "ork_elite_helmet_2"
	body_parts_covered = HEAD|FACE|EYES
	force = WEAPON_FORCE_PAINFUL
	armor = list(melee = 80, arrow = 90, gun = FALSE, energy = FALSE, bomb = 50, bio = 20, rad = 10)

/obj/item/clothing/head/helmet/eliteorc2
	name = "iron helmet"
	desc = "A helmet made of dark iron."
	icon_state = "ork_elite_helmet"
	item_state = "ork_elite_helmet"
	worn_state = "ork_elite_helmet"
	body_parts_covered = HEAD
	force = WEAPON_FORCE_PAINFUL
	armor = list(melee = 70, arrow = 70, gun = FALSE, energy = FALSE, bomb = 50, bio = 20, rad = 10)

/obj/item/clothing/head/helmet/orc_spearman
	name = "orc spearman helm"
	desc = "Orc make good helmet!"
	icon_state = "spearmanhelmet"
	item_state = "spearmanhelmet"
	worn_state = "spearmanhelmet"
	body_parts_covered = HEAD|FACE|EYES
	force = WEAPON_FORCE_PAINFUL
	armor = list(melee = 55, arrow = 45, gun = 10, energy = 15, bomb = 60, bio = 30, rad = FALSE)

/obj/item/clothing/head/helmet/orc_captain
	name = "orc captain helm"
	desc = "Orc make good helmet!"
	icon_state = "captainhelmet"
	item_state = "captainhelmet"
	worn_state = "captainhelmet"
	body_parts_covered = HEAD|FACE|EYES
	force = WEAPON_FORCE_PAINFUL
	armor = list(melee = 55, arrow = 45, gun = 10, energy = 15, bomb = 60, bio = 30, rad = FALSE)

/obj/item/clothing/head/helmet/orc_grunt
	name = "orc grunt helm"
	desc = "Orc make good helmet!"
	icon_state = "grunthelmet"
	item_state = "grunthelmet"
	worn_state = "grunthelmet"
	body_parts_covered = HEAD|FACE
	force = WEAPON_FORCE_PAINFUL
	armor = list(melee = 50, arrow = 40, gun = 5, energy = 15, bomb = 50, bio = 20, rad = FALSE)

/obj/item/clothing/suit/armor/ork_urukhai
	name = "orc urukhai armor"
	desc = "Orc make good armor!"
	icon_state = "urukhai_armor"
	item_state = "urukhai_armor"
	worn_state = "urukhai_armor"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 60, arrow = 40, gun = 8, energy = 15, bomb = 40, bio = 20, rad = 25)
	value = 50
	slowdown = 1.7
	health = 50

/obj/item/clothing/suit/armor/ork_whitehand
	name = "orc whitehand armor"
	desc = "Orc make good armor!"
	icon = 'icons/obj/clothing/suits.dmi'
	icon_state = "whitehand_armor"
	item_state = "whitehand_armor"
	worn_state = "whitehand_armor"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 60, arrow = 40, gun = 8, energy = 15, bomb = 40, bio = 20, rad = 25)
	value = 50
	slowdown = 1.7
	health = 50

/obj/item/clothing/suit/armor/ork_grunt
	name = "orc grunt armor"
	desc = "Orc make good armor!"
	icon = 'icons/obj/clothing/suits.dmi'
	icon_state = "grunt_armor"
	item_state = "grunt_armor"
	worn_state = "grunt_armor"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 50, arrow = 35, gun = 6, energy = 10, bomb = 35, bio = 20, rad = 20)
	value = 50
	slowdown = 1.7
	health = 50

/obj/item/clothing/shoes/orc
	name = "orcish sabatons"
	desc = "A pair of orc plated armored boots."
	icon_state = "ork_warrior"
	item_state = "ork_warrior"
	worn_state = "ork_warrior"
	body_parts_covered = FEET
	force = WEAPON_FORCE_PAINFUL
	armor = list(melee = 75, arrow = 60, gun = 10, energy = 8, bomb = 25, bio = 15, rad = FALSE)
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE
	slowdown = 0.1
	health = 35

/obj/item/clothing/gloves/gauntlets/orc
	name = "orcish gauntlets"
	desc = "A pair of orcish armored gauntlets."
	icon_state = "ork_gauntlet"
	item_state = "ork_gauntlet"
	worn_state = "ork_gauntlet"
	body_parts_covered = HANDS
	force = WEAPON_FORCE_PAINFUL
	armor = list(melee = 75, arrow = 60, gun = 10, energy = 8, bomb = 25, bio = 15, rad = FALSE)
	cold_protection = HANDS
	min_cold_protection_temperature = GLOVES_MIN_COLD_PROTECTION_TEMPERATURE
	slowdown = 0.1
	health = 30

	/* - 3b. Other Orc Clothes & Accessories*/

/obj/item/clothing/mask/bossjaw
	name = "'rite nasty boss jawpiece"
	desc = "A chunk of crude metal crafted into the shape of a orcish jaw, cements status amongst brutes making them appear larger."
	icon_state = "bossjaw"
	item_state = "bossjaw"
	worn_state = "bossjaw"
	body_parts_covered = FACE
	flags = CONDUCT
	flags_inv = 0
	w_class = ITEM_SIZE_SMALL
	armor = list(melee = 15, arrow = 5, gun = FALSE, energy = 15, bomb = 30, bio = 20, rad = FALSE)

/obj/item/clothing/shoes/fur/orc
	name = "orc fur boots"
	desc = "Dense fur boots made from orc skin."
	icon_state = "fur6"
	item_state = "fur6"
	worn_state = "fur6"
	specific = TRUE //uses new() from within apparel_ancient.dm

/obj/item/clothing/suit/storage/coat/fur/orc
	name = "orc fur coat"
	desc = "A thick dark green fur coat, made from disgusting orc pelts."
	icon_state = "fur_jacket6"
	item_state = "fur_jacket6"
	worn_state = "fur_jacket6"
	specific = TRUE
	colorn = 6

/obj/item/clothing/gloves/thick/leather/orc //inherits from gloves/miscellanous.dm
	desc = "These fur gloves are cold and fire-resistant, made from orc skin."
	name = "orc fur gloves"
	icon_state = "orcfur"
	item_state = "orcfur"

	/* - 3c. Orc Weapons*/

/obj/item/weapon/material/sword/urukhaiscimitar
	name = "uruk-hai scimitar"
	desc = "A broad sword with a curved tip."
	icon_state = "urukhaiscimitar"
	item_state = "urukhaiscimitar"
	throw_speed = 2
	throw_range = 2
	force_divisor = 1 // 60 when wielded with hardness 60 (steel)
	thrown_force_divisor = 0.6 // 12 when thrown with weight 20 (steel)
	slot_flags = SLOT_BELT | SLOT_BACK
	block_chance = 40
	cooldownw = 15
	value = 55

/* Other Fantasy Objects*/

/* Other Fantasy Clothing & Armor*/

	/* Lizardperson & lizard-reptile hide objects (not snakes)*/

/obj/item/clothing/head/lizardpelt 	//inherits from (/modules/1713/apparel_ancient.dm)
	name = "lizard pelt headcover"
	desc = "A lizard pelt turned into a headcover."
	icon_state = "lizardpelt"
	item_state = "lizardpelt"
	worn_state = "lizardpelt"
	flags_inv = BLOCKHEADHAIR
	heat_protection = HEAD
	var/colortype = "green"

/obj/item/clothing/under/lizardpants
	name = "shirtless lizard pants"
	desc = "A tight fitting pair of lizard scale pants. When you're this on-point; wearing a shirt would just cramp your style."
	icon_state = "lizard_pants"
	item_state = "lizard_pants"
	worn_state = "lizard_pants"
	body_parts_covered = LOWER_TORSO|LEGS

/obj/item/weapon/storage/backpack/satchel/lizard_satchel 	//inherits from (weapons/storage/backpack.dm)
	name = "lizard scale satchel"
	desc = "A fashionable satchel lined with exotic lizard scales"
	icon_state = "lizard_satchel"
	base_icon = "lizard_satchel"

/obj/item/clothing/shoes/riding1/lizard_cowboy 	//inherits from (/modules/1713/apparel_industrial.dm)
	name = "lizard scale riding boots"
	desc = "lizard scale patterned boots with spurs, perfect for riding in style."
	icon_state = "lizard_cowboy"
	item_state = "lizard_cowboy"
	worn_state = "lizard_cowboy"

/obj/item/clothing/shoes/lizard_ankleboots 	//same as lizard cowboy
	name = "lizard scale ankle boots"
	desc = "Classy lizard scale ankle-length boots, a certain statement for fashion."
	icon_state = "lizard_ankleboots"
	item_state = "lizard_ankleboots"
	worn_state = "lizard_ankleboots"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 50, arrow = 30, gun = FALSE, energy = 20, bomb = 40, bio = 10, rad = 20)
	item_flags = NOSLIP
	siemens_coefficient = 0.6

/obj/item/weapon/storage/belt/lizard_belt 	//inherits from (/items/weapons/storage/belt.dm)
	name = "lizard scale belt"
	desc = "A purely decorative lizard scale thin belt. It has no pockets or attachments for items"
	icon_state = "lizard_belt"
	item_state = "lizard_belt"
	storage_slots = 0
	max_w_class = 1
	max_storage_space = 0

/obj/item/clothing/shoes/lizard_laceup 	//inherits from (/clothing/shoes/miscellaneous.dm)
	name = "lizard scale laceup shoes"
	desc = "The height of luxurious footwear, and they're pre-polished!"
	icon_state = "lizard_laceups"

/obj/item/clothing/suit/storage/coat/ww2/biker/lizard_jacket 	//inherits from (/modules/1713/apparel_worldwars.dm)
	name = "lizard scale jacket"
	desc = "A sleek lizard scale jacket, bold and impression-setting like the people who wear it. `Too cool for S-s-s-school'."
	icon_state = "lizard_jacket"
	item_state = "lizard_jacket"
	worn_state = "lizard_jacket"
	value = 150

/obj/item/clothing/accessory/storage/coinpouch/lizard_wallet 	//inherits from (/modules/1713/apparel_imperial.dm)
	name = "lizard scale wallet"
	desc = "A exotic personal wallet decorated in lizard scale, where you can carry your coins and small objects."
	icon = 'icons/obj/storage.dmi'
	icon_state = "lizard_wallet"

/*Lizard objects -END*/

/obj/item/clothing/head/mystic
	name = "mystic hood"
	desc = "A ominous cream hood, it conceals the face almost fully."
	icon_state = "mystic"
	item_state = "mystic"

/* Wyvern & Dragon Armor & Clothes*/

/* wip - art assets ready, incomplete polished code.

/obj/item/clothing/gloves/wyvern
	name = "wyvern gauntlets"
	desc = "A pair of gauntlets made from the scaly hide of a wyvern. The scales seem to protect the user from the heat."
	icon_state = "wyvern"
	item_state = "wyvern"
	worn_state = "wyvern"
	body_parts_covered = HANDS
	force = WEAPON_FORCE_PAINFUL
	armor = list(melee = 50, arrow = 45, gun = 10, energy = 40, bomb = 50, bio = 15, rad = FALSE)
	heat_protection = HANDS
	slowdown = 0.25
	health = 30

/obj/item/clothing/gloves/wyvern/ice
	name = "ice wyvern gauntlets"
	desc = "A pair of gauntlets made from the scaly hide of a ice wyvern. The scales seem to protect the user from the cold."
	icon_state = "ice_wyvern"
	item_state = "ice_wyvern"
	worn_state = "ice_wyvern"
	body_parts_covered = HANDS
	force = WEAPON_FORCE_PAINFUL
	armor = list(melee = 50, arrow = 45, gun = 10, energy = 40, bomb = 50, bio = 15, rad = FALSE)
	cold_protection = HANDS
	slowdown = 0.25
	health = 30

/obj/item/clothing/head/helmet/wyvern
	name = "wyvern helmet"
	desc = "A scaly helmet in the form of a wailing wyvern. The scales seem to protect the user from the heat."
	icon_state = "wyvern"
	item_state = "wyvern"
	worn_state = "wyvern"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 55, arrow = 45, gun = 10, energy = 15, bomb = 60, bio = 30, rad = FALSE)
	health = 45
	heat_protection = HEAD|FACE|EYES
	slowdown = 0.25

/obj/item/clothing/head/helmet/wyvern/ice
	name = "ice wyvern helmet"
	desc = "A scaly helmet in the form of a wailing ice wyvern. The scales seem to protect the user from the cold."
	icon_state = "ice_wyvern"
	item_state = "ice_wyvern"
	worn_state = "ice_wyvern"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 55, arrow = 45, gun = 10, energy = 40, bomb = 60, bio = 30, rad = FALSE)
	health = 45
	cold_protection = HEAD|FACE|EYES
	slowdown = 0.25

/obj/item/clothing/head/helmet/dragon/green
	name = "wyvern helmet"
	desc = "A scaly helmet in the form of a roaring green dragon. The scales seem to protect the user from the heat."
	icon_state = "green_dragon"
	item_state = "green_dragon"
	worn_state = "green_dragon"
	body_parts_covered = HEAD|FACE
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 60, arrow = 70, gun = 5, energy = 15, bomb = 60, bio = 20, rad = FALSE)
	health = 60
	heat_protection =  HEAD|FACE|EYES
	slowdown = 0.25

/obj/item/clothing/gloves/dragon/green
	name = "green dragon gauntlets"
	desc = "A pair of gauntlets made from the scaly hide of a green dragon."
	icon_state = "green_dragon"
	item_state = "green_dragon"
	worn_state = "green_dragon"
	body_parts_covered = HANDS
	force = WEAPON_FORCE_PAINFUL
	armor = list(melee = 65, arrow = 60, gun = 15, energy = 70, bomb = 70, bio = 30, rad = FALSE)
	heat_protection = HANDS
	slowdown = 0.50
	health = 50

wip pending sprites

/obj/item/clothing/suit/armor/wyvern
	name = "wyvern armor"
	desc = "A set of armor made out of the scaly hide of a wyvern."
	icon_state = "wyvern"
	item_state = "wyvern"
	worn_state = "wyvern"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 60, arrow = 40, gun = 10, energy = 40, bomb = 50, bio = 20, rad = FALSE) //compared agianst a iron chestplate
	slowdown = 0.8
	health = 50
	heat_protection = UPPER_TORSO|LOWER_TORSO

/obj/item/clothing/suit/armor/wyvern/ice
	name = "wyvern armor"
	desc = "A set of armor made out of the scaly hide of a wyvern."
	icon_state = "wyvern"
	item_state = "wyvern"
	worn_state = "wyvern"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 60, arrow = 40, gun = 10, energy = 40, bomb = 50, bio = 20, rad = FALSE) //compared agianst a iron chestplate
	slowdown = 0.8
	health = 50
	cold_protection = UPPER_TORSO|LOWER_TORSO

/obj/item/clothing/suit/armor/dragon/green
	name = "green dragon armor"
	desc = "A set of armor made out of the scaly hide of a green dragon. Its thick plates cover the entire body suprisingly without being rigid and cumbersome."
	icon_state = "green_dragon"
	item_state = "green_dragon"
	worn_state = "green_dragon"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 85, arrow = 90, gun = 10, energy = 15, bomb = 60, bio = 20, rad = FALSE) // plated armor for comparison
	value = 500
	slowdown = 1.0
	health = 60
	heat_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS*/

/* Grimdark Future Fantasy Clothes */

/obj/item/clothing/suit/storage/jacket/imperial/commissar
	name = "commissar jacket"
	desc = "A red jacket belonging to overzealous leaders of large squadrons of infantry. The authority this grants means rejecting orders will by no means be acceptable..."
	icon_state = "commissar"
	icon_state = "commissar"
	icon_state = "commissar"

/obj/item/clothing/suit/armor/imperial/arbites
	name = "arbites armor"
	desc = "A thick, authoritive red armor with reinforced steel leggings and shoulder plates, covering most of the body. Futile attempts to assault arbite enforcers of the law find that rebellion is fruitless."
	icon_state = "arbit"
	item_state = "arbit"
	worn_state = "arbit"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 85, arrow = 90, gun = 35, energy = 65, bomb = 70, bio = 20, rad = FALSE) //better more futuristic stats than platemail.
	value = 100
	slowdown = 1.2 //less slowdown than platemail
	health = 60

/obj/item/clothing/suit/storage/jacket/inquisition
	name = "inquisitorial jacket"
	desc = "A black jacket with red arm stripes belonging to expert investigators of intrigue and heresy. By all means nessecary..."
	icon_state = "commissar"
	icon_state = "commissar"
	icon_state = "commissar"

/obj/item/clothing/suit/storage/jacket/inquisition/alt
	name = "inquisitorial light jacket"
	desc = "A black light jacket belonging to expert investigators of intrigue and heresy. By all means nessecary..."
	icon_state = "inquistor_alt"
	icon_state = "inquistor_alt"
	icon_state = "inquistor_alt"

/obj/item/clothing/suit/storage/jacket/inquisition/alt/hood
	name = "inquisitorial jacket"
	icon_state = "inqcape_alt"
	icon_state = "inqcape_alt"
	icon_state = "inqcape_alt"
	flags_inv = BLOCKHAIR|HIDEFACE

/obj/item/clothing/suit/storage/jacket/elf/warlock
	name = "elven warlock robe"
	desc = "A long robe worn by mystic leaders of the elven race."
	icon_state = "elf_warlock"
	icon_state = "elf_warlock"
	icon_state = "elf_warlock"

/obj/item/clothing/suit/storage/jacket/elf/harlequin
	name = "elven harlequin jacket"
	desc = "A flamboyant jacket worn by roaming troupes of deadly elven assassins with theatrical motifs."
	icon_state = "elf_harlequin"
	icon_state = "elf_harlequin"
	icon_state = "elf_harlequin"

/obj/item/clothing/mask/elf/solitaire
	name = "solitaire masque"
	desc = "A hauntingly chiselled and androgynous mask. Often worn by elite elven assassins who only work alone."
	icon_state = "solitaire"
	item_state = "solitaire"
	flags_inv = HIDEFACE
	body_parts_covered = FACE
	w_class = ITEM_SIZE_TINY
	armor = list(melee = 20, arrow = 15, gun = 5, energy = 15, bomb = 55, bio = 20, rad = FALSE) //equal to japanese face mask.

	/* - 5b. Fantasy Materials*/

// etc magic crystals, special monster parts