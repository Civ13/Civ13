/* Beds... get your mind out of the gutter, they're for sleeping!
 * Contains:
 * 		Beds
 *		Roller beds
 */

/*
 * Beds
 */
/obj/structure/bed
	name = "bed"
	desc = "This is used to lie in, sleep in or strap on."
	icon = 'icons/obj/bed_chair.dmi'
	icon_state = "bed"
	anchored = TRUE
	can_buckle = TRUE
	buckle_dir = SOUTH
	buckle_lying = TRUE
	var/material/material
	var/material/padding_material
	var/base_icon = "bed"
	var/applies_material_colour = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE

/obj/structure/bed/fieldbed
	name = "field bed"
	desc = "This is an easy to move field bed for sleeping while on the move."
	icon_state = "fieldbed"
	base_icon = "fieldbed"
	material = "steel"
	applies_material_colour = FALSE

/obj/structure/bed/wood
	material = "wood"

/obj/structure/bed/hammock
	name = "hammock"
	desc = "a rope bed, hanging from the ceiling."
	applies_material_colour = FALSE
	material = "rope"
	icon_state = "hammockf"
/obj/structure/bed/hammock/update_icon()
	return

/obj/structure/bed/hammock/New()
	..()
	processing_objects |= src

/obj/structure/bed/hammock/Del()
	processing_objects -= src
	..()


/obj/structure/bed/hammock/process()
	fire()

// call this instead of process() if you want to do direct calls, I think its better - Kachnov
/obj/structure/bed/hammock/proc/fire()
	if (buckled_mob)
		icon_state = "hammockf_static"
		if (pixel_y == 0)
			pixel_y = 1
		else if (pixel_y == 1)
			pixel_y = 0
		else if (pixel_y == 0)
			pixel_y = -1
		else // somehow
			pixel_y = 0
		buckled_mob.pixel_y = pixel_y
	else
		icon_state = "hammockf"

/obj/structure/bed/New(var/newloc, var/new_material, var/new_padding_material)
	..(newloc)
	if (!istype(src, /obj/structure/bed/bedroll) && !istype(src, /obj/structure/bed/custsofa))
		color = null
		if (!new_material)
			if (!material)
				new_material = DEFAULT_WALL_MATERIAL
			else
				new_material = material
		material = get_material_by_name(new_material)
		if (!istype(material))
			qdel(src)
			return
		if (new_padding_material)
			padding_material = get_material_by_name(new_padding_material)
		update_icon()
		if (get_material_name() == "wood")
			flammable = TRUE

/obj/structure/bed/get_material()
	return material

// Reuse the cache/code from stools, todo maybe unify.
/obj/structure/bed/update_icon()
	if (!istype(src, /obj/structure/bed/custsofa))
		// Prep icon.
		icon_state = ""
		overlays.Cut()
		// Base icon.
		var/cache_key = "[base_icon]-[material.name]"
		if (isnull(stool_cache[cache_key]))
			var/image/I = image('icons/obj/bed_chair.dmi', base_icon)
			if (applies_material_colour)
				I.color = material.icon_colour
			stool_cache[cache_key] = I
		overlays |= stool_cache[cache_key]
		// Padding overlay.
		if (padding_material)
			var/padding_cache_key = "[base_icon]-padding-[padding_material.name]"
			if (isnull(stool_cache[padding_cache_key]))
				var/image/I =  image(icon, "[base_icon]_padding")
				I.color = padding_material.icon_colour
				stool_cache[padding_cache_key] = I
			overlays |= stool_cache[padding_cache_key]

		// Strings.
		desc = initial(desc)
		if (padding_material)
			name = "[padding_material.display_name] [initial(name)]" //this is not perfect but it will do for now.
			desc += " It's made of [material.use_name] and covered with [padding_material.use_name]."
		else
			name = "[material.display_name] [initial(name)]"
			desc += " It's made of [material.use_name]."

/obj/structure/bed/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if (istype(mover) && mover.checkpass(PASSTABLE))
		return TRUE
	else
		return ..()

/obj/structure/bed/ex_act(severity)
	switch(severity)
		if (1.0)
			qdel(src)
			return
		if (2.0)
			if (prob(50))
				qdel(src)
				return
		if (3.0)
			if (prob(5))
				qdel(src)
				return

