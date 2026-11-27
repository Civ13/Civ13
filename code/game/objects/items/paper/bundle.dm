/obj/item/weapon/paper_bundle
	name = "paper bundle"
	gender = NEUTER
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "paper"
	item_state = "paper"
	throwforce = FALSE
	w_class = ITEM_SIZE_SMALL
	throw_range = 2
	throw_speed = TRUE
	layer = 4
	attack_verb = list("bapped")
	var/page = TRUE	// current page
	var/list/pages = list()  // Ordered list of pages as they are to be displayed. Can be different order than contents.
	flammable = TRUE
	flags = FALSE

/obj/item/weapon/paper_bundle/attackby(obj/item/weapon/W as obj, mob/user as mob)
	..()

	// adding sheets
	if (istype(W, /obj/item/weapon/paper))
		insert_sheet_at(user, pages.len+1, W)

	// burning
	else if (istype(W, /obj/item/weapon/flame))
		burnpaper(W, user)

	// merging bundles
	else if (istype(W, /obj/item/weapon/paper_bundle))
		user.drop_from_inventory(W)
		for (var/obj/O in W)
			O.loc = src
			O.add_fingerprint(usr)
			pages.Add(O)

		to_chat(user, "<span class='notice'>You add \the [W.name] to [(name == "paper bundle") ? "the paper bundle" : name].</span>")
		qdel(W)
	else
		if (istype(W, /obj/item/weapon/pen))
			show_browse(usr, "", "window=[name]") //Closes the dialog)
		if (pages.len)
			var/obj/P = pages[page]
			P.attackby(W, user)

	update_icon()
	attack_self(usr) //Update the browsed page.
	add_fingerprint(usr)
	return

/obj/item/weapon/paper_bundle/proc/insert_sheet_at(mob/user, var/index, obj/item/weapon/sheet)
	if (istype(sheet, /obj/item/weapon/paper))
		to_chat(user, "<span class='notice'>You add [(sheet.name == "paper") ? "the paper" : sheet.name] to [(name == "paper bundle") ? "the paper bundle" : name].</span>")

	user.drop_from_inventory(sheet)
	sheet.loc = src

	pages.Insert(index, sheet)

	if (index <= page)
		page++

/obj/item/weapon/paper_bundle/proc/burnpaper(obj/item/weapon/flame/P, mob/user)
	var/class = "warning"

	if (P.lit && !user.restrained())
		if (istype(P, /obj/item/weapon/flame/lighter/zippo))
			class = "rose>"

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
				to_chat(user, "<span class = 'red'>You must hold \the [P] steady to burn \the [src].</span>")

/obj/item/weapon/paper_bundle/examine(mob/user)
	if (..(user, TRUE))
		if (!farsight_can_read(user, src))
			return
		show_content(user)
	else
		to_chat(user, "<span class='notice'>It is too far away.</span>")
	return

