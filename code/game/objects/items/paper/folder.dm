/obj/item/weapon/folder
	name = "folder"
	desc = "A folder."
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "folder"
	w_class = ITEM_SIZE_SMALL
	flags = FALSE

/obj/item/weapon/folder/blue
	desc = "A blue folder."
	icon_state = "folder_blue"

/obj/item/weapon/folder/red
	desc = "A red folder."
	icon_state = "folder_red"

/obj/item/weapon/folder/yellow
	desc = "A yellow folder."
	icon_state = "folder_yellow"

/obj/item/weapon/folder/white
	desc = "A white folder."
	icon_state = "folder_white"

/obj/item/weapon/folder/black
	desc = "A black folder."
	icon_state = "folder_black"

/obj/item/weapon/folder/sred
	desc = "A black folder with a red bar."
	icon_state = "folder_sred"

/obj/item/weapon/folder/update_icon()
	if (GLOB.nanomanager)
		GLOB.nanomanager.update_uis(src)
	overlays.Cut()
	if (contents.len)
		overlays += "folder_paper"
	return

/obj/item/weapon/folder/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/paper) || istype(W, /obj/item/weapon/photo) || istype(W, /obj/item/weapon/paper_bundle))
		user.drop_item()
		W.loc = src
		to_chat(user, SPAN_NOTICE("You put [W] into \the [src]."))
		update_icon()
	else if (istype(W, /obj/item/weapon/pen))
		var/n_name = sanitizeSafe(player_input(usr, "What would you like to label the folder?", "Folder Labelling", null, "text", null, FALSE), MAX_NAME_LEN)
		if ((loc == usr && usr.stat == FALSE))
			name = "folder[(n_name ? text("- '[n_name]'") : null)]"
	return

/obj/item/weapon/folder/attack_self(mob/user as mob)
	ui_interact(user)
	add_fingerprint(user)

/obj/item/weapon/folder/ui_actions(ui_key)
	return list("read", "look", "browse", "rename", "remove")

/obj/item/weapon/folder/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = TRUE)
	var/list/items = list()
	for (var/obj/item/weapon/paper/P in src)
		items += list(paper_document_container_row(P, "read"))
	for (var/obj/item/weapon/photo/Ph in src)
		items += list(paper_document_container_row(Ph, "look", "Look"))
	for (var/obj/item/weapon/paper_bundle/Pb in src)
		items += list(paper_document_container_row(Pb, "browse", "Browse"))
	open_panel(user, name, 420, 420, list(panel_section("Contents", items = items, empty = "The folder is empty.")), ui = ui, force_open = force_open)

/obj/item/weapon/folder/Topic(href, href_list)
	..()
	if ((usr.stat || usr.restrained()))
		return

	if (loc == usr)

		if (href_list["remove"])
			var/obj/item/P = locate(href_list["remove"])
			if (P && (P.loc == src) && istype(P))
				P.loc = usr.loc
				usr.put_in_hands(P)

		else if (href_list["read"])
			var/obj/item/weapon/paper/P = locate(href_list["read"])
			if (P && (P.loc == src) && istype(P))
				P.show_document(usr, FALSE, "folder", src)
		else if (href_list["look"])
			var/obj/item/weapon/photo/P = locate(href_list["look"])
			if (P && (P.loc == src) && istype(P))
				P.show(usr)
		else if (href_list["browse"])
			var/obj/item/weapon/paper_bundle/P = locate(href_list["browse"])
			if (P && (P.loc == src) && istype(P))
				P.attack_self(usr)
				onclose(usr, "[P.name]")
		else if (href_list["rename"])
			var/obj/item/weapon/O = locate(href_list["rename"])

			if (O && (O.loc == src))
				if (istype(O, /obj/item/weapon/paper))
					var/obj/item/weapon/paper/to_rename = O
					to_rename.rename()

				else if (istype(O, /obj/item/weapon/photo))
					var/obj/item/weapon/photo/to_rename = O
					to_rename.rename()

				else if (istype(O, /obj/item/weapon/paper_bundle))
					var/obj/item/weapon/paper_bundle/to_rename = O
					to_rename.rename()

		//Update everything
		attack_self(usr)
		update_icon()
	return
