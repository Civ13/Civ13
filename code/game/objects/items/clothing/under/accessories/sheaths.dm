/obj/item/clothing/accessory/storage/sheath
	name = "short sword sheath"
	desc = "A case of leather for a shorter length sword."
	var/base_icon = "short_sheath"
	icon_state = "short_sheath"
	item_state = "short_sheath"
	slots = 1
	slot = "utility"
	ripable = FALSE
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/material/sword/smallsword,
		/obj/item/weapon/material/sword/gladius,
		/obj/item/weapon/material/sword/xiphos,
		/obj/item/weapon/material/sword/gaelic,
		/obj/item/weapon/material/sword/khopesh,
		/obj/item/weapon/material/sword/kukri,
		/obj/item/weapon/material/sword/bolo)



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

	var/obj/item/weapon/currsword = null
	for(var/obj/item/weapon/W in H.hold)
		currsword = W

	if (!currsword)
		var/obj/item/W = usr.get_active_hand()
		attackby(W, usr)
		if (H.hold.contents.len >= 1)
			visible_message("[usr] stores \the [W].")
//			update_icon()
			playsound(usr, 'sound/items/unholster_sword01.ogg', 50, 1)
			return TRUE
		else
			usr << "<span class='warning'>That is not going to fit there.</span>"
			return FALSE

	else
		if (istype(usr.get_active_hand(),/obj) && istype(usr.get_inactive_hand(),/obj))
			usr << "<span class='warning'>You need an empty hand to draw \the [currsword]!</span>"
			return FALSE
		else
			usr.put_in_hands(currsword)
			visible_message("<span class='danger'>[usr] draws \the [currsword]!</span>")
//			update_icon()
			playsound(usr, 'sound/items/unholster_sword02.ogg', 80, 1)
			return TRUE

/*obj/item/clothing/accessory/storage/sheath/update_icon()
	if (hold.contents.len > 0)
		icon_state = "[base_icon]"
		item_state = "[base_icon]"
	else
		icon_state = "[base_icon]_empty"
		item_state = "[base_icon]_empty"
*/
/obj/item/clothing/accessory/storage/sheath/longsword
	name = "long sword sheath"
	desc = "A large leather case. Looks long enough to accommodate most swords."
	base_icon = "longsword_sheath"
	icon_state = "longsword_sheath"
	item_state = "longsword_sheath"
	slots = 1
	slot = "utility"
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/material/sword/arabsword,
		/obj/item/weapon/material/sword/arabsword2,
		/obj/item/weapon/material/sword/armingsword,
		/obj/item/weapon/material/sword/bolo,
		/obj/item/weapon/material/sword/broadsword,
		/obj/item/weapon/material/sword/cutlass,
		/obj/item/weapon/material/sword/gaelic,
		/obj/item/weapon/material/sword/gladius,
		/obj/item/weapon/material/sword/khopesh,
		/obj/item/weapon/material/sword/kukri,
		/obj/item/weapon/material/sword/longquan,
		/obj/item/weapon/material/sword/longsword,
		/obj/item/weapon/material/sword/magic,
		/obj/item/weapon/material/sword/mersksword,
		/obj/item/weapon/material/sword/rapier,
		/obj/item/weapon/material/sword/sabre,
		/obj/item/weapon/material/sword/saif,
		/obj/item/weapon/material/sword/scimitar,
		/obj/item/weapon/material/sword/shashka,
		/obj/item/weapon/material/sword/smallsword,
		/obj/item/weapon/material/sword/spadroon,
		/obj/item/weapon/material/sword/tes13,
		/obj/item/weapon/material/sword/training,
		/obj/item/weapon/material/sword/urukhaiscimitar,
		/obj/item/weapon/material/sword/xiphos,
		/obj/item/weapon/material/sword/zweihander,
		/obj/item/weapon/material/machete,
		/obj/item/weapon/material/machete1)

