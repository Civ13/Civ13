/*
 * Paper
 * also scraps of paper
 */

/obj/item/weapon/paper
	name = "sheet of paper"
	gender = NEUTER
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "paper"
	item_state = "paper"
	var/base_icon = "paper"
	throwforce = FALSE
	w_class = ITEM_SIZE_TINY
	throw_range = TRUE
	throw_speed = TRUE
	layer = 4
	slot_flags = SLOT_HEAD
	body_parts_covered = HEAD
	attack_verb = list("bapped")
	flammable = TRUE
	flags = FALSE
	var/info		//What's actually written on the paper.
	var/info_links	//A different version of the paper which includes html links at fields and EOF
	var/stamps		//The (text for the) stamps on the paper.
	var/fields		//Amount of user created fields
	var/free_space = MAX_PAPER_MESSAGE_LEN
	var/list/stamped
	var/list/ico[0]	  //Icons and
	var/list/offset_x[0] //offsets stored for later
	var/list/offset_y[0] //usage by the photocopier
	var/rigged = FALSE
	var/spam_flag = FALSE

	var/const/deffont = "Verdana"
	var/const/signfont = "Times New Roman"
	var/const/crayonfont = "Comic Sans MS"

	map_storage_saved_vars = "density;icon_state;dir;name;pixel_x;pixel_y;info;info_links;stamped"
	safe_list_vars = "stamped"

/obj/item/weapon/paper/official
	base_icon = "official"
	name = "official paper"
	icon_state = "Decree_empty"
	var/faction = ""
	var/color1 = "#000000"
	var/color2 = "#FFFFFF"

/obj/item/weapon/paper/official/New()
	..()
	spawn(30)
		name = "official [faction] paper"

/obj/item/weapon/paper/official/update_icon()
	..()
	overlays.Cut()
	var/image/i1 = image(icon=src.icon, icon_state="Decree_Overlay_1")
	var/image/i2 = image(icon=src.icon, icon_state="Decree_Overlay_2")
	i1.color = color1
	i2.color = color2
	overlays += i1
	overlays += i2

//lipstick wiping is in code/game/objects/items/weapons/cosmetics.dm!

/obj/item/weapon/paper/New()
	..()
	pixel_y = rand(-8, 8)
	pixel_x = rand(-9, 9)
	stamps = ""

	if (name != "paper")
		desc = "This is a paper titled '" + name + "'."

	if (info != initial(info))
		info = html_encode(info)
		info = replacetext(info, "\n", "<BR>")
		info = parsepencode(info)

	spawn(2)
		update_icon()
		update_space(info)
		updateinfolinks()

	if (map && base_icon == "paper")
		if (map.ordinal_age <= 1)
			name = "papyrus"
			icon_state = "scrollpaper"
			desc = "A blank parchement scroll."
		else if (map.ordinal_age <= 3)
			name = "paper"
			icon_state = "Colonial_Paper_Empty"
			desc = "A blank paper sheet."

/obj/item/weapon/paper/verb/airplane()
	set name = "Make Paper Airplane"
	set category = null
	set src in usr
	src.icon_state = "paper_plane"
	src.throw_range = 14
	src.name = "airplane- \"[src.name]\""
	add_fingerprint(usr)

/obj/item/weapon/paper/update_icon()
	if (base_icon == "paper")
		if (map && map.ordinal_age <= 1)
			if (info)
				icon_state = "scrollpaper1"
			else
				icon_state = "scrollpaper0"
		else if (map && map.ordinal_age <= 3)
			if (info)
				icon_state = "Colonial_Paper"
			else
				icon_state = "Colonial_Paper_Empty"
		else
			if (icon_state == "paper_talisman")
				return
			if (info)
				icon_state = "paper_words"
				return
			icon_state = "paper"
	else if (base_icon == "official")
		if (info)
			icon_state = "Decree"
		else
			icon_state = "Decree_empty"

/obj/item/weapon/paper/proc/update_space(var/new_text)
	if (!new_text)
		return

	free_space -= length(strip_html_properly(new_text))

/obj/item/weapon/paper/examine(mob/user)
	..()
	if (in_range(user, src) || isghost(user))
		show_content(usr)
	else
		user << "<span class='notice'>You have to go closer if you want to read it.</span>"
	return

/obj/item/weapon/paper/proc/show_content(var/mob/user, var/forceshow=0)
	if (!(istype(user, /mob/living/human) || isghost(user) && !forceshow))
		user << browse("<HTML><HEAD><TITLE>[name]</TITLE></HEAD><BODY>[stars(info)][stamps]</BODY></HTML>", "window=[name]")
		onclose(user, "[name]")
	else
		user << browse("<HTML><HEAD><TITLE>[name]</TITLE></HEAD><BODY>[info][stamps]</BODY></HTML>", "window=[name]")
		onclose(user, "[name]")

