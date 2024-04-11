/obj/item/weapon/gun/launcher/grenade
	name = "grenade launcher"
	desc = "A bulky pump-action grenade launcher. Holds up to 6 grenades in a revolving magazine."
	icon_state = "grenade_launcher"
	item_state = "grenade_launcher"
	w_class = ITEM_SIZE_HUGE
	force = 10

	fire_sound = 'sound/weapons/guns/fire/M79.ogg'
	fire_sound_text = "a metallic thunk"
	shake_strength = 0
	firing_range = 40
	release_force = 5
	gun_safety = FALSE

	var/list/grenades = new/list()
	var/max_grenades = 5 // How many grenades can be loaded
	var/whitelisted_grenades = list(
		/obj/item/weapon/grenade/frag/shell,
		/obj/item/weapon/grenade/chemical
		)

	var/blacklisted_grenades = list(
		/obj/item/weapon/grenade,
		/obj/item/weapon/grenade/frag
		)

	matter = list(DEFAULT_WALL_MATERIAL = 2000)

/obj/item/weapon/gun/launcher/grenade/process_projectile(obj/item/projectile, mob/user, atom/target, var/target_zone, var/params=null, var/pointblank=0, var/reflex=0)
	update_release_force(projectile)
	projectile.loc = get_turf(user)
	projectile.allow_spin = FALSE
	projectile.throw_at(target, firing_range, release_force, user)
	projectile.dir = get_dir(get_turf(src), get_turf(target))
	projectile.icon_state = "[initial(projectile.icon_state)]_active"
	playsound(get_turf(user), fire_sound, 100, TRUE,100)
	return TRUE

/obj/item/weapon/gun/launcher/grenade/examine(mob/user)
	if (..(user, 2))
		to_chat(user, "Has [grenades.len] grenade\s remaining.")

/obj/item/weapon/gun/launcher/grenade/proc/load(obj/item/weapon/grenade/G, mob/user)
	if (!can_load_grenade_type(G, user))
		return
	if (grenades.len >= max_grenades)
		to_chat(user, SPAN_WARNING("\The [src] is full."))
		return

	user.drop_from_inventory(G, src)
	G.loc = src
	grenades.Insert(1, G) //add to the head of the list, so that it is loaded on the next pump

/obj/item/weapon/gun/launcher/grenade/proc/unload(mob/user)
	if (grenades.len)
		var/obj/item/weapon/grenade/G = grenades[grenades.len]
		grenades -= G
		user.put_in_hands(G)
	else
		to_chat(user, SPAN_WARNING("\The [src] is empty."))

/obj/item/weapon/gun/launcher/grenade/attackby(obj/item/I, mob/user)
	if ((istype(I, /obj/item/weapon/grenade)))
		if (do_after(user, 10, src, can_move = TRUE))
			load(I, user)
	else
		..()

/obj/item/weapon/gun/launcher/grenade/attack_hand(mob/user)
	if (user.get_inactive_hand() == src)
		unload(user)
	else
		..()

/obj/item/weapon/gun/launcher/grenade/consume_next_projectile()
	if (grenades.len)
		var/obj/item/weapon/grenade/G = grenades[1]
		G.dir = src.loc.dir
		G.det_time = 15
		G.activate(null)
		grenades -= G
		return G
	return null

/obj/item/weapon/gun/launcher/grenade/handle_post_fire(mob/user)
	message_admins("[key_name_admin(user)] fired a grenade launcher ([src.name]).", key_name_admin(user))
	log_game("[key_name_admin(user)] fired a grenade launcher ([src.name]).")
	..()

/obj/item/weapon/gun/launcher/grenade/proc/can_load_grenade_type(obj/item/weapon/grenade/G, mob/user)
	if (is_type_in_list(G, blacklisted_grenades) && ! is_type_in_list(G, whitelisted_grenades))
		to_chat(user, "<span class='warning'>\The [G] doesn't seem to fit in \the [src]!</span>")
		return FALSE
	return TRUE

// For uplink purchase, comes loaded with a random assortment of grenades
/obj/item/weapon/gun/launcher/grenade/loaded/New()
	..()

	var/list/grenade_types = list(
		/obj/item/weapon/grenade/smokebomb = 2,
		/obj/item/weapon/grenade/frag/shell = 1 //dont do this ever again
		)

	var/grenade_type = pickweight(grenade_types)
	for(var/i in 1 to max_grenades)
		grenade_type = pickweight(grenade_types)
		grenades += new grenade_type(src)

