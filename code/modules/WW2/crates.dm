#define DYNAMIC_AMT -1

// increase or decrease the amount of items in a crate
/*/obj/structure/closet/crate/proc/resize(decimal)
	if (decimal > 1.0)
		var/add_crates = max(1, ceil((decimal - 1.0) * contents.len))
		for (var/v in 1 to add_crates)
			if (!contents.len)
				break
			var/atom/object = pick(contents)
			if (object)
				var/object_type = object.type
				new object_type(src)

	else if (decimal < 1.0)
		var/remove_crates = ceil((1.0 - decimal) * contents.len)
		for (var/v in 1 to remove_crates)
			if (!contents.len)
				break
			contents -= pick(contents)
	update_capacity(contents.len)
	*/
/obj/structure/closet/crate/var/list/paths = list() // typepath = amount

/obj/structure/closet/crate/New()
	..()
	crate_list += src
	for (var/typepath in paths)
		var/limit = paths[typepath]
		if (limit == DYNAMIC_AMT)
			var/atom/ref = new typepath (null)
			limit = max(3, min(ceil(75/round(ref.contents.len/2)), 12))
			if (ref.contents.len < 100)
				limit += pick(2,3)
			qdel(ref)
		for (var/v in 1 to limit)
			new typepath (src)
	update_capacity(contents.len)

/obj/structure/closet/crate/Destroy()
	crate_list -= src
	..()

// new crate icons from F13 - most are unused

/* todo: turn some crates into CARTS and re-enable this
/obj/structure/closet/crate
	icon = 'icons/obj/crate.dmi'*/

/obj/structure/closet/crate/empty
	name = "Crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"

/obj/structure/closet/crate/wood
	name = "Wood planks crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/stack/material/wood = 5)

/obj/structure/closet/crate/wood/New()
	..()
	for (var/stack in contents)
		var/obj/item/stack/S = stack
		S.amount = 20

/obj/structure/closet/crate/steel
	name = "Steel sheets crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/stack/material/steel = 5)

/obj/structure/closet/crate/steel/New()
	..()
	for (var/stack in contents)
		var/obj/item/stack/S = stack
		S.amount = 20

/obj/structure/closet/crate/iron
	name = "Iron ingots crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/stack/material/iron = 5)

/obj/structure/closet/crate/iron/New()
	..()
	for (var/stack in contents)
		var/obj/item/stack/S = stack
		S.amount = 20

/obj/structure/closet/crate/glass
	name = "Glass sheets crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/stack/material/glass = 5)

/obj/structure/closet/crate/glass/New()
	..()
	for (var/stack in contents)
		var/obj/item/stack/S = stack
		S.amount = 20

/obj/structure/closet/crate/flammenwerfer_fueltanks
	name = "Flammenwerfer fueltanks crate"
	icon = 'icons/WW2/artillery_crate.dmi'
	icon_state = "closed"
	icon_opened = "opened"
	icon_closed = "closed"
	paths = list(/obj/item/weapon/flammenwerfer_fueltank = 3)

/obj/structure/closet/crate/vehicle_fueltanks
	name = "Vehicle fueltanks crate"
	icon = 'icons/WW2/artillery_crate.dmi'
	icon_state = "closed"
	icon_opened = "opened"
	icon_closed = "closed"
	paths = list(/obj/item/weapon/vehicle_fueltank = 3)

/obj/structure/closet/crate/maximbelt
	name = "Maxim belts crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/ammo_magazine/maxim = DYNAMIC_AMT)

/obj/structure/closet/crate/mg34belt
	name = "MG34 belts crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/ammo_magazine/maxim/mg34_belt = DYNAMIC_AMT)

/obj/structure/closet/crate/type92belt
	name = "Type 92 belts crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/ammo_magazine/maxim/type92_belt = DYNAMIC_AMT)

/obj/structure/closet/crate/bint
	name = "Bint crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/weapon/gauze_pack/bint = 10)

/obj/structure/closet/crate/gauze
	name = "Gauze crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/weapon/gauze_pack/gauze = 10)

