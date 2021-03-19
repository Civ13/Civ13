/obj/item/gunbox
	name = "equipment kit"
	desc = "A secure box containing your equipment."
	icon = 'icons/obj/storage.dmi'
	icon_state = "ammo_can" //temp

/obj/item/gunbox/attack_self(mob/living/user)
	var/list/options = list()
	options["Warden - CQC"] = list(/obj/item/weapon/gun/projectile/shotgun/spas,/obj/item/clothing/under/pmc)
	options["Scout - Long range"] = list(/obj/item/clothing/under/tactical1,/obj/item/weapon/gun/projectile/semiautomatic/svd,/obj/item/ammo_magazine/svd,/obj/item/ammo_magazine/svd,/obj/item/ammo_magazine/svd,/obj/item/weapon/attachment/scope/adjustable/binoculars)
	options["Swat - Tactical"] = list(/obj/item/clothing/under/tactical1,/obj/item/clothing/suit/swat,/obj/item/weapon/gun/projectile/submachinegun/m16,/obj/item/ammo_magazine/m16,/obj/item/ammo_magazine/m16,/obj/item/ammo_magazine/m16)
	var/choice = input(user,"What type of equipment?") as null|anything in options
	if(src && choice)
		var/list/things_to_spawn = options[choice]
		for(var/new_type in things_to_spawn)
			var/atom/movable/AM = new new_type(get_turf(src))
			if(istype(AM, /obj/item/weapon/gun/))
				to_chat(user, "You have chosen \the [AM]. This is probably worth more than what your paycheck can be used for.")
		qdel(src)