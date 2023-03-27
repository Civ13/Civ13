/obj/item/weapon/grenade
	name = "grenade"
	desc = "A hand held grenade, with a 5 second fuse."
	w_class = ITEM_SIZE_SMALL
	icon = 'icons/obj/grenade.dmi'
	icon_state = "grenade_old"
	item_state = "grenade"
	throw_speed = 4
	throw_range = 8
	flags = CONDUCT
	slot_flags = SLOT_BELT|SLOT_POCKET
	var/active = FALSE
	var/det_time = 50
	var/loadable = TRUE
	flammable = TRUE
	value = 5
	var/explosion_sound = 'sound/weapons/Explosives/HEGrenade.ogg'
	var/mob/living/human/firer = null
/obj/item/weapon/grenade/examine(mob/user)
	if (..(user, FALSE))
		if (det_time > 1)
			user << "The timer is set to [det_time/10] seconds."
			return


/obj/item/weapon/grenade/attack_self(mob/user as mob)
	if (!active)
		user << "<span class='warning'>You light \the [name]! [det_time/10] seconds!</span>"
		firer = user
		activate(user)
		add_fingerprint(user)

	// clicking a grenade a second time turned throw mode off, this fixes that
	if (ishuman(user))
		var/mob/living/human/H = user
		if(istype(H) && !H.in_throw_mode)
			H.throw_mode_on()

/obj/item/weapon/grenade/dropped(mob/user)
	. = ..()
	if(ishuman(user) && active)
		var/mob/living/human/H = user
		H.throw_mode_off()

/obj/item/weapon/grenade/proc/activate(mob/living/human/user as mob)
	if (active)
		return

	if (user)
		msg_admin_attack("[user.name] ([user.ckey]) primed \a [src] (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[user.x];Y=[user.y];Z=[user.z]'>JMP</a>)")
		message_admins("[user.name] ([user.ckey]) primed \a [src] (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[user.x];Y=[user.y];Z=[user.z]'>JMP</a>)")
		log_game("[user.name] ([user.ckey]) primed \a [src] (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[user.x];Y=[user.y];Z=[user.z]'>JMP</a>)")
		firer = user
	icon_state = initial(icon_state) + "_active"
	active = TRUE
	playsound(loc, 'sound/weapons/armbomb.ogg', 75, TRUE, -3)

	spawn(det_time)
		visible_message("<span class = 'warning'>\The [src] goes off!</span>")
		prime(user)
		return

/obj/item/weapon/grenade/proc/fast_activate()
	det_time = round(det_time/10)
	activate()

/obj/item/weapon/grenade/proc/prime()
	return

/obj/item/weapon/grenade/attack_hand()
	walk(src, null, null)
	..()
	return


// grenades set off other grenades, but only ones on the same turf
/obj/item/weapon/grenade/ex_act(severity)
	switch (severity)
		if (1.0)
			fast_activate()
		if (2.0, 3.0)
			return // infinite recursive grenades are gone

/obj/item/weapon/grenade/bullet_act(var/obj/item/projectile/proj)
	if (proj && !proj.nodamage)
		return ex_act(1.0)
	return FALSE

/obj/item/weapon/grenade/old_grenade
	name = "grenade"
	desc = "A hand held grenade, with a 5 second fuse."
	var/explosion_size = 2

/obj/item/weapon/grenade/old_grenade/prime()
	set waitfor = 0
	..()

	var/turf/O = get_turf(src)
	if(!O) return

	if(explosion_size)
		explosion(O,0,1,3,1,sound=explosion_sound)
		qdel(src)


/obj/item/weapon/grenade/bomb
	name = "gunpowder barrel bomb"
	desc = "A gunpowder barrel, with a loose gunpowder fuse. Should take about 10 seconds to detonate, but it's not very fiable."
	icon_state = "bomb"
	var/explosion_size = 3
	nothrow = TRUE
	throw_speed = 1
	throw_range = 2
	flags = CONDUCT
	slot_flags = SLOT_BELT
	explosion_sound = 'sound/weapons/Explosives/Dynamite.ogg'
/obj/item/weapon/grenade/bomb/New()
	..()
	det_time = rand(80,120)
/obj/item/weapon/grenade/bomb/prime()
	set waitfor = 0
	..()

	var/turf/O = get_turf(src)
	if(!O) return

	if(explosion_size)
		explosion(O,1,2,3,1,sound=explosion_sound)
		qdel(src)


