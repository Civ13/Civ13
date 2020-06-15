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
		var/mob/living/human/H = user
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
/obj/structure/wild/berrybush/attackby(obj/item/weapon/W as obj, mob/user as mob)
	var/mob/living/human/H = user
	if(istype(W, /obj/item/weapon/berriesgatherer))
		if (ishuman(user) && berries > 0)
			//var/mob/living/human/H = user
			H << "You start gathering some berries..."
			if (do_after(user, 80, src))
				if (src && berries >= 1)
					new btype(get_turf(src))
					new btype(get_turf(src))
					/*if(rand(100) <= 10)
						var/obj/item/stack/berryseeds/BS = new /obj/item/stack/berryseeds(get_turf(src))
						BS.bushtype = src*/
					berries--
					berryproc()
				else
					user << "There are no berries to harvest here."
			else
				user << "You stop gathering berries."
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

/obj/structure/wild/berrybush/zelenyy
	name = "zelenyy berry bush"
	icon_state = "zelenyybush_1"
	berries = 1
	btype = /obj/item/weapon/reagent_containers/food/snacks/grown/berries/zelenyy

/obj/structure/wild/berrybush/marron
	name = "marron berry bush"
	icon_state = "marronbush_1"
	berries = 1
	btype = /obj/item/weapon/reagent_containers/food/snacks/grown/berries/marron

/obj/structure/wild/berrybush/corcairghorm
	name = "corcairghorm berry bush"
	icon_state = "corcairghormbush_1"
	berries = 1
	btype = /obj/item/weapon/reagent_containers/food/snacks/grown/berries/corcairghorm


/obj/item/weapon/reagent_containers/food/snacks/grown/berries
	name = "berries"
	icon = 'icons/obj/flora/berries.dmi'
	icon_state = "tintoberry"
	satisfaction = 3
	var/randeffect = "neutral"
	nutriment_desc = list("fruit" = 1)
	nutriment_amt = 1
	decay = 18*600
/obj/item/weapon/reagent_containers/food/snacks/grown/berries/New()
	..()
	for (var/list/i in map.berryeffects)
		if (i[1] == randeffect)
			switch (i[2])
				if ("drug","poisonous","healing")
					reagents.add_reagent(i[3],5)
					nutriment_desc = list("bitterness" = 1)
				if ("tasty")
					satisfaction = 6
					nutriment_desc = list("sweetness" = 1)
				if ("disgusting")
					satisfaction = -6
					nutriment_desc = list("disgusting food" = 1)

/obj/item/berryseeds
	name = "berry seeds"
	desc = "Seeds of some sort of berry."
	icon = 'icons/obj/flora/berries.dmi'
	icon_state = "berryseeds"
	var/bushtype = /obj/structure/wild/berrybush

/obj/item/berryseeds/attack_self(mob/user)
	new bushtype(user.loc)
	src.amount--
	if(src.amount <= 0)
		qdel(src)

/obj/item/weapon/reagent_containers/food/snacks/grown/berries/tinto
	name = "tinto berries"
	icon_state = "tintoberry"
	randeffect = "tinto"

/obj/item/weapon/reagent_containers/food/snacks/grown/berries/azul
	name = "azul berries"
	icon_state = "azulberry"
	randeffect = "azul"

/obj/item/weapon/reagent_containers/food/snacks/grown/berries/amar
	name = "amar berries"
	icon_state = "amarberry"
	randeffect = "amar"

/obj/item/weapon/reagent_containers/food/snacks/grown/berries/majo
	name = "majo berries"
	icon_state = "majoberry"
	randeffect = "majo"

/obj/item/weapon/reagent_containers/food/snacks/grown/berries/narco
	name = "narco berries"
	icon_state = "narcoberry"
	randeffect = "narco"

/obj/item/weapon/reagent_containers/food/snacks/grown/berries/zelenyy
	name = "zelenyy berries"
	icon_state = "zelenyyberry"
	randeffect = "zelenyy"

/obj/item/weapon/reagent_containers/food/snacks/grown/berries/marron
	name = "marron berries"
	icon_state = "marronberry"
	randeffect = "marron"

/obj/item/weapon/reagent_containers/food/snacks/grown/berries/corcairghorm
	name = "corcairghorm berries"
	icon_state = "corcairghormberry"
	randeffect = "corcairghorm"
