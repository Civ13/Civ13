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
	recipes += new/datum/stack_recipe("unfired clay bricks", /obj/item/weapon/clay/claybricks, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("unfired clay bowl", /obj/item/weapon/clay/claybowl, 1, _time = 30, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("unfired clay jug", /obj/item/weapon/clay/clayjug, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("unfired clay cup", /obj/item/weapon/clay/claycup, 1, _time = 30, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("unfired very small clay pot", /obj/item/weapon/clay/verysmallclaypot, 1, _time = 20, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("unfired small clay pot", /obj/item/weapon/clay/smallclaypot, 1, _time = 30, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("unfired medium clay pot", /obj/item/weapon/clay/claypot, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("unfired large clay pot", /obj/item/weapon/clay/bigclaypot, 3, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("unfired clay pitcher", /obj/item/weapon/clay/claypitcher, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("unfired large clay pitcher", /obj/item/weapon/clay/largeclaypitcher, 3, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE)

/material/leather/generate_recipes_civs(var/list/current_res = list(0,0,0))
	..()
	if (current_res[1] >= 25 && current_res[3] >= 25)
		recipes += new/datum/stack_recipe("comfy chair", /obj/structure/bed/chair/comfy/brown, 6, _time = 100, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("bug swatter", /obj/item/weapon/swatter, 3, _time = 90, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("quiver", /obj/item/weapon/storage/backpack/quiver, 3, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("leather satchel", /obj/item/weapon/storage/belt/leather, 3, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("leather bedroll", /obj/item/weapon/bedroll, 4, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("leather waterskin", /obj/item/weapon/reagent_containers/food/drinks/drinkingglass/waterskin, 3, _time = 90, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("ore collector", /obj/item/weapon/storage/ore_collector, 5, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("seed collector", /obj/item/weapon/storage/seed_collector, 5, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("leather bandages", /obj/item/stack/medical/bruise_pack/bint/leather, 3, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += list(new/datum/stack_recipe("foldable canopy", /obj/item/weapon/tent, 5, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE))
	if (current_res[1] >= 18)
		recipes += new/datum/stack_recipe("coin pouch", /obj/item/clothing/accessory/storage/coinpouch, 2, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("leather backpack", /obj/item/weapon/storage/backpack, 6, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[2] >= 19)
		recipes += new/datum/stack_recipe("roman-style sandals", /obj/item/clothing/shoes/roman, 2, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[2] >= 39)
		recipes += new/datum/stack_recipe("medieval shoes", /obj/item/clothing/shoes/medieval, 3, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("arabic-style shoes", /obj/item/clothing/shoes/medieval/arab, 2, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[2] >= 85)
		recipes += new/datum/stack_recipe("gunpowder pouch", /obj/item/weapon/reagent_containers/food/drinks/gunpowder, 2, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("bandolier", /obj/item/clothing/accessory/storage/webbing, 3, _time = 70, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[1] >= 55 && current_res[3] >= 25)
		recipes += new/datum/stack_recipe("black leather shoes", /obj/item/clothing/shoes/soldiershoes, 2, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("black leather boots", /obj/item/clothing/shoes/blackboots1, 3, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("leather boots", /obj/item/clothing/shoes/leatherboots1, 3, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[2] >= 15)
		recipes += new/datum/stack_recipe("leather armor", /obj/item/clothing/suit/armor/medieval/leather, 6, _time = 130, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("leather curtain", /obj/structure/curtain/leather, 4, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += list(new/datum/stack_recipe("custom flag maker", /obj/item/flagmaker, 4, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE))
	recipes += new/datum/stack_recipe_list("armbands", list(
		new/datum/stack_recipe("red armband", /obj/item/clothing/accessory/armband/british, 1, _time = 30, _one_per_turf = FALSE, _on_floor = TRUE),
		new/datum/stack_recipe("orange armband", /obj/item/clothing/accessory/armband/dutch, 1, _time = 30, _one_per_turf = FALSE, _on_floor = TRUE),
		new/datum/stack_recipe("blue armband", /obj/item/clothing/accessory/armband/french, 1, _time = 30, _one_per_turf = FALSE, _on_floor = TRUE),
		new/datum/stack_recipe("yellow armband", /obj/item/clothing/accessory/armband/spanish, 1, _time = 30, _one_per_turf = FALSE, _on_floor = TRUE),
		new/datum/stack_recipe("green armband", /obj/item/clothing/accessory/armband/portuguese, 1, _time = 30, _one_per_turf = FALSE, _on_floor = TRUE),))
/material/iron/generate_recipes_civs(var/list/current_res = list(0,0,0))
	..()
	if (current_res[1] >= 33)
		recipes += new/datum/stack_recipe("table", /obj/structure/table, 4, _time = 80, _one_per_turf = TRUE, _on_floor = TRUE, _supplied_material = "[name]")
		recipes += new/datum/stack_recipe("cooking pot", /obj/structure/pot, 8, _time = 180, _one_per_turf = TRUE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("oven", /obj/structure/oven, 8, _time = 150, _one_per_turf = TRUE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe(" brazier",	/obj/structure/brazier, 4, _time = 90, _one_per_turf = TRUE, _on_floor = TRUE)
	if (current_res[2] >= 32)
		recipes += new/datum/stack_recipe("mechanical trap", /obj/item/weapon/beartrap, 5, _time = 140, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[1] >= 28)
		recipes += new/datum/stack_recipe("lantern", /obj/item/flashlight/lantern, 4, _time = 140, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("unlocked door", /obj/structure/simple_door/key_door/anyone, 5, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("locked door", /obj/structure/simple_door/key_door/custom, 5, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("key", /obj/item/weapon/key, 2, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("keychain", /obj/item/weapon/storage/belt/keychain, 1, _time = 30, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[1] >= 25)
		recipes += new/datum/stack_recipe("anvil", /obj/structure/anvil, 25, _time = 150, _one_per_turf = TRUE, _on_floor = TRUE)
	if (current_res[1] >= 27 && current_res[2] >= 16)
		recipes += new/datum/stack_recipe("iron-tipped spear", /obj/item/weapon/material/spear, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")

		recipes += new/datum/stack_recipe("battle axe", /obj/item/weapon/material/battleaxe, 4, _time = 70, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
		recipes += new/datum/stack_recipe("iron shield", /obj/item/weapon/shield/iron, 4, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[1] >= 33 && current_res[2] >= 39)
		recipes += new/datum/stack_recipe("halberd", /obj/item/weapon/material/halberd, 2, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
		recipes += new/datum/stack_recipe("pike", /obj/item/weapon/material/pike, 3, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")

		recipes += new/datum/stack_recipe_list("tools", list(
			new/datum/stack_recipe("hatchet", /obj/item/weapon/material/hatchet, 2, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]"),
			new/datum/stack_recipe("shovel", /obj/item/weapon/shovel, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("wrench", /obj/item/weapon/wrench, 4, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("butcher's cleaver", /obj/item/weapon/material/knife/butcher, 3, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]"),
			new/datum/stack_recipe("pickaxe", /obj/item/weapon/pickaxe, 3, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE),))
	if (current_res[2] >= 82)
		recipes += new/datum/stack_recipe_list("bullets", list(
			new/datum/stack_recipe("musket ball (x2)", /obj/item/stack/ammopart/musketball, 1, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("small musket ball (x3)", /obj/item/stack/ammopart/musketball_pistol, 1, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("blunderbuss ball (x2)", /obj/item/stack/ammopart/blunderbuss, 1, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("cannon ball", /obj/item/cannon_ball, 5, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE),))
	recipes += new/datum/stack_recipe("iron arm bangles", /obj/item/clothing/accessory/armband/armbangle, 2, _time = 95, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[1] >= 35 && current_res[3]>= 44)
		recipes += new/datum/stack_recipe("splints", /obj/item/stack/medical/splint, 2, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE)

	if (current_res[1] >= 35 && current_res[3]>= 55)
		recipes += new/datum/stack_recipe_list("medical tools", list(
			new/datum/stack_recipe("retractor", /obj/item/weapon/surgery/retractor, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("bone saw",/obj/item/weapon/surgery/bone_saw, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("bone setter",/obj/item/weapon/surgery/bonesetter, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("scalpel", /obj/item/weapon/surgery/scalpel, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),))
	else if (current_res[1] >= 35 && current_res[3]>= 67)
		recipes += new/datum/stack_recipe_list("medical tools", list(
			new/datum/stack_recipe("retractor", /obj/item/weapon/surgery/retractor, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("hemostat", /obj/item/weapon/surgery/hemostat, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("cautery",/obj/item/weapon/surgery/cautery, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("bone saw",/obj/item/weapon/surgery/bone_saw, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("bone setter",/obj/item/weapon/surgery/bonesetter, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("scalpel", /obj/item/weapon/surgery/scalpel, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),))

/material/wood/generate_recipes_civs(var/list/current_res = list(0,0,0))
	..()
	recipes += new/datum/stack_recipe("roof support",/obj/structure/roof_support, 2, _time = 30, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("mine support",/obj/structure/mine_support, 2, _time = 30, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("roof builder",/obj/item/weapon/roofbuilder, 1, _time = 20, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[1] >= 33 && current_res[3]>= 48)
		recipes += new/datum/stack_recipe("doctor handbook",/obj/item/weapon/doctor_handbook, 12, _time = 210, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[1] >= 25 && current_res[3]>= 51)
		recipes += new/datum/stack_recipe("operating table",/obj/structure/optable, 9, _time = 190, _one_per_turf = FALSE, _on_floor = TRUE)
	if (map.ordinal_age > 0 && map.research_active == TRUE)
		recipes += new/datum/stack_recipe("research kit",/obj/item/weapon/researchkit, 10, _time = 190, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("scientific literature",/obj/item/weapon/book/research, 4, _time = 110, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[1] >= 18)

		recipes += new/datum/stack_recipe_list("walls, doors & floors", list(
			new/datum/stack_recipe("door", /obj/structure/simple_door/key_door/anyone/wood, 5, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("floor tile", /obj/covers/wood, 1, _time = 25, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("window", /obj/structure/window_frame, 5, _time = 80, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("soft wood wall", /obj/covers/wood_wall, 8, _time = 170, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("straw wall", /obj/covers/straw_wall, 4, _time = 90, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("custom sign", /obj/structure/sign/custom, 3, _time = 40, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("floor cover", /obj/item/weapon/covers, 2, _time = 30, _one_per_turf = TRUE, _on_floor = TRUE),))
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

	if (current_res[2] >= 21)
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
	else
		recipes += new/datum/stack_recipe_list("weapons", list(
			new/datum/stack_recipe("arrow", /obj/item/ammo_casing/arrow, 1, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("bow", /obj/item/weapon/gun/projectile/bow, 8, _time = 120, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("punji sticks trap", /obj/item/weapon/punji_sticks, 4, _time = 70, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("quarterstaff", /obj/item/weapon/material/quarterstaff, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]"),
			new/datum/stack_recipe("wood spear", /obj/item/weapon/material/spear, 3, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]"),))

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
			/obj/item/weapon/cane
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
			new/datum/stack_recipe("wood pole", /obj/structure/barricade/wood_pole, 2, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),))
	else
		recipes += new/datum/stack_recipe_list("furniture", list(
			new/datum/stack_recipe("bed", /obj/structure/bed/wood, 4, _time = 60,_one_per_turf = TRUE, _on_floor = TRUE,),
			new/datum/stack_recipe("wood crate", /obj/structure/closet/crate/empty, 5, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("table", /obj/structure/table/wood, 4, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("wood pole", /obj/structure/barricade/wood_pole, 2, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),))

	if (current_res[1] < 47)
		recipes += new/datum/stack_recipe_list("decoration", list(
			new/datum/stack_recipe("native wood mask", /obj/structure/religious/tribalmask, 2, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("impaled skull", /obj/structure/religious/impaledskull, 2, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),))
	else
		recipes += new/datum/stack_recipe_list("decoration", list(
			new/datum/stack_recipe("impaled skull", /obj/structure/religious/impaledskull, 2, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("small cross", /obj/structure/religious/woodcross1, 2, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("cross", /obj/structure/religious/woodcross2, 4, _time = 80, _one_per_turf = TRUE, _on_floor = TRUE),))

	if (current_res[1] < 19)
		recipes += new/datum/stack_recipe_list("kitchen & other", list(
			new/datum/stack_recipe("sandals", /obj/item/clothing/shoes/sandal, TRUE),
			new/datum/stack_recipe("wood mug",/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/wood, 1, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("campfire",/obj/structure/oven/fireplace, 4, _time = 140, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("torch",/obj/item/flashlight/torch, 2, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("wood bowl",/obj/item/kitchen/wood_bowl, 1, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE),))
	else if (current_res[1] >= 19 && current_res[1] <= 45)
		recipes += new/datum/stack_recipe_list("kitchen & other", list(
			new/datum/stack_recipe("loom",/obj/structure/loom, 8, _time = 150, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("pen",/obj/item/weapon/pen, 1, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("sandals", /obj/item/clothing/shoes/sandal, TRUE),
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
			new/datum/stack_recipe("pen",/obj/item/weapon/pen, 1, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("paper sheet",/obj/item/weapon/paper, 1, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("sandals", /obj/item/clothing/shoes/sandal, TRUE),
			new/datum/stack_recipe("wood mug",/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/wood, 1, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("campfire",/obj/structure/oven/fireplace, 4, _time = 140, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("torch",/obj/item/flashlight/torch, 2, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("wood pipe",/obj/item/clothing/mask/smokable/pipe, 2, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("wood bowl",/obj/item/kitchen/wood_bowl, 1, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("small mill",/obj/structure/mill, 4, _time = 90, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("barrel",/obj/item/weapon/reagent_containers/glass/barrel/empty, 5, _time = 75, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("violin",/obj/item/violin, 10, _time = 135, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("dehydrator",/obj/structure/dehydrator, 5, _time = 110, _one_per_turf = TRUE, _on_floor = TRUE),))
	if (current_res[1] >= 24 && current_res[2] >= 33)
		recipes += new/datum/stack_recipe_list("siege weapons", list(
			new/datum/stack_recipe("catapult",/obj/structure/catapult, 50, _time = 450, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("siege ladder",/obj/item/weapon/siegeladder, 8, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),))


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

/material/stone/stone/generate_recipes_civs(var/list/current_res = list(0,0,0))
	..()
	recipes += new/datum/stack_recipe("stone brazier",	/obj/structure/brazier/stone, 3, _time = 100, _one_per_turf = TRUE, _on_floor = TRUE)
	if (map.ordinal_age == 0 && map.research_active == TRUE)
		recipes += new/datum/stack_recipe("research kit",/obj/item/weapon/researchkit, 10, _time = 190, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("scientific rock slate",/obj/item/weapon/book/research, 4, _time = 110, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("stone hatchet", /obj/item/weapon/material/hatchet/tribal, 2, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
	recipes += new/datum/stack_recipe("cobblestone floor", /obj/covers/cobblestone, 1, _time = 25, _one_per_turf = TRUE, _on_floor = TRUE)
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

	if (current_res[1] >= 29)
		recipes += new/datum/stack_recipe_list("fortifications", list(
			new/datum/stack_recipe("fortified wall (horizontal)", /obj/structure/barricade/stone_h, 5, _time = 80, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("fortified wall (vertical)", /obj/structure/barricade/stone_v, 5, _time = 80, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("fortified crenelated wall (horizontal)", /obj/structure/barricade/stone_h/crenelated, 5, _time = 80, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("fortified crenelated wall (vertical)", /obj/structure/barricade/stone_v/crenelated, 5, _time = 80, _one_per_turf = TRUE, _on_floor = TRUE),))

/material/tobacco/generate_recipes_civs(var/list/current_res = list(0,0,0))
	..()
	if (current_res[3] >= 23)
		recipes = list(new/datum/stack_recipe("cigar", /obj/item/clothing/mask/smokable/cigarette/cigar, 3, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE))
		recipes += list(new/datum/stack_recipe("cuban cigar", /obj/item/clothing/mask/smokable/cigarette/cigar/havana, 5, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE))

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
	if (current_res[3] >= 19)
		recipes += list(new/datum/stack_recipe("bandages", /obj/item/stack/medical/bruise_pack/bint, 2, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE))
		recipes += list(new/datum/stack_recipe("foldable canopy", /obj/item/weapon/tent, 4, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE))

	if (current_res[3] >= 56)
		recipes += list(new/datum/stack_recipe("trauma kit", /obj/item/stack/medical/advanced/bruise_pack, 5, _time = 105, _one_per_turf = FALSE, _on_floor = TRUE))
	if (current_res[3] >= 43)
		recipes += list(new/datum/stack_recipe("burn kit", /obj/item/stack/medical/advanced/ointment, 4, _time = 90, _one_per_turf = FALSE, _on_floor = TRUE))
	recipes += list(new/datum/stack_recipe("custom flag maker", /obj/item/flagmaker, 4, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE))

	if ((current_res[1] >= 22 && current_res[3] >= 25)&& !(current_res[1] >= 45 && current_res[3] >= 35))
		recipes += new/datum/stack_recipe_list("hats", list(
			new/datum/stack_recipe("straw hat", /obj/item/clothing/head/strawhat, 3, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("red beret", /obj/item/clothing/head/red_beret, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("colored turban", /obj/item/clothing/head/turban, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("white turban", /obj/item/clothing/head/turban/imam, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("shemagh", /obj/item/clothing/mask/shemagh, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("blue beret", /obj/item/clothing/head/blue_beret, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),))
	if ((current_res[1] >= 45 && current_res[3] >= 35) && !(current_res[1] >= 76 && current_res[3] >= 48))
		recipes += new/datum/stack_recipe_list("hats", list(
			new/datum/stack_recipe("straw hat", /obj/item/clothing/head/strawhat, 3, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("red beret", /obj/item/clothing/head/red_beret, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("colored turban", /obj/item/clothing/head/turban, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("white turban", /obj/item/clothing/head/turban/imam, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("shemagh", /obj/item/clothing/mask/shemagh, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("blue beret", /obj/item/clothing/head/blue_beret, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("kerchief", /obj/item/clothing/head/kerchief, 2, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),))
	if (current_res[1] >= 76 && current_res[3] >= 48)
		recipes += new/datum/stack_recipe_list("hats", list(
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
			new/datum/stack_recipe("bandana", /obj/item/clothing/head/piratebandana1, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),))
	if ((current_res[1] >= 18 && current_res[3] >= 15) && !(current_res[1] >= 38 && current_res[3] >= 32))
		recipes += new/datum/stack_recipe_list("clothing", list(
			new/datum/stack_recipe("white tunic", /obj/item/clothing/under/toxotai, 4, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("white toga", /obj/item/clothing/under/toga, 3, _time = 65, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("half-shoulder white toga", /obj/item/clothing/under/toga2, 2, _time = 65, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("roman-style tunic", /obj/item/clothing/under/roman, 5, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("greek-style tunic", /obj/item/clothing/under/greek2, 4, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("blue celtic trousers", /obj/item/clothing/under/celtic_blue, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("green celtic trousers", /obj/item/clothing/under/celtic_green, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("red celtic trousers", /obj/item/clothing/under/celtic_red, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("long celtic braccae", /obj/item/clothing/under/celtic_long_braccae, 3, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("short celtic braccae", /obj/item/clothing/under/celtic_short_braccae, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("blue cape", /obj/item/clothing/suit/cape/blue, 2, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("red cape", /obj/item/clothing/suit/cape, 2, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),))
	if ((current_res[1] >= 38 && current_res[3] >= 32) && !(current_res[1] >= 74 && current_res[3] >= 55))
		recipes += new/datum/stack_recipe_list("clothing", list(
			new/datum/stack_recipe("yellow tunic", /obj/item/clothing/under/medieval/yellow, 4, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("blue tunic", /obj/item/clothing/under/medieval/blue, 4, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("blue-white tunic", /obj/item/clothing/under/medieval/blue2, 4, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("red tunic", /obj/item/clothing/under/medieval/red, 4, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("red-yellow tunic", /obj/item/clothing/under/medieval/red2, 4, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("light brown arabic tunic", /obj/item/clothing/under/medieval/arab1, 3, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("light white arabic tunic", /obj/item/clothing/under/medieval/arab2, 3, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("white arabic tunic", /obj/item/clothing/under/medieval/arab3, 3, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("blue cape", /obj/item/clothing/suit/cape/blue, 2, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("red cape", /obj/item/clothing/suit/cape, 2, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),))
	if (current_res[1] >= 74 && current_res[3] >= 55)
		recipes += new/datum/stack_recipe_list("clothing", list(
				new/datum/stack_recipe("blue colonial clothing", /obj/item/clothing/under/civ1, 3, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
				new/datum/stack_recipe("white colonial clothing", /obj/item/clothing/under/civ2, 3, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
				new/datum/stack_recipe("short-sleeved colonial clothing", /obj/item/clothing/under/civ3, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
				new/datum/stack_recipe("fancy colonial clothing", /obj/item/clothing/under/civ4, 5, _time = 105, _one_per_turf = FALSE, _on_floor = TRUE),
				new/datum/stack_recipe("green colonial clothing", /obj/item/clothing/under/civ5, 3, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
				new/datum/stack_recipe("pink colonial clothing", /obj/item/clothing/under/civ6, 3, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
				new/datum/stack_recipe("black stripes clothing", /obj/item/clothing/under/pirate1, 3, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
				new/datum/stack_recipe("red stripes clothing", /obj/item/clothing/under/pirate2, 3, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
				new/datum/stack_recipe("blue stripes clothing", /obj/item/clothing/under/pirate3, 3, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
				new/datum/stack_recipe("black dress", /obj/item/clothing/under/civf1, 4, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),
				new/datum/stack_recipe("blue dress", /obj/item/clothing/under/civf2, 4, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),
				new/datum/stack_recipe("brown dress", /obj/item/clothing/under/civf3, 4, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE),))

	if (current_res[1] >= 78 && current_res[3] >= 57)
		recipes += new/datum/stack_recipe_list("jackets & vests", list(
			new/datum/stack_recipe("black jacket", /obj/item/clothing/suit/storage/jacket/piratejacket1, 6, _time = 110, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("fancy brown jacket", /obj/item/clothing/suit/storage/jacket/piratejacket2, 10, _time = 180, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("fancy red jacket", /obj/item/clothing/suit/storage/jacket/piratejacket5, 10, _time = 180, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("blue vest", /obj/item/clothing/suit/storage/jacket/piratejacket3, 4, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("black vest", /obj/item/clothing/suit/storage/jacket/piratejacket4, 4, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),))
	if (current_res[1] >= 41 && current_res[3] >= 28)
		recipes += new/datum/stack_recipe_list("bedsheet", list(
			new/datum/stack_recipe("white bedsheet", /obj/item/weapon/bedsheet, 2, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("medical bedsheet", /obj/item/weapon/bedsheet/medical, 2, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("brown bedsheet", /obj/item/weapon/bedsheet/brown, 2, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("blue bedsheet", /obj/item/weapon/bedsheet/blue, 2, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("yellow bedsheet", /obj/item/weapon/bedsheet/blue, 2, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("red bedsheet", /obj/item/weapon/bedsheet/red, 2, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),))


/material/gold/generate_recipes_civs(var/list/current_res = list(0,0,0))
	..()
	if (current_res[1] >= 17 && current_res[2] >= 16)
		recipes += new/datum/stack_recipe("[display_name] hatchet", /obj/item/weapon/material/hatchet, 2, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
		recipes += new/datum/stack_recipe("[display_name]-tipped spear", /obj/item/weapon/material/spear, 1, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
	recipes += new/datum/stack_recipe("gold coins", /obj/item/stack/money/goldcoin, 1, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("gold crown", /obj/item/clothing/head/helmet/gold_crown, 3, _time = 135, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("gold arm bangles", /obj/item/clothing/accessory/armband/armbangle/gold, 2, _time = 95, _one_per_turf = FALSE, _on_floor = TRUE)

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
	recipes += new/datum/stack_recipe("bronze arm bangles", /obj/item/clothing/accessory/armband/armbangle/bronze, 2, _time = 95, _one_per_turf = FALSE, _on_floor = TRUE)
/material/steel/generate_recipes_civs(var/list/current_res = list(0,0,0))
	..()
	if (current_res[1] >= 50 && current_res[2] >= 44)
		recipes += new/datum/stack_recipe("[display_name] hatchet", /obj/item/weapon/material/hatchet, 2, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
		recipes += new/datum/stack_recipe("[display_name]-tipped spear", /obj/item/weapon/material/spear, 1, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
		recipes += new/datum/stack_recipe("steel shield", /obj/item/weapon/shield/steel, 4, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE)
	if (current_res[1] >= 71 && current_res[2] >= 89)
		recipes += new/datum/stack_recipe("cannon", /obj/structure/cannon, 40, _time = 600, _one_per_turf = TRUE, _on_floor = TRUE)

/material/tin/generate_recipes_civs(var/list/current_res = list(0,0,0))
	..()
	recipes += new/datum/stack_recipe("small tin pot", /obj/item/weapon/reagent_containers/glass/small_pot, 3, _time = 120, _one_per_turf = FALSE, _on_floor = TRUE)

/material/bearpelt/generate_recipes_civs(var/list/current_res = list(0,0,0))
	..()
	recipes += new/datum/stack_recipe("fur coat", /obj/item/clothing/suit/storage/coat/fur/black, 6, _time = 150, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("fur boots", /obj/item/clothing/shoes/fur/black, 3, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("fur gloves", /obj/item/clothing/gloves/thick/leather/black, 3, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("bear pelt headcover", /obj/item/clothing/head/bearpelt/black, 4, _time = 150, _one_per_turf = FALSE, _on_floor = TRUE)

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
