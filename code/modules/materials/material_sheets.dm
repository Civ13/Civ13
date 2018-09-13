#define SHEET_MATERIAL_AMOUNT 2000
// Stacked resources. They use a material datum for a lot of inherited values.
/obj/item/stack/material
	force = WEAPON_FORCE_NORMAL
	throwforce = WEAPON_FORCE_NORMAL
	w_class = 3.0
	throw_speed = 3
	throw_range = 3
	max_amount = 50

	var/default_type = DEFAULT_WALL_MATERIAL
	var/material/material
	var/perunit = SHEET_MATERIAL_AMOUNT
	var/apply_colour //temp pending icon rewrite

/obj/item/stack/material/New()
	..()
	pixel_x = rand(0,4)-4
	pixel_y = rand(0,4)-4

	if (!default_type)
		default_type = DEFAULT_WALL_MATERIAL
	material = get_material_by_name("[default_type]")

	recipes = material.get_recipes()
	stacktype = material.stack_type
/*	if (islist(material.stack_origin_tech))
		origin_tech = material.stack_origin_tech.Copy()*/

	if (apply_colour)
		color = material.icon_colour

	if (material.conductive)
		flags |= CONDUCT

	matter = material.get_matter()
	update_strings()
	return TRUE

/obj/item/stack/material/get_material()
	return material

/obj/item/stack/material/proc/update_strings()
	// Update from material datum.
	singular_name = material.sheet_singular_name

	if (amount>1)
		name = "[material.use_name] [material.sheet_plural_name]"
		desc = "A stack of [material.use_name] [material.sheet_plural_name]."
		gender = PLURAL
	else
		name = "[material.use_name] [material.sheet_singular_name]"
		desc = "A [material.sheet_singular_name] of [material.use_name]."
		gender = NEUTER

/obj/item/stack/material/use(var/used)
	. = ..()
	update_strings()
	return

/obj/item/stack/material/transfer_to(obj/item/stack/S, var/tamount=null, var/type_verified)
	var/obj/item/stack/material/M = S
	if (!istype(M) || material.name != M.material.name)
		return FALSE
	var/transfer = ..(S,tamount,1)
	if (src) update_strings()
	if (M) M.update_strings()
	return transfer

/obj/item/stack/material/attack_self(var/mob/user)
//	if (!material.build_windows(user, src))
	..()

/obj/item/stack/material/attackby(var/obj/item/W, var/mob/user)
	if (istype(W, /obj/item/stack/rods))
		material.build_rod_product(user, W, src)
		return
	return ..()

/obj/item/stack/material/iron
	name = "iron"
	icon_state = "sheet-iron"
	default_type = "iron"
	apply_colour = TRUE
	value = 3

/obj/item/stack/material/iron/twentyfive
	amount = 25

/obj/item/stack/material/sandstone
	name = "sandstone brick"
	icon_state = "sheet-sandstone"
	default_type = "sandstone"
	value = 2

/obj/item/stack/material/stone
	name = "stone block"
	icon_state = "sheet-stone"
	default_type = "stone"
	value = 2

/obj/item/stack/material/marble
	name = "marble brick"
	icon_state = "sheet-marble"
	default_type = "marble"
	value = 3

/obj/item/stack/material/diamond
	name = "diamond"
	icon_state = "sheet-diamond"
	default_type = "diamond"
	value = 40

/obj/item/stack/material/rope
	name = "Rope"
	icon_state = "rope"
	default_type = "rope"
	value = 2

/obj/item/stack/material/tobacco
	name = "tobacco leaves"
	icon_state = "tobacco"
	default_type = "tobacco"
	value = 3
	w_class = 1.0

/obj/item/stack/material/poppy
	name = "poppy"
	desc = "dried opium poppies. Opium can be extracted."
	icon_state = "poppy"
	default_type = "poppy"
	value = 6

/obj/item/stack/material/rope/attackby(var/obj/item/W, var/mob/M)
	if (anchored)
		return FALSE
	else
		return ..()

/obj/item/stack/material/rope/attack_hand(var/mob/M)
	if (ishuman(M))
		var/mob/living/carbon/human/H = M
		if (H.hand && H.l_hand && H.l_hand.type == /obj/item/stack/material/rope)
			return
		else if (!H.hand && H.r_hand && H.r_hand.type == /obj/item/stack/material/rope)
			return
		var/obj/rope = new /obj/item/stack/material/rope
		rope.anchored = FALSE
		if (H.put_in_any_hand_if_possible(rope, prioritize_active_hand = TRUE))
			--amount
			visible_message("<span class = 'warning'>[H] takes a coil of rope from the pile of rope.</span>")
			if (amount < 1)
				qdel(src)


/obj/item/stack/material/gold
	name = "gold"
	icon_state = "sheet-gold"
	default_type = "gold"
	value = 40

/obj/item/stack/material/silver
	name = "silver"
	icon_state = "sheet-silver"
	default_type = "silver"
	value = 20

/obj/item/stack/material/steel
	name = DEFAULT_WALL_MATERIAL
	icon_state = "sheet-metal"
	default_type = DEFAULT_WALL_MATERIAL
	value = 5

/obj/item/stack/material/wood
	name = "wooden plank"
	icon_state = "sheet-wood"
	default_type = "wood"
	dropsound = 'sound/effects/drop_wood.ogg'
	value = 1

/obj/item/stack/material/cloth
	name = "cloth"
	icon_state = "sheet-cloth"
	default_type = "cloth"
	value = 3


/obj/item/stack/material/leather
	name = "leather"
	desc = "The by-product of mob grinding."
	icon_state = "sheet-leather"
	default_type = "leather"
	value = 2

/obj/item/stack/material/glass
	name = "glass"
	icon_state = "sheet-glass"
	default_type = "glass"
	dropsound = 'sound/effects/drop_glass.ogg'
	value = 3

/obj/item/stack/material/glass/reinforced
	name = "reinforced glass"
	icon_state = "sheet-rglass"
	default_type = "rglass"
	value = 6