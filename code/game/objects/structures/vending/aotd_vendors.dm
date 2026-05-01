
/obj/structure/vending/sales/menu
	name = "menu"
	desc = "Place your order here!"
	sound_type = 'sound/effects/deskbell.ogg'
	icon_state = "menu"

/obj/structure/vending/sales/menu/pizza
	products = list(
	/obj/item/weapon/reagent_containers/food/snacks/sliceable/pizza/pizzasauced = 30,
	/obj/item/weapon/reagent_containers/food/snacks/sliceable/pizza/pizzacheesed = 30,
	/obj/item/weapon/reagent_containers/food/snacks/sliceable/pizza/pizzamushroom = 30,
	/obj/item/weapon/reagent_containers/food/snacks/sliceable/pizza/pizzapepperoni = 30,
	/obj/item/weapon/reagent_containers/food/snacks/sliceable/pizza/vegetablepizza = 30,
	/obj/item/weapon/reagent_containers/food/snacks/sliceable/pizza/meatpizza = 30,
	/obj/item/weapon/reagent_containers/food/snacks/sliceable/pizza/pizzahawaiian = 1,
	)
	prices = list(
	/obj/item/weapon/reagent_containers/food/snacks/sliceable/pizza/pizzasauced = 40,
	/obj/item/weapon/reagent_containers/food/snacks/sliceable/pizza/pizzacheesed = 60,
	/obj/item/weapon/reagent_containers/food/snacks/sliceable/pizza/pizzamushroom = 80,
	/obj/item/weapon/reagent_containers/food/snacks/sliceable/pizza/pizzapepperoni = 80,
	/obj/item/weapon/reagent_containers/food/snacks/sliceable/pizza/vegetablepizza = 80,
	/obj/item/weapon/reagent_containers/food/snacks/sliceable/pizza/meatpizza = 120,
	/obj/item/weapon/reagent_containers/food/snacks/sliceable/pizza/pizzahawaiian = 12000,
	)

/obj/structure/vending/sales/menu/ramen
	products = list(
	/obj/item/weapon/reagent_containers/food/snacks/ramen = 30,
	/obj/item/weapon/reagent_containers/food/drinks/bottle/small/sake = 10,
	)
	prices = list(
	/obj/item/weapon/reagent_containers/food/snacks/ramen = 100,
	/obj/item/weapon/reagent_containers/food/drinks/bottle/small/sake = 120,
	)

/obj/structure/vending/sales/menu/mcd
	icon = 'icons/obj/decals.dmi'
	icon_state = "mcd2"
	products = list(
	/obj/item/weapon/reagent_containers/food/snacks/burger = 50,
	/obj/item/weapon/reagent_containers/food/snacks/cheeseburger = 50,
	/obj/item/weapon/reagent_containers/food/snacks/fries = 80,
	/obj/item/weapon/reagent_containers/food/drinks/can/cola = 50,
	)
	prices = list(
	/obj/item/weapon/reagent_containers/food/snacks/burger = 40,
	/obj/item/weapon/reagent_containers/food/snacks/cheeseburger = 60,
	/obj/item/weapon/reagent_containers/food/snacks/fries = 20,
	/obj/item/weapon/reagent_containers/food/drinks/can/cola = 20,
	)

/obj/structure/vending/sales/menu/donuts
	products = list(
	/obj/item/weapon/storage/fancy/donut_box = 30,
	/obj/item/weapon/reagent_containers/food/snacks/cheesecakeslice = 10,
	/obj/item/weapon/reagent_containers/food/snacks/chocolatecakeslice = 10,
	/obj/item/weapon/reagent_containers/food/snacks/muffin = 15,
	/obj/item/weapon/reagent_containers/food/drinks/coffee = 20,
	/obj/item/weapon/reagent_containers/food/condiment/bsugar = 30,
	)
	prices = list(
	/obj/item/weapon/storage/fancy/donut_box = 60,
	/obj/item/weapon/reagent_containers/food/snacks/cheesecakeslice = 40,
	/obj/item/weapon/reagent_containers/food/snacks/chocolatecakeslice = 40,
	/obj/item/weapon/reagent_containers/food/snacks/muffin = 40,
	/obj/item/weapon/reagent_containers/food/drinks/coffee = 20,
	/obj/item/weapon/reagent_containers/food/condiment/bsugar = 20,
	)

/obj/structure/vending/business_apparel
	name = "equipment rack"
	desc = "All the equipment you need for that special business meeting."
	icon_state = "apparel_german2"
	products = list(
		/obj/item/stack/medical/bruise_pack/gauze = 10,
		/obj/item/clothing/accessory/storage/webbing/pouches = 10,
		/obj/item/weapon/storage/backpack/duffel = 5,
		/obj/item/weapon/storage/briefcase = 5,
		/obj/item/clothing/accessory/holster/armpit = 10,
		/obj/item/clothing/accessory/holster/chest = 10,
		/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars = 10,
		/obj/item/clothing/glasses/sunglasses = 10,
		/obj/item/clothing/gloves/fingerless = 10,
		/obj/item/clothing/mask/balaclava = 10,
		/obj/item/flashlight/flashlight = 10,
		/obj/item/ammo_magazine/emptyspeedloader = 20,
		/obj/item/weapon/handcuffs/rope = 50,
		/obj/item/weapon/material/kitchen/utensil/knife/shank/iron = 10,
	)

