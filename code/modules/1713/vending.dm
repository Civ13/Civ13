// APPAREL RACKS

/obj/structure/vending/piratesapparel
	name = "Pirate clothes rack"
	desc = "Basic wear for pirates soldiers."
	icon_state = "apparel_pirates"
	products = list(
		/obj/item/clothing/suit/storage/jacket/piratejacket1 = 15,
		/obj/item/clothing/suit/storage/jacket/piratejacket3 = 15,
		/obj/item/clothing/suit/storage/jacket/piratejacket4 = 15,
		/obj/item/clothing/under/pirate1 = 15,
		/obj/item/clothing/under/pirate2 = 15,
		/obj/item/clothing/under/pirate3 = 15,
		/obj/item/clothing/under/pirate4 = 15,
		/obj/item/clothing/under/pirate5 = 15,
		/obj/item/clothing/head/piratebandana1 = 25,
	)

/obj/structure/vending/muskets
	name = "Musket rack"
	desc = "A rack of war muskets."
	icon_state = "apparel_rifles"
	products = list(
		/obj/item/weapon/gun/projectile/flintlock/musket = 15,

	)

/obj/structure/vending/flintlock
	name = "Flintlock weapon rack"
	desc = "An assorted rack of flintlock weapons."
	icon_state = "apparel_rifles"
	products = list(
		/obj/item/weapon/gun/projectile/flintlock/musketoon = 5,
		/obj/item/weapon/gun/projectile/flintlock/pistol = 5,
		/obj/item/weapon/gun/projectile/flintlock/blunderbuss = 5,

	)

/obj/structure/vending/britishapparel
	name = "Royal Navy sailor clothes rack"
	desc = "Basic wear for sailors of the Royal Navy."
	icon_state = "apparel_british"
	products = list(
		/obj/item/clothing/under/british_sailor1 = 15,
		/obj/item/clothing/under/british_sailor2 = 15,
		/obj/item/clothing/under/british_sailor3 = 15,
		/obj/item/clothing/under/british_sailor4 = 15,
		/obj/item/clothing/head/tarred_hat = 25,
		/obj/item/clothing/accessory/armband/british_scarf = 25,

	)

//	idle_power_usage = 0

/obj/structure/vending/rusweapons
	name = "Russian Weapon rack"
	desc = "A rack of war equipment."
	icon_state = "equipment_russia"
	products = list(
		/obj/item/weapon/gun/projectile/boltaction/mosin = 15,
		/obj/item/ammo_magazine/mosin = 50,
		/obj/item/ammo_magazine/mosinbox = 10,
	)

/obj/structure/vending/ww1gerweapons
	name = "German rifle rack"
	desc = "A rack of rifles and ammunition."
	icon_state = "modern_german"
	products = list(
		/obj/item/weapon/gun/projectile/boltaction/gewehr98 = 15,
		/obj/item/ammo_magazine/gewehr98 = 50,
		/obj/item/ammo_magazine/mauser = 20,
		/obj/item/weapon/attachment/bayonet/military = 25,
	)

/obj/structure/vending/ww1britweapons
	name = "British rifle rack"
	desc = "A rack of rifles and ammunition."
	icon_state = "modern_british"
	products = list(
		/obj/item/weapon/gun/projectile/boltaction/enfield = 15,
		/obj/item/ammo_magazine/enfield = 50,
		/obj/item/ammo_magazine/c455 = 20,
		/obj/item/weapon/attachment/bayonet/military = 25,
	)
/obj/structure/vending/ww1frenchweapons
	name = "French rifle rack"
	desc = "A rack of rifles and ammunition."
	icon_state = "modern_france"
	products = list(
		/obj/item/weapon/gun/projectile/boltaction/lebel = 15,
		/obj/item/ammo_magazine/c8x50 = 20,
		/obj/item/ammo_magazine/c8x50_3clip = 30,
		/obj/item/ammo_magazine/c8x27 = 20,
		/obj/item/weapon/attachment/bayonet/military = 25,
	)
