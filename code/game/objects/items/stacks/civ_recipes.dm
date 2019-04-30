/*
/////////////////////////////AGES///////////////////////
0-15 Stone Age (<5000 BC)
15-20 Copper Age (2-3k BC)
20-30 Bronze Age (1000 BC)
30-40 Iron age/Ancient Age (500 BC to 300 AC)
40-50 Early Medieval Age (500 to 1200)
50-60 Late Medieval (1400-1500)
60-80 Renaissance (1500-1600)
80-90 Imperial Age (1700s)
90-100 Napoleonic Age (early 1800s)
100-110 Early Industrial Age (1850-1870)
110-120 Industrial Age (1870-1900)
120-130 Early Modern Age (1900-1910)
130-140 Interwar period (1910-1950)
140-150 Space age (1950-Present

///the next time lines are of the SS13 universe\\\

150-170 Earth uniteds ( 1950-2050)
170-230 Nanotrason hase taken over (2050-the SS13 time line 2560
///////////////////////////////////////////////////////
*/

/material/proc/get_recipes_civs(var/civ = "none", var/mob/living/carbon/human/user)
	var/list/current_res = list(0,0,0)
	if (civ == "Nomad")
		current_res = map.custom_civs[user.civilization]
	else
		if (civ == "Civilization A Citizen")
			current_res = map.civa_research
		else if (civ == "Civilization B Citizen")
			current_res = map.civb_research
		else if (civ == "Civilization C Citizen")
			current_res = map.civc_research
		else if (civ == "Civilization D Citizen")
			current_res = map.civd_research
		else if (civ == "Civilization E Citizen")
			current_res = map.cive_research
		else if (civ == "Civilization F Citizen")
			current_res = map.civf_research
	generate_recipes_civs(current_res)
	return recipes

/material/proc/generate_recipes_civs(var/current_res = "none")

	recipes = list()
	if (hardness>=40 && current_res[1] > 8)
		recipes += new/datum/stack_recipe("[display_name] fork", /obj/item/weapon/material/kitchen/utensil/fork, TRUE, _on_floor = TRUE, _supplied_material = "[name]")
		recipes += new/datum/stack_recipe("[display_name] knife", /obj/item/weapon/material/kitchen/utensil/knife, TRUE, _on_floor = TRUE, _supplied_material = "[name]")
		recipes += new/datum/stack_recipe("[display_name] spoon", /obj/item/weapon/material/kitchen/utensil/spoon, TRUE, _on_floor = TRUE, _supplied_material = "[name]")