/obj/structure/closet/crate/medical
	name = "Medical crate"
	icon_state = "freezer"
	icon_opened = "freezeropen"
	icon_closed = "freezer"
	paths = list(
		/obj/item/weapon/storage/firstaid/toxin = 1,
		/obj/item/weapon/storage/firstaid/fire = 1,
		/obj/item/weapon/storage/firstaid/o2 = 1,
		/obj/item/weapon/storage/firstaid/regular = 1,
		/obj/item/weapon/storage/firstaid/injectorpack = 1,
		/obj/item/weapon/storage/firstaid/combat = 1,
		/obj/item/weapon/storage/firstaid/adv = 1,
		/obj/item/weapon/gauze_pack/gauze = 1,
		/obj/item/weapon/doctor_handbook = 1
	)

/obj/structure/closet/crate/mosinammo
	name = "Mosin ammo crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/ammo_magazine/mosin = DYNAMIC_AMT)

/obj/structure/closet/crate/ppshammo
	name = "PPSh ammo crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/ammo_magazine/a556/ppsh = DYNAMIC_AMT)

/obj/structure/closet/crate/lugerammo
	name = "Luger ammo crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/ammo_magazine/luger = DYNAMIC_AMT)

/obj/structure/closet/crate/c45ammo
	name = ".45 ammo crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/ammo_magazine/c45m = DYNAMIC_AMT)

/obj/structure/closet/crate/kar98kammo
	name = "Kar98k ammo crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/ammo_magazine/kar98k = DYNAMIC_AMT)

/obj/structure/closet/crate/mp40kammo
	name = "Mp40 ammo crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/ammo_magazine/mp40 = DYNAMIC_AMT)

/obj/structure/closet/crate/mg34ammo
	name = "Mg34 ammo crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/ammo_magazine/a762 = DYNAMIC_AMT)

/obj/structure/closet/crate/mp43ammo
	name = "Mp43 ammo crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/ammo_magazine/a762/akm = DYNAMIC_AMT)

/obj/structure/closet/crate/ptrdammo
	name = "PTRD ammo crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/ammo_casing/a145 = 12)

/obj/structure/closet/crate/tokarevammo
	name = "Tokarev TT-30 ammo crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/ammo_magazine/c762mm_tokarev = DYNAMIC_AMT)

/obj/structure/closet/crate/mauserammo
	name = "Mauser C96 crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/ammo_magazine/c763x25mm_mauser = DYNAMIC_AMT)

/obj/structure/closet/crate/waltherammo
	name = "Walther P38 ammo crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/ammo_magazine/p9x19mm = DYNAMIC_AMT)

/obj/structure/closet/crate/ppsammo
	name = "PPS-43 ammo crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/ammo_magazine/c762x25mm_pps = DYNAMIC_AMT)

/obj/structure/closet/crate/stenammo
	name = "Sten MKIII ammo crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/ammo_magazine/mp40/c9x19mm_stenmk2 = DYNAMIC_AMT)

/obj/structure/closet/crate/nagantrevolverammo
	name = "Nagant Revolver ammo crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/ammo_magazine/c762x38mmR = DYNAMIC_AMT)

/obj/structure/closet/crate/bettymines
	name = "Betty mines crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/mine/betty = 12)

/obj/structure/closet/crate/dpammo
	name = "DP disk crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/ammo_magazine/a762/dp = DYNAMIC_AMT)

/obj/structure/closet/crate/svtammo
	name = "SVT ammo crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/ammo_magazine/svt = DYNAMIC_AMT)

/obj/structure/closet/crate/type99ammo
	name = "Type 99 ammo crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/ammo_magazine/c77x58_smg = DYNAMIC_AMT)

/obj/structure/closet/crate/m1garand
	name = "M1Garand clips"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/ammo_magazine/c762x63 = DYNAMIC_AMT)

/obj/structure/closet/crate/c762x63_smg
	name = "(30-06) magazines"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/ammo_magazine/c762x63_smg = DYNAMIC_AMT)

/obj/structure/closet/crate/c45m
	name = "M1911 ammo"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/ammo_magazine/c45m = DYNAMIC_AMT)

/obj/structure/closet/crate/c8mmnambu
	name = "Nambu ammo"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/ammo_magazine/c8mmnambu = DYNAMIC_AMT)

/obj/structure/closet/crate/a77x58
	name = "arisaka clips"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/ammo_magazine/a77x58 = DYNAMIC_AMT)

/obj/structure/closet/crate/c8mmnambu_smg
	name = "type 100 ammo"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/ammo_magazine/c8mmnambu_smg = DYNAMIC_AMT)

