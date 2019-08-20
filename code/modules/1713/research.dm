/*
/////////////////////////////AGES///////////////////////
0-15 Stone Age (<5000 BC)
15-20 Copper Age (2-3k BC)
20-30 Bronze Age (1000 BC)
30-40 Iron age/Ancient Age (500 BC to 300 AC)
40-50 Early Medieval Age (500 to 1200)
50-60 Late Medieval (1400-1500)
60-80 Renaissance (1500-1600)
80-90 Imperial Age (1700s)
90-100 Napoleonic Age (early 1800s)
100-110 Early Industrial Age (1850-1870)
110-120 Industrial Age (1870-1900)
120-130 Early Modern Age (1900-1910)
///////////////////////////////////////////////////////
*/

/obj/item/weapon/book/research
	name = "blank scroll"
	icon_state = "scroll0"
	title = "Blank Scroll"
	desc = "A blank parchement scroll."
	var/completed = 0
	var/k_class = "none"
	var/k_level = 0
	var/styleb = "scroll"
	var/sum_a = 0
	var/sum_b = 0
	var/sum_c = 0
	var/monk = FALSE //if the book was authored by a monk
	var/religion = "none"
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



/obj/item/weapon/book/research/attack_self(var/mob/living/carbon/human/user as mob)
	if (completed == 0)
		var/list/display = list("Cancel")
		if (map.ordinal_age < 3)
			display = list("Cancel", "Industry", "Anatomy", "Fencing", "Archery", "Medicine", "Philosophy")
		else
			display = list("Cancel", "Industry", "Anatomy", "Fencing", "Archery", "Gunpowder", "Medicine", "Philosophy")
		var/choice = WWinput(user, "Which subject do you wish to write about?", "Scientific [name] production", "Cancel", display)
		if (choice == "Cancel")
			return
		var/modif = 1
		if (user.religion_check() == "Knowledge")
			modif += 0.15
		if (user.religious_clergy == "Monks")
			modif += 0.3
		if (choice == "Industry")
			user << "<span class='notice'>You begin to transpose your knowledge to the [name].</span>"
			if (do_after(user, (300*(user.getStatCoeff("crafting")))/modif, src))
				user << "<span class='notice'>You finish the [name].</span>"
				user.adaptStat("philosophy", 1)
				k_class = "industry"
				k_level = (user.getStatCoeff("crafting"))
				completed = TRUE
				if (name == "blank slate")
					icon_state = "research_rock1"
				else
					icon_state = "[styleb]1"
				name = pick("Woodcutting Basics, by [user]", "Mining and Industrialization, by [user]", "Furniture: How to Complete a Home, by [user]", "Building and Construction Basics, by [user]")
				desc = "A scientific [name], with knowledge in crafting."
				author = "[user]"
				if (user.religious_clergy == "Monks")
					monk = TRUE
					religion = user.religion
					map.custom_religions[user.religion][3] += 6
				update_icon()
				return

		if (choice == "Anatomy")
			user << "<span class='notice'>You begin to transpose your knowledge to the [name].</span>"
			if (do_after(user, (300*((user.getStatCoeff("dexterity")+user.getStatCoeff("strength"))))/modif, src))
				user << "<span class='notice'>You finish the [name].</span>"
				user.adaptStat("philosophy", 1)
				k_class = "anatomy"
				k_level = ((user.getStatCoeff("dexterity")+user.getStatCoeff("strength")))
				completed = TRUE
				icon_state = "[styleb]1"
				name = pick("Human Body Limits, by [user]", "Increasing Muscular Mass, by [user]", "Complete Guide to Human Anatomy, by [user]", "Athletics Guide, by [user]")
				desc = "A scientific [name], with knowledge in strength and dexterity."
				author = "[user]"
				if (user.religious_clergy == "Monks")
					monk = TRUE
					religion = user.religion
					map.custom_religions[user.religion][3] += 6
				update_icon()
				return

		if (choice == "Fencing")
			user << "<span class='notice'>You begin to transpose your knowledge to the [name].</span>"
			if (do_after(user, (300*(user.getStatCoeff("swords")))/modif, src))
				user << "<span class='notice'>You finish the [name].</span>"
				user.adaptStat("philosophy", 1)
				k_class = "fencing"
				k_level = (user.getStatCoeff("swords"))
				completed = TRUE
				icon_state = "[styleb]1"
				name = pick("Swords & Swordfighting, by [user]", "Fencing: The Human Art, by [user]", "Introduction to Swordfighting, by [user]", "From Spears to Pikes, by [user]")
				desc = "A scientific [name], with knowledge in swords."
				author = "[user]"
				if (user.religious_clergy == "Monks")
					monk = TRUE
					religion = user.religion
					map.custom_religions[user.religion][3] += 6
				update_icon()
				return

		if (choice == "Archery")
			user << "<span class='notice'>You begin to transpose your knowledge to the [name].</span>"
			if (do_after(user, (300*(user.getStatCoeff("bows")))/modif, src))
				user << "<span class='notice'>You finish the [name].</span>"
				user.adaptStat("philosophy", 1)
				k_class = "archery"
				k_level = (user.getStatCoeff("bows"))
				completed = TRUE
				icon_state = "[styleb]1"
				name = pick("Bows & Longbows, by [user]", "On Archery Physics, by [user]", "Archery and Accuracy, by [user]", "The Archer's Guide, by [user]")
				desc = "A scientific [name], with knowledge in archery."
				author = "[user]"
				if (user.religious_clergy == "Monks")
					monk = TRUE
					religion = user.religion
					map.custom_religions[user.religion][3] += 6
				update_icon()
				return

		if (choice == "Gunpowder")
			user << "<span class='notice'>You begin to transpose your knowledge to the [name].</span>"
			if (do_after(user, (300*((user.getStatCoeff("pistol")+user.getStatCoeff("rifle"))))/modif, src))
				user << "<span class='notice'>You finish the [name].</span>"
				user.adaptStat("philosophy", 1)
				k_class = "gunpowder"
				k_level = ((user.getStatCoeff("pistol")+user.getStatCoeff("rifle")))
				completed = TRUE
				icon_state = "[styleb]1"
				name = pick("Muskets and Pistols: The Complete Guide, by [user]", "Gun Rifling, by [user]", "Cannons, Muskets & Blunderbusses, by [user]", "The Soldiers Companion, by [user]")
				desc = "A scientific [name], with knowledge in gunpowder weapons."
				author = "[user]"
				if (user.religious_clergy == "Monks")
					monk = TRUE
					religion = user.religion
					map.custom_religions[user.religion][3] += 6
				update_icon()
				return

		if (choice == "Medicine")
			user << "<span class='notice'>You begin to transpose your knowledge to the [name].</span>"
			if (do_after(user, (300*(user.getStatCoeff("medical")))/modif, src))
				user << "<span class='notice'>You finish the [name].</span>"
				user.adaptStat("philosophy", 1)
				k_class = "medicine"
				k_level = (user.getStatCoeff("medical"))
				completed = TRUE
				icon_state = "[styleb]1"
				name = pick("Diseases of the Blood, by [user]", "Religion & Cures, by [user]", "Surgery Guide, by [user]", "Amputation: A Beginners Guide, by [user]")
				desc = "A scientific [name], with knowledge in medicine."
				author = "[user]"
				if (user.religious_clergy == "Monks")
					monk = TRUE
					religion = user.religion
					map.custom_religions[user.religion][3] += 6
				update_icon()
				return

		if (choice == "Philosophy")
			user << "<span class='notice'>You begin to transpose your knowledge to the [name].</span>"
			if (do_after(user, (300*(user.getStatCoeff("philosophy")))/modif, src))
				user << "<span class='notice'>You finish the [name].</span>"
				user.adaptStat("philosophy", 1)
				k_class = "philosophy"
				k_level = (user.getStatCoeff("philosophy"))
				completed = TRUE
				icon_state = "[styleb]1"
				name = pick("Discourse Rethoric, by [user]", "Metaphysics of Religion, by [user]", "Politics, by [user]", "Human Ethics, by [user]")
				desc = "A scientific [name], with knowledge in philosophy."
				author = "[user]"
				if (user.religious_clergy == "Monks")
					monk = TRUE
					religion = user.religion
					map.custom_religions[user.religion][3] += 6
				update_icon()
				return
	else
		if (author == "[user]")
			user << "<span class='notice'>This book was written by you! You will not learn anything from reading it...</span>"
			return
		else
			var/choice = input("This is a book by [author] on [k_class]. Do you want to study it?") in list("Yes", "No")
			if (choice == "No")
				return
			else if (choice == "Yes")
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
					qdel(src)
					return


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


/obj/item/weapon/book/research/attackby(obj/O as obj, mob/living/carbon/human/user as mob)
	if (istype(O, /obj/item/weapon/researchkit))

		if (user.original_job_title == "Nomad" && map.civilizations && map.ID != MAP_TRIBES)
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
		if (!map.civilizations || map.ID == MAP_TRIBES)
			return
		else if(!completed)
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
