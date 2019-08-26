/obj/structure/wild/berrybush
	name = "berry bush"
	icon = 'icons/obj/flora/berries.dmi'
	icon_state = "tintobush_1"
	deadicon = 'icons/obj/flora/berries.dmi'
	deadicon_state = "burnedbush"
	opacity = FALSE
	density = FALSE
	health = 40
	maxhealth = 40
	var/berries = 0
	var/btype = /obj/item/weapon/reagent_containers/food/snacks/grown/berries
	var/randeffect = "neutral"

/obj/structure/wild/berrybush/proc/berryproc()
	spawn(3000)
		berries++

/obj/structure/wild/berrybush/fire_act(temperature)
	if (prob(55 * (temperature/500)))
		visible_message("<span class = 'warning'>[src] is burned away.</span>")
		if (prob(18))
			new/obj/structure/wild/burnedbush(src.loc)
		qdel(src)

/obj/structure/wild/berrybush/attack_hand(mob/user as mob)
	if (user.a_intent == I_GRAB && ishuman(user) && berries > 0)
		var/mob/living/carbon/human/H = user
		H << "You start foraging for some berries..."
		if (do_after(user, 80, src))
			if (src && berries >= 1)
				H << "You collect some berries."
				new btype(get_turf(src))
				berries--
				berryproc()
			else
				user << "There are no berries to harvest here."
		else
			user << "You stop foraging."
	else
		..()


/obj/structure/wild/berrybush/tinto
	name = "tinto berry bush"
	icon_state = "tintobush_1"
	berries = 1
	btype = /obj/item/weapon/reagent_containers/food/snacks/grown/berries/tinto

/obj/structure/wild/berrybush/amar
	name = "amar berry bush"
	icon_state = "amarbush_1"
	berries = 1
	btype = /obj/item/weapon/reagent_containers/food/snacks/grown/berries/amar

/obj/structure/wild/berrybush/azul
	name = "azul berry bush"
	icon_state = "azulbush_1"
	berries = 1
	btype = /obj/item/weapon/reagent_containers/food/snacks/grown/berries/azul

/obj/structure/wild/berrybush/majo
	name = "majo berry bush"
	icon_state = "majobush_1"
	berries = 1
	btype = /obj/item/weapon/reagent_containers/food/snacks/grown/berries/majo

/obj/structure/wild/berrybush/narco
	name = "narco berry bush"
	icon_state = "narcobush_1"
	berries = 1
	btype = /obj/item/weapon/reagent_containers/food/snacks/grown/berries/narco
