// this now inherits from window as its an easy way to give it the same
// multidirectional collision behavior

/mob/living/human/var/crouching = FALSE

/obj/structure/window/barrier
	icon = 'icons/obj/structures.dmi'
	name = "dirt wall"
	desc = "That's a barricade from dirt."
	icon_state = "dirt_wall"
	layer = MOB_LAYER + 2 //just above mobs
	anchored = TRUE
	climbable = TRUE
	mouse_drop_zone = TRUE
	var/incomplete = FALSE
	var/dismantlable = TRUE
	maxhealth = 30
	health = 30
	New()
		..()
		health = maxhealth

/obj/structure/window/barrier/attack_hand(var/mob/user as mob)
    if (locate(src) in range(user, 1)) // TODO: Somehow make the user face what they are dismantling.
        if (dismantlable && user.a_intent == I_HARM)
            user.visible_message(SPAN_DANGER("[user] starts dismantling the [src]."), SPAN_DANGER("You start dismantling the [src]."))
            if (do_after(user, 200, src))
                user.visible_message(SPAN_DANGER("[user] finishes dismantling the [src]."), SPAN_DANGER("You finish dismantling the [src]."))
                var/turf = get_turf(src)

                if (!istype(src, /obj/structure/window/barrier/incomplete))
                    for (var/v in TRUE to rand(4,6))
                        new /obj/item/weapon/barrier(turf)
                else
                    var/obj/structure/window/barrier/incomplete/I = src
                    for (var/v in TRUE to (1 + pick(I.progress-1, I.progress)))
                        new /obj/item/weapon/barrier(turf)
                qdel(src)

        else if (user.a_intent == I_GRAB)
            var/mob/living/H = user
            if (istype(H) && can_climb(H))
                H.dir = get_dir(H, src)
                do_climb(H)

/obj/structure/window/barrier/ex_act(severity)
	switch(severity)
		if (1.0)
			qdel(src)
			return
		if (2.0)
			qdel(src)
			return
		else
			if (prob(50))
				return ex_act(2.0)
	return

var/set_dir = null // Set the variable outside of any scopes

/obj/structure/window/barrier/New(location, var/mob/creator, direction)
    loc = location
    flags |= ON_BORDER

    if (creator && ismob(creator))
        set_dir = direction

    // Adjust direction to cardinal directions if intermediate directions are given
    // Cardinal movements use the standardized bitflag numbers 1, 2, 4, and 8. To move in any diagonal direction you just add 2 numbers together to find the sum 
    // NORTH is 1 and EAST is 4, so NORTHEAST is 5

    // Also much faster than a switch with if/else and OR

    if (set_dir & EAST)
        dir = EAST
    else if (set_dir & WEST)
        dir = WEST
    else
        dir = set_dir

    // Adjust layer and direction based on the final direction
    switch (dir)
        if (NORTH)
            layer = MOB_LAYER - 1.01
            pixel_y = FALSE
        if (SOUTH)
            layer = MOB_LAYER + 2
            pixel_y = FALSE
        if (EAST)
            layer = MOB_LAYER - 0.05
            pixel_x = FALSE
        if (WEST)
            layer = MOB_LAYER - 0.05
            pixel_x = FALSE


//incomplete sandbag structures
/// Dirt-bags
/obj/structure/window/barrier/incomplete
	name = "incomplete dirt barricade"
	desc = "This dirt barricade is unfinished. Add few more dirt."
	icon_state = "dirt_wall_33%"
	var/progress = FALSE
	incomplete = TRUE

/obj/structure/window/barrier/incomplete/attackby(obj/O as obj, mob/user as mob) // Dirt Barrier Attackby()
	//user.dir = get_dir(user, src)
	if (O.type == /obj/item/weapon/barrier)
		if (progress < 3)
			progress += 1
			if (progress == 2)
				icon_state = "dirt_wall_66%"
			if (progress >= 3)
				icon_state = "dirt_wall"
				new/obj/structure/window/barrier(loc, user, dir)
				qdel(src)
			user.visible_message(SPAN_DANGER("[user] adds dirt onto \the [src]."), SPAN_DANGER("You add dirt onto \the [src]."))
			qdel(O)
			return
	..()
/// Sand-bags