/obj/item/weapon/grenade/dynamite
	name = "empty dynamite stick"
	desc = "Light it and run."
	icon_state = "dynamite0"
	det_time = 40
	explosion_sound = 'sound/weapons/Explosives/Dynamite.ogg'
	var/explosion_size = 2
	var/state = 0

/obj/item/weapon/grenade/dynamite/prime()
	set waitfor = 0
	..()

	var/turf/O = get_turf(src)
	if(!O) return

	if(explosion_size)
		explosion(O,0,2,4,2,sound=explosion_sound)
		for (var/turf/floor/dirt/underground/U in range(2,src))
			U.mining_proc()
		qdel(src)

/obj/item/weapon/grenade/dynamite/attack_self(mob/user as mob)
	if (state == 2)
		activate()
		firer = user
	return

/obj/item/weapon/grenade/dynamite/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (state == 2 && istype(W, /obj/item/flashlight))
		var/obj/item/flashlight/F = W
		if (F.on)
			firer = user
			activate(user)
			add_fingerprint(user)
			name = "lighted dynamite stick"
			state = 3
			icon_state = "dynamite3"

			// clicking a grenade a second time turned throw mode off, this fixes that
			if (ishuman(user))
				var/mob/living/human/H = user
				if(istype(H) && !H.in_throw_mode)
					H.throw_mode_on()
			return
	else if (state == 1 && istype(W, /obj/item/stack/material/rope))
		var/obj/item/stack/material/rope/R = W
		if (R.amount == 1)
			qdel(R)
		else
			R.amount -= 1
		state = 2
		user << "You attach the wick to \the [src]."
		name = "dynamite stick"
		icon_state = "dynamite2"
		return
	else if (state == 0 && istype(W, /obj/item/weapon/reagent_containers))
		var/obj/item/weapon/reagent_containers/RG = W
		if (RG.reagents.has_reagent("nitroglycerin",2))
			RG.reagents.remove_reagent("nitroglycerin",2)
			user << "You fill \the [src] with the explosive charge."
			state = 1
			name = "filled dynamite stick"
			icon_state = "dynamite1"
			return
	else
		return

/obj/item/weapon/grenade/dynamite/dropped(mob/user)
	. = ..()
	if(ishuman(user) && active)
		var/mob/living/human/H = user
		H.throw_mode_off()

/obj/item/weapon/grenade/dynamite/ready
	state = 2
	name = "dynamite stick"
	icon_state = "dynamite2"
	update_icon()

/obj/item/weapon/grenade/dynamite/activate(mob/user as mob)
	if (active)
		return

	if (user)
		msg_admin_attack("[user.name] ([user.ckey]) primed \a [src] (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[user.x];Y=[user.y];Z=[user.z]'>JMP</a>)")
		message_admins("[user.name] ([user.ckey]) primed \a [src] (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[user.x];Y=[user.y];Z=[user.z]'>JMP</a>)")
		log_game("[user.name] ([user.ckey]) primed \a [src] (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[user.x];Y=[user.y];Z=[user.z]'>JMP</a>)")


	icon_state = "dynamite3"
	active = TRUE
	playsound(loc, 'sound/weapons/armbomb.ogg', 75, TRUE, -3)
	update_icon()
	spawn(det_time)
		visible_message("<span class = 'warning'>\The [src] goes off!</span>")
		prime()
		return

/obj/item/weapon/grenade/modern
	name = "grenade"
	desc = "A hand held grenade, with a 5 second fuse."
	var/explosion_size = 2
	var/fragment_type = /obj/item/projectile/bullet/pellet/fragment
	var/num_fragments = 30  //total number of fragments produced by the grenade
	var/fragment_damage = 15
	var/damage_step = 2	  //projectiles lose a fragment each time they travel this distance. Can be a non-integer.
	var/big_bomb = FALSE
	var/spread_range = 7
	explosion_sound = 'sound/weapons/Explosives/FragGrenade.ogg'