//Underslung grenade launcher to be used with the Z8
/obj/item/weapon/gun/launcher/grenade/underslung
	name = "underslung grenade launcher"
	desc = "Not much more than a tube and a firing mechanism, this grenade launcher is designed to be fitted to a rifle."
	icon = 'icons/obj/gun_att.dmi'
	icon_state = "grenade_launcher"
	w_class = ITEM_SIZE_NORMAL
	force = 5
	firing_range = 40
	max_grenades = 1
	var/A_attached = FALSE
	var/mount = "none"

/obj/item/weapon/gun/launcher/grenade/underslung/attack_self()
	return

//load and unload directly into grenades
/obj/item/weapon/gun/launcher/grenade/underslung/load(obj/item/weapon/grenade/G, mob/user)
	if (!can_load_grenade_type(G, user))
		return
	if (grenades.len >= max_grenades)
		to_chat(user, SPAN_WARNING("\The [src] is full."))
		return

	user.drop_from_inventory(G, src)
	G.loc = src
	grenades += G

/obj/item/weapon/gun/launcher/grenade/underslung/unload(mob/user)
	if (grenades.len)
		var/obj/item/weapon/grenade/G = grenades[grenades.len]
		grenades -= G
		user.put_in_hands(G)
	else
		to_chat(user, SPAN_WARNING("\The [src] is empty."))

///////////////////////////////////////
/////LAUNCHERS/////////////////////////
///////////////////////////////////////

//////////////////////////// underslug and launcher ////////////////////////////

/obj/item/weapon/gun/launcher/grenade/underslung/m203
	name = "M203 grenade launcher"
	release_force = 2
	firing_range = 40
	desc = "Not much more than a tube and a firing mechanism, this grenade launcher is designed to be fitted to a rifle."
	mount = "m203_mount"
	whitelisted_grenades = list(
		/obj/item/weapon/grenade/frag/ugl/shell40mm,
		/obj/item/weapon/grenade/smokebomb/ugl/shell40mm,
		/obj/item/weapon/grenade/chemical/ugl
		)

	blacklisted_grenades = list(
		/obj/item/weapon/grenade/frag/ugl/vog25,
		/obj/item/weapon/grenade/smokebomb/ugl/vog25,
		/obj/item/weapon/grenade,
		/obj/item/weapon/grenade/frag,
		/obj/item/weapon/grenade/smokebomb
		)

/obj/item/weapon/gun/launcher/grenade/underslung/gp25
	name = "GP-25 'Koster' grenade launcher"
	release_force = 2
	firing_range = 40
	desc = "Not much more than a tube and a firing mechanism, this grenade launcher is designed to be fitted to a rifle."
	mount = "gp25_mount"
	whitelisted_grenades = list(
		/obj/item/weapon/grenade/frag/ugl/vog25,
		/obj/item/weapon/grenade/smokebomb/ugl/vog25,
		/obj/item/weapon/grenade/chemical/ugl
		)
	blacklisted_grenades = list(
		/obj/item/weapon/grenade/frag/ugl/shell40mm,
		/obj/item/weapon/grenade/smokebomb/ugl/shell40mm,
		/obj/item/weapon/grenade,
		/obj/item/weapon/grenade/frag,
		/obj/item/weapon/grenade/smokebomb
		)

//Grenade Launcher
/obj/item/weapon/gun/launcher/grenade/standalone
	name = "Standalone Grenade Launcher"
	desc = "A generic standalone grenade launcher"
	icon_state = "hk69"
	item_state = "hk69"
	w_class = ITEM_SIZE_LARGE
	max_grenades = 1
	shake_strength = 1
	gun_safety = TRUE
	release_force = 2
	firing_range = 40
	equiptimer = 25
	slot_flags =  SLOT_SHOULDER | SLOT_BACK
	var/cover_opened = FALSE
	whitelisted_grenades = list(
		/obj/item/weapon/grenade/frag/ugl/shell40mm,
		/obj/item/weapon/grenade/smokebomb/ugl/shell40mm,
		/obj/item/weapon/grenade/frag/ugl/vog25,
		/obj/item/weapon/grenade/smokebomb/ugl/vog25,
		/obj/item/weapon/grenade/chemical/ugl
		)
	blacklisted_grenades = list(
		/obj/item/weapon/grenade,
		/obj/item/weapon/grenade/frag,
		/obj/item/weapon/grenade/smokebomb
		)

