/*
A little documentation of the mess I've made here :D --Bierkraan 2022

You can spawn a random object of your desire, just return it in the proc spawn_choises().
Because we're calling all /obj/random on spawn and not on Initialize you can spawn in a /random in the middle of a round and get an object, though this might lag out the round on roundstart (untill someone finds a better solution).
Example for later use:

/obj/random/myItems
	name = "gun or health kit"
	desc "Nobody will EVER read this exept a curious mapper"
	icon = 'icons/misc/mark.dmi'
	icon_state = "dice"
	spawn_nothing_percentage = 0 // This variable determines the likelyhood that this random object will not spawn anything

/obj/random/myItems/spawn_choices()
	return list(/obj/item/weapon/gun/myverycoolgun,
				/obj/item/stack/medical/myveryhealthykit)
*/

/obj/random
	name = "random object"
	desc = "This item type is used to spawn random objects at round-start."
	icon = 'icons/misc/mark.dmi' // This is where all the /random icons are located
	icon_state = "dice"
	var/spawn_nothing_percentage = 0 // This variable determines the likelyhood that this random object will not spawn anything
	var/number_to_spawn = 1

	var/spawn_method = /obj/random/proc/spawn_item

// Creates a new object and deletes itself
/obj/random/New()
	..()
	call(src, spawn_method)()
	qdel(src)

// Creates the random item
/obj/random/proc/spawn_item()
	if(prob(spawn_nothing_percentage))
		return
    
	if(isnull(loc))
		return

	var/build_path = pickweight(spawn_choices())
	if (build_path)
		for (var/i = 1, i <= number_to_spawn, i++)
		var/atom/A = new build_path(src.loc)
		if(pixel_x || pixel_y)
			A.pixel_x = pixel_x
			A.pixel_y = pixel_y

// Returns an associative list in format path:weight
/obj/random/proc/spawn_choices()
	return list()

/obj/random/single
	name = "randomly spawned object"
	desc = "This item type is used to randomly spawn a given object at round-start."
	icon_state = "x3"
	var/spawn_object = null

/obj/random/single/spawn_choices()
	return list(ispath(spawn_object) ? spawn_object : text2path(spawn_object))


////////////////Guns////////////////

/obj/random/gun
	name = "DO NOT USE"
	icon_state = "dice"

/obj/random/gun/random_ak
	name = "random ak"
	icon_state = "ak_old"
/obj/random/gun/random_ak/New()
	pick(new /obj/random/gun/ak47(src),new /obj/random/gun/ak74(src))
	qdel(src)

/obj/random/gun/ak47
	name = "random ak47"
	icon_state = "ak_old"
/obj/random/gun/ak47/spawn_choices()
	return list(
				/obj/item/weapon/gun/projectile/submachinegun/ak47 = 50,
				/obj/item/weapon/gun/projectile/submachinegun/ak47/akms = 50)

/obj/random/gun/ak74
	name = "random ak74"
	icon_state = "ak_old"
/obj/random/gun/ak74/spawn_choices()
	return list(
				/obj/item/weapon/gun/projectile/submachinegun/ak74 = 25,
				/obj/item/weapon/gun/projectile/submachinegun/ak74/aks74 = 25,
                /obj/item/weapon/gun/projectile/submachinegun/ak74/aks74/aks74u = 25,
                /obj/item/weapon/gun/projectile/submachinegun/ak74m = 25)

/obj/random/gun/ak_modern
	name = "random modern ak"
	icon_state = "ak_modern"
/obj/random/gun/ak_modern/spawn_choices()
	return list(
				/obj/item/weapon/gun/projectile/submachinegun/ak101 = 25,
				/obj/item/weapon/gun/projectile/submachinegun/ak101/ak102 = 25,
				/obj/item/weapon/gun/projectile/submachinegun/ak101/ak103/ak104 = 25,
				/obj/item/weapon/gun/projectile/submachinegun/ak101/ak105 = 25)

/obj/random/gun/western_random
	name = "random western"
	icon_state = "western"
/obj/random/gun/western_random/spawn_choices()
	return list(
				/obj/item/weapon/gun/projectile/submachinegun/m16 = 20,
				/obj/item/weapon/gun/projectile/submachinegun/scarl = 20,
				/obj/item/weapon/gun/projectile/submachinegun/c7 = 10,
				/obj/item/weapon/gun/projectile/submachinegun/c7/c8 = 5,
				/obj/item/weapon/gun/projectile/submachinegun/l85a2 = 15,
				/obj/item/weapon/gun/projectile/submachinegun/aug = 15,
				/obj/item/weapon/gun/projectile/submachinegun/g3 = 20,
				/obj/item/weapon/gun/projectile/submachinegun/mp40/mp5 = 15,
				/obj/item/weapon/gun/projectile/submachinegun/p90 = 10)

