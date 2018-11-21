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
		var/choice = WWinput(user, "Which subject do you wish to write about?", "Scientific [styleb] production", "Cancel", display)
		if (choice == "Cancel")
			return
		if (choice == "Industry")
			user << "<span class='notice'>You begin to transpose your knowledge to the [styleb].</span>"
			if (do_after(user, (300*(user.getStatCoeff("crafting"))), src))
				user << "<span class='notice'>You finish the [styleb].</span>"
				user.adaptStat("philosophy", 1)
				k_class = "industry"
				k_level = (user.getStatCoeff("crafting"))
				completed = TRUE
				if (name == "blank slate")
					icon_state = "research_rock1"
				else
					icon_state = "[styleb]1"
				name = pick("Woodcutting Basics, by [user]", "Mining and Industrialization, by [user]", "Furniture: How to Complete a Home, by [user]", "Building and Construction Basics, by [user]")
				desc = "A scientific [styleb], with knowledge in crafting."
				author = "[user]"
				update_icon()
				return

		if (choice == "Anatomy")
			user << "<span class='notice'>You begin to transpose your knowledge to the [styleb].</span>"
			if (do_after(user, (300*((user.getStatCoeff("dexterity")+user.getStatCoeff("strength")))), src))
				user << "<span class='notice'>You finish the [styleb].</span>"
				user.adaptStat("philosophy", 1)
				k_class = "anatomy"
				k_level = ((user.getStatCoeff("dexterity")+user.getStatCoeff("strength")))
				completed = TRUE
				icon_state = "[styleb]1"
				name = pick("Human Body Limits, by [user]", "Increasing Muscular Mass, by [user]", "Complete Guide to Human Anatomy, by [user]", "Athletics Guide, by [user]")
				desc = "A scientific [styleb], with knowledge in strength and dexterity."
				author = "[user]"
				update_icon()
				return

		if (choice == "Fencing")
			user << "<span class='notice'>You begin to transpose your knowledge to the [styleb].</span>"
			if (do_after(user, (300*(user.getStatCoeff("swords"))), src))
				user << "<span class='notice'>You finish the [styleb].</span>"
				user.adaptStat("philosophy", 1)
				k_class = "fencing"
				k_level = (user.getStatCoeff("swords"))
				completed = TRUE
				icon_state = "[styleb]1"
				name = pick("Swords & Swordfighting, by [user]", "Fencing: The Human Art, by [user]", "Introduction to Swordfighting, by [user]", "From Spears to Pikes, by [user]")
				desc = "A scientific [styleb], with knowledge in swords."
				author = "[user]"
				update_icon()
				return

		if (choice == "Archery")
			user << "<span class='notice'>You begin to transpose your knowledge to the [styleb].</span>"
			if (do_after(user, (300*(user.getStatCoeff("bows"))), src))
				user << "<span class='notice'>You finish the [styleb].</span>"
				user.adaptStat("philosophy", 1)
				k_class = "archery"
				k_level = (user.getStatCoeff("bows"))
				completed = TRUE
				icon_state = "[styleb]1"
				name = pick("Bows & Longbows, by [user]", "On Archery Physics, by [user]", "Archery and Accuracy, by [user]", "The Archer's Guide, by [user]")
				desc = "A scientific [styleb], with knowledge in archery."
				author = "[user]"
				update_icon()
				return

		if (choice == "Gunpowder")
			user << "<span class='notice'>You begin to transpose your knowledge to the [styleb].</span>"
			if (do_after(user, (300*((user.getStatCoeff("pistol")+user.getStatCoeff("rifle")))), src))
				user << "<span class='notice'>You finish the [styleb].</span>"
				user.adaptStat("philosophy", 1)
				k_class = "gunpowder"
				k_level = ((user.getStatCoeff("pistol")+user.getStatCoeff("rifle")))
				completed = TRUE
				icon_state = "[styleb]1"
				name = pick("Muskets and Pistols: The Complete Guide, by [user]", "Gun Rifling, by [user]", "Cannons, Muskets & Blunderbusses, by [user]", "The Soldiers Companion, by [user]")
				desc = "A scientific [styleb], with knowledge in gunpowder weapons."
				author = "[user]"
				update_icon()
				return

		if (choice == "Medicine")
			user << "<span class='notice'>You begin to transpose your knowledge to the [styleb].</span>"
			if (do_after(user, (300*(user.getStatCoeff("medical"))), src))
				user << "<span class='notice'>You finish the [styleb].</span>"
				user.adaptStat("philosophy", 1)
				k_class = "medicine"
				k_level = (user.getStatCoeff("medical"))
				completed = TRUE
				icon_state = "[styleb]1"
				name = pick("Diseases of the Blood, by [user]", "Religion & Cures, by [user]", "Surgery Guide, by [user]", "Amputation: A Beginners Guide, by [user]")
				desc = "A scientific [styleb], with knowledge in medicine."
				author = "[user]"
				update_icon()
				return

		if (choice == "Philosophy")
			user << "<span class='notice'>You begin to transpose your knowledge to the [styleb].</span>"
			if (do_after(user, (300*(user.getStatCoeff("philosophy"))), src))
				user << "<span class='notice'>You finish the [styleb].</span>"
				user.adaptStat("philosophy", 1)
				k_class = "philosophy"
				k_level = (user.getStatCoeff("philosophy"))
				completed = TRUE
				icon_state = "[styleb]1"
				name = pick("Discourse Rethoric, by [user]", "Metaphysics of Religion, by [user]", "Politics, by [user]", "Human Ethics, by [user]")
				desc = "A scientific [styleb], with knowledge in philosophy."
				author = "[user]"
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
				user << "<span class='notice'>You begin reading the [styleb] attently...</span>"
				if (do_after(user, (600*k_level), src))
					user << "<span class='notice'>You finish studying the [styleb]. You feel smarter already.</span>"
					if (k_class == "industry")
						user.adaptStat("crafting", (16*k_level))
					if (k_class == "medicine")
						user.adaptStat("medical", (16*k_level))
					if (k_class == "archery")
						user.adaptStat("bows", (16*k_level))
					if (k_class == "fencing")
						user.adaptStat("swords", (16*k_level))
					if (k_class == "anatomy")
						user.adaptStat("strength", (8*k_level))
						user.adaptStat("dexterity", (8*k_level))
					if (k_class == "gunpowder")
						user.adaptStat("pistol", (8*k_level))
						user.adaptStat("rifle", (8*k_level))
					if (k_class == "philosophy")
						user.adaptStat("philosophy", (16*k_level))
					qdel(src)
					return


