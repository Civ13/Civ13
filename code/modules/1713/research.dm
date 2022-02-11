//////////////////////////////////////////////////////////////////
//  Research books  //////////////////////////////////////////////
//////////////////////////////////////////////////////////////////
//TO DO: Split research book items to diiferent items
/obj/item/weapon/book/research
	name = "blank scroll"
	icon_state = "scroll0"
	title = "Blank Scroll"
	desc = "A blank parchement scroll."
	var/list/completed = list()
	var/k_class = "none"
	var/k_level = 0
	var/styleb = "scroll"
	unique = TRUE

/obj/item/weapon/book/research/New()
	..()
	if (map.ordinal_age >= 3)
		name = "blank research book"
		icon_state = "research0"
		title = "Blank Book"
		desc = "A blank scientific book."
		styleb = "book"
	else if (map.ordinal_age == 0)
		name = "blank slate"
		icon_state = "research_rock0"
		title = "Blank Slate"
		desc = "A blank slate, where you can carve scientific information."
		styleb = "research_rock"

/obj/item/weapon/book/research/attack_self(var/mob/living/human/user as mob)
	if (!completed.len)
		var/list/display = list("Cancel")
		if (map.ordinal_age < 3)
			display = list("Cancel", "Industry", "Anatomy", "Fencing", "Archery", "Medicine", "Philosophy")
		else
			display = list("Cancel", "Industry", "Anatomy", "Fencing", "Archery", "Gunpowder", "Medicine", "Philosophy")
		var/choice = WWinput(user, "Which subject do you wish to write about?", "Scientific [name] production", "Cancel", display)
		var/modif = 1
		if (user.religion_check() == "Knowledge")
			modif += 0.15
		if (user.religious_clergy == "Monks")
			modif += 0.3
		user << "<span class='notice'>You begin to transpose your knowledge to the [name].</span>"
		var/success = FALSE
		switch (choice)
			if ("Industry")
				if (do_after(user, (300*(user.getStatCoeff("crafting")))/modif, src))
					success = TRUE
					k_level = (user.getStatCoeff("crafting"))
					name = pick("Woodcutting Basics, by [user]", "Mining and Industrialization, by [user]", "Furniture: How to Complete a Home, by [user]", "Building and Construction Basics, by [user]")
			if ("Anatomy")
				if (do_after(user, (300*((user.getStatCoeff("dexterity")+user.getStatCoeff("strength"))))/modif, src))
					success = TRUE
					k_level = ((user.getStatCoeff("dexterity")+user.getStatCoeff("strength")))
					name = pick("Human Body Limits, by [user]", "Increasing Muscular Mass, by [user]", "Complete Guide to Human Anatomy, by [user]", "Athletics Guide, by [user]")
			if ("Fencing")
				if (do_after(user, (300*(user.getStatCoeff("swords")))/modif, src))
					success = TRUE
					k_level = (user.getStatCoeff("swords"))
					name = pick("Swords & Swordfighting, by [user]", "Fencing: The Human Art, by [user]", "Introduction to Swordfighting, by [user]", "From Spears to Pikes, by [user]")
			if ("Archery")
				if (do_after(user, (300*(user.getStatCoeff("bows")))/modif, src))
					success = TRUE
					k_level = (user.getStatCoeff("bows"))
					name = pick("Bows & Longbows, by [user]", "On Archery Physics, by [user]", "Archery and Accuracy, by [user]", "The Archer's Guide, by [user]")
			if ("Gunpowder")
				if (do_after(user, (300*((user.getStatCoeff("pistol")+user.getStatCoeff("rifle"))))/modif, src))
					success = TRUE
					k_level = ((user.getStatCoeff("pistol")+user.getStatCoeff("rifle")))
					name = pick("Muskets and Pistols: The Complete Guide, by [user]", "Gun Rifling, by [user]", "Cannons, Muskets & Blunderbusses, by [user]", "The Soldiers Companion, by [user]")
			if ("Medicine")
				if (do_after(user, (300*(user.getStatCoeff("medical")))/modif, src))
					success = TRUE
					k_level = (user.getStatCoeff("medical"))
					name = pick("Diseases of the Blood, by [user]", "Religion & Cures, by [user]", "Surgery Guide, by [user]", "Amputation: A Beginners Guide, by [user]")
			if ("Philosophy")
				if (do_after(user, (300*(user.getStatCoeff("philosophy")))/modif, src))
					success = TRUE
					k_level = (user.getStatCoeff("philosophy"))
					name = pick("Discourse Rethoric, by [user]", "Metaphysics of Religion, by [user]", "Politics, by [user]", "Human Ethics, by [user]")
			else 
				return
		if (success)
			k_class = lowertext(choice)
			switch (choice)
				if ("Industry") 
					choice = "crafting"
				if ("Anatomy")
					choice = "strength and dexterity"
				if ("Fencing")
					choice = "swords"
				if ("Gunpowder")
					choice = "gunpowder weapons"
				else
					choice = k_class
			user.adaptStat("philosophy", 1)
			if (user.religious_clergy == "Monks")
				map.custom_religions[user.religion][3] += 6
			author = "[user]"
			completed += user
			icon_state = "[styleb]1"
			desc = "A scientific [replacetext(styleb,"research_rock","slate")], with knowledge in [choice]."
			user << "<span class='notice'>You finish the [name].</span>"
			update_icon()
	else
		if (completed[1] == user)
			user << "<span class='warning'>This book was written by you! You will not learn anything from reading it.</span>"
			return
		if (user in completed)
			user << "<span class='warning'>You have already read this book and it is unlikely that it will bring you new knowledge.</span>"
			return
		var/choice = input("This is a book by [author] on [k_class]. Do you want to study it?") in list("Yes", "No")
		if (choice == "No")
			return
		var/modif = 1
		if (user.religion_check() == "Knowledge")
			modif += 0.25
		if (user.religious_clergy == "Monks")
			modif += 0.3
		user << "<span class='notice'>You begin reading the [name] attently...</span>"
		if (do_after(user, (600*k_level)/modif, src))
			user << "<span class='notice'>You finish studying the [name]. You feel smarter already.</span>"
			if (k_class == "industry")
				user.adaptStat("crafting", (16*k_level)/modif)
			if (k_class == "medicine")
				user.adaptStat("medical", (16*k_level)/modif)
			if (k_class == "archery")
				user.adaptStat("bows", (16*k_level)/modif)
			if (k_class == "fencing")
				user.adaptStat("swords", (16*k_level)/modif)
			if (k_class == "anatomy")
				user.adaptStat("strength", (8*k_level)/modif)
				user.adaptStat("dexterity", (8*k_level)/modif)
			if (k_class == "gunpowder")
				user.adaptStat("pistol", (8*k_level)/modif)
				user.adaptStat("rifle", (8*k_level)/modif)
			if (k_class == "philosophy")
				user.adaptStat("philosophy", (16*k_level)/modif)
			completed += user

