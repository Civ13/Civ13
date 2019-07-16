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

obj/structure/closet/crate/chest
	name = "wood chest"
	desc = "Maybe there's a treasure insde?"
	icon_state = "wood_chest"
	icon_opened = "wood_chest_opened"
	icon_closed = "wood_chest"
	storage_capacity = 3 * MOB_MEDIUM
obj/structure/closet/crate/chest/treasury
	name = "colony treasury"
	desc = "Where the colony treasury is stored."
	icon_state = "wood_chest"
	icon_opened = "wood_chest_opened"
	icon_closed = "wood_chest"
	anchored = TRUE
	var/faction = "civilian"

obj/structure/closet/crate/empty
	name = "wood crate"
	desc = "A wooden crate."
	icon_state = "wood_crate"
	icon_opened = "wood_crate_opened"
	icon_closed = "wood_crate"

/obj/structure/closet/crate/bayonets
	name = "bayonets crate"
	icon_state = "wood_crate"
	icon_opened = "wood_crate_opened"
	icon_closed = "wood_crate"
	paths = list(/obj/item/weapon/attachment/bayonet/military = 10)
	cratevalue = 132//100 base value from 100 planks of wood

/obj/structure/closet/crate/sandbags
	name = "sandbag crate"
	icon_state = "wood_crate"
	icon_opened = "wood_crate_opened"
	icon_closed = "wood_crate"
	paths = list(/obj/item/weapon/sandbag/sandbag = 20)
	cratevalue = 90

/obj/structure/closet/crate/wood
	name = "wood planks crate"
	icon_state = "wood_crate"
	icon_opened = "wood_crate_opened"
	icon_closed = "wood_crate"
	paths = list(/obj/item/stack/material/wood = 5)
	cratevalue = 120 //100 base value from 100 planks of wood

/obj/structure/closet/crate/wood/New()
	..()
	for (var/stack in contents)
		var/obj/item/stack/S = stack
		S.amount = 20

/obj/structure/closet/crate/steel
	name = "steel sheets crate"
	icon_state = "wood_crate"
	icon_opened = "wood_crate_opened"
	icon_closed = "wood_crate"
	paths = list(/obj/item/stack/material/steel = 5)
	cratevalue = 550 //500 base value from 100 steel sheets

/obj/structure/closet/crate/steel/New()
	..()
	for (var/stack in contents)
		var/obj/item/stack/S = stack
		S.amount = 20

/obj/structure/closet/crate/iron
	name = "iron ingots crate"
	icon_state = "wood_crate"
	icon_opened = "wood_crate_opened"
	icon_closed = "wood_crate"
	paths = list(/obj/item/stack/material/iron = 5)
	cratevalue = 330 //300 base value from 100 iron sheets

/obj/structure/closet/crate/iron/New()
	..()
	for (var/stack in contents)
		var/obj/item/stack/S = stack
		S.amount = 20

/obj/structure/closet/crate/glass
	name = "glass sheets crate"
	icon_state = "wood_crate"
	icon_opened = "wood_crate_opened"
	icon_closed = "wood_crate"
	paths = list(/obj/item/stack/material/glass = 5)
	cratevalue = 330 //300 base value from 100 glass sheets

/obj/structure/closet/crate/glass/New()
	..()
	for (var/stack in contents)
		var/obj/item/stack/S = stack
		S.amount = 20

/obj/structure/closet/crate/rations/
	name = "rations"
	icon_state = "wood_crate"
	icon_opened = "wood_crate_opened"
	icon_closed = "wood_crate"

/obj/structure/closet/crate/rations/vegetables
	name = "Rations: vegetables"
	paths = list(/obj/item/weapon/reagent_containers/food/snacks/grown/potato = 4,
				/obj/item/weapon/reagent_containers/food/snacks/grown/beans = 4,
				/obj/item/weapon/reagent_containers/food/snacks/grown/cabbage = 4,
				/obj/item/weapon/reagent_containers/food/snacks/grown/carrot = 4,)
	cratevalue = 60 //48 base, 16 grown stuff x 3

/obj/structure/closet/crate/rations/fruits
	name = "Rations: fruits"
	paths = list(/obj/item/weapon/reagent_containers/food/snacks/grown/lemon = 3,
				/obj/item/weapon/reagent_containers/food/snacks/grown/lime = 3,
				/obj/item/weapon/reagent_containers/food/snacks/grown/apple = 3,
				/obj/item/weapon/reagent_containers/food/snacks/grown/orange = 3,
				/obj/item/weapon/reagent_containers/food/snacks/grown/banana = 3,
				/obj/item/weapon/reagent_containers/food/snacks/grown/coconut = 3,)
	cratevalue = 66 //54, 18 x 3

