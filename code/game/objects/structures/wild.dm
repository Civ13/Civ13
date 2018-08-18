/obj/structure/wild
	icon = 'icons/obj/wild.dmi'
	icon_state = "tree"
	anchored = TRUE
	var/sways = FALSE
	var/amount = 0 //how much wood to drop. 0 = none
	var/health = 100
	var/maxhealth = 100
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
	if (amount > 0)
		var/obj/item/stack/material/wood/wooddrop = new /obj/item/stack/material/wood
		wooddrop.amount = amount
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
/obj/structure/wild/attackby(obj/item/W as obj, mob/user as mob)
	user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	if(istype(W,/obj/item/weapon/material/hatchet))
		health -= 25
	else
		switch(W.damtype)
			if ("fire")
				health -= W.force * TRUE
			if ("brute")
				health -= W.force * 0.20

	playsound(get_turf(src), 'sound/weapons/smash.ogg', 100)
	user.do_attack_animation(src)
	try_destroy()
	..()

/obj/structure/wild/proc/try_destroy()
	if (health <= 0)
		visible_message("<span class='danger'>The [src] is broken into pieces!</span>")
		for(var/i = FALSE; i < amount; i++)
			new /obj/item/stack/material/wood(src)
		qdel(src)
		return


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
	amount = 3


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
	amount = 2

/obj/structure/wild/palm/fire_act(temperature)
	if (prob(15 * (temperature/500)))
		visible_message("<span class = 'warning'>[src] collapses.</span>")
		qdel(src)

/obj/structure/wild/palm/New()
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

/*obj/structure/wild/junglebush
	name = "jungle vegetation"
	icon_state = "jungle1"
	opacity = FALSE
	density = FALSE
*/
obj/structure/wild/junglebush
	name = "jungle vegetation"
	icon = 'icons/obj/flora/jungleflora.dmi'
	icon_state = "1"
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
	amount = 0

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

/*/obj/structure/wild/junglebush/New()
	..()

	icon_state = "jungle[rand(1,6)]"
*/
/obj/structure/wild/junglebush/New()
	..()

	icon_state = "[rand(1,30)]"

/obj/structure/wild/burnedtree/New()
	..()

	icon_state = "burnedtree[rand(1,5)]"

/obj/structure/wild/rock/New()
	..()

	icon_state = "rock[rand(1,5)]"

/obj/structure/wild/jungle
	name = "jungle tree"
	icon = 'icons/obj/flora/jungletreesmaller.dmi'
	icon_state = "tree1"
	opacity = TRUE
	density = TRUE
	sways = FALSE
	bound_height = 64
	bound_width = 32
	amount = 6

/obj/structure/wild/jungle/fire_act(temperature)
	if (prob(15 * (temperature/500)))
		visible_message("<span class = 'warning'>[src] collapses.</span>")
		qdel(src)

/obj/structure/wild/jungle/New()
	..()
	icon_state = "tree[rand(1,7)]"