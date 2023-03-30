/obj/item/gunbox
	name = "equipment kit"
	desc = "A secure box containing your sidearm."
	icon = 'icons/obj/storage.dmi'
	icon_state = "ammo_can" //temp
	flags = CONDUCT

/obj/item/gunbox/police
	name = "equipment kit"
	desc = "A secure box containing your sidearm."
	icon = 'icons/obj/storage.dmi'
	icon_state = "ammo_can" //temp

/obj/item/gunbox/police/attack_self(mob/living/human/user as mob)
	var/list/options = list()
	options["Colt Police - revolver"] = list(/obj/item/weapon/gun/projectile/revolver/coltpolicepositive,/obj/item/ammo_magazine/c32,/obj/item/ammo_magazine/c32,/obj/item/ammo_magazine/c32)
	options["Glock 17 - pistol"] = list(/obj/item/weapon/gun/projectile/pistol/glock17,/obj/item/ammo_magazine/glock17,/obj/item/ammo_magazine/glock17,/obj/item/ammo_magazine/glock17)
	options["Peace maker - revolver"] = list(/obj/item/weapon/gun/projectile/revolver/frontier,/obj/item/ammo_magazine/c44,/obj/item/ammo_magazine/c44,/obj/item/ammo_magazine/c44)
	options["Beretta m9 - pistol"] = list(/obj/item/weapon/gun/projectile/pistol/m9beretta,/obj/item/ammo_magazine/m9beretta,/obj/item/ammo_magazine/m9beretta,/obj/item/ammo_magazine/m9beretta)
	options["TT-30 - less than lethal pistol"] = list(/obj/item/weapon/gun/projectile/pistol/tt30,/obj/item/ammo_magazine/tt30ll/rubber,/obj/item/ammo_magazine/tt30ll/rubber,/obj/item/ammo_magazine/tt30ll/rubber)
	var/choice = input(user,"What type of equipment?") as null|anything in options
	if(src && choice)
		var/list/things_to_spawn = options[choice]
		for(var/new_type in things_to_spawn)
			new new_type(get_turf(src))
		qdel(src)

/obj/item/gunbox/emplacement
	name = "equipment kit"
	desc = "A secure box containing your emplacement choice."
	icon = 'icons/obj/storage.dmi'
	icon_state = "ammo_can" //temp
	flags = CONDUCT

/obj/item/gunbox/emplacement/attack_self(mob/living/human/user as mob)
	var/list/options = list()
	switch (user.faction_text)
		if ("DUTCH")
			options["Foldable Anti-Tank Guide Missile system"] = list(/obj/item/weapon/foldable/atgm,/obj/item/weapon/storage/backpack/heavyrucksack)
			options["Foldable Mortar"] = list(/obj/item/weapon/foldable/generic,/obj/item/weapon/storage/backpack/heavyrucksack,/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars)
		if ("RUSSIAN")
			options["Foldable Anti-Tank Guide Missile system"] = list(/obj/item/weapon/foldable/atgm,/obj/item/weapon/storage/backpack/heavyrucksack)
			options["Foldable Mortar"] = list(/obj/item/weapon/foldable/generic,/obj/item/weapon/storage/backpack/heavyrucksack,/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars)
			options["Foldable PKM"] = list(/obj/item/weapon/foldable/pkm,/obj/item/ammo_magazine/pkm,/obj/item/ammo_magazine/pkm)
	var/choice = input(user,"What type of equipment?") as null|anything in options
	if(src && choice)
		var/list/things_to_spawn = options[choice]
		for(var/new_type in things_to_spawn)
			new new_type(get_turf(src))
		qdel(src)

/obj/item/gunbox/specialist
	name = "equipment kit"
	desc = "A secure box containing your specalist choice."
	icon = 'icons/obj/storage.dmi'
	icon_state = "ammo_can" //temp
	flags = CONDUCT

/obj/item/gunbox/specialist/attack_self(mob/living/human/user as mob)
	var/list/options = list()
	switch (user.faction_text)
		if ("DUTCH")
			options["Sniper"] = list(/obj/item/weapon/gun/projectile/boltaction/singleshot/barrett/sniper,/obj/item/ammo_magazine/a50cal,/obj/item/ammo_magazine/a50cal)
			options["Anti-Tank"] = list(/obj/item/weapon/gun/launcher/rocket/single_shot/m72law,/obj/item/weapon/gun/launcher/rocket/single_shot/m72law)
			options["Breacher"] = list(/obj/item/weapon/gun/projectile/shotgun/pump/remington870,/obj/item/ammo_magazine/shellbox,/obj/item/ammo_magazine/shellbox,/obj/item/ammo_magazine/shellbox)
			options["Grenadier"] = list(/obj/item/weapon/gun/launcher/grenade/standalone/hk69,/obj/item/clothing/accessory/storage/webbing/shell40mm)
		if ("RUSSIAN")
			options["Sniper"] = list(/obj/item/weapon/gun/projectile/semiautomatic/vintorez,/obj/item/ammo_magazine/vintorez,/obj/item/ammo_magazine/vintorez)
			options["Anti-Tank"] = list(/obj/item/weapon/gun/launcher/rocket/single_shot/rpg22,/obj/item/weapon/gun/launcher/rocket/single_shot/rpg22)
			options["Breacher"] = list(/obj/item/weapon/gun/projectile/submachinegun/saiga12,/obj/item/ammo_magazine/saiga12,/obj/item/ammo_magazine/saiga12,/obj/item/ammo_magazine/saiga12)
	var/choice = input(user,"What type of equipment?") as null|anything in options
	if(src && choice)
		var/list/things_to_spawn = options[choice]
		for(var/new_type in things_to_spawn)
			new new_type(get_turf(src))
		qdel(src)