/obj/structure/closet/crate/rations/biscuits
	name = "Rations: biscuits"
	paths = list(/obj/item/weapon/reagent_containers/food/snacks/hardtack = 20,)
	cratevalue = 50 //Nutrient amt = 2, 2 x 2 for value so 20 x 2 = 40 base

/obj/structure/closet/crate/rations/beer
	name = "Rations: beer"
	paths = list(/obj/item/weapon/reagent_containers/food/drinks/bottle/small/beer = 10,)
	cratevalue = 60 //50 base

/obj/structure/closet/crate/rations/ale
	name = "Rations: ale"
	paths = list(/obj/item/weapon/reagent_containers/food/drinks/bottle/small/ale = 10,)
	cratevalue = 70 //60 base

/obj/structure/closet/crate/rations/meat
	name = "Rations: meat"
	paths = list(/obj/item/weapon/reagent_containers/food/snacks/meat = 7,)
	cratevalue = 70 //just putting this here

/obj/structure/closet/crate/rations/seeds/trees
	name = "Seeds: Trees"
	paths = list(/obj/item/stack/farming/seeds/apple = 4,
				/obj/item/stack/farming/seeds/tree = 4,
				/obj/item/stack/farming/seeds/orange = 4,)
	cratevalue = 30 //seeds don't have a value, effort into farming harvesting and exporting is already lots of work

/obj/structure/closet/crate/rations/seeds/cereals
	name = "Seeds: Cereals (+yeast)"
	paths = list(/obj/item/stack/farming/seeds/wheat = 6,
				/obj/item/stack/farming/seeds/corn = 6,
				/obj/item/weapon/reagent_containers/food/condiment/enzyme = 1,
				/obj/item/weapon/reagent_containers/food/condiment/enzyme = 1)
	cratevalue = 50

/obj/structure/closet/crate/rations/seeds/vegetables
	name = "Seeds: Vegetables"
	paths = list(/obj/item/stack/farming/seeds/tomato = 4,
				/obj/item/stack/farming/seeds/potato = 4,
				/obj/item/stack/farming/seeds/cabbage = 4,)
	cratevalue = 30

/obj/structure/closet/crate/rations/seeds/cashcrops
	name = "Seeds: Cash Crops"
	paths = list(/obj/item/stack/farming/seeds/tobacco = 3,
				/obj/item/stack/farming/seeds/sugarcane = 3,
				/obj/item/stack/farming/seeds/hemp = 3,
				/obj/item/stack/farming/seeds/cotton = 3,)
	cratevalue = 60

/obj/structure/closet/crate/rations/seeds/medicinal
	name = "Seeds: Medicinal"
	paths = list(/obj/item/stack/farming/seeds/poppy = 3,
				/obj/item/stack/farming/seeds/tea = 3,
				/obj/item/stack/farming/seeds/coffee = 3,
				/obj/item/stack/farming/seeds/peyote = 3,)
	cratevalue = 50
///WEAPONS///

/obj/structure/closet/crate/grenades
	name = "Grenade crate"
	icon_state = "wood_crate"
	icon_opened = "wood_crate_opened"
	icon_closed = "wood_crate"
	paths = list(/obj/item/weapon/grenade/old_grenade = 10)
	cratevalue = 110 //assuming value = 10 as no value yet

/obj/structure/closet/crate/musketball
	name = "Musket ammunition crate"
	icon_state = "wood_crate"
	icon_opened = "wood_crate_opened"
	icon_closed = "wood_crate"
	paths = list(/obj/item/ammo_casing/musketball = 25)
	cratevalue = 100 //base 75, 25 x 3
/obj/structure/closet/crate/muskets
	name = "Musket crate"
	icon_state = "wood_crate"
	icon_opened = "wood_crate_opened"
	icon_closed = "wood_crate"
	paths = list(/obj/item/weapon/gun/projectile/flintlock/musket = 5)
	cratevalue = 550 //100*5
/obj/structure/closet/crate/musketoons
	name = "Musketoon crate"
	icon_state = "wood_crate"
	icon_opened = "wood_crate_opened"
	icon_closed = "wood_crate"
	paths = list(/obj/item/weapon/gun/projectile/flintlock/musketoon = 5)
	cratevalue = 440 //80*5
/obj/structure/closet/crate/pistols
	name = "Pistol crate"
	icon_state = "wood_crate"
	icon_opened = "wood_crate_opened"
	icon_closed = "wood_crate"
	paths = list(/obj/item/weapon/gun/projectile/flintlock/pistol = 5)
	cratevalue = 385 //70*5
