///////////RAW MOLDS/////////////
/obj/item/weapon/clay/mold
	name = "unfired clay ingot mold"
    desc = "An unfired mould."
	icon = 'icons/obj/metallurgy.dmi'
	icon_state = "ingot_mold_raw"
	base_icon = "ingot_mold"
	result = /obj/item/weapon/clay/mold/fired
	var/fired = FALSE
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

/obj/item/weapon/clay/mold/attackby(obj/item/W as obj, mob/user as mob)
	if (!fired)
		return
	if (istype(W, /obj/item/weapon/clay/mold/clayjug) || istype(W, /obj/item/weapon/clay/mold/claypot))
		var/obj/item/weapon/clay/mold/ML = W
		if (ML.capacity > 0 && src.capacity == 0)
			user.visible_message("[user] pours the molten [ML.material] into \the [src].")
			src.capacity = ML.capacity
			src.current_material = ML.current_material
			ML.current_material = null
			ML.capacity = 0
			ML.update_icon()
			src.update_icon()

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
	name = "unfired clay ingot mold"
    desc = "A mould."
	icon_state = "ingot_mold_empty"
	base_icon = "ingot_mold"
	fired = TRUE

/obj/item/weapon/clay/mold/axehead/fired
	name = "unfired clay axehead mold"
	icon_state = "axehead_mold_empty"
	base_icon = "axehead_mold"
	fired = TRUE

/obj/item/weapon/clay/mold/sword/fired
	name = "unfired clay sword mold"
	icon_state = "sword_mold_empty"
	base_icon = "sword_mold"
	fired = TRUE

/obj/item/weapon/clay/mold/knife/fired
	name = "unfired clay knife mold"
	icon_state = "knife_mold_empty"
	base_icon = "knife_mold"
	fired = TRUE

/obj/item/weapon/clay/mold/spearhead/fired
	name = "unfired clay spearhead mold"
	icon_state = "spearhead_mold_empty"
	base_icon = "spearhead_mold"
	fired = TRUE

/obj/item/weapon/clay/mold/pickaxe/fired
	name = "unfired clay pickaxe mold"
	icon_state = "pickaxe_mold_empty"
	base_icon = "pickaxe_mold"
	fired = TRUE

/obj/item/weapon/clay/mold/shovel/fired
	name = "unfired clay shovel mold"
	icon_state = "shovel_mold_empty"
	base_icon = "shovel_mold"
	fired = TRUE

/obj/item/weapon/clay/mold/arrowhead/fired
	name = "unfired clay arrowhead mold"
	icon_state = "arrowhead_mold_empty"
	base_icon = "arrowhead_mold"
	fired = TRUE

/obj/item/weapon/clay/mold/claypot/fired
	name = "unfired clay blacksmith pot"
	desc = "A blacksmith pot."
	icon_state = "clay_pot_empty"
	base_icon = "clay_pot"
	fired = TRUE
	max_capacity = 20

/obj/item/weapon/clay/mold/clayjug/fired
	name = "unfired clay blacksmith jug"
    desc = "A blacksmith jug."
	icon_state = "clay_jug_empty"
	base_icon = "clay_jug"
	fired = TRUE
	max_capacity = 70
