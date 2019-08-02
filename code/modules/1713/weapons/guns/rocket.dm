/obj/item/weapon/gun/launcher
	name = "launcher"
	desc = "A device that launches things."
	w_class = 5.0
	flags =  CONDUCT
	slot_flags = SLOT_SHOULDER
	var/load_delay = 10
	var/release_force = 0
	var/throw_distance = 10
	fire_sound_text = "a launcher firing"

//This normally uses a proc on projectiles and our ammo is not strictly speaking a projectile.
/obj/item/weapon/gun/launcher/can_hit(var/mob/living/target as mob, var/mob/living/user as mob)
	return 1

//Override this to avoid a runtime with suicide handling.
/obj/item/weapon/gun/launcher/handle_suicide(mob/living/user)
	user << "\red Shooting yourself with \a [src] is pretty tricky. You can't seem to manage it."
	return

/obj/item/weapon/gun/launcher/secondary_attack_self(mob/living/carbon/human/user)
	if (gun_safety)
		if (safetyon)
			safetyon = FALSE
			user << "<span class='notice'>You toggle \the [src]'s safety <b>OFF</b>.</span>"
			return
		else
			safetyon = TRUE
			user << "<span class='notice'>You toggle \the [src]'s safety <b>ON</b>.</span>"
			return


/obj/item/weapon/gun/launcher/proc/update_release_force(obj/item/projectile)
	return 0

/obj/item/weapon/gun/launcher/process_projectile(obj/item/projectile, mob/user, atom/target, var/target_zone, var/params=null, var/pointblank=0, var/reflex=0)
	update_release_force(projectile)
	projectile.loc = get_turf(user)
	projectile.throw_at(target, throw_distance, release_force, user)
	projectile.dir = get_dir(src.loc, target.loc)
	update_icon(projectile)
	return 1

/obj/item/weapon/gun/launcher/special_check(mob/user)
	if (!user.has_empty_hand(both = FALSE))
		user << "<span class='warning'>You need both hands to fire \the [src]!</span>"
		return FALSE
	if (gun_safety && safetyon)
		user << "<span class='warning'>You can't fire \the [src] while the safety is on!</span>"
		return FALSE
	return TRUE
/obj/item/weapon/gun/launcher/rocket
	name = "rocket launcher"
	desc = "MAGGOT."
	icon_state = "rocket"
	item_state = "rocket"
	w_class = 5
	throw_speed = 2
	throw_range = 10
	force = 5.0
	flags =  CONDUCT
	slot_flags = 0
	fire_sound = 'sound/effects/bang.ogg'
	var/max_rockets = 1
	var/list/rockets = new/list()
	release_force = 15
	throw_distance = 30
	fire_delay = 6
	equiptimer = 28
	load_delay = 18
/obj/item/weapon/gun/launcher/rocket/examine(mob/user)
	if(!..(user, 2))
		return
	if (rockets)
		user << "<b>LOADED</B>"
	else
		user << "<b>UNLOADED</B>"

/obj/item/weapon/gun/launcher/rocket/attackby(obj/item/I as obj, mob/user as mob)
	if(istype(I, /obj/item/ammo_casing/rocket))
		if(rockets.len < max_rockets && do_after(user, load_delay, src, can_move = TRUE))
			user.drop_item()
			I.loc = src
			rockets += I
			user << "You put the rocket in \the [src]."
			update_icon()
		else
			usr << "\The [src] cannot hold more rockets."

/obj/item/weapon/gun/launcher/rocket/consume_next_projectile()
	if(rockets.len)
		var/obj/item/ammo_casing/rocket/I = rockets[1]
		var/obj/item/missile/M = new (src)
		if (ishuman(src.loc))
			M.dir = src.loc.dir
		M.primed = 1
		rockets -= I
		return M
	return null

/obj/item/weapon/gun/launcher/rocket/handle_post_fire(mob/user, atom/target)
	message_admins("[key_name_admin(user)] fired a rocket from a rocket launcher ([src.name]) at [target].")
	log_game("[key_name_admin(user)] used a rocket launcher ([src.name]) at [target].")
	update_icon()
	..()