/obj/structure/vending/ww1frenchapparel
	name = "French Army apparel rack"
	desc = "Basic wear for soldiers of the French Army."
	icon_state = "apparel_france"
	products = list(
		/obj/item/clothing/shoes/leatherboots1 = 15,
		/obj/item/clothing/under/ww1/french = 15,
		/obj/item/clothing/suit/storage/coat/frenchcoat = 15,
		/obj/item/clothing/head/ww/frenchcap = 15,
		/obj/item/clothing/accessory/storage/webbing/ww1/french = 15,
		/obj/item/clothing/head/helmet/ww/adrian = 15,
		/obj/item/clothing/mask/gas/french = 15,
		/obj/item/stack/medical/bruise_pack/bint = 10,
		/obj/item/weapon/shovel/trench = 10,
		/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen/full = 30,
		/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/french = 50,
	)
/obj/structure/vending/ww1britapparel
	name = "British Army apparel rack"
	desc = "Basic wear for soldiers of the Royal Army."
	icon_state = "apparel_russia"
	products = list(
		/obj/item/clothing/shoes/leatherboots1 = 15,
		/obj/item/clothing/under/ww1/british = 15,
		/obj/item/clothing/suit/storage/coat/britishcoat = 15,
		/obj/item/clothing/head/ww/britishcap = 15,
		/obj/item/clothing/accessory/storage/webbing/ww1/british = 15,
		/obj/item/clothing/head/helmet/ww/brodie = 15,
		/obj/item/clothing/head/helmet/ww/brodie/khaki = 15,
		/obj/item/clothing/mask/gas/british = 15,
		/obj/item/stack/medical/bruise_pack/bint = 10,
		/obj/item/weapon/shovel/trench = 10,
		/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen/full = 30,
		/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/british = 50,
	)
/obj/structure/vending/ww1gerapparel
	name = "German Army apparel rack"
	desc = "Basic wear for soldiers of the Imperial German Army."
	icon_state = "apparel_german2"
	products = list(
		/obj/item/clothing/shoes/blackboots1 = 15,
		/obj/item/clothing/under/ww1/german = 15,
		/obj/item/clothing/suit/storage/coat/germcoat = 15,
		/obj/item/clothing/head/ww/germcap = 15,
		/obj/item/clothing/accessory/storage/webbing/ww1/german = 15,
		/obj/item/clothing/head/helmet/ww/stahlhelm = 15,
		/obj/item/clothing/head/helmet/modern/pickelhaube = 15,
		/obj/item/clothing/mask/gas/german = 15,
		/obj/item/stack/medical/bruise_pack/bint = 10,
		/obj/item/weapon/shovel/trench = 10,
		/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen/full = 30,
		/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/german = 50,
	)
/obj/structure/vending/japweapons
	name = "Japanese Weapon rack"
	desc = "A rack of war equipment."
	icon_state = "equipment_japan"
	products = list(
		/obj/item/weapon/gun/projectile/boltaction/arisaka30 = 15,
		/obj/item/ammo_magazine/arisakabox = 10,
		/obj/item/ammo_magazine/arisaka = 50,
		/obj/item/weapon/attachment/bayonet/military = 15,
	)

/obj/structure/vending/japaneseapparel
	name = "Imperial Japanese Army apparel rack"
	desc = "Basic wear for soldiers of the Imperial Japanese Army."
	icon_state = "apparel_japan"
	products = list(
		/obj/item/clothing/shoes/japboots = 15,
		/obj/item/clothing/under/japuni = 15,
		/obj/item/clothing/suit/storage/coat/japcoat = 15,
		/obj/item/clothing/suit/storage/coat/japcoat2 = 15,
		/obj/item/clothing/suit/armor/japmisc/japvest = 5,
		/obj/item/clothing/head/japcap = 15,
		/obj/item/clothing/head/japcap2 = 15,
		/obj/item/stack/medical/bruise_pack/bint = 10,
		/obj/item/weapon/shovel/trench = 10,
		/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen/full = 30,
		/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/japanese = 50,
	)

/obj/structure/vending/usa_apparel_ww2
	name = "US Army apparel rack"
	desc = "Basic wear for soldiers of the US Army."
	icon_state = "apparel_usa"
	products = list(
		/obj/item/clothing/shoes/jackboots = 15,
		/obj/item/clothing/under/ww2/us = 15,
		/obj/item/clothing/under/ww2/us_shirtless = 15,
		/obj/item/clothing/head/helmet/ww2/us = 15,
		/obj/item/stack/medical/bruise_pack/bint = 10,
		/obj/item/weapon/shovel/trench = 10,
		/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen/full = 30,
		/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/american = 50,
	)