/material/clay/generate_recipes_civs(var/list/current_res = list(0,0,0))
	..()
	recipes += new/datum/stack_recipe("unfired clay roofing", /obj/item/weapon/clay/roofing, 2, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("unfired clay vase", /obj/item/weapon/clay/vase, 3, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("unfired clay wine cup", /obj/item/weapon/clay/winecup, 1, _time = 30, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("unfired clay blocks", /obj/item/weapon/clay/claybricks, 1, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("unfired clay bowl", /obj/item/weapon/clay/claybowl, 1, _time = 30, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("unfired clay jug", /obj/item/weapon/clay/clayjug, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("unfired clay cup", /obj/item/weapon/clay/claycup, 1, _time = 30, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("unfired very small clay pot", /obj/item/weapon/clay/verysmallclaypot, 1, _time = 20, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("unfired small clay pot", /obj/item/weapon/clay/smallclaypot, 1, _time = 30, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("unfired medium clay pot", /obj/item/weapon/clay/claypot, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("unfired large clay pot", /obj/item/weapon/clay/bigclaypot, 3, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("unfired clay pitcher", /obj/item/weapon/clay/claypitcher, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("unfired large clay pitcher", /obj/item/weapon/clay/largeclaypitcher, 3, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[1] >= 82)
		recipes += new/datum/stack_recipe("unfired clay bricks", /obj/item/weapon/clay/advclaybricks, 1, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("unfired cement bricks", /obj/item/weapon/clay/advclaybricks/cement, 1, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE)

/material/leather/generate_recipes_civs(var/list/current_res = list(0,0,0))
	..()
	recipes += new/datum/stack_recipe("sling", /obj/item/weapon/gun/projectile/bow/sling, 3, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[1] >= 25 && current_res[3] >= 25)
		recipes += new/datum/stack_recipe("comfy chair", /obj/structure/bed/chair/comfy/brown, 6, _time = 100, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("bug swatter", /obj/item/weapon/swatter, 3, _time = 90, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("quiver", /obj/item/weapon/storage/backpack/quiver, 3, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("leather satchel", /obj/item/weapon/storage/belt/leather, 3, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("leather bedroll", /obj/item/weapon/bedroll, 4, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("leather waterskin", /obj/item/weapon/reagent_containers/food/drinks/drinkingglass/waterskin, 3, _time = 90, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("ore collector", /obj/item/weapon/storage/ore_collector, 5, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("seed collector", /obj/item/weapon/storage/seed_collector, 5, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("leather bandages", /obj/item/stack/medical/bruise_pack/bint/leather, 1, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("foldable canopy", /obj/item/weapon/tent, 5, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE)
	if (map.ordinal_age <= 0)
		recipes += new/datum/stack_recipe("leather loincloth", /obj/item/clothing/under/loinleather, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE)
	if (map.ordinal_age <= 1)
		recipes += new/datum/stack_recipe("small customizable loincloth", /obj/item/clothing/under/custom/spartan, 3, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[1] >= 18)
		recipes += new/datum/stack_recipe("coin pouch", /obj/item/clothing/accessory/storage/coinpouch, 2, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("leather backpack", /obj/item/weapon/storage/backpack, 6, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[1] >= 87)
		recipes += new/datum/stack_recipe("wallet", /obj/item/clothing/accessory/storage/coinpouch/wallet, 2, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[2] >= 19 && map.ordinal_age <= 1)
		recipes += new/datum/stack_recipe("roman-style sandals", /obj/item/clothing/shoes/roman, 2, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("long celtic braccae", /obj/item/clothing/under/celtic_long_braccae, 3, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes +=  new/datum/stack_recipe("short celtic braccae", /obj/item/clothing/under/celtic_short_braccae, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[2] >= 39 && map.ordinal_age <= 2)
		recipes += new/datum/stack_recipe("medieval shoes", /obj/item/clothing/shoes/medieval, 3, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("arabic-style shoes", /obj/item/clothing/shoes/medieval/arab, 2, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("samurai armor", /obj/item/clothing/suit/armor/samurai, 20, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("red samurai armor", /obj/item/clothing/suit/armor/samurai/red, 20, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("blue samurai armor", /obj/item/clothing/suit/armor/samurai/blue, 20, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("black samurai armor", /obj/item/clothing/suit/armor/samurai/black, 20, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("samurai helmet", /obj/item/clothing/head/helmet/samurai/guard, 10, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("red samurai helmet", /obj/item/clothing/head/helmet/samurai/guard/red, 10, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("blue samurai helmet", /obj/item/clothing/head/helmet/samurai/guard/blue, 10, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("black samurai helmet", /obj/item/clothing/head/helmet/samurai/guard/black, 10, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[2] >= 54 && map.ordinal_age >= 2)
		recipes += new/datum/stack_recipe("gunpowder pouch", /obj/item/weapon/reagent_containers/food/drinks/gunpowder, 2, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("bandolier", /obj/item/clothing/accessory/storage/webbing, 3, _time = 70, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[3] >= 85)
		recipes += new/datum/stack_recipe("suspenders", /obj/item/clothing/accessory/armband/suspenders1, 1, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("dark suspenders", /obj/item/clothing/accessory/armband/suspenders2, 1, _time = 70, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("bullet pouch", /obj/item/ammo_magazine/emptypouch, 3, _time = 70, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("hip holster", /obj/item/clothing/accessory/holster/hip, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("double hip holster", /obj/item/clothing/accessory/holster/hip/double, 3, _time = 70, _one_per_turf = FALSE, _on_floor = TRUE)

	if (current_res[1] >= 55 && current_res[3] >= 25)
		recipes += new/datum/stack_recipe("black leather shoes", /obj/item/clothing/shoes/soldiershoes, 2, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("black leather boots", /obj/item/clothing/shoes/blackboots1, 3, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("leather boots", /obj/item/clothing/shoes/leatherboots1, 3, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[2] >= 15 && current_res[3] < 72)
		recipes += new/datum/stack_recipe("leather armor", /obj/item/clothing/suit/armor/medieval/leather, 6, _time = 130, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("leather helmet", /obj/item/clothing/head/helmet/leather, 3, _time = 90, _one_per_turf = FALSE, _on_floor = TRUE)

	recipes += new/datum/stack_recipe("leather curtain", /obj/structure/curtain/leather, 4, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += list(new/datum/stack_recipe("custom flag maker", /obj/item/flagmaker, 4, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE))
	recipes += new/datum/stack_recipe_list("accessories", list(
		new/datum/stack_recipe("customizable armband", /obj/item/clothing/accessory/custom/armband, 1, _time = 30, _one_per_turf = FALSE, _on_floor = TRUE),))
	if (current_res[3] >= 107)
		recipes += new/datum/stack_recipe("pilot goggles", /obj/item/clothing/mask/glasses/pilot, 2, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE)

	if (current_res[3] >= 98 && current_res[3] < 109)
		recipes += new/datum/stack_recipe_list("foot wear", list(
			new/datum/stack_recipe("black riding boots", /obj/item/clothing/shoes/riding1, 3, _time =50 , _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("riding boots", /obj/item/clothing/shoes/riding2, 3, _time =50 , _one_per_turf = FALSE, _on_floor = TRUE),))

/material/iron/generate_recipes_civs(var/list/current_res = list(0,0,0))
	..()
	if (current_res[1] >= 33)
		recipes += new/datum/stack_recipe("table", /obj/structure/table, 4, _time = 80, _one_per_turf = TRUE, _on_floor = TRUE, _supplied_material = "[name]")
		recipes += new/datum/stack_recipe("cooking pot", /obj/structure/pot, 8, _time = 180, _one_per_turf = TRUE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("oven", /obj/structure/oven, 8, _time = 150, _one_per_turf = TRUE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe(" brazier",	/obj/structure/brazier, 4, _time = 90, _one_per_turf = TRUE, _on_floor = TRUE)
	if (current_res[2] >= 32)
		recipes += new/datum/stack_recipe("mechanical trap", /obj/item/weapon/beartrap, 5, _time = 140, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[2] >= 61)
		recipes += new/datum/stack_recipe("monocle", /obj/item/clothing/mask/glasses/monocle, 3, _time = 110, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[2] >= 46)
		recipes += new/datum/stack_recipe("telescope", /obj/item/weapon/attachment/scope/adjustable/binoculars, 5, _time = 140, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[1] >= 28)
		recipes += new/datum/stack_recipe("lantern", /obj/item/flashlight/lantern, 4, _time = 140, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("unlocked door", /obj/structure/simple_door/key_door/anyone, 5, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("locked door", /obj/structure/simple_door/key_door/custom, 5, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("key", /obj/item/weapon/key, 2, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("keychain", /obj/item/weapon/storage/belt/keychain, 1, _time = 30, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[1] >= 25)
		recipes += new/datum/stack_recipe("anvil", /obj/structure/anvil, 25, _time = 150, _one_per_turf = TRUE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("circumcision knife", /obj/item/weapon/material/kitchen/utensil/knife/circumcision, 2, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE)

	if (current_res[1] >= 27 && current_res[2] >= 16)
		recipes += new/datum/stack_recipe("iron-tipped spear", /obj/item/weapon/material/spear, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")

		recipes += new/datum/stack_recipe("battle axe", /obj/item/weapon/material/hatchet/battleaxe, 4, _time = 70, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
		recipes += new/datum/stack_recipe("iron shield", /obj/item/weapon/shield/iron, 4, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[1] >= 33 && current_res[2] >= 39)
		recipes += new/datum/stack_recipe("halberd", /obj/item/weapon/material/halberd, 2, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
		recipes += new/datum/stack_recipe("pike", /obj/item/weapon/material/pike, 3, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
		recipes += new/datum/stack_recipe_list("tools", list(
			new/datum/stack_recipe("hatchet", /obj/item/weapon/material/hatchet, 2, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]"),
			new/datum/stack_recipe("shovel", /obj/item/weapon/shovel, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("wrench", /obj/item/weapon/wrench, 4, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("butcher's cleaver", /obj/item/weapon/material/knife/butcher, 3, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]"),
			new/datum/stack_recipe("razor blade", /obj/item/weapon/material/kitchen/utensil/knife/razorblade, 2, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]"),
			new/datum/stack_recipe("pickaxe", /obj/item/weapon/pickaxe, 3, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE),))

	if (current_res[1] >= 39 && current_res[2] >= 40 && map.ordinal_age <= 2)
		recipes += new/datum/stack_recipe("naginata", /obj/item/weapon/material/naginata, 12, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")

	if (current_res[2] >= 80 && map.ordinal_age < 4)
		recipes += new/datum/stack_recipe_list("bullets", list(
			new/datum/stack_recipe("musket ball (x2)", /obj/item/stack/ammopart/musketball, 1, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("small musket ball (x3)", /obj/item/stack/ammopart/musketball_pistol, 1, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("blunderbuss ball (x2)", /obj/item/stack/ammopart/blunderbuss, 1, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("cannon ball", /obj/item/cannon_ball, 5, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE),))
	else if (current_res[2] >= 82 && map.ordinal_age >= 4)
		recipes += new/datum/stack_recipe_list("bullets", list(
			new/datum/stack_recipe("musket ball (x2)", /obj/item/stack/ammopart/musketball, 1, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("small musket ball (x3)", /obj/item/stack/ammopart/musketball_pistol, 1, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("blunderbuss ball (x2)", /obj/item/stack/ammopart/blunderbuss, 1, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("iron bullet (x3)", /obj/item/stack/ammopart/bullet, 1, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE),

			new/datum/stack_recipe("cannon ball", /obj/item/cannon_ball, 5, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE),))
	if (current_res[1] >= 115 && map.ordinal_age >= 5)
		recipes += new/datum/stack_recipe("engine maker", /obj/item/weapon/enginemaker, 5, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[2] >= 90 && map.ordinal_age >= 4)
		recipes += new/datum/stack_recipe("trench shovel", /obj/item/weapon/shovel/trench, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("bayonet", /obj/item/weapon/attachment/bayonet, 2, _time = 30, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[2] >= 87)
		recipes += new/datum/stack_recipe("iron furnace", /obj/structure/heatsource, 15, _time = 140, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("iron altar", /obj/structure/altar/iron, 12, _time = 200, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("iron arm bangles", /obj/item/clothing/accessory/armband/armbangle, 2, _time = 95, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[1] >= 35 && current_res[3]>= 44)
		recipes += new/datum/stack_recipe("splints", /obj/item/stack/medical/splint, 2, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE)

	if (current_res[1] >= 35 && current_res[3]>= 67)
		recipes += new/datum/stack_recipe_list("medical tools", list(
			new/datum/stack_recipe("retractor", /obj/item/weapon/surgery/retractor, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("hemostat", /obj/item/weapon/surgery/hemostat, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("cautery",/obj/item/weapon/surgery/cautery, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("bone saw",/obj/item/weapon/surgery/bone_saw, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("bone setter",/obj/item/weapon/surgery/bonesetter, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("scalpel", /obj/item/weapon/surgery/scalpel, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),))

	else if (current_res[1] >= 35 && current_res[3]>= 55)
		recipes += new/datum/stack_recipe_list("medical tools", list(
			new/datum/stack_recipe("retractor", /obj/item/weapon/surgery/retractor, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("bone saw",/obj/item/weapon/surgery/bone_saw, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("bone setter",/obj/item/weapon/surgery/bonesetter, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("scalpel", /obj/item/weapon/surgery/scalpel, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),))

	if (current_res[2] >= 70)
		recipes += new/datum/stack_recipe_list("firearms", list(
			new/datum/stack_recipe("fire lance", /obj/item/weapon/gun/projectile/ancient/firelance, 6, _time = 90, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("hand cannon", /obj/item/weapon/gun/projectile/ancient/handcannon, 14, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("arquebus", /obj/item/weapon/gun/projectile/ancient/arquebus, 15, _time = 110, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("matchlock musket", /obj/item/weapon/gun/projectile/ancient/matchlock, 18, _time = 140, _one_per_turf = FALSE, _on_floor = TRUE),))
	else if (current_res[2] >= 62 && current_res[2] < 70)
		recipes += new/datum/stack_recipe_list("firearms", list(
			new/datum/stack_recipe("fire lance", /obj/item/weapon/gun/projectile/ancient/firelance, 6, _time = 90, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("hand cannon", /obj/item/weapon/gun/projectile/ancient/handcannon, 14, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("arquebus", /obj/item/weapon/gun/projectile/ancient/arquebus, 15, _time = 110, _one_per_turf = FALSE, _on_floor = TRUE),))
	else if (current_res[2] >= 56 && current_res[2] < 62)
		recipes += new/datum/stack_recipe_list("firearms", list(
			new/datum/stack_recipe("fire lance", /obj/item/weapon/gun/projectile/ancient/firelance, 6, _time = 90, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("hand cannon", /obj/item/weapon/gun/projectile/ancient/handcannon, 14, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),))
	else if (current_res[2] >= 49 && current_res[2] < 56)
		recipes += new/datum/stack_recipe_list("firearms", list(
			new/datum/stack_recipe("fire lance", /obj/item/weapon/gun/projectile/ancient/firelance, 6, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),))

/material/wood/generate_recipes_civs(var/list/current_res = list(0,0,0))
	..()
	if (current_res[1] >= 22)
		recipes += new/datum/stack_recipe("raft",/obj/structure/vehicle/raft, 10, _time = 180, _one_per_turf = TRUE, _on_floor = TRUE)
	if (current_res[1] >= 22)
		recipes += new/datum/stack_recipe("boat frame", /obj/item/vehicleparts/frame/boat, 22, _time = 200, _one_per_turf = FALSE, _on_floor = TRUE)
	if (map.resourceresearch == TRUE)
		recipes += new/datum/stack_recipe("research desk",/obj/structure/researchdesk, 8, _time = 250, _one_per_turf = TRUE, _on_floor = TRUE)
	if (current_res[1] >= 96)
		recipes += new/datum/stack_recipe("global exchange",/obj/structure/marketplace, 10, _time = 140, _one_per_turf = TRUE, _on_floor = TRUE)
	if (map.ordinal_age >= 4)
		recipes += new/datum/stack_recipe("communications pole",/obj/structure/phoneline, 2, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE)
	if (current_res[1] >= 105 || map.gamemode == "Oil Rush")
		recipes += new/datum/stack_recipe("oil well",/obj/structure/oilwell, 40, _time = 270, _one_per_turf = TRUE, _on_floor = TRUE)
	if (map.gamemode == "Oil Rush")
		recipes += new/datum/stack_recipe("oil deposit",/obj/structure/oil_deposits, 6, _time = 100, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("roof support",/obj/structure/roof_support, 2, _time = 30, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("mine support",/obj/structure/mine_support, 2, _time = 30, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("roof builder",/obj/item/weapon/roofbuilder, 1, _time = 20, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[1] >= 33 && current_res[3]>= 48)
		recipes += new/datum/stack_recipe("doctor handbook",/obj/item/weapon/doctor_handbook, 12, _time = 210, _one_per_turf = FALSE, _on_floor = TRUE)
//	if (current_res[1] >= 25 && current_res[3]>= 51)
//		recipes += new/datum/stack_recipe("operating table",/obj/structure/optable, 9, _time = 190, _one_per_turf = FALSE, _on_floor = TRUE)
	if (map.ordinal_age > 0 && map.research_active == TRUE)
		recipes += new/datum/stack_recipe("research kit",/obj/item/weapon/researchkit, 10, _time = 190, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[1] >= 18)

		recipes += new/datum/stack_recipe_list("walls, doors & floors", list(
			new/datum/stack_recipe("door", /obj/structure/simple_door/key_door/anyone/wood, 5, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("floor tile", /obj/covers/wood, 1, _time = 25, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("wood stairs", /obj/covers/wood/stairs, 2, _time = 35, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("window", /obj/structure/window_frame, 5, _time = 80, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("soft wood wall", /obj/covers/wood_wall, 8, _time = 170, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("straw wall", /obj/covers/straw_wall, 4, _time = 90, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("custom sign", /obj/structure/sign/custom, 3, _time = 40, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("floor cover", /obj/item/weapon/covers, 2, _time = 30, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("shoji wall", /obj/covers/wood_wall/shoji, 4, _time = 80, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("shoji divider", /obj/covers/wood_wall/shoji_divider, 3, _time = 90, _one_per_turf = TRUE, _on_floor = TRUE),))
	else
		recipes += new/datum/stack_recipe_list("walls, doors & floors", list(
			new/datum/stack_recipe("straw wall", /obj/covers/straw_wall, 5, _time = 90, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("custom sign", /obj/structure/sign/custom, 3, _time = 40, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("floor cover", /obj/item/weapon/covers, 2, _time = 30, _one_per_turf = TRUE, _on_floor = TRUE),))

	recipes += new/datum/stack_recipe_list("barricades", list(
		new/datum/stack_recipe("horizontal wood barrier", /obj/structure/barricade/horizontal, 5, _time = 35, _one_per_turf = TRUE, _on_floor = TRUE),
		new/datum/stack_recipe("vertical wood barrier", /obj/structure/barricade/vertical, 5, _time = 35, _one_per_turf = TRUE, _on_floor = TRUE),
		new/datum/stack_recipe("wood palisade", 	/obj/structure/grille/logfence, 6, _time = 80, _one_per_turf = TRUE, _on_floor = TRUE),
		new/datum/stack_recipe("wood fence", 	/obj/structure/grille/fence, 3, _time = 60, _one_per_turf = TRUE, _on_floor = TRUE),
		new/datum/stack_recipe("wood structure", /obj/structure/barricade, 5, _time = 35, _one_per_turf = TRUE, _on_floor = TRUE,),))

	if (current_res[2] >= 95)
		recipes += new/datum/stack_recipe_list("weapons", list(
			new/datum/stack_recipe("arrow", /obj/item/ammo_casing/arrow, 1, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("bow", /obj/item/weapon/gun/projectile/bow, 8, _time = 120, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("quarterstaff", /obj/item/weapon/material/quarterstaff, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]"),
			new/datum/stack_recipe("punji sticks trap", /obj/item/weapon/punji_sticks, 4, _time = 70, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("wood spear", /obj/item/weapon/material/spear, 3, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]"),
			new/datum/stack_recipe("police baton", /obj/item/weapon/melee/classic_baton, 4, _time = 90, _one_per_turf = FALSE, _on_floor = TRUE),))
	else if (current_res[2] >= 21 && current_res[2] < 95)
		recipes += new/datum/stack_recipe_list("weapons", list(
			new/datum/stack_recipe("arrow", /obj/item/ammo_casing/arrow, 1, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("bow", /obj/item/weapon/gun/projectile/bow, 8, _time = 120, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("quarterstaff", /obj/item/weapon/material/quarterstaff, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]"),
			new/datum/stack_recipe("punji sticks trap", /obj/item/weapon/punji_sticks, 4, _time = 70, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("wood spear", /obj/item/weapon/material/spear, 3, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]"),
			new/datum/stack_recipe("wood dory", /obj/item/weapon/material/spear/dory, 4, _time = 70, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]"),
			new/datum/stack_recipe("wood sarissa", /obj/item/weapon/material/spear/sarissa, 4, _time = 90, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]"),
			new/datum/stack_recipe("wood shield", /obj/item/weapon/shield, 8, _time = 180, _one_per_turf = FALSE, _on_floor = TRUE)))

	else if (current_res[2] >= 14 && current_res[2] < 21)
		recipes += new/datum/stack_recipe_list("weapons", list(
			new/datum/stack_recipe("arrow", /obj/item/ammo_casing/arrow, 1, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("bow", /obj/item/weapon/gun/projectile/bow, 8, _time = 120, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("punji sticks trap", /obj/item/weapon/punji_sticks, 4, _time = 70, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("quarterstaff", /obj/item/weapon/material/quarterstaff, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]"),
			new/datum/stack_recipe("wood spear", /obj/item/weapon/material/spear, 3, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]"),
			new/datum/stack_recipe("wood shield", /obj/item/weapon/shield, 8, _time = 180, _one_per_turf = FALSE, _on_floor = TRUE)))
	else if (current_res[1] >= 14 && current_res[2] < 14)
		recipes += new/datum/stack_recipe_list("weapons", list(
			new/datum/stack_recipe("arrow", /obj/item/ammo_casing/arrow, 1, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("bow", /obj/item/weapon/gun/projectile/bow, 8, _time = 120, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("punji sticks trap", /obj/item/weapon/punji_sticks, 4, _time = 70, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("quarterstaff", /obj/item/weapon/material/quarterstaff, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]"),
			new/datum/stack_recipe("wood spear", /obj/item/weapon/material/spear, 3, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]"),))

	else
		recipes += new/datum/stack_recipe_list("weapons", list(
			new/datum/stack_recipe("punji sticks trap", /obj/item/weapon/punji_sticks, 4, _time = 70, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("quarterstaff", /obj/item/weapon/material/quarterstaff, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]"),
			new/datum/stack_recipe("wood spear", /obj/item/weapon/material/spear, 3, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]"),
			new/datum/stack_recipe("wood club", /obj/item/weapon/melee/classic_baton/club, 3, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]"),))

	if (current_res[1] >= 22)
		recipes += new/datum/stack_recipe_list("tools", list(
			new/datum/stack_recipe("wood handle", /obj/item/weapon/material/handle, 1, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]"),
			new/datum/stack_recipe("wood cane", /obj/item/weapon/cane, 2, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("bucket",/obj/item/weapon/reagent_containers/glass/bucket, 2, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("plough",/obj/item/weapon/plough, 4, _time = 120, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("fishing pole",/obj/item/weapon/fishing, 3, _time = 120, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("hammer",/obj/item/weapon/hammer, 5, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("rollingpin",/obj/item/weapon/material/kitchen/rollingpin, 1, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("mop",/obj/item/weapon/mop, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),))
	else
		recipes += new/datum/stack_recipe_list("tools", list(
			new/datum/stack_recipe("wood handle", /obj/item/weapon/material/handle, 1, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]"),
			new/datum/stack_recipe("wood cane", /obj/item/weapon/cane, 2, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("bucket",/obj/item/weapon/reagent_containers/glass/bucket, 2, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("plough",/obj/item/weapon/plough, 4, _time = 120, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("fishing pole",/obj/item/weapon/fishing, 3, _time = 120, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("hammer",/obj/item/weapon/hammer, 5, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),))
	if (current_res[1] >= 41)
		recipes += new/datum/stack_recipe_list("furniture", list(
			new/datum/stack_recipe("chair", /obj/structure/bed/chair/wood, 4, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("wood chest", /obj/structure/closet/crate/chest, 7, _time = 75, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("bed", /obj/structure/bed/wood, 4, _time = 60,_one_per_turf = TRUE, _on_floor = TRUE,),
			new/datum/stack_recipe("wood crate", /obj/structure/closet/crate/empty, 5, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("bookcase", /obj/structure/bookcase, 6, _time = 80, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("target practice dummy", /obj/structure/target_practice, 7, _time = 120, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("table", /obj/structure/table/wood, 4, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("coffin", /obj/structure/closet/coffin, 4, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("gallows", /obj/structure/gallows, 3, _time = 60, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("wardrobe", /obj/structure/closet/cabinet, 5, _time = 80, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("wood pole", /obj/structure/barricade/wood_pole, 2, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),))
	else if (current_res[1] >= 14)
		recipes += new/datum/stack_recipe_list("furniture", list(
			new/datum/stack_recipe("chair", /obj/structure/bed/chair/wood, 4, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("wood chest", /obj/structure/closet/crate/chest, 7, _time = 75, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("bed", /obj/structure/bed/wood, 4, _time = 60,_one_per_turf = TRUE, _on_floor = TRUE,),
			new/datum/stack_recipe("wood crate", /obj/structure/closet/crate/empty, 5, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("bookcase", /obj/structure/bookcase, 6, _time = 80, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("target practice dummy", /obj/structure/target_practice, 7, _time = 120, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("table", /obj/structure/table/wood, 4, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("gallows", /obj/structure/gallows, 3, _time = 60, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("wood pole", /obj/structure/barricade/wood_pole, 2, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),))
	else
		recipes += new/datum/stack_recipe_list("furniture", list(
			new/datum/stack_recipe("bed", /obj/structure/bed/wood, 4, _time = 60,_one_per_turf = TRUE, _on_floor = TRUE,),
			new/datum/stack_recipe("wood crate", /obj/structure/closet/crate/empty, 5, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("table", /obj/structure/table/wood, 4, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("gallows", /obj/structure/gallows, 3, _time = 60, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("wood pole", /obj/structure/barricade/wood_pole, 2, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),))

	if (current_res[1] < 47)
		recipes += new/datum/stack_recipe_list("religious & decoration", list(
			new/datum/stack_recipe("wood altar", /obj/structure/altar/wood, 20, _time = 200, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("native wood mask", /obj/structure/religious/tribalmask, 2, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("impaled skull", /obj/structure/religious/impaledskull, 2, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),))
	else
		recipes += new/datum/stack_recipe_list("religious & decoration", list(
			new/datum/stack_recipe("wood altar", /obj/structure/altar/wood, 20, _time = 200, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("impaled skull", /obj/structure/religious/impaledskull, 2, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("small cross", /obj/structure/religious/woodcross1, 2, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("cross", /obj/structure/religious/woodcross2, 4, _time = 80, _one_per_turf = TRUE, _on_floor = TRUE),))

	if (current_res[1] < 19)
		recipes += new/datum/stack_recipe_list("kitchen & other", list(
			new/datum/stack_recipe("sandals", /obj/item/clothing/shoes/sandal, 1, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("wood mug",/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/wood, 1, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("campfire",/obj/structure/oven/fireplace, 4, _time = 140, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("torch",/obj/item/flashlight/torch, 2, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("wood bowl",/obj/item/kitchen/wood_bowl, 1, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE),))
	else if (current_res[1] >= 19 && current_res[1] <= 45)
		recipes += new/datum/stack_recipe_list("kitchen & other", list(
			new/datum/stack_recipe("loom",/obj/structure/loom, 8, _time = 150, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("sandals", /obj/item/clothing/shoes/sandal, 1, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("wood mug",/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/wood, 1, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("campfire",/obj/structure/oven/fireplace, 4, _time = 140, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("torch",/obj/item/flashlight/torch, 2, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("wood pipe",/obj/item/clothing/mask/smokable/pipe, 2, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("wood bowl",/obj/item/kitchen/wood_bowl, 1, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("small mill",/obj/structure/mill, 4, _time = 90, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("barrel",/obj/item/weapon/reagent_containers/glass/barrel/empty, 5, _time = 75, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("dehydrator",/obj/structure/dehydrator, 5, _time = 110, _one_per_turf = TRUE, _on_floor = TRUE),))
	else
		recipes += new/datum/stack_recipe_list("kitchen & other", list(
			new/datum/stack_recipe("loom",/obj/structure/loom, 8, _time = 150, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("sandals", /obj/item/clothing/shoes/sandal, 1, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("wood mug",/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/wood, 1, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("campfire",/obj/structure/oven/fireplace, 4, _time = 140, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("torch",/obj/item/flashlight/torch, 2, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("wood pipe",/obj/item/clothing/mask/smokable/pipe, 2, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("wood bowl",/obj/item/kitchen/wood_bowl, 1, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("small mill",/obj/structure/mill, 4, _time = 90, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("barrel",/obj/item/weapon/reagent_containers/glass/barrel/empty, 5, _time = 75, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("violin",/obj/item/violin, 10, _time = 135, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("piano",/obj/structure/piano, 18, _time = 195, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("dehydrator",/obj/structure/dehydrator, 5, _time = 110, _one_per_turf = TRUE, _on_floor = TRUE),))
	if (current_res[1] < 19)
		recipes += new/datum/stack_recipe_list("paper & printing", list(
			new/datum/stack_recipe("scientific literature",/obj/item/weapon/book/research, 4, _time = 110, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("holy book",/obj/item/weapon/book/holybook, 15, _time = 240, _one_per_turf = TRUE, _on_floor = TRUE),))
	else if (current_res[1] >= 19 && current_res[1] <= 45)
		recipes += new/datum/stack_recipe_list("paper & printing", list(
			new/datum/stack_recipe("passport",/obj/item/clothing/accessory/storage/passport, 3, _time = 150, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("visa (empty)",/obj/item/weapon/visa, 1, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("scientific literature",/obj/item/weapon/book/research, 4, _time = 110, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("holy book",/obj/item/weapon/book/holybook, 15, _time = 240, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("pen",/obj/item/weapon/pen, 1, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("paper sheet",/obj/item/weapon/paper, 1, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("religious poster",/obj/item/weapon/poster/religious, 1, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("military propaganda poster (flag)",/obj/item/weapon/poster/faction/mil1, 1, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("military propaganda poster (armed)",/obj/item/weapon/poster/faction/mil2, 1, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("work propaganda poster",/obj/item/weapon/poster/faction/work, 1, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("leader propaganda poster",/obj/item/weapon/poster/faction/lead, 1, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE),))
	else if (current_res[1] > 45 && current_res[1] < 52)
		recipes += new/datum/stack_recipe_list("paper & printing", list(
			new/datum/stack_recipe("passport",/obj/item/clothing/accessory/storage/passport, 3, _time = 150, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("visa (empty)",/obj/item/weapon/visa, 1, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("scientific literature",/obj/item/weapon/book/research, 4, _time = 110, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("holy book",/obj/item/weapon/book/holybook, 15, _time = 240, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("pen",/obj/item/weapon/pen, 1, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("paper sheet",/obj/item/weapon/paper, 1, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("book",/obj/item/weapon/book, 4, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("religious poster",/obj/item/weapon/poster/religious, 1, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("military propaganda poster (flag)",/obj/item/weapon/poster/faction/mil1, 1, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("military propaganda poster (armed)",/obj/item/weapon/poster/faction/mil2, 1, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("work propaganda poster",/obj/item/weapon/poster/faction/work, 1, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("leader propaganda poster",/obj/item/weapon/poster/faction/lead, 1, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE),))
	else
		recipes += new/datum/stack_recipe_list("paper & printing", list(
			new/datum/stack_recipe("printing press",/obj/structure/printingpress, 12, _time = 120, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("passport",/obj/item/clothing/accessory/storage/passport, 3, _time = 150, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("visa (empty)",/obj/item/weapon/visa, 1, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("scientific literature",/obj/item/weapon/book/research, 4, _time = 110, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("holy book",/obj/item/weapon/book/holybook, 15, _time = 240, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("pen",/obj/item/weapon/pen, 1, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("paper sheet",/obj/item/weapon/paper, 1, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("book",/obj/item/weapon/book, 4, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("religious poster",/obj/item/weapon/poster/religious, 1, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("military propaganda poster (flag)",/obj/item/weapon/poster/faction/mil1, 1, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("military propaganda poster (armed)",/obj/item/weapon/poster/faction/mil2, 1, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("work propaganda poster",/obj/item/weapon/poster/faction/work, 1, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("leader propaganda poster",/obj/item/weapon/poster/faction/lead, 1, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE),))

	if (current_res[1] >= 24 && current_res[2] >= 33)
		recipes += new/datum/stack_recipe_list("siege weapons", list(
			new/datum/stack_recipe("catapult",/obj/structure/catapult, 50, _time = 450, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("siege ladder",/obj/item/weapon/siegeladder, 8, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),))

	if (current_res[3] >= 18)
		recipes += new/datum/stack_recipe_list("prosthetics", list(
			new/datum/stack_recipe("wooden foot", /obj/item/weapon/prosthesis/woodfoot, 3, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("wooden pegleg", /obj/item/weapon/prosthesis/pegleg, 5, _time = 110, _one_per_turf = FALSE, _on_floor = TRUE),))

/material/rope/generate_recipes_civs(var/list/current_res = list(0,0,0))
	..()
	recipes = list(new/datum/stack_recipe("noose", /obj/structure/noose, _time = 20))
	recipes += list(new/datum/stack_recipe("rope handcuffs", /obj/item/weapon/handcuffs/rope, _time = 50))
	recipes += list(new/datum/stack_recipe("fishing net", /obj/item/weapon/fishing/net, 4, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE))
	recipes += list(new/datum/stack_recipe("leash", /obj/item/weapon/leash, _time = 20))
/material/glass/generate_recipes_civs(var/list/current_res = list(0,0,0))
	..()
	if (current_res[1] >= 22)
		recipes += new/datum/stack_recipe("drinking glass", /obj/item/weapon/reagent_containers/food/drinks/drinkingglass, 2, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("small glass bottle", /obj/item/weapon/reagent_containers/food/drinks/bottle/small, 2, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[1] >= 49 && current_res[3] >= 24 )
		recipes += new/datum/stack_recipe("teapot", /obj/item/weapon/reagent_containers/food/drinks/teapot, 4, _time = 70, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("teacup", /obj/item/weapon/reagent_containers/food/drinks/tea/empty, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[1] >= 49)
		recipes += new/datum/stack_recipe("wine glass", /obj/item/weapon/reagent_containers/food/drinks/drinkingglass, 2, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("tribal pot", /obj/item/weapon/reagent_containers/food/drinks/drinkingglass/tribalpot, 2, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("fermentation jar", /obj/item/weapon/starterjar, 3, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE)
	if (map.ordinal_age >= 5)
		recipes += new/datum/stack_recipe_list("electrical", list(
			new/datum/stack_recipe("small lightbulb", /obj/structure/lamp/lamp_small, 1, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("light tube", /obj/structure/lamp/lamp_big, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),))
/material/stone/generate_recipes_civs(var/list/current_res = list(0,0,0))
	..()
	recipes += new/datum/stack_recipe("stone pillar",	/obj/structure/mine_support/stone, 2, _time = 130, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("stone brazier",	/obj/structure/brazier/stone, 3, _time = 100, _one_per_turf = TRUE, _on_floor = TRUE)
	if (map.ordinal_age == 0 && map.research_active == TRUE)
		recipes += new/datum/stack_recipe("research kit",/obj/item/weapon/researchkit, 10, _time = 190, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("scientific rock slate",/obj/item/weapon/book/research, 4, _time = 110, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("stone hatchet", /obj/item/weapon/material/hatchet/tribal, 2, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
	recipes += new/datum/stack_recipe("cobblestone floor", /obj/covers/cobblestone, 1, _time = 25, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("stone stairs", /obj/covers/cobblestone/stairs, 2, _time = 45, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("stone altar", /obj/structure/altar/stone, 15, _time = 200, _one_per_turf = TRUE, _on_floor = TRUE)
	if (current_res[1] >= 28)
		recipes += new/datum/stack_recipe("marble altar", /obj/structure/altar/marble, 20, _time = 200, _one_per_turf = TRUE, _on_floor = TRUE)
	if (current_res[1] >= 43)
		recipes += new/datum/stack_recipe("gravestone", /obj/structure/religious/gravestone, 3, _time = 60, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("totem", /obj/structure/religious/totem, 8, _time = 150, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("stone wall", /obj/covers/stone_wall, 8, _time = 140, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("rock barrier wall", /obj/structure/window/sandbag/rock, 3, _time = 70, _one_per_turf = TRUE, _on_floor = TRUE)
	if (current_res[1] >= 26)
		recipes += new/datum/stack_recipe("furnace", /obj/structure/furnace/, 10, _time = 150, _one_per_turf = TRUE, _on_floor = TRUE)
	if (current_res[1] >= 21)
		recipes += new/datum/stack_recipe("well", /obj/structure/sink/well, 7, _time = 250, _one_per_turf = TRUE, _on_floor = TRUE)
	if (current_res[1] >= 24 && current_res[2] >= 33)
		recipes += new/datum/stack_recipe("catapult projectile", /obj/item/catapult_ball, 5, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("sling projectile (x5)", /obj/item/ammo_casing/stone, 1, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[1] >= 49)
		recipes += new/datum/stack_recipe("stone projectile (x2)", /obj/item/stack/ammopart/stoneball, 1, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE)

	if (current_res[1] >= 29)
		recipes += new/datum/stack_recipe_list("fortifications", list(
			new/datum/stack_recipe("fortified wall (horizontal)", /obj/structure/barricade/stone_h, 5, _time = 80, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("fortified wall (vertical)", /obj/structure/barricade/stone_v, 5, _time = 80, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("fortified crenelated wall (horizontal)", /obj/structure/barricade/stone_h/crenelated, 5, _time = 80, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("fortified crenelated wall (vertical)", /obj/structure/barricade/stone_v/crenelated, 5, _time = 80, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("stone shingled wall (vertical center)", /obj/structure/barricade/jap_v, 4, _time = 80, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("stone shingled wall (vertical top)", /obj/structure/barricade/jap_v_t, 4, _time = 80, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("stone shingled wall (vertical bottom)", /obj/structure/barricade/jap_v_b, 4, _time = 80, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("stone shingled wall (horizontal center)", /obj/structure/barricade/jap_h, 4, _time = 80, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("stone shingled wall (horizontal left)", /obj/structure/barricade/jap_h_l, 4, _time = 80, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("stone shingled wall (horizontal right)", /obj/structure/barricade/jap_h_r, 4, _time = 80, _one_per_turf = TRUE, _on_floor = TRUE),))

/material/tobacco/generate_recipes_civs(var/list/current_res = list(0,0,0))
	..()
	if (current_res[3] >= 23)
		recipes = list(new/datum/stack_recipe("cigar", /obj/item/clothing/mask/smokable/cigarette/cigar, 3, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE))
		recipes += list(new/datum/stack_recipe("cuban cigar", /obj/item/clothing/mask/smokable/cigarette/cigar/havana, 5, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE))
		recipes += list(new/datum/stack_recipe("cigarette", /obj/item/clothing/mask/smokable/cigarette, 2, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE))

/material/coca/generate_recipes_civs(var/list/current_res = list(0,0,0))
	..()
	if (current_res[3] >= 93)
		recipes = list(new/datum/stack_recipe("cocaine", /obj/item/weapon/reagent_containers/pill/cocaine, 10, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE))


/material/poppy/generate_recipes_civs(var/list/current_res = list(0,0,0))
	..()
	if (current_res[3] >= 29)
		recipes = list(new/datum/stack_recipe("opium", /obj/item/weapon/reagent_containers/pill/opium, 3, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE))

/material/bone/generate_recipes_civs(var/list/current_res = list(0,0,0))

	..()
	recipes = list(new/datum/stack_recipe("bone talisman", /obj/item/clothing/accessory/armband/talisman, 2, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE))
	recipes += list(new/datum/stack_recipe("skull mask", /obj/item/clothing/head/skullmask, 5, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE))
	recipes += list(new/datum/stack_recipe("bone knife", /obj/item/weapon/material/kitchen/utensil/knife/bone, 4, _time = 90, _one_per_turf = FALSE, _on_floor = TRUE))
	recipes += list(new/datum/stack_recipe("blowing horn", /obj/item/weapon/horn, 4, _time = 110, _one_per_turf = FALSE, _on_floor = TRUE))
	if (current_res[2] >= 12)
		recipes += list(new/datum/stack_recipe("bone armor", /obj/item/clothing/suit/storage/jacket/bonearmor, 10, _time = 170, _one_per_turf = FALSE, _on_floor = TRUE))
	recipes += list(new/datum/stack_recipe("bone hatchet", /obj/item/weapon/material/hatchet/tribal, 2, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]"))
	recipes += list(new/datum/stack_recipe("bone pickaxe", /obj/item/weapon/pickaxe/bone, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE))
	recipes += list(new/datum/stack_recipe("bone shovel", /obj/item/weapon/shovel/bone, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE))
	if (current_res[1] >= 15)
		recipes += list(new/datum/stack_recipe("dice", /obj/item/weapon/dice, 2, _time = 90, _one_per_turf = FALSE, _on_floor = TRUE))

/material/cloth/generate_recipes_civs(var/list/current_res = list(0,0,0))
	..()
	if (current_res[3] >= 22)
		recipes += list(new/datum/stack_recipe("small sail",/obj/item/sail, 15, _time = 125, _one_per_turf = FALSE, _on_floor = TRUE))
	if (current_res[3] >= 19)
		recipes += list(new/datum/stack_recipe("bandages", /obj/item/stack/medical/bruise_pack/bint, 1, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE))
		recipes += list(new/datum/stack_recipe("foldable canopy", /obj/item/weapon/tent, 4, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE))

	if (current_res[3] >= 56)
		recipes += list(new/datum/stack_recipe("trauma kit", /obj/item/stack/medical/advanced/bruise_pack, 2, _time = 105, _one_per_turf = FALSE, _on_floor = TRUE))
	if (current_res[3] >= 43)
		recipes += list(new/datum/stack_recipe("burn kit", /obj/item/stack/medical/advanced/ointment, 1, _time = 90, _one_per_turf = FALSE, _on_floor = TRUE))
	if (current_res[3] >= 130)
		recipes += list(new/datum/stack_recipe("custom camo uniform", 	/obj/item/clothing/under/customuniform_modern, 4, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE))

	if ((current_res[3] >= 18) && (current_res[3] < 38))
		recipes += new/datum/stack_recipe_list("hats & masks", list(
			new/datum/stack_recipe("mayan headdress", /obj/item/clothing/head/mayan_headdress, 4, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("nemes headdress", /obj/item/clothing/head/nemes, 6, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("double crown", /obj/item/clothing/head/doublecrown, 5, _time = 65, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("eyepatch", /obj/item/clothing/mask/glasses/eyepatch, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("blindfold", /obj/item/clothing/mask/glasses/sunglasses/blindfold, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("straw hat", /obj/item/clothing/head/strawhat, 3, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("red beret", /obj/item/clothing/head/red_beret, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("colored turban", /obj/item/clothing/head/turban, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("white turban", /obj/item/clothing/head/turban/imam, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("shemagh", /obj/item/clothing/mask/shemagh, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("blue beret", /obj/item/clothing/head/blue_beret, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),))
	if ((current_res[3] >= 38) && (current_res[3] < 52))
		recipes += new/datum/stack_recipe_list("hats & masks", list(
			new/datum/stack_recipe("mayan headdress", /obj/item/clothing/head/mayan_headdress, 4, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("eyepatch", /obj/item/clothing/mask/glasses/eyepatch, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("blindfold", /obj/item/clothing/mask/glasses/sunglasses/blindfold, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("straw hat", /obj/item/clothing/head/strawhat, 3, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("red beret", /obj/item/clothing/head/red_beret, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("colored turban", /obj/item/clothing/head/turban, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("white turban", /obj/item/clothing/head/turban/imam, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("shemagh", /obj/item/clothing/mask/shemagh, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("blue beret", /obj/item/clothing/head/blue_beret, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("kerchief", /obj/item/clothing/head/kerchief, 2, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),))
	if (current_res[3] >= 52 && (current_res[3] < 98))
		recipes += new/datum/stack_recipe_list("hats & masks", list(
			new/datum/stack_recipe("eyepatch", /obj/item/clothing/mask/glasses/eyepatch, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("blindfold", /obj/item/clothing/mask/glasses/sunglasses/blindfold, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("straw hat", /obj/item/clothing/head/strawhat, 3, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("red beret", /obj/item/clothing/head/red_beret, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("blue beret", /obj/item/clothing/head/blue_beret, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("colored turban", /obj/item/clothing/head/turban, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("white turban", /obj/item/clothing/head/turban/imam, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("shemagh", /obj/item/clothing/mask/shemagh, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("kerchief", /obj/item/clothing/head/kerchief, 2, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("black bicorne", /obj/item/clothing/head/bicorne_british_soldier, 2, _time = 95, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("black tricorne", /obj/item/clothing/head/tricorne_black, 3, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("tarred hat", /obj/item/clothing/head/tarred_hat, 3, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("rice hat", /obj/item/clothing/head/rice_hat, 3, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("bandana", /obj/item/clothing/head/piratebandana1, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("artisan hat", /obj/item/clothing/head/artisan, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("feathered hat", /obj/item/clothing/head/feathered_hat, 3, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),))
	if (current_res[3] >= 98 && (current_res[3] < 109))
		recipes += new/datum/stack_recipe_list("hats & masks", list(
			new/datum/stack_recipe("eyepatch", /obj/item/clothing/mask/glasses/eyepatch, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("blindfold", /obj/item/clothing/mask/glasses/sunglasses/blindfold, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("straw hat", /obj/item/clothing/head/strawhat, 3, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("cowboy hat", /obj/item/clothing/head/cowboyhat, 3, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("dark cowboy hat", /obj/item/clothing/head/cowboyhat2, 3, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("shemagh", /obj/item/clothing/mask/shemagh, 3, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("kerchief", /obj/item/clothing/head/kerchief, 2, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("tarred hat", /obj/item/clothing/head/tarred_hat, 3, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("bowler hat", /obj/item/clothing/head/bowler_hat, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("rice hat", /obj/item/clothing/head/rice_hat, 3, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("sombrero", /obj/item/clothing/head/sombrero, 4, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("red kerchief", /obj/item/clothing/mask/shemagh/redkerchief, 2, _time = 45, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("grey kerchief", /obj/item/clothing/mask/shemagh/greykerchief, 2, _time = 45, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("dark union hat", /obj/item/clothing/head/unionhat, 3, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("light union hat", /obj/item/clothing/head/unionhatlight, 3, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("grey confederate hat", /obj/item/clothing/head/confederatehat, 3, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("confederate cap", /obj/item/clothing/head/confederatecap, 3, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("union cap", /obj/item/clothing/head/unioncap, 3, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),))
	if (current_res[3] >= 109)
		recipes += new/datum/stack_recipe_list("hats & masks", list(
			new/datum/stack_recipe("eyepatch", /obj/item/clothing/mask/glasses/eyepatch, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("blindfold", /obj/item/clothing/mask/glasses/sunglasses/blindfold, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("straw hat", /obj/item/clothing/head/strawhat, 3, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("cowboy hat", /obj/item/clothing/head/cowboyhat, 3, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("dark cowboy hat", /obj/item/clothing/head/cowboyhat2, 3, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("shemagh", /obj/item/clothing/mask/shemagh, 3, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("kerchief", /obj/item/clothing/head/kerchief, 2, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("bowler hat", /obj/item/clothing/head/bowler_hat, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("rice hat", /obj/item/clothing/head/rice_hat, 3, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("red kerchief", /obj/item/clothing/mask/shemagh/redkerchief, 2, _time = 45, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("grey kerchief", /obj/item/clothing/mask/shemagh/greykerchief, 2, _time = 45, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("tophat", /obj/item/clothing/head/top_hat, 5, _time = 95, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("brown flatcap", /obj/item/clothing/head/flatcap1, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("blue flatcap", /obj/item/clothing/head/flatcap2, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("grey flatcap", /obj/item/clothing/head/flatcap3, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("custom officer cap", /obj/item/clothing/head/custom_off_cap, 4, _time = 95, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("custom field cap", /obj/item/clothing/head/custom/fieldcap, 3, _time = 70, _one_per_turf = FALSE, _on_floor = TRUE),
			))
	if ( current_res[3] < 15)
		recipes += new/datum/stack_recipe_list("clothing", list(
			new/datum/stack_recipe("cotton loincloth", /obj/item/clothing/under/loincotton, 2, _time = 45, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("mayan loincloth", /obj/item/clothing/under/mayan_loincloth, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),))

	if ((current_res[3] >= 15) && (current_res[3] < 38))
		recipes += new/datum/stack_recipe_list("clothing", list(
			new/datum/stack_recipe("fancy shendyt", /obj/item/clothing/under/pharaoh, 8, _time = 145, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("great shendyt", /obj/item/clothing/under/pharaoh2, 10, _time = 185, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("mayan loincloth", /obj/item/clothing/under/mayan_loincloth, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("huipil", /obj/item/clothing/under/huipil, 3, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("half huipil", /obj/item/clothing/under/halfhuipil, 2, _time = 45, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("customizable tunic", /obj/item/clothing/under/custom/roman, 4, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("customizable toga", /obj/item/clothing/under/custom/toga, 3, _time = 65, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("customizable shendyt", /obj/item/clothing/under/custom/shendyt, 2, _time = 45, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("customizable celtic trousers", /obj/item/clothing/under/custom/celtic, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("light hanfu", /obj/item/clothing/under/hanfu/light, 3, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("dark hanfu", /obj/item/clothing/under/hanfu, 3, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("green hanfu", /obj/item/clothing/under/hanfu/green, 3, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("linothorax armor", /obj/item/clothing/suit/armor/ancient/linen, 8, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),))

	if ((current_res[3] >= 38) && (current_res[3] < 59))
		recipes += new/datum/stack_recipe_list("clothing", list(
			new/datum/stack_recipe("huipil", /obj/item/clothing/under/huipil, 3, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("half huipil", /obj/item/clothing/under/halfhuipil, 2, _time = 45, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("customizable dress", /obj/item/clothing/under/customdress, 4, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("customizable buttoned dress", /obj/item/clothing/under/customdress2, 4, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("customizable tunic", /obj/item/clothing/under/custom/tunic, 4, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("customizable arabic tunic", /obj/item/clothing/under/custom/arabictunic, 4, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("light brown arabic tunic", /obj/item/clothing/under/medieval/arab1, 3, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("light white arabic tunic", /obj/item/clothing/under/medieval/arab2, 3, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("light hanfu", /obj/item/clothing/under/hanfu/light, 3, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("dark hanfu", /obj/item/clothing/under/hanfu, 3, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("green hanfu", /obj/item/clothing/under/hanfu/green, 3, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("artisan clothing", /obj/item/clothing/under/artisan, 3, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("dark artisan clothing", /obj/item/clothing/under/artisan/dark, 3, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("light artisan clothing", /obj/item/clothing/under/artisan/light, 3, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("linothorax armor", /obj/item/clothing/suit/armor/ancient/linen, 8, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),))

	if ((current_res[3] >= 59) && (current_res[3] < 79))
		recipes += new/datum/stack_recipe_list("clothing", list(
			new/datum/stack_recipe("huipil", /obj/item/clothing/under/huipil, 3, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("half huipil", /obj/item/clothing/under/halfhuipil, 2, _time = 45, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("customizable buttoned dress", /obj/item/clothing/under/customdress2, 4, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("customizable dress", /obj/item/clothing/under/customdress, 4, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("customizable tunic", /obj/item/clothing/under/custom/tunic, 4, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("customizable arabic tunic", /obj/item/clothing/under/custom/arabictunic, 4, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("light brown arabic tunic", /obj/item/clothing/under/medieval/arab1, 3, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("light white arabic tunic", /obj/item/clothing/under/medieval/arab2, 3, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("customizable renaissance clothing", /obj/item/clothing/under/customren, 6, _time = 105, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("baggy renaissance clothing", /obj/item/clothing/under/renaissance, 6, _time = 105, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("pontifical renaissance clothing", /obj/item/clothing/under/renaissance_pontifical, 6, _time = 105, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("light hanfu", /obj/item/clothing/under/hanfu/light, 3, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("dark hanfu", /obj/item/clothing/under/hanfu, 3, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("green hanfu", /obj/item/clothing/under/hanfu/green, 3, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("artisan clothing", /obj/item/clothing/under/artisan, 3, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("dark artisan clothing", /obj/item/clothing/under/artisan/dark, 3, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("light artisan clothing", /obj/item/clothing/under/artisan/light, 3, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),))
	if (current_res[3] >= 79 && current_res[3] < 98)
		recipes += new/datum/stack_recipe_list("clothing", list(
				new/datum/stack_recipe("customizable dress", /obj/item/clothing/under/customdress, 4, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),
				new/datum/stack_recipe("customizable buttoned dress", /obj/item/clothing/under/customdress2, 4, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),
				new/datum/stack_recipe("blue colonial clothing", /obj/item/clothing/under/civ1, 3, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
				new/datum/stack_recipe("white colonial clothing", /obj/item/clothing/under/civ2, 3, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
				new/datum/stack_recipe("short-sleeved colonial clothing", /obj/item/clothing/under/civ3, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
				new/datum/stack_recipe("fancy colonial clothing", /obj/item/clothing/under/civ4, 5, _time = 105, _one_per_turf = FALSE, _on_floor = TRUE),
				new/datum/stack_recipe("green colonial clothing", /obj/item/clothing/under/civ5, 3, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
				new/datum/stack_recipe("pink colonial clothing", /obj/item/clothing/under/civ6, 3, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
				new/datum/stack_recipe("black stripes clothing", /obj/item/clothing/under/pirate1, 3, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
				new/datum/stack_recipe("red stripes clothing", /obj/item/clothing/under/pirate2, 3, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
				new/datum/stack_recipe("blue stripes clothing", /obj/item/clothing/under/pirate3, 3, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
				new/datum/stack_recipe("light hanfu", /obj/item/clothing/under/hanfu/light, 3, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),
				new/datum/stack_recipe("dark hanfu", /obj/item/clothing/under/hanfu, 3, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),
				new/datum/stack_recipe("green hanfu", /obj/item/clothing/under/hanfu/green, 3, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),
				new/datum/stack_recipe("artisan clothing", /obj/item/clothing/under/artisan, 3, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),
				new/datum/stack_recipe("dark artisan clothing", /obj/item/clothing/under/artisan/dark, 3, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),
				new/datum/stack_recipe("light artisan clothing", /obj/item/clothing/under/artisan/light, 3, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),))
	if (current_res[3] >= 98 && current_res[3] < 112)
		recipes += new/datum/stack_recipe_list("clothing", list(
			new/datum/stack_recipe("customizable dress", /obj/item/clothing/under/customdress, 4, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("customizable buttoned dress", /obj/item/clothing/under/customdress2, 4, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("pioneer outfit", /obj/item/clothing/under/industrial1, 3, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("rancher outfit", /obj/item/clothing/under/industrial2, 3, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("cowboy outfit", /obj/item/clothing/under/industrial3, 3, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("checkered outfit", /obj/item/clothing/under/industrial4, 3, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("worker outfit", /obj/item/clothing/under/industrial5, 3, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("custom uniform", /obj/item/clothing/under/customuniform, 3, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("light hanfu", /obj/item/clothing/under/hanfu/light, 3, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("dark hanfu", /obj/item/clothing/under/hanfu, 3, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("green hanfu", /obj/item/clothing/under/hanfu/green, 3, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("artisan clothing", /obj/item/clothing/under/artisan, 3, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("dark artisan clothing", /obj/item/clothing/under/artisan/dark, 3, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("customizable buttoned dress", /obj/item/clothing/under/customdress2, 4, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("light artisan clothing", /obj/item/clothing/under/artisan/light, 3, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),))
	if (current_res[3] >= 112)
		recipes += new/datum/stack_recipe_list("clothing", list(
			new/datum/stack_recipe("customizable dress", /obj/item/clothing/under/customdress, 4, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("light brown outfit", /obj/item/clothing/under/modern1, 4, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("black outfit", /obj/item/clothing/under/modern2, 4, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("grey outfit", /obj/item/clothing/under/modern3, 4, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("brown outfit", /obj/item/clothing/under/modern4, 4, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("farmer outfit", /obj/item/clothing/under/farmer_outfit, 4, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("mechanic outfit", /obj/item/clothing/under/mechanic_outfit, 4, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("custom uniform", /obj/item/clothing/under/customuniform, 3, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("light hanfu", /obj/item/clothing/under/hanfu/light, 3, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("dark hanfu", /obj/item/clothing/under/hanfu, 3, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("green hanfu", /obj/item/clothing/under/hanfu/green, 3, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("artisan clothing", /obj/item/clothing/under/artisan, 3, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("dark artisan clothing", /obj/item/clothing/under/artisan/dark, 3, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("light artisan clothing", /obj/item/clothing/under/artisan/light, 3, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),))
	if (current_res[3] >= 57 && current_res[3] < 89 )
		recipes += new/datum/stack_recipe_list("jackets & vests", list(
			new/datum/stack_recipe("black jacket", /obj/item/clothing/suit/storage/jacket/piratejacket1, 6, _time = 110, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("fancy brown jacket", /obj/item/clothing/suit/storage/jacket/piratejacket2, 10, _time = 180, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("fancy red jacket", /obj/item/clothing/suit/storage/jacket/piratejacket5, 10, _time = 180, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("blue vest", /obj/item/clothing/suit/storage/jacket/piratejacket3, 4, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("black vest", /obj/item/clothing/suit/storage/jacket/piratejacket4, 4, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),))
	if (current_res[3] >= 89 && current_res[3] < 112 )
		recipes += new/datum/stack_recipe_list("jackets & vests", list(
			new/datum/stack_recipe("leather overcoat", /obj/item/clothing/suit/storage/jacket/leatherovercoat1, 6, _time = 120, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("black leather overcoat", /obj/item/clothing/suit/storage/jacket/leatherovercoat2, 6, _time = 120, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("black vest", /obj/item/clothing/suit/storage/jacket/blackvest, 4, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("blue vest", /obj/item/clothing/suit/storage/jacket/bluevest, 4, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("olive vest", /obj/item/clothing/suit/storage/jacket/olivevest, 4, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("brown winter coat", /obj/item/clothing/suit/storage/coat/japcoat2/brown, 10, _time = 200, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("grey winter coat", /obj/item/clothing/suit/storage/coat/ruscoat/grey, 10, _time = 200, _one_per_turf = FALSE, _on_floor = TRUE),))
	if (current_res[3] >= 112)
		recipes += new/datum/stack_recipe_list("jackets & vests", list(
			new/datum/stack_recipe("black vest", /obj/item/clothing/suit/storage/jacket/blackvest, 4, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("blue vest", /obj/item/clothing/suit/storage/jacket/bluevest, 4, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("olive vest", /obj/item/clothing/suit/storage/jacket/olivevest, 4, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("charcoal suit", /obj/item/clothing/suit/storage/jacket/charcoal_suit, 15, _time = 200, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("black suit", /obj/item/clothing/suit/storage/jacket/black_suit, 15, _time = 200, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("dark black suit", /obj/item/clothing/suit/storage/jacket/really_black_suit, 15, _time = 200, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("burgundy suit", /obj/item/clothing/suit/storage/jacket/burgundy_suit, 15, _time = 200, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("checkered suit", /obj/item/clothing/suit/storage/jacket/checkered_suit, 15, _time = 200, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("navy suit", /obj/item/clothing/suit/storage/jacket/navy_suit, 15, _time = 200, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("brown winter coat", /obj/item/clothing/suit/storage/coat/japcoat2/brown, 10, _time = 200, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("grey winter coat", /obj/item/clothing/suit/storage/coat/ruscoat/grey, 10, _time = 200, _one_per_turf = FALSE, _on_floor = TRUE),))
	if (current_res[3] < 38)
		recipes += new/datum/stack_recipe_list("accessories", list(
			new/datum/stack_recipe("customizable armband", /obj/item/clothing/accessory/custom/armband, 1, _time = 30, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("customizable sash", /obj/item/clothing/accessory/custom/sash, 1, _time = 30, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("customizable cape", /obj/item/clothing/accessory/custom/cape, 2, _time = 30, _one_per_turf = FALSE, _on_floor = TRUE),))
	else if (current_res[3] >= 38 && current_res[3] < 70 )
		recipes += new/datum/stack_recipe_list("accessories", list(
			new/datum/stack_recipe("customizable armband", /obj/item/clothing/accessory/custom/armband, 1, _time = 30, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("customizable sash", /obj/item/clothing/accessory/custom/sash, 1, _time = 30, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("customizable cape", /obj/item/clothing/accessory/custom/cape, 2, _time = 30, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("customizable tabard", /obj/item/clothing/accessory/custom/tabard, 2, _time = 30, _one_per_turf = FALSE, _on_floor = TRUE),))
	else if (current_res[3] >= 70 && current_res[3] < 95 )
		recipes += new/datum/stack_recipe_list("accessories", list(
			new/datum/stack_recipe("customizable scarf", /obj/item/clothing/accessory/custom/scarf, 2, _time = 30, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("customizable armband", /obj/item/clothing/accessory/custom/armband, 1, _time = 30, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("customizable sash", /obj/item/clothing/accessory/custom/sash, 1, _time = 30, _one_per_turf = FALSE, _on_floor = TRUE),))
	else if (current_res[3] >= 95 )
		recipes += new/datum/stack_recipe_list("accessories", list(
			new/datum/stack_recipe("customizable scarf", /obj/item/clothing/accessory/custom/scarf, 2, _time = 30, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("customizable armband", /obj/item/clothing/accessory/custom/armband, 1, _time = 30, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("customizable sash", /obj/item/clothing/accessory/custom/sash, 1, _time = 30, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("customizable tie", /obj/item/clothing/accessory/custom/tie, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("customizable bowtie", /obj/item/clothing/accessory/custom/bowtie, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),))
	if (current_res[3] >= 28)
		recipes += new/datum/stack_recipe_list("bedsheets", list(
			new/datum/stack_recipe("white bedsheet", /obj/item/weapon/bedsheet, 2, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("medical bedsheet", /obj/item/weapon/bedsheet/medical, 2, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("brown bedsheet", /obj/item/weapon/bedsheet/brown, 2, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("blue bedsheet", /obj/item/weapon/bedsheet/blue, 2, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("yellow bedsheet", /obj/item/weapon/bedsheet/blue, 2, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("red bedsheet", /obj/item/weapon/bedsheet/red, 2, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),))

		recipes += new/datum/stack_recipe_list("banners & flags", list(
			new/datum/stack_recipe("custom flag maker", /obj/item/flagmaker, 4, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("faction banner (square)",/obj/structure/banner/faction/banner_a, 3, _time = 65, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("faction banner (gonfalon)",/obj/structure/banner/faction/banner_b, 3, _time = 65, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("religious banner",/obj/structure/banner/religious, 3, _time = 65, _one_per_turf = TRUE, _on_floor = TRUE),))

	if (current_res[1] >= 18 && current_res[3]>= 26) // Same level that bronze surgical tools can be made.
		recipes += list(new/datum/stack_recipe("surgery kit", /obj/item/weapon/storage/firstaid/surgery_empty, 6, _time = 90, _one_per_turf = FALSE, _on_floor = TRUE))
		recipes += list(new/datum/stack_recipe("cigarette pack", /obj/item/weapon/storage/fancy/cigarettes, 1, _time = 20, _one_per_turf = FALSE, _on_floor = TRUE))

	//Carpets - To be expanded upon with borders and such later.
	if (map.ordinal_age >= 2)
		recipes += new/datum/stack_recipe_list("carpeting", list(
			new/datum/stack_recipe("pink carpet", /obj/covers/carpet/pinkcarpet, 1, _time = 20, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("red carpet", /obj/covers/carpet/redcarpet, 1, _time = 20, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("orange carpet", /obj/covers/carpet/orangecarpet, 1, _time = 20, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("purple carpet", /obj/covers/carpet/purplecarpet, 1, _time = 20, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("blue carpet", /obj/covers/carpet/bluecarpet, 1, _time = 20, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("teal carpet", /obj/covers/carpet/tealcarpet, 1, _time = 20, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("green carpet", /obj/covers/carpet/greencarpet, 1, _time = 20, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("black carpet", /obj/covers/carpet/blackcarpet, 1, _time = 20, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("white carpet", /obj/covers/carpet/whitecarpet, 1, _time = 20, _one_per_turf = FALSE, _on_floor = TRUE),))

/material/gold/generate_recipes_civs(var/list/current_res = list(0,0,0))
	..()
	if (current_res[1] >= 17 && current_res[2] >= 16)
		recipes += new/datum/stack_recipe("[display_name] hatchet", /obj/item/weapon/material/hatchet, 2, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
		recipes += new/datum/stack_recipe("[display_name]-tipped spear", /obj/item/weapon/material/spear, 1, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
	recipes += new/datum/stack_recipe("gold coins", /obj/item/stack/money/goldcoin, 1, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("gold crown", /obj/item/clothing/head/helmet/gold_crown, 3, _time = 135, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("gold arm bangles", /obj/item/clothing/accessory/armband/armbangle/gold, 2, _time = 95, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("gold sceptre",  /obj/item/weapon/goldsceptre, 3, _time = 105, _one_per_turf = FALSE, _on_floor = TRUE)

/material/silver/generate_recipes_civs(var/list/current_res = list(0,0,0))
	..()
	if (current_res[1] >= 17 && current_res[2] >= 16)
		recipes += new/datum/stack_recipe("[display_name] hatchet", /obj/item/weapon/material/hatchet, 2, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
		recipes += new/datum/stack_recipe("[display_name]-tipped spear", /obj/item/weapon/material/spear, 1, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
	recipes += new/datum/stack_recipe("silver coins", /obj/item/stack/money/silvercoin, 1, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("silver crown", /obj/item/clothing/head/helmet/silver_crown, 3, _time = 135, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("silver arm bangles", /obj/item/clothing/accessory/armband/armbangle/silver, 2, _time = 95, _one_per_turf = FALSE, _on_floor = TRUE)
/material/diamond/generate_recipes_civs(var/list/current_res = list(0,0,0))
	..()

/material/copper/generate_recipes_civs(var/list/current_res = list(0,0,0))
	..()
	if (map.ordinal_age >= 4)
		recipes += new/datum/stack_recipe("telegraph",/obj/structure/telegraph, 12, _time = 90, _one_per_turf = TRUE, _on_floor = TRUE)
	if (map.ordinal_age >= 5)
		recipes += new/datum/stack_recipe("electronic circuits",/obj/item/stack/material/electronics, 1, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[1] >= 8 && current_res[2] >= 8)
		recipes += new/datum/stack_recipe("[display_name] hatchet", /obj/item/weapon/material/hatchet, 2, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
		recipes += new/datum/stack_recipe("[display_name]-tipped spear", /obj/item/weapon/material/spear, 1, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
		recipes += new/datum/stack_recipe("copper coins", /obj/item/stack/money/coppercoin, 1, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE)

	if (current_res[1] >= 18 && current_res[2] >= 34)
		recipes += new/datum/stack_recipe("[display_name] small sword", /obj/item/weapon/material/sword/smallsword/copper, 10, _time = 70, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
	if (current_res[1] >= 18 && current_res[2] >= 42)
		recipes += new/datum/stack_recipe("[display_name] spadroon", /obj/item/weapon/material/sword/spadroon/copper, 15, _time = 115, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
	recipes += new/datum/stack_recipe("copper lamp", /obj/item/flashlight/lantern/copper, 3, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("small copper pot", /obj/item/weapon/reagent_containers/glass/small_pot/copper_small, 3, _time = 90, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("large copper pot", /obj/item/weapon/reagent_containers/glass/small_pot/copper_large, 5, _time = 120, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("copper arm bangles", /obj/item/clothing/accessory/armband/armbangle/copper, 2, _time = 95, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[1] >= 83)
		recipes += new/datum/stack_recipe("trombone",/obj/item/trombone, 6, _time = 155, _one_per_turf = FALSE, _on_floor = TRUE)


	if (map.ordinal_age >= 4)
		recipes += new/datum/stack_recipe("rifle casing (x3)", /obj/item/stack/ammopart/casing/rifle, 1, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("pistol casing (x3)", /obj/item/stack/ammopart/casing/pistol, 1, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("artillery casing", /obj/item/stack/ammopart/casing/artillery, 2, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("ammo clip", /obj/item/ammo_magazine/emptyclip, 1, _time = 30, _one_per_turf = FALSE, _on_floor = TRUE)

	if (map.ordinal_age >= 4)
		recipes += new/datum/stack_recipe_list("cables", list(
			new/datum/stack_recipe("cable connector", /obj/item/connector, 1, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("white cable coil (10m)", /obj/item/stack/cable_coil/white, 1, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("red cable coil (10m)", /obj/item/stack/cable_coil/red, 1, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("blue cable coil (10m)", /obj/item/stack/cable_coil/blue, 1, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("yellow cable coil (10m)", /obj/item/stack/cable_coil/yellow, 1, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("green cable coil (10m)", /obj/item/stack/cable_coil/green, 1, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("orange cable coil (10m)", /obj/item/stack/cable_coil/orange, 1, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("cyan cable coil (10m)", /obj/item/stack/cable_coil/cyan, 1, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("pink cable coil (10m)", /obj/item/stack/cable_coil/pink, 1, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE),))
/material/bronze/generate_recipes_civs(var/list/current_res = list(0,0,0))
	..()
	if (current_res[1] >= 21 && current_res[2] >= 16)
		recipes += new/datum/stack_recipe("[display_name] hatchet", /obj/item/weapon/material/hatchet, 2, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
		recipes += new/datum/stack_recipe("[display_name]-tipped spear", /obj/item/weapon/material/spear, 1, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
		recipes += new/datum/stack_recipe("bronze shield", /obj/item/weapon/shield/bronze, 4, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("aspis shield", /obj/item/weapon/shield/aspis, 5, _time = 95, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("roman shield", /obj/item/weapon/shield/roman, 6, _time = 105, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[1] >= 27 && current_res[2] >= 34)
		recipes += new/datum/stack_recipe("[display_name] small sword", /obj/item/weapon/material/sword/smallsword/bronze, 10, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
	if (current_res[1] >= 27 && current_res[2] >= 42)
		recipes += new/datum/stack_recipe("[display_name] spadroon", /obj/item/weapon/material/sword/spadroon/bronze, 15, _time = 125, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
	if (current_res[1] >= 34 && current_res[2] >= 21)
		recipes += new/datum/stack_recipe("bronze chestplate", /obj/item/clothing/suit/armor/medieval/bronze_chestplate, 6, _time = 165, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
	if (current_res[1] >= 18 && current_res[3]>= 26)
		recipes += new/datum/stack_recipe_list("bronze medical tools", list(
			new/datum/stack_recipe("bronze retractor", /obj/item/weapon/surgery/retractor/bronze, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("bronze hemostat", /obj/item/weapon/surgery/hemostat/bronze, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("bronze cautery",/obj/item/weapon/surgery/cautery/bronze, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("bronze bone saw",/obj/item/weapon/surgery/bone_saw/bronze, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("bronze bone setter",/obj/item/weapon/surgery/bonesetter/bronze, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("bronze scalpel", /obj/item/weapon/surgery/scalpel/bronze, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),))
	recipes += new/datum/stack_recipe("bronze etsy lamp", /obj/item/flashlight/lantern/bronze, 4, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("bronze arm bangles", /obj/item/clothing/accessory/armband/armbangle/bronze, 2, _time = 95, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("razor blade", /obj/item/weapon/material/kitchen/utensil/knife/razorblade, 2, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")

/material/steel/generate_recipes_civs(var/list/current_res = list(0,0,0))
	..()
	if (current_res[1] >= 50 && current_res[2] >= 44)
		recipes += new/datum/stack_recipe("[display_name] hatchet", /obj/item/weapon/material/hatchet, 2, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
		recipes += new/datum/stack_recipe("[display_name]-tipped spear", /obj/item/weapon/material/spear, 1, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
		recipes += new/datum/stack_recipe("steel shield", /obj/item/weapon/shield/steel, 4, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[1] >= 71 && current_res[2] >= 79)
		recipes += new/datum/stack_recipe("cannon", /obj/structure/cannon, 35, _time = 600, _one_per_turf = TRUE, _on_floor = TRUE)
	if (current_res[1] >= 95 && current_res[2] >= 109)
		recipes += new/datum/stack_recipe("artillery cannon", /obj/structure/cannon/modern, 40, _time = 600, _one_per_turf = TRUE, _on_floor = TRUE)
	if (map.ordinal_age >= 4)
		recipes += new/datum/stack_recipe("petroleum refinery",/obj/structure/refinery, 22, _time = 230, _one_per_turf = TRUE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("steam engine",/obj/structure/engine/external/steam, 15, _time = 250, _one_per_turf = TRUE, _on_floor = TRUE)

	if (map.ordinal_age >= 5)
		recipes += new/datum/stack_recipe("steel barrel",/obj/item/weapon/reagent_containers/glass/barrel/modern, 1, _time = 75, _one_per_turf = TRUE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("fuel pump (star)",/obj/structure/fuelpump/star, 15, _time = 120, _one_per_turf = TRUE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("fuel pump (small)",/obj/structure/fuelpump/small, 15, _time = 120, _one_per_turf = TRUE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("fuel pump (N)",/obj/structure/fuelpump/n, 15, _time = 120, _one_per_turf = TRUE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("fuel pump (S)",/obj/structure/fuelpump/s, 15, _time = 120, _one_per_turf = TRUE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe_list("vehicle parts", list(
			new/datum/stack_recipe("motorcycle frame", /obj/item/vehicleparts/frame/bike, 12, _time = 200, _one_per_turf = FALSE, _on_floor = TRUE),))
		recipes += new/datum/stack_recipe_list("fuel tanks", list(
			new/datum/stack_recipe("25u bike fuel tank", /obj/item/weapon/reagent_containers/glass/barrel/fueltank/bike25, 2, _time = 45, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("50u bike fuel tank", /obj/item/weapon/reagent_containers/glass/barrel/fueltank/bike, 4, _time = 65, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("75u bike fuel tank", /obj/item/weapon/reagent_containers/glass/barrel/fueltank/bike75, 6, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("120u small fuel tank", /obj/item/weapon/reagent_containers/glass/barrel/fueltank/small, 10, _time = 125, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("250u large fuel tank", /obj/item/weapon/reagent_containers/glass/barrel/fueltank, 20, _time = 185, _one_per_turf = FALSE, _on_floor = TRUE),))

		recipes += new/datum/stack_recipe_list("electrical", list(
			new/datum/stack_recipe("street lamp", /obj/structure/lamp/lamppost_small, 3, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE),))

/material/tin/generate_recipes_civs(var/list/current_res = list(0,0,0))
	..()
	recipes += new/datum/stack_recipe("small tin pot", /obj/item/weapon/reagent_containers/glass/small_pot, 3, _time = 120, _one_per_turf = FALSE, _on_floor = TRUE)

/material/bearpelt/brown/generate_recipes_civs(var/list/current_res = list(0,0,0))
	..()
	recipes += new/datum/stack_recipe("fur coat", /obj/item/clothing/suit/storage/coat/fur/brown, 6, _time = 150, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("fur boots", /obj/item/clothing/shoes/fur/brown, 3, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("fur gloves", /obj/item/clothing/gloves/thick/leather/brown, 3, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("bear pelt headcover", /obj/item/clothing/head/bearpelt/brown, 4, _time = 150, _one_per_turf = FALSE, _on_floor = TRUE)

/material/bearpelt/white/generate_recipes_civs(var/list/current_res = list(0,0,0))
	..()
	recipes += new/datum/stack_recipe("fur coat", /obj/item/clothing/suit/storage/coat/fur/white, 6, _time = 150, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("fur boots", /obj/item/clothing/shoes/fur/white, 3, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("fur gloves", /obj/item/clothing/gloves/thick/leather/white, 3, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("bear pelt headcover", /obj/item/clothing/head/bearpelt/white, 4, _time = 150, _one_per_turf = FALSE, _on_floor = TRUE)

/material/bearpelt/black/generate_recipes_civs(var/list/current_res = list(0,0,0))
	..()
	recipes += new/datum/stack_recipe("fur coat", /obj/item/clothing/suit/storage/coat/fur/black, 6, _time = 150, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("fur boots", /obj/item/clothing/shoes/fur/black, 3, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("fur gloves", /obj/item/clothing/gloves/thick/leather/black, 3, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("bear pelt headcover", /obj/item/clothing/head/bearpelt/black, 4, _time = 150, _one_per_turf = FALSE, _on_floor = TRUE)



/material/wolfpelt/generate_recipes_civs(var/list/current_res = list(0,0,0))
	..()
	recipes += new/datum/stack_recipe("fur coat", /obj/item/clothing/suit/storage/coat/fur/grey, 6, _time = 150, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("fur boots", /obj/item/clothing/shoes/fur/grey, 3, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("fur gloves", /obj/item/clothing/gloves/thick/leather/grey, 3, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("wolf pelt headcover", /obj/item/clothing/head/wolfpelt, 4, _time = 150, _one_per_turf = FALSE, _on_floor = TRUE)

/material/catpelt/generate_recipes_civs(var/list/current_res = list(0,0,0))
	..()
	recipes += new/datum/stack_recipe("fur coat", /obj/item/clothing/suit/storage/coat/fur, 6, _time = 150, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("fur boots", /obj/item/clothing/shoes/fur, 3, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("fur gloves", /obj/item/clothing/gloves/thick/leather, 3, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE)

/material/monkeypelt/generate_recipes_civs(var/list/current_res = list(0,0,0))
	..()
	recipes += new/datum/stack_recipe("fur coat", /obj/item/clothing/suit/storage/coat/fur/brown, 6, _time = 150, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("fur boots", /obj/item/clothing/shoes/fur/brown, 3, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("fur gloves", /obj/item/clothing/gloves/thick/leather/brown, 3, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE)

/material/humanpelt/generate_recipes_civs(var/list/current_res = list(0,0,0))
	..()
	recipes += new/datum/stack_recipe("skin coat", /obj/item/clothing/suit/storage/coat/fur/pink, 6, _time = 150, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("skin boots", /obj/item/clothing/shoes/fur/pink, 3, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("skin gloves", /obj/item/clothing/gloves/thick/leather/pink, 3, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE)

/material/electronics/generate_recipes_civs(var/list/current_res = list(0,0,0))
	..()
	recipes += new/datum/stack_recipe("radio transmitter", /obj/structure/radio/transmitter, 12, _time = 150, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("radio receiver", /obj/structure/radio, 3, _time = 80, _one_per_turf = TRUE, _on_floor = TRUE)
//	recipes += new/datum/stack_recipe("two-way radio", /obj/structure/radio/transmitter_receiver, 10, _time = 120, _one_per_turf = TRUE, _on_floor = TRUE)