/obj/structure/bed/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W,/obj/item/stack))
		if (padding_material)
			user << "\The [src] is already padded."
			return
		var/obj/item/stack/C = W
		if (C.amount < 1) // How??
			user.drop_from_inventory(C)
			qdel(C)
			return
		var/padding_type //This is awful but it needs to be like this until tiles are given a material var.
		if (istype(W,/obj/item/stack/material))
			var/obj/item/stack/material/M = W
			if (M.material && (M.material.flags & MATERIAL_PADDING))
				padding_type = "[M.material.name]"
		if (!padding_type)
			user << "You cannot pad \the [src] with that."
			return
		C.use(1)
		if (!istype(loc, /turf))
			user.drop_from_inventory(src)
			loc = get_turf(src)
		user << "You add padding to \the [src]."
		add_padding(padding_type)
		return

	else if (istype(W, /obj/item/weapon/wirecutters))
		if (!padding_material)
			user << "\The [src] has no padding to remove."
			return
		user << "You remove the padding from \the [src]."
		playsound(src, 'sound/items/Wirecutter.ogg', 100, TRUE)
		remove_padding()

	else if (istype(W, /obj/item/weapon/grab))
		var/obj/item/weapon/grab/G = W
		var/mob/living/affecting = G.affecting
		user.visible_message("<span class='notice'>[user] attempts to buckle [affecting] into \the [src]!</span>")
		if (do_after(user, 20, src))
			affecting.loc = loc
			spawn(0)
				if (buckle_mob(affecting))
					affecting.visible_message(\
						"<span class='danger'>[affecting.name] is buckled to [src] by [user.name]!</span>",\
						"<span class='danger'>You are buckled to [src] by [user.name]!</span>",\
						"<span class='notice'>You hear metal clanking.</span>")
			qdel(W)
	else
		..()

/obj/structure/bed/proc/remove_padding()
	if (padding_material)
		padding_material.place_sheet(get_turf(src))
		padding_material = null
	update_icon()

/obj/structure/bed/proc/add_padding(var/padding_type)
	padding_material = get_material_by_name(padding_type)
	update_icon()

/obj/structure/bed/proc/dismantle()
	material.place_sheet(get_turf(src))
	if (padding_material)
		padding_material.place_sheet(get_turf(src))

/obj/structure/bed/psych
	name = "divan"
	desc = "For prime comfort during psychiatric evaluations."
	icon_state = "psychbed"
	base_icon = "psychbed"

/obj/structure/bed/psych/New(var/newloc)
	..(newloc,"wood","leather")

/obj/structure/bed/padded/New(var/newloc)
	..(newloc,"wood","cotton")

/obj/structure/bed/roller
	name = "roller bed"
	icon = 'icons/obj/rollerbed.dmi'
	icon_state = "down"
	anchored = FALSE
	var/next_sound = -1

/obj/structure/bed/roller/update_icon()
	return // Doesn't care about material or anything else.

/obj/structure/bed/roller/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/wrench) || istype(W,/obj/item/stack) || istype(W, /obj/item/weapon/wirecutters))
		return
	else if (istype(W,/obj/item/roller_holder))
		if (buckled_mob)
			user_unbuckle_mob(user)
		else
			visible_message("[user] collapses \the [name].")
			new/obj/item/roller(get_turf(src))
			spawn(0)
				qdel(src)
		return
	..()

/obj/structure/bed/roller/Move(var/turf/newloc)

	if (buckled_mob && map.check_caribbean_block(buckled_mob, newloc))
		return FALSE

	var/oloc = loc

	..(newloc)

	if (oloc != loc)
		if (world.time > next_sound)
			playsound(get_turf(src), 'sound/effects/rollermove.ogg', 75, TRUE)
			next_sound = world.time + 10

	if (buckled_mob)
		if (buckled_mob.buckled == src)
			buckled_mob.loc = loc
		else
			buckled_mob = null

	return TRUE

/obj/structure/bed/roller/post_buckle_mob(mob/living/M as mob)
	if (M == buckled_mob)
		M.pixel_y = 6
		M.old_y = 6
		density = TRUE
		icon_state = "up"
	else
		M.pixel_y = FALSE
		M.old_y = FALSE
		density = FALSE
		icon_state = "down"

	return ..()

/obj/structure/bed/roller/MouseDrop(over_object, src_location, over_location)
	..()
	if ((over_object == usr && (in_range(src, usr) || usr.contents.Find(src))))
		if (!ishuman(usr))	return
		if (buckled_mob)	return FALSE
		visible_message("[usr] collapses \the [name].")
		new/obj/item/roller(get_turf(src))
		spawn(0)
			qdel(src)
		return

/obj/item/roller
	name = "roller bed"
	desc = "A collapsed roller bed that can be carried around."
	icon = 'icons/obj/rollerbed.dmi'
	icon_state = "folded"
	w_class = ITEM_SIZE_LARGE // Can't be put in backpacks. Oh well.
	flags = CONDUCT
/obj/item/roller/attack_self(mob/user)
		var/obj/structure/bed/roller/R = new /obj/structure/bed/roller(user.loc)
		R.add_fingerprint(user)
		qdel(src)