/obj/structure/vending/usa_equipment_ww2
	name = "US Army equipment rack"
	desc = "Basic gear for soldiers of the US Army."
	icon_state = "equipment_usa"
	products = list(
		/obj/item/weapon/gun/projectile/semiautomatic/m1garand = 15,
		/obj/item/ammo_magazine/garand = 50,
		/obj/item/ammo_magazine/springfield = 40,
		/obj/item/ammo_magazine/bar = 15,
		/obj/item/ammo_magazine/thompson = 15,
		/obj/item/ammo_magazine/m1911 = 10,
	)

/obj/structure/vending/japaneseapparel_ww2
	name = "Imperial Japanese Army apparel rack"
	desc = "Basic wear for soldiers of the Imperial Japanese Army."
	icon_state = "apparel_japan_ww2"
	products = list(
		/obj/item/clothing/shoes/heavyboots/wrappedboots = 15,
		/obj/item/clothing/under/ww2/japuni = 15,
		/obj/item/clothing/suit/storage/coat/ww2/japcoat = 15,
		/obj/item/clothing/head/ww2/japcap = 15,
		/obj/item/clothing/head/helmet/ww2/japhelm = 15,
		/obj/item/clothing/head/ww2/jap_headband = 10,
		/obj/item/stack/medical/bruise_pack/bint = 10,
		/obj/item/weapon/shovel/trench = 10,
		/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen/full = 30,
		/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/japanese = 50,
	)
obj/structure/vending/japweapons_ww2
	name = "Japanese Weapon rack"
	desc = "A rack of war equipment."
	icon_state = "equipment_japan"
	products = list(
		/obj/item/weapon/gun/projectile/boltaction/arisaka38 = 15,
		/obj/item/weapon/gun/projectile/boltaction/arisaka99 = 5,
		/obj/item/ammo_magazine/arisakabox = 5,
		/obj/item/ammo_magazine/arisaka = 50,
		/obj/item/ammo_magazine/arisaka99 = 40,
		/obj/item/weapon/attachment/bayonet/military = 15,
	)

/obj/structure/vending/russianapparel
	name = "Russian Army apparel rack"
	desc = "Basic wear for russian soldiers."
	icon_state = "apparel_russia"
	products = list(
		/obj/item/clothing/shoes/heavyboots/wrappedboots = 15,
		/obj/item/clothing/under/rusuni = 15,
		/obj/item/clothing/suit/storage/coat/ruscoat = 15,
		/obj/item/clothing/head/ruscap = 15,
		/obj/item/stack/medical/bruise_pack/bint = 10,
		/obj/item/weapon/shovel/trench = 10,
		/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen/full = 30,
		/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/russian = 50,

	)


/obj/structure/vending/sofapparel
	name = "SOF apparel rack"
	desc = "Basic wear for U.S. Special Operations Forces."
	icon_state = "apparel_sof"
	products = list(
		/obj/item/clothing/shoes/jackboots = 15,
		/obj/item/clothing/head/jungle_hat/khaki = 15,
		/obj/item/clothing/gloves/fingerless = 15,
		/obj/item/weapon/storage/belt/largepouches = 15,
		/obj/item/weapon/storage/belt/smallpouches = 15,
		/obj/item/flashlight/flashlight = 15,
		/obj/item/clothing/under/us_uni/us_camo_woodland = 15,
		/obj/item/clothing/under/us_uni/us_camo_dcu = 15,
		/obj/item/clothing/under/us_uni/us_camo_ucp = 15,
		/obj/item/clothing/under/us_uni/us_camo_ocp = 15,
		/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen/full = 30,
		/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/american = 30,
		/obj/item/clothing/accessory/armor/coldwar/plates/interceptor = 10,
		/obj/item/clothing/accessory/armor/coldwar/plates/interceptor/ucp = 10,
		/obj/item/clothing/accessory/armor/coldwar/plates/interceptor/ocp = 10,
		/obj/item/weapon/armorplates = 15,
		/obj/item/clothing/accessory/armor/knee_protections = 15,
		/obj/item/clothing/accessory/armor/elbow_protections = 15,
		/obj/item/clothing/head/helmet/modern/lwh = 15,
		/obj/item/clothing/head/helmet/modern/lwh/black = 15,
		/obj/item/clothing/head/jungle_hat/khaki = 15,
		/obj/item/clothing/mask/balaclava = 15,
		/obj/item/clothing/glasses/nvg = 15,
	)

