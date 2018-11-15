/obj/item/weapon/book/research
	name = "blank scroll"
	icon_state = "scroll0"
	title = "Blank Scroll"
	desc = "A blank parchement scroll."
	var/completed = 0
	var/k_class = "none"
	var/k_level = 0
	var/styleb = "scroll"
/obj/item/weapon/book/research/New()
	..()
	if (map.ordinal_age >= 3)
		name = "blank research book"
		icon_state = "research0"
		title = "Blank Book"
		desc = "A blank scientific book."
		styleb = "book"



/obj/item/weapon/book/research/attack_self(var/mob/living/carbon/human/user as mob)
	if (completed == 0)
		var/list/display = list("Cancel")
		if (map.ordinal_age < 3)
			display = list("Cancel", "Industry", "Anatomy", "Fencing", "Archery", "Medicine")
		else
			display = list("Cancel", "Industry", "Anatomy", "Fencing", "Archery", "Gunpowder", "Medicine")
		var/choice = WWinput(user, "Which subject do you wish to write about?", "Scientific [styleb] production", "Cancel", display)
		if (choice == "Cancel")
			return
		if (choice == "Industry")
			user << "<span class='notice'>You begin to transpose your knowledge to the [styleb].</span>"
			if (do_after(user, (300*(user.getStatCoeff("crafting"))), src))
				user << "<span class='notice'>You finish the [styleb].</span>"
				k_class = "industry"
				k_level = (user.getStatCoeff("crafting"))
				completed = TRUE
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
				k_class = "archery"
				k_level = (user.getStatCoeff("bows"))
				completed = TRUE
				icon_state = "[styleb]1"
				name = pick("Bows & Longbows, by [user]", "On Archery Phisics, by [user]", "Archery and Accuracy, by [user]", "The Archer's Guide, by [user]")
				desc = "A scientific [styleb], with knowledge in archery."
				author = "[user]"
				update_icon()
				return

		if (choice == "Gunpowder")
			user << "<span class='notice'>You begin to transpose your knowledge to the [styleb].</span>"
			if (do_after(user, (300*((user.getStatCoeff("pistol")+user.getStatCoeff("rifle")))), src))
				user << "<span class='notice'>You finish the [styleb].</span>"
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
				k_class = "medicine"
				k_level = (user.getStatCoeff("medical"))
				completed = TRUE
				icon_state = "[styleb]1"
				name = pick("Diseases of the Blood, by [user]", "Religion & Cures, by [user]", "Surgery Guide, by [user]", "Amputation: A Beginners Guide, by [user]")
				desc = "A scientific [styleb], with knowledge in medicine."
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
					qdel(src)
					return