/obj/item/weapon/paper_bundle/proc/show_content(mob/user as mob)
	var/dat
	var/obj/item/weapon/W
	if (page <= pages.len && pages[page])
		W = pages[page]
	else
		return

	var/mutation_controls = ""
	if (can_change_held_bundle(user))
		mutation_controls = "<A href='?src=\ref[src];remove=\ref[W]'>Remove [(istype(W, /obj/item/weapon/paper)) ? "paper" : "photo"]</A>"
		if (istype(user.get_active_hand(), /obj/item/weapon/paper))
			mutation_controls += " | <A href='?src=\ref[src];insert_before=\ref[W]'>Insert before</A>"
			mutation_controls += " | <A href='?src=\ref[src];insert_after=\ref[W]'>Insert after</A>"

	// first
	if (page == TRUE)
		dat+= "<DIV STYLE='float:left; text-align:left; width:33.33333%'><A href='?src=\ref[src];prev_page=1'>Front</A></DIV>"
		dat+= "<DIV STYLE='float:left; text-align:center; width:33.33333%'>[mutation_controls]</DIV>"
		dat+= "<DIV STYLE='float:left; text-align:right; width:33.33333%'><A href='?src=\ref[src];next_page=1'>Next Page</A></DIV><BR><HR>"
	// last
	else if (page == pages.len)
		dat+= "<DIV STYLE='float:left; text-align:left; width:33.33333%'><A href='?src=\ref[src];prev_page=1'>Previous Page</A></DIV>"
		dat+= "<DIV STYLE='float:left; text-align:center; width:33.33333%'>[mutation_controls]</DIV>"
		dat+= "<DIV STYLE='float;left; text-align:right; with:33.33333%'><A href='?src=\ref[src];next_page=1'>Back</A></DIV><BR><HR>"
	// middle pages
	else
		dat+= "<DIV STYLE='float:left; text-align:left; width:33.33333%'><A href='?src=\ref[src];prev_page=1'>Previous Page</A></DIV>"
		dat+= "<DIV STYLE='float:left; text-align:center; width:33.33333%'>[mutation_controls]</DIV>"
		dat+= "<DIV STYLE='float:left; text-align:right; width:33.33333%'><A href='?src=\ref[src];next_page=1'>Next Page</A></DIV><BR><HR>"

	if (istype(pages[page], /obj/item/weapon/paper))
		var/obj/item/weapon/paper/P = W
		var/paper_html = P.document_classic_html(user, FALSE, "bundle", src)
		if (isnull(paper_html))
			return
		dat += paper_html
		show_browse(user, dat, "window=[name]")

/obj/item/weapon/paper_bundle/attack_self(mob/user as mob)
	if (!farsight_can_read(user, src))
		return
	show_content(user)
	add_fingerprint(usr)
	update_icon()
	return

/obj/item/weapon/paper_bundle/proc/can_change_held_bundle(mob/living/human/user)
	return istype(user) && !QDELETED(user) && !QDELETED(src) && (user.client?.mob == user || agent_character_for(user)) && !user.stat && !user.restrained() && !user.incapacitated() && user.can_use_hands() && loc == user && user.item_is_in_hands(src) && !persistence_save_in_progress && !persistence_active_operation && !persistence_load_recovery_required

/obj/item/weapon/paper_bundle/proc/held_bundle_page()
	if (!isnum(page) || page < 1 || page > pages.len || page != round(page))
		return null
	var/obj/item/weapon/W = pages[page]
	return !QDELETED(W) && W.loc == src ? W : null

/obj/item/weapon/paper_bundle/proc/browser_insert_page(mob/living/human/user, obj/item/weapon/expected, after)
	if (!can_change_held_bundle(user) || !expected || held_bundle_page() != expected)
		return
	var/obj/item/weapon/paper/sheet = user.get_active_hand()
	if (!istype(sheet) || QDELETED(sheet) || (sheet in pages) || !user.transfer_held_item_to(sheet, src))
		return
	// Transfer verified before changing the page order.
	pages.Insert(page + (after ? 1 : 0), sheet)
	if (!after)
		page++
	paper_authoring_notify(sheet, "physical")
	to_chat(user, SPAN_NOTICE("You add [sheet] to [src]."))

/obj/item/weapon/paper_bundle/proc/release_browser_page(mob/living/human/user, obj/item/weapon/sheet, turf/site)
	user.put_in_hands(sheet) // A full hand falls back to the floor.
	if (sheet.loc != user && sheet.loc != site)
		return FALSE
	pages -= sheet
	return TRUE

