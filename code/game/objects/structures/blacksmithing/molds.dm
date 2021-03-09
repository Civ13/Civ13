///////////RAW MOLDS/////////////
/obj/item/weapon/clay/mold
	name = "unfired clay ingot mold"
	desc = "An unfired mold."
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
	..()
	if (capacity > 0)
		user << "Has [capacity] unit[capacity > 1 ? "s" : ""] of [current_material] in it."
	if (contents_materials.len)
		for (var/i in contents_materials)
			if (contents_materials[i]>0)
				user << "Has <b>[contents_materials[i]]</b> unit[contents_materials[i] > 1 ? "s" : ""] of [i] in it."
	if (max_capacity > 0)
		user << "Has a maximum capacity of <b>[max_capacity]</b> units."
/obj/item/weapon/clay/mold/attackby(obj/item/I as obj, mob/user as mob)
	if (!fired)
		user << "<span class='warning'>[src] is unfired!</span>"
		return
	if (istype(I, /obj/item/weapon/clay/mold))
		var/obj/item/weapon/clay/mold/ML = I
		if (!ML.fired)
			user << "<span class='warning'>[ML] is unfired!</span>"
			return
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
			ML.capacity -= amt_to_transfer
			if (ML.capacity <= 1)
				ML.current_material = null
			ML.update_icon()
			src.update_icon()
	else if (istype(I, /obj/item/stack/ore) || istype(I, /obj/item/stack/material))
		if (istype(src, /obj/item/weapon/clay/mold/clayjug) || istype(src, /obj/item/weapon/clay/mold/claypot))
			var/current_cap = 0
			for (var/i in contents_materials)
				current_cap += contents_materials[i]
			if (current_cap >= max_capacity)
				user << "<span class='warning'>[src] is full!</span>"
				return
			var/max_free_cap = max_capacity-current_cap
			var/obj/item/stack/O = I
			var/cap_to_add = min(max_free_cap, O.amount)
			if (istype(O, /obj/item/stack/ore/gold))
				if (contents_materials.len == 0)
					contents_materials += list("gold" = cap_to_add)
					O.amount -= cap_to_add
					if (O.amount <= 0)
						qdel(O)
					user << "You put some [O] in \the [src]."
				else if  (contents_materials.len == 1 && contents_materials["gold"])
					contents_materials["gold"] += cap_to_add
					O.amount -= cap_to_add
					if (O.amount <= 0)
						qdel(O)
					user << "You put some [O] in \the [src]."
			else if (istype(O, /obj/item/stack/ore/silver))
				if (contents_materials.len == 0)
					contents_materials += list("silver" = cap_to_add)
					O.amount -= cap_to_add
					if (O.amount <= 0)
						qdel(O)
					user << "You put some [O] in \the [src]."
				else if  (contents_materials.len == 1 && contents_materials["silver"])
					contents_materials["silver"] += cap_to_add
					O.amount -= cap_to_add
					if (O.amount <= 0)
						qdel(O)
					user << "You put some [O] in \the [src]."
			else if (istype(O, /obj/item/stack/ore/copper))
				if (contents_materials.len == 0 || (contents_materials.len == 1 && contents_materials["tin"]))
					contents_materials += list("copper" = cap_to_add)
					O.amount -= cap_to_add
					if (O.amount <= 0)
						qdel(O)
					user << "You put some [O] in \the [src]."
				else if ((contents_materials.len == 1 && contents_materials["copper"]) || (contents_materials.len == 2 && contents_materials["copper"]))
					contents_materials["copper"] += cap_to_add
					O.amount -= cap_to_add
					if (O.amount <= 0)
						qdel(O)
					user << "You put some [O] in \the [src]."
			else if (istype(O, /obj/item/stack/ore/tin))
				if (contents_materials.len == 0 || (contents_materials.len == 1 && contents_materials["copper"]))
					contents_materials += list("tin" = cap_to_add)
					O.amount -= cap_to_add
					if (O.amount <= 0)
						qdel(O)
					user << "You put some [O] in \the [src]."
				else if ((contents_materials.len == 1 && contents_materials["tin"]) || (contents_materials.len == 2 && contents_materials["tin"]))
					contents_materials["tin"] += cap_to_add
					O.amount -= cap_to_add
					if (O.amount <= 0)
						qdel(O)
					user << "You put some [O] in \the [src]."
			else if (istype(O, /obj/item/stack/ore/lead))
				if (contents_materials.len == 0)
					contents_materials += list("lead" = cap_to_add)
					O.amount -= cap_to_add
					if (O.amount <= 0)
						qdel(O)
					user << "You put some [O] in \the [src]."
				else if (contents_materials.len == 1 && contents_materials["lead"])
					contents_materials["lead"] += cap_to_add
					O.amount -= cap_to_add
					if (O.amount <= 0)
						qdel(O)
					user << "You put some [O] in \the [src]."
			else if (istype(O, /obj/item/stack/material/iron))
				if (contents_materials.len == 0)
					contents_materials += list("iron" = cap_to_add)
					O.amount -= cap_to_add
					if (O.amount <= 0)
						qdel(O)
					user << "You put some [O] in \the [src]."
				else if (contents_materials.len == 1 && contents_materials["iron"])
					contents_materials["iron"] += cap_to_add
					O.amount -= cap_to_add
					if (O.amount <= 0)
						qdel(O)
					user << "You put some [O] in \the [src]."
			else if (istype(O, /obj/item/stack/material/steel))
				if (contents_materials.len == 0)
					contents_materials += list("steel" = cap_to_add)
					O.amount -= cap_to_add
					if (O.amount <= 0)
						qdel(O)
					user << "You put some [O] in \the [src]."
				else if (contents_materials.len == 1 && contents_materials["steel"])
					contents_materials["steel"] += cap_to_add
					O.amount -= cap_to_add
					if (O.amount <= 0)
						qdel(O)
					user << "You put some [O] in \the [src]."
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

/obj/item/weapon/clay/mold/key
	name = "unfired clay guard key mold"
	icon_state = "key_mold_raw"
	base_icon = "key_mold"
	result = /obj/item/weapon/clay/mold/key/fired
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
	max_capacity = 10

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
	max_capacity = 20

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

/obj/item/weapon/clay/mold/key/fired
	name = "key mold"
	icon_state = "key_mold_empty"
	base_icon = "key_mold"
	fired = TRUE
	craftable_classes = "keys"
	max_capacity = 3