/obj/structure/closet/crate/blunderbusses
	name = "blunderbuss crate"
	icon_state = "wood_crate"
	icon_opened = "wood_crate_opened"
	icon_closed = "wood_crate"
	paths = list(/obj/item/weapon/gun/projectile/flintlock/blunderbuss = 5)
	cratevalue = 495 //90*5
/obj/structure/closet/crate/musketball_pistol
	name = "Pistol ammunition crate"
	icon_state = "wood_crate"
	icon_opened = "wood_crate_opened"
	icon_closed = "wood_crate"
	paths = list(/obj/item/ammo_casing/musketball_pistol = 25)
	cratevalue = 60 //base value 50

/obj/structure/closet/crate/blunderbuss_ammo
	name = "Blunderbuss ammunition crate"
	icon_state = "wood_crate"
	icon_opened = "wood_crate_opened"
	icon_closed = "wood_crate"
	paths = list(/obj/item/ammo_casing/blunderbuss = 15)
	cratevalue = 60 //base value 45

/obj/structure/closet/crate/cannonball
	name = "Cannonball crate"
	icon_state = "wood_crate"
	icon_opened = "wood_crate_opened"
	icon_closed = "wood_crate"
	paths = list(/obj/item/cannon_ball = 15)
	cratevalue = 175 //assuming 10 value

/obj/structure/closet/crate/webbings
	name = "bandolier crate"
	icon_state = "wood_crate"
	icon_opened = "wood_crate_opened"
	icon_closed = "wood_crate"
	paths = list(/obj/item/clothing/accessory/storage/webbing = 10)
	cratevalue = 110 //assuming 10 value


////WW1////////
obj/structure/closet/crate/ww1/grenades_french
	name = "F1 grenade crate"
	icon_state = "wood_crate"
	icon_opened = "wood_crate_opened"
	icon_closed = "wood_crate"
	paths = list(/obj/item/weapon/grenade/modern/f1 = 10)

obj/structure/closet/crate/ww1/grenades_german
	name = "stg 1915 grenade crate"
	icon_state = "wood_crate"
	icon_opened = "wood_crate_opened"
	icon_closed = "wood_crate"
	paths = list(/obj/item/weapon/grenade/modern/stg1915 = 10)

obj/structure/closet/crate/ww1/grenades_british
	name = "Mills grenade crate"
	icon_state = "wood_crate"
	icon_opened = "wood_crate_opened"
	icon_closed = "wood_crate"
	paths = list(/obj/item/weapon/grenade/modern/mills = 10)


obj/structure/closet/crate/ww1/ammo_hotchkiss
	name = "Hotchkiss belts crate"
	icon_state = "wood_crate"
	icon_opened = "wood_crate_opened"
	icon_closed = "wood_crate"
	paths = list(/obj/item/ammo_magazine/hotchkiss = 3)

obj/structure/closet/crate/ww1/ammo_type3
	name = "Type 3 belts crate"
	icon_state = "wood_crate"
	icon_opened = "wood_crate_opened"
	icon_closed = "wood_crate"
	paths = list(/obj/item/ammo_magazine/type3 = 3)

obj/structure/closet/crate/ww1/ammo_vickers
	name = "Vickers belts crate"
	icon_state = "wood_crate"
	icon_opened = "wood_crate_opened"
	icon_closed = "wood_crate"
	paths = list(/obj/item/ammo_magazine/vickers = 3)

obj/structure/closet/crate/ww1/ammo_mg08
	name = "MG08 belts crate"
	icon_state = "wood_crate"
	icon_opened = "wood_crate_opened"
	icon_closed = "wood_crate"
	paths = list(/obj/item/ammo_magazine/mg08 = 3)
obj/structure/closet/crate/ww1/ammo_maxim
	name = "Maxim belts crate"
	icon_state = "wood_crate"
	icon_opened = "wood_crate_opened"
	icon_closed = "wood_crate"
	paths = list(/obj/item/ammo_magazine/maxim = 3)

obj/structure/closet/crate/ww2
	icon_state = "mil_crate_closed"
	icon_opened = "mil_crate_opened"
	icon_closed = "mil_crate_closed"
	name = "military crate"
obj/structure/closet/crate/ww2/mk2
	name = "Mk2 grenade crate"
	paths = list(/obj/item/weapon/grenade/ww2/mk2 = 10)

obj/structure/closet/crate/coldwar/m26
	name = "M26 grenade crate"
	paths = list(/obj/item/weapon/grenade/coldwar/m26 = 10)

obj/structure/closet/crate/ww2/artillery_shells
	name = "HE artillery shells"
	paths = list(/obj/item/cannon_ball/shell = 10)
#undef DYNAMIC_AMT
