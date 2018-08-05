/obj/structure/wild
	icon = 'icons/obj/wild.dmi'
	icon_state = "tree"
	anchored = TRUE
	var/sways = FALSE
/*
/obj/structure/wild/New()
	..()*/
/*
	spawn (50)
		for (var/obj/structure/S in get_turf(src))
			if (S && istype(S) && S != src)
				qdel(src)
				return
*/
/obj/structure/wild/Destroy()
	for (var/obj/o in get_turf(src))
		if (o.special_id == "seasons")
			qdel(o)
	..()

/obj/structure/wild/fire_act(temperature)
	if (prob(35 * (temperature/500)))
		visible_message("<span class = 'warning'>[src] is burned away.</span>")
		qdel(src)

// it's windy out
/obj/structure/wild/proc/sway()
	if (!sways)
		return
	icon_state = "[initial(icon_state)]_swaying_[pick("left", "right")]"

/obj/structure/wild/CanPass(var/atom/movable/mover)
	if (istype(mover, /obj/effect/effect/smoke))
		return TRUE
	else if (istype(mover, /obj/item/projectile))
		if (prob(75) && density)
			visible_message("<span class = 'warning'>The [mover.name] hits \the [src]!</span>")
			return FALSE
		else
			return TRUE
	else
		return ..()

/obj/structure/wild/bullet_act(var/obj/item/projectile/proj)
	if (prob(proj.damage - 30)) // makes shrapnel unable to take down trees
		visible_message("<span class = 'danger'>[src] collapses!</span>")
		qdel(src)

/obj/structure/wild/tree
	name = "tree"
	icon_state = "tree"
	opacity = TRUE
	density = TRUE
	sways = TRUE

/obj/structure/wild/tree/fire_act(temperature)
	if (prob(15 * (temperature/500)))
		visible_message("<span class = 'warning'>[src] collapses.</span>")
		qdel(src)

/obj/structure/wild/tree/anchored

/obj/structure/wild/tree/New()
	..()
	if (!istype(src, /obj/structure/wild/tree/anchored))
		pixel_x = rand(-8,8)

/obj/structure/wild/palm
	name = "palm tree"
	icon = 'icons/misc/beach2.dmi'
	icon_state = "palm1"
	opacity = TRUE
	density = TRUE
	sways = FALSE

/obj/structure/wild/palm/fire_act(temperature)
	if (prob(15 * (temperature/500)))
		visible_message("<span class = 'warning'>[src] collapses.</span>")
		qdel(src)

/obj/structure/wild/tree/New()
	..()
	icon_state = pick("palm1","palm2")

/obj/structure/wild/bush
	name = "bush"
	icon_state = "small_bush"
	opacity = FALSE
	density = FALSE

/* todo: bush sounds
/obj/structure/wild/bush/Crossed(var/atom/movable/am)
	if (!istype(src, /obj/structure/wild/bush/tame))
		if (istype(am, /mob/living))
			playsound(get_turf(src), "rustle", rand(50,70))
	..(am)
*/

/obj/structure/wild/bush/tame
	name = "cultivated bush"

/obj/structure/wild/bush/tame/big
	name = "large cultivated bush"
	icon_state = "big_bush"

obj/structure/wild/burnedbush
	name = "burned bush"
	icon_state = "burnedbush1"
	opacity = FALSE
	density = FALSE

obj/structure/wild/junglebush
	name = "jungle vegetation"
	icon_state = "jungle1"
	opacity = FALSE
	density = FALSE

obj/structure/wild/burnedtree
	name = "burned tree"
	icon_state = "burnedtree1"
	opacity = FALSE
	density = FALSE

obj/structure/wild/rock
	name = "rock"
	icon_state = "rock1"
	opacity = FALSE
	density = FALSE

/obj/structure/wild/bush/New()
	..()

	if (istype(src, /obj/structure/wild/bush/tame))
		return

	if (prob(25))
		icon_state = "grassybush_[rand(1,4)]"
	else if (prob(25))
		icon_state = "leafybush_[rand(1,3)]"
	else if (prob(25))
		icon_state = "palebush_[rand(1,4)]"
	else
		icon_state = "stalkybush_[rand(1,3)]"


/obj/structure/wild/burnedbush/New()
	..()

	icon_state = "burnedbush[rand(1,5)]"

/obj/structure/wild/junglebush/New()
	..()

	icon_state = "jungle[rand(1,6)]"


/obj/structure/wild/burnedtree/New()
	..()

	icon_state = "burnedtree[rand(1,5)]"

/obj/structure/wild/rock/New()
	..()

	icon_state = "rock[rand(1,5)]"