/obj/structure/window/barrier/sandbag/incomplete
	name = "incomplete sandbag wall"
	desc = "This sandbag wall is unfinished. Add a few more sandbags."
	icon_state = "sandbag_33%"
	var/progress = FALSE
	incomplete = TRUE

/obj/structure/window/barrier/sandbag/incomplete/attackby(obj/O as obj, mob/user as mob)
	//user.dir = get_dir(user, src)
	if (istype(O, /obj/item/weapon/barrier/sandbag))
		var/obj/item/weapon/barrier/sandbag/bag = O
		if (bag.sand_amount <= 0)
			to_chat(user, SPAN_NOTICE("You need to fill the sandbag with sand first!"))
			return
		if (progress < 3)
			progress += 1
			if (progress == 2)
				icon_state = "sandbag_66%"
			if (progress >= 3)
				icon_state = "sandbag"
				new/obj/structure/window/barrier/sandbag(loc, user, dir)
				qdel(src)
			user.visible_message(SPAN_DANGER("[user] puts the sandbag onto \the [src]."), SPAN_DANGER("You put the sandbag onto \the [src]."))
			qdel(O)
	else if (istype(O, /obj/item/weapon/material/shovel))
		user.visible_message(SPAN_WARNING("[user] starts dismantling the [src] using the [O.name]."), SPAN_WARNING("You start dismantling the [src] using the [O.name]."))
		var/decon_time = 200
		if (ishuman(user))
			var/mob/living/human/H = user
			decon_time /= 1.5*H.getStatCoeff("crafting")
		if (do_after(user, decon_time, src))
			user.visible_message(SPAN_DANGER("[user] finishes dismantling the [src] using the [O.name]."), SPAN_DANGER("You finish dismantling the [src] using the [O.name]."))
			var/turf = get_turf(src)
			new /obj/item/weapon/barrier/sandbag(turf)
			qdel(src)
	else
		return

/*
// This is being commented out to reduce proc-overhead and doing a switch in barrier/New() instead.

/obj/structure/window/barrier/set_dir(direction)
	dir = direction
*/

// window procedure overrides.
/obj/structure/window/barrier/attackby(obj/O as obj, mob/user as mob)
	return FALSE

/obj/structure/window/barrier/take_damage(var/damage = FALSE, var/sound_effect = TRUE)
	return FALSE

/obj/structure/window/barrier/apply_silicate(var/amount)
	return FALSE

/obj/structure/window/barrier/updateSilicate()
	return FALSE

/obj/structure/window/barrier/shatter(var/display_message = TRUE)
	return FALSE

/obj/structure/window/barrier/bullet_act(var/obj/item/projectile/Proj)
	health -= Proj.damage * 0.03
	visible_message("<span class = 'warning'>[Proj] hits the [src]!</span>")
	if (health <= 0)
		qdel(src)

/obj/structure/window/barrier/incomplete/ex_act(severity)
	qdel(src)

/obj/structure/window/barrier/ex_act(severity)
	switch(severity)
		if (1.0)
			qdel(src)
			return
		if (2.0)
			qdel(src)
			return
		if (3.0)
			if (prob(50))
				qdel(src)

/obj/structure/window/barrier/is_full_window()
	return FALSE

/obj/structure/window/hitby(AM as mob|obj)
	return FALSE // don't move

/obj/structure/window/barrier/attack_generic(var/mob/user, var/damage)
	return FALSE

/obj/structure/window/barrier/rotate_left()
	return

/obj/structure/window/barrier/rotate_right()
	return

/obj/structure/window/barrier/is_fulltile()
	return FALSE

/obj/structure/window/barrier/update_verbs()
	verbs -= /obj/structure/window/proc/rotate_left
	verbs -= /obj/structure/window/proc/rotate_right

//merges adjacent full-tile windows into one (blatant ripoff from game/smoothwall.dm)
/obj/structure/window/barrier/update_icon()
	return

/obj/structure/window/barrier/fire_act(temperature)
	return

/obj/item/weapon/barrier
	name = "dirt"
	icon_state = "dirt_pile"
	icon = 'icons/obj/items.dmi'
	w_class = ITEM_SIZE_TINY
	var/sand_amount = FALSE
	//value = 0
	flammable = FALSE
	flags = FALSE

