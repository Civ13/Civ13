/obj/structure/bookcase
	name = "bookcase"
	icon = 'icons/obj/library.dmi'
	icon_state = "book-0"
	anchored = TRUE
	density = TRUE
	opacity = TRUE

/obj/structure/bookcase/initialize()
	for (var/obj/item/I in loc)
		if (istype(I, /obj/item/weapon/book))
			I.loc = src
	update_icon()

/obj/structure/bookcase/attackby(obj/O as obj, mob/user as mob)
	if (istype(O, /obj/item/weapon/book))
		user.drop_item()
		O.loc = src
		update_icon()
	else if (istype(O, /obj/item/weapon/pen))
		var/newname = sanitizeSafe(input("What would you like to title this bookshelf?"), MAX_NAME_LEN)
		if (!newname)
			return
		else
			name = ("bookcase ([newname])")
	else if (istype(O,/obj/item/weapon/wrench))
		playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
		user << (anchored ? "<span class='notice'>You unfasten \the [src] from the floor.</span>" : "<span class='notice'>You secure \the [src] to the floor.</span>")
		anchored = !anchored
	else if (istype(O,/obj/item/weapon/screwdriver))
		playsound(loc, 'sound/items/Screwdriver.ogg', 75, TRUE)
		user << "<span class='notice'>You begin dismantling \the [src].</span>"
		if (do_after(user,25,src))
			user << "<span class='notice'>You dismantle \the [src].</span>"
			new /obj/item/stack/material/wood(get_turf(src), amount = 3)
			for (var/obj/item/weapon/book/b in contents)
				b.loc = (get_turf(src))
			qdel(src)

	else
		..()

/obj/structure/bookcase/attack_hand(var/mob/user as mob)
	if (contents.len)
		var/obj/item/weapon/book/choice = WWinput(user, "Which book would you like to remove from the shelf?", "Bookcase", WWinput_first_choice(contents), WWinput_list_or_null(contents))
		if (choice)
			if (!usr.canmove || usr.stat || usr.restrained() || !in_range(loc, usr))
				return
			if (ishuman(user))
				if (!user.get_active_hand())
					user.put_in_hands(choice)
			else
				choice.loc = get_turf(src)
			update_icon()

/obj/structure/bookcase/ex_act(severity)
	switch(severity)
		if (1.0)
			for (var/obj/item/weapon/book/b in contents)
				qdel(b)
			qdel(src)
			return
		if (2.0)
			for (var/obj/item/weapon/book/b in contents)
				if (prob(50)) b.loc = (get_turf(src))
				else qdel(b)
			qdel(src)
			return
		if (3.0)
			if (prob(50))
				for (var/obj/item/weapon/book/b in contents)
					b.loc = (get_turf(src))
				qdel(src)
			return
		else
	return

/obj/structure/bookcase/update_icon()
	if (contents.len < 5)
		icon_state = "book-[contents.len]"
	else
		icon_state = "book-5"

/obj/structure/bookcase/manuals/medical
	name = "Medical Manuals bookcase"

	New()
		..()
		new /obj/item/weapon/book/manual/medical_diagnostics_manual(src)
		new /obj/item/weapon/book/manual/medical_diagnostics_manual(src)
		new /obj/item/weapon/book/manual/medical_diagnostics_manual(src)
		update_icon()


/obj/structure/bookcase/manuals/engineering
	name = "Engineering Manuals bookcase"

	New()
		..()
		new /obj/item/weapon/book/manual/engineering_construction(src)
		new /obj/item/weapon/book/manual/engineering_guide(src)
		update_icon()