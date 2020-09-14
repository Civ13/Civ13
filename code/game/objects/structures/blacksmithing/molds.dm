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
	var/craftable_classes = null

/obj/item/weapon/clay/mold/update_icon()
	..()
	if (!fired)
		icon_state = "[base_icon]_raw"
	else if (capacity > 0)
		icon_state = "[base_icon]_full"
	else
		icon_state = "[base_icon]_empty"

/obj/item/weapon/clay/mold/examine(mob/user)
	if (capacity > 0)
		user << "Has [capacity] unit[capacity > 1 ? "s" : ""] of [current_material] in it."
/obj/item/weapon/clay/mold/attackby(obj/item/I as obj, mob/user as mob)
	if (!fired)
		return
	if (istype(I, /obj/item/weapon/clay/mold))
		var/obj/item/weapon/clay/mold/ML = I
		if (ML.fired && ML.capacity > 0 && (src.capacity < src.max_capacity) && (src.current_material == ML.current_material || !src.current_material))
			var/amt_to_transfer = min(max_capacity - capacity, ML.capacity)
			var/input = input(user, "Transfer", "How much of the [ML.current_material] do you want to transfer? Free capacity: [amt_to_transfer]", amt_to_transfer) as num
			if (!isnum(input))
				return
			else if (input <= 0)
				return
			else if (input > amt_to_transfer)
				input = amt_to_transfer
			amt_to_transfer = input
			user.visible_message("[user] pours [amt_to_transfer] unit[amt_to_transfer > 1 ? "s" : ""] of [ML.current_material] into the molten [ML.current_material] into \the [src].")
			src.capacity += amt_to_transfer
			src.current_material = ML.current_material
			ML.current_material = null
			ML.capacity -= amt_to_transfer
			ML.update_icon()
			src.update_icon()
	else if (istype(I, /obj/item/stack/ore) || istype(I, /obj/item/stack/material))
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
		else if (istype(O, /obj/item/stack/material/iron))
			if (contents_materials.len == 0)
				contents_materials += list("iron" = O.amount)
				qdel(I)
			else if (contents_materials.len == 1 && contents_materials["iron"])
				contents_materials["iron"] += O.amount
				qdel(I)
		else if (istype(O, /obj/item/stack/material/steel))
			if (contents_materials.len == 0)
				contents_materials += list("steel" = O.amount)
				qdel(I)
			else if (contents_materials.len == 1 && contents_materials["steel"])
				contents_materials["steel"] += O.amount
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
	craftable_classes = "ingots"
	max_capacity = 100

/obj/item/weapon/clay/mold/axehead/fired
	name = "axehead mold"
	icon_state = "axehead_mold_empty"
	base_icon = "axehead_mold"
	fired = TRUE
	craftable_classes = "axes"
	max_capacity = 5

/obj/item/weapon/clay/mold/sword/fired
	name = "sword mold"
	icon_state = "sword_mold_empty"
	base_icon = "sword_mold"
	fired = TRUE
	craftable_classes = "swords"
	max_capacity = 40

/obj/item/weapon/clay/mold/knife/fired
	name = "knife mold"
	icon_state = "knife_mold_empty"
	base_icon = "knife_mold"
	fired = TRUE
	craftable_classes = "knives"
	max_capacity = 10

/obj/item/weapon/clay/mold/spearhead/fired
	name = "spearhead mold"
	icon_state = "spearhead_mold_empty"
	base_icon = "spearhead_mold"
	fired = TRUE
	craftable_classes = "spearheads"
	max_capacity = 3

/obj/item/weapon/clay/mold/pickaxe/fired
	name = "pickaxe mold"
	icon_state = "pickaxe_mold_empty"
	base_icon = "pickaxe_mold"
	fired = TRUE
	craftable_classes = "pickaxes"
	max_capacity = 3

/obj/item/weapon/clay/mold/shovel/fired
	name = "shovel mold"
	icon_state = "shovel_mold_empty"
	base_icon = "shovel_mold"
	fired = TRUE
	craftable_classes = "shovels"
	max_capacity = 3

/obj/item/weapon/clay/mold/arrowhead/fired
	name = "arrowhead mold"
	icon_state = "arrowhead_mold_empty"
	base_icon = "arrowhead_mold"
	fired = TRUE
	craftable_classes = "arrowheads"
	max_capacity = 50

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
