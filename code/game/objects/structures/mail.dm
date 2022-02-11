/////MAILBOXES/////

/obj/structure/closet/crate/wall_mailbox
	name = "wall mailbox"
	desc = "A mail box fastened on walls."
	icon = 'icons/obj/mail.dmi'
	icon_state = "wall_mailbox_closed"
	icon_closed = "wall_mailbox_closed"
	icon_opened = "wall_mailbox_open"
	density = FALSE
	anchored = TRUE
	store_mobs = FALSE
	storagecap = 5
	var/mailbox_color = null
	var/contents_stored = 0

/obj/structure/closet/crate/wall_mailbox/open()
	..()
	contents_stored = 0

	return TRUE

/obj/structure/closet/crate/wall_mailbox/close(mob/user as mob)
	if (!opened)
		return FALSE
	if (!can_close())
		return FALSE

	playsound(loc, 'sound/machines/click.ogg', 15, TRUE, -3)
	var/itemcount = FALSE
	for (var/obj/O in get_turf(src))
		if (itemcount >= storagecap)
			break
		if (O.density || O.anchored)
			continue
		if (istype(O, /obj/structure))
			continue
		if (!istype(O, /obj/item/weapon/paper) && !istype(O, /obj/item/weapon/photo) && !istype(O, /obj/item/weapon/storage/envelope))
			continue
		if (istype(O, /obj/item/weapon/storage/envelope))
			var/obj/item/weapon/storage/envelope/E = O
			if (E.opened == TRUE)
				continue
		O.forceMove(src)
		itemcount++
		contents_stored = itemcount

	icon_state = icon_closed
	opened = FALSE
	return TRUE

/obj/structure/closet/crate/wall_mailbox/toggle(mob/user as mob)
	..()
	if (!istype(src, /obj/structure/closet/crate/wall_mailbox/wood_mailbox))
		if (opened)
			var/image/mailbox_open_color_overlay = image("icon" = 'icons/obj/mail.dmi', "icon_state" = "wall_mailbox_open")
			mailbox_open_color_overlay.color = mailbox_color
			overlays += mailbox_open_color_overlay

		if (!opened)
			var/image/mailbox_color_overlay = image("icon" = 'icons/obj/mail.dmi', "icon_state" = "wall_mailbox_closed")
			mailbox_color_overlay.color = mailbox_color
			overlays += mailbox_color_overlay
			return

/obj/structure/closet/crate/wall_mailbox/attackby(var/obj/item/W as obj, mob/user as mob)
	if (!istype(W, /obj/item/weapon/storage/envelope) && !istype(W, /obj/item/weapon/paper) && !istype(W, /obj/item/weapon/key) && !istype(W, /obj/item/weapon/storage/belt/keychain) && !istype(W, /obj/item/weapon/photo) && !istype(W, /obj/item/weapon/hammer))
		user << "<span class='notice'>You can't put it in the mailbox!</span>"
		return

	if (istype(W, /obj/item/weapon/paper) || istype(W, /obj/item/weapon/photo) || istype(W, /obj/item/weapon/storage/envelope))
		if(!opened)
			if (contents_stored >= storagecap)
				user << "<span class='notice'>The mailbox is full!</span>"
				return
			else
				if (istype(W, /obj/item/weapon/storage/envelope))
					var/obj/item/weapon/storage/envelope/E = W
					if (E.opened == TRUE || E.knifed == TRUE)
						user << "<span class='notice'>You change your mind about sending an opened envelope - better use a closed one instead.</span>"
						return
				user.remove_from_mob(W)
				user << "<span class='notice'>You slip the [W.name] into the mailbox slot.</span>"
				W.forceMove(src)
				contents_stored++
				return

	if (istype(W, /obj/item/weapon/key))
		..()
		return

	if (istype(W, /obj/item/weapon/storage/belt/keychain) && custom_code != 0)
		..()
		return

	if (istype(W, /obj/item/weapon/hammer) && user.a_intent == I_HARM)
		..()
		return

/obj/structure/closet/crate/wall_mailbox/wood_mailbox
	name = "wood mailbox"
	desc = "A wood box with a slot to accept mail."
	icon = 'icons/obj/mail.dmi'
	icon_state = "wood_mailbox_closed"
	icon_closed = "wood_mailbox_closed"
	icon_opened = "wood_mailbox_open"
	density = TRUE

/////ENVELOPE/////

/obj/item/weapon/storage/envelope
	name = "envelope"
	icon = 'icons/obj/mail.dmi'
	icon_state = "envelope_empty"
	item_state = "envelope_empty"
	w_class = TRUE
	flammable = TRUE
	storage_slots = 3
	can_hold = list(/obj/item/weapon/paper,/obj/item/weapon/photo)
	var/opened = TRUE
	var/knifed = FALSE
	var/sealed = FALSE
	var/addressee = null
	var/sender = null
	flags = FALSE


