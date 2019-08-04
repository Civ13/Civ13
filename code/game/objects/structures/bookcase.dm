/obj/structure/bookcase
	name = "bookcase"
	icon = 'icons/obj/library.dmi'
	icon_state = "book-0"
	anchored = TRUE
	density = TRUE
	opacity = TRUE
	var/current_research = 0
	var/sum_i = 0
	var/sum_m = 0
	var/sum_h = 0
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE

/obj/structure/bookcase/initialize()
	for (var/obj/item/I in loc)
		if (istype(I, /obj/item/weapon/book))
			I.loc = src
	update_icon()

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
	if (map.ordinal_age >= 3)
		if (contents.len < 5)
			icon_state = "book-[contents.len]"
		else
			icon_state = "book-5"
	else
		if (contents.len > 8)
			icon_state = "books-5"
		else if (contents.len <= 8 && contents.len > 6)
			icon_state = "books-4"
		else if (contents.len <= 6 && contents.len > 4)
			icon_state = "books-3"
		else if (contents.len <= 4 && contents.len > 2)
			icon_state = "books-2"
		else if (contents.len <= 2 && contents.len > 0)
			icon_state = "books-1"
		else if (contents.len == 0)
			icon_state = "books-0"

//for civ mode
/obj/structure/bookcase/proc/check_research()
	if (!map.civilizations || map.ID == MAP_TRIBES)
		return
	else
		for (var/obj/item/weapon/book/research/RB in contents)
			if (RB.completed)
				if (RB.k_class == "medicine" || RB.k_class == "anatomy")
					sum_h += RB.k_level
				if (RB.k_class == "gunpowder" || RB.k_class == "fencing" || RB.k_class == "archery")
					sum_m += RB.k_level
				if (RB.k_class == "industry" || RB.k_class == "philosophy")
					sum_i += RB.k_level
		current_research = sum_i+sum_m+sum_h

