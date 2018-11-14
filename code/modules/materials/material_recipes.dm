var/list/engineer_exclusive_recipe_types = null

/material/proc/get_recipes()
	if (!recipes)
		generate_recipes()
	return recipes

/material/proc/generate_recipes()
	recipes = list()
	if (hardness>=40)
		recipes += new/datum/stack_recipe("[display_name] fork", /obj/item/weapon/material/kitchen/utensil/fork/plastic, TRUE, _on_floor = TRUE, _supplied_material = "[name]")
		recipes += new/datum/stack_recipe("[display_name] knife", /obj/item/weapon/material/kitchen/utensil/knife/plastic, TRUE, _on_floor = TRUE, _supplied_material = "[name]")
		if (map.ordinal_age >= 1)
			recipes += new/datum/stack_recipe("[display_name] spoon", /obj/item/weapon/material/kitchen/utensil/spoon/plastic, TRUE, _on_floor = TRUE, _supplied_material = "[name]")

/material/leather/generate_recipes()
	..()
	if (map.ordinal_age >= 2)
		recipes += new/datum/stack_recipe("comfy chair", /obj/structure/bed/chair/comfy/brown, 6, _time = 100, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("quiver", /obj/item/weapon/storage/backpack/quiver, 3, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("leather satchel", /obj/item/weapon/storage/belt/leather, 3, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE)
	if (map.ordinal_age >= 1)
		recipes += new/datum/stack_recipe("coin pouch", /obj/item/clothing/accessory/storage/coinpouch, 2, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE)
	if (map.ordinal_age >= 3)
		recipes += new/datum/stack_recipe("gunpowder pouch", /obj/item/weapon/reagent_containers/food/drinks/gunpowder, 2, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("bandolier", /obj/item/clothing/accessory/storage/webbing, 3, _time = 70, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("black leather shoes", /obj/item/clothing/shoes/soldiershoes, 2, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("black leather boots", /obj/item/clothing/shoes/blackboots1, 3, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("leather boots", /obj/item/clothing/shoes/leatherboots1, 3, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("leather armor", /obj/item/clothing/suit/armor/medieval/leather, 6, _time = 130, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("leather curtain", /obj/structure/curtain/leather, 4, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE)

/material/iron/generate_recipes()
	..()
	if (map.ordinal_age >= 1)
		recipes += new/datum/stack_recipe("table", /obj/structure/table, 4, _time = 80, _one_per_turf = TRUE, _on_floor = TRUE, _supplied_material = "[name]")
		recipes += new/datum/stack_recipe("cooking pot", /obj/structure/pot, 8, _time = 180, _one_per_turf = TRUE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("oven", /obj/structure/oven, 8, _time = 150, _one_per_turf = TRUE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("lantern", /obj/item/flashlight/lantern, 4, _time = 140, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("unlocked door", /obj/structure/simple_door/key_door/anyone, 5, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("locked door", /obj/structure/simple_door/key_door/custom, 5, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("key", /obj/item/weapon/key, 2, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("keychain", /obj/item/weapon/storage/belt/keychain, 1, _time = 30, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("anvil", /obj/structure/anvil, 25, _time = 150, _one_per_turf = TRUE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("iron-tipped spear", /obj/item/weapon/material/spear, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
		recipes += new/datum/stack_recipe("iron shield", /obj/item/weapon/shield/iron, 4, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe_list("tools", list(
			new/datum/stack_recipe("hatchet", /obj/item/weapon/material/hatchet, 2, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]"),
			new/datum/stack_recipe("shovel", /obj/item/weapon/shovel, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("wrench", /obj/item/weapon/wrench, 4, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("butcher's cleaver", /obj/item/weapon/material/knife/butcher, 3, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]"),
			new/datum/stack_recipe("pickaxe", /obj/item/weapon/pickaxe, 3, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE),))
	if (map.ordinal_age >= 3)
		recipes += new/datum/stack_recipe_list("bullets", list(
			new/datum/stack_recipe("musket ball (x2)", /obj/item/stack/ammopart/musketball, 1, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("small musket ball (x3)", /obj/item/stack/ammopart/musketball_pistol, 1, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("blunderbuss ball (x2)", /obj/item/stack/ammopart/blunderbuss, 1, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("cannon ball", /obj/item/cannon_ball, 5, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE),))

/material/wood/generate_recipes()
	..()
	if (map.ordinal_age >= 1)
		recipes += new/datum/stack_recipe_list("walls, doors & floors", list(
			new/datum/stack_recipe("door", /obj/structure/simple_door/key_door/anyone/wood, 5, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("floor tile", /obj/covers/wood, 1, _time = 25, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("window", /obj/structure/window_frame, 5, _time = 80, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("soft wood wall", /obj/covers/wood_wall, 8, _time = 170, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("straw wall", /obj/covers/straw_wall, 5, _time = 90, _one_per_turf = TRUE, _on_floor = TRUE),
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

	if (map.ordinal_age >= 1)
		recipes += new/datum/stack_recipe_list("weapons", list(
			new/datum/stack_recipe("arrow", /obj/item/ammo_casing/arrow, 1, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("bow", /obj/item/weapon/gun/projectile/bow, 8, _time = 120, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("punji sticks trap", /obj/item/weapon/punji_sticks, 4, _time = 70, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("wood spear", /obj/item/weapon/material/spear, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]"),
			new/datum/stack_recipe("wood shield", /obj/item/weapon/shield, 8, _time = 180, _one_per_turf = FALSE, _on_floor = TRUE),))
	else
		recipes += new/datum/stack_recipe_list("weapons", list(
			new/datum/stack_recipe("arrow", /obj/item/ammo_casing/arrow, 1, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("bow", /obj/item/weapon/gun/projectile/bow, 8, _time = 120, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("punji sticks trap", /obj/item/weapon/punji_sticks, 4, _time = 70, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("wood spear", /obj/item/weapon/material/spear, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]"),))
	if (map.ordinal_age < 1)
		recipes += new/datum/stack_recipe_list("tools", list(
			new/datum/stack_recipe("wood handle", /obj/item/weapon/material/handle, 1, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]"),
			new/datum/stack_recipe("bucket",/obj/item/weapon/reagent_containers/glass/bucket, 2, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("plough",/obj/item/weapon/plough, 4, _time = 120, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("hammer",/obj/item/weapon/hammer, 5, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),))
	else
		recipes += new/datum/stack_recipe_list("tools", list(
			new/datum/stack_recipe("wood handle", /obj/item/weapon/material/handle, 1, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]"),
			new/datum/stack_recipe("bucket",/obj/item/weapon/reagent_containers/glass/bucket, 2, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("plough",/obj/item/weapon/plough, 4, _time = 120, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("hammer",/obj/item/weapon/hammer, 5, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("rollingpin",/obj/item/weapon/material/kitchen/rollingpin, 1, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("mop",/obj/item/weapon/mop, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),))

	if (map.ordinal_age == 0)
		recipes += new/datum/stack_recipe_list("furniture", list(
			new/datum/stack_recipe("bed", /obj/structure/bed/wood, 4, _time = 60,_one_per_turf = TRUE, _on_floor = TRUE,),
			new/datum/stack_recipe("wood crate", /obj/structure/closet/crate/empty, 5, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("table", /obj/structure/table/wood, 4, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),))
	else if (map.ordinal_age >= 1)
		recipes += new/datum/stack_recipe_list("furniture", list(
			new/datum/stack_recipe("chair", /obj/structure/bed/chair/wood, 4, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("wood chest", /obj/structure/closet/crate/chest, 7, _time = 75, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("coffin", /obj/structure/closet/coffin, 4, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("bed", /obj/structure/bed/wood, 4, _time = 60,_one_per_turf = TRUE, _on_floor = TRUE,),
			new/datum/stack_recipe("wood crate", /obj/structure/closet/crate/empty, 5, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("table", /obj/structure/table/wood, 4, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),))
	else if (map.ordinal_age >= 2)
		recipes += new/datum/stack_recipe_list("furniture", list(
			new/datum/stack_recipe("chair", /obj/structure/bed/chair/wood, 4, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("wood chest", /obj/structure/closet/crate/chest, 7, _time = 75, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("coffin", /obj/structure/closet/coffin, 4, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("bed", /obj/structure/bed/wood, 4, _time = 60,_one_per_turf = TRUE, _on_floor = TRUE,),
			new/datum/stack_recipe("wood crate", /obj/structure/closet/crate/empty, 5, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("table", /obj/structure/table/wood, 4, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("coffin", /obj/structure/closet/coffin, 4, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),))
	if (map.ordinal_age < 2)
		recipes += new/datum/stack_recipe_list("decoration", list(
			new/datum/stack_recipe("impaled skull", /obj/structure/religious/impaledskull, 2, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("native wood mask", /obj/structure/religious/tribalmask, 2, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("impaled skull", /obj/structure/religious/impaledskull, 2, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),))
	else if (map.ordinal_age >= 2)
		recipes += new/datum/stack_recipe_list("decoration", list(
			new/datum/stack_recipe("impaled skull", /obj/structure/religious/impaledskull, 2, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("native wood mask", /obj/structure/religious/tribalmask, 2, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("impaled skull", /obj/structure/religious/impaledskull, 2, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("small cross", /obj/structure/religious/woodcross1, 2, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("cross", /obj/structure/religious/woodcross2, 4, _time = 80, _one_per_turf = TRUE, _on_floor = TRUE),))

	if (map.ordinal_age == 0)
		recipes += new/datum/stack_recipe_list("kitchen & other", list(
			new/datum/stack_recipe("sandals", /obj/item/clothing/shoes/sandal, TRUE),
			new/datum/stack_recipe("wood mug",/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/wood, 1, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("campfire",/obj/structure/oven/fireplace, 4, _time = 140, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("torch",/obj/item/flashlight/torch, 2, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("wood pipe",/obj/item/clothing/mask/smokable/pipe, 2, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("wood bowl",/obj/item/kitchen/wood_bowl, 1, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("small mill",/obj/structure/mill, 4, _time = 90, _one_per_turf = TRUE, _on_floor = TRUE),
			new/datum/stack_recipe("barrel",/obj/item/weapon/reagent_containers/glass/barrel/empty, 5, _time = 75, _one_per_turf = TRUE, _on_floor = TRUE),))
	else if (map.ordinal_age >= 1)
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
			new/datum/stack_recipe("barrel",/obj/item/weapon/reagent_containers/glass/barrel/empty, 5, _time = 75, _one_per_turf = TRUE, _on_floor = TRUE),))
/material/rope/generate_recipes()
	recipes = list(new/datum/stack_recipe("noose", /obj/structure/noose, _time = 20))
	recipes += list(new/datum/stack_recipe("rope handcuffs", /obj/item/weapon/handcuffs/rope, _time = 50))
/material/glass/generate_recipes()
	..()
	if (map.ordinal_age >= 1)
		recipes += new/datum/stack_recipe("drinking glass", /obj/item/weapon/reagent_containers/food/drinks/drinkingglass, 2, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("small glass bottle", /obj/item/weapon/reagent_containers/food/drinks/bottle/small, 2, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE)
	if (map.ordinal_age >= 2)
		recipes += new/datum/stack_recipe("drinking glass", /obj/item/weapon/reagent_containers/food/drinks/drinkingglass, 2, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("teapot", /obj/item/weapon/reagent_containers/food/drinks/teapot, 4, _time = 70, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("teacup", /obj/item/weapon/reagent_containers/food/drinks/tea/empty, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE)
		recipes += new/datum/stack_recipe("wine glass", /obj/item/weapon/reagent_containers/food/drinks/drinkingglass, 2, _time = 25, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("tribal pot", /obj/item/weapon/reagent_containers/food/drinks/drinkingglass/tribalpot, 2, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE)

/material/stone/stone/generate_recipes()
	..()
	recipes += new/datum/stack_recipe("stone hatchet", /obj/item/weapon/material/hatchet/tribal, 2, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
	recipes += new/datum/stack_recipe("cobblestone floor", /obj/covers/cobblestone, 1, _time = 25, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("gravestone", /obj/structure/religious/gravestone, 3, _time = 60, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("totem", /obj/structure/religious/totem, 8, _time = 150, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("stone wall", /obj/covers/stone_wall, 10, _time = 140, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("rock barrier wall", /obj/structure/window/sandbag/rock, 3, _time = 70, _one_per_turf = TRUE, _on_floor = TRUE)
	if (map.ordinal_age >= 1)
		recipes += new/datum/stack_recipe("furnace", /obj/structure/furnace/, 10, _time = 150, _one_per_turf = TRUE, _on_floor = TRUE)

/material/tobacco/generate_recipes()
	recipes = list(new/datum/stack_recipe("cigar", /obj/item/clothing/mask/smokable/cigarette/cigar, 3, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE))
	recipes += list(new/datum/stack_recipe("cuban cigar", /obj/item/clothing/mask/smokable/cigarette/cigar/havana, 5, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE))

/material/poppy/generate_recipes()
	recipes = list(new/datum/stack_recipe("opium", /obj/item/weapon/reagent_containers/pill/opium, 3, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE))

/material/bone/generate_recipes()
	recipes = list(new/datum/stack_recipe("bone talisman", /obj/item/clothing/accessory/armband/talisman, 2, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE))
	recipes += list(new/datum/stack_recipe("skull mask", /obj/item/clothing/head/skullmask, 5, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE))
	recipes += list(new/datum/stack_recipe("bone knife", /obj/item/weapon/material/kitchen/utensil/knife/bone, 4, _time = 90, _one_per_turf = FALSE, _on_floor = TRUE))
	recipes += list(new/datum/stack_recipe("blowing horn", /obj/item/weapon/horn, 4, _time = 110, _one_per_turf = FALSE, _on_floor = TRUE))
	recipes += list(new/datum/stack_recipe("bone armor", /obj/item/clothing/suit/storage/jacket/bonearmor, 10, _time = 170, _one_per_turf = FALSE, _on_floor = TRUE))
	recipes += list(new/datum/stack_recipe("bone hatchet", /obj/item/weapon/material/hatchet/tribal, 2, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]"))
	recipes += list(new/datum/stack_recipe("bone pickaxe", /obj/item/weapon/material/hatchet/tribal, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE))
	recipes += list(new/datum/stack_recipe("bone shovel", /obj/item/weapon/pickaxe/bone, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE))


/material/cloth/generate_recipes()
	..()
	recipes = list(new/datum/stack_recipe("bandages", /obj/item/stack/medical/bruise_pack/bint, 2, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE))

	if (map.ordinal_age <= 1)
		recipes += new/datum/stack_recipe_list("hats", list(
			new/datum/stack_recipe("straw hat", /obj/item/clothing/head/strawhat, 3, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("red beret", /obj/item/clothing/head/red_beret, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("blue beret", /obj/item/clothing/head/blue_beret, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),))
	if (map.ordinal_age >= 2)
		recipes += new/datum/stack_recipe_list("hats", list(
			new/datum/stack_recipe("straw hat", /obj/item/clothing/head/strawhat, 3, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("red beret", /obj/item/clothing/head/red_beret, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("blue beret", /obj/item/clothing/head/blue_beret, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("kerchief", /obj/item/clothing/head/kerchief, 2, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),))
	if (map.ordinal_age >= 3)
		recipes += new/datum/stack_recipe_list("hats", list(
			new/datum/stack_recipe("straw hat", /obj/item/clothing/head/strawhat, 3, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("red beret", /obj/item/clothing/head/red_beret, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("blue beret", /obj/item/clothing/head/blue_beret, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("kerchief", /obj/item/clothing/head/kerchief, 2, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("black bicorne", /obj/item/clothing/head/bicorne_british_soldier, 2, _time = 95, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("black tricorne", /obj/item/clothing/head/tricorne_black, 3, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("tarred hat", /obj/item/clothing/head/tarred_hat, 3, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("bandana", /obj/item/clothing/head/piratebandana1, 2, _time = 55, _one_per_turf = FALSE, _on_floor = TRUE),))

	if (map.ordinal_age >= 3)
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

	if (map.ordinal_age >= 3)
		recipes += new/datum/stack_recipe_list("jackets & vests", list(
			new/datum/stack_recipe("black jacket", /obj/item/clothing/suit/storage/jacket/piratejacket1, 6, _time = 110, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("fancy brown jacket", /obj/item/clothing/suit/storage/jacket/piratejacket2, 10, _time = 180, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("fancy red jacket", /obj/item/clothing/suit/storage/jacket/piratejacket5, 10, _time = 180, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("blue vest", /obj/item/clothing/suit/storage/jacket/piratejacket3, 4, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
			new/datum/stack_recipe("black vest", /obj/item/clothing/suit/storage/jacket/piratejacket4, 4, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),))

	recipes += new/datum/stack_recipe_list("bedsheet", list(
		new/datum/stack_recipe("white bedsheet", /obj/item/weapon/bedsheet, 2, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
		new/datum/stack_recipe("medical bedsheet", /obj/item/weapon/bedsheet/medical, 2, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
		new/datum/stack_recipe("brown bedsheet", /obj/item/weapon/bedsheet/brown, 2, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
		new/datum/stack_recipe("blue bedsheet", /obj/item/weapon/bedsheet/blue, 2, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
		new/datum/stack_recipe("yellow bedsheet", /obj/item/weapon/bedsheet/blue, 2, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),
		new/datum/stack_recipe("red bedsheet", /obj/item/weapon/bedsheet/red, 2, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE),))


/material/gold/generate_recipes()
	..()
	recipes += new/datum/stack_recipe("[display_name] hatchet", /obj/item/weapon/material/hatchet, 2, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
	recipes += new/datum/stack_recipe("[display_name]-tipped spear", /obj/item/weapon/material/spear, 1, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")

/material/silver/generate_recipes()
	..()
	recipes += new/datum/stack_recipe("[display_name] hatchet", /obj/item/weapon/material/hatchet, 2, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
	recipes += new/datum/stack_recipe("[display_name]-tipped spear", /obj/item/weapon/material/spear, 1, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")

/material/diamond/generate_recipes()
	..()
	recipes += new/datum/stack_recipe("[display_name] hatchet", /obj/item/weapon/material/hatchet, 2, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
	recipes += new/datum/stack_recipe("[display_name]-tipped spear", /obj/item/weapon/material/spear, 1, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")

/material/copper/generate_recipes()
	..()
	recipes += new/datum/stack_recipe("[display_name] hatchet", /obj/item/weapon/material/hatchet, 2, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
	recipes += new/datum/stack_recipe("[display_name]-tipped spear", /obj/item/weapon/material/spear, 1, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
	recipes += new/datum/stack_recipe("[display_name] small sword", /obj/item/weapon/material/sword/smallsword/copper, 10, _time = 70, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
	recipes += new/datum/stack_recipe("[display_name] spadroon", /obj/item/weapon/material/sword/spadroon/copper, 15, _time = 115, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")

/material/bronze/generate_recipes()
	..()
	recipes += new/datum/stack_recipe("[display_name] hatchet", /obj/item/weapon/material/hatchet, 2, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
	recipes += new/datum/stack_recipe("[display_name]-tipped spear", /obj/item/weapon/material/spear, 1, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
	recipes += new/datum/stack_recipe("bronze shield", /obj/item/weapon/shield/bronze, 4, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("[display_name] small sword", /obj/item/weapon/material/sword/smallsword/bronze, 10, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
	recipes += new/datum/stack_recipe("[display_name] spadroon", /obj/item/weapon/material/sword/spadroon/bronze, 15, _time = 125, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
	recipes += new/datum/stack_recipe("bronze chestplate", /obj/item/clothing/suit/armor/medieval/bronze_chestplate, 6, _time = 165, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")

/material/steel/generate_recipes()
	..()
	if (map.ordinal_age >= 2)
		recipes += new/datum/stack_recipe("[display_name] hatchet", /obj/item/weapon/material/hatchet, 2, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
		recipes += new/datum/stack_recipe("[display_name]-tipped spear", /obj/item/weapon/material/spear, 1, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE, _supplied_material = "[name]")
		recipes += new/datum/stack_recipe("steel shield", /obj/item/weapon/shield/steel, 4, _time = 85, _one_per_turf = FALSE, _on_floor = TRUE)
