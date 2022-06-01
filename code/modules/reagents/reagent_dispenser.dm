
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

	var/custom_code = 0
	var/locked = 0
	map_storage_saved_vars = "density;icon_state;dir;name;pixel_x;pixel_y;custom_code;locked"
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
		else if (istype(W, /obj/item/weapon/wrench))
			..()
		else if (istype(W, /obj/item/weapon/key))
			var/obj/item/weapon/key/K = W
			if (W.code != custom_code)
				user << "This key does not match this lock!"
				return
			if (custom_code == 0 && K.code != 0)
				var/choice = WWinput(user, "Are you sure you want to assign this key to \the [src]?", "Lock", "No", list("Yes","No"))
				if (choice == "No")
					return
				else
					locked = TRUE
					custom_code = K.code
					visible_message("<span class = 'notice'>[user] locks \the [src].</span>")
					playsound(get_turf(user), 'sound/effects/door_lock_unlock.ogg', 100)
					return
			if (K.code == custom_code)
				locked = !locked
				if (locked == 1)
					visible_message("<span class = 'notice'>[user] locks \the [src].</span>")
					playsound(get_turf(user), 'sound/effects/door_lock_unlock.ogg', 100)
					return
				else if (locked == 0)
					visible_message("<span class = 'notice'>[user] unlocks \the [src].</span>")
					playsound(get_turf(user), 'sound/effects/door_lock_unlock.ogg', 100)
					return
		else if (istype(W, /obj/item/weapon/storage/belt/keychain) && custom_code != 0)
			for (var/obj/item/weapon/key/KK in W.contents)
				if (KK.code == custom_code)
					locked = !locked
					if (locked == 1)
						visible_message("<span class = 'notice'>[user] locks \the [src].</span>")
						playsound(get_turf(user), 'sound/effects/door_lock_unlock.ogg', 100)
						return
					else if (locked == 0)
						visible_message("<span class = 'notice'>[user] unlocks \the [src].</span>")
						playsound(get_turf(user), 'sound/effects/door_lock_unlock.ogg', 100)
						return
			user << "No key in this keychain matches the lock!"
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
	set category = null
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


/obj/structure/reagent_dispensers/largebarrel/beer
	name = "large beer barrel"
	desc = "A large barrel of beer. Keep it secured!"
	amount_per_transfer_from_this = 20
	density = TRUE
	New()
		..()
		reagents.add_reagent("beer",950)

/obj/structure/reagent_dispensers/largebarrel/ale
	name = "large ale barrel"
	desc = "A large barrel of ale. Keep it secured!"
	amount_per_transfer_from_this = 20
	density = TRUE
	New()
		..()
		reagents.add_reagent("ale",950)

/obj/structure/reagent_dispensers/largebarrel/water
	name = "large water barrel"
	desc = "A large barrel of water. Keep it secured!"
	amount_per_transfer_from_this = 20
	density = TRUE
	New()
		..()
		reagents.add_reagent("water",950)



/obj/structure/reagent_dispensers/peppertank
	name = "Pepper Spray Refiller"
	desc = "Refill pepper spray canisters."
	icon = 'icons/obj/barrel.dmi'
	icon_state = "peppertank"
	anchored = TRUE
	density = FALSE
	amount_per_transfer_from_this = 45
	New()
		..()
		reagents.add_reagent("condensedcapsaicin",1000)

/obj/structure/reagent_dispensers/fountain
	name = "water fountain"
	desc = "A water fountain with a big tank on top."
	icon_state = "dispenser_water1"
	anchored = TRUE
	amount_per_transfer_from_this = 10
	New()
		..()
		reagents.add_reagent("water",2000)