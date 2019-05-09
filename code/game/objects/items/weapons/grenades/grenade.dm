/obj/item/weapon/grenade
	name = "grenade"
	desc = "A hand held grenade, with a 5 second fuse."
	w_class = 2.0
	icon = 'icons/obj/grenade.dmi'
	icon_state = "grenade_old"
	item_state = "grenade"
	throw_speed = 4
	throw_range = 8
	flags = CONDUCT
	slot_flags = SLOT_BELT|SLOT_MASK
	var/active = FALSE
	var/det_time = 50
	var/loadable = TRUE
	flammable = TRUE
	value = 5

/obj/item/weapon/grenade/examine(mob/user)
	if (..(user, FALSE))
		if (det_time > 1)
			user << "The timer is set to [det_time/10] seconds."
			return


/obj/item/weapon/grenade/attack_self(mob/user as mob)
	if (!active)
		user << "<span class='warning'>You light \the [name]! [det_time/10] seconds!</span>"
		activate(user)
		add_fingerprint(user)

	// clicking a grenade a second time turned throw mode off, this fixes that
	if (iscarbon(user))
		var/mob/living/carbon/C = user
		C.throw_mode_on()


/obj/item/weapon/grenade/proc/activate(mob/user as mob)
	if (active)
		return

	if (user)
		msg_admin_attack("[user.name] ([user.ckey]) primed \a [src] (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[user.x];Y=[user.y];Z=[user.z]'>JMP</a>)")

	icon_state = initial(icon_state) + "_active"
	active = TRUE
	playsound(loc, 'sound/weapons/armbomb.ogg', 75, TRUE, -3)

	spawn(det_time)
		visible_message("<span class = 'warning'>\The [src] goes off!</span>")
		prime()
		return

/obj/item/weapon/grenade/proc/fast_activate()
	det_time = round(det_time/10)
	activate()

/obj/item/weapon/grenade/proc/prime()
	if (active)
	//	playsound(loc, 'sound/items/Welder2.ogg', 25, TRUE)
		var/turf/T = get_turf(src)
		if (T)
			T.hotspot_expose(700,125)


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
		explosion(O,0,1,3,1)
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
/obj/item/weapon/grenade/bomb/New()
	..()
	det_time = rand(80,120)
/obj/item/weapon/grenade/bomb/prime()
	set waitfor = 0
	..()

	var/turf/O = get_turf(src)
	if(!O) return

	if(explosion_size)
		explosion(O,1,2,3,1)
		qdel(src)


/obj/item/weapon/grenade/dynamite
	name = "empty dynamite stick"
	desc = "Light it and run."
	icon_state = "dynamite0"
	det_time = 40
	var/explosion_size = 2
	var/state = 0

/obj/item/weapon/grenade/dynamite/prime()
	set waitfor = 0
	..()

	var/turf/O = get_turf(src)
	if(!O) return

	if(explosion_size)
		explosion(O,0,2,4,2)
		qdel(src)

/obj/item/weapon/grenade/dynamite/attack_self(mob/user as mob)
	return

/obj/item/weapon/grenade/dynamite/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (state == 2 && istype(W, /obj/item/flashlight))
		var/obj/item/flashlight/F = W
		if (F.on)
			activate(user)
			add_fingerprint(user)
			name = "lighted dynamite stick"
			state = 3
			icon_state = "dynamite3"

			// clicking a grenade a second time turned throw mode off, this fixes that
			if (iscarbon(user))
				var/mob/living/carbon/C = user
				C.throw_mode_on()
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

/obj/item/weapon/grenade/dynamite/ready
	state = 2
	name = "dynamite stick"
	update_icon()

/obj/item/weapon/grenade/dynamite/activate(mob/user as mob)
	if (active)
		return

	if (user)
		msg_admin_attack("[user.name] ([user.ckey]) primed \a [src] (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[user.x];Y=[user.y];Z=[user.z]'>JMP</a>)")

	icon_state = "dynamite3"
	active = TRUE
	playsound(loc, 'sound/weapons/armbomb.ogg', 75, TRUE, -3)

	spawn(det_time)
		visible_message("<span class = 'warning'>\The [src] goes off!</span>")
		prime()
		return

/obj/item/weapon/grenade/modern
	name = "grenade"
	desc = "A hand held grenade, with a 5 second fuse."
	var/explosion_size = 2

/obj/item/weapon/grenade/modern/prime()
	set waitfor = 0
	..()

	var/turf/O = get_turf(src)
	if(!O) return

	if(explosion_size)
		explosion(O,0,1,3,1)
		qdel(src)

/obj/item/weapon/grenade/modern/mills
	name = "mills bomb no. 5"
	desc = "A British early XXth century grenade."
	icon_state = "mills"
	det_time = 70
	throw_range = 7

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
	desc = "A A German early XXth century design."
	icon_state = "stgnade"
	det_time = 45
	throw_range = 10
/obj/item/weapon/grenade/ww2/stg1924
	name = "M1924 Stielhandgranate"
	desc = "A A German design, to replace the M1915."
	icon_state = "stgnade"
	det_time = 45
	throw_range = 11

/obj/item/weapon/grenade/ww2/mk2
	name = "Mk2 grenade"
	desc = "An American grenade introduced in 1918."
	icon_state = "mk2"
	det_time = 50
	throw_range = 8

/obj/item/weapon/grenade/coldwar/m26
	name = "M26 grenade"
	desc = "An American grenade introduced in the 1950's."
	icon_state = "m26"
	det_time = 50
	throw_range = 9

/obj/item/weapon/grenade/ww2
	secondary_action = TRUE
/obj/item/weapon/grenade/modern
	secondary_action = TRUE
/obj/item/weapon/grenade/coldwar
	secondary_action = TRUE
/obj/item/weapon/grenade/secondary_attack_self(mob/living/carbon/human/user)
	if (secondary_action)
		var/inp = WWinput(user, "Are you sure you wan't to place a booby trap here?", "Booby Trapping", "No", list("Yes","No"))
		if (inp == "Yes")
			user << "Placing the booby trap..."
			if (do_after(user, 100, src))
				if (src)
					user << "You successfully place the booby trap here using \the [src]."
					var/obj/item/mine/boobytrap/BT = new /obj/item/mine/boobytrap(get_turf(user))
					BT.origin = src.type
					qdel(src)
		else
			return