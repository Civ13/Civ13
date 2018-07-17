/obj/item/weapon/book
	name = "book"
	icon = 'icons/obj/library.dmi'
	icon_state ="book"
	throw_speed = TRUE
	throw_range = 5
	w_class = 3		 //upped to three because books are, y'know, pretty big. (and you could hide them inside eachother recursively forever)
	attack_verb = list("bashed", "whacked")
	var/dat			 // Actual page content
	var/due_date = FALSE // Game time in TRUE/10th seconds
	var/author		 // Who wrote the thing, can be changed by pen or PC. It is not automatically assigned
	var/unique = FALSE   // FALSE - Normal book, TRUE - Should not be treated as normal book, unable to be copied, unable to be modified
	var/title		 // The real name of the book.
	var/carved = FALSE	 // Has the book been hollowed out for use as a secret storage item?
	var/obj/item/store	//What's in the book?

/obj/item/weapon/book/attack_self(var/mob/user as mob)
	if (carved)
		if (store)
			user << "<span class='notice'>[store] falls out of [title]!</span>"
			store.loc = get_turf(loc)
			store = null
			return
		else
			user << "<span class='notice'>The pages of [title] have been cut out!</span>"
			return
	if (dat)
		user << browse("<TT><I>Penned by [author].</I></TT> <BR>" + "[dat]", "window=book")
		user.visible_message("[user] opens a book titled \"[title]\" and begins reading intently.")
		onclose(user, "book")
	else
		user << "This book is completely blank!"

/obj/item/weapon/book/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (carved)
		if (!store)
			if (W.w_class < w_class)
				user.drop_item()
				W.loc = src
				store = W
				user << "<span class='notice'>You put [W] in [title].</span>"
				return
			else
				user << "<span class='notice'>[W] won't fit in [title].</span>"
				return
		else
			user << "<span class='notice'>There's already something in [title]!</span>"
			return
	if (istype(W, /obj/item/weapon/pen))
		if (unique)
			user << "These pages don't seem to take the ink well. Looks like you can't modify it."
			return
		var/choice = input("What would you like to change?") in list("Title", "Contents", "Author", "Cancel")
		switch(choice)
			if ("Title")
				var/newtitle = reject_bad_text(sanitizeSafe(input("Write a new title:")))
				if (!newtitle)
					usr << "The title is invalid."
					return
				else
					name = newtitle
					title = newtitle
			if ("Contents")
				var/content = sanitize(input("Write your book's contents (HTML NOT allowed):") as message|null, MAX_BOOK_MESSAGE_LEN)
				if (!content)
					usr << "The content is invalid."
					return
				else
					dat += content
			if ("Author")
				var/newauthor = sanitize(input(usr, "Write the author's name:"))
				if (!newauthor)
					usr << "The name is invalid."
					return
				else
					author = newauthor
			else
				return
	else if (istype(W, /obj/item/weapon/material/knife) || istype(W, /obj/item/weapon/wirecutters))
		if (carved)	return
		user << "<span class='notice'>You begin to carve out [title].</span>"
		if (do_after(user, 30, src))
			user << "<span class='notice'>You carve out the pages from [title]! You didn't want to read it anyway.</span>"
			carved = TRUE
			return
	else
		..()

/obj/item/weapon/book/attack(mob/living/carbon/M as mob, mob/living/carbon/user as mob)
	if (user.targeted_organ == "eyes")
		user.visible_message("<span class='notice'>You open up the book and show it to [M]. </span>", \
			"<span class='notice'> [user] opens up a book and shows it to [M]. </span>")
		M << browse("<TT><I>Penned by [author].</I></TT> <BR>" + "[dat]", "window=book")
		user.setClickCooldown(DEFAULT_QUICK_COOLDOWN) //to prevent spam