/obj/structure/closet/crate/c792x57_fg42
	name = "Fg42 ammo"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/ammo_magazine/c792x57_fg42 = DYNAMIC_AMT)

/obj/structure/closet/crate/Thompson_ammo
	name = "Thompson ammo"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/ammo_magazine/c45_smg = DYNAMIC_AMT)

/obj/structure/closet/crate/german_grenade
	name = "Stielgranate 41 crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/weapon/grenade/explosive/stgnade = 7)

/obj/structure/closet/crate/german_grenade2
	name = "l2a2 grenade crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/weapon/grenade/explosive/l2a2 = 7)

/obj/structure/closet/crate/jap_type97
	name = "type97 grenade crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/weapon/grenade/explosive/type97 = 7)

/obj/structure/closet/crate/jap_type91
	name = "type91 grenade crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/weapon/grenade/explosive/type91 = 7)

/obj/structure/closet/crate/US_mk2
	name = "mk2 grenade crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/weapon/grenade/explosive/mk2 = 7)

/obj/structure/closet/crate/panzerfaust
	name = "Panzerfaust crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/weapon/gun/launcher/rocket/panzerfaust = 5)

/obj/structure/closet/crate/mortar_shells
	name = "Mortar shells crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/mortar_shell = 12)

/obj/structure/closet/crate/german_smoke_grenade
	name = "Smoke grenade crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/weapon/grenade/smokebomb/german = 7)

/obj/structure/closet/crate/soviet_smoke_grenade
	name = "Smoke grenade crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/weapon/grenade/smokebomb/soviet = 7)

/obj/structure/closet/crate/soviet_grenade
	name = "RGD-33 crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/weapon/grenade/explosive/rgd = 7)

/obj/structure/closet/crate/soviet_grenade2
	name = "RGD-5 crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/weapon/grenade/explosive/f1 = 7)

/obj/structure/closet/crate/sandbags
	name = "Sandbags crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/weapon/sandbag = 66)

/obj/structure/closet/crate/punji_sticks
	name = "Punji stick crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/weapon/punji_sticks = 25)

/obj/structure/closet/crate/flares_ammo
	name = "Flaregun Ammo crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(
		/obj/item/ammo_magazine/flare/red = 10,
		/obj/item/ammo_magazine/flare/green = 10,
		/obj/item/ammo_magazine/flare/yellow = 10)

/obj/structure/closet/crate/flares
	name = "Flares crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/flashlight/flare = 50)

/obj/structure/closet/crate/barbwire
	name = "Barbwire crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	paths = list(/obj/item/stack/material/barbwire = 3)

/obj/structure/closet/crate/barbwire/New()
	..()
	for (var/stack in contents)
		var/obj/item/stack/S = stack
		S.amount = 15

/obj/structure/closet/crate/bayonets
	name = "Bayonets crate"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"

/obj/structure/closet/crate/bayonets/soviet
	paths = list(/obj/item/weapon/attachment/bayonet/soviet = 15)

/obj/structure/closet/crate/bayonets/german
	paths = list(/obj/item/weapon/attachment/bayonet/german = 15)


/obj/structure/closet/crate/lugers
	name = "Luger crate"
	icon = 'icons/WW2/artillery_crate.dmi'
	icon_state = "closed"
	icon_opened = "opened"
	icon_closed = "closed"
	paths = list(/obj/item/weapon/gun/projectile/pistol/luger = 5)

/obj/structure/closet/crate/colts
	name = "Colt crate"
	icon = 'icons/WW2/artillery_crate.dmi'
	icon_state = "closed"
	icon_opened = "opened"
	icon_closed = "closed"
	paths = list(/obj/item/weapon/gun/projectile/pistol/_45 = 5)

/obj/structure/closet/crate/tokarevs
	name = "Tokarev crate"
	icon = 'icons/WW2/artillery_crate.dmi'
	icon_state = "closed"
	icon_opened = "opened"
	icon_closed = "closed"
	paths = list(/obj/item/weapon/gun/projectile/pistol/tokarev = 5)

/obj/structure/closet/crate/waltherp38
	name = "Walther P38 crate"
	icon = 'icons/WW2/artillery_crate.dmi'
	icon_state = "closed"
	icon_opened = "opened"
	icon_closed = "closed"
	paths = list(/obj/item/weapon/gun/projectile/pistol/waltherp38 = 5)