/obj/item/weapon/paper/verb/rename()
	set name = "Rename paper"
	set category = null
	set src in usr
	playsound(src,'sound/effects/pen.ogg',40,1)

	var/n_name = sanitizeSafe(input(usr, "What would you like to label the paper?", "Paper Labelling", null)  as text, MAX_NAME_LEN)

	// We check loc one level up, so we can rename in clipboards and such. See also: /obj/item/weapon/photo/rename()
	if ((loc == usr || loc.loc && loc.loc == usr) && usr.stat == FALSE && n_name)
		name = n_name
		if (n_name != "paper")
			desc = "This is a paper titled '" + name + "'."

		add_fingerprint(usr)
	return

/obj/item/weapon/paper/attack_self(mob/living/user as mob)
	if (user.a_intent == I_HARM)
		if (icon_state == "scrap")
			user.show_message("<span class='warning'>\The [src] is already crumpled.</span>")
			return
		//crumple dat paper
		info = stars(info,85)
		user.visible_message("\The [user] crumples \the [src] into a ball!")
		if (map.ordinal_age <= 1)
			if (info)
				icon_state = "scrollpaper1_scrap"
			else
				icon_state = "scrollpaper0_scrap"
		else
			icon_state = "scrap"
		return
	user.examinate(src)
	return


/obj/item/weapon/paper/attack(mob/living/human/M as mob, mob/living/human/user as mob)
	if (user.targeted_organ == "eyes")
		user.visible_message("<span class='notice'>You show the paper to [M]. </span>", \
			"<span class='notice'> [user] holds up a paper and shows it to [M]. </span>")
		M.examinate(src)

	else if (user.targeted_organ == "mouth") // lipstick wiping
		if (ishuman(M))
			var/mob/living/human/H = M
			if (H == user)
				user << "<span class='notice'>You wipe off the lipstick with [src].</span>"
				H.lip_style = null
				H.update_body()
			else
				user.visible_message("<span class='warning'>[user] begins to wipe [H]'s lipstick off with \the [src].</span>", \
								 	 "<span class='notice'>You begin to wipe off [H]'s lipstick.</span>")
				if (do_after(user, 10, H) && do_after(H, 10, needhand = FALSE))	//user needs to keep their active hand, H does not.
					user.visible_message("<span class='notice'>[user] wipes [H]'s lipstick off with \the [src].</span>", \
										 "<span class='notice'>You wipe off [H]'s lipstick.</span>")
					H.lip_style = null
					H.update_body()

/obj/item/weapon/paper/proc/addtofield(var/id, var/text, var/links = FALSE)
	var/locid = FALSE
	var/laststart = TRUE
	var/textindex = TRUE
	while (1) // I know this can cause infinite loops and fuck up the whole server, but the if (istart==0) should be safe as fuck
		var/istart = FALSE
		if (links)
			istart = findtext(info_links, "<span class=\"paper_field\">", laststart)
		else
			istart = findtext(info, "<span class=\"paper_field\">", laststart)

		if (istart==0)
			return // No field found with matching id

		laststart = istart+1
		locid++
		if (locid == id)
			var/iend = TRUE
			if (links)
				iend = findtext(info_links, "</span>", istart)
			else
				iend = findtext(info, "</span>", istart)

			//textindex = istart+26
			textindex = iend
			break

	if (links)
		var/before = copytext(info_links, TRUE, textindex)
		var/after = copytext(info_links, textindex)
		info_links = before + text + after
	else
		var/before = copytext(info, TRUE, textindex)
		var/after = copytext(info, textindex)
		info = before + text + after
		updateinfolinks()

/obj/item/weapon/paper/proc/updateinfolinks()
	info_links = info
	var/i = FALSE
	for (i=1,i<=fields,i++)
		addtofield(i, "<font face=\"[deffont]\"><A href='?src=\ref[src];write=[i]'>write</A></font>", TRUE)
	info_links = info_links + "<font face=\"[deffont]\"><A href='?src=\ref[src];write=end'>write</A></font>"


/obj/item/weapon/paper/proc/clearpaper()
	info = null
	stamps = null
	free_space = MAX_PAPER_MESSAGE_LEN
	stamped = list()
	overlays.Cut()
	updateinfolinks()
	update_icon()

/obj/item/weapon/paper/proc/get_signature(var/obj/item/weapon/pen/P, mob/user as mob)
	if (P && istype(P, /obj/item/weapon/pen))
		return P.get_signature(user)
	return (user && user.real_name) ? user.real_name : "Anonymous"