/obj/item/weapon/grenade/modern/prime()
	set waitfor = 0
	..()

	var/turf/T = get_turf(src)
	if(!T) return

	if(explosion_size)
		explosion(T,0,1,3,1,sound=explosion_sound)
	if (!ismob(loc))

		var/list/target_turfs = getcircle(T, spread_range)
		var/fragments_per_projectile = round(num_fragments/target_turfs.len)

		for (var/turf/TT in target_turfs)
			var/obj/item/projectile/bullet/pellet/fragment/P = new fragment_type(T)
			P.damage = fragment_damage
			P.pellets = fragments_per_projectile
			P.range_step = damage_step
			P.shot_from = name
			P.launch_fragment(TT)
			P.firer_loc = get_turf(src)

			// any mob on the source turf, lying or not, absorbs 100% of shrapnel now
			for (var/mob/living/L in T)
				P.attack_mob(L, 0, 0)

	spawn (5)
		qdel(src)

/obj/item/weapon/grenade/modern/mills
	name = "mills bomb no. 5"
	desc = "A British early XXth century grenade."
	icon_state = "mills"
	det_time = 70
	throw_range = 7
	explosion_sound = 'sound/weapons/Explosives/FragGrenade.ogg'

/obj/item/weapon/grenade/ww2/mills2
	name = "mills bomb no. 36M"
	desc = "A British early XXth century grenade, with a reduced timer to 4 seconds."
	icon_state = "mills"
	det_time = 40
	throw_range = 7

/obj/item/weapon/grenade/modern/f1
	name = "F1 grenade"
	desc = "A French early XXth century grenade, also used by Russia."
	icon_state = "f1"
	det_time = 40
	throw_range = 8

/obj/item/weapon/grenade/modern/stg1915
	name = "M1915 Stielhandgranate"
	desc = "A German early XXth century design."
	icon_state = "stgnade"
	det_time = 45
	throw_range = 10
/obj/item/weapon/grenade/ww2/stg1924
	name = "M1924 Stielhandgranate"
	desc = "A German design, to replace the M1915."
	icon_state = "stgnade"
	det_time = 45
	throw_range = 11

/obj/item/weapon/grenade/modern/thermaldetonator
	name = "Thermal Detonator"
	desc = "A grenade-like weapon popular among military personnel, criminals, bountyhunters, and mercenaries."
	icon_state = "detonator"
	det_time = 35
	throw_range = 12

/obj/item/weapon/grenade/modern/t68
	name = "Type68 grenade"
	desc = "An advanced grenade modeled after the Type 67 hand grenade used by the Chinese."
	icon_state = "t68"
	det_time = 35
	throw_range = 12

/obj/item/weapon/grenade/ww2/rgd33
	name = "RGD-33 grenade"
	desc = "A Soviet fragmentation grenade."
	icon_state = "rgd33"
	det_time = 50
	throw_range = 9

/obj/item/weapon/grenade/ww2/rg42
	name = "RG-42 grenade"
	desc = "A Soviet fragmentation grenade."
	icon_state = "rg42"
	det_time = 50
	throw_range = 10

/obj/item/weapon/grenade/ww2/mk2
	name = "Mk2 grenade"
	desc = "An American grenade introduced in 1918."
	icon_state = "mk2"
	det_time = 50
	throw_range = 8

/obj/item/weapon/grenade/ww2/type97
	name = "Type-97 grenade"
	desc = "A japanese grenade introduced in the second sino-japanese war. Blows up at 5 seconds."
	icon_state = "type97"
	det_time = 50
	throw_range = 10

/obj/item/weapon/grenade/ww2/type91
	name = "Type-91 grenade"
	desc = "A japanese grenade introduced in the second sino-japanese war. Blows up at 8 seconds."
	icon_state = "type91"
	det_time = 80
	throw_range = 10
	explosion_sound = 'sound/weapons/Explosives/FragGrenade.ogg'

/obj/item/weapon/grenade/coldwar/m26
	name = "M26 grenade"
	desc = "An American grenade introduced in the 1950's."
	icon_state = "m26"
	det_time = 50
	throw_range = 9
	explosion_sound = 'sound/weapons/Explosives/FragGrenade.ogg'

/obj/item/weapon/grenade/coldwar/stinger
	name = "Stinger grenade"
	desc = "A less then lethal  grenade that Explodes into a burst of rubber balls."
	icon_state = "sting"
	det_time = 50
	throw_range = 10
	explosion_sound = 'sound/weapons/Explosives/FragGrenade.ogg'
	fragment_type = /obj/item/projectile/bullet/pellet/rubberball
	explosion_size = 0