/obj/item/weapon/barrier/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/reagent_containers))
		if (W.reagents.has_reagent("water", 10))
			W.reagents.remove_reagent("water", 10)
			to_chat(user, SPAN_NOTICE("You mold the dirt and water into clay."))
			new/obj/item/stack/material/clay(user.loc, 2)
			qdel(src)
			return TRUE //resolving attack

/obj/item/weapon/barrier/attack_self(mob/user)
	for(var/obj/O in user.loc) // Checking if there's another dense object to prevent stacking barricades
		if(O.density)
			if(O.flags & ON_BORDER)
				if(O.dir == user.dir)
					to_chat(user, SPAN_WARNING("There is already \a [O.name] in this direction!"))
					return
	to_chat(user, SPAN_NOTICE("You start building the dirt blocks wall..."))
	if (do_after(user, 25, src))
		to_chat(user, SPAN_NOTICE("You finish the placement of the dirt blocks wall foundation."))
		new /obj/covers/dirt_wall/blocks/incomplete(user.loc)
		qdel(src)
		return

/obj/structure/window/barrier/sandbag
	name = "sandbag wall"
	desc = "That's a sandbag barricade."
	icon_state = "sandbag"
	layer = MOB_LAYER + 2 //just above mobs
	anchored = TRUE
	climbable = TRUE

/obj/structure/window/barrier/concrete
	icon = 'icons/obj/structures.dmi'
	name = "concrete halfwall"
	icon_state = "concrete"
	layer = MOB_LAYER + 2 //just above mobs
	anchored = TRUE
	climbable = TRUE
	dismantlable = FALSE
	maxhealth = 900

/obj/structure/window/barrier/rock
	name = "rock wall"
	desc = "That's a barricade from rocks."
	icon_state = "rock_barricade"
	layer = MOB_LAYER + 2 //just above mobs
	anchored = TRUE
	climbable = TRUE
	maxhealth = 30

/obj/structure/window/barrier/sandstone
	name = "sandstone wall"
	desc = "That's a barricade from sandstone."
	icon_state = "sandstone_barricade"
	layer = MOB_LAYER + 2 //just above mobs
	anchored = TRUE
	climbable = TRUE
	dismantlable = FALSE
	maxhealth = 30

/obj/structure/window/barrier/palisade
	name = "palisade"
	desc = "A wooden palisade."
	icon = 'icons/obj/structures.dmi'
	icon_state = "palisade"
	health = 25
	anchored = TRUE
	climbable = FALSE
	flammable = TRUE
	dismantlable = FALSE

/obj/item/weapon/barrier/sandbag
	name = "sandbag"
	icon_state = "sandbag_new"
	icon = 'icons/obj/items.dmi'
	w_class = ITEM_SIZE_TINY
	sand_amount = TRUE
	value = 0
	maxhealth = 30

/obj/item/weapon/barrier/sandbag/empty
	sand_amount = FALSE
	icon_state = "sandbag_new_empty"

/obj/item/weapon/barrier/sandbag/empty/attackby(var/obj/item/stack/O as obj, mob/user as mob)
	if (istype(O, /obj/item/stack/ore/glass) && sand_amount < 1)
		O.amount--
		user << "You fill the sandbag with sand."
		sand_amount = TRUE
		if (O.amount<=0)
			qdel(O)
		return
	else
		..()

/obj/item/weapon/barrier/sandbag/attack_self(mob/user)
	if (sand_amount <= 0)
		to_chat(user, SPAN_NOTICE("You need to fill the sandbag with sand first!"))
		return
	for(var/obj/O in user.loc) // Checking if there's another dense object to prevent stacking barricades
		if(O.density)
			if(O.flags & ON_BORDER)
				if(O.dir == user.dir)
					to_chat(user, SPAN_WARNING("There is already \a [O.name] in this direction!"))
					return
	var/sandbag_time = 50

	if (ishuman(user))
		var/mob/living/human/H = user
		sandbag_time /= H.getStatCoeff("strength")
		sandbag_time /= (H.getStatCoeff("crafting") * H.getStatCoeff("crafting"))

	visible_message(SPAN_NOTICE("[user] starts constructing the base of a sandbag wall."), SPAN_NOTICE("You start constructing the base of a sandbag wall."))
	if (do_after(user, sandbag_time, user.loc))
		var/current_direction = user.dir
		if (current_direction & EAST)
			current_direction = EAST
		else if (current_direction & WEST)
			current_direction = WEST
		// Recheck user's direction before creating the sandbag/incomplete
		for (var/obj/O in user.loc) // Checking user's direction again
			if (O.density && O.flags & ON_BORDER && O.dir == current_direction)
				to_chat(user, SPAN_WARNING("There is already \a [O.name] in this direction!"))
				return
		var/progress = sand_amount
		qdel(src)
		var/obj/structure/window/barrier/sandbag/incomplete/sb = new/obj/structure/window/barrier/sandbag/incomplete(user.loc, user, current_direction)
		sb.progress = progress
		/*
		sb.dir = user.dir
		if (sb.dir == NORTH)
			sb.layer = MOB_LAYER - 2.01*/
		visible_message(SPAN_NOTICE("[user] finishes constructing the base of a sandbag wall. Anyone can now add to it."))
		if (ishuman(user))
			var/mob/living/human/H = user
			H.adaptStat("crafting", 3) // Needs to be rebalanced
	return