/obj/structure/vending/undercover_apparel
	name = "undercover apparel"
	desc = "All the equipment needed for undercover missions."
	icon_state = "apparel_german2"
	products = list(
		/obj/item/clothing/suit/storage/jacket/charcoal_suit = 10,
		/obj/item/clothing/suit/storage/jacket/black_suit = 10,
		/obj/item/clothing/suit/storage/jacket/navy_suit = 10,
		/obj/item/clothing/shoes/laceup = 10,
		/obj/item/clothing/glasses/sunglasses = 10,
		/obj/item/clothing/under/expensive/red = 10,
		/obj/item/clothing/accessory/armband/british = 10,
		/obj/item/clothing/under/expensive/yellow = 10,
		/obj/item/clothing/accessory/armband/spanish = 10,
		/obj/item/clothing/under/expensive/green = 10,
		/obj/item/clothing/accessory/armband/portuguese = 10,
		/obj/item/clothing/under/expensive/blue = 10,
		/obj/item/clothing/accessory/armband/french = 10,
		/obj/item/weapon/storage/backpack/duffel = 10,
		/obj/item/weapon/storage/briefcase = 10,
		/obj/item/clothing/accessory/holster/armpit = 10,
		/obj/item/clothing/accessory/holster/chest = 10,
		/obj/item/weapon/material/kitchen/utensil/knife/shank/iron = 10,
	)

	attack_hand(mob/living/human/user as mob)
		if (user.civilization == "Sheriff Office")
			..()
		else
			to_chat(user, "You do not have access to this.")
			return

/obj/structure/vending/sales/business_weapons
	name = "weapon and ammo rack"
	desc = "When you need to pack that extra punch."
	icon_state = "weapons_sof"
	products = list(
		/obj/item/weapon/gun/projectile/pistol/colthammerless = 5,
		/obj/item/weapon/gun/projectile/pistol/colthammerless/m1908 = 5,
		/obj/item/weapon/gun/projectile/pistol/m1911 = 5,
		/obj/item/weapon/gun/projectile/revolver/smithwesson = 10,
		/obj/item/weapon/attachment/silencer/pistol = 5,

		/obj/item/ammo_magazine/colthammerless = 20,
		/obj/item/ammo_magazine/colthammerless/a380acp = 20,
		/obj/item/ammo_magazine/m1911 = 20,
		/obj/item/ammo_magazine/c32 = 10,

		/obj/item/clothing/accessory/armor/nomads/civiliankevlar = 5,
		/obj/item/clothing/head/ghillie = 2,
		/obj/item/clothing/suit/storage/ghillie = 2,
	)

	prices = list(
		/obj/item/clothing/accessory/armor/nomads/civiliankevlar = 1000,
		/obj/item/clothing/head/ghillie = 500,
		/obj/item/clothing/suit/storage/ghillie = 1000,

		/obj/item/weapon/gun/projectile/pistol/colthammerless = 300,
		/obj/item/weapon/gun/projectile/pistol/colthammerless/m1908 = 300,
		/obj/item/weapon/gun/projectile/pistol/m1911 = 400,
		/obj/item/weapon/gun/projectile/revolver/smithwesson = 240,
		/obj/item/weapon/gun/projectile/shotgun/pump/remington870 = 500,
		/obj/item/weapon/gun/projectile/boltaction/m24 = 600,
		/obj/item/weapon/attachment/silencer/pistol = 120,

		/obj/item/ammo_magazine/colthammerless = 40,
		/obj/item/ammo_magazine/colthammerless/a380acp = 40,
		/obj/item/ammo_magazine/m1911 = 40,
		/obj/item/ammo_magazine/c32 = 80,
		/obj/item/ammo_magazine/shellbox = 80,
		/obj/item/ammo_magazine/shellbox/slug = 80,
		/obj/item/ammo_magazine/m24 = 80,
	)
	attack_hand(mob/living/human/user as mob)
		if (!user.gun_permit)
			to_chat(user, SPAN_WARNING("You do not have a valid gun permit. Get one first from your local police station."))
			return
		var/count = 0
		for (var/list/L in map.gun_registrations)
			if(L[3] == user.real_name)
				count++
		if (count > 4)
			to_chat(user, SPAN_WARNING("You can't buy more weapons. You can only have [count] weapons registered to your name."))
		..()
	attackby(obj/item/I, mob/living/human/user)
		if (!user.gun_permit)
			to_chat(user, SPAN_WARNING("You do not have a valid gun permit. Get one first from your local police station."))
			return
		var/count = 0
		for (var/list/L in map.gun_registrations)
			if(L[3] == user.real_name)
				count++
		if (count > 4)
			to_chat(user, SPAN_WARNING("You can't buy more weapons. You can only have [count] weapons registered to your name."))
		..()