/obj/item/weapon/grenade/coldwar/m67
	name = "M67 grenade"
	desc = "An American grenade introduced as a replacement for the M26."
	icon_state = "m67"
	det_time = 50
	throw_range = 10

/obj/item/weapon/grenade/coldwar/hg85
	name = "HG 85 grenade"
	desc = "The HG 85 is a round fragmentation hand grenade designed for the Swiss Armed Forces."
	icon_state = "hg85"
	det_time = 50
	throw_range = 10

/obj/item/weapon/grenade/coldwar/hg85/l109
	name = "L109 grenade"
	desc = "The L109 is the British designation for the HG 85. It differs from the HG 85 in that it has a special safety clip, which is similar to the safety clip on the American M67 grenade."
	icon_state = "l109"
	det_time = 50
	throw_range = 10

/obj/item/weapon/grenade/coldwar/rgd5
	name = "RGD-5 grenade"
	desc = "A Soviet fragmentation grenade designed in the 1950's."
	icon_state = "rgd5"
	det_time = 50
	throw_range = 11

/obj/item/weapon/grenade/ww2/prime()
	set waitfor = 0
	..()

	var/turf/T = get_turf(src)
	if(!T) return

	if(explosion_size)
		explosion(T,0,1,3,1,sound=explosion_sound)
	if (!ismob(loc))

		var/list/target_turfs = getcircle(T, spread_range)
		var/fragments_per_projectile = round(num_fragments/target_turfs.len)

		for (var/turf/TT in target_turfs)
			var/obj/item/projectile/bullet/pellet/fragment/P = new fragment_type(T)
			P.damage = fragment_damage
			P.pellets = fragments_per_projectile
			P.range_step = damage_step
			P.shot_from = name
			P.launch_fragment(TT)

			// any mob on the source turf, lying or not, absorbs 100% of shrapnel now
			for (var/mob/living/L in T)
				P.attack_mob(L, 0, 0)

	spawn (5)
		qdel(src)

/obj/item/weapon/grenade/coldwar/prime()
	set waitfor = 0
	..()

	var/turf/T = get_turf(src)
	if(!T) return

	if(explosion_size)
		explosion(T,0,1,3,1,sound=explosion_sound)
	if (!ismob(loc))

		var/list/target_turfs = getcircle(T, spread_range)
		var/fragments_per_projectile = round(num_fragments/target_turfs.len)

		for (var/turf/TT in target_turfs)
			var/obj/item/projectile/bullet/pellet/fragment/P = new fragment_type(T)
			P.damage = fragment_damage
			P.pellets = fragments_per_projectile
			P.range_step = damage_step
			P.shot_from = name
			P.launch_fragment(TT)

			// any mob on the source turf, lying or not, absorbs 100% of shrapnel now
			for (var/mob/living/L in T)
				P.attack_mob(L, 0, 0)

	spawn (5)
		qdel(src)

/obj/item/weapon/grenade/coldwar/nonfrag/m26
	name = "M26 explosive grenade"
	desc = "An American grenade introduced in the 1950's. This one has no shrapnel."
	icon_state = "m26_explosive"
	det_time = 50
	throw_range = 10

/obj/item/weapon/grenade/coldwar/nonfrag/prime()
	set waitfor = 0
	..()

	var/turf/T = get_turf(src)
	if(!T) return

	if(explosion_size)
		explosion(T,1,3,3,1,sound=explosion_sound)
		qdel(src)

/obj/item/weapon/grenade/ww2
	var/fragment_type = /obj/item/projectile/bullet/pellet/fragment
	var/num_fragments = 37  //total number of fragments produced by the grenade
	var/fragment_damage = 15
	var/damage_step = 2	  //projectiles lose a fragment each time they travel this distance. Can be a non-integer.
	var/big_bomb = FALSE
	secondary_action = TRUE
	var/explosion_size = 2
	var/spread_range = 7

/obj/item/weapon/grenade/modern
	secondary_action = TRUE

/obj/item/weapon/grenade/coldwar
	var/fragment_type = /obj/item/projectile/bullet/pellet/fragment
	var/num_fragments = 37  //total number of fragments produced by the grenade
	var/fragment_damage = 15
	var/damage_step = 2	  //projectiles lose a fragment each time they travel this distance. Can be a non-integer.
	var/big_bomb = FALSE

	//The radius of the circle used to launch projectiles. Lower values mean less projectiles are used but if set too low gaps may appear in the spread pattern
	var/spread_range = 7
	secondary_action = TRUE
	var/explosion_size = 2

