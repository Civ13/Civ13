#define DYNAMIC_AMT -1

// increase or decrease the amount of items in a crate
/*/obj/structure/closet/crate/proc/resize(decimal)
	if (decimal > 1.0)
		var/add_crates = max(1, ceil((decimal - 1.0) * contents.len))
		for (var/v in 1 to add_crates)
			if (!contents.len)
				break
			var/atom/object = pick(contents)
			if (object)
				var/object_type = object.type
				new object_type(src)

	else if (decimal < 1.0)
		var/remove_crates = ceil((1.0 - decimal) * contents.len)
		for (var/v in 1 to remove_crates)
			if (!contents.len)
				break
			contents -= pick(contents)
	update_capacity(contents.len)
	*/
/obj/structure/closet/crate/var/list/paths = list() // typepath = amount

/obj/structure/closet/crate/New()
	..()
	crate_list += src
	for (var/typepath in paths)
		var/limit = paths[typepath]
		if (limit == DYNAMIC_AMT)
			var/atom/ref = new typepath (null)
			limit = max(3, min(ceil(75/round(ref.contents.len/2)), 12))
			if (ref.contents.len < 100)
				limit += pick(2,3)
			qdel(ref)
		for (var/v in 1 to limit)
			new typepath (src)
	update_capacity(contents.len)

/obj/structure/closet/crate/Destroy()
	crate_list -= src
	..()

// new crate icons from F13 - most are unused

/* todo: turn some crates into CARTS and re-enable this
/obj/structure/closet/crate
	icon = 'icons/obj/crate.dmi'*/

/obj/structure/closet/crate/empty
	name = "Crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"

/obj/structure/closet/crate/wood
	name = "Wood planks crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/stack/material/wood = 5)

/obj/structure/closet/crate/wood/New()
	..()
	for (var/stack in contents)
		var/obj/item/stack/S = stack
		S.amount = 20

/obj/structure/closet/crate/steel
	name = "Steel sheets crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/stack/material/steel = 5)

/obj/structure/closet/crate/steel/New()
	..()
	for (var/stack in contents)
		var/obj/item/stack/S = stack
		S.amount = 20

/obj/structure/closet/crate/iron
	name = "Iron ingots crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/stack/material/iron = 5)

/obj/structure/closet/crate/iron/New()
	..()
	for (var/stack in contents)
		var/obj/item/stack/S = stack
		S.amount = 20

/obj/structure/closet/crate/glass
	name = "Glass sheets crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/stack/material/glass = 5)

/obj/structure/closet/crate/glass/New()
	..()
	for (var/stack in contents)
		var/obj/item/stack/S = stack
		S.amount = 20
/obj/structure/closet/crate/rations/
	name = "Rations"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"

/obj/structure/closet/crate/rations/New()
	..()
	update_capacity(30)
	var/textpath = "[type]"
	if (findtext(textpath, GERMAN))
		if (findtext(textpath, "solids"))
			for (var/v in 1 to rand(10,15))
				contents += new_ration(GERMAN, "solid")
		if (findtext(textpath, "liquids"))
			for (var/v in 1 to rand(10,15))
				contents += new_ration(GERMAN, "liquid")
		if (findtext(textpath, "desserts"))
			for (var/v in 1 to rand(10,15))
				contents += new_ration(GERMAN, "dessert")
		if (findtext(textpath, "meat"))
			for (var/v in 1 to rand(10,15))
				contents += new_ration(GERMAN, "meat")
		if (findtext(textpath, "alcohol"))
			for (var/v in 1 to rand(10,15))
				contents += beer_ration()
	else if (findtext(textpath, "soviet"))
		if (findtext(textpath, "solids"))
			for (var/v in 1 to rand(10,15))
				contents += new_ration(SOVIET, "solid")
		if (findtext(textpath, "liquids"))
			for (var/v in 1 to rand(10,15))
				contents += new_ration(SOVIET, "liquid")
	/*	if (findtext(textpath, "desserts"))
			for (var/v in 1 to rand(10,15))
				contents += new_ration("SOVIET", "dessert")*/
		if (findtext(textpath, "meat"))
			for (var/v in 1 to rand(10,15))
				contents += new_ration(SOVIET, "meat")
		if (findtext(textpath, "alcohol"))
			for (var/v in 1 to rand(10,15))
				contents += vodka_ration()

	else if (findtext(textpath, "water"))
		for (var/v in 1 to rand(20,30))
			contents += water_ration()

	update_capacity(min(30, contents.len+5))


/obj/structure/closet/crate/rations/german_solids
	name = "Rations: solids"

/obj/structure/closet/crate/rations/german_liquids
	name = "Rations: liquids"

/obj/structure/closet/crate/rations/german_desserts
	name = "Rations: dessert"

/obj/structure/closet/crate/rations/german_meat
	name = "Rations: meat"

/obj/structure/closet/crate/rations/german_alcohol
	name = "Rations: bier"

/obj/structure/closet/crate/rations/soviet_solids
	name = "Rations: solids"

/obj/structure/closet/crate/rations/soviet_liquids
	name = "Rations: liquids"

/*
/obj/structure/closet/crate/rations/soviet_desserts
	name = "Rations: dessert"*/

/obj/structure/closet/crate/rations/soviet_meat
	name = "Rations: meat"

/obj/structure/closet/crate/rations/soviet_alcohol
	name = "Rations: vodka"

/obj/structure/closet/crate/rations/water
	name = "Rations: water"

#undef DYNAMIC_AMT