/obj/item/weapon/gun/launcher/rocket/rpg7
	name = "RPG-7"
	desc = "Russian multi-use rocket."
	icon_state = "rpg7_empty"
	item_state = "rpg"
	slot_flags = SLOT_SHOULDER
	force = 10

/obj/item/weapon/gun/launcher/rocket/rpg7/update_icon()
	..()
	if(rockets.len)
		icon_state = "rpg7"
	else
		icon_state = "rpg7_empty"

/obj/item/weapon/gun/launcher/rocket/rpg7/proc/unload(mob/user)
	if(rockets.len)
		var/obj/item/ammo_casing/rocket/G = rockets[rockets.len]
		rockets.len--
		user.put_in_hands(G)
		user.visible_message("\The [user] removes \a [G] from [src].", "<span class='notice'>You remove \a [G] from \the [src].</span>")
		update_icon()
	else
		user << "<span class='warning'>\The [src] is empty.</span>"

/obj/item/weapon/gun/launcher/rocket/rpg7/attack_hand(mob/user)
	if(user.get_inactive_hand() == src)
		unload(user)
	else
		..()


/obj/item/weapon/gun/launcher/rocket/panzerfaust
	name = "Panzerfaust 60"
	desc = "German single-use rocket."
	icon_state = "panzerfaust"
	item_state = "panzerfaust"
	slot_flags = SLOT_SHOULDER
	force = 10
	recoil = 2
	fire_delay = 12
	release_force = 12
	throw_distance = 10

/obj/item/weapon/gun/launcher/rocket/panzerfaust/New()
	..()
	rockets += new /obj/item/ammo_casing/rocket/panzerfaust(src)
	update_icon()

/obj/item/weapon/gun/launcher/rocket/panzerfaust/attackby(obj/item/I as obj, mob/user as mob)
	if(istype(I, /obj/item/ammo_casing/rocket))
		user << "<span class='warning'>You can't reload a [src]!</span>"
		return

/obj/item/weapon/gun/launcher/rocket/panzerfaust/update_icon()
	..()
	if(rockets.len)
		icon_state = "panzerfaust"
	else
		icon_state = "panzerfaust_empty"

/obj/item/weapon/gun/launcher/rocket/panzerfaust/proc/unload(mob/user)
	if(rockets.len)
		user << "<span class='warning'>You can't unload a [src]!</span>"
		return
	else
		user << "<span class='warning'>\The [src] is already used.</span>"
		return

/obj/item/weapon/gun/launcher/rocket/panzerfaust/attack_hand(mob/user)
	..()

/obj/item/ammo_casing/rocket
	name = "RPG rocket"
	desc = "A high explosive warhead and propeller designed to be fired from a rocket launcher."
	icon_state = "rocketshell"
	projectile_type = /obj/item/missile
	caliber = "rocket"
	w_class = 4
	slot_flags = SLOT_BELT

/obj/item/ammo_casing/rocket/panzerfaust
	name = "panzerfaust rocket"
	desc = "A high explosive warhead and propeller designed to be fired from a panzerfaust launcher."
	icon_state = "panzerfaust"
	projectile_type = /obj/item/missile/explosive/panzerfaust

/obj/item/ammo_casing/rocket/pg7v
	name = "PG-7V rocket"
	desc = "A high explosive warhead and propeller designed to be fired from a RPG-7 launcher."
	icon_state = "pg7v"
	projectile_type = /obj/item/missile/explosive


/obj/item/ammo_casing/rocket/og7v
	name = "OG-7V rocket"
	desc = "A fragmentation warhead and propeller designed to be fired from a RPG-7 launcher."
	icon_state = "og7v"
	projectile_type = /obj/item/missile/fragmentation

/obj/item/missile
	icon = 'icons/obj/grenade.dmi'
	icon_state = "missile"
	var/primed = null
	throwforce = 15
	allow_spin = FALSE
	throw_impact(atom/hit_atom)
		if(primed)
			explosion(hit_atom, 0, 1, 2, 4)
			qdel(src)
		else
			..()
		return

/obj/item/missile/explosive
	throw_impact(atom/hit_atom)
		if(primed)
			explosion(hit_atom, 0, 1, 2, 4)
			qdel(src)
		else
			..()
		return