/obj/item/clothing/accessory/storage/sheath/katana
	name = "katana sheath"
	desc = "A case of leather for a katana."
	base_icon = "katana_sheath"
	icon_state = "katana_sheath"
	item_state = "katana_sheath"
	slots = 1
	slot = "utility"
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/material/sword/katana,
		/obj/item/weapon/material/sword/wakazashi,
		/obj/item/weapon/material/sword/training/bamboo,
		/obj/item/weapon/material/kitchen/utensil/knife/tanto)

/obj/item/clothing/accessory/storage/sheath/katana/full
	slots = 1
/obj/item/clothing/accessory/storage/sheath/katana/full/New()
	..()
	new/obj/item/weapon/material/sword/katana(src)


/obj/item/clothing/accessory/storage/sheath/daisho
	name = "daisho sheaths"
	desc = "A pair of leather cases for a matched weapon set."
	base_icon = "daisho_sheath"
	icon_state = "daisho_sheath"
	item_state = "daisho_sheath"
	slots = 2
	slot = "utility"
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/material/sword/katana,
		/obj/item/weapon/material/sword/wakazashi,
		/obj/item/weapon/material/sword/training/bamboo,
		/obj/item/weapon/material/kitchen/utensil/knife/tanto)

/obj/item/clothing/accessory/storage/sheath/longer
	name = "sword sheath"
	desc = "A case of leather for holding a sword, it is of intermediate length."
	base_icon = "longer_sheath"
	icon_state = "longer_sheath"
	item_state = "longer_sheath"
	slots = 1
	slot = "utility"
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/material/sword/arabsword,
		/obj/item/weapon/material/sword/arabsword2,
		/obj/item/weapon/material/sword/armingsword,
		/obj/item/weapon/material/sword/bolo,
		/obj/item/weapon/material/sword/cutlass,
		/obj/item/weapon/material/sword/gaelic,
		/obj/item/weapon/material/sword/gladius,
		/obj/item/weapon/material/sword/khopesh,
		/obj/item/weapon/material/sword/kukri,
		/obj/item/weapon/material/sword/longquan,
		/obj/item/weapon/material/sword/magic,
		/obj/item/weapon/material/sword/mersksword,
		/obj/item/weapon/material/sword/rapier,
		/obj/item/weapon/material/sword/sabre,
		/obj/item/weapon/material/sword/saif,
		/obj/item/weapon/material/sword/scimitar,
		/obj/item/weapon/material/sword/shashka,
		/obj/item/weapon/material/sword/smallsword,
		/obj/item/weapon/material/sword/spadroon,
		/obj/item/weapon/material/sword/tes13/steel,
		/obj/item/weapon/material/sword/training,
		/obj/item/weapon/material/sword/urukhaiscimitar,
		/obj/item/weapon/material/sword/xiphos,
		/obj/item/weapon/material/machete,
		/obj/item/weapon/material/machete1)

