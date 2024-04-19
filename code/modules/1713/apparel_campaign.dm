/obj/item/clothing/accessory/armband/redfaction
	name = "red armband"
	desc = "A red armband"
	icon_state = "red"
	slot = "armband"

/obj/item/clothing/accessory/armband/bluefaction
	name = "blue armband"
	desc = "A red armband"
	icon_state = "french"
	slot = "armband"

    
///////////////////// Pouches ///////////////////////

/obj/item/weapon/storage/belt/smallpouches/red
	icon_state = "smallpouches_olive"
	item_state = "smallpouches_olive"
	New()
		..()
		new /obj/item/clothing/mask/gas/swat_new(src)
		new /obj/item/stack/medical/bruise_pack/gauze(src)
		new /obj/item/ammo_magazine/ak47(src)
		new /obj/item/weapon/attachment/bayonet(src)

/obj/item/weapon/storage/belt/smallpouches/red/white
	icon_state = "smallpouches_white"
	item_state = "smallpouches_white"

/obj/item/weapon/storage/belt/largepouches/redmg
/obj/item/weapon/storage/belt/largepouches/redmg/New()
	..()
	new /obj/item/ammo_magazine/dp(src)
	new /obj/item/ammo_magazine/dp(src)

/obj/item/weapon/storage/belt/largepouches/redmg/white
	icon_state = "largepouches_white"
	item_state = "largepouches_white"

/obj/item/weapon/storage/belt/smallpouches/blue
	icon_state = "smallpouches_olive"
	item_state = "smallpouches_olive"
	New()
		..()
		new /obj/item/clothing/mask/gas/swat_new(src)
		new /obj/item/stack/medical/bruise_pack/gauze(src)
		new /obj/item/ammo_magazine/ak47(src)
		new /obj/item/weapon/attachment/bayonet(src)

/obj/item/weapon/storage/belt/smallpouches/blue/white
	icon_state = "smallpouches_white"
	item_state = "smallpouches_white"

/obj/item/weapon/storage/belt/largepouches/bluemg
/obj/item/weapon/storage/belt/largepouches/bluemg/New()
	..()
	new /obj/item/ammo_magazine/dp(src)
	new /obj/item/ammo_magazine/dp(src)

/obj/item/weapon/storage/belt/largepouches/bluemg/white
	icon_state = "largepouches_white"
	item_state = "largepouches_white"


///////////////////// Webbings ///////////////////////

/obj/item/clothing/accessory/storage/webbing/green_webbing/blue
	name = "Blugoslavian green chest webbing"
	desc = "A green chest-level webbing, with three medium sized pouches."
	slots = 3
	icon_state = "green_webbing"
	item_state = "green_webbing"

/obj/item/clothing/accessory/storage/webbing/green_webbing/blue/sksm
	New()
		..()
		for (var/i=1, i<= 3, i++)
			new /obj/item/ammo_magazine/sksm(hold)

/obj/item/clothing/accessory/storage/webbing/green_webbing/blue/svd
	New()
		..()
		for (var/i=1, i<= 3, i++)
			new /obj/item/ammo_magazine/svd(hold)

/obj/item/clothing/accessory/storage/webbing/green_webbing/blue/ak47
	New()
		..()
		for (var/i=1, i<= 3, i++)
			new/obj/item/ammo_magazine/ak47(hold)

/obj/item/clothing/accessory/storage/webbing/green_webbing/blue/ak74
	New()
		..()
		for (var/i=1, i<= 3, i++)
			new/obj/item/ammo_magazine/ak74(hold)

/obj/item/clothing/accessory/storage/webbing/green_webbing/blue/akdrum
	New()
		..()
		for (var/i=1, i<= 3, i++)
			new/obj/item/ammo_magazine/ak47/drum(hold)

/obj/item/clothing/accessory/storage/webbing/green_webbing/blue/nomads
	New()
		..()
		for (var/i=1, i<= 3, i++)
			new/obj/item/ammo_magazine/emptymagazine/rifle/ak47/filled(hold)

/obj/item/clothing/accessory/storage/webbing/green_webbing/red
	name = "Redmenian green chest webbing"
	desc = "A green chest-level webbing, with three medium sized pouches."
	slots = 3
	icon_state = "green_webbing"
	item_state = "green_webbing"

/obj/item/clothing/accessory/storage/webbing/green_webbing/red/m16
	New()
		..()
		for (var/i=1, i<= 3, i++)
			new/obj/item/ammo_magazine/m16(hold)

/obj/item/clothing/accessory/storage/webbing/green_webbing/red/ak47
	New()
		..()
		for (var/i=1, i<= 3, i++)
			new/obj/item/ammo_magazine/ak47(hold)

/obj/item/clothing/accessory/storage/webbing/green_webbing/red/nomads
	New()
		..()
		for (var/i=1, i<= 3, i++)
			new/obj/item/ammo_magazine/emptymagazine/rifle/m16/filled(hold)