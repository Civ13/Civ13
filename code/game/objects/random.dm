/obj/random
	name = "random object"
	desc = "This item type is used to spawn random objects at round-start."
	icon = 'icons/misc/mark.dmi'
	icon_state = "rup"
	var/spawn_nothing_percentage = 0 // this variable determines the likelyhood that this random object will not spawn anything

	var/spawn_method = /obj/random/proc/spawn_item

// creates a new object and deletes itself
/obj/random/initialize()
	..()
	call(src, spawn_method)()
	qdel(src)

// creates the random item
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
	desc = "This is a random gun."
	icon_state = "dice"
/*
/obj/random/gun/random_ak
	name = "random ak"
	desc = "This is a random ak."
	icon_state = "dice"
	var/gun = pick(/obj/random/gun/ak47,/obj/random/gun/ak74,/obj/random/gun/ak_modern)
/obj/random/gun/random_ak/New()
*/

/obj/random/gun/ak47
	name = "random old ak"
	desc = "This is a random ak."
	icon_state = "ak_old"
/obj/random/gun/ak47/spawn_choices()
	return list(/obj/item/weapon/gun/projectile/submachinegun/ak47,
				/obj/item/weapon/gun/projectile/submachinegun/ak47/akms)

/obj/random/gun/ak74
	name = "random old ak"
	desc = "This is a random ak."
	icon_state = "ak_old"
/obj/random/gun/ak74/spawn_choices()
	return list(/obj/item/weapon/gun/projectile/submachinegun/ak74,
				/obj/item/weapon/gun/projectile/submachinegun/ak74/aks74,
                /obj/item/weapon/gun/projectile/submachinegun/ak74/aks74/aks74u,
                /obj/item/weapon/gun/projectile/submachinegun/ak74m)

/obj/random/gun/ak_modern
	name = "random modern ak"
	desc = "This is a random ak."
	icon_state = "ak_modern"
/obj/random/gun/ak_modern/spawn_choices()
	return list(/obj/item/weapon/gun/projectile/submachinegun/ak101,
				/obj/item/weapon/gun/projectile/submachinegun/ak101/ak102,
				/obj/item/weapon/gun/projectile/submachinegun/ak101/ak103/ak104,
				/obj/item/weapon/gun/projectile/submachinegun/ak101/ak105)


////////////////Magazines////////////////

/obj/random/magazine
	name = "DO NOT USE"
	desc = "This is a random magazine."
	icon_state = "dice"

/obj/random/magazine/ak47
    name = "random ak magazine"
    icon_state = "magazine"
/obj/random/magazine/ak47/spawn_choices()
	return list(/obj/item/ammo_magazine/ak47 = rand(1,3),
                /obj/item/ammo_magazine/ak47 = rand(1,2),
                /obj/item/ammo_magazine/ak47,
                /obj/item/ammo_magazine/ak47/drum)

/obj/random/magazine/ak74
    name = "random ak magazine"
    icon_state = "magazine"
/obj/random/magazine/ak74/spawn_choices()
	return list(/obj/item/ammo_magazine/ak74 = rand(1,3),
                /obj/item/ammo_magazine/ak74 = rand(1,2),
                /obj/item/ammo_magazine/ak74,
                /obj/item/ammo_magazine/ak74/drum)