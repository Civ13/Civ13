/obj/item/weapon/clipboard
	name = "clipboard"
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "clipboard"
	item_state = "clipboard"
	throwforce = FALSE
	w_class = ITEM_SIZE_SMALL
	throw_speed = 3
	throw_range = 10
	var/obj/item/weapon/pen/haspen		//The stored pen.
	var/obj/item/weapon/toppaper	//The topmost piece of paper.
	slot_flags = SLOT_BELT

/obj/item/weapon/clipboard/New()
	update_icon()

/obj/item/weapon/clipboard/MouseDrop(obj/over_object as obj) //Quick clipboard fix. -Agouri
	if (ishuman(usr))
		var/mob/M = usr
		if (!(istype(over_object, /obj/screen) ))
			return ..()

		if (!M.restrained() && !M.stat && istype(over_object, /obj/screen/inventory/hand))
			var/obj/screen/inventory/hand/H = over_object
			switch(H.slot_id)
				if (slot_r_hand)
					M.u_equip(src)
					M.put_in_r_hand(src)
				if (slot_l_hand)
					M.u_equip(src)
					M.put_in_l_hand(src)
/*			switch(over_object.name)
				if ("r_hand")
					M.u_equip(src)
					M.put_in_r_hand(src)
				if ("l_hand")
					M.u_equip(src)
					M.put_in_l_hand(src)*/



			add_fingerprint(usr)
			return

/obj/item/weapon/clipboard/proc/contained_top_paper()
	if (istype(toppaper, /obj/item/weapon/paper) && !QDELETED(toppaper) && toppaper.loc == src)
		return toppaper
	// Older clipboards may have papers but no selection. Match the order of clipping new sheets.
	toppaper = null
	for (var/obj/item/weapon/paper/P in contents)
		if (!QDELETED(P) && P.loc == src)
			toppaper = P
	return toppaper

/obj/item/weapon/clipboard/update_icon()
	contained_top_paper()
	if (GLOB.nanomanager)
		GLOB.nanomanager.update_uis(src)
	overlays.Cut()
	if (toppaper)
		overlays += toppaper.icon_state
		overlays += toppaper.overlays
	if (haspen)
		overlays += "clipboard_pen"
	overlays += "clipboard_over"
	return

/obj/item/weapon/clipboard/attackby(obj/item/weapon/W as obj, mob/user as mob)

	if (istype(W, /obj/item/weapon/paper) || istype(W, /obj/item/weapon/photo))
		user.drop_item()
		W.loc = src
		if (istype(W, /obj/item/weapon/paper))
			toppaper = W
		to_chat(user, SPAN_NOTICE("You clip the [W] onto \the [src]."))
		update_icon()

	else if (istype(W, /obj/item/weapon/pen) || istype(W, /obj/item/weapon/stamp))
		var/obj/item/weapon/paper/P = contained_top_paper()
		if (P)
			P.attackby(W, user)
			update_icon()

	return

/obj/item/weapon/clipboard/attack_self(mob/user as mob)
	ui_interact(user)
	add_fingerprint(user)

/obj/item/weapon/clipboard/ui_actions(ui_key)
	return list("pen", "addpen", "write", "read", "look", "rename", "remove")

/obj/item/weapon/clipboard/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = TRUE)
	var/list/sections = list()
	sections += list(panel_section("Pen", rows = list(panel_row("Pen", haspen ? "Clipped on" : "None", haspen ? "good" : "muted",
		list(haspen ? panel_button("Remove Pen", "pen") : panel_button("Add Pen", "addpen"))))))

	var/obj/item/weapon/paper/top = contained_top_paper()
	if (top)
		var/obj/item/weapon/paper/P = top
		sections += list(panel_section("Top paper", items = list(panel_item(P.name, null, list(
			panel_button("Read", "read", "\ref[P]"), panel_button("Write", "write", "\ref[P]"),
			panel_button("Rename", "rename", "\ref[P]"), panel_button("Remove", "remove", "\ref[P]"))))))

	var/list/items = list()
	for (var/obj/item/weapon/paper/P in src)
		if (P==toppaper)
			continue
		items += list(paper_document_container_row(P, "read"))
	for (var/obj/item/weapon/photo/Ph in src)
		items += list(paper_document_container_row(Ph, "look", "Look"))
	if (items.len || !toppaper)
		sections += list(panel_section(toppaper ? "Underneath" : "Papers", items = items, empty = "The clipboard is empty."))
	open_panel(user, name, 460, 460, sections, ui = ui, force_open = force_open)

/obj/item/weapon/clipboard/Topic(href, href_list)
	..()
	if ((usr.stat || usr.restrained()))
		return

	if (loc == usr)

		if (href_list["pen"])
			if (istype(haspen) && (haspen.loc == src))
				haspen.loc = usr.loc
				usr.put_in_hands(haspen)
				haspen = null

		else if (href_list["addpen"])
			if (!haspen)
				var/obj/item/weapon/pen/W = usr.get_active_hand()
				if (istype(W, /obj/item/weapon/pen))
					usr.drop_item()
					W.loc = src
					haspen = W
					to_chat(usr, "<span class='notice'>You slot the pen into \the [src].</span>")

		else if (href_list["write"])
			var/obj/item/weapon/P = locate(href_list["write"])

			if (P && (P.loc == src) && istype(P, /obj/item/weapon/paper) && (P == contained_top_paper()) )

				var/obj/item/I = usr.get_active_hand()

				if (istype(I, /obj/item/weapon/pen))

					P.attackby(I, usr)

		else if (href_list["remove"])
			var/obj/item/P = locate(href_list["remove"])

			if (P && (P.loc == src) && (istype(P, /obj/item/weapon/paper) || istype(P, /obj/item/weapon/photo)) )

				P.loc = usr.loc
				usr.put_in_hands(P)

		else if (href_list["rename"])
			var/obj/item/weapon/O = locate(href_list["rename"])

			if (O && (O.loc == src))
				if (istype(O, /obj/item/weapon/paper))
					var/obj/item/weapon/paper/to_rename = O
					to_rename.rename()

				else if (istype(O, /obj/item/weapon/photo))
					var/obj/item/weapon/photo/to_rename = O
					to_rename.rename()

		else if (href_list["read"])
			var/obj/item/weapon/paper/P = locate(href_list["read"])

			if (P && (P.loc == src) && istype(P, /obj/item/weapon/paper) )
				P.show_document(usr, FALSE, "clipboard", src)
		else if (href_list["look"])
			var/obj/item/weapon/photo/P = locate(href_list["look"])
			if (P && (P.loc == src) && istype(P, /obj/item/weapon/photo) )
				P.show(usr)

		else if (href_list["top"]) // currently unused
			var/obj/item/P = locate(href_list["top"])
			if (P && (P.loc == src) && istype(P, /obj/item/weapon/paper) )
				toppaper = P
				to_chat(usr, "<span class='notice'>You move [P.name] to the top.</span>")

		//Update everything
		attack_self(usr)
		update_icon()
	return

/obj/item/weapon/clipboard/full
/obj/item/weapon/clipboard/full/New()
	..()
	for (var/i=1, i<= 20, i++)
		toppaper = new /obj/item/weapon/paper(src)
	update_icon()
