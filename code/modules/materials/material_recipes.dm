var/list/engineer_exclusive_recipe_types = null

/material/proc/get_recipes()
	if (!recipes)
		generate_recipes()
	return recipes

/material/proc/generate_recipes()
	recipes = list()
	if (hardness>50)
		recipes += new/datum/stack_recipe("[display_name] fork", /obj/item/weapon/material/kitchen/utensil/fork/plastic, TRUE, _on_floor = TRUE, _supplied_material = "[name]")
		recipes += new/datum/stack_recipe("[display_name] knife", /obj/item/weapon/material/kitchen/utensil/knife/plastic, TRUE, _on_floor = TRUE, _supplied_material = "[name]")
		recipes += new/datum/stack_recipe("[display_name] spoon", /obj/item/weapon/material/kitchen/utensil/spoon/plastic, TRUE, _on_floor = TRUE, _supplied_material = "[name]")

/material/leather/generate_recipes()
	..()

	recipes += new/datum/stack_recipe("comfy chair", /obj/structure/bed/chair/comfy/brown, 6, _time = 100, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("quiver", /obj/item/weapon/storage/backpack/quiver, 3, _time = 60, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("leather satchel", /obj/item/weapon/storage/belt/leather, 3, _time = 60, _one_per_turf = TRUE, _on_floor = TRUE)

/material/iron/generate_recipes()
	..()

	recipes += new/datum/stack_recipe("table", /obj/structure/table, 4, _time = 80, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("cooking pot", /obj/structure/pot, 8, _time = 180, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("oven", /obj/structure/oven, 8, _time = 150, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("lantern", /obj/item/flashlight/lantern, 4, _time = 140, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("unlocked door", /obj/structure/simple_door/key_door/anyone, 5, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("locked door", /obj/structure/simple_door/key_door/anyone, 5, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("key", /obj/item/weapon/key, 2, _time = 35, _one_per_turf = TRUE, _on_floor = TRUE)

	recipes += new/datum/stack_recipe_list("tools", list(
		new/datum/stack_recipe("hatchet", /obj/item/weapon/material/hatchet, 2, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE),
		new/datum/stack_recipe("shovel", /obj/item/weapon/shovel, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
		new/datum/stack_recipe("pickaxe", /obj/item/weapon/pickaxe, 3, _time = 80, _one_per_turf = FALSE, _on_floor = TRUE),))

/material/wood/generate_recipes()
	..()

	recipes += new/datum/stack_recipe_list("walls, doors & floors", list(
		new/datum/stack_recipe("door", /obj/structure/simple_door/key_door/anyone/wood, 5, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
		new/datum/stack_recipe("soft wood wall", /obj/covers/wood_wall, 8, _time = 170, _one_per_turf = TRUE, _on_floor = TRUE),
		new/datum/stack_recipe("window", /obj/structure/window_frame, 5, _time = 80, _one_per_turf = TRUE, _on_floor = TRUE),
		new/datum/stack_recipe("floor tile", /obj/covers/wood, 1, _time = 25, _one_per_turf = TRUE, _on_floor = TRUE),
		new/datum/stack_recipe("floor cover", /obj/item/weapon/covers, 2, _time = 30, _one_per_turf = TRUE, _on_floor = TRUE),))

	recipes += new/datum/stack_recipe_list("barricades", list(
		new/datum/stack_recipe("horizontal wood barrier", /obj/structure/barricade/horizontal, 5, _time = 35, _one_per_turf = TRUE, _on_floor = TRUE),
		new/datum/stack_recipe("vertical wood barrier", /obj/structure/barricade/vertical, 5, _time = 35, _one_per_turf = TRUE, _on_floor = TRUE),
		new/datum/stack_recipe("wood palisade", 	/obj/structure/grille/logfence, 7, _time = 80, _one_per_turf = TRUE, _on_floor = TRUE),
		new/datum/stack_recipe("barricade", /obj/structure/barricade, 5, _time = 35, _one_per_turf = TRUE, _on_floor = TRUE,),))


	recipes += new/datum/stack_recipe_list("weapons", list(
		new/datum/stack_recipe("arrow", /obj/item/ammo_casing/arrow, 1, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE),
		new/datum/stack_recipe("bow", /obj/item/weapon/gun/projectile/bow, 6, _time = 120, _one_per_turf = FALSE, _on_floor = TRUE),
		new/datum/stack_recipe("punji sticks trap", /obj/item/weapon/punji_sticks, 4, _time = 70, _one_per_turf = FALSE, _on_floor = TRUE),
		new/datum/stack_recipe("wood shield", /obj/item/weapon/shield, 8, _time = 180, _one_per_turf = FALSE, _on_floor = TRUE),
		new/datum/stack_recipe("wood handle", /obj/item/weapon/material/handle, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
		new/datum/stack_recipe("wood spear", /obj/item/weapon/material/spear, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),))

	recipes += new/datum/stack_recipe_list("furniture", list(
		new/datum/stack_recipe("stool", /obj/item/weapon/stool, 3, _time = 35,_one_per_turf = TRUE, _on_floor = TRUE,),
		new/datum/stack_recipe("chair", /obj/structure/bed/chair/wood, 4, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
		new/datum/stack_recipe("bed", /obj/structure/bed, 4, _time = 60,_one_per_turf = TRUE, _on_floor = TRUE,),
		new/datum/stack_recipe("coffin", /obj/structure/closet/coffin, 4, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
		new/datum/stack_recipe("wood crate", /obj/structure/closet/crate/empty, 5, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
		new/datum/stack_recipe("wood chest", /obj/structure/closet/crate/chest, 7, _time = 75, _one_per_turf = TRUE, _on_floor = TRUE),
		new/datum/stack_recipe("table", /obj/structure/table/wood, 4, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
		new/datum/stack_recipe("small cross", /obj/structure/woodcross1, 2, _time = 50, _one_per_turf = TRUE, _on_floor = TRUE),
		new/datum/stack_recipe("cross", /obj/structure/woodcross2, 4, _time = 80, _one_per_turf = TRUE, _on_floor = TRUE),))
	recipes += new/datum/stack_recipe_list("kitchen & tools", list(
		new/datum/stack_recipe("wood mug",/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/wood, 1, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE),
		new/datum/stack_recipe("campfire",/obj/structure/oven/fireplace, 4, _time = 140, _one_per_turf = TRUE, _on_floor = TRUE),
		new/datum/stack_recipe("torch",/obj/item/flashlight/torch, 2, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE),
		new/datum/stack_recipe("bucket",/obj/item/weapon/reagent_containers/glass/bucket, 2, _time = 60, _one_per_turf = FALSE, _on_floor = TRUE),
		new/datum/stack_recipe("plough",/obj/item/weapon/plough, 4, _time = 120, _one_per_turf = FALSE, _on_floor = TRUE),
		new/datum/stack_recipe("plough",/obj/item/weapon/material/kitchen/rollingpin, 1, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE),
		new/datum/stack_recipe("plough",/obj/item/clothing/mask/smokable/pipe, 2, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE),
		new/datum/stack_recipe("wood bowl",/obj/item/kitchen/wood_bowl, 1, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE),))

/material/rope/generate_recipes()
	recipes = list(new/datum/stack_recipe("noose", /obj/structure/noose, _time = 20))
	recipes += list(new/datum/stack_recipe("rope handcuffs", /obj/item/weapon/handcuffs/rope, _time = 50))


/material/stone/stone/generate_recipes()
	..()
	recipes += new/datum/stack_recipe("tribal hatchet", /obj/item/weapon/material/hatchet/tribal, 2, _time = 35, _one_per_turf = FALSE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("cobblestone floor", /obj/covers/cobblestone, 2, _time = 25, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("gravestone", /obj/structure/gravestone, 3, _time = 60, _one_per_turf = TRUE, _on_floor = TRUE)

/material/tobacco/generate_recipes()
	recipes = list(new/datum/stack_recipe("cigar", /obj/item/clothing/mask/smokable/cigarette/cigar, 3, _time = 75, _one_per_turf = FALSE, _on_floor = TRUE))
	recipes += list(new/datum/stack_recipe("cuban cigar", /obj/item/clothing/mask/smokable/cigarette/cigar/havana, 5, _time = 100, _one_per_turf = FALSE, _on_floor = TRUE))

/material/poppy/generate_recipes()
	recipes = list(new/datum/stack_recipe("opium", /obj/item/weapon/reagent_containers/pill/opium, 3, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE))