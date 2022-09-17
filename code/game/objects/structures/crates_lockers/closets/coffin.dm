/obj/structure/closet/coffin
	name = "coffin"
	desc = "It's a burial receptacle for the dearly departed."
	icon_state = "coffin"
	icon_closed = "coffin"
	icon_opened = "coffin_open"
	throwpass = TRUE
	health = 300

/obj/structure/closet/coffin/anchored
	anchored = TRUE

/obj/structure/closet/coffin/update_icon()
	if (!opened)
		icon_state = icon_closed
	else
		icon_state = icon_opened

/obj/structure/closet/coffin/generic
	icon_state = "coffin_blank"
	icon_closed = "coffin_blank"
/obj/structure/closet/coffin/generic/anchored
	anchored = TRUE

/obj/structure/closet/coffin/sarcophagus
	name = "bronze sarcophagus"
	desc = "It's a burial receptacle for egyptian royalty."
	icon_state = "bronze_sarcophagus_closed"
	icon_closed = "bronze_sarcophagus_closed"
	icon_opened = "sarcophagus_open"
	throwpass = TRUE
	health = 1100

/obj/structure/closet/coffin/sarcophagus/anchored
	anchored = TRUE

/obj/structure/closet/coffin/sarcophagus/gold
	name = "gold sarcophagus"
	desc = "It's a burial receptacle for egyptian royalty."
	icon_state = "gold_sarcophagus_closed"
	icon_closed = "gold_sarcophagus_closed"
	icon_opened = "sarcophagus_open"
	throwpass = TRUE
	health = 700

/obj/structure/closet/old_coffin
	name = "old coffin"
	desc = "It's a burial receptacle for some ancient bag of bones."
	icon_state = "sealed_coffin"
	icon_closed = "sealed_coffin"
	icon_opened = "sealed_coffin_open"
	throwpass = TRUE
	health = 300

/obj/structure/closet/old_coffin/attack_hand(mob/user as mob)
	add_fingerprint(user)
	if (!opened)
		user << "<span class='notice'>\The [src] is a big heavy stone... you're not gonna move this by hand</span>"
		return
	else
		toggle(user)

/obj/structure/closet/old_coffin/attackby(obj/item/weapon/W as obj, mob/user as mob)
	add_fingerprint(usr)
	if (opened)
		if (istype(W, /obj/item/weapon/grab))
			var/obj/item/weapon/grab/G = W
			MouseDrop_T(G.affecting, user)	  //act like they were dragged onto the closet
			return FALSE
		if (W.loc != user) // This should stop mounted modules ending up outside the module.
			return
		usr.drop_item()
		if (W)
			if (istype(src, /obj/structure/closet/crate/dumpster))
				var/content_size = FALSE
				for (var/obj/item/I in contents)
					content_size += ceil(I.w_class/2)
				if (content_size < storage_capacity)
					W.forceMove(src)
					user << "You throw \the [W] into \the [src]."
					update_icon()
					return
				else
					user << "<span class='warning'>\The [src] is too full!</span>"
					return
			else
				W.forceMove(loc)
	else
		if (istype(W, /obj/item/weapon/material/tes13) || istype(W, /obj/item/weapon/material/hatchet/battleaxe/tes13) || istype(W, /obj/item/weapon/material/sword/tes13))
			toggle(user)
	return
/obj/structure/closet/old_coffin/update_icon()
	if (!opened)
		icon_state = icon_closed
	else
		icon_state = icon_opened