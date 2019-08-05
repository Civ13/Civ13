/obj/item/clothing/accessory/storage/sheath
	name = "sword sheath"
	desc = "A sheath for a shorter length sword."
	icon_state = "short_sheath"
	item_state = "short_sheath"
	slots = 1
	slot = "utility"
	New()
		..()
		hold.can_hold = list(/obj/item/weapon/material/sword/smallsword,
		/obj/item/weapon/material/sword/gladius,
		/obj/item/weapon/material/sword/xiphos)

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
		/obj/item/weapon/material/sword/rapier)