/obj/structure/vending/sofweapons
	name = "SOF weapons rack"
	desc = "Weapons for U.S. Special Operations Forces."
	icon_state = "weapons_sof"
	products = list(
		/obj/item/weapon/gun/projectile/submachinegun/m16/m16a4 = 15,
		/obj/item/weapon/gun/projectile/submachinegun/m16/commando/m4mws = 15,
		/obj/item/weapon/gun/projectile/submachinegun/m14 = 15,
		/obj/item/weapon/gun/projectile/submachinegun/ak74/aks74/aks74u/aks74uso = 15,
		/obj/item/weapon/gun/projectile/submachinegun/scarl = 15,
		/obj/item/weapon/gun/projectile/submachinegun/scarh = 15,
		/obj/item/weapon/gun/projectile/submachinegun/hk417 = 15,
		/obj/item/weapon/gun/projectile/pistol/m1911 = 15,
		/obj/item/weapon/gun/projectile/pistol/m9beretta = 15,
		/obj/item/weapon/grenade/smokebomb/m18smoke = 15,
		/obj/item/weapon/grenade/coldwar/m67 = 15,
		/obj/item/weapon/grenade/coldwar/nonfrag/m26 = 15,
		/obj/item/weapon/grenade/flashbang/m84 = 15,
		/obj/item/weapon/grenade/incendiary/anm14 = 15,
		/obj/item/weapon/plastique/c4 = 6,
	)

obj/structure/vending/sofammo
	name = "SOF ammunition crates"
	desc = "ammunition and attachments for U.S. Special Operations Forces."
	icon_state = "ammo_crates"
	products = list(
		/obj/item/ammo_magazine/ak74 = 20,
		/obj/item/ammo_magazine/m16 = 50,
		/obj/item/ammo_magazine/m14 = 50,
		/obj/item/ammo_magazine/hk = 20,
		/obj/item/ammo_magazine/scarh = 20,
		/obj/item/ammo_magazine/m1911 = 50,
		/obj/item/ammo_magazine/m9beretta = 50,
		/obj/item/weapon/attachment/scope/adjustable/sniper_scope = 15,
		/obj/item/weapon/attachment/scope/adjustable/advanced/acog = 15,
		/obj/item/weapon/attachment/scope/adjustable/advanced/reddot = 15,
		/obj/item/weapon/attachment/scope/adjustable/advanced/holographic = 15,
		/obj/item/weapon/attachment/under/laser = 15,
		/obj/item/weapon/attachment/under/foregrip = 15,
	)


/obj/structure/vending/sovietapparel
	name = "Red Army apparel rack"
	desc = "Basic wear for russian soldiers."
	icon_state = "apparel_russia"
	products = list(
		/obj/item/clothing/shoes/heavyboots/wrappedboots = 15,
		/obj/item/clothing/under/ww2/soviet = 15,
		/obj/item/clothing/suit/storage/coat/ww2/soviet = 15,
		/obj/item/clothing/head/ww2/sov_pilotka = 15,
		/obj/item/clothing/head/ww2/sov_ushanka = 10,
		/obj/item/clothing/head/helmet/ww2/soviet = 15,
		/obj/item/clothing/accessory/storage/webbing/ww1/leather = 15,
		/obj/item/stack/medical/bruise_pack/bint = 10,
		/obj/item/weapon/shovel/trench = 10,
		/obj/item/flashlight/flashlight = 15,
		/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen/full = 30,
		/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/russian = 50,

	)

