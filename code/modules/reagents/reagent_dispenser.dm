
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
	var/max_capacity = 1000
	var/amount_per_transfer_from_this = 20
	var/possible_transfer_amounts = list(10,20,25,50,100)
	var/dmode = "dispense"
	var/label_text = ""
	var/base_name
	proc/update_name_label()
		playsound(src,'sound/effects/pen.ogg',40,1)
		if (label_text == "")
			name = base_name
		else
			name = "[base_name] ([label_text])"

	attackby(obj/item/weapon/W as obj, mob/user as mob)
		if (istype(W, /obj/item/weapon/pen))
			var/tmp_label = sanitizeSafe(input(user, "Enter a label for [name]", "Label", label_text), MAX_NAME_LEN)
			if (length(tmp_label) > 15)
				user << "<span class='notice'>The label can be at most 15 characters long.</span>"
			else
				user << "<span class='notice'>You set the label to \"[tmp_label]\".</span>"
				label_text = tmp_label
				update_name_label()
			return
		else
			return

	New()
		var/datum/reagents/R = new/datum/reagents(max_capacity)
		reagents = R
		R.my_atom = src
		if (!possible_transfer_amounts)
			verbs -= /obj/structure/reagent_dispensers/verb/set_APTFT
		..()
		base_name = name
	examine(mob/user)
		if (!..(user, 2))
			return
		user << "<span class = 'notice'>It contains:</span>"
		if (reagents && reagents.reagent_list.len)
			var/g_name = "nothing"
			var/g_amount = 0
			for (var/datum/reagent/R in reagents.reagent_list)
				if (R.volume >= g_amount)
					g_name = R.name
					g_amount = R.volume
			if (g_amount)
				user << "<span class = 'notice'>[g_amount] units of [g_name]</span>"
			else
				user << "<span class = 'notice'>Nothing.</span>"
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

/obj/structure/reagent_dispensers/verb/switch_mode()
	set name = "Switch Mode"
	set desc = "Switch between dispensing and refilling"
	set src in range(1, usr)

	if (!isliving(usr))
		return

	if (dmode=="dispense")
		dmode = "refill"
		usr << "[src] switched to refill mode."
	else if (dmode=="refill")
		dmode = "dispense"
		usr << "[src] switched to dispense mode."

/obj/structure/reagent_dispensers/largebarrel
	name = "large barrel"
	desc = "A large barrel with high capacity."
	icon_state = "beer_barrel"
	max_capacity = 1000