/obj/item/clothing/accessory/storage/sheath
	name = "sword sheath"
	desc = "A sheath for a shorter length sword."
	icon_state = "short_sheath"
	item_state = "short_sheath"
	slots = 1
	slot = "utility"
	ripable = FALSE
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/material/sword/smallsword,
		/obj/item/weapon/material/sword/gladius,
		/obj/item/weapon/material/sword/xiphos)

/obj/item/clothing/accessory/storage/sheath/on_attached(obj/item/clothing/under/S, mob/user as mob)
	..()
	has_suit.verbs += /obj/item/clothing/accessory/storage/sheath/verb/sheathe_verb

/obj/item/clothing/accessory/storage/sheath/on_removed(mob/user as mob)
	has_suit.verbs -= /obj/item/clothing/accessory/storage/sheath/verb/sheathe_verb
	..()

/obj/item/clothing/accessory/storage/sheath/verb/sheathe_verb()
	set name = "Holster"
	set category = null
	set src in usr
	if (!istype(usr, /mob/living)) return
	if (usr.stat) return

	//can't we just use src here?
	var/obj/item/clothing/accessory/storage/sheath/H = null
	if (istype(src, /obj/item/clothing/accessory/storage/sheath))
		H = src
	else if (istype(src, /obj/item/clothing/under))
		var/obj/item/clothing/under/S = src
		if (S.accessories.len)
			H = locate() in S.accessories

	if (!H)
		usr << "<span class='warning'>Something is very wrong.</span>"
	var/obj/item/weapon/material/sword/currsword = null
	for(var/obj/item/weapon/material/sword/W in H.hold)
		currsword = W
	if (!currsword)
		var/obj/item/W = usr.get_active_hand()
		if (!istype(W, /obj/item/weapon/material/sword))
			usr << "<span class='warning'>You need a sword in your hand to sheathe it.</span>"
			return FALSE
		attackby(W, usr)
		visible_message("[usr] sheathes \the [W].")
		playsound(usr, 'sound/items/unholster_sword01.ogg', 50, 1)
		return TRUE
	else
		if (istype(usr.get_active_hand(),/obj) && istype(usr.get_inactive_hand(),/obj))
			usr << "<span class='warning'>You need an empty hand to draw \the [currsword]!</span>"
			return FALSE
		else
			usr.put_in_hands(currsword)
			visible_message("<span class='danger'>[usr] draws \the [currsword]!</span>")
			playsound(usr, 'sound/items/unholster_sword02.ogg', 80, 1)
			return TRUE

/obj/item/clothing/accessory/storage/sheath/longsword
	name = "longsword sheath"
	desc = "A sheath for a longsword."
	icon_state = "longsword_sheath"
	item_state = "longsword_sheath"
	slots = 1
	slot = "utility"
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/material/sword/longsword)

/obj/item/clothing/accessory/storage/sheath/katana
	name = "katana sheath"
	desc = "A sheath for a katana."
	icon_state = "katana_sheath"
	item_state = "katana_sheath"
	slots = 1
	slot = "utility"
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/material/sword/katana,
		/obj/item/weapon/material/sword/wakazashi)

/obj/item/clothing/accessory/storage/sheath/daisho
	name = "daisho sheath"
	desc = "A sheath for a daisho."
	icon_state = "daisho_sheath"
	item_state = "daisho_sheath"
	slots = 2
	slot = "utility"
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/material/sword/katana,
		/obj/item/weapon/material/sword/wakazashi)

/obj/item/clothing/accessory/storage/sheath/longer
	name = "longer sword sheath"
	desc = "A sheath for a longer length sword."
	icon_state = "longer_sheath"
	item_state = "longer_sheath"
	slots = 1
	slot = "utility"
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/material/sword/spadroon,
		/obj/item/weapon/material/sword/cutlass,
		/obj/item/weapon/material/sword/scimitar,
		/obj/item/weapon/material/sword/saif,
		/obj/item/weapon/material/sword/sabre,
		/obj/item/weapon/material/sword/rapier,
		/obj/item/weapon/material/sword/armingsword)