/obj/item/weapon/paper/proc/parsepencode(var/t, var/obj/item/weapon/pen/P, mob/user as mob, var/iscrayon = FALSE)

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
	t = replacetext(t, "\[field\]", "<span class=\"paper_field\"></span>")

	t = replacetext(t, "\[h1\]", "<H1>")
	t = replacetext(t, "\[/h1\]", "</H1>")
	t = replacetext(t, "\[h2\]", "<H2>")
	t = replacetext(t, "\[/h2\]", "</H2>")
	t = replacetext(t, "\[h3\]", "<H3>")
	t = replacetext(t, "\[/h3\]", "</H3>")

	if (!iscrayon)
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
	else // If it is a crayon, and he still tries to use these, make them empty!
		t = replacetext(t, "\[*\]", "")
		t = replacetext(t, "\[hr\]", "")
		t = replacetext(t, "\[small\]", "")
		t = replacetext(t, "\[/small\]", "")
		t = replacetext(t, "\[list\]", "")
		t = replacetext(t, "\[/list\]", "")
		t = replacetext(t, "\[table\]", "")
		t = replacetext(t, "\[/table\]", "")
		t = replacetext(t, "\[row\]", "")
		t = replacetext(t, "\[cell\]", "")
		t = replacetext(t, "\[logo\]", "")

		t = "<font face=\"[crayonfont]\" color=[P ? P.colour : "black"]><b>[t]</b></font>"


//	t = replacetext(t, "#", "") // Junk converted to nothing!

//Count the fields
	var/laststart = TRUE
	while (1)
		var/i = findtext(t, "<span class=\"paper_field\">", laststart)	//</span>
		if (i==0)
			break
		laststart = i+1
		fields++

	return t

/obj/item/weapon/paper/proc/burnpaper(obj/item/weapon/flame/P, mob/user)
	var/class = "warning"

	if (P.lit && !user.restrained())
		if (istype(P, /obj/item/weapon/flame/lighter/zippo))
			class = "rose"

		user.visible_message("<span class='[class]'>[user] holds \the [P] up to \the [src], it looks like \he's trying to burn it!</span>", \
		"<span class='[class]'>You hold \the [P] up to \the [src], burning it slowly.</span>")

		spawn(20)
			if (get_dist(src, user) < 2 && user.get_active_hand() == P && P.lit)
				user.visible_message("<span class='[class]'>[user] burns right through \the [src], turning it to ash. It flutters through the air before settling on the floor in a heap.</span>", \
				"<span class='[class]'>You burn right through \the [src], turning it to ash. It flutters through the air before settling on the floor in a heap.</span>")

				if (user.get_inactive_hand() == src)
					user.drop_from_inventory(src)

				new /obj/effect/decal/cleanable/ash(loc)
				qdel(src)

			else
				user << "<span class = 'red'>You must hold \the [P] steady to burn \the [src].</span>"


/obj/item/weapon/paper/Topic(href, href_list)
	..()
	if (!usr || (usr.stat || usr.restrained()))
		return

	if (href_list["write"])
		var/id = href_list["write"]
		//var/t = strip_html_simple(input(usr, "What text do you wish to add to " + (id=="end" ? "the end of the paper" : "field "+id) + "?", "[name]", null),8192) as message

		if (free_space <= 0)
			usr << "<span class='info'>There isn't enough space left on \the [src] to write anything.</span>"
			return

		var/t =  sanitize(input("Enter what you want to write:", "Write", null, null) as message, free_space, extra = FALSE)

		if (!t)
			return

		var/obj/item/i = usr.get_active_hand() // Check to see if he still got that darn pen, also check if he's using a crayon or pen.
		var/iscrayon = FALSE
		if (!istype(i, /obj/item/weapon/pen))
			return

		if (istype(i, /obj/item/weapon/pen/crayon))
			iscrayon = TRUE


		// if paper is not in usr, then it must be near them, or in a clipboard or folder, which must be in or near usr
		if (loc != usr && !Adjacent(usr) && !((istype(loc, /obj/item/weapon/clipboard) || istype(loc, /obj/item/weapon/folder)) && (loc.loc == usr || loc.Adjacent(usr)) ) )
			return