//////////////////////////////////////////////////////////////////
//  Research kit  ////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////
/obj/item/weapon/researchkit
	name = "research kit"
	icon_state = "scrolls1"
	icon = 'icons/obj/library.dmi'
	desc = "A set of instruments used to study ancient knowledge."
	weight = 1.0
	flammable = TRUE

/obj/item/weapon/researchkit/New()
	..()
	icon_state = "scrolls[map.ordinal_age]"

/obj/item/weapon/researchkit/update_icon()
	..()
	icon_state = "scrolls[map.ordinal_age]"

/obj/item/weapon/book/research/attackby(obj/O as obj, mob/living/human/user as mob)
	if (istype(O, /obj/item/weapon/researchkit))
		if (user.original_job_title == "Nomad" && map.civilizations && map.ID != MAP_TRIBES && map.ID != MAP_FOUR_KINGDOMS && map.ID != MAP_THREE_TRIBES)
			if (map.age1_done == FALSE)
				if (world.time < 36000 && map.custom_civs[user.civilization][1]+map.custom_civs[user.civilization][2]+map.custom_civs[user.civilization][3] >= (19*3))
					user << "You are already too advanced. You can research again in [(36000-world.time)/600] minutes."
					return
			else if (map.age1_done == TRUE && map.age2_done == FALSE)
				if (world.time < map.age2_timer && map.custom_civs[user.civilization][1]+map.custom_civs[user.civilization][2]+map.custom_civs[user.civilization][3] >= (map.age1_top*3))
					user << "You are already too advanced. You can research again in [(map.age2_timer-world.time)/600] minutes."
					return
			else if (map.age2_done == TRUE && map.age3_done == FALSE)
				if (world.time < map.age3_timer && map.custom_civs[user.civilization][1]+map.custom_civs[user.civilization][2]+map.custom_civs[user.civilization][3] >= (map.age2_top*3))
					user << "You are already too advanced. You can research again in [(map.age3_timer-world.time)/600] minutes."
					return
			else if (map.age3_done == TRUE && map.age4_done == FALSE)
				if (world.time < map.age3_timer && map.custom_civs[user.civilization][1]+map.custom_civs[user.civilization][2]+map.custom_civs[user.civilization][3] >= (map.age3_top*3))
					user << "You are already too advanced. You can research again in [(map.age4_timer-world.time)/600] minutes."
					return
			else if (map.age4_done == TRUE && map.age5_done == FALSE)
				if (world.time < map.age5_timer && map.custom_civs[user.civilization][1]+map.custom_civs[user.civilization][2]+map.custom_civs[user.civilization][3] >= (map.age4_top*3))
					user << "You are already too advanced. You can research again in [(map.age5_timer-world.time)/600] minutes."
					return
		if (!map.civilizations || (map.ID == MAP_TRIBES || map.ID == MAP_FOUR_KINGDOMS || map.ID == MAP_THREE_TRIBES))
			return
		else if(!completed.len)
			user << "The book is blank."
			return
		else
			var/current_tribesmen = 0
			var/studytime = 300*k_level
			var/modif = 1
			if (user.religion_check() == "Knowledge")
				modif += 0.25
			if (user.religious_clergy == "Monks")
				modif += 0.3
			var/displaytime = convert_to_textminute(studytime)
			user << "Studying this document... This will take [displaytime] to finish."
			if (do_after(user,(studytime/user.getStatCoeff("philosophy"))/modif,src))
				user << "You finish studying this document. The knowledge gained will be useful in the development of our society."
				user.adaptStat("philosophy", 1*k_level*modif)
				if (user.original_job_title == "Nomad")
					if (user.civilization != null && user.civilization != "none")
						if (alive_civilians.len <= 12)
							current_tribesmen = alive_civilians.len
						else if (alive_civilians.len > 12 && alive_civilians.len <= 30)
							current_tribesmen = alive_civilians.len/2
						else
							current_tribesmen = alive_civilians.len/min(2+((alive_civilians.len-30)*0.1),5)
						if (k_class == "medicine" || k_class == "anatomy")
							map.custom_civs[user.civilization][3] += k_level/current_tribesmen
						if (k_class == "gunpowder" || k_class == "fencing" || k_class == "archery")
							map.custom_civs[user.civilization][2] += k_level/current_tribesmen
						if (k_class == "industry" || k_class == "philosophy")
							map.custom_civs[user.civilization][1] += k_level/current_tribesmen
					else
						user << "You don't belong to any faction."
						return
				else
					if (user.civilization == civname_a)
						current_tribesmen = (alive_civilians.len/map.availablefactions.len)
						if (k_class == "medicine" || k_class == "anatomy")
							map.civa_research[3] += k_level/current_tribesmen
						if (k_class == "gunpowder" || k_class == "fencing" || k_class == "archery")
							map.civa_research[2] += k_level/current_tribesmen
						if (k_class == "industry" || k_class == "philosophy")
							map.civa_research[1] += k_level/current_tribesmen
					else if (user.civilization == civname_b)
						current_tribesmen = (alive_civilians.len/map.availablefactions.len)
						if (k_class == "medicine" || k_class == "anatomy")
							map.civb_research[3] += k_level/current_tribesmen
						if (k_class == "gunpowder" || k_class == "fencing" || k_class == "archery")
							map.civb_research[2] += k_level/current_tribesmen
						if (k_class == "industry" || k_class == "philosophy")
							map.civb_research[1] += k_level/current_tribesmen
					else if (user.civilization == civname_c)
						current_tribesmen = (alive_civilians.len/map.availablefactions.len)
						if (k_class == "medicine" || k_class == "anatomy")
							map.civc_research[3] += k_level/current_tribesmen
						if (k_class == "gunpowder" || k_class == "fencing" || k_class == "archery")
							map.civc_research[2] += k_level/current_tribesmen
						if (k_class == "industry" || k_class == "philosophy")
							map.civc_research[1] += k_level/current_tribesmen
					else if (user.civilization == civname_d)
						current_tribesmen = (alive_civilians.len/map.availablefactions.len)
						if (k_class == "medicine" || k_class == "anatomy")
							map.civd_research[3] += k_level/current_tribesmen
						if (k_class == "gunpowder" || k_class == "fencing" || k_class == "archery")
							map.civd_research[2] += k_level/current_tribesmen
						if (k_class == "industry" || k_class == "philosophy")
							map.civd_research[1] += k_level/current_tribesmen
					else if (user.civilization == civname_e)
						current_tribesmen = (alive_civilians.len/map.availablefactions.len)
						if (k_class == "medicine" || k_class == "anatomy")
							map.cive_research[3] += k_level/current_tribesmen
						if (k_class == "gunpowder" || k_class == "fencing" || k_class == "archery")
							map.cive_research[2] += k_level/current_tribesmen
						if (k_class == "industry" || k_class == "philosophy")
							map.cive_research[1] += k_level/current_tribesmen
					else if (user.civilization == civname_f)
						current_tribesmen = (alive_civilians.len/map.availablefactions.len)
						if (k_class == "medicine" || k_class == "anatomy")
							map.civf_research[3] += k_level/current_tribesmen
						if (k_class == "gunpowder" || k_class == "fencing" || k_class == "archery")
							map.civf_research[2] += k_level/current_tribesmen
						if (k_class == "industry" || k_class == "philosophy")
							map.civf_research[1] += k_level/current_tribesmen
	else
		..()