/obj/structure/vending/wehrmachtapparel
	name = "Wehrmacht apparel rack"
	desc = "Basic wear for german soldiers."
	icon_state = "apparel_german"
	products = list(
		/obj/item/clothing/shoes/jackboots = 15,
		/obj/item/clothing/under/ww2/german = 15,
		/obj/item/clothing/suit/storage/coat/ww2/german = 15,
		/obj/item/clothing/head/ww2/german_fieldcap = 15,
		/obj/item/clothing/head/helmet/ww2/gerhelm = 15,
		/obj/item/clothing/accessory/storage/webbing/ww1/german = 15,
		/obj/item/stack/medical/bruise_pack/bint = 10,
		/obj/item/weapon/shovel/trench = 10,
		/obj/item/flashlight/flashlight = 15,
		/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen/full = 30,
		/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/german = 50,

	)

/obj/structure/vending/wehrmachtweapons
	name = "Wehrmacht rifle rack"
	desc = "A rack of war equipment."
	icon_state = "modern_german"
	products = list(
		/obj/item/weapon/gun/projectile/boltaction/gewehr98/karabiner98k = 15,
		/obj/item/weapon/attachment/bayonet/military = 15,
	)

/obj/structure/vending/sovietweapons
	name = "Soviet rifle rack"
	desc = "A rack of war equipment."
	icon_state = "modern_british"
	products = list(
		/obj/item/weapon/gun/projectile/boltaction/mosin/m30 = 15,
		/obj/item/weapon/attachment/bayonet/military = 15,
	)


/obj/structure/vending/oldrussianweapons
	name = "Russian rifle rack"
	desc = "A rack of war equipment."
	icon_state = "modern_british"
	products = list(
		/obj/item/weapon/gun/projectile/boltaction/mosin = 15,
		/obj/item/weapon/attachment/bayonet/military = 15,
	)

/obj/structure/vending/wehrmachtammo
	name = "Wehrmacht ammo crate"
	desc = "A large crate of Wehrmacht ammunition."
	icon_state = "ammo_crates"
	products = list(
		/obj/item/ammo_magazine/gewehr98box = 10,
		/obj/item/ammo_magazine/gewehr98 = 50,
		/obj/item/ammo_magazine/mp40 = 15,
		/obj/item/ammo_magazine/stg = 15,
		/obj/item/ammo_magazine/g43 = 15,
		/obj/item/ammo_magazine/mg34 = 10,
		/obj/item/ammo_magazine/luger = 10,
		/obj/item/ammo_magazine/walther = 10,
	)

/obj/structure/vending/sovietammo
	name = "Soviet ammo crate"
	desc = "A large crate of Red Army ammunition."
	icon_state = "ammo_crates"
	products = list(
		/obj/item/ammo_magazine/mosinbox = 10,
		/obj/item/ammo_magazine/mosin = 50,
		/obj/item/ammo_magazine/svt = 15,
		/obj/item/ammo_magazine/c762x25_pps = 15,
		/obj/item/ammo_magazine/c762x25_ppsh = 15,
		/obj/item/ammo_magazine/dp = 10,
		/obj/item/ammo_magazine/c762x38mmR = 10,
		/obj/item/ammo_magazine/tt30 = 10,
	)

obj/structure/vending/idfammo
	name = "IDF ammunition crates"
	desc = "ammunition and attachments for the Israeli Defense Forces."
	icon_state = "ammo_crates"
	products = list(
		/obj/item/ammo_magazine/m16 = 50,
		/obj/item/ammo_magazine/negev = 10,
		/obj/item/ammo_magazine/jericho = 50,
		/obj/item/ammo_magazine/m24 = 50,
		/obj/item/weapon/grenade/coldwar/m67= 20,
		/obj/item/weapon/grenade/smokebomb/m18smoke = 20,
		/obj/item/weapon/grenade/flashbang/m84 = 20,
//		/obj/item/weapon/grenade/incendiary = 20,
	)

obj/structure/vending/hezammo
	name = "Hezbollah ammunition crates"
	desc = "ammunition and attachments for the Hezbollah armed forces."
	icon_state = "ammo_crates"
	products = list(
		/obj/item/ammo_magazine/ak47 = 50,
		/obj/item/ammo_magazine/ak74 = 50,
		/obj/item/ammo_magazine/tt30 = 50,
		/obj/item/ammo_magazine/mosin = 50,
		/obj/item/ammo_magazine/pkm/c100 = 10,
		/obj/item/weapon/grenade/coldwar/m26= 20,
		/obj/item/weapon/grenade/smokebomb/m18smoke = 20,
	)