/obj/item/weapon/grenade/secondary_attack_self(mob/living/human/user)
	if (secondary_action)
		var/inp = WWinput(user, "Are you sure that you want to place a booby trap here?", "Booby Trapping", "No", list("Yes","No"))
		if (inp == "Yes")
			user << "Placing the booby trap..."
			if (do_after(user, 100, src))
				if (src)
					user << "You successfully place the booby trap here using \the [src]."
					var/obj/item/mine/boobytrap/BT = new /obj/item/mine/boobytrap(get_turf(user))
					BT.origin = src.type
					firer = user
					message_admins("[user.name] ([user.ckey]) placed a boobytrap from \a [src] at ([user.x],[user.y],[user.z])(<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[user.x];Y=[user.y];Z=[user.z]'>JMP</a>)")
					log_game("[user.name] ([user.ckey]) placed a boobytrap from \a [src] at ([user.x],[user.y],[user.z])(<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[user.x];Y=[user.y];Z=[user.z]'>JMP</a>)")
					qdel(src)
		else
			return

/obj/item/weapon/grenade/suicide_vest
	name = "suicide vest"
	desc = "An IED suicide vest. Deadly!"
	icon_state = "suicide_vest"
	nothrow = TRUE
	throw_speed = 1
	throw_range = 2
	flags = CONDUCT
	slot_flags = SLOT_BELT
	det_time = 10
	var/armed = "disarmed"

/obj/item/weapon/grenade/suicide_vest/prime()
	if (active)
		var/turf/T = get_turf(src)
		if(!T) return
		var/original_mobs = list()
		var/original_objs = list()

		explosion(T,2,3,3,3)
		for (var/mob/living/L in T.contents)
			original_mobs += L
			if (L.client)
				L.canmove = FALSE
				L.gib()
		for (var/obj/O in T.contents)
			original_objs += O
		playsound(T, "explosion", 100, TRUE)
		spawn (1)
			for (var/mob/living/L in range(1,T))
				if (L)
					L.maim()
					if (L)
						L.canmove = TRUE
			for (var/obj/O in original_objs)
				if (O)
					O.ex_act(1.0)
			T.ex_act(1.0)
		qdel(src)


/obj/item/weapon/grenade/suicide_vest/examine(mob/user)
	..()
	user << "\The [src] is <b>[armed]</b>."
	return

/obj/item/weapon/grenade/suicide_vest/attack_self(mob/user as mob)
	if (!active && armed == "armed")
		user << "<span class='warning'>You switch \the [name]!</span>"
		activate(user)
		add_fingerprint(user)

/obj/item/weapon/grenade/suicide_vest/attack_hand(mob/user as mob)
	if (!active && armed == "armed" && loc == user)
		user << "<span class='warning'>You switch \the [name]!</span>"
		activate(user)
		add_fingerprint(user)
	else
		..()

/obj/item/weapon/grenade/suicide_vest/verb/arm()
	set category = null
	set name = "Arm/Disarm"
	set src in range(1, usr)

	if (armed == "armed")
		usr << "You disarm \the [src]."
		armed = "disarmed"
		return
	else
		usr << "<span class='warning'>You arm \the [src]!</span>"
		armed = "armed"
		return

/obj/item/weapon/grenade/suicide_vest/activate(mob/living/human/user as mob)
	if (active)
		return

	if (user)
		msg_admin_attack("[user.name] ([user.ckey]) primed \a [src] (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[user.x];Y=[user.y];Z=[user.z]'>JMP</a>)")
		log_game("[user.name] ([user.ckey]) primed \a [src] (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[user.x];Y=[user.y];Z=[user.z]'>JMP</a>)")
		message_admins("[user.name] ([user.ckey]) primed \a [src] (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[user.x];Y=[user.y];Z=[user.z]'>JMP</a>)")

	if (user && user.faction_text == ARAB)
		user.emote("charge")
	active = TRUE
	playsound(loc, 'sound/weapons/armbomb.ogg', 75, TRUE, -3)

	spawn(det_time)
		visible_message("<span class = 'warning'>\The [src] goes off!</span>")
		prime()
		return

