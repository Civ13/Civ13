GLOBAL_LIST_INIT(forged_recipes,\
		list(\
			"/obj/item/heatable/ingot/wroughtiron" = list(\
				"Resources" = list("icon" = 'icons/obj/materials.dmi', "icon_state" = "sheet-iron_4",\
					"Iron Plates (x3)"		= list("type" = /obj/item/stack/material/iron, "icon" = 'icons/obj/materials.dmi', "icon_state" = "sheet-iron_2", "cost" = 1, "count" = INGOT_VALUE*1, "first_age" = 0, "final_age" = 99),\
					"Iron Plates (x6)"		= list("type" = /obj/item/stack/material/iron, "icon" = 'icons/obj/materials.dmi', "icon_state" = "sheet-iron_3", "cost" = 2, "count" = INGOT_VALUE*2, "first_age" = 0, "final_age" = 99),\
					"Iron Plates (x12)"		= list("type" = /obj/item/stack/material/iron, "icon" = 'icons/obj/materials.dmi', "icon_state" = "sheet-iron_4", "cost" = 4, "count" = INGOT_VALUE*4, "first_age" = 0, "final_age" = 99),\
				),\

				"Tools" = list("icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "wiron-hammer-handled",
					"Hammer"				= list("type" = /obj/item/heatable/forged/hammer, "icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "wiron-hammer-handled", "cost" = 1, "count" = 1, "first_age" = 0, "final_age" = 99),\
					"Hatchet"				= list("type" = /obj/item/heatable/forged/hatchet, "icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "wiron-hatchet-handled", "cost" = 1, "count" = 1, "first_age" = 0, "final_age" = 99),\
					"Pickaxe"				= list("type" = /obj/item/heatable/forged/pickaxe, "icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "wiron-pickaxe-handled", "cost" = 2, "count" = 1, "first_age" = 0, "final_age" = 99),\
					"Knife"					= list("type" = /obj/item/weapon/material/kitchen/utensil/knife/iron, "icon" = 'icons/obj/kitchen.dmi', "icon_state" = "knife", "cost" = 1, "count" = 1, "first_age" = 0, "final_age" = 99),\
					"Anvil"					= list("type" = /obj/structure/anvil, "icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "wiron-anvil", "cost" = 6, "count" = 1, "first_age" = 0, "final_age" = 99),\
					"Shovel"				= list("type" = /obj/item/heatable/forged/shovel, "icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "wiron-shovel-handled", "cost" = 1, "count" = 1, "first_age" = 0, "final_age" = 99),\
					"Tongs"					= list("type" = /obj/item/heatable/forged/tongs, "icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "wiron-tongs", "cost" = 1, "count" = 1, "first_age" = 0, "final_age" = 99),\
				),\

				"Weaponry" = list("icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "wiron-longsword-handled",\
					"Arrowhead"				= list("type" = /obj/item/stack/arrowhead/iron, "icon" = 'icons/obj/items.dmi', "icon_state" = "iron_arrowhead", "cost" = 3, "count" = 1, "first_age" = 0, "final_age" = 99),\

					"Longsword"				= list("type" = /obj/item/heatable/forged/weapon/longsword, "icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "wiron-longsword-handled", "cost" = 3, "count" = 1, "first_age" = 2, "final_age" = 2),\
					"Arming sword"			= list("type" = /obj/item/heatable/forged/weapon, "icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "wiron-arming_sword-handled", "cost" = 2, "count" = 1, "first_age" = 2, "final_age" = 2),\
					"Halberd"				= list("type" = /obj/item/heatable/forged/weapon/halberd, "icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "wiron-halberd-handled", "cost" = 2, "count" = 1, "first_age" = 2, "final_age" = 2),\
					"Pike"					= list("type" = /obj/item/heatable/forged/weapon/pike, "icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "wiron-pike-handled", "cost" = 2, "count" = 1, "first_age" = 2, "final_age" = 2),\
					"Spear"					= list("type" = /obj/item/heatable/forged/weapon/spear, "icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "wiron-spear-handled", "cost" = 1, "count" = 1, "first_age" = 2, "final_age" = 2),\
					"Throwing axe"			= list("type" = /obj/item/heatable/forged/weapon/throwing_axe, "icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "wiron-throwing_axe-handled", "cost" = 1, "count" = 1, "first_age" = 2, "final_age" = 2),\
					"Battle axe"			= list("type" = /obj/item/heatable/forged/weapon/battle_axe, "icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "wiron-battle_axe-handled", "cost" = 3, "count" = 1, "first_age" = 2, "final_age" = 2),\

					"Scutum Shield"			= list("type" = /obj/item/weapon/shield/scutum, "icon" = 'icons/obj/weapons.dmi', "icon_state" = "scutum", "cost" = 2, "count" = 1, "first_age" = 1, "final_age" = 1),\
					"Roman Shield"			= list("type" = /obj/item/weapon/shield/roman, "icon" = 'icons/obj/weapons.dmi', "icon_state" = "roman_shield", "cost" = 2, "count" = 1, "first_age" = 1, "final_age" = 1),\
					"Blue Roman Shield"		= list("type" = /obj/item/weapon/shield/roman/blue, "icon" = 'icons/obj/weapons.dmi', "icon_state" = "blue_roman_shield", "cost" = 2, "count" = 1, "first_age" = 1, "final_age" = 1),\
					"Praetorian Shield"		= list("type" = /obj/item/weapon/shield/roman/praetorian, "icon" = 'icons/obj/weapons.dmi', "icon_state" = "prae_roman_shield", "cost" = 2, "count" = 1, "first_age" = 1, "final_age" = 2),\
					"Semi Oval Shield"		= list("type" = /obj/item/weapon/shield/iron/nomads/semioval, "icon" = 'icons/obj/weapons.dmi', "icon_state" = "semioval_shield", "cost" = 2, "count" = 1, "first_age" = 2, "final_age" = 2),\
					"Semi Oval Templar Shield" = list("type" = /obj/item/weapon/shield/iron/nomads/semioval/templar, "icon" = 'icons/obj/weapons.dmi', "icon_state" = "semioval_shield_templar", "cost" = 2, "count" = 1, "first_age" = 2, "final_age" = 2),\
					"Iron Shield"			= list("type" = /obj/item/weapon/shield/iron, "icon" = 'icons/obj/weapons.dmi', "icon_state" = "iron_shield", "cost" = 2, "count" = 1, "first_age" = 1, "final_age" = 2),\

					"Crude Musket"			= list("type" = /obj/item/weapon/gun/projectile/flintlock/crude, "icon" = 'icons/obj/guns/ancient.dmi', "icon_state" = "musketoon", "cost" = 2, "count" = 1, "first_age" = 3, "final_age" = 4),\
					"Flintlock Musket"		= list("type" = /obj/item/weapon/gun/projectile/flintlock/musket, "icon" = 'icons/obj/guns/ancient.dmi', "icon_state" = "musket", "cost" = 4, "count" = 1, "first_age" = 3, "final_age" = 4),\
					"Flintlock Musketoon"	= list("type" = /obj/item/weapon/gun/projectile/flintlock/musketoon, "icon" = 'icons/obj/guns/ancient.dmi', "icon_state" = "compactmusket", "cost" = 4, "count" = 1, "first_age" = 3, "final_age" = 4),\
					"Flintlock Blunderbuss"	= list("type" = /obj/item/weapon/gun/projectile/flintlock/blunderbuss, "icon" = 'icons/obj/guns/ancient.dmi', "icon_state" = "blunderbuss", "cost" = 4, "count" = 1, "first_age" = 3, "final_age" = 4),\
					"Flintlock Pistol"		= list("type" = /obj/item/weapon/gun/projectile/flintlock/pistol, "icon" = 'icons/obj/guns/ancient.dmi', "icon_state" = "flintpistol", "cost" = 3, "count" = 1, "first_age" = 3, "final_age" = 4),\

					"Derringer M95"			= list("type" = /obj/item/weapon/gun/projectile/revolver/derringer, "icon" = 'icons/obj/guns/pistols.dmi', "icon_state" = "derringer", "cost" = 2, "count" = 1, "first_age" = 4, "final_age" = 5),\
					"Colt Peacemaker"		= list("type" = /obj/item/weapon/gun/projectile/revolver/peacemaker, "icon" = 'icons/obj/guns/pistols.dmi', "icon_state" = "coltsaa", "cost" = 2, "count" = 1, "first_age" = 4, "final_age" = 5),\
					"Martini-Henry"			= list("type" = /obj/item/weapon/gun/projectile/boltaction/singleshot/martini_henry, "icon" = 'icons/obj/guns/rifles.dmi', "icon_state" = "martini_henry", "cost" = 4, "count" = 1, "first_age" = 4, "final_age" = 5),\
					"Wichester Repeater"	= list("type" = /obj/item/weapon/gun/projectile/leveraction/winchesterm1873, "icon" = 'icons/obj/guns/rifles.dmi', "icon_state" = "winchester1873", "cost" = 4, "count" = 1, "first_age" = 4, "final_age" = 5),\
					"Evans repeater"		= list("type" = /obj/item/weapon/gun/projectile/leveraction/evansrepeater, "icon" = 'icons/obj/guns/rifles.dmi', "icon_state" = "evans_repeating_rifle", "cost" = 4, "count" = 1, "first_age" = 4, "final_age" = 5),\
					"Henry Repeater"		= list("type" = /obj/item/weapon/gun/projectile/leveraction/henryrepeater, "icon" = 'icons/obj/guns/rifles.dmi', "icon_state" = "henry_rifle", "cost" = 4, "count" = 1, "first_age" = 4, "final_age" = 5),\
					"Sharps Rifle"			= list("type" = /obj/item/weapon/gun/projectile/boltaction/singleshot, "icon" = 'icons/obj/guns/rifles.dmi', "icon_state" = "sharps", "cost" = 4, "count" = 1, "first_age" = 4, "final_age" = 5),\
					"coach gun"				= list("type" = /obj/item/weapon/gun/projectile/shotgun/coachgun, "icon" = 'icons/obj/guns/rifles.dmi', "icon_state" = "doublebarreled", "cost" = 3, "count" = 1, "first_age" = 4, "final_age" = 6),\
					"Gewehr 71"				= list("type" = /obj/item/weapon/gun/projectile/boltaction/gewehr71, "icon" = 'icons/obj/guns/rifles.dmi', "icon_state" = "gewehr71", "cost" = 4, "count" = 1, "first_age" = 4, "final_age" = 6),\

					"RPG-7"					= list("type" = /obj/item/weapon/gun/launcher/rocket/rpg7/makeshift, "icon" = 'icons/obj/guns/gun.dmi', "icon_state" = "rpg7_empty", "cost" = 5, "count" = 1, "first_age" = 7, "final_age" = 8),\
				),\

				"Armor" = list("icon" = 'icons/obj/clothing/suits.dmi', "icon_state" = "knight_templar",\
					"Early Chainmail"		= list("type" = /obj/item/clothing/suit/armor/ancient/chainmail, "icon" = 'icons/obj/clothing/suits.dmi', "icon_state" = "early_chainmail", "cost" = 1, "count" = 1, "first_age" = 1, "final_age" = 1),\
					"Segmented Armor"		= list("type" = /obj/item/clothing/suit/armor/ancient/scale, "icon" = 'icons/obj/clothing/suits.dmi', "icon_state" = "scale_armor", "cost" = 3, "count" = 1, "first_age" = 1, "final_age" = 1),\

					"Templar Armor"			= list("type" = /obj/item/clothing/suit/armor/medieval/templar, "icon" = 'icons/obj/clothing/suits.dmi', "icon_state" = "knight_templar", "cost" = 3, "count" = 1, "first_age" = 2, "final_age" = 2),\
					"Plated Armor"			= list("type" = /obj/item/clothing/suit/armor/medieval, "icon" = 'icons/obj/clothing/suits.dmi', "icon_state" = "knight_simple", "cost" = 3, "count" = 1, "first_age" = 2, "final_age" = 2),\
					"Hauberk"				= list("type" = /obj/item/clothing/suit/armor/medieval/hauberk, "icon" = 'icons/obj/clothing/suits.dmi', "icon_state" = "hauberk", "cost" = 2, "count" = 1, "first_age" = 2, "final_age" = 2),\
					"Chainmail"				= list("type" = /obj/item/clothing/suit/armor/medieval/chainmail, "icon" = 'icons/obj/clothing/suits.dmi', "icon_state" = "chainmail", "cost" = 2, "count" = 1, "first_age" = 2, "final_age" = 2),\
					"Gauntlets"				= list("type" = /obj/item/clothing/gloves/gauntlets, "icon" = 'icons/obj/clothing/gloves.dmi', "icon_state" = "gauntlet", "cost" = 1, "count" = 1, "first_age" = 2, "final_age" = 2),\
					"Plated Boots"			= list("type" = /obj/item/clothing/shoes/medieval/knight, "icon" = 'icons/obj/clothing/shoes.dmi', "icon_state" = "knight", "cost" = 1, "count" = 1, "first_age" = 2, "final_age" = 2),\
					"Emirate Armor"			= list("type" = /obj/item/clothing/suit/armor/medieval/emirate, "icon" = 'icons/obj/clothing/suits.dmi', "icon_state" = "emir_armor", "cost" = 3, "count" = 1, "first_age" = 2, "final_age" = 2),\
				),\

				"Helmets" = list("icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "crusader",\
					"Horned Helmet"			= list("type" = /obj/item/clothing/head/helmet/horned, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "barbarian", "cost" = 1, "count" = 1, "first_age" = 1, "final_age" = 1),\
					"Winged Helmet"			= list("type" = /obj/item/clothing/head/helmet/asterix, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "asterix", "cost" = 1, "count" = 1, "first_age" = 1, "final_age" = 1),\
					"Gaelic Helmet"			= list("type" = /obj/item/clothing/head/helmet/asterix/conspicious, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "vitalstatistix", "cost" = 1, "count" = 1, "first_age" = 1, "final_age" = 2),\

					"Roman Helmet"			= list("type" = /obj/item/clothing/head/helmet/roman/nomads, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "roman", "cost" = 1, "count" = 1, "first_age" = 2, "final_age" = 2),\
					"Centurion Helmet"		= list("type" = /obj/item/clothing/head/helmet/roman_centurion/nomads, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "roman_c", "cost" = 2, "count" = 1, "first_age" = 2, "final_age" = 2),\
					"Decurion Helmet"		= list("type" = /obj/item/clothing/head/helmet/roman_decurion/nomads, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "roman_d", "cost" = 2, "count" = 1, "first_age" = 2, "final_age" = 2),\
					"Sol Invictus Helmet"	= list("type" = /obj/item/clothing/head/helmet/solinvictus, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "sol_invictus", "cost" = 3, "count" = 1, "first_age" = 2, "final_age" = 2),\

					"Kettle Helmet"			= list("type" = /obj/item/clothing/head/helmet/medieval/helmet2, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "medieval_helmet2", "cost" = 1, "count" = 1, "first_age" = 2, "final_age" = 2),\
					"Coif"					= list("type" = /obj/item/clothing/head/helmet/medieval/coif, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "coif", "cost" = 1, "count" = 1, "first_age" = 2, "final_age" = 2),\
					"Coif & Helmet"			= list("type" = /obj/item/clothing/head/helmet/medieval/coif_helmet, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "coif_helmet", "cost" = 2, "count" = 1, "first_age" = 2, "final_age" = 2),\
					"Conical Helmet"		= list("type" = /obj/item/clothing/head/helmet/medieval/helmet1, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "medieval_helmet1", "cost" = 2, "count" = 1, "first_age" = 2, "final_age" = 2),\
					"Crusader Helmet"		= list("type" = /obj/item/clothing/head/helmet/medieval/crusader, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "crusader", "cost" = 3, "count" = 1, "first_age" = 2, "final_age" = 2),\
					"Knight Helmet"			= list("type" = /obj/item/clothing/head/helmet/medieval, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "knight_simple", "cost" = 3, "count" = 1, "first_age" = 2, "final_age" = 2),\
					"German Sallet Helmet"	= list("type" = /obj/item/clothing/head/helmet/sallet/german, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "german_sallet", "cost" = 2, "count" = 1, "first_age" = 2, "final_age" = 2),\
					"Viking Helmet"			= list("type" = /obj/item/clothing/head/helmet/medieval/viking, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "new_viking", "cost" = 2, "count" = 1, "first_age" = 2, "final_age" = 2),\
					"Valkyrie Helmet"		= list("type" = /obj/item/clothing/head/helmet/medieval/viking/valkyrie, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "valkyrie", "cost" = 2, "count" = 1, "first_age" = 2, "final_age" = 2),\
					"Varangian Helmet"		= list("type" = /obj/item/clothing/head/helmet/medieval/viking/varangian, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "varangian_guard", "cost" = 4, "count" = 1, "first_age" = 2, "final_age" = 2),\
					"Arabic Long helmet"	= list("type" = /obj/item/clothing/head/helmet/medieval/nomads/longarab, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "arabw_helmet", "cost" = 2, "count" = 1, "first_age" = 2, "final_age" = 2),\

					"Morion Helmet"			= list("type" = /obj/item/clothing/head/helmet/imperial/morion, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "morion_helmet", "cost" = 1, "count" = 1, "first_age" = 3, "final_age" = 3),\
				),\
			),\

			"/obj/item/heatable/ingot/copper" = list(\
				"Copper Plates (x3)"	= list("type" = /obj/item/stack/material/copper, "icon" = 'icons/obj/materials.dmi', "icon_state" = "sheet-copper_2", "cost" = 1, "count" = INGOT_VALUE*1, "first_age" = 0, "final_age" = 99),\
				"Copper Plates (x6)"	= list("type" = /obj/item/stack/material/copper, "icon" = 'icons/obj/materials.dmi', "icon_state" = "sheet-copper_3", "cost" = 2, "count" = INGOT_VALUE*2, "first_age" = 0, "final_age" = 99),\
				"Copper Plates (x12)"	= list("type" = /obj/item/stack/material/copper, "icon" = 'icons/obj/materials.dmi', "icon_state" = "sheet-copper_4", "cost" = 4, "count" = INGOT_VALUE*4, "first_age" = 0, "final_age" = 99),\
			),\

			"/obj/item/heatable/ingot/bronze" = list(\
				"Resources" = list("icon" = 'icons/obj/materials.dmi', "icon_state" = "sheet-bronze_4",\
					"Bronze Plates (x3)"	= list("type" = /obj/item/stack/material/bronze, "icon" = 'icons/obj/materials.dmi', "icon_state" = "sheet-bronze_2", "cost" = 1, "count" = INGOT_VALUE*1, "first_age" = 0, "final_age" = 99),\
					"Bronze Plates (x6)"	= list("type" = /obj/item/stack/material/bronze, "icon" = 'icons/obj/materials.dmi', "icon_state" = "sheet-bronze_3", "cost" = 2, "count" = INGOT_VALUE*2, "first_age" = 0, "final_age" = 99),\
					"Bronze Plates (x12)"	= list("type" = /obj/item/stack/material/bronze, "icon" = 'icons/obj/materials.dmi', "icon_state" = "sheet-bronze_4", "cost" = 4, "count" = INGOT_VALUE*4, "first_age" = 0, "final_age" = 99),\
				),\

				"Armor" = list("icon" = 'icons/obj/clothing/suits.dmi', "icon_state" = "scaled_armor",\
					"Egyptian Lammellar"	= list("type" = /obj/item/clothing/suit/armor/ancient/bronze_lamellar, "icon" = 'icons/obj/clothing/suits.dmi', "icon_state" = "egyptian_lamellar", "cost" = 3, "count" = 1, "first_age" = 1, "final_age" = 1),\
					"Chinese Lammellar"		= list("type" = /obj/item/clothing/suit/armor/ancient/bronze_lamellar/chinese, "icon" = 'icons/obj/clothing/suits.dmi', "icon_state" = "chinese_lamellar", "cost" = 3, "count" = 1, "first_age" = 1, "final_age" = 1),\
					"Scaled Armor"			= list("type" = /obj/item/clothing/suit/armor/ancient/scaled, "icon" = 'icons/obj/clothing/suits.dmi', "icon_state" = "scaled_armor", "cost" = 3, "count" = 1, "first_age" = 1, "final_age" = 1),\
				),\

				"Helmets" = list("icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "athenian",\
					"Phrigian Helmet"		= list("type" = /obj/item/clothing/head/helmet/phrigian, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "phrigian_helmet", "cost" = 2, "count" = 1, "first_age" = 1, "final_age" = 1),\
					"Gladiator Helmet"		= list("type" = /obj/item/clothing/head/helmet/gladiator/nomads, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "gladiator", "cost" = 2, "count" = 1, "first_age" = 1, "final_age" = 1),\
					"Chinese warrior Helmet"= list("type" = /obj/item/clothing/head/helmet/chinese_warrior, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "bronze_chinese", "cost" = 2, "count" = 1, "first_age" = 1, "final_age" = 1),\
					"Egyptian Headdress"	= list("type" = /obj/item/clothing/head/helmet/egyptian/nomads, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "egyptian_bronze_headdress", "cost" = 2, "count" = 1, "first_age" = 1, "final_age" = 1),\
					"Greek Helmet"			= list("type" = /obj/item/clothing/head/helmet/greek/nomads, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "new_greek", "cost" = 2, "count" = 1, "first_age" = 1, "final_age" = 1),\
					"Diomerites Helmet"		= list("type" = /obj/item/clothing/head/helmet/greek_sl/nomads, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "athenian", "cost" = 2, "count" = 1, "first_age" = 1, "final_age" = 1),\
					"Lochagos Helmet"		= list("type" = /obj/item/clothing/head/helmet/greek_commander/nomads, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "spartan", "cost" = 2, "count" = 1, "first_age" = 1, "final_age" = 1),\
					"Anax Helmet"			= list("type" = /obj/item/clothing/head/helmet/anax, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "aries", "cost" = 2, "count" = 1, "first_age" = 1, "final_age" = 1),\

					"Dragoon Helmet"		= list("type" = /obj/item/clothing/head/helmet/napoleonic/dragoon, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "dragoon", "cost" = 1, "count" = 1, "first_age" = 3, "final_age" = 3),\
				),\

				"Weaponry" = list("icon" = 'icons/obj/weapons.dmi', "icon_state" = "athenian_shield",\
					"Arrowhead"				= list("type" = /obj/item/stack/arrowhead/bronze, "icon" = 'icons/obj/items.dmi', "icon_state" = "iron_arrowhead", "cost" = 3, "count" = 1, "first_age" = 0, "final_age" = 99),\

					"Gladius"				= list("type" = /obj/item/weapon/material/sword/gladius/bronze, "icon" = 'icons/obj/weapons.dmi', "icon_state" = "gladius", "cost" = 2, "count" = 1, "first_age" = 1, "final_age" = 1),\
					"Khopesh"				= list("type" = /obj/item/weapon/material/sword/khopesh/bronze, "icon" = 'icons/obj/weapons.dmi', "icon_state" = "khopesh", "cost" = 2, "count" = 1, "first_age" = 1, "final_age" = 1),\
					"Xiphos"				= list("type" = /obj/item/weapon/material/sword/xiphos/bronze, "icon" = 'icons/obj/weapons.dmi', "icon_state" = "xiphos", "cost" = 2, "count" = 1, "first_age" = 1, "final_age" = 1),\

					"Athenian Aspis Shield"	= list("type" = /obj/item/weapon/shield/nomads/aspis, "icon" = 'icons/obj/weapons.dmi', "icon_state" = "athenian_shield", "cost" = 2, "count" = 1, "first_age" = 1, "final_age" = 1),\
					"Spartan Aspis Shield"	= list("type" = /obj/item/weapon/shield/nomads/spartan, "icon" = 'icons/obj/weapons.dmi', "icon_state" = "spartan_shield", "cost" = 2, "count" = 1, "first_age" = 1, "final_age" = 1),\
					"Pegasus Aspis Shield"	= list("type" = /obj/item/weapon/shield/nomads/aspis/pegasus, "icon" = 'icons/obj/weapons.dmi', "icon_state" = "pegasus_shield", "cost" = 2, "count" = 1, "first_age" = 1, "final_age" = 1),\
					"Owl Aspis Shield"		= list("type" = /obj/item/weapon/shield/nomads/aspis/owl, "icon" = 'icons/obj/weapons.dmi', "icon_state" = "owl_shield", "cost" = 2, "count" = 1, "first_age" = 1, "final_age" = 1),\
					"Egyptian Shield"		= list("type" = /obj/item/weapon/shield/egyptian, "icon" = 'icons/obj/weapons.dmi', "icon_state" = "egyptian_shield", "cost" = 2, "count" = 1, "first_age" = 1, "final_age" = 1),\
					"Bronze Shield"			= list("type" = /obj/item/weapon/shield/egyptian, "icon" = 'icons/obj/weapons.dmi', "icon_state" = "bronze_shield", "cost" = 2, "count" = 1, "first_age" = 1, "final_age" = 2),\
				),\
			),\

			"/obj/item/heatable/ingot/blistersteel" = list(\
				"Steel Ingot"	= list("type" = "/obj/item/heatable/ingot/steel", "icon" = 'icons/obj/resources.dmi', "icon_state" = "steelingot-1", "cost" = 1, "count" = 1, "first_age" = 0, "final_age" = 99),\
			),\

			"/obj/item/heatable/ingot/steel" = list(\
				"Resources" = list("icon" = 'icons/obj/materials.dmi', "icon_state" = "sheet-metal_4",\
					"Steel Plates (x3)"		= list("type" = /obj/item/stack/material/steel, "icon" = 'icons/obj/materials.dmi', "icon_state" = "sheet-metal_2", "cost" = 1, "count" = INGOT_VALUE*1, "first_age" = 0, "final_age" = 99),\
					"Steel Plates (x6)"		= list("type" = /obj/item/stack/material/steel, "icon" = 'icons/obj/materials.dmi', "icon_state" = "sheet-metal_3", "cost" = 2, "count" = INGOT_VALUE*2, "first_age" = 0, "final_age" = 99),\
					"Steel Plates (x12)"	= list("type" = /obj/item/stack/material/steel, "icon" = 'icons/obj/materials.dmi', "icon_state" = "sheet-metal_4", "cost" = 4, "count" = INGOT_VALUE*4, "first_age" = 0, "final_age" = 99),\
				),\

				"Tools" = list("icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "wiron-hammer-handled",
					"Hammer"				= list("type" = /obj/item/heatable/forged/hammer, "icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "steel-hammer-handled", "cost" = 1, "count" = 1, "first_age" = 0, "final_age" = 99),\
					"Hatchet"				= list("type" = /obj/item/heatable/forged/hatchet, "icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "steel-hatchet-handled", "cost" = 1, "count" = 1, "first_age" = 0, "final_age" = 99),\
					"Pickaxe"				= list("type" = /obj/item/heatable/forged/pickaxe, "icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "steel-pickaxe-handled", "cost" = 2, "count" = 1, "first_age" = 0, "final_age" = 99),\
					"Knife"					= list("type" = /obj/item/weapon/material/kitchen/utensil/knife/steel, "icon" = 'icons/obj/kitchen.dmi', "icon_state" = "knife", "cost" = 1, "count" = 1, "first_age" = 0, "final_age" = 99),\
					"Anvil"					= list("type" = /obj/structure/anvil, "icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "steel-anvil", "cost" = 6, "count" = 1, "first_age" = 0, "final_age" = 99),\
					"Shovel"				= list("type" = /obj/item/heatable/forged/shovel, "icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "steel-shovel-handled", "cost" = 1, "count" = 1, "first_age" = 0, "final_age" = 99),\
					"Tongs"					= list("type" = /obj/item/heatable/forged/tongs, "icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "steel-tongs", "cost" = 1, "count" = 1, "first_age" = 0, "final_age" = 99),\
				),\

				"Weaponry" = list("icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "steel-longsword-handled",\
					"Arrowhead"				= list("type" = /obj/item/stack/arrowhead/steel, "icon" = 'icons/obj/items.dmi', "icon_state" = "iron_arrowhead", "cost" = 3, "count" = 1, "first_age" = 0, "final_age" = 99),\

					"Longsword"				= list("type" = /obj/item/heatable/forged/weapon/longsword, "icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "steel-longsword-handled", "cost" = 3, "count" = 1, "first_age" = 2, "final_age" = 2),\
					"Arming sword"			= list("type" = /obj/item/heatable/forged/weapon, "icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "steel-arming_sword-handled", "cost" = 2, "count" = 1, "first_age" = 2, "final_age" = 2),\
					"Halberd"				= list("type" = /obj/item/heatable/forged/weapon/halberd, "icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "steel-halberd-handled", "cost" = 2, "count" = 1, "first_age" = 2, "final_age" = 2),\
					"Pike"					= list("type" = /obj/item/heatable/forged/weapon/pike, "icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "steel-pike-handled", "cost" = 2, "count" = 1, "first_age" = 2, "final_age" = 2),\
					"Spear"					= list("type" = /obj/item/heatable/forged/weapon/spear, "icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "steel-spear-handled", "cost" = 1, "count" = 1, "first_age" = 2, "final_age" = 2),\
					"Throwing axe"			= list("type" = /obj/item/heatable/forged/weapon/throwing_axe, "icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "steel-throwing_axe-handled", "cost" = 1, "count" = 1, "first_age" = 2, "final_age" = 2),\
					"Battle axe"			= list("type" = /obj/item/heatable/forged/weapon/battle_axe, "icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "steel-battle_axe-handled", "cost" = 3, "count" = 1, "first_age" = 2, "final_age" = 2),\

					"Steel Shield"			= list("type" = /obj/item/weapon/shield/steel, "icon" = 'icons/obj/weapons.dmi', "icon_state" = "steel_shield", "cost" = 2, "count" = 1, "first_age" = 2, "final_age" = 2),\
				),\

				"Armor" = list("icon" = 'icons/obj/clothing/suits.dmi', "icon_state" = "samurai_warrior3",\
					"Samurai Armor"			= list("type" = /obj/item/clothing/suit/armor/samurai, "icon" = 'icons/obj/clothing/suits.dmi', "icon_state" = "samurai_warrior3", "cost" = 2, "count" = 1, "first_age" = 2, "final_age" = 3),\
					"Samurai Lord Armor"	= list("type" = /obj/item/clothing/suit/armor/samurai/lord, "icon" = 'icons/obj/clothing/suits.dmi', "icon_state" = "samurai_lord3", "cost" = 3, "count" = 1, "first_age" = 2, "final_age" = 3),\
					"Red Samurai Armor"		= list("type" = /obj/item/clothing/suit/armor/samurai/red, "icon" = 'icons/obj/clothing/suits.dmi', "icon_state" = "samurai_warrior1", "cost" = 2, "count" = 1, "first_age" = 2, "final_age" = 3),\
					"Red Samurai Lord Armor"= list("type" = /obj/item/clothing/suit/armor/samurai/lord/red, "icon" = 'icons/obj/clothing/suits.dmi', "icon_state" = "samurai_lord1", "cost" = 3, "count" = 1, "first_age" = 2, "final_age" = 3),\
					"Blue Samurai Armor"	= list("type" = /obj/item/clothing/suit/armor/samurai/blue, "icon" = 'icons/obj/clothing/suits.dmi', "icon_state" = "samurai_warrior2", "cost" = 2, "count" = 1, "first_age" = 2, "final_age" = 3),\
					"Blue Samurai Lord Armor" = list("type" = /obj/item/clothing/suit/armor/samurai/lord/blue, "icon" = 'icons/obj/clothing/suits.dmi', "icon_state" = "samurai_lord2", "cost" = 3, "count" = 1, "first_age" = 2, "final_age" = 3),\
					"Black Samurai Armor"	= list("type" = /obj/item/clothing/suit/armor/samurai/black, "icon" = 'icons/obj/clothing/suits.dmi', "icon_state" = "samurai_warrior4", "cost" = 2, "count" = 1, "first_age" = 2, "final_age" = 3),\
					"Black Samurai Lord Armor" = list("type" = /obj/item/clothing/suit/armor/samurai/lord/black, "icon" = 'icons/obj/clothing/suits.dmi', "icon_state" = "samurai_lord4", "cost" = 3, "count" = 1, "first_age" = 2, "final_age" = 3),\
				),\

				"Helmets" = list("icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "samurai_warrior3",\
					"Samurai Helmet"		= list("type" = /obj/item/clothing/head/helmet/samurai, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "samurai_warrior3", "cost" = 1, "count" = 1, "first_age" = 2, "final_age" = 3),\
					"Samurai Lord Helmet"	= list("type" = /obj/item/clothing/head/helmet/samurai/lord/brown, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "samurai_lord3", "cost" = 2, "count" = 1, "first_age" = 2, "final_age" = 3),\
					"Samurai Mask"			= list("type" = /obj/item/clothing/mask/samurai, "icon" = 'icons/obj/clothing/masks.dmi', "icon_state" = "samurai1", "cost" = 1, "first_age" = 2, "count" = 1, "final_age" = 3),\
					"Red Samurai Helmet"	= list("type" = /obj/item/clothing/head/helmet/samurai/red, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "samurai_warrior1", "cost" = 1, "count" = 1, "first_age" = 2, "final_age" = 3),\
					"Red Samurai Lord Helmet" = list("type" = /obj/item/clothing/head/helmet/samurai/lord/red, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "samurai_lord1", "cost" = 2, "count" = 1, "first_age" = 2, "final_age" = 3),\
					"Red Samurai Mask"		= list("type" = /obj/item/clothing/mask/samurai/red, "icon" = 'icons/obj/clothing/masks.dmi', "icon_state" = "samurai2", "cost" = 1, "count" = 1, "first_age" = 2, "final_age" = 3),\
					"Blue Samurai Helmet"	= list("type" = /obj/item/clothing/head/helmet/samurai/blue, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "samurai_warrior2", "cost" = 1, "count" = 1, "first_age" = 2, "final_age" = 3),\
					"Blue Samurai Lord Helmet" = list("type" = /obj/item/clothing/head/helmet/samurai/lord/blue, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "samurai_lord2", "cost" = 2, "count" = 1, "first_age" = 2, "final_age" = 3),\
					"Blue Samurai Mask"		= list("type" = /obj/item/clothing/mask/samurai/blue, "icon" = 'icons/obj/clothing/masks.dmi', "icon_state" = "samurai3", "cost" = 1, "count" = 1, "first_age" = 2, "final_age" = 3),\
					"Black Samurai Helmet"	= list("type" = /obj/item/clothing/head/helmet/samurai/black, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "samurai_warrior4", "cost" = 1, "count" = 1, "first_age" = 2, "final_age" = 3),\
					"Black Samurai Lord Helmet" = list("type" = /obj/item/clothing/head/helmet/samurai/lord/black, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "samurai_lord4", "cost" = 2, "count" = 1, "first_age" = 2, "final_age" = 3),\

					"Mk1 Brodie (Apple Green)" = list("type" = /obj/item/clothing/head/helmet/ww/mk1brodieag, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "brodie_mk1_ag", "cost" = 2, "count" = 1, "first_age" = 5, "final_age" = 5),\
					"Mk1 Brodie (Duck Egg Blue)" = list("type" = /obj/item/clothing/head/helmet/ww/mk1brodiedeb, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "brodie_mk1_deb", "cost" = 2, "count" = 1, "first_age" = 5, "final_age" = 5),\
					"Standard M15 Adrian"	= list("type" = /obj/item/clothing/head/helmet/ww/adrian, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "adrian_standard", "cost" = 2, "count" = 1, "first_age" = 5, "final_age" = 5),\
					"Russian M15 Adrian"	= list("type" = /obj/item/clothing/head/helmet/ww/adriansoviet, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "adrian_russian", "cost" = 2, "count" = 1, "first_age" = 5, "final_age" = 5),\
					"Greek M15 Adrian"		= list("type" = /obj/item/clothing/head/helmet/ww/adrian/greek, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "adrian_greek", "cost" = 2, "count" = 1, "first_age" = 5, "final_age" = 5),\

					"Soviet Helmet"			= list("type" = /obj/item/clothing/head/helmet/ww2/soviet, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "sovhelm", "cost" = 2, "count" = 1, "first_age" = 6, "final_age" = 6),\
					"M1 Helmet"				= list("type" = /obj/item/clothing/head/helmet/ww2/usm1, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "m1_standard", "cost" = 2, "count" = 1, "first_age" = 6, "final_age" = 6),\
					"Type 92 Helmet"		= list("type" = /obj/item/clothing/head/helmet/ww2/japhelm, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "japhelm", "cost" = 2, "count" = 1, "first_age" = 6, "final_age" = 6),\
					"Mk2 Brodie Helmet"		= list("type" = /obj/item/clothing/head/helmet/ww/mk2brodieog, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "brodie_mk2_og", "cost" = 2, "count" = 1, "first_age" = 6, "final_age" = 6),\
					"M26 Adrian Helmet"		= list("type" = /obj/item/clothing/head/helmet/ww/adrianm26, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "m26_adrian", "cost" = 2, "count" = 1, "first_age" = 6, "final_age" = 6),\

					"USSR SSh-68 Helmet"	= list("type" = /obj/item/clothing/head/helmet/modern/ssh_68, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "ssh_68_sovhelm", "cost" = 2, "count" = 1, "first_age" = 7, "final_age" = 7),\
					"Korean War US M1 Helmet" = list("type" = /obj/item/clothing/head/helmet/korean/usm1, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "korea_m1_standard", "cost" = 2, "count" = 1, "first_age" = 7, "final_age" = 7),\
					"Russian ZSh-1 Helmet"	= list("type" = /obj/item/clothing/head/helmet/modern/zsh1, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "zsh1", "cost" = 2, "first_age" = 7, "count" = 1, "final_age" = 7),\
					"USSR MASKA1 Helmet"	= list("type" = /obj/item/clothing/head/helmet/modern/sovietfacehelmet/nomads, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "sovietfacehelmet_o", "cost" = 2, "count" = 1, "first_age" = 7, "final_age" = 7),\
					"USSR K6-3 Helmet"		= list("type" = /obj/item/clothing/head/helmet/modern/sovietfacehelmet/welding/nomads, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "sovietface_weldhelmet", "cost" = 2, "count" = 1, "first_age" = 7, "final_age" = 7),\
					"Russian ZSh-2 helmet"	= list("type" = /obj/item/clothing/head/helmet/modern/a6b47, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "a6b47", "cost" = 2, "first_age" = 7, "count" = 1, "final_age" = 7),

					"Kevlar Helmet"			= list("type" = /obj/item/clothing/head/helmet/kevlarhelmet, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "kevlarhelmet", "cost" = 2, "count" = 1, "first_age" = 7, "final_age" = 8),\
					"SWAT Helmet"			= list("type" = /obj/item/clothing/head/helmet/swat, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "swat", "cost" = 2, "count" = 1, "first_age" = 7, "final_age" = 8),\
					"Standard PASGT Helmet"	= list("type" = /obj/item/clothing/head/helmet/modern/pasgt, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "pasgt_woodland", "cost" = 2, "count" = 1, "first_age" = 7, "final_age" = 8),\
					"Desert PASGT Helmet"	= list("type" = /obj/item/clothing/head/helmet/modern/pasgt/desert, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "pasgt_desert", "cost" = 2, "count" = 1, "first_age" = 7, "final_age" = 8),\
					"Tactical Helmet"		= list("type" = /obj/item/clothing/head/helmet/tactical, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "tacticalhelmet", "cost" = 2, "count" = 1, "first_age" = 7, "final_age" = 8),\

					"Modern US M1 Helmet"	= list("type" = /obj/item/clothing/head/helmet/modern/ushelmet, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "m1_standard", "cost" = 2, "count" = 1, "first_age" = 8, "final_age" = 8),\
					"Standard US LWT Helmet"= list("type" = /obj/item/clothing/head/helmet/modern/lwh, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "lwh_desert", "cost" = 2, "count" = 1, "first_age" = 8, "final_age" = 8),\
					"Black US LWT Helmet"	= list("type" = /obj/item/clothing/head/helmet/modern/lwh/black, "icon" = 'icons/obj/clothing/hats.dmi', "icon_state" = "lwh_black", "cost" = 2, "count" = 1, "first_age" = 8, "final_age" = 8),\
				),\
			),\
		)\
	)