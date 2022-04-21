/obj/item/gunbox
	name = "equipment kit"
	desc = "A secure box containing your sidearm."
	icon = 'icons/obj/storage.dmi'
	icon_state = "ammo_can" //temp
	flags = CONDUCT

/obj/item/gunbox/attack_self(mob/living/user)
	var/list/options = list()
	options["Colt Police - revolver"] = list(/obj/item/weapon/gun/projectile/revolver/coltpolicepositive,/obj/item/ammo_magazine/c32,/obj/item/ammo_magazine/c32,/obj/item/ammo_magazine/c32)
	options["Glock 17 - pistol"] = list(/obj/item/weapon/gun/projectile/pistol/glock17,/obj/item/ammo_magazine/glock17,/obj/item/ammo_magazine/glock17,/obj/item/ammo_magazine/glock17)
	options["Peace maker - revolver"] = list(/obj/item/weapon/gun/projectile/revolver/frontier,/obj/item/ammo_magazine/c44,/obj/item/ammo_magazine/c44,/obj/item/ammo_magazine/c44)
	options["Beretta m9 - pistol"] = list(/obj/item/weapon/gun/projectile/pistol/m9beretta,/obj/item/ammo_magazine/m9beretta,/obj/item/ammo_magazine/m9beretta,/obj/item/ammo_magazine/m9beretta)
	options["TT-30ll - less than lethal pistol"] = list(/obj/item/weapon/gun/projectile/pistol/tt30ll,/obj/item/projectile/bullet/pistol/rubber,/obj/item/projectile/bullet/pistol/rubber,/obj/item/projectile/bullet/pistol/rubber)
	var/choice = input(user,"What type of equipment?") as null|anything in options
	if(src && choice)
		var/list/things_to_spawn = options[choice]
		for(var/new_type in things_to_spawn)
			var/atom/movable/AM = new new_type(get_turf(src))
			if(istype(AM, /obj/item/weapon/gun/))
				to_chat(user, "You have chosen \the [AM]. This is probably worth more than what your paycheck can be used for.")
		qdel(src)