/obj/item/weapon/grenade/suicide_vest/kamikaze
	name = "kamikaze vest"
	desc = "An Antitank Mine Suicide Vest, deadly!"
	icon_state = "kamikaze_vest"
	nothrow = TRUE
	throw_speed = 1
	throw_range = 2
	flags = CONDUCT
	slot_flags = SLOT_BELT
	det_time = 1
	heavy_armor_penetration = 22
	var/armed1 = "disarmed"

/obj/item/weapon/grenade/suicide_vest/kamikaze/examine(mob/user)
	..()
	user << "\The [src] is <b>[armed]</b>."
	return

/obj/item/weapon/grenade/suicide_vest/kamikaze/attack_self(mob/user as mob)
	if (!active && armed1 == "armed")
		user << "<span class='warning'>You switch \the [name]!</span>"
		firer = user
		activate(user)
		add_fingerprint(user)

/obj/item/weapon/grenade/suicide_vest/kamikaze/attack_hand(mob/user as mob)
	if (!active && armed1 == "armed" && loc == user)
		user << "<span class='warning'>You switch \the [name]!</span>"
		firer = user
		activate(user)
		add_fingerprint(user)
	else
		..()

/obj/item/weapon/grenade/suicide_vest/kamikaze/verb/arm1()
	set category = null
	set name = "Arm/Disarm"
	set src in range(1, usr)

	if (armed1 == "armed")
		usr << "You disarm \the [src]."
		armed1 = "disarmed"
		firer = null
		return
	else
		usr << "<span class='warning'>You arm \the [src]!</span>"
		armed1 = "armed"
		return

/obj/item/weapon/grenade/suicide_vest/kamikaze/activate(mob/living/human/user as mob)
	if (active)
		return

	if (user)
		msg_admin_attack("[user.name] ([user.ckey]) primed \a [src] (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[user.x];Y=[user.y];Z=[user.z]'>JMP</a>)")
		log_game("[user.name] ([user.ckey]) primed \a [src] (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[user.x];Y=[user.y];Z=[user.z]'>JMP</a>)")
		message_admins("[user.name] ([user.ckey]) primed \a [src] (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[user.x];Y=[user.y];Z=[user.z]'>JMP</a>)")

	if (user && user.faction_text == JAPANESE)
		user.emote("charge")
	active = TRUE
	playsound(loc, 'sound/weapons/armbomb.ogg', 75, TRUE, -3)

	spawn(det_time)
		visible_message("<span class = 'warning'>\The [src] goes off!</span>")
		prime()
		return

/obj/item/weapon/grenade/suicide_vest/kamikaze/prime()
	set waitfor = 0

	var/turf/T = get_turf(src.loc)
	if(!T) return

	if (active)
		explosion(T,3,3,3,3)
		for(var/obj/structure/vehicleparts/frame/F in range(1,T))
			for (var/mob/M in F.axis.transporting)
				shake_camera(M, 3, 3)
			var/penloc = F.CheckPenLoc(src)
			switch(penloc)
				if ("left")
					if (F.w_left[5] > 0)
						F.w_left[5] -= heavy_armor_penetration
						visible_message("<span class = 'danger'><big>The left hull gets damaged!</big></span>")
				if ("right")
					if (F.w_right[5] > 0)
						F.w_right[5] -= heavy_armor_penetration
						visible_message("<span class = 'danger'><big>The right hull gets damaged!</big></span>")
				if ("front")
					if (F.w_front[5] > 0)
						F.w_front[5] -= heavy_armor_penetration
						visible_message("<span class = 'danger'><big>The front hull gets damaged!</big></span>")
				if ("back")
					if (F.w_back[5] > 0)
						F.w_back[5] -= heavy_armor_penetration
						visible_message("<span class = 'danger'><big>The rear hull gets damaged!</big></span>")
				if ("frontleft")
					if (F.w_left[5] > 0 && F.w_front[5] > 0)
						if (F.w_left[4] > F.w_front[4] && F.w_left[5]>0)
							F.w_left[5] -= heavy_armor_penetration
							visible_message("<span class = 'danger'><big>The left hull gets damaged!</big></span>")
						else
							F.w_front[5] -= heavy_armor_penetration
							visible_message("<span class = 'danger'><big>The front hull gets damaged!</big></span>")
				if ("frontright")
					if (F.w_right[5] > 0 && F.w_front[5] > 0)
						if (F.w_right[4] > F.w_front[4] && F.w_right[5]>0)
							F.w_right[5] -= heavy_armor_penetration
							visible_message("<span class = 'danger'><big>The right hull gets damaged!</big></span>")
						else
							F.w_front[5] -= heavy_armor_penetration
							visible_message("<span class = 'danger'><big>The front hull gets damaged!</big></span>")
				if ("backleft")
					if (F.w_left[5] > 0 && F.w_back[5] > 0)
						if (F.w_left[4] > F.w_back[4] && F.w_left[5]>0)
							F.w_left[5] -= heavy_armor_penetration
							visible_message("<span class = 'danger'><big>The left hull gets damaged!</big></span>")
						else
							F.w_back[5] -= heavy_armor_penetration
							visible_message("<span class = 'danger'><big>The rear hull gets damaged!</big></span>")
				if ("backright")
					if (F.w_right[5] > 0 && F.w_back[5] > 0)
						if (F.w_right[4] > F.w_back[4] && F.w_right[5]>0)
							F.w_right[5] -= heavy_armor_penetration
							visible_message("<span class = 'danger'><big>The right hull gets damaged!</big></span>")
						else
							F.w_back[5] -= heavy_armor_penetration
							visible_message("<span class = 'danger'><big>The rear hull gets damaged!</big></span>")
			F.try_destroy()
			for(var/obj/structure/vehicleparts/movement/MV in F)
				MV.broken = TRUE
				MV.update_icon()
			F.update_icon()
		qdel(src)

