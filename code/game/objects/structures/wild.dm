/obj/structure/wild
	icon = 'icons/obj/wild.dmi'
	icon_state = "tree"
	anchored = TRUE
	var/sways = FALSE
	var/amount = 0 //how much wood to drop. 0 = none
	var/health = 100
	var/maxhealth = 100
	layer = 3.2
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
		visible_message("<span class='danger'>[user] begins to chop down the [src]!</span>")
		playsound(get_turf(src), 'sound/effects/wood_cutting.ogg', 100)
		user.do_attack_animation(src)
		if (do_after(user, 50, user.loc))
			health = 0
			try_destroy()
			if (prob(50))
				if (istype(user, /mob/living/carbon/human))
					var/mob/living/carbon/human/H = user
					H.adaptStat("strength", 1)
			return
	else
		switch(W.damtype)
			if ("fire")
				health -= W.force * TRUE
			if ("brute")
				health -= W.force * 0.20

	playsound(get_turf(src), 'sound/effects/wood_cutting.ogg', 100)
	user.do_attack_animation(src)
	try_destroy()
	..()

/obj/structure/wild/proc/try_destroy()
	if (health <= 0)
		visible_message("<span class='danger'>[src] is broken into pieces!</span>")
		qdel(src)
		return


/obj/structure/wild/bullet_act(var/obj/item/projectile/proj)
	if (prob(proj.damage - 30)) // makes shrapnel unable to take down trees
		visible_message("<span class = 'danger'>[src] collapses!</span>")
		qdel(src)

/obj/structure/wild/tree
	name = "small tree"
	icon_state = "tree"
	opacity = TRUE
	density = TRUE
	sways = TRUE
	amount = 5

/obj/structure/wild/tree/dead_tree
	name = "dead tree"
	icon = 'icons/obj/flora/deadtrees.dmi'
	icon_state = "tree_1"
	opacity = TRUE
	density = TRUE
	sways = FALSE
	amount = 5

/obj/structure/wild/tree/live_tree
	name = "tree"
	icon = 'icons/obj/flora/bigtrees.dmi'
	icon_state = "tree_1"
	opacity = TRUE
	density = TRUE
	sways = FALSE
	amount = 5

/obj/structure/wild/tree/live_tree/New()
	..()
	icon_state = "tree_[rand(1,5)]"

/obj/structure/wild/tree/live_tree/update_icon()
	..()
	if (season == "WINTER")
		icon = 'icons/obj/flora/bigtrees_winter.dmi'

	else if (season == "SUMMER")
		icon = 'icons/obj/flora/bigtrees.dmi'

	else if (season == "FALL")
		if (prob(40))
			icon = 'icons/obj/flora/deadtrees.dmi'
		else
			icon = 'icons/obj/flora/bigtrees.dmi'
	else if (season == "SPRING")
		if (prob(40))
			icon = 'icons/obj/flora/bigtrees.dmi'
		else
			icon = 'icons/obj/flora/deadtrees.dmi'

/obj/structure/wild/tree/fire_act(temperature)
	if (prob(15 * (temperature/500)))
		visible_message("<span class = 'warning'>[src] collapses.</span>")
		qdel(src)

/obj/structure/wild/tree/anchored

/obj/structure/wild/tree/New()
	..()
	if (!istype(src, /obj/structure/wild/tree/anchored))
		pixel_x = rand(-8,8)

/obj/structure/wild/tree/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/material/kitchen/utensil/knife))
		health -= 10
		visible_message("<span class='danger'>[user] tries to chop down the [src]!</span>")
		playsound(get_turf(src), 'sound/effects/wood_cutting.ogg', 100)
		user.do_attack_animation(src)
	else
		..()
/obj/structure/wild/palm
	name = "palm tree"
	icon = 'icons/misc/beach2.dmi'
	icon_state = "palm1"
	opacity = TRUE
	density = TRUE
	sways = FALSE
	amount = 4
	var/cooldown_sap = FALSE

/obj/structure/wild/palm/attackby(obj/item/W as obj, mob/user as mob)
	if(istype(W,/obj/item/weapon/material/kitchen/utensil/knife/bone))
		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
		if (!istype(user.l_hand, /obj/item/weapon/reagent_containers/food/drinks/drinkingglass/tribalpot) && !istype(user.r_hand, /obj/item/weapon/reagent_containers/food/drinks/drinkingglass/tribalpot))
			user << "<span class = 'warning'>You need to have a pot in one of your hands in order to extract palm sap.</span>"
			return
		else
			var/done = FALSE
			if (cooldown_sap == TRUE)
				user << "Sap was extracted from this palm recently, you need to wait before collecting it again."
				return
			if (istype(user.l_hand, /obj/item/weapon/reagent_containers/food/drinks/drinkingglass/tribalpot) && cooldown_sap == FALSE)
				user << "You start extracting the palm sap..."
				if (do_after(user, 50, user.loc) && done == FALSE)
					user << "You finish extracting the palm sap."
					qdel(user.l_hand)
					new/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/tribalpot/palmsap(user.loc)
					cooldown_sap = TRUE
					spawn(3000)
						cooldown_sap = FALSE
				done = TRUE
			else if (istype(user.r_hand, /obj/item/weapon/reagent_containers/food/drinks/drinkingglass/tribalpot) && cooldown_sap == FALSE)
				user << "You start extracting the palm sap..."
				if (do_after(user, 50, user.loc) && done == FALSE)
					user << "You finish extracting the palm sap."
					qdel(user.r_hand)
					new/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/tribalpot/palmsap(user.loc)
					cooldown_sap = TRUE
					spawn(3000)
						cooldown_sap = FALSE
				done = TRUE

	else
		..()
