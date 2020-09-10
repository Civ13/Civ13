///////////RAW MOLDS/////////////
/obj/item/weapon/clay/mold
	name = "unfired clay ingot mold"
	desc = "An unfired mould."
	icon = 'icons/obj/metallurgy.dmi'
	icon_state = "ingot_mold_raw"
	base_icon = "ingot_mold"
	result = /obj/item/weapon/clay/mold/fired
	var/fired = FALSE
	var/list/contents_materials = list()
	var/capacity = 0
	var/max_capacity = 0
	var/current_material = null

/obj/item/weapon/clay/mold/update_icon()
	..()
	if (!fired)
		icon_state = "[base_icon]_raw"
	else if (capacity > 0)
		icon_state = "[base_icon]_full"
	else
		icon_state = "[base_icon]_empty"

/obj/item/weapon/clay/mold/attackby(obj/item/I as obj, mob/user as mob)
	if (!fired)
		return
	if (istype(I, /obj/item/weapon/clay/mold/clayjug) || istype(I, /obj/item/weapon/clay/mold/claypot))
		var/obj/item/weapon/clay/mold/ML = I
		if (ML.capacity > 0 && src.capacity == 0)
			user.visible_message("[user] pours the molten [ML.current_material] into \the [src].")
			src.capacity = ML.capacity
			src.current_material = ML.current_material
			ML.current_material = null
			ML.capacity = 0
			ML.update_icon()
			src.update_icon()
	else if (istype(I, /obj/item/stack/ore))
		var/obj/item/stack/ore/O = I
		if (istype(O, /obj/item/stack/ore/gold))
			if (contents_materials.len == 0)
				contents_materials += list("gold" = O.amount)
				qdel(I)
			else if  (contents_materials.len == 1 && contents_materials["gold"])
				contents_materials["gold"] += O.amount
				qdel(I)
		else if (istype(O, /obj/item/stack/ore/silver))
			if (contents_materials.len == 0)
				contents_materials += list("silver" = O.amount)
				qdel(I)
			else if  (contents_materials.len == 1 && contents_materials["silver"])
				contents_materials["silver"] += O.amount
				qdel(I)
		else if (istype(O, /obj/item/stack/ore/copper))
			if (contents_materials.len == 0 || (contents_materials.len == 1 && contents_materials["tin"]))
				contents_materials += list("copper" = O.amount)
				qdel(I)
			else if ((contents_materials.len == 1 && contents_materials["copper"]) || (contents_materials.len == 2 && contents_materials["copper"]))
				contents_materials["copper"] += O.amount
				qdel(I)
		else if (istype(O, /obj/item/stack/ore/tin))
			if (contents_materials.len == 0 || (contents_materials.len == 1 && contents_materials["copper"]))
				contents_materials += list("tin" = O.amount)
				qdel(I)
			else if ((contents_materials.len == 1 && contents_materials["tin"]) || (contents_materials.len == 2 && contents_materials["tin"]))
				contents_materials["tin"] += O.amount
				qdel(I)
		else if (istype(O, /obj/item/stack/ore/lead))
			if (contents_materials.len == 0)
				contents_materials += list("lead" = O.amount)
				qdel(I)
			else if (contents_materials.len == 1 && contents_materials["lead"])
				contents_materials["lead"] += O.amount
				qdel(I)
		else
			user << "You cannot use this material on a kiln."
			return
		return
/obj/item/weapon/clay/mold/axehead
	name = "unfired clay axehead mold"
	icon_state = "axehead_mold_raw"
	base_icon = "axehead_mold"
	result = /obj/item/weapon/clay/mold/axehead/fired


/obj/item/weapon/clay/mold/sword
	name = "unfired clay sword mold"
	icon_state = "sword_mold_raw"
	base_icon = "sword_mold"
	result = /obj/item/weapon/clay/mold/sword/fired


