//default dart
/obj/item/projectile/bullet/chemdart
	name = "dart"
	icon_state = "dart"
	damage = 5
	sharp = TRUE
	embed = TRUE //the dart is shot fast enough to pierce space suits, so I guess splintering inside the target can be a thing. Should be rare due to low damage.
	var/reagent_amount = 15
	kill_count = 15 //shorter range

	muzzle_type = null

/obj/item/projectile/bullet/chemdart/New()
	reagents = new/datum/reagents(reagent_amount)
	reagents.my_atom = src

/obj/item/projectile/bullet/chemdart/on_hit(var/atom/target, var/blocked = FALSE, var/def_zone = null)
	if(blocked < 2 && isliving(target))
		var/mob/living/L = target
		if(L.can_inject(target_zone=def_zone))
			reagents.trans_to_mob(L, reagent_amount, CHEM_BLOOD)


//bone dart
/obj/item/projectile/bullet/chemdart/bone
	name = "bone dart"
	icon_state = "bdart"
	damage = 2.5
	reagent_amount = 7

//DARTS WHAT HOLD CHEMICALS
/obj/item/ammo_casing/chemdart
	name = "chemical dart"
	desc = "A small hardened, hollow dart."
	icon_state = "dart"
	caliber = "dart"
	projectile_type = /obj/item/projectile/bullet/chemdart

/obj/item/ammo_casing/chemdart/expend()
	qdel(src)

/obj/item/ammo_casing/chemdart/bone
	name = "bone dart"
	desc = "A small hardened, hollow dart."
	icon_state = "bdart"
	projectile_type = /obj/item/projectile/bullet/chemdart/bone

//BASE FANCY DART GUN MAGAZINE
/obj/item/ammo_magazine/chemdart
	name = "dart cartridge"
	desc = "A rack of hollow darts."
	icon_state = "darts"
	item_state = "darts"
	mag_type = MAGAZINE
	caliber = "dart"
	ammo_type = /obj/item/ammo_casing/chemdart
	max_ammo = 10
	multiple_sprites = TRUE

/obj/item/ammo_magazine/chemdart/mag
	name = "dart magazine"
	desc = "A magazine of hollow darts."
	icon_state = "dartmag"
	item_state = "dartmag"
	mag_type = MAGAZINE
	caliber = "dart"
	ammo_type = /obj/item/ammo_casing/chemdart
	max_ammo = 5
	multiple_sprites = TRUE

//IMAGINARY DARTGUN BASE
/obj/item/weapon/gun/projectile/dartgun
	icon = 'icons/obj/guns/dartgun.dmi'
	var/base_icon = "blowgun"
	var/list/beakers = list() //All containers inside the gun.
	var/list/mixing = list() //Containers being used for mixing.
	var/max_beakers = 1
	var/dart_reagent_amount = 10
	var/container_type = /obj/item/weapon/reagent_containers
	var/list/starting_chems = null
	move_delay=2
	fire_delay=6
	burst=1
	max_shells = 1
	muzzle_flash = FALSE


//FANCY DART GUN
/obj/item/weapon/gun/projectile/dartgun/dartgun
	name = "dart gun"
	desc = "Zeng-Hu Pharmaceutical's entry into the arms market, the Z-H P Artemis is a gas-powered dart gun capable of delivering chemical cocktails swiftly across short distances."

	icon_state = "dartgun-empty"

	item_state = null
	base_icon = "dartgun-empty"
	w_class = ITEM_SIZE_LARGE
	load_method = SINGLE_CASING|MAGAZINE
	load_delay = 8
	slot_flags = SLOT_BELT
	ammo_type = /obj/item/ammo_casing/chemdart
	weight = 3
	force = 10
	throwforce = 20
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_SCOPE
	effectiveness_mod = 1.07
	caliber = "dart"
	fire_sound = 'sound/weapons/guns/interact/garandload.ogg'
	fire_sound_text = "a sharp metalic clack"
	recoil = FALSE
	magazine_type = /obj/item/ammo_magazine/chemdart
	auto_eject = FALSE
	gtype = "none"
	beakers = list() //All containers inside the gun.
	mixing = list() //Containers being used for mixing.
	max_beakers = 3
	dart_reagent_amount = 15
	container_type = /obj/item/weapon/reagent_containers/glass/beaker
	muzzle_flash = FALSE