/obj/item/weapon/researchkit
	name = "research kit"
	icon_state = "scrolls1"
	icon = 'icons/obj/library.dmi'
	desc = "A set of instruments used to study ancient knowledge."
	weight = 1.0

/obj/item/weapon/researchkit/New()
	..()
	icon_state = "scrolls[map.ordinal_age]"

/obj/item/weapon/researchkit/update_icon()
	..()
	icon_state = "scrolls[map.ordinal_age]"


/obj/item/weapon/book/research/attackby(obj/O as obj, mob/living/carbon/human/user as mob)
	if (istype(O, /obj/item/weapon/researchkit))
		if (!map.civilizations)
			return
		else
			var/current_tribesmen = 0
			user << "Studying this document..."
			if (do_after(user,(300*k_level)/user.getStatCoeff("philosophy"),src))
				user << "You finish studying this document. The knowledge gained will be useful in the development of our society."
				user.adaptStat("philosophy", 1*k_level)
				if (user.civilization == civname_a)
					current_tribesmen = (alive_civilians.len/map.availablefactions.len)/2
					if (k_class == "medicine" || k_class == "anatomy")
						map.civa_research[3] += k_level/current_tribesmen
					if (k_class == "gunpowder" || k_class == "fencing" || k_class == "archery")
						map.civa_research[2] += k_level/current_tribesmen
					if (k_class == "industry" || k_class == "philosophy")
						map.civa_research[1] += k_level/current_tribesmen
				else if (user.civilization == civname_b)
					current_tribesmen = (alive_civilians.len/map.availablefactions.len)/2
					if (k_class == "medicine" || k_class == "anatomy")
						map.civb_research[3] += k_level/current_tribesmen
					if (k_class == "gunpowder" || k_class == "fencing" || k_class == "archery")
						map.civb_research[2] += k_level/current_tribesmen
					if (k_class == "industry" || k_class == "philosophy")
						map.civb_research[1] += k_level/current_tribesmen
				else if (user.civilization == civname_c)
					current_tribesmen = (alive_civilians.len/map.availablefactions.len)/2
					if (k_class == "medicine" || k_class == "anatomy")
						map.civc_research[3] += k_level/current_tribesmen
					if (k_class == "gunpowder" || k_class == "fencing" || k_class == "archery")
						map.civc_research[2] += k_level/current_tribesmen
					if (k_class == "industry" || k_class == "philosophy")
						map.civc_research[1] += k_level/current_tribesmen
				else if (user.civilization == civname_d)
					current_tribesmen = (alive_civilians.len/map.availablefactions.len)/2
					if (k_class == "medicine" || k_class == "anatomy")
						map.civd_research[3] += k_level/current_tribesmen
					if (k_class == "gunpowder" || k_class == "fencing" || k_class == "archery")
						map.civd_research[2] += k_level/current_tribesmen
					if (k_class == "industry" || k_class == "philosophy")
						map.civd_research[1] += k_level/current_tribesmen
				else if (user.civilization == civname_e)
					current_tribesmen = (alive_civilians.len/map.availablefactions.len)/2
					if (k_class == "medicine" || k_class == "anatomy")
						map.cive_research[3] += k_level/current_tribesmen
					if (k_class == "gunpowder" || k_class == "fencing" || k_class == "archery")
						map.cive_research[2] += k_level/current_tribesmen
					if (k_class == "industry" || k_class == "philosophy")
						map.cive_research[1] += k_level/current_tribesmen
				else if (user.civilization == civname_f)
					current_tribesmen = (alive_civilians.len/map.availablefactions.len)/2
					if (k_class == "medicine" || k_class == "anatomy")
						map.civf_research[3] += k_level/current_tribesmen
					if (k_class == "gunpowder" || k_class == "fencing" || k_class == "archery")
						map.civf_research[2] += k_level/current_tribesmen
					if (k_class == "industry" || k_class == "philosophy")
						map.civf_research[1] += k_level/current_tribesmen
	else
		..()
