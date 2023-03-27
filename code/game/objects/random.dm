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
	icon_state = "rup"
	var/spawn_nothing_percentage = 0 // This variable determines the likelyhood that this random object will not spawn anything

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
	..()
	pick(new /obj/random/gun/ak47(src),new /obj/random/gun/ak74(src))


/obj/random/gun/ak47
	name = "random ak47"
	icon_state = "ak_old"
/obj/random/gun/ak47/spawn_choices()
	return list(/obj/item/weapon/gun/projectile/submachinegun/ak47,
				/obj/item/weapon/gun/projectile/submachinegun/ak47/akms)

/obj/random/gun/ak74
	name = "random ak74"
	icon_state = "ak_old"
/obj/random/gun/ak74/spawn_choices()
	return list(/obj/item/weapon/gun/projectile/submachinegun/ak74,
				/obj/item/weapon/gun/projectile/submachinegun/ak74/aks74,
                /obj/item/weapon/gun/projectile/submachinegun/ak74/aks74/aks74u,
                /obj/item/weapon/gun/projectile/submachinegun/ak74m)

/obj/random/gun/ak_modern
	name = "random modern ak"
	icon_state = "ak_modern"
/obj/random/gun/ak_modern/spawn_choices()
	return list(/obj/item/weapon/gun/projectile/submachinegun/ak101,
				/obj/item/weapon/gun/projectile/submachinegun/ak101/ak102,
				/obj/item/weapon/gun/projectile/submachinegun/ak101/ak103/ak104,
				/obj/item/weapon/gun/projectile/submachinegun/ak101/ak105)


////////////////Magazines////////////////

/obj/random/magazine
	name = "DO NOT USE"
	icon_state = "dice"

/obj/random/magazine/ak47
    name = "random ak magazine"
    icon_state = "magazine"
/obj/random/magazine/ak47/spawn_choices()
	return list(/obj/item/ammo_magazine/ak47,
                /obj/item/ammo_magazine/ak47/drum)

/obj/random/magazine/ak74
    name = "random ak magazine"
    icon_state = "magazine"
/obj/random/magazine/ak74/spawn_choices()
	return list(/obj/item/ammo_magazine/ak74,
                /obj/item/ammo_magazine/ak74/drum)

		
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
	return list(/obj/item/stack/medical/advanced/sulfa/small = rand(1,2),
                /obj/item/stack/medical/advanced/herbs/small = rand(1,3),
                /obj/item/stack/medical/bruise_pack/bint/small = rand(1,2))

/obj/random/medical/drugs
	name = "Medical Drugs"
	icon_state = "drug"
	spawn_nothing_percentage = 18
/obj/random/medical/drugs/spawn_choices()
	return list(/obj/item/weapon/reagent_containers/syringe/morphine,
				/obj/item/weapon/reagent_containers/syringe/morphine,
				/obj/item/weapon/reagent_containers/syringe/morphine,
                /obj/item/weapon/reagent_containers/syringe/adrenaline,
				/obj/item/weapon/reagent_containers/syringe/adrenaline,
				/obj/item/weapon/reagent_containers/syringe/adrenaline,
                /obj/item/weapon/reagent_containers/syringe/thc)

////////////////Barricades, Mines & Trees////////////////
/obj/random/mine/ap
	name = "Anti Personnel Mine"
	icon_state = "mine"
	spawn_nothing_percentage = 70
/obj/random/mine/ap/spawn_choices()
	return list(/obj/item/mine/ap/armed)

/obj/random/mine/booby
	name = "Anti Personnel Mine"
	icon_state = "mine"
	spawn_nothing_percentage = 70
/obj/random/mine/booby/spawn_choices()
	return list(/obj/item/mine/boobytrap)

/obj/random/barricade/random
	name = "Random Barricade"
	icon_state = "barricade"
	spawn_nothing_percentage = 50
/obj/random/barricade/random/spawn_choices()
	return list(/obj/structure/barricade/antitank,
				/obj/structure/barricade/horizontal,
				/obj/structure/barricade/vertical)

/obj/random/plants/tree
	name = "Tree"
	icon_state = "tree"
	spawn_nothing_percentage = 15
/obj/random/plants/tree/spawn_choices()
	return list(/obj/structure/wild/tree/live_tree,
				/obj/structure/wild/tallgrass,
				/obj/structure/wild/rock,
				/obj/structure/wild/rock/basalt,
				/obj/structure/wild/tree_stump,
				/obj/structure/wild/bush,
				/obj/structure/wild/smallbush,
				/obj/structure/wild/tallgrass)

/obj/random/plants/tree_lowchance
	name = "Tree"
	icon_state = "tree"
	spawn_nothing_percentage = 75
/obj/random/plants/tree/spawn_choices()
	return list(/obj/structure/wild/tree/live_tree,
				/obj/structure/wild/tallgrass,
				/obj/structure/wild/rock,
				/obj/structure/wild/rock/basalt,
				/obj/structure/wild/tree_stump,
				/obj/structure/wild/bush,
				/obj/structure/wild/smallbush,
				/obj/structure/wild/tallgrass)

/obj/random/plants/tree_snow
	name = "Snowy Tree"
	icon_state = "tree"
	spawn_nothing_percentage = 15
/obj/random/plants/snow/spawn_choices()
	return list(/obj/structure/wild/tree/live_tree/snow,
				/obj/structure/wild/rock,
				/obj/structure/wild/rock/basalt,
				/obj/structure/wild/tree_stump,
				/obj/structure/wild/smallbush/winter)

/obj/random/plants/tree_snow_lowchance
	name = "Snowy Tree"
	icon_state = "tree"
	spawn_nothing_percentage = 15
/obj/random/plants/snow/spawn_choices()
	return list(/obj/structure/wild/tree/live_tree/snow,
				/obj/structure/wild/rock,
				/obj/structure/wild/rock/basalt,
				/obj/structure/wild/tree_stump,
				/obj/structure/wild/smallbush/winter)

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
	stashed = list(	/obj/item/weapon/gun/projectile/submachinegun/sten,
					/obj/item/ammo_magazine/sten2 = 2)
/obj/item/weapon/hiddenstash/mp40
	stashed = list(	/obj/item/weapon/gun/projectile/submachinegun/mp40,
					/obj/item/ammo_magazine/mp40 = 2)
/obj/item/weapon/hiddenstash/grenade
	stashed = list(	/obj/item/weapon/grenade/modern/custom)
/obj/item/weapon/hiddenstash/makarov
	stashed = list(	/obj/item/weapon/gun/projectile/pistol/makarov,
					/obj/item/ammo_magazine/makarov = 3)
/obj/item/weapon/hiddenstash/luger
	stashed = list(	/obj/item/weapon/gun/projectile/pistol/luger,
					/obj/item/ammo_magazine/luger = 3)