/obj/item/weapon/clay/mold/knife
	name = "unfired clay knife mold"
	icon_state = "knife_mold_raw"
	base_icon = "knife_mold"
	result = /obj/item/weapon/clay/mold/knife/fired


/obj/item/weapon/clay/mold/spearhead
	name = "unfired clay spearhead mold"
	icon_state = "spearhead_mold_raw"
	base_icon = "spearhead_mold"
	result = /obj/item/weapon/clay/mold/spearhead/fired


/obj/item/weapon/clay/mold/pickaxe
	name = "unfired clay pickaxe mold"
	icon_state = "pickaxe_mold_raw"
	base_icon = "pickaxe_mold"
	result = /obj/item/weapon/clay/mold/pickaxe/fired


/obj/item/weapon/clay/mold/shovel
	name = "unfired clay shovel mold"
	icon_state = "shovel_mold_raw"
	base_icon = "shovel_mold"
	result = /obj/item/weapon/clay/mold/shovel/fired


/obj/item/weapon/clay/mold/arrowhead
	name = "unfired clay arrowhead mold"
	icon_state = "arrowhead_mold_raw"
	base_icon = "arrowhead_mold"
	result = /obj/item/weapon/clay/mold/arrowhead/fired


/obj/item/weapon/clay/mold/claypot
	name = "unfired clay blacksmith pot"
	desc = "An unfired blacksmith pot."
	icon_state = "clay_pot_raw"
	base_icon = "clay_pot"
	result = /obj/item/weapon/clay/mold/claypot/fired

/obj/item/weapon/clay/mold/clayjug
	name = "unfired clay blacksmith jug"
	desc = "An unfired blacksmith jug."
	icon_state = "clay_jug_raw"
	base_icon = "clay_jug"
	result = /obj/item/weapon/clay/mold/clayjug/fired

//////FIRED MOLDS/////////
/obj/item/weapon/clay/mold/fired
	name = "ingot mold"
	desc = "A mold."
	icon_state = "ingot_mold_empty"
	base_icon = "ingot_mold"
	fired = TRUE

/obj/item/weapon/clay/mold/axehead/fired
	name = "axehead mold"
	icon_state = "axehead_mold_empty"
	base_icon = "axehead_mold"
	fired = TRUE

/obj/item/weapon/clay/mold/sword/fired
	name = "sword mold"
	icon_state = "sword_mold_empty"
	base_icon = "sword_mold"
	fired = TRUE

/obj/item/weapon/clay/mold/knife/fired
	name = "knife mold"
	icon_state = "knife_mold_empty"
	base_icon = "knife_mold"
	fired = TRUE

/obj/item/weapon/clay/mold/spearhead/fired
	name = "spearhead mold"
	icon_state = "spearhead_mold_empty"
	base_icon = "spearhead_mold"
	fired = TRUE

/obj/item/weapon/clay/mold/pickaxe/fired
	name = "pickaxe mold"
	icon_state = "pickaxe_mold_empty"
	base_icon = "pickaxe_mold"
	fired = TRUE

/obj/item/weapon/clay/mold/shovel/fired
	name = "shovel mold"
	icon_state = "shovel_mold_empty"
	base_icon = "shovel_mold"
	fired = TRUE

/obj/item/weapon/clay/mold/arrowhead/fired
	name = "arrowhead mold"
	icon_state = "arrowhead_mold_empty"
	base_icon = "arrowhead_mold"
	fired = TRUE

/obj/item/weapon/clay/mold/claypot/fired
	name = "clay blacksmith pot"
	desc = "A blacksmith pot."
	icon_state = "clay_pot_empty"
	base_icon = "clay_pot"
	fired = TRUE
	max_capacity = 20

/obj/item/weapon/clay/mold/clayjug/fired
	name = "clay blacksmith jug"
	desc = "A blacksmith jug."
	icon_state = "clay_jug_empty"
	base_icon = "clay_jug"
	fired = TRUE
	max_capacity = 70
