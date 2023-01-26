/obj/item/gunbox
	name = "equipment kit"
	desc = "A secure box containing your sidearm."
	icon = 'icons/obj/storage.dmi'
	icon_state = "ammo_can" //temp
	flags = CONDUCT
	var/list/options = list()

/obj/item/gunbox/attack_self(mob/living/human/user as mob)
	var/choice = input(user,"What type of equipment?") as null|anything in options
	if(src && choice)
		var/list/things_to_spawn = options[choice]
		for(var/new_type in things_to_spawn)
			new new_type(get_turf(src))
		qdel(src)

/obj/item/gunbox/police
	name = "equipment kit"
	desc = "A secure box containing your sidearm."
	icon = 'icons/obj/storage.dmi'
	icon_state = "ammo_can" //temp

/obj/item/gunbox/police/attack_self(mob/living/human/user as mob)
	options["Colt Police - revolver"] = list(/obj/item/weapon/gun/projectile/revolver/coltpolicepositive,/obj/item/ammo_magazine/c32,/obj/item/ammo_magazine/c32,/obj/item/ammo_magazine/c32)
	options["Glock 17 - pistol"] = list(/obj/item/weapon/gun/projectile/pistol/glock17,/obj/item/ammo_magazine/glock17,/obj/item/ammo_magazine/glock17,/obj/item/ammo_magazine/glock17)
	options["Peace maker - revolver"] = list(/obj/item/weapon/gun/projectile/revolver/frontier,/obj/item/ammo_magazine/c44,/obj/item/ammo_magazine/c44,/obj/item/ammo_magazine/c44)
	options["Beretta m9 - pistol"] = list(/obj/item/weapon/gun/projectile/pistol/m9beretta,/obj/item/ammo_magazine/m9beretta,/obj/item/ammo_magazine/m9beretta,/obj/item/ammo_magazine/m9beretta)
	options["TT-30 - less than lethal pistol"] = list(/obj/item/weapon/gun/projectile/pistol/tt30,/obj/item/ammo_magazine/tt30ll/rubber,/obj/item/ammo_magazine/tt30ll/rubber,/obj/item/ammo_magazine/tt30ll/rubber)

/obj/item/gunbox/emplacement
	name = "equipment kit"
	desc = "A secure box containing your emplacement choice."
	icon = 'icons/obj/storage.dmi'
	icon_state = "ammo_can" //temp
	flags = CONDUCT

/obj/item/gunbox/emplacement/attack_self(mob/living/human/user as mob)
	options["Foldable Anti-Tank Guide Missile system"] = list(/obj/item/weapon/foldable/atgm,/obj/item/weapon/storage/backpack/heavyrucksack)
	options["Foldable Mortar"] = list(/obj/item/weapon/foldable/generic,/obj/item/weapon/storage/backpack/heavyrucksack)

/obj/item/gunbox/specialist
	name = "equipment kit"
	desc = "A secure box containing your specalist choice."
	icon = 'icons/obj/storage.dmi'
	icon_state = "ammo_can" //temp
	flags = CONDUCT

/obj/item/gunbox/specialist/attack_self(mob/living/human/user as mob)
	switch (user.faction_text)
		if ("DUTCH")
			options["Sniper"] = list(/obj/item/weapon/gun/projectile/boltaction/singleshot/a50cal,/obj/item/ammo_magazine/a50cal,/obj/item/ammo_magazine/a50cal)
			options["Anti-Tank"] = list(/obj/item/weapon/gun/launcher/rocket/m72law)
			options["Breacher"] = list(/obj/item/weapon/gun/projectile/shotgun/pump/remington870,/obj/item/ammo_magazine/shellbox,/obj/item/ammo_magazine/shellbox,/obj/item/ammo_magazine/shellbox)
		if ("RUSSIAN")
			options["Sniper"] = list(/obj/item/weapon/gun/projectile/semiautomatic/vintorez,/obj/item/ammo_magazine/vintorez,/obj/item/ammo_magazine/vintorez)
			options["Anti-Tank"] = list(/obj/item/weapon/gun/launcher/rocket/rpg7,/obj/item/missile/explosive)
			options["Breacher"] = list(/obj/item/weapon/gun/projectile/submachinegun/saiga12,/obj/item/ammo_magazine/saiga12,/obj/item/ammo_magazine/saiga12,/obj/item/ammo_magazine/saiga12)
			