/obj/item/weapon/gun/projectile/dartgun/New()
	..()
	if(starting_chems)
		for(var/chem in starting_chems)
			var/obj/B = new container_type(src)
			B.reagents.add_reagent(chem, 60)
			beakers += B
	update_icon()

/obj/item/weapon/gun/projectile/dartgun/dartgun/update_icon()
	icon_state = "dartgun-[ammo_magazine ? round(ammo_magazine.stored_ammo.len, 2) : "empty"]"


	//BLOWGUN
/obj/item/weapon/gun/projectile/dartgun/blowgun
	name = "blow gun"
	desc = "A bamboo tube used to spit single darts."
	icon_state = "blowgun"
	base_icon = "blowgun"
	item_state = "blowgun"
	w_class = ITEM_SIZE_NORMAL
	load_method = SINGLE_CASING
	load_delay = 4
	slot_flags = SLOT_BELT
	ammo_type = /obj/item/ammo_casing/chemdart
	weight = 0.9
	force = 3
	throwforce = 20
	effectiveness_mod = 1.07
	caliber = "dart"
	fire_sound = 'sound/weapons/guns/fire/Crossbow.ogg'
	fire_sound_text = "someone blowing through a tube"
	bulletinsert_sound = 'sound/items/matchstick_hit.ogg'
	recoil = FALSE
	auto_eject = FALSE
	gtype = "none"
	max_beakers = 1
	dart_reagent_amount = 10
	beakers = list() //All containers inside the gun.
	mixing = list() //Containers being used for mixing.
	container_type = /obj/item/weapon/reagent_containers/food/drinks/drinkingglass/tribalpot
	muzzle_flash = FALSE

/obj/item/weapon/gun/projectile/dartgun/consume_next_projectile()
	. = ..()
	var/obj/item/projectile/bullet/chemdart/dart = .
	if(istype(dart))
		fill_dart(dart)

/obj/item/weapon/gun/projectile/dartgun/examine(mob/user)
	//update_icon()
	//if (!..(user, 2))
	//	return
	..()
	if (beakers.len)
		user << "<span class = 'notice'>[src] contains:</span>"
		for(var/obj/item/weapon/reagent_containers/B in beakers)
			if(B.reagents && B.reagents.reagent_list.len)
				for(var/datum/reagent/R in B.reagents.reagent_list)
					user << "<span class = 'notice'>[R.volume] units of [R.name]</span>"

/obj/item/weapon/gun/projectile/dartgun/attackby(obj/item/I as obj, mob/user as mob)
	if (..()) // handle attachments
		return TRUE

	if(istype(I, /obj/item/weapon/reagent_containers))
		if(!istype(I, container_type))
			user << "<span class = 'notice'>[I] doesn't seem to fit into [src].</span>"
			return
		if(beakers.len >= max_beakers)
			user << "<span class = 'notice'>[src] already has [max_beakers] beakers in it - another one isn't going to fit!</span>"
			return
		var/obj/item/weapon/reagent_containers/B = I
		user.drop_item()
		B.loc = src
		beakers += B
		user << "<span class = 'notice'>You slot [B] into [src].</span>"
		updateUsrDialog()
		return TRUE
	..()

//fills the given dart with reagents
/obj/item/weapon/gun/projectile/dartgun/proc/fill_dart(var/obj/item/projectile/bullet/chemdart/dart)
	if(mixing.len)
		var/mix_amount = dart.reagent_amount/mixing.len
		for(var/obj/item/weapon/reagent_containers/B in mixing)
			B.reagents.trans_to_obj(dart, mix_amount)

/obj/item/weapon/gun/projectile/dartgun/attack_self(mob/user)
	var/dat = "<b>[src] mixing control:</b><br><br>"

	if (beakers.len)
		var/i = TRUE
		for(var/obj/item/weapon/reagent_containers/B in beakers)
			dat += "[B] [i] contains: "
			if(B.reagents && B.reagents.reagent_list.len)
				for(var/datum/reagent/R in B.reagents.reagent_list)
					dat += "<br>	[R.volume] units of [R.name], "
				if (check_beaker_mixing(B))
					dat += text("<A href='?src=\ref[src];stop_mix=[i]'><font color='green'>Mixing</font></A> ")
				else
					dat += text("<A href='?src=\ref[src];mix=[i]'><font color='red'>Not mixing</font></A> ")
			else
				dat += "nothing."
			dat += " \[<A href='?src=\ref[src];eject=[i]'>Eject</A>\]<br>"
			i++
	else
		dat += "There is no container inserted!<br><br>"

	if(ammo_magazine)
		if(ammo_magazine.stored_ammo && ammo_magazine.stored_ammo.len)
			dat += "The dart cartridge has [ammo_magazine.stored_ammo.len] shots remaining."
		else
			dat += "<font color='red'>The dart cartridge is empty!</font>"
		dat += " \[<A href='?src=\ref[src];eject_cart=1'>Eject</A>\]"

	user << browse(dat, "window=dartgun")
	onclose(user, "dartgun", src)