/obj/random/gun/german_random
	name = "random german"
	icon_state = "german"
/obj/random/gun/german_random/spawn_choices()
	return list(
				/obj/item/weapon/gun/projectile/boltaction/gewehr98 = 30,
				/obj/item/weapon/gun/projectile/semiautomatic/g43 = 30,
				/obj/item/weapon/gun/projectile/submachinegun/mp40 = 30,
				/obj/item/weapon/grenade/ww2/stg1924 = 10)

/obj/random/gun/funny_random
	name = "random funny"
	icon_state = "funny"
	spawn_nothing_percentage = 75
/obj/random/gun/german_random/spawn_choices()
	return list(
				/obj/item/weapon/gun/launcher/rocket/fatman/loaded = 15,
				/obj/structure/payload/bomb/kg250 = 5,
				/obj/item/weapon/grenade/modern/impact/rgo = 40,
				/obj/item/weapon/grenade/suicide_vest = 20,
				/obj/item/weapon/grenade/chemical/chlorine = 20)

////////////////Magazines////////////////

/obj/random/magazine
	name = "DO NOT USE"
	icon_state = "dice"

/obj/random/magazine/ak47
    name = "random ak magazine"
    icon_state = "magazine"
/obj/random/magazine/ak47/spawn_choices()
	return list(
				/obj/item/ammo_magazine/ak47 = 95,
                /obj/item/ammo_magazine/ak47/drum = 5)

/obj/random/magazine/ak74
    name = "random ak magazine"
    icon_state = "magazine"
/obj/random/magazine/ak74/spawn_choices()
	return list(
				/obj/item/ammo_magazine/ak74 = 95,
                /obj/item/ammo_magazine/ak74/drum = 5)

/obj/random/magazine/western_random
	name = "random western magazine"
	icon_state = "magazine"
/obj/random/magazine/western_random/spawn_choices()
	return list(
				/obj/item/ammo_magazine/m16 = 50,
				/obj/item/ammo_magazine/hk = 15,
				/obj/item/ammo_magazine/mp40/mp5 = 20,
				/obj/item/ammo_magazine/p90 = 15)

/obj/random/magazine/german
    name = "random german magazine"
    icon_state = "magazine"
/obj/random/magazine/german/spawn_choices()
	return list(
				/obj/item/ammo_magazine/gewehr98 = 90,
                /obj/item/ammo_magazine/fg42 = 10,
				/obj/item/ammo_magazine/g43 = 10)

////////////////////////////

/obj/random/explosives
	name = "random melee weapon"
	icon_state = "explosives"
/obj/random/explosives/spawn_choices()
	return list(
				/obj/item/weapon/grenade/dynamite/ready= 1,
				/obj/item/weapon/grenade/flashbang/m84= 1,
				/obj/item/weapon/grenade/incendiary/anm14= 1,
				/obj/item/weapon/grenade/coldwar/m67= 1,
				/obj/item/weapon/grenade/ww2/stg1924 = 1,
				/obj/item/weapon/gun/launcher/rocket/single_shot/panzerfaust = 1,
				/obj/item/weapon/gun/launcher/rocket/single_shot/rpg22 = 1,
				/obj/item/weapon/gun/launcher/rocket/single_shot/m72law = 1)

/obj/random/melee
	name = "random melee weapon"
	icon_state = "melee"
/obj/random/melee/spawn_choices()
	return list(
				/obj/item/weapon/attachment/bayonet = 1,
				/obj/item/weapon/material/sword/gladius/iron = 1,
				/obj/item/weapon/material/sword/armingsword = 1,
				/obj/item/weapon/material/sword/katana = 1,
				/obj/item/weapon/material/sword/sabre = 1,
				/obj/item/weapon/material/hatchet/battleaxe = 1,
				/obj/item/weapon/melee/classic_baton = 1)

/obj/random/armor
	name = "random armor"
	icon_state = "armor"
	number_to_spawn = 2
