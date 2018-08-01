
//basically, the dispensers are now wood barrels and wood crates.
/obj/structure/reagent_dispensers
	name = "Barrel"
	desc = "..."
	icon = 'icons/obj/barrel.dmi'
	icon_state = "barrel_wood"
	density = TRUE
	anchored = FALSE

	var/amount_per_transfer_from_this = 10
	var/possible_transfer_amounts = list(10,25,50,100)

	attackby(obj/item/weapon/W as obj, mob/user as mob)
		return

	New()
		var/datum/reagents/R = new/datum/reagents(1000)
		reagents = R
		R.my_atom = src
		if (!possible_transfer_amounts)
			verbs -= /obj/structure/reagent_dispensers/verb/set_APTFT
		..()

	examine(mob/user)
		if (!..(user, 2))
			return
		user << "<span class = 'notice'>It contains:</span>"
		if (reagents && reagents.reagent_list.len)
			for (var/datum/reagent/R in reagents.reagent_list)
				user << "<span class = 'notice'>[R.volume] units of [R.name]</span>"
		else
			user << "<span class = 'notice'>Nothing.</span>"

	verb/set_APTFT() //set amount_per_transfer_from_this
		set name = "Set transfer amount"
		set category = null
		set src in view(1)
		var/N = input("Amount per transfer from this:","[src]") as null|anything in possible_transfer_amounts
		if (N)
			amount_per_transfer_from_this = N

	ex_act(severity)
		switch(severity)
			if (1.0)
				qdel(src)
				return
			if (2.0)
				if (prob(50))
					new /obj/effect/effect/water(loc)
					qdel(src)
					return
			if (3.0)
				if (prob(5))
					new /obj/effect/effect/water(loc)
					qdel(src)
					return
			else
		return







//Dispensers

/obj/structure/reagent_dispensers/barrel/water
	name = "water barrel"
	desc = "A wood barrel, filled with drinking water."
	icon = 'icons/obj/barrel.dmi'
	icon_state = "barrel_wood_drinks"
	amount_per_transfer_from_this = 10
	New()
		..()
		reagents.add_reagent("water",250)

/obj/structure/reagent_dispensers/barrel/beer
	name = "beer barrel"
	desc = "A barrel of beer. Keep it secured!"
	icon = 'icons/obj/barrel.dmi'
	icon_state = "barrel_wood_drinks"
	amount_per_transfer_from_this = 10
	New()
		..()
		reagents.add_reagent("beer",200)

/obj/structure/reagent_dispensers/barrel/rum
	name = "rum barrel"
	desc = "A barrel of rum. You better keep it locked and away from the crew!"
	icon = 'icons/obj/barrel.dmi'
	icon_state = "barrel_wood_drinks"
	amount_per_transfer_from_this = 10
	New()
		..()
		reagents.add_reagent("rum",200)

/obj/structure/reagent_dispensers/barrel/gunpowder
	name = "gunpowder barrel"
	desc = "A barrel of gunpowder. Don't light it on fire."
	icon = 'icons/obj/barrel.dmi'
	icon_state = "barrel_wood_gunpowder"
	amount_per_transfer_from_this = 10
	New()
		..()
		reagents.add_reagent("gunpowder",200)

/obj/structure/reagent_dispensers/barrel/gunpowder/bullet_act(var/obj/item/projectile/proj)
	if (proj && !proj.nodamage)
		if (prob(30))
			visible_message("<span class = 'warning'>\The [src] is hit by \the [proj] and explodes!</span>")
			return explode()
	return FALSE

/obj/structure/reagent_dispensers/barrel/gunpowder/ex_act()
	explode()

/obj/structure/reagent_dispensers/barrel/gunpowder/proc/explode()
	if (reagents.total_volume > 500)
		explosion(loc,1,2,4,2)
	else if (reagents.total_volume > 100)
		explosion(loc,0,1,3,1)
	else if (reagents.total_volume > 50)
		explosion(loc,-1,1,2,1)
	if (src) qdel(src)

/obj/structure/reagent_dispensers/barrel/gunpowder/fire_act(temperature)
	if (temperature > T0C+500)
		explode()
	return ..()