/obj/structure/wild/palm/fire_act(temperature)
	if (prob(15 * (temperature/500)))
		visible_message("<span class = 'warning'>[src] collapses.</span>")
		qdel(src)

/obj/structure/wild/tree/try_destroy()
	if (health <= 0)
		visible_message("<span class='danger'>[src] is broken into pieces!</span>")
		var/obj/item/stack/material/wood/dropwood = new /obj/item/stack/material/wood(get_turf(src))
		dropwood.amount = 4
		qdel(src)
		return

/obj/structure/wild/palm/try_destroy()
	if (health <= 0)
		visible_message("<span class='danger'>[src] is broken into pieces!</span>")
		var/obj/item/stack/material/wood/dropwood = new /obj/item/stack/material/wood(get_turf(src))
		dropwood.amount = 3
		qdel(src)
		return
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

/obj/structure/wild/burnedbush
	name = "dead twigs"
	icon_state = "burnedbush1"
	opacity = FALSE
	density = FALSE

/obj/structure/wild/junglebush
	name = "small vegetation"
	icon = 'icons/obj/flora/jungleflora.dmi'
	icon_state = "1"
	opacity = FALSE
	density = FALSE
	var/healthamount = 1

/obj/structure/wild/smallbush
	name = "small bush"
	icon = 'icons/obj/flora/ausflora.dmi'
	icon_state = "smallbush1"
	opacity = FALSE
	density = FALSE

/obj/structure/wild/smallbush/New()
	..()
	icon_state = "smallbush[rand(1,42)]"

/obj/structure/wild/burnedtree
	name = "burned tree"
	icon_state = "burnedtree1"
	opacity = FALSE
	density = FALSE

/obj/structure/wild/rock
	name = "rock"
	icon_state = "rock1"
	opacity = FALSE
	density = FALSE
	amount = 0

/obj/structure/wild/tallgrass
	name = "tall grass"
	icon = 'icons/obj/wild.dmi'
	icon_state = "tall_grass_1"
	opacity = FALSE
	density = FALSE
	layer = 5.1

/obj/structure/wild/tallgrass2
	name = "tall grass"
	icon = 'icons/obj/wild.dmi'
	icon_state = "tall_grass_5"
	opacity = FALSE
	density = FALSE

/obj/structure/wild/tallgrass/New()
	..()
	icon_state = "tall_grass_[rand(1,4)]"

/obj/structure/wild/tallgrass2/New()
	..()
	icon_state = "tall_grass_[rand(5,8)]"
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
	icon_state = "burnedbush[rand(1,9)]"

/obj/structure/wild/junglebush/New()
	..()
	icon_state = "[rand(1,30)]"

/obj/structure/wild/junglebush/attackby(obj/item/W as obj, mob/user as mob)
	user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	if(istype(W,/obj/item/weapon/material/kitchen/utensil/knife))
		user.do_attack_animation(src)
		if (healthamount == 1)
			if (prob(25))
				user << "You harvest some medicinal leaves."
				new /obj/item/stack/medical/advanced/bruise_pack/herbs(get_turf(user))
				healthamount = 0
			else
				user << "You couldn't find any good leaves in this plant."
				healthamount = 0
		else
			user << "There are no leaves to harvest here."
	..()

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
	amount = 9
	health = 200
	maxhealth = 200

/obj/structure/wild/jungle/fire_act(temperature)
	if (prob(15 * (temperature/500)))
		visible_message("<span class = 'warning'>[src] collapses.</span>")
		qdel(src)

/obj/structure/wild/jungle/New()
	..()
	icon_state = "tree[rand(1,7)]"

/obj/structure/wild/jungle/try_destroy()
	if (health <= 0)
		visible_message("<span class='danger'>[src] is broken into pieces!</span>")
		var/obj/item/stack/material/wood/dropwood = new /obj/item/stack/material/wood(get_turf(src))
		dropwood.amount = 7
		qdel(src)
		return

/obj/structure/wild/largejungle
	name = "large jungle bush"
	icon = 'icons/obj/flora/largejungleflora.dmi'
	icon_state = "bush1"
	opacity = FALSE
	density = FALSE

/obj/structure/wild/largejungle/New()
	..()
	if (prob(75))
		icon_state = "bush[rand(1,6)]"
	else
		icon_state = "rocks[rand(1,3)]"