/obj/item/weapon/paper_bundle/proc/browser_remove_page(mob/living/human/user, obj/item/weapon/expected)
	if (!can_change_held_bundle(user) || !expected || held_bundle_page() != expected)
		return
	var/turf/site = get_turf(user)
	if (!site)
		return
	if (!release_browser_page(user, expected, site))
		return
	page = max(1, min(page, pages.len))
	if (istype(expected, /obj/item/weapon/paper))
		paper_authoring_notify(expected, "physical")
	to_chat(user, SPAN_NOTICE("You remove [expected] from the bundle."))
	// Keep the historical one-page unclip, but never delete a refused move.
	if (pages.len == 1 && contents.len == 1)
		var/obj/item/weapon/remaining = held_bundle_page()
		if (remaining && release_browser_page(user, remaining, site))
			if (istype(remaining, /obj/item/weapon/paper))
				paper_authoring_notify(remaining, "physical")
	if (!contents.len && user.transfer_held_item_to(src, site))
		qdel(src)
	else if (pages.len)
		update_icon()

/obj/item/weapon/paper_bundle/Topic(href, href_list)
	..()
	var/mob/user = usr
	if (!user)
		return
	if (src in user.contents)
		user.set_using_object(src)
		if (href_list["remove"])
			browser_remove_page(user, locate(href_list["remove"]))
		else if (href_list["insert_before"])
			browser_insert_page(user, locate(href_list["insert_before"]), FALSE)
		else if (href_list["insert_after"])
			browser_insert_page(user, locate(href_list["insert_after"]), TRUE)
		else if (href_list["next_page"])
			if (page != pages.len)
				page++
				playsound(loc, "pageturn", 50, TRUE)
		else if (href_list["prev_page"])
			if (page > 1)
				page--
				playsound(loc, "pageturn", 50, TRUE)
	else
		to_chat(user, "<span class='notice'>You need to hold it in hands!</span>")
	if (!QDELETED(src) && (istype(loc, /mob) || istype(loc?.loc, /mob)))
		attack_self(user)
		updateUsrDialog()

/obj/item/weapon/paper_bundle/verb/rename()
	set name = "Rename bundle"
	set category = null
	set src in usr

	var/n_name = sanitizeSafe(player_input(usr, "What would you like to label the bundle?", "Bundle Labelling", null, "text", null, FALSE), MAX_NAME_LEN)
	if ((loc == usr || loc.loc && loc.loc == usr) && usr.stat == FALSE)
		name = "[(n_name ? text("[n_name]") : "paper")]"
	add_fingerprint(usr)
	return


/obj/item/weapon/paper_bundle/verb/remove_all()
	set name = "Loose bundle"
	set category = null
	set src in usr

	var/mob/living/human/user = usr
	if (!can_change_held_bundle(user))
		return
	var/turf/site = get_turf(user)
	if (!site)
		return
	for (var/obj/O in contents.Copy())
		if (QDELETED(O) || O.loc != src || !O.forceMove(site) || O.loc != site)
			break
		pages -= O
		O.layer = initial(O.layer)
		O.add_fingerprint(user)
		if (istype(O, /obj/item/weapon/paper))
			paper_authoring_notify(O, "physical")
	if (contents.len)
		page = max(1, min(page, pages.len))
		update_icon()
		to_chat(user, SPAN_NOTICE("Some pages could not be moved and stay clipped."))
	else if (user.transfer_held_item_to(src, site))
		to_chat(user, SPAN_NOTICE("You loosen the bundle."))
		qdel(src)

/obj/item/weapon/paper_bundle/update_icon()
	if (pages[1])
		var/obj/item/weapon/paper/P = pages[1]
		icon_state = P.icon_state
		overlays = P.overlays
		underlays = FALSE
		var/i = FALSE
		for (var/obj/O in src)
			var/image/img = image('icons/obj/bureaucracy.dmi')
			if (istype(O, /obj/item/weapon/paper))
				img.icon_state = O.icon_state
				img.pixel_x -= min(1*i, 2)
				img.pixel_y -= min(1*i, 2)
				pixel_x = min(0.5*i, TRUE)
				pixel_y = min(  TRUE*i, 2)
				underlays += img
				i++
		if (i>1)
			desc =  "[i] papers clipped to each other."
		else
			desc = "A single sheet of paper."
		overlays += image('icons/obj/bureaucracy.dmi', "clip")
		return
