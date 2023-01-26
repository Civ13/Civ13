/obj/structure/bed/chair	//YES, chairs are a type of bed, which are a type of stool. This works, believe me.	-Pete
	name = "chair"
	desc = "You sit in this. Either by will or force."
	icon_state = "chair"
	color = "#666666"
	base_icon = "chair"
	buckle_dir = FALSE
	buckle_lying = FALSE //force people to sit up in chairs when buckled
	var/propelled = FALSE // Check for fire-extinguisher-driven chairs

/obj/structure/bed/chair/New()
	..()
	update_layer()

/obj/structure/bed/chair/post_buckle_mob()
	update_icon()

/obj/structure/bed/chair/update_icon()
	..()

/*
	var/cache_key = "[base_icon]-[material.name]-over"
	if (isnull(stool_cache[cache_key]))
		var/image/I = image('icons/obj/furniture.dmi', "[base_icon]_over")
		I.color = material.icon_colour
		I.layer = FLY_LAYER
		stool_cache[cache_key] = I
	overlays |= stool_cache[cache_key]
*/
	// Padding overlay.
	if (padding_material)
		var/padding_cache_key = "[base_icon]-padding-[padding_material.name]-over"
		if (isnull(stool_cache[padding_cache_key]))
			var/image/I =  image(icon, "[base_icon]_padding_over")
			I.color = padding_material.icon_colour
			I.layer = FLY_LAYER
			stool_cache[padding_cache_key] = I
		overlays |= stool_cache[padding_cache_key]

	if (buckled_mob && padding_material)
		var/cache_key = "[base_icon]-armrest-[padding_material.name]"
		if (isnull(stool_cache[cache_key]))
			var/image/I = image(icon, "[base_icon]_armrest")
			I.layer = MOB_LAYER + 0.1
			I.color = padding_material.icon_colour
			stool_cache[cache_key] = I
		overlays |= stool_cache[cache_key]

/obj/structure/bed/chair/proc/update_layer()
	if (dir == NORTH)
		layer = FLY_LAYER
	else
		layer = OBJ_LAYER

/obj/structure/bed/chair/set_dir()
	..()
	update_layer()
	if (buckled_mob)
		buckled_mob.set_dir(dir)

/obj/structure/bed/chair/verb/rotate_right()
	set name = "Rotate Right"
	set category = null
	set src in oview(1)

	if (config.ghost_interaction)
		set_dir(turn(dir, 90))

		return

	else
		if (istype(usr,/mob/living/simple_animal/mouse))
			return
		if (!usr || !isturf(usr.loc))
			return
		if (usr.stat || usr.restrained())
			return

		set_dir(turn(dir, 90))

		return

/obj/structure/bed/chair/verb/rotate_left()
	set name = "Rotate Left"
	set category = null
	set src in oview(1)

	if (config.ghost_interaction)
		set_dir(turn(dir, -90))

		return

	else
		if (istype(usr,/mob/living/simple_animal/mouse))
			return
		if (!usr || !isturf(usr.loc))
			return
		if (usr.stat || usr.restrained())
			return

		set_dir(turn(dir, -90))

		return

// Leaving this in for the sake of compilation.
/obj/structure/bed/chair/comfy
	desc = "It's a chair. It looks comfy."
	icon_state = "chair_padding"

/obj/structure/bed/chair/comfy/brown/New(var/newloc,var/newmaterial)
	..(newloc,"steel","leather")

/obj/structure/bed/chair/comfy/red/New(var/newloc,var/newmaterial)
	..(newloc,"steel","carpet")

/obj/structure/bed/chair/comfy/teal/New(var/newloc,var/newmaterial)
	..(newloc,"steel","teal")

/obj/structure/bed/chair/comfy/black/New(var/newloc,var/newmaterial)
	..(newloc,"steel","black")

/obj/structure/bed/chair/comfy/green/New(var/newloc,var/newmaterial)
	..(newloc,"steel","green")

/obj/structure/bed/chair/comfy/purp/New(var/newloc,var/newmaterial)
	..(newloc,"steel","purple")

/obj/structure/bed/chair/comfy/blue/New(var/newloc,var/newmaterial)
	..(newloc,"steel","blue")

/obj/structure/bed/chair/comfy/beige/New(var/newloc,var/newmaterial)
	..(newloc,"steel","beige")

/obj/structure/bed/chair/comfy/lime/New(var/newloc,var/newmaterial)
	..(newloc,"steel","lime")

/obj/structure/bed/chair/comfy/fancy_sofa
	name = "fancy sofa"
	desc = "A nice leather sofa."
	base_icon = "fancysofa_l"
	icon_state = "fancysofa_l"
	applies_material_colour = FALSE
	material = "leather"
/obj/structure/bed/chair/comfy/fancy_sofa/l
	icon_state = "fancysofa_l"
	applies_material_colour = FALSE
	base_icon = "fancysofa_l"
/obj/structure/bed/chair/comfy/fancy_sofa/r
	icon_state = "fancysofa_r"
	applies_material_colour = FALSE
	base_icon = "fancysofa_r"

/obj/structure/bed/chair/comfy/diner_booth
	name = "diner booth seating"
	desc = "A comfy red dining booth seating."
	base_icon = "diner_booth_right"
	icon_state = "diner_booth_right"
	applies_material_colour = FALSE
	material = "leather"
	color = "#FFFFFF"