/obj/structure/closet/crate/gasmasks
	name = "Gasmask crate"
	icon = 'icons/WW2/artillery_crate.dmi'
	icon_state = "closed"
	icon_opened = "opened"
	icon_closed = "closed"
	paths = list(/obj/item/clothing/mask/gas/german = 10)

/obj/structure/closet/crate/gasmasks/soviet
	paths = list(/obj/item/clothing/mask/gas/soviet = 10)

/obj/structure/closet/crate/artillery
	name = "German artillery shell crate"
	icon = 'icons/WW2/artillery_crate.dmi'
	icon_state = "closed2"
	icon_opened = "opened"
	icon_closed = "closed2"
	paths = list(/obj/item/artillery_shell = 12)

/obj/structure/closet/crate/artillery_gas
	name = "German gas artillery shell crate"
	icon = 'icons/WW2/artillery_crate.dmi'
	icon_state = "closed2"
	icon_opened = "opened"
	icon_closed = "closed2"
	paths = list(
		/obj/item/artillery_shell/gaseous/green_cross/chlorine = 3,
		/obj/item/artillery_shell/gaseous/yellow_cross/mustard = 3,
		/obj/item/artillery_shell/gaseous/yellow_cross/white_phosphorus = 3,
		/obj/item/artillery_shell/gaseous/blue_cross/xylyl_bromide = 3)

/obj/structure/closet/crate/webbing
	paths = list(/obj/item/clothing/accessory/storage/webbing = 15)

/obj/structure/closet/crate/rations/
	name = "Rations"
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"

/obj/structure/closet/crate/rations/New()
	..()
	update_capacity(30)
	var/textpath = "[type]"
	if (findtext(textpath, GERMAN))
		if (findtext(textpath, "solids"))
			for (var/v in 1 to rand(10,15))
				contents += new_ration(GERMAN, "solid")
		if (findtext(textpath, "liquids"))
			for (var/v in 1 to rand(10,15))
				contents += new_ration(GERMAN, "liquid")
		if (findtext(textpath, "desserts"))
			for (var/v in 1 to rand(10,15))
				contents += new_ration(GERMAN, "dessert")
		if (findtext(textpath, "meat"))
			for (var/v in 1 to rand(10,15))
				contents += new_ration(GERMAN, "meat")
		if (findtext(textpath, "alcohol"))
			for (var/v in 1 to rand(10,15))
				contents += beer_ration()
	else if (findtext(textpath, "soviet"))
		if (findtext(textpath, "solids"))
			for (var/v in 1 to rand(10,15))
				contents += new_ration(SOVIET, "solid")
		if (findtext(textpath, "liquids"))
			for (var/v in 1 to rand(10,15))
				contents += new_ration(SOVIET, "liquid")
	/*	if (findtext(textpath, "desserts"))
			for (var/v in 1 to rand(10,15))
				contents += new_ration("SOVIET", "dessert")*/
		if (findtext(textpath, "meat"))
			for (var/v in 1 to rand(10,15))
				contents += new_ration(SOVIET, "meat")
		if (findtext(textpath, "alcohol"))
			for (var/v in 1 to rand(10,15))
				contents += vodka_ration()

	else if (findtext(textpath, "water"))
		for (var/v in 1 to rand(20,30))
			contents += water_ration()

	update_capacity(min(30, contents.len+5))


/obj/structure/closet/crate/rations/german_solids
	name = "Rations: solids"

/obj/structure/closet/crate/rations/german_liquids
	name = "Rations: liquids"

/obj/structure/closet/crate/rations/german_desserts
	name = "Rations: dessert"

/obj/structure/closet/crate/rations/german_meat
	name = "Rations: meat"

/obj/structure/closet/crate/rations/german_alcohol
	name = "Rations: bier"

/obj/structure/closet/crate/rations/soviet_solids
	name = "Rations: solids"

/obj/structure/closet/crate/rations/soviet_liquids
	name = "Rations: liquids"

/*
/obj/structure/closet/crate/rations/soviet_desserts
	name = "Rations: dessert"*/

/obj/structure/closet/crate/rations/soviet_meat
	name = "Rations: meat"

/obj/structure/closet/crate/rations/soviet_alcohol
	name = "Rations: vodka"

/obj/structure/closet/crate/rations/water
	name = "Rations: water"

#undef DYNAMIC_AMT