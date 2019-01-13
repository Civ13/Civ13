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