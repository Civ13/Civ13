var/list/engineer_exclusive_recipe_types = null

/material/proc/get_recipes()
	if (!recipes)
		generate_recipes()
	return recipes

/material/proc/generate_recipes()
	recipes = list()

	// If is_brittle() returns true, these are only good for a single strike.
	recipes += new/datum/stack_recipe("[display_name] ashtray", /obj/item/weapon/material/ashtray, 2, _one_per_turf = TRUE, _on_floor = TRUE, _supplied_material = "[name]")
	recipes += new/datum/stack_recipe("[display_name] spoon", /obj/item/weapon/material/kitchen/utensil/spoon/plastic, TRUE, _on_floor = TRUE, _supplied_material = "[name]")

	if (integrity>=50)
	//	recipes += new/datum/stack_recipe("[display_name] door", /obj/machinery/door/unpowered/simple, 10, _time = 35, _one_per_turf = TRUE, _on_floor = TRUE, _supplied_material = "[name]")
		recipes += new/datum/stack_recipe("[display_name] barricade", /obj/structure/barricade, 5, _time = 35, _one_per_turf = TRUE, _on_floor = TRUE, _supplied_material = "[name]")
		recipes += new/datum/stack_recipe("[display_name] stool", /obj/item/weapon/stool, 3, _one_per_turf = TRUE, _on_floor = TRUE, _supplied_material = "[name]")
		if (!istype(src, /material/wood))
			recipes += new/datum/stack_recipe("[display_name] chair", /obj/structure/bed/chair, 3, _one_per_turf = TRUE, _on_floor = TRUE, _supplied_material = "[name]")
		recipes += new/datum/stack_recipe("[display_name] bed", /obj/structure/bed, 4, _one_per_turf = TRUE, _on_floor = TRUE, _supplied_material = "[name]")

	if (hardness>50)
		recipes += new/datum/stack_recipe("[display_name] fork", /obj/item/weapon/material/kitchen/utensil/fork/plastic, TRUE, _on_floor = TRUE, _supplied_material = "[name]")
		recipes += new/datum/stack_recipe("[display_name] knife", /obj/item/weapon/material/kitchen/utensil/knife/plastic, TRUE, _on_floor = TRUE, _supplied_material = "[name]")

/material/leather/generate_recipes()
	..()

	recipes += new/datum/stack_recipe_list("comfy chairs", list( \
		new/datum/stack_recipe("beige comfy chair", /obj/structure/bed/chair/comfy/beige, 3, _one_per_turf = TRUE, _on_floor = TRUE), \
		new/datum/stack_recipe("black comfy chair", /obj/structure/bed/chair/comfy/black, 3, _one_per_turf = TRUE, _on_floor = TRUE), \
		new/datum/stack_recipe("brown comfy chair", /obj/structure/bed/chair/comfy/brown, 3, _one_per_turf = TRUE, _on_floor = TRUE), \
		new/datum/stack_recipe("lime comfy chair", /obj/structure/bed/chair/comfy/lime, 3, _one_per_turf = TRUE, _on_floor = TRUE), \
		new/datum/stack_recipe("teal comfy chair", /obj/structure/bed/chair/comfy/teal, 3, _one_per_turf = TRUE, _on_floor = TRUE), \
		new/datum/stack_recipe("red comfy chair", /obj/structure/bed/chair/comfy/red, 3, _one_per_turf = TRUE, _on_floor = TRUE), \
		new/datum/stack_recipe("blue comfy chair", /obj/structure/bed/chair/comfy/blue, 3, _one_per_turf = TRUE, _on_floor = TRUE), \
		new/datum/stack_recipe("purple comfy chair", /obj/structure/bed/chair/comfy/purp, 3, _one_per_turf = TRUE, _on_floor = TRUE), \
		new/datum/stack_recipe("green comfy chair", /obj/structure/bed/chair/comfy/green, 3, _one_per_turf = TRUE, _on_floor = TRUE), \
		))

/material/steel/generate_recipes()
	..()

	recipes += new/datum/stack_recipe("table", /obj/structure/table, 4, _time = 7, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("rack", /obj/structure/table/rack, 2, _time = 5, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("metal rod", /obj/item/stack/rods, TRUE, 2, 60)
	recipes += new/datum/stack_recipe("railing", /obj/structure/railing, 2, _time = 50, _one_per_turf = FALSE, _on_floor = TRUE)

	recipes += new/datum/stack_recipe("unlocked door", /obj/structure/simple_door/key_door/anyone, 5, _time = 35, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("locked door", /obj/structure/simple_door/key_door/anyone, 5, _time = 35, _one_per_turf = TRUE, _on_floor = TRUE)

/material/wood/generate_recipes()
	..()
	recipes += new/datum/stack_recipe("sandals", /obj/item/clothing/shoes/sandal, TRUE)
	recipes += new/datum/stack_recipe("floor tile", /obj/item/stack/tile/wood, TRUE, 4, 20)
	recipes += new/datum/stack_recipe("chair", /obj/structure/bed/chair/wood, 3, _time = 7, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("coffin", /obj/structure/closet/coffin, 4, _time = 10, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("book shelf", /obj/structure/bookcase, 4, _time = 10, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("door", /obj/structure/simple_door/key_door/anyone/wood, 5, _time = 30, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("table", /obj/structure/table/wood, 4, _time = 7, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("window frame", /obj/structure/window_frame, 3, _time = 30, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("horizontal wood barrier", /obj/structure/barricade/horizontal, 5, _time = 35, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("vertical wood barrier", /obj/structure/barricade/vertical, 5, _time = 35, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("floor cover", /obj/item/weapon/covers, 2, _time = 30, _one_per_turf = TRUE, _on_floor = TRUE)
	recipes += new/datum/stack_recipe("arrow", /obj/item/ammo_casing/arrow, 1, _time = 40, _one_per_turf = FALSE, _on_floor = TRUE)


/material/rope/generate_recipes()
	recipes = list(new/datum/stack_recipe("noose", /obj/structure/noose, _time = 20))