/obj/structure/window/barrier/sandbag/attack_hand(var/mob/user as mob)
	if (user.a_intent == I_HARM)
		user.dir = get_dir(user, src)
		visible_message(SPAN_DANGER("[user] starts dismantling the sandbag wall."), SPAN_DANGER("You start dismantling the sandbag wall."))
		if (do_after(user, 200, src))
			visible_message(SPAN_DANGER("[user] finishes dismantling the sandbag wall"), SPAN_DANGER("You finish dismantling the sandbag wall."))
			var/turf = get_turf(src)
			new /obj/item/weapon/barrier/sandbag(turf)
			qdel(src)
	else if (user.a_intent == I_GRAB)
		var/mob/living/H = user
		if (istype(H) && can_climb(H))
			H.dir = get_dir(H, src)
			do_climb(H)

/obj/structure/window/barrier/rock/attack_hand(var/mob/user as mob)
	if (user.a_intent == I_HARM)
		user.dir = get_dir(user, src)
		visible_message(SPAN_DANGER("[user] starts dismantling the rock wall."), SPAN_DANGER("You start dismantling the rock wall."))
		if (do_after(user, 200, src))
			visible_message(SPAN_DANGER("[user] finishes dismantling the rock wall"), SPAN_DANGER("You finish dismantling the rock wall."))
			var/turf = get_turf(src)
			new /obj/item/stack/material/stone(turf)
			qdel(src)
	else if (user.a_intent == I_GRAB)
		var/mob/living/H = user
		if (istype(H) && can_climb(H))
			H.dir = get_dir(H, src)
			do_climb(H)

/obj/structure/window/barrier/railing
	name = "railing"
	desc = "It's a sandstone railing to keep you from falling where you shouldn't."
	icon = 'icons/obj/railing.dmi'
	icon_state = "sandstone"
	layer = MOB_LAYER + 2 //just above mobs
	anchored = TRUE
	climbable = TRUE
	dismantlable = FALSE
	maxhealth = 1500

/obj/structure/window/barrier/railing/stone
	name = "railing"
	desc = "It's a stone railing to keep you from falling where you shouldn't."
	icon = 'icons/obj/railing.dmi'
	icon_state = "stone"
	layer = MOB_LAYER + 2 //just above mobs
	anchored = TRUE
	climbable = TRUE
	maxhealth = 2500

/obj/structure/window/barrier/railing/brick
	name = "Brick Wall"
	desc = "It's a railing from bricks to keep you from falling where you shouldn't."
	icon = 'icons/obj/railing.dmi'
	icon_state = "brick"
	layer = MOB_LAYER + 2 //just above mobs
	anchored = TRUE
	climbable = TRUE
	maxhealth = 3500

/obj/structure/window/barrier/railing/New()
	..()
	//invisibility = 101

/obj/structure/window/barrier/jersey
	name = "jersey barrier"
	desc = "Barrier employed to separate lanes of traffic."
	icon_state = "jerseybarrier1"
	icon = 'icons/obj/junk.dmi'
	maxhealth = 200
	dismantlable = FALSE

/obj/structure/window/barrier/jersey/New()
	..()
	icon_state = "jerseybarrier[rand(1,5)]"

/obj/structure/window/barrier/jersey/alt
	icon_state = "jerseybarrier_alt1"
	New()
		..()
		icon_state = "jerseybarrier_alt[rand(1,2)]"
