/obj/item/weapon/book/research
	name = "blank scroll"
	icon_state = "scroll0"
	title = "Blank scroll"
	desc = "A blank parchement scroll."
	var/completed = 0
	var/k_class = "none"
	var/k_level = 0

/obj/item/weapon/book/research/attack_self(var/mob/living/carbon/human/user as mob)
	if (completed == 0)
		var/list/display = list("Cancel")
		if (map.ordinal_age < 3)
			display = list("Cancel", "Industry", "Anatomy", "Fencing", "Archery", "Medicine")
		else
			display = list("Cancel", "Industry", "Anatomy", "Fencing", "Archery", "Gunpowder", "Medicine")
		var/choice = WWinput(user, "Which subject do you wish to write about?", "Scientific scroll production", "Cancel", display)
		if (choice == "Cancel")
			return
		if (choice == "Industry")
			user << "<span class='notice'>You begin to transpose your knowledge to the scroll.</span>"
			if (do_after(user, (300*(user.getStatCoeff("crafting")/100)), src))
				user << "<span class='notice'>You finish the scroll.</span>"
				k_class = "industry"
				k_level = (user.getStatCoeff("crafting")/100)
				completed = TRUE
				icon_state = "scroll1"
				name = pick("Woodcutting Basics, by [user]", "Mining and Industrialization, by [user]", "Furniture: How to Complete a Home, by [user]", "Building and Construction Basics, by [user]")
				desc = "A scientific scroll, with knowledge in crafting."
				author = "[user]"
				update_icon()
				return

		if (choice == "Anatomy")
			user << "<span class='notice'>You begin to transpose your knowledge to the scroll.</span>"
			if (do_after(user, (300*((user.getStatCoeff("dexterity")+user.getStatCoeff("strength"))/200)), src))
				user << "<span class='notice'>You finish the scroll.</span>"
				k_class = "anatomy"
				k_level = ((user.getStatCoeff("dexterity")+user.getStatCoeff("strength"))/200)
				completed = TRUE
				icon_state = "scroll1"
				name = pick("Human Body Limits, by [user]", "Increasing Muscular Mass, by [user]", "Complete Guide to Human Anatomy, by [user]", "Athletics Guide, by [user]")
				desc = "A scientific scroll, with knowledge in strength and dexterity."
				author = "[user]"
				update_icon()
				return

		if (choice == "Fencing")
			user << "<span class='notice'>You begin to transpose your knowledge to the scroll.</span>"
			if (do_after(user, (300*(user.getStatCoeff("swords")/100)), src))
				user << "<span class='notice'>You finish the scroll.</span>"
				k_class = "fencing"
				k_level = (user.getStatCoeff("swords")/100)
				completed = TRUE
				icon_state = "scroll1"
				name = pick("Swords & Swordfighting, by [user]", "Fencing: The Human Art, by [user]", "Introduction to Swordfighting, by [user]", "From Spears to Pikes, by [user]")
				desc = "A scientific scroll, with knowledge in swords."
				author = "[user]"
				update_icon()
				return

		if (choice == "Archery")
			user << "<span class='notice'>You begin to transpose your knowledge to the scroll.</span>"
			if (do_after(user, (300*(user.getStatCoeff("bows")/100)), src))
				user << "<span class='notice'>You finish the scroll.</span>"
				k_class = "archery"
				k_level = (user.getStatCoeff("bows")/100)
				completed = TRUE
				icon_state = "scroll1"
				name = pick("Bows & Longbows, by [user]", "On Archery Phisics, by [user]", "Archery and Accuracy, by [user]", "The Archer's Guide, by [user]")
				desc = "A scientific scroll, with knowledge in archery."
				author = "[user]"
				update_icon()
				return

		if (choice == "Gunpowder")
			user << "<span class='notice'>You begin to transpose your knowledge to the scroll.</span>"
			if (do_after(user, (300*((user.getStatCoeff("pistol")+user.getStatCoeff("rifle"))/200)), src))
				user << "<span class='notice'>You finish the scroll.</span>"
				k_class = "gunpowder"
				k_level = ((user.getStatCoeff("pistol")+user.getStatCoeff("rifle"))/200)
				completed = TRUE
				icon_state = "scroll1"
				name = pick("Muskets and Pistols: The Complete Guide, by [user]", "Gun Rifling, by [user]", "Cannons, Muskets & Blunderbusses, by [user]", "The Soldiers Companion, by [user]")
				desc = "A scientific scroll, with knowledge in gunpowder weapons."
				author = "[user]"
				update_icon()
				return

		if (choice == "M	edicine")
			user << "<span class='notice'>You begin to transpose your knowledge to the scroll.</span>"
			if (do_after(user, (300*(user.getStatCoeff("medical")/100)), src))
				user << "<span class='notice'>You finish the scroll.</span>"
				k_class = "medicine"
				k_level = (user.getStatCoeff("medical")/100)
				completed = TRUE
				icon_state = "scroll1"
				name = pick("Diseases of the Blood, by [user]", "Religion & Cures, by [user]", "Surgery Guide, by [user]", "Amputation: A Beginners Guide, by [user]")
				desc = "A scientific scroll, with knowledge in medicine."
				author = "[user]"
				update_icon()
				return
	else
		var/choice = input("This is a book by [author] on [k_class]. Do you want to study it?") in list("Yes", "No")
		if (choice == "No")
			return
		else if (choice == "Yes")
			user << "<span class='notice'>You begin reading the book attently...</span>"
			if (do_after(user, (600*k_level), src))
				user << "<span class='notice'>You finish studying the scroll. You feel smarter already.</span>"
				if (k_class == "industry")
					user.adaptStat("crafting", (10*k_level))
				if (k_class == "medicine")
					user.adaptStat("medical", (10*k_level))
				if (k_class == "archery")
					user.adaptStat("bows", (10*k_level))
				if (k_class == "fencing")
					user.adaptStat("swords", (10*k_level))
				if (k_class == "anatomy")
					user.adaptStat("strength", (5*k_level))
					user.adaptStat("dexterity", (5*k_level))
				if (k_class == "gunpowder")
					user.adaptStat("pistol", (5*k_level))
					user.adaptStat("rifle", (5*k_level))
				qdel(src)
				return