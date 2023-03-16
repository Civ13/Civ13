/obj/item/weapon/book
	name = "book"
	icon = 'icons/obj/library.dmi'
	icon_state ="book"
	throw_speed = TRUE
	throw_range = 5
	w_class = ITEM_SIZE_NORMAL		 //upped to three because books are, y'know, pretty big. (and you could hide them inside eachother recursively forever)
	attack_verb = list("bashed", "whacked")
	var/dat			 // Actual page content
	var/due_date = FALSE // Game time in TRUE/10th seconds
	var/author		 // Who wrote the thing, can be changed by pen or PC. It is not automatically assigned
	var/unique = FALSE   // FALSE - Normal book, TRUE - Should not be treated as normal book, unable to be copied, unable to be modified
	var/title		 // The real name of the book.
	var/obj/item/store	//What's in the book?
	flammable = TRUE
	var/const/deffont = "Verdana"
	var/const/signfont = "Times New Roman"
	flags = FALSE
/obj/item/weapon/book/attack_self(var/mob/user as mob)
	if (dat)
		user.examinate(src)
		return
	else
		user << "This book is completely blank!"

/obj/item/weapon/book/attackby(obj/item/weapon/W as obj, mob/living/human/user as mob)
	if (istype(W, /obj/item/weapon/book))
		var/obj/item/weapon/book/B = W
		if (!B.author && user.religious_clergy == "Monks")
			user << "You start copying [src]..."
			if (do_after(user, 200, src))
				user << "You finish copying [src]."
				if (istype(src, /obj/item/weapon/book) && !istype(src, /obj/item/weapon/book/holybook) && !istype(src, /obj/item/weapon/book/research))
					var/obj/item/weapon/book/NC = src
					var/obj/item/weapon/book/NB = new/obj/item/weapon/book(get_turf(user))
					NB.dat = NC.dat
					NB.due_date = NC.due_date
					NB.author = NC.author
					NB.unique = NC.unique
					NB.title = NC.title
					qdel(B)
				else if (istype(src, /obj/item/weapon/book/holybook))
					var/obj/item/weapon/book/holybook/NC = src
					var/obj/item/weapon/book/holybook/NB = new/obj/item/weapon/book/holybook(get_turf(user))
					NB.author = NC.author
					NB.title = NC.title
					NB.name = NC.name
					NB.desc = NC.desc
					NB.religion = NC.religion
					NB.religion_type = NC.religion_type
					qdel(B)
				else if (istype(src, /obj/item/weapon/book/research))
					var/obj/item/weapon/book/research/NC = src
					var/obj/item/weapon/book/research/NB = new/obj/item/weapon/book/research(get_turf(user))
					NB.author = NC.author
					NB.title = NC.title
					NB.name = NC.name
					NB.desc = NC.desc
					NB.completed = NC.completed = 0
					NB.k_class = NC.k_class = "none"
					NB.k_level = NC.k_level = 0
					NB.styleb = NC.styleb = "scroll"
					qdel(B)
	if (istype(W, /obj/item/weapon/pen))
		if (unique)
			user << "Looks like you can't modify it."
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
				var/content = sanitize(input("Write your book's contents:") as message|null, MAX_BOOK_MESSAGE_LEN)
				if (!content)
					usr << "The content is invalid."
					return
				else
					var/t = parsepencode(content, W, user)
					dat += t
			if ("Author")
				var/newauthor = sanitize(input(usr, "Write the author's name:"))
				if (!newauthor)
					usr << "The name is invalid."
					return
				else
					author = newauthor
			else
				return
	else
		..()

/obj/item/weapon/book/examine(mob/user)
	..()
	if (in_range(user, src) || isghost(user))
		show_content(usr)
	else
		user << "<span class='notice'>You have to go closer if you want to read it.</span>"
	return

/obj/item/weapon/book/proc/show_content(var/mob/user, var/forceshow=0)
	if (!(istype(user, /mob/living/human) || isghost(user) && !forceshow))
		user << browse("<HTML><HEAD><TITLE>[title]</TITLE></HEAD><BODY>[stars(dat)]</BODY></HTML>", "window=[name]")
		onclose(user, "[name]")
	else
		user << browse("<HTML><HEAD><TITLE>[title]</TITLE></HEAD><BODY>[dat]</BODY></HTML>", "window=[name]")
		onclose(user, "[name]")

/obj/item/weapon/book/verb/rename()
	set name = "Rename book"
	set category = null
	set src in usr
	playsound(src,'sound/effects/pen.ogg',40,1)

	var/n_name = sanitizeSafe(input(usr, "What would you like to label the book?", "Book Labelling", null)  as text, MAX_NAME_LEN)

	// We check loc one level up, so we can rename in clipboards and such. See also: /obj/item/weapon/photo/rename()
	if ((loc == usr || loc.loc && loc.loc == usr) && usr.stat == FALSE && n_name)
		name = n_name
		if (n_name != "paper")
			desc = "This is a paper titled '" + name + "'."

		add_fingerprint(usr)
	return


/obj/item/weapon/book/proc/get_signature(var/obj/item/weapon/pen/P, mob/user as mob)
	if (P && istype(P, /obj/item/weapon/pen))
		return P.get_signature(user)
	return (user && user.real_name) ? user.real_name : "Anonymous"

/obj/item/weapon/book/proc/parsepencode(var/t, var/obj/item/weapon/pen/P, mob/user as mob)

	t = replacetext(t, "\[center\]", "<center>")
	t = replacetext(t, "\[/center\]", "</center>")
	t = replacetext(t, "\[br\]", "<BR>")
	t = replacetext(t, "\[b\]", "<b>")
	t = replacetext(t, "\[/b\]", "</b>")
	t = replacetext(t, "\[i\]", "<I>")
	t = replacetext(t, "\[/i\]", "</I>")
	t = replacetext(t, "\[u\]", "<U>")
	t = replacetext(t, "\[/u\]", "</U>")
	t = replacetext(t, "\[time\]", "[stationtime2text()]")
	t = replacetext(t, "\[date\]", "[stationdate2text()]")
	t = replacetext(t, "\[large\]", "<font size=\"4\">")
	t = replacetext(t, "\[/large\]", "</font>")
	t = replacetext(t, "\[sign\]", "<font face=\"[signfont]\"><i>[get_signature(P, user)]</i></font>")

	t = replacetext(t, "\[h1\]", "<H1>")
	t = replacetext(t, "\[/h1\]", "</H1>")
	t = replacetext(t, "\[h2\]", "<H2>")
	t = replacetext(t, "\[/h2\]", "</H2>")
	t = replacetext(t, "\[h3\]", "<H3>")
	t = replacetext(t, "\[/h3\]", "</H3>")

	t = replacetext(t, "\[*\]", "<li>")
	t = replacetext(t, "\[hr\]", "<HR>")
	t = replacetext(t, "\[small\]", "<font size = \"1\">")
	t = replacetext(t, "\[/small\]", "</font>")
	t = replacetext(t, "\[list\]", "<ul>")
	t = replacetext(t, "\[/list\]", "</ul>")
	t = replacetext(t, "\[table\]", "<table border=1 cellspacing=0 cellpadding=3 style='border: TRUEpx solid black;'>")
	t = replacetext(t, "\[/table\]", "</td></tr></table>")
	t = replacetext(t, "\[grid\]", "<table>")
	t = replacetext(t, "\[/grid\]", "</td></tr></table>")
	t = replacetext(t, "\[row\]", "</td><tr>")
	t = replacetext(t, "\[cell\]", "<td>")

	t = "<font face=\"[deffont]\" color=[P ? P.colour : "black"]>[t]</font>"

	return t