/obj/structure/bed/chair/comfy/diner_booth/l
	base_icon = "diner_booth_left"
	icon_state = "diner_booth_left"
	applies_material_colour = FALSE
/obj/structure/bed/chair/comfy/diner_booth/r
	base_icon = "diner_booth_right"
	icon_state = "diner_booth_right"
	applies_material_colour = FALSE

/obj/structure/bed/chair/office
	anchored = FALSE
	buckle_movable = TRUE

/obj/structure/bed/chair/office/update_icon()
	return

/obj/structure/bed/chair/office/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W,/obj/item/stack) || istype(W, /obj/item/weapon/wirecutters))
		return
	..()

/obj/structure/bed/chair/office/Move()
	..()
	if (buckled_mob)
		var/mob/living/occupant = buckled_mob
		occupant.buckled = null
		occupant.Move(loc)
		occupant.buckled = src
		if (occupant && (loc != occupant.loc))
			if (propelled)
				for (var/mob/O in loc)
					if (O != occupant)
						Bump(O)
			else
				unbuckle_mob()

/obj/structure/bed/chair/office/Bump(atom/A)
	..()
	if (!buckled_mob)	return

	if (propelled)
		var/mob/living/occupant = unbuckle_mob()

		var/def_zone = ran_zone()
		var/blocked = occupant.run_armor_check(def_zone, "melee")
		occupant.throw_at(A, 3, propelled)
		occupant.apply_effect(6, STUN, blocked)
		occupant.apply_effect(6, WEAKEN, blocked)
		occupant.apply_effect(6, STUTTER, blocked)
		occupant.apply_damage(10, BRUTE, def_zone, blocked)
		playsound(loc, 'sound/weapons/punch1.ogg', 50, TRUE, -1)
		if (istype(A, /mob/living))
			var/mob/living/victim = A
			def_zone = ran_zone()
			blocked = victim.run_armor_check(def_zone, "melee")
			victim.apply_effect(6, STUN, blocked)
			victim.apply_effect(6, WEAKEN, blocked)
			victim.apply_effect(6, STUTTER, blocked)
			victim.apply_damage(10, BRUTE, def_zone, blocked)
		occupant.visible_message("<span class='danger'>[occupant] crashed into \the [A]!</span>")

/obj/structure/bed/chair/office/light
	icon_state = "officechair_white"

/obj/structure/bed/chair/office/dark
	icon_state = "officechair_dark"

/obj/structure/bed/chair/office/New()
	..()
	var/image/I = image(icon, "[icon_state]_over")
	I.layer = FLY_LAYER
	overlays += I


// Chair types
/obj/structure/bed/chair/wood
	name = "wooden chair"
	desc = "Old is never too old to not be in fashion."
	icon_state = "wooden_chair"
	applies_material_colour = FALSE

/obj/structure/bed/chair/wood/another
	name = "wooden chair"
	desc = "Classic is never too old to not be in fashion."
	icon_state = "wooden_chair_alt"

/obj/structure/bed/modern/chair
	name = "steel chair"
	desc = "A cold boring chair."
	icon_state = "wooden_chair"
	applies_material_colour = FALSE

/obj/structure/bed/chair/wood/bleacher
	name = "wood bleacher"
	desc = "A long bench like seat for a church."
	icon_state = "bleacher"
	applies_material_colour = FALSE

/obj/structure/bed/chair/wood/bleacher/r
	name = "wood bleacher"
	desc = "A long bench like seat for a church."
	icon_state = "bleacher_r"
	applies_material_colour = FALSE

/obj/structure/bed/chair/wood/bleacher/l
	name = "wood bleacher"
	desc = "A long bench like seat for a church."
	icon_state = "bleacher_l"
	applies_material_colour = FALSE

/obj/structure/bed/chair/stone
	name = "stone chair"
	desc = "Old is never too old to not be in fashion."
	icon_state = "chair"
	material = "stone"
	applies_material_colour = TRUE

/obj/structure/bed/modern/steel
	name = "steel chair"
	desc = "cold boring chair."
	icon_state = "steelchair"
	base_icon = "steelchair"
	material = "steel"
	applies_material_colour = FALSE

/obj/structure/bed/chair/steel
	name = "steel chair"
	desc = "cold boring chair."
	icon_state = "steelchair"
	base_icon = "steelchair"
	material = "steel"
	applies_material_colour = FALSE



/obj/structure/bed/chair/wood/update_icon()
	return

/obj/structure/bed/chair/wood/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W,/obj/item/stack) || istype(W, /obj/item/weapon/wirecutters))
		return
	..()

/obj/structure/bed/chair/wood/New(var/newloc)
	..(newloc, "wood")
	var/image/I = image(icon, "[icon_state]_over")
	I.layer = FLY_LAYER
	overlays += I

/obj/structure/bed/chair/wood/wings
	name = "wing back wood chair"
	icon_state = "wooden_chair_wings"

/obj/structure/bed/chair/wood/red
	name = "padded chair"
	desc = "Built with padding for extra comfort."
	icon_state = "wooden_chair_red"

/obj/structure/bed/chair/wood/alt
	icon_state = "wooden_chair_alt"

/obj/structure/bed/chair/barber
	name = "barber chair"
	desc = "A barbershop chair."
	icon_state = "barberchair"
	base_icon = "barberchair"
	material = "steel"
	applies_material_colour = FALSE
