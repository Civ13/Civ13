
/obj/item/weapon/flamethrower
	name = "M2 Flamethrower hoose"
	desc = "Use with a flamethrower fuel tank to set your enemies on fire."
	icon = 'icons/obj/guns/gun.dmi'
	icon_state = "m2_flamethrower"
	item_state = "m2_flamethrower"
	var/base_icon = "m2_flamethrower"
	flags = CONDUCT
	sharp = FALSE
	edge = FALSE
	attack_verb = list("bashed", "hit")
	force = WEAPON_FORCE_WEAK+2
	throwforce = WEAPON_FORCE_WEAK
	flammable = FALSE
	w_class = ITEM_SIZE_LARGE
	slot_flags = SLOT_BELT|SLOT_SHOULDER
	var/active = FALSE
	var/lastfire = 0
	var/max_range = 4
	var/firing_sound = 'sound/weapons/flamethrower.ogg'

/obj/item/weapon/flamethrower/update_icon()
	if (active)
		icon_state = "[base_icon]_on"
		item_state = "[base_icon]_on"
	else
		icon_state = base_icon
		item_state = base_icon

/obj/item/weapon/flamethrower/attack_self(var/mob/living/H)
	if (active)
		active=FALSE
		update_icon()
		H << "<span class='danger'>You extinguish \the [src].</span>"
	else
		active=TRUE
		update_icon()
		H << "<span class='danger'>You light \the [src].</span>"

/obj/item/weapon/flamethrower/proc/fire(var/mob/living/human/H,var/cdir=null,atom/target)
	if (!active || !H)
		return
	if (world.time<=lastfire)
		return
	if (!H.has_empty_hand(both = FALSE))
		H << "<span class='warning'>You need both hands to fire \the [src]!</span>"
		return
	if (!cdir)
		cdir = H.dir
	var/obj/item/weapon/reagent_containers/glass/flamethrower/FM = null
	if (!H.back || !istype(H.back,/obj/item/weapon/reagent_containers/glass/flamethrower))
		H << "<span class='warning'>You need a fuel tank on your back in order to be able to use a flamethrower!</span>"
		return
	if (istype(H.back,/obj/item/weapon/reagent_containers/glass/flamethrower))
		FM = H.back
	if (!FM)
		H << "<span class='warning'>You need a fuel tank on your back in order to be able to use a flamethrower!</span>"
		return
	if (FM.reagents && FM.reagents.get_reagent_amount("gasoline") < 5)
		H << "<span class='warning'>The fuel tank doesn't have enough fuel to operate the flamethrower!</span>"
		return
	else
		process_fire(H,FM,cdir,target)
		return

/obj/item/weapon/flamethrower/proc/process_fire(var/mob/living/human/user, var/obj/item/weapon/reagent_containers/glass/flamethrower/FM, var/cdir = null, atom/target)
	if (!cdir || !(cdir in list(NORTH,SOUTH,EAST,WEST)))
		cdir = user.dir
	if (FM.reagents && FM.reagents.get_reagent_amount("gasoline") >= 5)
		FM.reagents.remove_reagent("gasoline",5)
		lastfire = world.time+20
		//message_admins("[user.name] ([user.ckey]) fired a flamethrower from: X=[user.x];Y=[user.y];Z[user.z]")
		var/turf/source_turf = get_turf(user)

		var/list/turfs = getline2(source_turf, target)

		var/distance = 0
		var/stop_at_turf = FALSE

		playsound(source_turf, firing_sound, 100, TRUE)

		for(var/turf/T in turfs)
			if(distance > max_range)
				break

			if(istype(T, /turf/floor/space))
				break

			if(T.density)
				if(!istype(T, /obj/structure/barricade) || !istype(T, /obj/structure/window/barrier))
					stop_at_turf = TRUE
			else
				if (distance > 0)
					ignite_turf(get_turf(T), 6, 70) // 6 second 70 damage flame

			if(T == target.loc)
				if(stop_at_turf)
					break
				continue

			if(stop_at_turf)
				break

			distance++