/obj/item/weapon/grenade/coldwar/nonfrag/custom
	name = "explosive grenade"
	desc = "An explosive grenade with no shrapnel."	//This is a plain lie
	icon_state = "m26"
	det_time = 50
	throw_range = 9

/obj/item/weapon/grenade/antitank/custom
	name = "anti-tank grenade"
	desc = "An anti-tank grenade with no shrapnel."
	icon_state = "rpg40"
	det_time = 50
	throw_range = 3
	heavy_armor_penetration = 18

/obj/item/weapon/grenade/modern/custom
	name = "shrapnel grenade"
	desc = "A grenade filled with metallic shrapnel."
	icon_state = "mk2"
	det_time = 50
	throw_range = 10

/obj/item/weapon/grenade/antitank
	name = "anti-tank grenade"
	desc = "A powerful grenade, useful against armored vehicles."
	icon_state = "rpg40"
	det_time = 50
	throw_range = 5
	heavy_armor_penetration = 22

/obj/item/weapon/grenade/antitank/rpg40
	name = "RPG-40"
	icon_state = "rpg40"
	det_time = 50
	throw_range = 5

/obj/item/weapon/grenade/antitank/stg24_bundle
	name = "M1924 Stielhandgranate bundle"
	desc = "A bundle of M1924 grenades tied together, useful against armored vehicles."
	icon_state = "stgbundle"
	det_time = 50
	throw_range = 6
	heavy_armor_penetration = 18

/obj/item/weapon/grenade/antitank/n73
	name = "N73 AT grenade"
	desc = "A British anti-tank hand percussion grenade used during WW2. Also known as \"Thermos\". "
	icon_state = "n73"
	heavy_armor_penetration = 20

/obj/item/weapon/grenade/antitank/n74
	name = "N74 AT grenade"
	desc = "A British anti-tank hand grenade used during WW2. Also known as the \"Sticky Bomb\"."
	icon_state = "n74"
	heavy_armor_penetration = 18

/obj/item/weapon/grenade/antitank/n75
	name = "n75 AT grenade"
	desc = "A British anti-tank hand grenade used during WW2. Also known as the \"Hawkins grenade\". Can also be used as an AT-mine."
	icon_state = "n75"
	heavy_armor_penetration = 22
	throw_range = 7
	secondary_action = TRUE

/obj/item/weapon/grenade/antitank/n75/secondary_attack_self(mob/living/human/user)
	if (secondary_action)
		var/inp = WWinput(user, "Are you sure you want to place an anti-tank mine here?", "Mining", "No", list("Yes","No"))
		if (inp == "Yes")
			user << "Placing the mine..."
			if (do_after(user, 60, src))
				if (src)
					user << "You successfully place the mine here using \the [src]."
					var/obj/item/mine/at/armed/BT = new /obj/item/mine/at/armed(get_turf(user))
					BT.origin = src.type
					firer = user
					qdel(src)
		else
			return