/obj/structure/bookcase/attackby(obj/O as obj, mob/living/carbon/human/user as mob)
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
		user << (anchored ? "<span class='notice'r>You unfasten \the [src] from the floor.</span>" : "<span class='notice'>You secure \the [src] to the floor.</span>")
		anchored = !anchored
	else if (istype(O,/obj/item/weapon/hammer))
		playsound(loc, 'sound/items/Screwdriver.ogg', 75, TRUE)
		user << "<span class='notice'>You begin dismantling \the [src].</span>"
		if (do_after(user,25,src))
			user << "<span class='notice'>You dismantle \the [src].</span>"
			new /obj/item/stack/material/wood(get_turf(src))
			for (var/obj/item/weapon/book/b in contents)
				b.loc = (get_turf(src))
			qdel(src)
	else if (istype(O, /obj/item/weapon/researchkit))
		if (user.original_job_title == "Nomad")
			if (map.age1_done == FALSE)
				if (world.time < 36000 && map.custom_civs[user.civilization][1]+map.custom_civs[user.civilization][2]+map.custom_civs[user.civilization][3] >= (19*3))
					user << "You are already too advanced. You can research again in [(36000-world.time)/600] minutes."
					return
			else if (map.age1_done == TRUE && map.age2_done == FALSE)
				if (world.time < map.age2_timer && map.custom_civs[user.civilization][1]+map.custom_civs[user.civilization][2]+map.custom_civs[user.civilization][3] >= (map.age1_top*3))
					user << "You are already too advanced. You can research again in [(map.age2_timer-world.time)/600] minutes."
					return
			if (map.age2_done == TRUE && map.age3_done == FALSE)
				if (world.time < map.age3_timer && map.custom_civs[user.civilization][1]+map.custom_civs[user.civilization][2]+map.custom_civs[user.civilization][3] >= (map.age2_top*3))
					user << "You are already too advanced. You can research again in [(map.age3_timer-world.time)/600] minutes."
					return
			if (map.age3_done == TRUE && map.age4_done == FALSE)
				if (world.time < map.age4_timer && map.custom_civs[user.civilization][1]+map.custom_civs[user.civilization][2]+map.custom_civs[user.civilization][3] >= (map.age3_top*3))
					user << "You are already too advanced. You can research again in [(map.age4_timer-world.time)/600] minutes."
					return
			if (map.age4_done == TRUE && map.age5_done == FALSE)
				if (world.time < map.age5_timer && map.custom_civs[user.civilization][1]+map.custom_civs[user.civilization][2]+map.custom_civs[user.civilization][3] >= (map.age4_top*3))
					user << "You are already too advanced. You can research again in [(map.age5_timer-world.time)/600] minutes."
					return
			if (map.age5_done == TRUE && map.age6_done == FALSE)
				if (world.time < map.age6_timer && map.custom_civs[user.civilization][1]+map.custom_civs[user.civilization][2]+map.custom_civs[user.civilization][3] >= (map.age5_top*3))
					user << "You are already too advanced. You can research again in [(map.age6_timer-world.time)/600] minutes."
					return
			if (map.age6_done == TRUE && map.age7_done == FALSE)
				if (world.time < map.age7_timer && map.custom_civs[user.civilization][1]+map.custom_civs[user.civilization][2]+map.custom_civs[user.civilization][3] >= (map.age6_top*3))
					user << "You are already too advanced. You can research again in [(map.age7_timer-world.time)/600] minutes."
					return
			if (map.age7_done == TRUE && map.age8_done == FALSE)
				if (world.time < map.age8_timer && map.custom_civs[user.civilization][1]+map.custom_civs[user.civilization][2]+map.custom_civs[user.civilization][3] >= (map.age7_top*3))
					user << "You are already too advanced. You can research again in [(map.age8_timer-world.time)/600] minutes."
					return
		if (!map.civilizations || map.ID == MAP_TRIBES)
			return
		else if(!contents.len)
			user << "The [name] is empty."
			return
		else
			check_research()
			var/current_tribesmen = (alive_civilians.len/map.availablefactions.len)
			if (map.nomads == TRUE)
				if (alive_civilians.len <= 12)
					current_tribesmen = alive_civilians.len
				else if (alive_civilians.len > 12 && alive_civilians.len <= 30)
					current_tribesmen = alive_civilians.len/2
				else
					current_tribesmen = alive_civilians.len/min(2+((alive_civilians.len-30)*0.1),5)
			var/studytime = (300*current_research)/current_tribesmen
			var/displaytime = convert_to_textminute(studytime)
			var/modif = 1
			if (user.religion_check() == "Knowledge")
				modif += 0.15
			if (user.religious_clergy == "Monks")
				modif += 0.3
			user << "Studying these documents... This will take [displaytime] to finish."
			if (do_after(user,(studytime/user.getStatCoeff("philosophy"))/modif,src))
				user << "You finish studying these documents. The knowledge gained will be useful in the development of our society."
				user.adaptStat("philosophy", 1*current_research)
				if (user.civilization == civname_a)
					map.civa_research[1] += sum_i
					map.civa_research[2] += sum_m
					map.civa_research[3] += sum_h
				else if (user.civilization == civname_b)
					map.civb_research[1] += sum_i
					map.civb_research[2] += sum_m
					map.civb_research[3] += sum_h
				else if (user.civilization == civname_c)
					map.civc_research[1] += sum_i
					map.civc_research[2] += sum_m
					map.civc_research[3] += sum_h
				else if (user.civilization == civname_d)
					map.civd_research[1] += sum_i
					map.civd_research[2] += sum_m
					map.civd_research[3] += sum_h
				else if (user.civilization == civname_e)
					map.cive_research[1] += sum_i
					map.cive_research[2] += sum_m
					map.cive_research[3] += sum_h
				else if (user.civilization == civname_f)
					map.civf_research[1] += sum_i
					map.civf_research[2] += sum_m
					map.civf_research[3] += sum_h
				else if (user.civilization != "none" && user.civilization != null)
					map.custom_civs[user.civilization][1] += sum_i
					map.custom_civs[user.civilization][2] += sum_m
					map.custom_civs[user.civilization][3] += sum_h
				else
					..()
		sum_i = null
		sum_m = null
		sum_h = null