/obj/item/missile/explosive/panzerfaust
	icon_state = "panzerfaust_missile"
	throw_impact(atom/hit_atom)
		if(primed)
			explosion(hit_atom, 0, 1, 2, 3)
			qdel(src)
		else
			..()
		return
/obj/item/missile/fragmentation
	var/num_fragments = 30
	var/spread_range = 6
	var/fragment_type = /obj/item/projectile/bullet/pellet/fragment
	var/fragment_damage = 15
	var/damage_step = 2
	throw_impact(atom/hit_atom)
		if(primed)
			explosion(hit_atom,0,1,3,1)
			var/turf/T = get_turf(hit_atom)
			if(!T) return
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
		else
			..()
		return
///////////////////M79
/obj/item/weapon/gun/launcher/grenadelauncher
	name = "grenade launcher"
	desc = "MAGGOT."
	icon_state = "rocket"
	item_state = "rocket"
	w_class = 5
	throw_speed = 2
	throw_range = 10
	force = 5.0
	flags =  CONDUCT
	slot_flags = 0
	fire_sound = 'sound/effects/bang.ogg'
	var/max_rockets = 1
	var/list/rockets = new/list()
	release_force = 9
	throw_distance = 12
	fire_delay = 4
	equiptimer = 20
	load_delay = 10
/obj/item/weapon/gun/launcher/grenadelauncher/examine(mob/user)
	if(!..(user, 2))
		return
	if (rockets)
		user << "<b>LOADED</B>"
	else
		user << "<b>UNLOADED</B>"

/obj/item/weapon/gun/launcher/grenadelauncher/attackby(obj/item/I as obj, mob/user as mob)
	if(istype(I, /obj/item/ammo_casing/grenade_l))
		if(rockets.len < max_rockets && do_after(user, load_delay, src, can_move = TRUE))
			user.drop_item()
			I.loc = src
			rockets += I
			user << "You put the grenade in \the [src]."
		else
			usr << "\The [src] cannot hold more grenades."

/obj/item/weapon/gun/launcher/grenadelauncher/consume_next_projectile()
	if(rockets.len)
		var/obj/item/ammo_casing/rocket/I = rockets[1]
		var/obj/item/missile/grenade/M = new (src)
		M.primed = 1
		rockets -= I
		return M
	return null

/obj/item/weapon/gun/launcher/grenadelauncher/handle_post_fire(mob/user, atom/target)
	message_admins("[key_name_admin(user)] fired a grenade from a grenade launcher ([src.name]) at [target].")
	log_game("[key_name_admin(user)] used a grenade launcher ([src.name]) at [target].")
	..()

/obj/item/weapon/gun/launcher/grenadelauncher/M79
	name = "M79 Grenade Launcher"
	desc = "American multi-use grenade launcher."
	icon_state = "m79"
	item_state = "m79"
	slot_flags = SLOT_SHOULDER
	force = 10

/obj/item/weapon/gun/launcher/grenadelauncher/M79/proc/unload(mob/user)
	if(rockets.len)
		var/obj/item/ammo_casing/rocket/G = rockets[rockets.len]
		rockets.len--
		user.put_in_hands(G)
		user.visible_message("\The [user] removes \a [G] from [src].", "<span class='notice'>You remove \a [G] from \the [src].</span>")
	else
		user << "<span class='warning'>\The [src] is empty.</span>"

/obj/item/weapon/gun/launcher/grenadelauncher/M79/attack_hand(mob/user)
	if(user.get_inactive_hand() == src)
		unload(user)
	else
		..()

/obj/item/ammo_casing/grenade_l
	icon = 'icons/obj/grenade.dmi'
	name = "40mm grenade"
	desc = "A high explosive designed to be fired from a launcher."
	icon_state = "g40mm"
	projectile_type = /obj/item/missile/grenade
	caliber = "g40"
	w_class = 4
	slot_flags = SLOT_POCKET

/obj/item/missile/grenade
	icon = 'icons/obj/grenade.dmi'
	icon_state = "g40mm"
	primed = null
	throwforce = 12
	allow_spin = TRUE
	throw_impact(atom/hit_atom)
		if(primed)
			explosion(hit_atom, 0, 1, 2, 2)
			qdel(src)
		else
			..()
		return