/obj/item/weapon/reagent_containers/glass/flamethrower
	name = "M2 Flamethrower backpack"
	desc = "A flamethrower backpack. Up to 100 liters of gasoline."
	icon = 'icons/obj/guns/gun.dmi'
	icon_state = "m2_flamethrower_back"
	item_state = "m2_flamethrower"
	flags = CONDUCT
	sharp = FALSE
	edge = FALSE
	nothrow = TRUE
	flags = CONDUCT
	attack_verb = list("bashed", "hit")
	force = WEAPON_FORCE_WEAK
	throwforce = WEAPON_FORCE_WEAK
	flammable = TRUE
	w_class = 10
	slot_flags = SLOT_BACK
	throw_speed = 1
	throw_range = 1
	amount_per_transfer_from_this = 25
	volume = 100
	density = FALSE

/obj/item/weapon/reagent_containers/glass/flamethrower/filled/New()
	..()
	reagents.add_reagent("gasoline",100)

/obj/item/weapon/flamethrower/flammenwerfer
	name = "Flammenwerfer hoose"
	icon_state = "flammenwerfer"
	item_state = "flammenwerfer"
	base_icon = "flammenwerfer"

/obj/item/weapon/reagent_containers/glass/flamethrower/flammenwerfer
	name = "Flammenwerfer backpack"
	icon_state = "flammenwerfer_back"
	item_state = "flammenwerfer"

/obj/item/weapon/reagent_containers/glass/flamethrower/flammenwerfer/filled/New()
	..()
	reagents.add_reagent("gasoline",100)

/obj/item/weapon/flamethrower/type100
	name = "Type100 Flamethrower hose"
	icon_state = "type100_flamethrower"
	item_state = "type100_flamethrower"
	base_icon = "type100_flamethrower"

/obj/item/weapon/reagent_containers/glass/flamethrower/type100
	name = "Type100 Flamethrower Canister"
	icon_state = "type100_flamethrower_back"
	item_state = "type100_flamethrower"

/obj/item/weapon/reagent_containers/glass/flamethrower/type100/filled/New()
	..()
	reagents.add_reagent("gasoline",100)

/obj/item/weapon/flamethrower/eins
	name = "Einstossflammenwerfer 46 hose"
	desc = "Single use flamethrower hose, aim carefully."
	w_class = ITEM_SIZE_NORMAL
	slot_flags = SLOT_BELT|SLOT_POCKET|SLOT_SHOULDER
	max_range = 5
	icon_state = "eins"
	item_state = "eins"
	base_icon = "eins"

/obj/item/weapon/reagent_containers/glass/flamethrower/eins //until someone makes it so the eins is just a single item that you can fire and drop there will be a canister
	name = "Einstossflammenwerfer 46 canister"
	desc = "A eins single use flamethrower canister. put it on your back to use it with the hose."
	icon_state = "eins_back"
	item_state = "eins_back"
	slowdown = 0.2
	amount_per_transfer_from_this = 1
	volume = 5
	w_class = ITEM_SIZE_NORMAL

/obj/item/weapon/reagent_containers/glass/flamethrower/eins/filled/New()
	..()
	reagents.add_reagent("gasoline",5)

/obj/item/weapon/flamethrower/roks2
	name = "ROKS2 Flamethrower hose"
	icon_state = "roks2_flamethrower"
	item_state = "roks2_flamethrower"
	base_icon = "roks2_flamethrower"

/obj/item/weapon/reagent_containers/glass/flamethrower/roks2
	name = "ROKS2 Flamethrower Canister"
	icon_state = "roks2_flamethrower_back"
	item_state = "roks2_flamethrower"

/obj/item/weapon/reagent_containers/glass/flamethrower/roks2/filled/New()
	..()
	reagents.add_reagent("gasoline",100)


/obj/item/weapon/reagent_containers/glass/flamethrower_mg
	name = "Stationary Flamethrower Tank"
	desc = "A flamethrower tank. Up to 200 liters of gasoline."
	icon = 'icons/obj/guns/gun.dmi'
	icon_state = "coaxflam_ammo"
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand.dmi',
		)
	item_state = "ammo_can"
	flags = CONDUCT
	sharp = FALSE
	edge = FALSE
	nothrow = TRUE
	flags = CONDUCT
	attack_verb = list("bashed", "hit")
	force = WEAPON_FORCE_WEAK
	throwforce = WEAPON_FORCE_WEAK
	flammable = TRUE
	w_class = 14
	slot_flags = null
	throw_speed = 1
	throw_range = 1
	amount_per_transfer_from_this = 25
	volume = 200
	density = FALSE
/obj/item/weapon/reagent_containers/glass/flamethrower_mg/filled/New()
	..()
	reagents.add_reagent("gasoline",200)