/obj/structure/vending/police_equipment
	name = "police equipment"
	desc = "All the equipment to keep your officers in top shape."
	icon_state = "apparel_german2"
	products = list(
		/obj/item/stack/medical/bruise_pack/gauze = 15,
		/obj/item/clothing/accessory/holster/hip = 15,
		/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars = 15,
		/obj/item/clothing/glasses/sunglasses = 15,
		/obj/item/clothing/gloves/thick/swat = 15,
		/obj/item/clothing/head/helmet/swat = 15,
		/obj/item/clothing/mask/gas/swat = 15,
		/obj/item/clothing/suit/police = 15,
		/obj/item/clothing/suit/storage/jacket/highvis = 15,
		/obj/item/clothing/shoes/swat = 15,
		/obj/item/clothing/under/countysheriff/deputy = 15,
		/obj/item/clothing/under/countysheriff/deputy/short = 15,
		/obj/item/clothing/shoes/laceup = 15,
		/obj/item/clothing/head/countysheriff_cap = 15,
		/obj/item/clothing/head/countysheriff_cap/black = 15,
		/obj/item/weapon/storage/backpack/satchel/police = 10,
		/obj/item/weapon/storage/backpack/satchel/black = 5,
		/obj/item/weapon/storage/backpack/satchel = 5,
		/obj/item/weapon/storage/backpack/duffel = 5,
		/obj/item/weapon/melee/nightbaton = 15,
		/obj/item/weapon/storage/box/handcuffs = 10,
		/obj/item/weapon/storage/box/bodybags = 3,
		/obj/item/weapon/storage/box/evidence = 10,
		/obj/item/taperoll/police = 10,
//		/obj/item/clothing/head/helmet/constable = 5,
//		/obj/item/clothing/under/constable = 5,
//		/obj/item/clothing/under/traffic_police = 5,
	)
	attack_hand(mob/living/human/user as mob)
		if (user.civilization == "Sheriff Office")
			..()
		else
			to_chat(user, "You do not have access to this.")
			return

/obj/structure/vending/police_weapons
	name = "lethal police weapons"
	desc = "When the baton is not enough."
	icon_state = "weapons_sof"
	products = list(
	/obj/item/weapon/gun/projectile/shotgun/pump/remington870 = 10,
	/obj/item/ammo_magazine/shellbox/slug = 10,
	/obj/item/ammo_magazine/shellbox = 10,
	/obj/item/ammo_magazine/glock17 = 50,
	/obj/item/ammo_magazine/m9beretta = 50,
	/obj/item/ammo_magazine/c32 = 50,
	/obj/item/ammo_magazine/c44 = 50,
	/obj/item/weapon/grenade/coldwar/stinger = 20,
	/obj/item/weapon/gun/projectile/boltaction/m24 = 10,
	/obj/item/ammo_magazine/m24 = 20,
	/obj/item/weapon/attachment/scope/adjustable/sniper_scope = 10,
	)
	attack_hand(mob/living/human/user as mob)
		if (user.civilization == "Sheriff Office")
			..()
		else
			to_chat(user, "You do not have access to this.")
			return

/obj/structure/vending/police_weapons/ltl
	name = "less than lethal police weapons"
	desc = "Baton +."
	icon_state = "equipment_usa"
	products = list(
	/obj/item/weapon/gun/projectile/shotgun/pump/remington870 = 10,
	/obj/item/ammo_magazine/shellbox/rubber = 10,
	/obj/item/ammo_magazine/shellbox/beanbag = 10,
	/obj/item/weapon/gun/launcher/grenade/standalone/m79 = 5,
	/obj/item/weapon/grenade/chemical/ugl/teargas = 10,
	/obj/item/weapon/grenade/flashbang = 20,
	/obj/item/weapon/grenade/chemical/xylyl_bromide = 10,
	/obj/item/weapon/grenade/smokebomb/m18smoke = 10,
	/obj/item/weapon/reagent_containers/spray/pepper = 10,
	/obj/item/weapon/gun/projectile/dartgun/mag = 10,

	/obj/item/ammo_magazine/chemdart/mag = 20,
	/obj/item/weapon/reagent_containers/glass/bottle/chloralhydrate = 10,
	/obj/item/ammo_magazine/tt30ll/rubber = 50,

	/obj/item/weapon/gun/projectile/pistol/taser = 5,
	/obj/item/ammo_magazine/taser = 10,
	)
	attack_hand(mob/living/human/user as mob)
		if (user.civilization == "Sheriff Office")
			..()
		else
			to_chat(user, "You do not have access to this.")
			return