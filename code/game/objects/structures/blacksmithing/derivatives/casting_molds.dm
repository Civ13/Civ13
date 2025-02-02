
// Hammer
/obj/item/claymold/hammer
	name = "\improper hammer mold"
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "hammermold"
	mold_result = /obj/item/heatable/forged/hammer
	ingot_value = 1
	allowed_metals = list(
		"/obj/item/heatable/ingot/copper",
		"/obj/item/heatable/ingot/bronze",
		)


// Pickaxe
/obj/item/claymold/pickaxe
	name = "\improper pickaxe mold"
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "pickaxemold"
	mold_result = /obj/item/heatable/forged/pickaxe
	ingot_value = 2
	allowed_metals = list(
		"/obj/item/heatable/ingot/copper",
		"/obj/item/heatable/ingot/bronze",
		)


// Hatchet
/obj/item/claymold/hatchet
	name = "\improper hatchet mold"
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "hatchetmold"
	mold_result = /obj/item/heatable/forged/hatchet
	ingot_value = 1
	allowed_metals = list(
		"/obj/item/heatable/ingot/copper",
		"/obj/item/heatable/ingot/bronze",
		)


// Shovel
/obj/item/claymold/shovel
	name = "\improper shovel mold"
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "shovelmold"
	mold_result = /obj/item/heatable/forged/shovel
	ingot_value = 1
	allowed_metals = list(
		"/obj/item/heatable/ingot/copper",
		"/obj/item/heatable/ingot/bronze",
		)


// Tongs
/obj/item/claymold/tongs
	name = "\improper tongs mold"
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "tongsmold"
	mold_result = /obj/item/heatable/forged/tongs
	ingot_value = 1
	allowed_metals = list(
		"/obj/item/heatable/ingot/copper",
		"/obj/item/heatable/ingot/bronze",
		)


// Spear
/obj/item/claymold/spear
	name = "\improper spear mold"
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "spearmold"
	mold_result = /obj/item/heatable/forged/weapon/spear
	ingot_value = 1
	allowed_metals = list(
		"/obj/item/heatable/ingot/copper",
		"/obj/item/heatable/ingot/bronze",
		)


// Anvil
/obj/item/claymold/anvil
	name = "\improper anvil mold"
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "anvilmold"
	mold_result = /obj/structure/anvil
	ingot_value = 2
	allowed_metals = list(
		"/obj/item/heatable/ingot/copper",
		"/obj/item/heatable/ingot/bronze",
		)

/obj/item/claymold/anvil/result()
	var/new_item
	switch(metal_contained)
		if("/obj/item/heatable/ingot/copper")
			new_item = new /obj/structure/anvil/copper(get_turf(src))
		if("/obj/item/heatable/ingot/bronze")
			new_item = new /obj/structure/anvil/bronze(get_turf(src))
	qdel(src)
	return new_item


// Arrowhead
/obj/item/claymold/arrowhead
	name = "\improper arrowhead mold"
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "arrowheadmold"
	mold_result = /obj/item/stack/arrowhead
	ingot_value = 1
	allowed_metals = list(
		"/obj/item/heatable/ingot/copper",
		"/obj/item/heatable/ingot/bronze",
		)

/obj/item/claymold/arrowhead/result()
	var/new_item
	switch(metal_contained)
		if("/obj/item/heatable/ingot/copper")
			new_item = new /obj/item/stack/arrowhead/copper(get_turf(src))
		if("/obj/item/heatable/ingot/bronze")
			new_item = new /obj/item/stack/arrowhead/bronze(get_turf(src))
	return new_item


// Sheets
/obj/item/claymold/sheet
	name = "\improper sheet mold"
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "sheetmold"
	mold_result = /obj/item/stack/material
	ingot_value = 1
	allowed_metals = list(
		"/obj/item/heatable/ingot/copper",
		"/obj/item/heatable/ingot/bronze",
		)

/obj/item/claymold/arrowhead/result()
	var/new_item
	switch(metal_contained)
		if("/obj/item/heatable/ingot/copper")
			new_item = new /obj/item/stack/material/copper(get_turf(src))
		if("/obj/item/heatable/ingot/bronze")
			new_item = new /obj/item/stack/material/bronze(get_turf(src))
	var/obj/item/stack/S = new_item
	S.amount = INGOT_VALUE
	S.update_icon()
	return new_item


// Knife
/obj/item/claymold/knife
	name = "\improper anvil mold"
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "knifemold"
	mold_result = /obj/item/weapon/material/kitchen/utensil/knife
	ingot_value = 1
	allowed_metals = list(
		"/obj/item/heatable/ingot/bronze",
		)

/obj/item/claymold/knife/result()
	var/new_item
	switch(metal_contained)
		if("/obj/item/heatable/ingot/bronze")
			new_item = new /obj/item/weapon/material/kitchen/utensil/knife/bronze(get_turf(src))
	return new_item


// Ingot
/obj/item/claymold/ingot
	name = "\improper ingot mold"
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "ingotmold"
	mold_result = /obj/item/heatable/ingot
	ingot_value = 1
	allowed_metals = list(
		"/obj/item/heatable/ingot/copper",
		"/obj/item/heatable/ingot/bronze",
		"/obj/item/heatable/ingot/brass",
		"/obj/item/heatable/ingot/tin",
		"/obj/item/heatable/ingot/lead",
		"/obj/item/heatable/ingot/wroughtiron",
		"/obj/item/heatable/ingot/steel"
		)