/obj/item/roller/attackby(obj/item/weapon/W as obj, mob/user as mob)

	if (istype(W,/obj/item/roller_holder))
		var/obj/item/roller_holder/RH = W
		if (!RH.held)
			user << "<span class='notice'>You collect the roller bed.</span>"
			loc = RH
			RH.held = src
			return

	..()

/obj/item/roller_holder
	name = "roller bed rack"
	desc = "A rack for carrying a collapsed roller bed."
	icon = 'icons/obj/rollerbed.dmi'
	icon_state = "folded"
	slot_flags = SLOT_BACK
	var/obj/item/roller/held
	flags = CONDUCT

/obj/item/roller_holder/New()
	..()
	held = new /obj/item/roller(src)

/obj/item/roller_holder/attack_self(mob/user as mob)

	if (!held)
		user << "<span class='notice'>The rack is empty.</span>"
		return

	user << "<span class='notice'>You deploy the roller bed.</span>"
	var/obj/structure/bed/roller/R = new /obj/structure/bed/roller(user.loc)
	R.add_fingerprint(user)
	qdel(held)
	held = null


////////////////sofa///////////////////
/obj/structure/bed/sofa
	name = "old sofa"
	desc = "A sofa where you can rest."
	icon = 'icons/obj/junk.dmi'
	icon_state = "sofa_forward"
	anchored = TRUE
	can_buckle = TRUE
	buckle_dir = SOUTH
	buckle_lying = FALSE
	base_icon = "sofa_forward"
	applies_material_colour = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE

/obj/structure/bed/sofa/left
	icon_state = "sofa_forward_left"
	base_icon = "sofa_forward_left"
/obj/structure/bed/sofa/right
	icon_state = "sofa_forward_right"
	base_icon = "sofa_forward_right"
/obj/structure/bed/sofa/get_material()
	return

/obj/structure/bed/sofa/update_icon()
	return

/obj/structure/bed/sofa/remove_padding()
	return

/obj/structure/bed/sofa/add_padding(var/padding_type)
	return

/obj/structure/bed/sofa/dismantle()
	return

/////////////Updated Sofa//////////////

/obj/structure/bed/custsofa
	name = "sofa"
	desc = "A sofa where you can rest."
	icon = 'icons/obj/junk.dmi'
	icon_state = "custsofa_middle"
	anchored = TRUE
	can_buckle = TRUE
	buckle_dir = SOUTH
	buckle_lying = FALSE
	base_icon = "custsofa_middle"
	applies_material_colour = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE
	applies_material_colour = FALSE
	var/uncolored = TRUE
	color = "#FFFFFF"

/obj/structure/bed/custsofa/New()
	..()
	if(dir == 1)
		buckle_dir = NORTH
		layer = MOB_LAYER + 0.5
	if(dir == 2)
		buckle_dir = SOUTH
	if(dir == 4)
		buckle_dir = EAST
	if(dir == 8)
		buckle_dir = WEST
	update_icon()

/obj/structure/bed/custsofa/attack_hand(mob/user as mob)
	if (uncolored)
		var/input = WWinput(user, "Choose the color of the sofa:", "Color" , "#FFFFFF", "color")
		if (input == null || input == "")
			return
		else
			color = input
			uncolored = FALSE
			return
	else
		..()

/obj/structure/bed/custsofa/left
	icon_state = "custsofaend_left"
	base_icon = "custsofaend_left"
/obj/structure/bed/custsofa/right
	icon_state = "custsofaend_right"
	base_icon = "custsofaend_right"
/obj/structure/bed/custsofa/corner
	icon_state = "custsofacorner"
	base_icon = "custsofacorner"

////////////////sofa but actually a chair not a bed///////////////////
/obj/structure/bed/chair/sofa
	name = "sofa"
	desc = "A sofa where you can rest."
	icon = 'icons/obj/junk.dmi'
	icon_state = "sofa_forward"
	anchored = TRUE
	can_buckle = TRUE
	buckle_dir = SOUTH
	buckle_lying = FALSE
	base_icon = "sofa_forward"
	applies_material_colour = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE

/obj/structure/bed/chair/sofa/left
	icon_state = "sofa_forward_left"
	base_icon = "sofa_forward_left"
/obj/structure/bed/chair/sofa/right
	icon_state = "sofa_forward_right"
	base_icon = "sofa_forward_right"
/obj/structure/bed/chair/sofa/get_material()
	return

/obj/structure/bed/chair/sofa/update_icon()
	return

/obj/structure/bed/chair/sofa/remove_padding()
	return

/obj/structure/bed/chair/sofa/add_padding(var/padding_type)
	return

/obj/structure/bed/chair/sofa/dismantle()
	return