/obj/random/armor/spawn_choices()
	return list(
				/obj/item/clothing/accessory/armor/coldwar/flakjacket = 1,
				/obj/item/clothing/accessory/armor/coldwar/pasgt = 1,
				/obj/item/clothing/accessory/armor/coldwar/plates/b45 = 1,
				/obj/item/clothing/accessory/armor/coldwar/plates/b45/ext = 1,
				/obj/item/clothing/head/helmet/modern/m95_dpm = 1,
				/obj/item/clothing/head/helmet/modern/pasgt = 1,
				/obj/item/clothing/head/helmet/modern/ushelmet = 1,
				/obj/item/clothing/head/helmet/modern/brodie = 1,
				/obj/item/clothing/head/helmet/modern/stahlhelm = 1,
				/obj/item/clothing/head/helmet/kevlarhelmet/press = 1)

/obj/random/accessories
	name = "random accessories"
	icon_state = "accessories"
	number_to_spawn = 2
/obj/random/accessories/spawn_choices()
	return list(
				/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars = 1,
				/obj/item/clothing/accessory/storage/webbing/light = 1,
				/obj/item/clothing/accessory/storage/webbing/largepouchestan = 1,
				/obj/item/clothing/accessory/storage/webbing/green_webbing = 1,
				/obj/item/clothing/accessory/storage/webbing/us_vest = 1,
				/obj/item/clothing/accessory/storage/webbing/ww1/british = 1,
				/obj/item/weapon/storage/belt/leather = 1,
				/obj/item/weapon/storage/belt/medical/full_us = 1,
				/obj/item/weapon/storage/belt/tactical = 1,
				/obj/item/weapon/storage/backpack/civbag = 1,
				/obj/item/weapon/storage/backpack/rucksack = 1,
				/obj/item/weapon/storage/backpack/scavpack = 1,
				/obj/item/weapon/storage/backpack/ww2/jap = 1,
				/obj/item/clothing/mask/gas/modern2 = 1,
				/obj/item/clothing/mask/gas/military = 1,
				/obj/item/clothing/glasses/nvg = 1,
				/obj/item/weapon/pill_pack/pervitin = 1)

////////////////Medical////////////////
/obj/item/weapon/storage/eft/medical
	name = "medical bag"
	desc = "Probably contains basic medical treatments."
	icon_state = "medical_bag"
	item_state = "medical_bag"
	anchored = TRUE
/obj/item/weapon/storage/eft/medical/New()
	..()
	if(prob(80))
		new /obj/random/medical/bandage(src)
		if(prob(50))
			new /obj/random/medical/bandage(src)
	if(prob(60))
		new /obj/random/medical/drugs(src)

/obj/random/medical
	name = "Medical Supplies"
	icon_state = "medical"

/obj/random/medical/bandage
	name = "Medical Bandages"
	icon_state = "bandage"
	spawn_nothing_percentage = 10
/obj/random/medical/bandage/spawn_choices()
	return list(
				/obj/item/stack/medical/advanced/sulfa/small = 1,
                /obj/item/stack/medical/advanced/herbs/small = 1,
                /obj/item/stack/medical/bruise_pack/bint/small = 1)

/obj/random/medical/drugs
	name = "Medical Drugs"
	icon_state = "drug"
	spawn_nothing_percentage = 18
/obj/random/medical/drugs/spawn_choices()
	return list(
				/obj/item/weapon/reagent_containers/syringe/morphine = 1,
                /obj/item/weapon/reagent_containers/syringe/thc = 1)

////////////////Barricades, Mines & Trees////////////////
/obj/random/mine/ap
	name = "Anti Personnel Mine"
	icon_state = "mine"
	spawn_nothing_percentage = 70
/obj/random/mine/ap/spawn_choices()
	return list(
				/obj/item/mine/ap/armed = 1)

/obj/random/mine/booby
	name = "Anti Personnel Mine"
	icon_state = "mine"
	spawn_nothing_percentage = 70
/obj/random/mine/booby/spawn_choices()
	return list(
				/obj/item/mine/boobytrap = 1)

/obj/random/barricade/random
	name = "Random Barricade"
	icon_state = "barricade"
	spawn_nothing_percentage = 50
/obj/random/barricade/random/spawn_choices()
	return list(
				/obj/structure/barricade/antitank = 1,
				/obj/structure/barricade/horizontal = 1,
				/obj/structure/barricade/vertical = 1)

/obj/random/plants/tree
	name = "Tree"
	icon_state = "tree"
	spawn_nothing_percentage = 15