/obj/item/weapon/grenade/antitank/type99
	name = "Type 99 AT mine"
	icon_state = "type99"
	desc = "A japanese anti-tank mine that can also be used as a grenade."
	det_time = 50
	throw_range = 8
	secondary_action = TRUE

/obj/item/weapon/grenade/antitank/type99/secondary_attack_self(mob/living/human/user)
	if (secondary_action)
		var/inp = WWinput(user, "Are you sure you want to place an anti-tank mine here?", "Mining", "No", list("Yes","No"))
		if (inp == "Yes")
			user << "Placing the mine..."
			if (do_after(user, 60, src))
				if (src)
					user << "You successfully place the mine here using \the [src]."
					var/obj/item/mine/at/armed/BT = new /obj/item/mine/at/armed(get_turf(user))
					BT.origin = src.type
					firer = user
					qdel(src)
		else
			return

/obj/item/weapon/grenade/antitank/prime()
	set waitfor = 0
	..()

	var/turf/T = get_turf(src)
	if(!T) return

	explosion(T,2,2,2,2,sound=explosion_sound)
	for(var/obj/structure/vehicleparts/frame/F in range(1,T))
		for (var/mob/M in F.axis.transporting)
			shake_camera(M, 3, 3)
		var/penloc = F.CheckPenLoc(src)
		switch(penloc)
			if ("left")
				if (F.w_left[5] > 0)
					F.w_left[5] -= heavy_armor_penetration
					visible_message("<span class = 'danger'><big>The left hull gets damaged!</big></span>")
			if ("right")
				if (F.w_right[5] > 0)
					F.w_right[5] -= heavy_armor_penetration
					visible_message("<span class = 'danger'><big>The right hull gets damaged!</big></span>")
			if ("front")
				if (F.w_front[5] > 0)
					F.w_front[5] -= heavy_armor_penetration
					visible_message("<span class = 'danger'><big>The front hull gets damaged!</big></span>")
			if ("back")
				if (F.w_back[5] > 0)
					F.w_back[5] -= heavy_armor_penetration
					visible_message("<span class = 'danger'><big>The rear hull gets damaged!</big></span>")
			if ("frontleft")
				if (F.w_left[5] > 0 && F.w_front[5] > 0)
					if (F.w_left[4] > F.w_front[4] && F.w_left[5]>0)
						F.w_left[5] -= heavy_armor_penetration
						visible_message("<span class = 'danger'><big>The left hull gets damaged!</big></span>")
					else
						F.w_front[5] -= heavy_armor_penetration
						visible_message("<span class = 'danger'><big>The front hull gets damaged!</big></span>")
			if ("frontright")
				if (F.w_right[5] > 0 && F.w_front[5] > 0)
					if (F.w_right[4] > F.w_front[4] && F.w_right[5]>0)
						F.w_right[5] -= heavy_armor_penetration
						visible_message("<span class = 'danger'><big>The right hull gets damaged!</big></span>")
					else
						F.w_front[5] -= heavy_armor_penetration
						visible_message("<span class = 'danger'><big>The front hull gets damaged!</big></span>")
			if ("backleft")
				if (F.w_left[5] > 0 && F.w_back[5] > 0)
					if (F.w_left[4] > F.w_back[4] && F.w_left[5]>0)
						F.w_left[5] -= heavy_armor_penetration
						visible_message("<span class = 'danger'><big>The left hull gets damaged!</big></span>")
					else
						F.w_back[5] -= heavy_armor_penetration
						visible_message("<span class = 'danger'><big>The rear hull gets damaged!</big></span>")
			if ("backright")
				if (F.w_right[5] > 0 && F.w_back[5] > 0)
					if (F.w_right[4] > F.w_back[4] && F.w_right[5]>0)
						F.w_right[5] -= heavy_armor_penetration
						visible_message("<span class = 'danger'><big>The right hull gets damaged!</big></span>")
					else
						F.w_back[5] -= heavy_armor_penetration
						visible_message("<span class = 'danger'><big>The rear hull gets damaged!</big></span>")
		F.try_destroy()
		for(var/obj/structure/vehicleparts/movement/MV in F)
			MV.broken = TRUE
			MV.update_icon()
		F.update_icon()
		if (firer)
			firer.awards["tank"]+=(heavy_armor_penetration/200)
	qdel(src)
