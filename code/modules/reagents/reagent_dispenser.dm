
//basically, the dispensers are now wood barrels and wood crates.
/obj/structure/reagent_dispensers
	name = "Barrel"
	desc = "..."
	icon = 'icons/obj/barrel.dmi'
	icon_state = "barrel_wood"
	density = TRUE
	anchored = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE

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