/obj/random/plants/tree/spawn_choices()
	return list(
				/obj/structure/wild/tree/live_tree = 1,
				/obj/structure/wild/tallgrass = 1,
				/obj/structure/wild/rock = 1,
				/obj/structure/wild/rock/basalt,
				/obj/structure/wild/tree_stump = 1,
				/obj/structure/wild/bush = 1,
				/obj/structure/wild/smallbush = 1,
				/obj/structure/wild/tallgrass = 1)

/obj/random/plants/tree_lowchance
	name = "Tree"
	icon_state = "tree"
	spawn_nothing_percentage = 75
/obj/random/plants/tree_lowchance/spawn_choices()
	return list(
				/obj/structure/wild/tree/live_tree = 1,
				/obj/structure/wild/tallgrass = 1,
				/obj/structure/wild/rock = 1,
				/obj/structure/wild/rock/basalt = 1,
				/obj/structure/wild/tree_stump = 1,
				/obj/structure/wild/bush = 1,
				/obj/structure/wild/smallbush = 1,
				/obj/structure/wild/tallgrass = 1)

/obj/random/plants/tree_snow
	name = "Snowy Tree"
	icon_state = "tree"
	spawn_nothing_percentage = 15
/obj/random/plants/snow/spawn_choices()
	return list(
				/obj/structure/wild/tree/live_tree/snow = 1,
				/obj/structure/wild/rock = 1,
				/obj/structure/wild/rock/basalt = 1,
				/obj/structure/wild/tree_stump = 1,
				/obj/structure/wild/smallbush/winter = 1)

/obj/random/plants/tree_snow_lowchance
	name = "Snowy Tree"
	icon_state = "tree"
	spawn_nothing_percentage = 15
/obj/random/plants/snow/spawn_choices()
	return list(
				/obj/structure/wild/tree/live_tree/snow = 1,
				/obj/structure/wild/rock = 1,
				/obj/structure/wild/rock/basalt = 1,
				/obj/structure/wild/tree_stump = 1,
				/obj/structure/wild/smallbush/winter = 1)

/obj/item/weapon/hiddenstash
	name = "Hidden Stach"
	desc = "Ooooh what could be inside??? If you see this report it to a developer"
	icon = 'icons/misc/mark.dmi'
	icon_state = "dice"
	w_class = ITEM_SIZE_SMALL
	var/stashed = list()

/obj/item/weapon/hiddenstash/New()
	..()
	var/rand_object = rand(1,4)
	switch (rand_object)
		if (1)
			name = "newspaper"
			desc = "An issue of a local Newspaper. It looks a bit off..."
			icon = 'icons/obj/bureaucracy.dmi'
			icon_state = "newspaper"
		if (2)
			name = "toolbox"
			desc = "Danger. Very robust. It looks a bit off..."
			icon = 'icons/obj/storage.dmi'
			icon_state = "toolbox_red"
			item_state = "toolbox_red"
		if (3)
			name = "briefcase"
			desc = "It's made of AUTHENTIC faux-leather and has a price-tag still attached. Its owner must be a real professional. It looks a bit off..."
			icon = 'icons/obj/storage.dmi'
			icon_state = "briefcase"
			item_state = "briefcase"
		if (4)
			name = "package"
			desc = "Some kind of package..."
			icon = 'icons/obj/bureaucracy.dmi'
			icon_state = "deliverypackage"
			item_state = "deliverypackage"

/obj/item/weapon/hiddenstash/attack_self()
	var/build_path = pickweight(stashed)
	new build_path(src.loc)

/obj/item/weapon/hiddenstash/sten
	stashed = list(
					/obj/item/weapon/gun/projectile/submachinegun/sten,
					/obj/item/ammo_magazine/sten2 = 2)
/obj/item/weapon/hiddenstash/mp40
	stashed = list(
					/obj/item/weapon/gun/projectile/submachinegun/mp40,
					/obj/item/ammo_magazine/mp40 = 2)
/obj/item/weapon/hiddenstash/grenade
	stashed = list(	
					/obj/item/weapon/grenade/modern/custom)
/obj/item/weapon/hiddenstash/makarov
	stashed = list(	
					/obj/item/weapon/gun/projectile/pistol/makarov,
					/obj/item/ammo_magazine/makarov = 3)
/obj/item/weapon/hiddenstash/luger
	stashed = list(	
					/obj/item/weapon/gun/projectile/pistol/luger,
					/obj/item/ammo_magazine/luger = 3)