/obj/item/weapon/gun/projectile/dartgun/proc/check_beaker_mixing(var/obj/item/B)
	if(!mixing || !beakers)
		return FALSE
	for(var/obj/item/M in mixing)
		if(M == B)
			return TRUE
	return FALSE

/obj/item/weapon/gun/projectile/dartgun/Topic(href, href_list)
	if(..()) return TRUE
	add_fingerprint(usr)
	if(href_list["stop_mix"])
		var/index = text2num(href_list["stop_mix"])
		if(index <= beakers.len)
			for(var/obj/item/M in mixing)
				if(M == beakers[index])
					mixing -= M
					break
	else if (href_list["mix"])
		var/index = text2num(href_list["mix"])
		if(index <= beakers.len)
			mixing += beakers[index]
	else if (href_list["eject"])
		var/index = text2num(href_list["eject"])
		if(index <= beakers.len)
			if(beakers[index])
				var/obj/item/weapon/reagent_containers/B = beakers[index]
				usr << "You remove [B] from [src]."
				mixing -= B
				beakers -= B
				B.loc = get_turf(src)
	else if (href_list["eject_cart"])
		unload_ammo(usr)
	updateUsrDialog()
	return

/obj/item/weapon/gun/projectile/dartgun/bolt
	name = "bolt action dart gun"
	desc = "A single shot dart gun operated by bolt."
	icon_state = "dartbolt"
	base_icon = "dartbolt"
	item_state = "dartbolt"
	w_class = ITEM_SIZE_LARGE
	load_method = SINGLE_CASING
	max_shells = 1
	load_delay = 8
	slot_flags = SLOT_SHOULDER
	ammo_type = /obj/item/ammo_casing/chemdart
	weight = 4.5
	force = 10
	throwforce = 20
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_SCOPE
	effectiveness_mod = 1.07
	caliber = "dart"
	fire_sound = 'sound/weapons/guns/interact/garandload.ogg'
	fire_sound_text = "a sharp metalic clack"
	recoil = FALSE
	auto_eject = TRUE
	gtype = "none"
	max_beakers = 1
	dart_reagent_amount = 10
	beakers = list() //All containers inside the gun.
	mixing = list() //Containers being used for mixing.
	container_type = /obj/item/weapon/reagent_containers/glass/bottle
	var/bolt_open = TRUE
	var/bolt_safety = TRUE

/obj/item/weapon/gun/projectile/dartgun/bolt/update_icon()

	if (loaded.len >= max_shells)
		icon_state = base_icon
	else
		icon_state = "[base_icon]_open"
	update_held_icon()
	return


/obj/item/weapon/gun/projectile/dartgun/mag
	name = "semi-automatic dart gun"
	desc = "A single shot dart gun operated by bolt."
	icon_state = "magdart"

	item_state = null
	base_icon = "magdart"
	w_class = ITEM_SIZE_LARGE
	load_method = SINGLE_CASING|MAGAZINE
	load_delay = 8
	slot_flags = SLOT_SHOULDER
	ammo_type = /obj/item/ammo_casing/chemdart
	weight = 3
	force = 10
	throwforce = 20
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_SCOPE
	effectiveness_mod = 1.07
	caliber = "dart"
	fire_sound = 'sound/weapons/guns/interact/garandload.ogg'
	fire_sound_text = "a sharp metalic clack"
	recoil = FALSE
	magazine_type = /obj/item/ammo_magazine/chemdart/mag
	auto_eject = TRUE
	gtype = "none"
	beakers = list() //All containers inside the gun.
	mixing = list() //Containers being used for mixing.
	max_beakers = 1
	dart_reagent_amount = 10
	container_type = /obj/item/weapon/reagent_containers/glass/bottle
	starting_chems = null

/obj/item/weapon/gun/projectile/dartgun/mag/update_icon()
	if (ammo_magazine)
		icon_state = base_icon
		item_state = base_icon
	else
		icon_state = "[base_icon]_open"
		item_state = base_icon
	update_held_icon()
	return