/obj/item/weapon/gun/launcher/grenade/standalone/New()
	..()
	var/obj/item/weapon/attachment/A = new /obj/item/weapon/attachment/scope/iron_sights(src)
	spawn_add_attachment(A, src)

/obj/item/weapon/gun/launcher/grenade/standalone/consume_next_projectile()
	if (cover_opened)
		return null
	if (grenades.len)
		var/obj/item/weapon/grenade/G = grenades[1]
		G.dir = src.loc.dir
		G.det_time = 15
		G.activate(null)
		grenades -= G
		return G
	return null

//load and unload directly into grenades
/obj/item/weapon/gun/launcher/grenade/standalone/load(obj/item/weapon/grenade/G, mob/user)
	if (!can_load_grenade_type(G, user))
		return
	if (!cover_opened)
		return
	if (grenades.len >= max_grenades)
		to_chat(user, SPAN_WARNING("\The [src] is full."))
		return

	user.drop_from_inventory(G, src)
	G.loc = src
	grenades += G
	playsound(src, 'sound/weapons/guns/interact/launcher_insertgrenade.ogg', 50, 1)
	update_icon()

/obj/item/weapon/gun/launcher/grenade/standalone/unload(mob/user)
	if (cover_opened)
		if (grenades.len)
			var/obj/item/weapon/grenade/G = grenades[grenades.len]
			grenades -= G
			user.put_in_hands(G)
			update_icon()
			playsound(src, 'sound/weapons/guns/interact/launcher_empty.ogg', 50, 1)
		else
			to_chat(user, "<span class='warning'>\The [src] is empty.</span>")
	else
		to_chat(user, "<span class='warning'>\The [src] is closed.</span>")

/obj/item/weapon/gun/launcher/grenade/standalone/proc/toggle_cover(mob/user)
	cover_opened = !cover_opened
	playsound(src, 'sound/weapons/guns/interact/launcher_openbarrel.ogg', 50, 1)
	update_icon()

/obj/item/weapon/gun/launcher/grenade/standalone/attack_self(mob/user as mob)
	toggle_cover(user)

/obj/item/weapon/gun/launcher/grenade/standalone/update_icon()
	..()
	if (cover_opened)
		if (grenades.len)
			icon_state = "[initial(icon_state)]_open"
		else
			icon_state = "[initial(icon_state)]_open_empty"
	else
		icon_state = "[initial(icon_state)]"



/obj/item/weapon/gun/launcher/grenade/standalone/hk69
	name = "HK69A1 grenade launcher"
	desc = "A German made multi-use 40mm grenade launcher."
	icon_state = "hk69"
	item_state = "hk69"
	whitelisted_grenades = list(
		/obj/item/weapon/grenade/frag/ugl/shell40mm,
		/obj/item/weapon/grenade/smokebomb/ugl/shell40mm,
		/obj/item/weapon/grenade/chemical/ugl
		)
	blacklisted_grenades = list(
		/obj/item/weapon/grenade/frag/ugl/vog25,
		/obj/item/weapon/grenade/smokebomb/ugl/vog25,
		/obj/item/weapon/grenade,
		/obj/item/weapon/grenade/frag,
		/obj/item/weapon/grenade/smokebomb
		)

/obj/item/weapon/gun/launcher/grenade/standalone/m79
	name = "M79 Grenade Launcher"
	desc = "An American multi-use 40mm grenade launcher."
	icon_state = "m79"
	item_state = "m79"
	whitelisted_grenades = list(
		/obj/item/weapon/grenade/frag/ugl/shell40mm,
		/obj/item/weapon/grenade/smokebomb/ugl/shell40mm,
		/obj/item/weapon/grenade/chemical/ugl
		)
	blacklisted_grenades = list(
		/obj/item/weapon/grenade/frag/ugl/vog25,
		/obj/item/weapon/grenade/smokebomb/ugl/vog25,
		/obj/item/weapon/grenade,
		/obj/item/weapon/grenade/frag,
		/obj/item/weapon/grenade/smokebomb
		)

/obj/item/weapon/gun/launcher/grenade/standalone/admin
	name = "Grenade Launcher"
	desc = "By the power of gods you can launch any grenade!"
	icon_state = "m79"
	item_state = "m79"
	whitelisted_grenades = list(
		/obj/item/weapon/grenade
		)
	blacklisted_grenades = null