/*
		t = checkhtml(t)

		// check for exploits
		for (var/bad in paper_blacklist)
			if (findtext(t,bad))
				usr << "<span class = 'notice'>You think to yourself, \"Hm.. this is only paper...\"</span>"
				log_admin("PAPER: [usr] ([usr.ckey]) tried to use forbidden word in [src]: [bad].")
				message_admins("PAPER: [usr] ([usr.ckey]) tried to use forbidden word in [src]: [bad].")
				return
*/

		var last_fields_value = fields

		//t = html_encode(t)
		t = replacetext(t, "\n", "<BR>")
		t = parsepencode(t, i, usr, iscrayon) // Encode everything from pencode to html


		if (fields > 50)//large amount of fields creates a heavy load on the server, see updateinfolinks() and addtofield()
			usr << "<span class='warning'>Too many fields. Sorry, you can't do this.</span>"
			fields = last_fields_value
			return

		if (id!="end")
			addtofield(text2num(id), t) // He wants to edit a field, let him.
		else
			info += t // Oh, he wants to edit to the end of the file, let him.
			updateinfolinks()
		playsound(src,'sound/effects/pen.ogg',40,1)
		update_space(t)

		usr << browse("<HTML><HEAD><TITLE>[name]</TITLE></HEAD><BODY>[info_links][stamps]</BODY></HTML>", "window=[name]") // Update the window

		update_icon()


/obj/item/weapon/paper/attackby(obj/item/weapon/P as obj, mob/user as mob)
	..()
	if (istype(P, /obj/item/weapon/paper))
		var/obj/item/weapon/paper_bundle/B = new(loc)
		if (name != "paper")
			B.name = name
		else if (P.name != "paper" && P.name != "photo")
			B.name = P.name
		user.drop_from_inventory(P)
		if (istype(user, /mob/living/human))
			var/mob/living/human/h_user = user
			if (h_user.r_hand == src)
				h_user.drop_from_inventory(src)
				h_user.put_in_r_hand(B)
			else if (h_user.l_hand == src)
				h_user.drop_from_inventory(src)
				h_user.put_in_l_hand(B)
			else if (h_user.l_store == src)
				h_user.drop_from_inventory(src)
				B.loc = h_user
				B.layer = 20
				h_user.l_store = B
				h_user.update_inv_pockets()
			else if (h_user.r_store == src)
				h_user.drop_from_inventory(src)
				B.loc = h_user
				B.layer = 20
				h_user.r_store = B
				h_user.update_inv_pockets()
			else if (h_user.head == src)
				h_user.u_equip(src)
				h_user.put_in_hands(B)
			else if (!istype(loc, /turf))
				loc = get_turf(h_user)
				if (h_user.client)	h_user.client.screen -= src
				h_user.put_in_hands(B)
		user << "<span class='notice'>You clip the [P.name] to [(name == "paper") ? "the paper" : name].</span>"
		loc = B
		P.loc = B

		B.pages.Add(src)
		B.pages.Add(P)
		B.update_icon()

	else if (istype(P, /obj/item/weapon/pen))
		if (icon_state == "scrap")
			usr << "<span class='warning'>\The [src] is too crumpled to write on.</span>"
			return
/*
		var/obj/item/weapon/pen/robopen/RP = P
		if ( istype(RP) && RP.mode == 2 )
			RP.RenamePaper(user,src)
		else*/
		user << browse("<HTML><HEAD><TITLE>[name]</TITLE></HEAD><BODY>[info_links][stamps]</BODY></HTML>", "window=[name]")
		return

	else if ((istype(P, /obj/item/weapon/stamp) && !( istype(P, /obj/item/weapon/stamp/mail))))
		if ((!in_range(src, usr) && loc != user && !( istype(loc, /obj/item/weapon/clipboard) ) && loc.loc != user && user.get_active_hand() != P))
			return
		playsound(src,'sound/effects/Stamp.ogg',40,1)
		var/image/stampoverlay = image('icons/obj/bureaucracy.dmi')
		stampoverlay.pixel_x = rand(-2, 2)
		stampoverlay.pixel_y = rand(-3, 2)
		stampoverlay.icon_state = "paper_[P.icon_state]"
		var/image/stampoverlay_paper = image('icons/obj/bureaucracy_large.dmi')
		stampoverlay.icon_state = P.icon_state
		stamps += "<img src='\ref[stampoverlay_paper.icon]'>"
		if(!stamped)
			stamped = new
		stamped += P.type
		overlays += stampoverlay

		user << "<span class='notice'>You stamp the paper with the [P.name].</span>"

	else if (istype(P, /obj/item/weapon/flame))
		burnpaper(P, user)

	add_fingerprint(user)
	return

/*
 * Premade paper
 */
/obj/item/weapon/paper/Court/british
	name = "Crown Court Judgement"
	info = "For crimes against the crown, the offender is sentenced to:<BR>\n<BR>\n"

/obj/item/weapon/paper/Court/pirates
	name = "Ship udgement"
	info = "For crimes against the crew, the offender is sentenced to:<BR>\n<BR>\n"

/obj/item/weapon/paper/crumpled
	name = "paper scrap"
	icon_state = "scrap"

/obj/item/weapon/paper/crumpled/update_icon()
	return

/obj/item/weapon/paper/crumpled/bloody
	icon_state = "scrap_bloodied"