/obj/item/clothing/accessory/storage/sheath/longer/officer
	name = "officer rig"
	desc = "A pair of cases for holding an officer's side arms. Can hold pistols, revolvers, and most swords."
	base_icon = "longer_sheath"
	icon_state = "longer_sheath"
	item_state = "longer_sheath"
	slots = 2
	slot = "utility"
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/material/sword/arabsword,
		/obj/item/weapon/material/sword/arabsword2,
		/obj/item/weapon/material/sword/armingsword,
		/obj/item/weapon/material/sword/bolo,
		/obj/item/weapon/material/sword/cutlass,
		/obj/item/weapon/material/sword/gaelic,
		/obj/item/weapon/material/sword/gladius,
		/obj/item/weapon/material/sword/khopesh,
		/obj/item/weapon/material/sword/kukri,
		/obj/item/weapon/material/sword/longquan,
		/obj/item/weapon/material/sword/magic,
		/obj/item/weapon/material/sword/mersksword,
		/obj/item/weapon/material/sword/rapier,
		/obj/item/weapon/material/sword/sabre,
		/obj/item/weapon/material/sword/saif,
		/obj/item/weapon/material/sword/scimitar,
		/obj/item/weapon/material/sword/shashka,
		/obj/item/weapon/material/sword/smallsword,
		/obj/item/weapon/material/sword/spadroon,
		/obj/item/weapon/material/sword/tes13/steel,
		/obj/item/weapon/material/sword/urukhaiscimitar,
		/obj/item/weapon/material/sword/xiphos,
		/obj/item/weapon/material/machete,
		/obj/item/weapon/material/machete1,
		/obj/item/weapon/gun/projectile/flintlock/pistol,
		/obj/item/weapon/gun/projectile/flintlock/pistoletmodelean1733,
		/obj/item/weapon/gun/projectile/flintlock/pistoletmodeleanxiii,
		/obj/item/weapon/gun/projectile/flintlock/blunderbuss/pistol,
		/obj/item/weapon/gun/projectile/flintlock/duellingpistol,
		/obj/item/weapon/material/sword/katana,
		/obj/item/weapon/material/sword/wakazashi,
		/obj/item/weapon/gun/projectile/capnball,
		/obj/item/weapon/gun/projectile/pistol,
		/obj/item/weapon/gun/projectile/revolver,
		/obj/item/weapon/whistle,
		/obj/item/weapon/horn,
		/obj/item/weapon/melee)

/obj/item/clothing/accessory/storage/sheath/knife
	name = "knife sheath"
	desc = "A leather case for holding a knife."
	base_icon = "knifeholster"
	icon_state = "knifeholster"
	item_state = "knifeholster"
	slots = 1
	slot = "utility"
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/material/kitchen/utensil,
		/obj/item/weapon/surgery/scalpel,
		/obj/item/weapon/attachment/bayonet,
		/obj/item/weapon/material/thrown/kunai_normal,
		/obj/item/weapon/material/thrown/throwing_knife,
		/obj/item/weapon/material/thrown/throwing_knife1,
		/obj/item/weapon/material/kitchen/utensil/knife/tanto)

/obj/item/clothing/accessory/storage/sheath/baton
	name = "belt loop"
	desc = "A loop for your belt. You could probably store something dibilitating there."
	base_icon = "knifeholster"
	icon_state = "knifeholster"
	item_state = "knifeholster"
	slots = 1
	slot = "utility"
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/melee)


/obj/item/clothing/accessory/storage/sheath/baton/enforcement
	name = "duty rig"
	desc = "A set of loops and cases on a belt. You could probably store some enforcement tool there."
	base_icon = "tacholster"
	icon_state = "tacholster"
	item_state = "tacholster"
	slots = 2
	slot = "utility"
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/melee/classic_baton/guard,
		/obj/item/weapon/reagent_containers/spray/pepper,
		/obj/item/weapon/handcuffs,
		/obj/item/clothing/mask/muzzle,
		/obj/item/weapon/melee/nightbaton,
		/obj/item/weapon/whistle,
		/obj/item/weapon/horn,
		/obj/item/weapon/melee/telebaton)


/obj/item/clothing/accessory/storage/sheath/baton/enslavement
	name = "loose pouches"
	desc = "A pair of loose pouches, perfect for getting some pacifying tools quickly."
	base_icon = "tan_pouches"
	icon_state = "tan_pouches"
	item_state = "tan_pouches"
	slots = 2
	slot = "utility"
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/melee,
		/obj/item/weapon/handcuffs,
		/obj/item/weapon/reagent_containers/syringe/ld50_syringe/choral,
		/obj/item/clothing/mask/muzzle,
		/obj/item/weapon/gun/projectile/dartgun/blowgun)

/obj/item/clothing/accessory/storage/sheath/thrown
	name = "thrown weapon bandolier"
	desc = "A set of leather cases on belts for storing and retrieving thrown weapons quickly."
	base_icon = "bandolier"
	icon_state = "bandolier"
	item_state = "bandolier"
	slots = 4
	slot = "utility"
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/material/thrown)