/obj/item/weapon/storage/envelope/handle_item_insertion(obj/item/W as obj, prevent_warning = FALSE)
	..()

	if(knifed)
		icon_state = "envelope_knifed"
	else
		if(locate(/obj/item/weapon/paper) in contents)
			if(!locate(/obj/item/weapon/photo) in contents)
				icon_state = "envelope_letter"
			if(locate(/obj/item/weapon/photo) in contents)
				icon_state = "envelope_letter_photo"
		if(locate(/obj/item/weapon/photo) in contents)
			if(!locate(/obj/item/weapon/paper) in contents)
				icon_state = "envelope_photo"
			if(locate(/obj/item/weapon/paper) in contents)
				icon_state = "envelope_letter_photo"
	return TRUE

/obj/item/weapon/storage/envelope/remove_from_storage(obj/item/W as obj, prevent_warning = FALSE)
	..()

	if(knifed)
		icon_state = "envelope_knifed"
	else
		if(locate(/obj/item/weapon/paper) in contents)
			if(!locate(/obj/item/weapon/photo) in contents)
				icon_state = "envelope_letter"
			if(locate(/obj/item/weapon/photo) in contents)
				icon_state = "envelope_letter_photo"
		if(locate(/obj/item/weapon/photo) in contents)
			if(!locate(/obj/item/weapon/paper) in contents)
				icon_state = "envelope_photo"
			if(locate(/obj/item/weapon/paper) in contents)
				icon_state = "envelope_letter_photo"
		if(!locate(/obj/item/weapon/paper) in contents)
			if(!locate(/obj/item/weapon/photo) in contents)
				icon_state = "envelope_empty"
		if(!locate(/obj/item/weapon/photo) in contents)
			if(!locate(/obj/item/weapon/paper) in contents)
				icon_state = "envelope_empty"
	return TRUE

/obj/item/weapon/storage/envelope/attack_self(mob/user as mob)
	if(opened && !knifed)
		if (do_after(user, 15, src))
			user << "You close the envelope."
			opened = FALSE
			icon_state = "envelope_closed"
			return

	if(!opened && user.a_intent == I_HARM)
		usr << "<span class='warning'>You start tearing up the envelope...</span>"
		playsound(loc,'sound/items/poster_ripped.ogg',100, TRUE)
		spawn(10)
			playsound(loc,'sound/items/poster_ripped.ogg',100, TRUE)
		if (do_after(user, 25, src))
			usr << "<span class='warning'>You tear the envelope into pieces!</span>"
			visible_message("[user] tears the envelope into pieces!")
			qdel(src)
			return

/obj/item/weapon/storage/envelope/attack_hand(mob/user as mob)
	if (ishuman(user) && !opened)
		var/mob/living/human/H = user
		if (H.l_store == src && !H.get_active_hand())	//Prevents opening if it's in a pocket.
			H.put_in_hands(src)
			H.l_store = null
			return
		if (H.r_store == src && !H.get_active_hand())
			H.put_in_hands(src)
			H.r_store = null
			return

	if (loc == user)
		if (opened)
			open(user)
		else
			usr << "<span class='warning'>The envelope is closed! Use a knife to open it.</span>"
			return
	else
		..()
		for (var/mob/M in range(1))
			if (M.s_active == src)
				close(M)
	add_fingerprint(user)
	return

/obj/item/weapon/storage/envelope/attackby(obj/item/W as obj, mob/user as mob)
	if(!opened)
		if(istype(W, /obj/item/weapon/material/kitchen/utensil/knife))
			if (do_after(usr, 15, src))
				usr << "You knife the envelope."
				opened = TRUE
				knifed = TRUE
				icon_state = "envelope_knifed"
				return

		if(istype(W, /obj/item/weapon/pen))
			if(addressee && sender)
				usr << "<span class='warning'>The addressee and sender fields are already filled!</span>"
				return
			else
				var/write_to = sanitize(input(user, "TO: Who is the addressee?", "Addressee", null)  as text, 128)
				addressee = write_to
				var/write_from = sanitize(input(user, "FROM: Who is the sender?", "Sender", null)  as text, 128)
				sender = write_from
				if (!addressee || !sender)
					desc = desc
					usr << "<span class='warning'>You need to fill both fields at the same time!</span>"
				else
					desc += "<br>= = = = =<br><u><b>TO:</b></u> [addressee]<br>- - - - -<br><u><b>FROM:</b></u> [sender]<br>= = = = ="
				return

		if(istype(W, /obj/item/weapon/stamp/mail))
			if(sealed)
				usr << "<span class='warning'>There is a wax seal already!</span>"
				return
			var/wax = WWinput(user, "What color should the wax seal be?","Wax seal","Normal",list("cancel", "red", "black", "blue", "green", "pink", "white"))
			if (wax == "cancel")
				return
			if (wax != "cancel")
				var/image/wax_seal = image("icon" = 'icons/obj/mail.dmi', "icon_state" = "wax_seal_[wax]")
				overlays += wax_seal
				desc += "<br>This envelope has been sealed with [wax] wax."
				sealed = TRUE
			var/add_name = WWinput(user, "Would you like the seal to bear your name?","Wax seal","Normal",list("yes", "no"))
			if (add_name == "no")
				return
			else
				desc += "<br>There is a name on the seal - <b>[usr.real_name]</b>."
			return
		usr << "<span class='warning'>The envelope is closed! Use a knife to open it.</span>"
		return
	..()
